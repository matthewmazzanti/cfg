# pkgs
- Write generic symlinkJoin/makeWrapper system
- Understand what https://github.com/nix-systems/nix-systems is doing
  (dependency of flake-utils)
- Remove fake.nix things

## Neovim
- Create "Share" mode, unset relative numbers
- Fix file path to always be relative - sometimes is home-based when using file
  picker
- Per-project editor config, lines, tabs etc - Already supported?
- Pre-compile Lua code?
- Re-add CCLS for C projects, if used
- Markdown renderer, of some sort

## Zsh
- Re-target zsh history file
- <C-O>/<C-I> mappings to push/pop directories like my buffer stack

## iTerm2
- Figure out how to get plist property loading to work
    - Don't overwrite existing properties, if possible
    - Filter non-relevant properties, like update times

## Direnv
- Upstream wrapper changes

__FOO__


```python
def foo():
  bar, baz
```

# Gitea
- Run on second interface to allow native port 22. Requires setting up static addressing
  and multiple addresses for the server
