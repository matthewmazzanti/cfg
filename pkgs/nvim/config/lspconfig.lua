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
            set("n", "gt", telescope.lsp_type_definitions)
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
    "nil_ls",
    "rust_analyzer",
    "tsserver",
}

for _, server in ipairs(servers) do
    if find_ls(server) then
        lspconfig[server].setup(defaults)
    end
end

if find_ls("lua_ls") then
    local settings = vim.tbl_extend("force", defaults, {
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
    })
    lspconfig.lua_ls.setup(settings)
end

local signs = { Error = "e", Warn = "w", Hint = "h", Info = "i" }
for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl })
end

require("lsp_lines").setup()

vim.diagnostic.config({
    virtual_text = true,
    virtual_lines = false,
    severity_sort = true,
})

vim.keymap.set(
    "",
    "<Leader>d",
    function()
        local diagnostic = vim.diagnostic.config()
        vim.diagnostic.config({
            virtual_text = not diagnostic.virtual_text,
            virtual_lines = not diagnostic.virtual_lines,
        })
    end
)


-- local event = require("nui.utils.autocmd").event
-- 
-- local function nui_lsp_rename()
--   local curr_name = vim.fn.expand("<cword>")
-- 
--   local params = vim.lsp.util.make_position_params()
-- 
--   local function on_submit(new_name)
--     if not new_name or #new_name == 0 or curr_name == new_name then
--       -- do nothing if `new_name` is empty or not changed.
--       return
--     end
-- 
--     -- add `newName` property to `params`.
--     -- this is needed for making `textDocument/rename` request.
--     params.newName = new_name
-- 
--     -- send the `textDocument/rename` request to LSP server
--     vim.lsp.buf_request(0, "textDocument/rename", params, function(_, result, ctx, _)
--       if not result then
--         -- do nothing if server returns empty result
--         return
--       end
-- 
--       -- the `result` contains all the places we need to update the
--       -- name of the identifier. so we apply those edits.
--       local client = vim.lsp.get_client_by_id(ctx.client_id)
--       vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
-- 
--       -- after the edits are applied, the files are not saved automatically.
--       -- let's remind ourselves to save those...
--       local total_files = vim.tbl_count(result.changes)
--       print(
--         string.format(
--           "Changed %s file%s. To save them run ':wa'",
--           total_files,
--           total_files > 1 and "s" or ""
--         )
--       )
--     end)
--   end
--   
--   local popup_options = {
--     -- border for the window
--     border = {
--       style = "rounded",
--       text = {
--         top = "[Rename]",
--         top_align = "left"
--       },
--     },
--     -- highlight for the window.
--     highlight = "Normal:Normal",
--     -- place the popup window relative to the
--     -- buffer position of the identifier
--     relative = {
--       type = "buf",
--       position = {
--         -- this is the same `params` we got earlier
--         row = params.position.line,
--         col = params.position.character,
--       }
--     },
--     -- position the popup window on the line below identifier
--     position = {
--       row = 1,
--       col = 0,
--     },
--     -- 25 cells wide, should be enough for most identifier names
--     size = {
--       width = 25,
--       height = 1,
--     },
--   }
-- 
--   local input = Input(popup_options, {
--     -- set the default value to current name
--     default_value = curr_name,
--     -- pass the `on_submit` callback function we wrote earlier
--     on_submit = on_submit,
--     prompt = "",
--   })
-- 
--   input:mount()
-- 
--   -- close on <esc> in normal mode
--   input:map("n", "<esc>", input.input_props.on_close, { noremap = true })
-- 
--   -- close when cursor leaves the buffer
--   input:on(event.BufLeave, input.input_props.on_close, { once = true })
-- end
