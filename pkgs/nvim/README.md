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
│   ├── marks.lua        # Sign-column marks (configures utils.marks)
│   └── readline.lua     # Readline keybindings for cmdline
├── plugin/
│   ├── readline.lua     # Readline utilities library
│   └── marks.lua        # Event-driven mark rendering engine
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

### Marks (marks.lua → utils.marks)
Shows the `a`–`z` (buffer-local) and `A`–`Z` (global) marks in the sign column,
replacing vim-signature. The renderer is fully event-driven — no polling timer,
zero idle cost. Signs are re-derived from `getmarklist()` on each change, so they
stay correct even through `:sort` (which pins marks to line numbers). Jump with
`` `{mark} ``/`'{mark}` and clear with `:delmarks` as usual; `<leader>m` opens
the fzf mark picker (see Navigation).

Styling is via settable module fields (also seedable through `setup(opts)`), read
on every repaint so they can change at runtime:

| Field | Default | Effect |
|-------|---------|--------|
| `hl_group` | `"MarkGutter"` (→ `Identifier`) | Sign glyph highlight |
| `number_hl_group` | `nil` | Line-number highlight for marked lines (opt-in, e.g. `"CursorLineNr"`) |
| `priority` | `10` | Sign priority |

The engine lives in `plugin/marks.lua` and installs no key mappings — bind the
handlers yourself in `config/marks.lua`. All are exposed under
`require("utils.marks")` and act on the current buffer:

| Call | Effect |
|------|--------|
| `setup(opts?)` | Install triggers + default highlight; seeds the styling fields from `opts` |
| `render(bufnr?)` | Force a repaint (nil = all loaded, 0 = current) |
| `toggle(name?)` | Toggle a mark: set/move it to the cursor, or remove it if already on the line. Reads the next keypress when `name` is omitted. |
| `set_next()` | Place the next unused `a`–`z` mark at the cursor |
| `delete(name?)` | Delete a mark (reads the next keypress when omitted) |
| `delete_line()` / `delete_buf()` | Delete every mark on the line / in the buffer |
| `next(opts?)` / `prev(opts?)` | Jump to the next / previous mark by file position; `opts.wrap` (default `true`) cycles past the ends |

`config/marks.lua` wires them into a marks.nvim-style layout. A single `m`
mapping reads the next key and dispatches, so the whole `m`-prefix set works with
no `timeoutlen` wait:

| Key | Action |
|-----|--------|
| `m{a-zA-Z}` | Toggle that mark (replaces native set) |
| `m]` / `m[` | Jump to next / previous mark (wraps) |
| `m,` | Set the next unused `a`–`z` mark |
| `dm` | Delete a mark (prompts) |
| `dm-` / `dm<Space>` | Delete every mark on the line / in the buffer |

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
