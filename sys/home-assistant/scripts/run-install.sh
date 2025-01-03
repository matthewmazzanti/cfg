#!/usr/bin/env bash
set -xeuo pipefail

remote="$1"

if [[ ! -z "$(git status -s)" ]]; then
    git add -u
    git commit
    git push
fi

scp install.sh nixos@"$remote":/home/nixos/install.sh
ssh -t nixos@"$remote" 'sudo bash install.sh'
