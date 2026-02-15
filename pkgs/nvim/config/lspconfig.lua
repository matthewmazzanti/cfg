vim.lsp.set_log_level("debug")

-- PLUGIN: lsp_config
-- HOMEPAGE: https://github.com/neovim/nvim-lspconfig
local defaults = {
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
    else
      set("n", "gd", vim.lsp.buf.definition)
      set("n", "gD", vim.lsp.buf.type_definition)
      set("n", "gi", vim.lsp.buf.implementation)
      set("n", "gr", vim.lsp.buf.references)
    end

    -- TODO: For lua, would be nicer to have K open the help document
    set("n", "K", vim.lsp.buf.hover)
    set("n", "<C-k>", vim.lsp.buf.signature_help)
    set("n", "<leader>r", vim.lsp.buf.rename)
  end,
}

local function setup(server, extra)
  -- Check that server binary exists, otherwise don't configure
  if vim.fn.executable(vim.lsp.config[server].cmd[1]) ~= 1 then
    return
  end
  vim.lsp.config(server, vim.tbl_extend("force", defaults, extra or {}))
  vim.lsp.enable(server)
end

-- Load servers
local servers = { "ccls", "gopls", "ts_ls", "nixd" }
for _, server in ipairs(servers) do
  setup(server)
end

setup("pyright", {
  on_new_config = function(config, _)
    config.settings.python.analysis.autoImportCompletions = false
  end
})

setup("rust_analyzer", {
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
})

setup("lua_ls", {
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
        library = vim.api.nvim_get_runtime_file("lua", true),
        checkThirdParty = false,
        useGitIgnore = true,
        ignoreDir = {
          ".git/",
          ".direnv/",
          ".venv/",
          "node_modules/",
          "result/",
        },
      },
      telemetry = {
        enable = false,
      },
    },
  },
})

local symbol = vim.env.TERM == "linux" and "*" or "●"

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
