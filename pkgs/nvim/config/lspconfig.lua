-- PLUGIN: lsp_config
-- HOMEPAGE: https://github.com/neovim/nvim-lspconfig
local lspconfig = require("lspconfig")

local function on_attach(_, bufnr)
    local function set(mode, keys, fn)
        vim.keymap.set(mode, keys, fn, { buffer = bufnr, silent = true })
    end

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    set("n", "gD", vim.lsp.buf.declaration)
    local ok, telescope = pcall(require, "telescope.builtins")
    if ok then
        set("n", "gd", telescope.lsp_definitions)
        set("n", "gi", telescope.lsp_implementations)
        set("n", "gr", telescope.lsp_references)
        set("n", "gt", telescope.lsp_type_definitions)
    end

    -- TODO: Reconsider this for opening help files. Possibly make function
    -- for if in comments?
    set("n", "K", vim.lsp.buf.hover)
    set("n", "<C-k>", vim.lsp.buf.signature_help)
    set("n", "<leader>a", vim.lsp.buf.code_action)
    set("n", "<leader>r", vim.lsp.buf.rename)
end

local defaults = {
    on_attach = on_attach,
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
}

-- Check that server binary exists
local function find_ls(server_name)
    local require_path = "lspconfig.server_configurations." .. server_name
    local cfg = require(require_path)
    return vim.fn.executable(cfg.default_config.cmd[1]) == 1
end


-- Load servers
local servers = {
      "bashls",
      "ccls",
      "gopls",
      "pyright",
      "rnix",
      "rust_analyzer",
      "tsserver",
}

for _, server in ipairs(servers) do
    if find_ls(server) then
        lspconfig[server].setup(defaults)
    end
end

if find_ls("lua_ls") then
    lspconfig.lua_ls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
            Lua = {
                runtime = {
                    version = "LuaJIT",
                },
                diagnostics = {
                    globals = { "vim" },
                },
                workspace = {
                    library = vim.api.nvim_get_runtime_file("", true),
                    checkThirdParty = false,
                },
                telemetry = {
                    enable = false,
                },
            },
        },
    })
end
