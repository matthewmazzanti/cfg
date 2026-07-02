#!/usr/bin/env bash
# SessionStart hook: load direnv's env AND register direnv's OWN watch set with
# Claude Code, so file-change reloads track exactly what direnv watches (the
# .envrc, flake.lock, the .direnv/*.rc profile, any watch_file/dotenv entries,
# and the allow-hash file) with nothing hardcoded.
#
# How: $CLAUDE_ENV_FILE is sourced as a preamble before each Bash tool call, so
# we write direnv's *bash* export there. direnv also stashes its watch list in
# $DIRENV_WATCHES (urlsafe-base64 + zlib). We decode it and hand the absolute
# paths back to Claude Code as `watchPaths`, which it watches for FileChanged
# events this session.
set -u

# 1) Initial env load.
direnv export bash >"$CLAUDE_ENV_FILE" 2>/dev/null || true

# 2) Read direnv's watch list (it's exported into the preamble) and register it.
[ -s "$CLAUDE_ENV_FILE" ] && . "$CLAUDE_ENV_FILE"

python3 - "${DIRENV_WATCHES:-}" <<'PY'
import sys, base64, zlib, json
blob = sys.argv[1]
paths = []
if blob:
    pad = "=" * (-len(blob) % 4)
    try:
        for e in json.loads(zlib.decompress(base64.urlsafe_b64decode(blob + pad))):
            if e.get("path") and e.get("exists"):   # existing files only
                paths.append(e["path"])
    except Exception:
        paths = []
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart", "watchPaths": paths}}))
PY
