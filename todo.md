# TODO

- 1password cli cleanup

## Infrastructure

- [ ] Lock down network access within quadlets
- [ ] Clean up nix modules generally
- [ ] Find a way of defining package sets for different systems that doesn't suck
  - Root/user/home manager level - who owns what?
  - How do I sync between them?
  - System overrides
- [ ] wayland/wm fast iteration thing

## Packages

- [ ] Formalize wrapping/config generation system
  - Wrappers to configure programs, not dropping files onto system
  - Nix -> config via composable libraries (nix/external scripts), not opaque modules
  - Possibly extract as standalone project
  - Support: neovim, zsh, ghostty, git, direnv, etc.
  - Lightweight nix -> file format helpers (generalize ghostty format.nix pattern)
- [ ] Understand what https://github.com/nix-systems/nix-systems is doing (dependency of flake-utils)
- [ ] Remove fake.nix things
- [ ] Re-add less/tmux configs - wrappers still live in pkgs/{less,tmux} but are orphaned (tmux never wired into pkgs/default.nix; less/dev only reaches the beta host). Hook them into the hosts I actually use.

## Neovim

- [x] Create "Share" mode, unset relative numbers
- [x] Markdown renderer
- [x] Replace lualine with native statusline + tabline
- [x] Fix file path to always be relative - sometimes is home-based when using file picker
- [x] Pre-compile Lua code? - not worth it; complexity/error messages outweigh the minimal startup savings
- [x] Per-project editor config, lines, tabs etc - supported natively via editorconfig (built in since 0.9)
- [x] Flesh out utils.marks handler API - shipped simple bindable verbs (`toggle`/`delete`/`delete_line`/`delete_buf`/`set_next`/`next`/`prev`) instead of the planned `{ buf, line, names }` selector; bound marks.nvim-style (`m{a-zA-Z}`/`m]`/`m[`/`m,`/`dm*`) in `config/marks.lua`.
- [x] Add a CLAUDE.md for pkgs/nvim
- [x] Add :LspStop/:LspStart/:LspRestart commands - the new vim.lsp.config/enable API ships none (nvim-lspconfig provides them only when its plugin loads). Buffer-scoped, async (no blocking wait), `!` force-kills; approach adapted from nvim-lspconfig's new-API commands.
- [ ] Re-add CCLS (C) + rust_analyzer (Rust), if used - expands the closure size, and forces frequent rebuilds under nixpkgs-unstable
- [ ] Upstream a Neovim "mark moved" event (e.g. `MarkUpdate`) - `MarkSet` only fires on add/remove/re-set, not when a mark's line *drifts* from edits (insert/delete lines, `:sort`). utils.marks papers over that with `nvim_buf_attach`/`on_lines` edit-tracking gated to structural changes. A native event when a mark's position changes would let utils.marks (and similar) drop that machinery and just re-derive on notification.

## Zsh

- [x] `<C-O>`/`<C-I>` mappings to push/pop directories like buffer stack

## Direnv

- [ ] Upstream wrapper changes - https://github.com/direnv/direnv/pull/1564

## Gitea

- [ ] Run on second interface to allow native port 22
  - Requires setting up static addressing and multiple addresses for the server


