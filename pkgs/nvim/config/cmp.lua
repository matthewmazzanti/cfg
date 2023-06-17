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

-- cmp uses a winhighlight string to change color of suggestions. Build that
-- from a mapping
local function winhighlight(data)
    local res = ""
    for key, value in pairs(data) do
        if res ~= "" then
            res = res .. ","
        end
        res = res .. key .. ":" .. value
    end
    return res
end

cmp.setup({
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    window = {
        completion = cmp.config.window.bordered({
            winhighlight = winhighlight({
                Normal = "Normal",
                FloatBorder = "GruvboxGray",
                CursorLine = "Visual",
                Search = "None",
            })
        }),
        documentation = cmp.config.window.bordered({
            winhighlight = winhighlight({
                Normal = "Normal",
                FloatBorder = "GruvboxGray",
                CursorLine = "Visual",
                Search = "None",
            })
        }),
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-d>"] = cmp.mapping.scroll_docs(4),
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        -- Accept currently selected item. Set `select` to `false` to only
        -- confirm explicitly selected items.
        -- TODO: Check back in on this
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
    }),
    formatting = {
        format = function(_entry, vim_item)
            -- Shorten "kind" name
            vim_item.kind = kind_display[vim_item.kind]

            return vim_item
        end
    },
})

vim.keymap.set("i", "<C-n>", cmp.complete)
