-- Setup nvim-cmp.
local cmp = require("cmp")
local luasnip = require("luasnip")

vim.opt.completeopt = {
    "menu",
    "menuone",
    "noselect"
}

local kind_display = {
    Text          = "text",
    Method        = "mthd",
    Function      = "func",
    Constructor   = "init",
    Field         = "fld",
    Variable      = "var",
    Class         = "cls",
    Interface     = "ifc",
    Module        = "mod",
    Property      = "prop",
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
    Constant      = "cnst",
    Struct        = "stct",
    Event         = "evnt",
    Operator      = "oper",
    TypeParameter = "typr",
}

cmp.setup({
    --[[
    snippet = {
        -- REQUIRED - you must specify a snippet engine
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    ]]
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-d>"] = cmp.mapping.scroll_docs(4),
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        -- Accept currently selected item. Set `select` to `false` to only
        -- confirm explicitly selected items.
        -- TODO: Check back in on this
        -- ["<CR>"] = cmp.mapping.confirm({ select = true }),
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "buffer" },
        -- { name = "luasnip" },
    }),
    formatting = {
        format = function(entry, vim_item)
            print(vim.inspect(entry))
            -- Shorten "kind" name
            vim_item.kind = kind_display[vim_item.kind]

            return vim_item
        end
    },
})

vim.keymap.set("i", "<C-n>", cmp.complete)
