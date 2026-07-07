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
│   ├── lspconfig.lua    # Language server setup
│   ├── blink.lua        # Completion (blink-cmp)
│   ├── fzf.lua          # Fuzzy finder
│   ├── lualine.lua      # Status line
│   ├── treesitter.lua   # Syntax highlighting & textobjects
│   ├── input.lua        # Custom floating input dialog
│   ├── fidget.lua       # LSP progress notifications
│   ├── surround.lua     # Surround text objects
│   ├── easyclip.lua     # Improved yank/delete
│   └── readline.lua     # Readline keybindings for cmdline
├── plugin/
│   └── readline.lua     # Readline utilities library
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

### Editing (easyclip.lua)
| Key | Action |
|-----|--------|
| `x` | Delete char (no clipboard) |
| `xx` | Delete line |
| `X` | Delete to end of line |

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
