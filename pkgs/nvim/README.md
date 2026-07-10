# Neovim Configuration

A modular Nix-based Neovim configuration with feature flags, LSP support, and per-language customization.

## Directory Structure

```
pkgs/nvim/
├── default.nix          # Main entry point - plugin/package orchestration
├── wrapper.nix          # Assembles final Neovim executable
├── config/              # Lua configuration modules
│   ├── init.lua         # Core editor settings
│   ├── gruvbox.lua      # Color theme
│   ├── lsp.lua          # Language server setup
│   ├── blink.lua        # Completion (blink-cmp)
│   ├── fzf.lua          # Fuzzy finder
│   ├── statusline.lua   # Tab & Status line
│   ├── treesitter.lua   # Syntax highlighting & textobjects
│   ├── input.lua        # Custom floating input dialog
│   ├── fidget.lua       # LSP progress notifications
│   ├── surround.lua     # Surround text objects
│   ├── clip.lua         # Cut/yank/paste register model (loads everywhere)
│   ├── marks.lua        # Sign-column marks (configures utils.render-marks)
│   └── readline.lua     # Readline keybindings for cmdline
├── plugin/
│   ├── readline.lua     # Readline utilities library
│   └── render-marks.lua # Event-driven mark rendering engine
└── test/                # Test files for various filetypes
```

## Build System

### default.nix

Defines feature toggles and assembles the configuration:

- **Feature flags**: `plugins`, `treesitter`, `lsp`, `ai`, language toggles
- **Language servers**: ccls, gopls, pyright, rust-analyzer, lua_ls, nixd, ts_ls
- **Ftplugin**: Auto-generated per-language indent settings
- **Plugin selection**: Conditional based on enabled features

### wrapper.nix

Creates the final wrapped executable:

1. Normalizes plugins into vim pack directories
2. Sets up LUA_PATH/LUA_CPATH for plugin dependencies
3. Generates combined init.lua loading all config modules
4. Adds LSP servers and tools to PATH
5. Creates the `vim` -> `nvim` alias

## Keybindings

**Leader key**: `;`

### General (init.lua)
| Key | Action |
|-----|--------|
| `<leader>n` | Clear search highlight |
| `<leader>l` | Toggle relative line numbers (also `:Share`) |

### Navigation (fzf.lua)
| Key | Action |
|-----|--------|
| `<leader>f` | Find files |
| `<leader>b` | Buffers |
| `<leader>j` | Jumps |
| `<leader>m` | Marks |
| `<leader>g` | Live grep |
| `z=` | Spell suggestions |

### LSP (lspconfig.lua)
| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to type definition |
| `gi` | Go to implementation |
| `gr` | Go to references |
| `K` | Hover documentation |
| `<C-k>` | Signature help |
| `<leader>r` | Rename |
| `<leader>d` | Toggle diagnostic virtual text |
| `<leader>k` | Open diagnostic float |

### Treesitter Textobjects
| Key | Object |
|-----|--------|
| `am`/`im` | Function (outer/inner) |
| `aC`/`iC` | Class (outer/inner) |
| `ac`/`ic` | Comment (outer/inner) |

### TreeSJ (treesitter.lua)
| Key | Action |
|-----|--------|
| `<leader>s` | Toggle split/join |
| `<leader>S` | Toggle recursive |

### Clipboard (clip.lua)
`d` = destroy, `x` = cut, `y` = yank — each a motion operator (double for
linewise, uppercase for to-EOL). `d` goes to the black hole, so it never
disturbs what `x`/`y` stored. Locally the default register is the system
clipboard (`unnamedplus`); over SSH it stays in-editor so nothing reaches OSC 52.

| Key | Action |
|-----|--------|
| `d` / `dd` / `D` | Delete → black hole (leaves the clipboard alone) |
| `x` / `xx` / `X` | Cut → default register |
| `y` / `yy` / `Y` | Yank → default register |
| `p` / `P` | Paste from default register (repeatable) |

### Marks (marks.lua → utils.render-marks)
Shows the `a`–`z` (buffer-local) and `A`–`Z` (global) marks in the sign column,
replacing vim-signature. The renderer is fully event-driven — no polling timer,
zero idle cost. Signs are re-derived from `getmarklist()` on each change, so they
stay correct even through `:sort` (which pins marks to line numbers). Set marks
with the usual `m{a-zA-Z}`; jump with `` `{mark} ``/`'{mark}`; clear with
`:delmarks`. `<leader>m` opens the fzf mark picker (see Navigation).

The sign glyph uses the `MarkGutter` highlight (installed by `setup`, linked to
`Identifier` by default — re-link it to restyle).

The engine lives in `plugin/render-marks.lua`. It installs no key mappings —
bind the handlers yourself in `config/marks.lua`. It exposes:

All under `require("utils.render-marks")`. A **selector** is
`{ buf, line, names }`: `buf` defaults to the current buffer (`0` also means
current); `line` is a number or `{lo, hi}` range; `names` is a string
(`"ab"` = a and b), a list, or nil for all. Local vs global is implicit in the
mark's case (`a` local, `A` global).

| Call | Effect |
|------|--------|
| `setup({ hl_group, priority })` | Install triggers + default highlight; `config/marks.lua` calls this |
| `render(bufnr)` | Force a repaint (nil = all loaded, 0 = current) |
| `list(sel?)` | Marks matching the selector → records `{name, buf, lnum, col, global?}` |
| `delete(sel?)` | Delete the marks `list` would return → deleted names |
| `set(name, where?)` | Set `name`; `where = { buf, line, col }` (default cursor) |
| `prompt()` | Read a mark name from the next keypress (nil if not a–zA–Z) |
| `set_next()` | Place the next unused `a`–`z` mark at the cursor |
| `toggle()` | Clear the current line's marks, or place the next if none |
| `jump(dir, opts?)` / `next(opts?)` / `prev(opts?)` | Jump by position; `opts = { from, wrap, names }` |

Examples: `delete({ names = "a" })`, `delete({ line = 42 })`, `delete()`
(whole buffer), `list({ names = "A" })` (just global `A` pointing here),
`set("q", { line = 42 })`.

### Readline (command mode)
| Key | Action |
|-----|--------|
| `<M-f>` / `<M-b>` | Word forward/backward |
| `<C-a>` / `<C-e>` | Line start/end |
| `<C-u>` | Kill line backward |
| `<C-k>` | Kill to end |
| `<M-d>` | Kill word |
| `<C-w>` | Unix word rubout |

## Language Support

Per-language settings are generated via ftplugin:

| Language | Indent |
|----------|--------|
| Python | 4 spaces, colorcolumn=89 |
| Go, C | Tabs |
| JS/TS, Nix, Lua, HTML, CSS | 2 spaces |

## Configuration Loading Order

1. `init.lua` - Core editor settings, leader key, basic options
2. `gruvbox.lua` - Color scheme
3. `input.lua` - Custom vim.ui.input override
4. Plugin configs loaded via `safe_dofile()` (pcall-wrapped)

## Design Notes

- **Modular**: Each config file handles one plugin/feature independently
- **Fallback behavior**: Features degrade gracefully if dependencies missing
- **Terminal-aware**: Detects Ghostty vs standard terminals, adjusts visuals
- **Safe loading**: pcall() prevents broken configs from crashing the editor
- **Nix patterns**: Uses `optionals` for conditional inclusion of servers/plugins

## TODO

### Markdown Rendering

Goals:
- [ ] Nested code blocks highlighted with appropriate language parsers
- [ ] Easy to glance headings & distinguish depth visually
- [ ] Good list handling with correct wrapping behavior
- [ ] Consistent markdown-aware wrapping that preserves document structure (custom `formatexpr` + treesitter)
- [ ] Nicer table rendering for non-formatted tables
- [ ] Table reformatting capability (auto-align columns)

Explore/extend:
- [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) - Rich markdown rendering with conceal
- [markdown.nvim](https://github.com/tadmccorkle/markdown.nvim) - Markdown editing utilities (lists, links, TOC)
- [nabla.nvim](https://github.com/jbyuki/nabla.nvim) - Render LaTeX as ASCII art
