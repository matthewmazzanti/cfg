local kind_map = {
  Text          = "txt",
  Method        = "mth",
  Function      = "fn",
  Constant      = "cnst",
  Constructor   = "init",
  Field         = "fld",
  Variable      = "var",
  Class         = "cls",
  Interface     = "ifc",
  Module        = "mod",
  Property      = "prp",
  Unit          = "unit",
  Value         = "val",
  Enum          = "enum",
  Keyword       = "kywd",
  Snippet       = "snip",
  Color         = "clr",
  File          = "file",
  Reference     = "ref",
  Folder        = "fldr",
  EnumMember    = "mem",
  Struct        = "stct",
  Event         = "evnt",
  Operator      = "oper",
  TypeParameter = "typr",
}

local function kind_text(ctx)
  local remap = kind_map[ctx.kind]
  if remap == nil then
    return ctx.kind
  end
  return remap
end

require("blink.cmp").setup({
  cmdline = {
    enabled = true,
    keymap = {
      preset = 'none',
      ['<Tab>'] = { 'show_and_insert', 'select_next' },
      ['<S-Tab>'] = { 'show_and_insert', 'select_prev' },
      ['<C-space>'] = { 'show', 'fallback' },
      ['<C-n>'] = { 'select_next', 'fallback' },
      ['<C-p>'] = { 'select_prev', 'fallback' },
      ['<C-y>'] = { 'select_and_accept' },
    }
  },
  completion = {
    accept = { auto_brackets = { enabled = false }, },

    menu = {
      -- nvim-cmp style menu
      draw = {
        columns = {
          { "label", "label_description", gap = 1 },
          { "kind" }
        },
        components = { kind = { text = kind_text } }
      }
    },

    -- Show documentation when selecting a completion item
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 500,
    },

    -- Display a preview of the selected item on the current line
    ghost_text = { enabled = true },
  }
})
