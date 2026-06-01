# TODO

- 1password cli cleanup

## Infrastructure

- [ ] Lock down network access within quadlets
- [ ] Clean up nix modules generally
- [ ] Find a way of defining package sets for different systems that doesn't suck
  - Root/user/home manager level - who owns what?
  - How do I sync between them?
  - System overrides

## Packages

- [ ] Formalize wrapping/config generation system
  - Wrappers to configure programs, not dropping files onto system
  - Nix -> config via composable libraries (nix/external scripts), not opaque modules
  - Possibly extract as standalone project
  - Support: neovim, zsh, ghostty, git, direnv, etc.
  - Lightweight nix -> file format helpers (generalize ghostty format.nix pattern)
- [ ] Understand what https://github.com/nix-systems/nix-systems is doing (dependency of flake-utils)
- [ ] Remove fake.nix things

## Neovim

- [ ] Create "Share" mode, unset relative numbers
- [ ] Fix file path to always be relative - sometimes is home-based when using file picker
- [ ] Per-project editor config, lines, tabs etc - already supported?
- [ ] Pre-compile Lua code?
- [ ] Re-add CCLS for C projects, if used
- [ ] Markdown renderer

## Zsh

- [x] `<C-O>`/`<C-I>` mappings to push/pop directories like buffer stack

## Direnv

- [ ] Upstream wrapper changes

## Gitea

- [ ] Run on second interface to allow native port 22
  - Requires setting up static addressing and multiple addresses for the server


