-- PLUGIN: lsp_config
-- HOMEPAGE: https://github.com/neovim/nvim-lspconfig
local lspconfig = require("lspconfig")

local defaults = {
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
    on_attach = function(_client, bufnr)
        local function set(mode, keys, fn)
            vim.keymap.set(mode, keys, fn, { buffer = bufnr, silent = true })
        end

        -- See `:help vim.lsp.*` for documentation on any of the below functions
        set("n", "gD", vim.lsp.buf.declaration)
        local ok, telescope = pcall(require, "telescope.builtin")
        if ok then
            set("n", "gd", telescope.lsp_definitions)
            set("n", "gi", telescope.lsp_implementations)
            set("n", "gr", telescope.lsp_references)
            set("n", "gD", telescope.lsp_type_definitions)
        end

        -- TODO: For lua, would be nicer to have K open the help document
        set("n", "K", vim.lsp.buf.hover)
        set("n", "<C-k>", vim.lsp.buf.signature_help)
        set("n", "<leader>a", vim.lsp.buf.code_action)
        set("n", "<leader>r", vim.lsp.buf.rename)
    end,
}

-- Check that server binary exists
local function find_ls(server_name)
    -- This is a hack for pulling internals...
    local require_path = "lspconfig.configs." .. server_name
    local cfg = lspconfig[server_name].config_def
    return vim.fn.executable(cfg.default_config.cmd[1]) == 1
end


-- Load servers
local servers = {
    "ccls",
    "gopls",
    "nil_ls",
    "ts_ls",
}

for _, server in ipairs(servers) do
    if find_ls(server) then
        lspconfig[server].setup(defaults)
    end
end

local function find_python(root_dir)
    local venv_python = root_dir .. "/.venv/bin/python"
    if vim.fn.filereadable(venv_python) == 1 then
        return venv_python
    end

    return vim.fn.exepath("python")
end

if find_ls("pyright") then
    local settings = {
        root_dir = lspconfig.util.root_pattern("pyproject.toml"),
        on_new_config = function(config, root_dir)
            local python = find_python(root_dir)
            config.settings.python.pythonPath = python
            config.settings.python.analysis.autoImportCompletions = false
        end
    }

    lspconfig.pyright.setup(vim.tbl_extend("force", defaults, settings))
end

if find_ls("rust_analyzer") then
    local settings = {
        ["rust-analyzer"] = {
            cargo = {
                -- Rust toolchain on Nix is in its own drv in the nix store. As
                -- a result, the default sub-path rust-analyzer looks for doesnt
                -- work, this works around this
                --
                -- Further, there are still errors when there's only cargo
                -- available
                sysrootSrc = "",
            }
        }
    }

    lspconfig.rust_analyzer.setup(vim.tbl_extend("force", defaults, settings))
end

if find_ls("lua_ls") then
    local settings = {
        settings = {
            Lua = {
                runtime = {
                    version = "LuaJIT",
                },
                diagnostics = {
                    globals = { "vim" },
                    unusedLocalExclude = { "_*" },
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
    }

    lspconfig.lua_ls.setup(vim.tbl_extend("force", defaults, settings))
end

vim.diagnostic.config({
    virtual_text = true,
    virtual_lines = false,
    severity_sort = true,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "e",
            [vim.diagnostic.severity.WARN] = "w",
            [vim.diagnostic.severity.HINT] = "h",
            [vim.diagnostic.severity.INFO] = "i",
        }
    }
})

vim.keymap.set(
    "",
    "<Leader>d",
    function()
        local diagnostic = vim.diagnostic.config()
        if diagnostic == nil then
            return
        end
        vim.diagnostic.config({
            virtual_text = not diagnostic.virtual_text,
            virtual_lines = not diagnostic.virtual_lines,
        })
    end
)
