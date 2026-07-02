#!/usr/bin/env bash
# FileChanged / CwdChanged hook: re-export direnv's env into $CLAUDE_ENV_FILE.
# The set of files that trigger this is supplied dynamically by the SessionStart
# hook via `watchPaths` (see direnv-session.sh), so there is no hardcoded list
# here. The FileChanged `matcher` in settings.json is only the required-field
# placeholder; the real watch set is direnv's own.
set -u

input="$(cat 2>/dev/null || true)"   # FileChanged provides JSON on stdin

direnv export bash >"$CLAUDE_ENV_FILE" 2>/dev/null || true

# --- TEST INSTRUMENTATION (remove once union behavior is confirmed) ----------
# Record which path triggered us, to verify FileChanged fires for paths that
# were registered via SessionStart watchPaths but are NOT in the matcher.
fp="$(printf '%s' "$input" | python3 -c 'import sys,json
try: d=json.load(sys.stdin); print(d.get("file_path",""), d.get("change_type",""))
except Exception: pass' 2>/dev/null)"
if [ -n "${fp// /}" ]; then
  printf '%s\t%s\n' "$(date -Iseconds 2>/dev/null || echo now)" "$fp" \
    >>"${CLAUDE_PROJECT_DIR:-.}/.claude/filechanged-test.log"
fi
# ---------------------------------------------------------------------------
