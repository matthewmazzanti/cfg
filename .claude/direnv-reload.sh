#!/usr/bin/env bash
# Reload direnv's environment into Claude Code.
#
# Claude Code runs each Bash tool call in a fresh shell, so `export`s do not
# persist. Instead it sources whatever we write to $CLAUDE_ENV_FILE as a
# preamble before every Bash command. We hand it direnv's *bash* export (the
# file is executed as a shell script, NOT parsed as a .env/dotenv file, so
# bash syntax with proper quoting is exactly what's wanted).
#
# Wired to SessionStart / CwdChanged / FileChanged(.envrc|flake.nix|flake.lock)
# in .claude/settings.json.

set -u

# direnv approves content by hash, so any edit to .envrc/flake.* re-blocks the
# dir until re-approved. We do NOT auto-allow: approving an .envrc runs its
# code, and that includes content Claude itself just wrote. Run `direnv allow`
# by hand when you've reviewed the change.
#
# If the dir is blocked, direnv emits nothing, so the preamble ends up empty
# and the env unloads back to your base profile — same as a real shell unloads
# a blocked .envrc. We just print a one-line nudge (hook stdout is surfaced
# back into the session) so you know to approve it.
if direnv export bash >"$CLAUDE_ENV_FILE" 2>/dev/null && [ -s "$CLAUDE_ENV_FILE" ]; then
  exit 0
fi

if direnv status 2>/dev/null | grep -q "Found RC allowed false"; then
  echo "direnv: .envrc is blocked — run 'direnv allow' to load the env"
fi
