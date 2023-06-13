set -e
nix build .
exec -c ./result/bin/zsh -x
