#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["websockets>=13", "pyyaml>=6"]
# ///
"""Push/pull a Home Assistant Lovelace dashboard via the websocket API.

    lovelace.py push [file.yaml]    # save repo YAML -> HA (live, no restart)
    lovelace.py pull [file.yaml]    # fetch HA's current config -> repo YAML

Auth: HASS_TOKEN, falling back to ~/.config/ha/token (a long-lived token).
"""
import argparse
import asyncio
import json
import os
import ssl
import sys
from pathlib import Path
from typing import Any

import yaml
from websockets.asyncio.client import ClientConnection, connect

DEFAULT_URL = "wss://hass.iot/api/websocket"
DEFAULT_DASHBOARD = "lovelace"
DEFAULT_FILE = Path("sys/ha/ui-lovelace.yaml")
TOKEN_FILE = Path("~/.local/share/hass/token").expanduser()


def get_token() -> str:
    tok = os.environ.get("HASS_TOKEN")
    if not tok and TOKEN_FILE.exists():
        tok = TOKEN_FILE.read_text().strip()
    if not tok:
        sys.exit(f"error: set HASS_TOKEN or write {TOKEN_FILE}")
    return tok


async def open_connection(url: str, insecure: bool = False) -> ClientConnection:
    # insecure disables TLS verification entirely (CERT_NONE) — handy when the
    # internal CA cert is malformed/untrusted; ignored for plain ws:// URLs.
    ssl_ctx = None
    if insecure and url.startswith("wss"):
        ssl_ctx = ssl.create_default_context()
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE

    ws = await connect(url, max_size=None, ssl=ssl_ctx)

    hello = json.loads(await ws.recv())
    if hello.get("type") != "auth_required":
        sys.exit(f"error: unexpected greeting {hello}")

    await ws.send(json.dumps({"type": "auth", "access_token": get_token()}))
    res = json.loads(await ws.recv())
    if res.get("type") != "auth_ok":
        sys.exit(f"error: auth failed {res}")

    return ws


async def call(ws: ClientConnection, msg: dict[str, Any]) -> Any:
    await ws.send(json.dumps({"id": 1, **msg}))
    while True:
        res = json.loads(await ws.recv())
        if res.get("id") == 1 and res.get("type") == "result":
            if not res.get("success"):
                sys.exit(f"error: API call failed {res.get('error')}")
            return res.get("result")


async def push(ws: ClientConnection, dashboard: str, file: Path) -> None:
    config = yaml.safe_load(file.read_text())
    await call(ws, {
        "type": "lovelace/config/save",
        "url_path": dashboard,
        "config": config,
    })
    print(f"pushed {file} -> dashboard '{dashboard}'")


async def pull(ws: ClientConnection, dashboard: str, file: Path) -> None:
    config = await call(ws, {"type": "lovelace/config", "url_path": dashboard})
    text = yaml.safe_dump(
        config,
        sort_keys=False,
        allow_unicode=True,
        default_flow_style=False
    )
    file.write_text(text)
    print(f"pulled dashboard '{dashboard}' -> {file}")


async def run(args: argparse.Namespace) -> None:
    ws = await open_connection(args.url, args.insecure)
    try:
        match args.command:
            case "push":
                await push(ws, args.dashboard, args.file)
            case "pull":
                await pull(ws, args.dashboard, args.file)
    finally:
        await ws.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["push", "pull"])
    parser.add_argument(
        "file",
        nargs="?",
        type=Path,
        default=DEFAULT_FILE,
        help="dashboard YAML (default: %(default)s)",
    )
    parser.add_argument(
        "--url",
        default=os.environ.get("HASS_URL", DEFAULT_URL),
        help="HA websocket URL (default: %(default)s; override with $HASS_URL)",
    )
    parser.add_argument(
        "--dashboard",
        default=os.environ.get("HASS_DASHBOARD", DEFAULT_DASHBOARD),
        help="dashboard url_path (default: %(default)s; override with $HASS_DASHBOARD)",
    )
    parser.add_argument(
        "--insecure",
        action="store_true",
        default=True,
        help="skip TLS certificate verification ($HASS_INSECURE)",
    )
    asyncio.run(run(parser.parse_args()))


if __name__ == "__main__":
    main()
