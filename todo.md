# pkgs
- Write generic symlinkJoin/makeWrapper system
- Understand what https://github.com/nix-systems/nix-systems is doing
  (dependency of flake-utils)

## Neovim
- Flesh out picker with more flexible behavior (https://github.com/nvim-telescope/telescope-file-browser.nvim)
- Path autocompletion for cmp
- Tweak cmp auto-selection and enter behavior
- Add rename ui functionality
- Fix file path to always be relative - sometimes is home-based when using file
  picker
- Per-project editor config, lines, tabs etc
- NUI rename box (upstream rename lambda?)
- Pre-compile LuaSnip JSON snippets (from VSCode)
- Pre-compile Lua code
- Re-add CCLS for C projects, if used

## Zsh
- Re-target zsh history file
- Startup seems slow occasionally

## iTerm2
- Figure out how to get plist property loading to work
    - Don't overwrite existing properties, if possible
    - Filter non-relevant properties, like update times
