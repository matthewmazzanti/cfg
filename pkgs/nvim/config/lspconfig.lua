-- PLUGIN: lsp_config
-- HOMEPAGE: https://github.com/neovim/nvim-lspconfig
local lspconfig = require("lspconfig")

local defaults = {
  -- capabilities = require("cmp_nvim_lsp").default_capabilities(),
  on_attach = function(_client, bufnr)
    local function set(mode, keys, fn)
      vim.keymap.set(mode, keys, fn, { buffer = bufnr, silent = true })
    end

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local ok, fzf = pcall(require, "fzf-lua")
    if ok then
      set("n", "gd", fzf.lsp_definitions)
      set("n", "gD", fzf.lsp_typedefs)
      set("n", "gi", fzf.lsp_implementations)
      set("n", "gr", fzf.lsp_references)
      -- set("n", "ga", fzf.lsp_code_actions)
    else
      set("n", "gd", vim.lsp.buf.definition)
      set("n", "gD", vim.lsp.buf.type_definition)
      set("n", "gi", vim.lsp.buf.implementation)
      set("n", "gr", vim.lsp.buf.references)
      -- set("n", "ga", vim.lsp.buf.code_action)
    end

    -- TODO: For lua, would be nicer to have K open the help document
    set("n", "K", vim.lsp.buf.hover)
    set("n", "<C-k>", vim.lsp.buf.signature_help)
    set("n", "<leader>r", vim.lsp.buf.rename)
  end,
}

-- Check that server binary exists
local function find_ls(server_name)
  -- This is a hack for pulling internals...
  local cfg = lspconfig[server_name].config_def
  return vim.fn.executable(cfg.default_config.cmd[1]) == 1
end


-- Load servers
local servers = {
  "ccls",
  "gopls",
  -- "nil_ls",
  "ts_ls",
  "nixd"
}

for _, server in ipairs(servers) do
  if find_ls(server) then
    lspconfig[server].setup(defaults)
  end
end

if find_ls("pyright") then
  local settings = {
    on_new_config = function(config, _)
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

local symbol
if vim.env.TERM == "linux" then
  symbol = "*"
else
  symbol = "●"
end

vim.diagnostic.config({
  virtual_text = true,
  virtual_lines = false,
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = symbol,
      [vim.diagnostic.severity.WARN]  = symbol,
      [vim.diagnostic.severity.HINT]  = symbol,
      [vim.diagnostic.severity.INFO]  = symbol,
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

vim.keymap.set("", "<Leader>k", vim.diagnostic.open_float)
