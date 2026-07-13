# Working on this Neovim config

A wrapped Neovim (see `../CLAUDE.md` for the general wrapper/build model — config
baked into a store path, git-tracked files only, rebuild to see any change).
`README.md` catalogs the keybindings and features; this file is about how *this*
build is wired and the gotchas that will otherwise cost you a debugging cycle.

## Layout and how it's wired

- **Variants** live in `../default.nix`: `nvim/root` (bare — no plugins),
  `nvim/dev` (full: plugins + lsp + treesitter + langs), `nvim/nix` (a small
  subset). A single `options` attrset (`plugins`/`treesitter`/`lsp`/`langs.*`)
  gates everything. `nvim/dev` is the one you normally build and test.
- **`default.nix`** turns those options into three things: the `plugins` list,
  the treesitter `grammars` list, and the `init` list of `config/*.lua` files to
  load. Most `config/*` files are gated behind `opts.plugins` — the plugin-less
  `nvim/root` gets only the plugin-free base set (`init`, `autoread`, `gruvbox`,
  `statusline`, `clip`, `readline`, `marks`).
- **`config/*.lua`** — feature/plugin setup, loaded in list order. `wrapper.nix`
  builds an `init.lua` that `safe_dofile`s each one (pcall-wrapped: a broken
  module prints its error instead of crashing the editor, so failures can be
  silent — check `:messages`).
- **`plugin/*.lua`** — hand-rolled utility *libraries* (`readline`, `marks`,
  `markdown`). The dir is copied to `lua/utils/`, so a file `plugin/foo.lua` is
  `require("utils.foo")`. **Loaded in every variant, including the plugin-less
  `root`** — the utils derivation sits *outside* the `opts.plugins` gate (that
  gate is a trust boundary for unreviewed external plugins; this is owned code),
  so even a `config/*` that loads everywhere (like `statusline`) may `require` it.
- **`ftplugin`** — the `ftplugin` attrset in `default.nix` maps a filetype to a
  Lua **string**, built into a derivation as `ftplugin/<ft>.lua` (buffer-local
  settings/keymaps). It's Nix strings, so keep real logic in a `plugin/` util and
  call it from here (see how `markdown` wires `require'utils.markdown'`). The
  builtin `$VIMRUNTIME/ftplugin/markdown.{vim,lua}` still runs alongside ours —
  don't re-set what it already provides (e.g. `formatlistpat`, `comments`).

Complex logic → a `plugin/` util module; thin wiring → `config/` or an
`ftplugin` string. This config leans hand-rolled (readline, marks, the markdown
indentexpr are all from-scratch) — match that grain over reaching for a plugin.

## Build and test

```sh
# Build the full variant; prints the store path. Binary at $out/bin/nvim.
nix build '.#"nvim/dev"' --no-link --print-out-paths
```

Reminder (see `../CLAUDE.md`): a new `plugin/foo.lua` / `config/foo.lua` is
invisible until `git add`ed — `require` fails / the feature no-ops with no error.

Headless smoke test driving real keystrokes through the built binary:

```sh
nvim --headless file.md -c 'redraw' -c 'call feedkeys("A\<CR>x\<Esc>", "mtx")' -c 'wq'
```

- `feedkeys(..., "mtx")`: **m** = honor mappings, **t** = as-typed, **x** = flush.
- Enter insert with `A` (end of line); `i` sits *before* the cursor cell and will
  split a line one char early.
- **Prime treesitter with `:redraw` first** — see below.

## Gotchas

- **`vim.treesitter.get_node()` does not parse.** It reads the tree the *active
  highlighter* maintains (`:h vim.treesitter.get_node()`). Headless runs never
  redraw, so the highlighter never parses and `get_node` returns **nil** — code
  that looks broken headless is often fine interactively. Prime with a `:redraw`
  (or `parser:parse(true)`) before the keystrokes. Do **not** paper over this by
  forcing a parse inside `indentexpr`: it's a per-keystroke hot path and a
  markdown reparse costs a few ms and grows with file size.
- **`indentexpr` fires *after* the newline, for the new (empty) line.** `v:lnum`
  is the just-created line; it has no content and isn't in the (stale) tree yet.
  Resolve context from the **previous settled line**, which is both non-empty and
  present in the tree.
- **A half-typed marker misparses.** Mid-edit, a lone `-`/`*`/number on its own
  line parses as a `setext_heading` (a `-` underline is a valid H2), not a list
  marker — so the *current line* must be classified lexically, not via the tree.
  The tree is authoritative for *settled* structure (which item, code-block vs
  list), lexical checks own the volatile current line. That split is deliberate;
  keep it.
- **tree-sitter-markdown column quirks.** Query at a line's *first non-blank*
  column, not 0 — column 0 lands in the outer item for nested lists. And a
  top-level item folds its ≤3 leading spaces into the marker node, so the
  marker's *start* column is unreliable; take the visual indent from `indent_of`
  of the marker's line and use the marker's *end* column for the content column.
- **Parsers present ≠ the `grammars` list.** `markdown`/`markdown_inline` are
  pulled in by render-markdown even though they're not in `default.nix`'s
  `grammars`. `config/treesitter.lua` deliberately leaves markdown's `indentexpr`
  unset so `plugin/markdown.lua` can own it.
