local options = {
    -- Relativenumber may be a bit heavy on low-power systems
    number = true,
    relativenumber = true,

    -- Movement stuff
    mouse = "a",
    startofline = false,
    backspace = {"indent", "eol", "start"},

    -- Line wrapping
    colorcolumn = "101",
    wrap = false,

    -- Indentation stuff
    tabstop = 4,
    shiftwidth = 4,
    softtabstop = 4,
    expandtab = true,

    smarttab = true,
    autoindent = true,
    smartindent = true,

    -- Incremental search and better caps handling
    incsearch = true,
    ignorecase = true,
    smartcase = true,

    -- Nice visualization of trailing space/tabs
    list = true,
    listchars = {
        tab = "» ",
        extends = "›",
        precedes = "‹",
        nbsp = "·",
        trail = "·",
    },

    -- Persistent undo
    undofile = true,

    -- Auto-read changed files
    autoread = true,

    -- Don't show mode (using lightline)
    showmode = false,

    -- Always show sign column for marks, errors
    signcolumn = "yes",

    -- nvim-compe
    completeopt = {"menuone", "noselect"},
}

for name, option in pairs(options) do
    vim.opt[name] = option
end

local globals = {
    sql_type_default = "pgsql"
}

for name, global in pairs(globals) do
    vim.g[name] = global
end

vim.opt.shortmess:append("c")

require('nvim-treesitter.configs').setup {
    -- Modules and its options go here
    highlight = { enable = true },
    indent = {
        enable = false,
        -- disable = { "go" },
    },
    textobjects = {
        enable = true,
        select = {
            enable = true,

            keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                ["ic"] = "@class.inner",
                ["al"] = "@loop.outer",
                ["il"] = "@loop.inner",
            }
        }
    }
}

require('compe').setup {
    enabled = true;
    autocomplete = true;
    debug = false;
    min_length = 1;
    preselect = 'enable';
    throttle_time = 80;
    source_timeout = 200;
    resolve_timeout = 800;
    incomplete_delay = 400;
    max_abbr_width = 100;
    max_kind_width = 100;
    max_menu_width = 100;
    documentation = {
        -- the border option is the same as `|help nvim_open_win|`
        border = { '', '' ,'', ' ', '', '', '', ' ' },
        winhighlight = "NormalFloat:CompeDocumentation,FloatBorder:CompeDocumentationBorder",
        max_width = 120,
        min_width = 60,
        max_height = math.floor(vim.o.lines * 0.3),
        min_height = 1,
    };

    source = {
        path = true;
        buffer = true;
        calc = true;
        nvim_lsp = true;
        nvim_lua = true;
        vsnip = true;
        ultisnips = true;
        luasnip = true;
    };
}

-- LSP
local on_attach = function(_, bufnr)
    local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
    local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

    -- Enable completion triggered by <c-x><c-o>
    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    local opts = { noremap=true, silent=true }

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
    buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
    -- buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
    buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
    buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
end


local lspconfig = require("lspconfig")
for name, cmd in pairs(language_servers) do
    lspconfig[name].setup {
        cmd = cmd,
        on_attach = on_attach,
        flags = {
            debounce_text_changes = 150,
        }
    }
end

lspconfig.sumneko_lua.setup({
    -- sumneko_lua passed as string
    cmd = { sumneko_lua },
    on_attach = on_attach,
    flags = {
        debounce_text_changes = 150,
    },
    settings = {
        Lua = {
            runtime = {
                -- Tell the language server which version of Lua you're using
                -- (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
            },
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = {'vim'},
            },
            workspace = {
                -- Make the server aware of Neovim runtime files
                library = vim.api.nvim_get_runtime_file("", true),
            },
            -- Do not send telemetry data containing a randomized but unique identifier
            telemetry = {
                enable = false,
            },
        },
    },
})
