import asyncio
from subprocess import run, CalledProcessError
from json import loads
from os import environ
from sys import argv

HOME = environ["HOME"]
SOCK = "unix:" + environ.get("XDG_RUNTIME_DIR", "/var/run") + "/kitty"
KITTY = f'kitty --single-instance --detach --listen-on {SOCK}'.split(' ')

def main():
    try:
        directory = get_dir()
    except Exception as e:
        directory = HOME

    run([*KITTY, "-d", directory, *argv[1:]], cwd=HOME)

def get_dir():
    run_args = { "capture_output": True, "text": True, "check": True }

    process = run("bspc query -T -n".split(' '), **run_args)
    window_info = loads(process.stdout)

    assert window_info["client"]["className"] == "kitty"

    process = run(f"kitty @ --to {SOCK} ls".split(' '), **run_args)
    kitty_info = loads(process.stdout)

    term = find_focused(kitty_info)
    tab = find_focused(term["tabs"])

    return tab["windows"][0]["cwd"]

def find_focused(kitty_info):
    for item in kitty_info:
        if item["is_focused"]:
            return item

    raise Exception("No focused items")

if __name__ == "__main__":
    main()
