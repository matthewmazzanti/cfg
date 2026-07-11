-- Override the LSP client log level from the environment (e.g. "debug",
-- "trace"). Unset -> leave vim.lsp's built-in default (WARN) in place.
if vim.env.NVIM_LSP_LOG then
  vim.lsp.log.set_level(vim.env.NVIM_LSP_LOG)
end

-- PLUGIN: lsp_config
-- HOMEPAGE: https://github.com/neovim/nvim-lspconfig
-- Defaults merged into every server's resolved config (see `:help lsp-config`).
-- Servers whose `cmd[1]` isn't on PATH are skipped automatically by vim.lsp's
-- internal validation, so no manual executable check is needed.
vim.lsp.config("*", {
  -- Neovim disables didChangeWatchedFiles on Linux/BSD by default (see
  -- protocol.lua make_client_capabilities). Re-advertise it: we ship
  -- inotify-tools, so the watcher uses the `inotify` backend rather than the
  -- slow libuv-watchdirs poller.
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
  },
})

vim.lsp.config("pyright", {
  settings = {
    python = {
      analysis = {
        autoImportCompletions = false,
      },
    },
  },
})

vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        -- Rust toolchain on Nix is in its own drv in the nix store. As
        -- a result, the default sub-path rust-analyzer looks for doesnt
        -- work, this works around this
        --
        -- Further, there are still errors when there's only cargo
        -- available
        sysrootSrc = "",
      },
    },
  },
})

vim.lsp.config("lua_ls", {
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

local servers = {
  "gopls",
  "ts_ls",
  "nixd",
  "pyright",
  "lua_ls",
  -- Not bundled in the nvim closure (see langs.{c,rust} = false); provided per
  -- project via devShell/direnv. vim.lsp silently skips a server whose cmd isn't
  -- on PATH, so enabling them here is a no-op outside a relevant project.
  "clangd",
  "rust_analyzer",
}
vim.lsp.enable(servers)

-- :LspStop / :LspStart / :LspRestart for the current buffer -- the modern
-- vim.lsp API ships none of them (nvim-lspconfig supplies them only when its
-- plugin loads). The approach is adapted from nvim-lspconfig's new-API commands
-- in plugin/lspconfig.lua (Apache-2.0):
--   https://github.com/neovim/nvim-lspconfig
-- Disabling a config gracefully detaches and shuts its clients down, and
-- (re-)enabling autostarts a fresh one. All async, no blocking wait; `!` on
-- stop/restart force-kills the clients instead of shutting them down gracefully.

-- Server names of the clients attached to the current buffer.
local function attached_servers()
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    names[client.name] = true
  end
  return names
end

-- Enabled servers configured for the current buffer's filetype -- how to start,
-- since with nothing attached there are no client names to read.
local function filetype_servers()
  local ft, matching = vim.bo.filetype, {}
  for _, name in ipairs(servers) do
    local cfg = vim.lsp.config[name]
    if cfg and cfg.filetypes and vim.tbl_contains(cfg.filetypes, ft) then
      matching[#matching + 1] = name
    end
  end
  return matching
end

-- Disable each named config (graceful detach + shutdown), force-killing the
-- clients too when `force`.
local function stop(names, force)
  for name in pairs(names) do
    vim.lsp.enable(name, false)
    if force then
      for _, client in ipairs(vim.lsp.get_clients({ name = name })) do
        client:stop(true)
      end
    end
  end
end

vim.api.nvim_create_user_command("LspStop", function(info)
  local names = attached_servers()
  if vim.tbl_isempty(names) then
    vim.notify("LspStop: no LSP client on this buffer", vim.log.levels.WARN)
    return
  end
  stop(names, info.bang)
end, { desc = "Stop the LSP clients on the current buffer", bang = true })

vim.api.nvim_create_user_command("LspStart", function()
  local matching = filetype_servers()
  if vim.tbl_isempty(matching) then
    vim.notify("LspStart: no server configured for this filetype", vim.log.levels.WARN)
    return
  end
  vim.lsp.enable(matching)
end, { desc = "Start the LSP servers for the current buffer" })

vim.api.nvim_create_user_command("LspRestart", function(info)
  local names = attached_servers()
  if vim.tbl_isempty(names) then
    vim.notify("LspRestart: no LSP client on this buffer", vim.log.levels.WARN)
    return
  end
  stop(names, info.bang)
  -- Re-enable off the loop, once the graceful shutdown has had time to land.
  local timer = assert(vim.uv.new_timer())
  timer:start(500, 0, function()
    timer:close()
    vim.schedule_wrap(vim.lsp.enable)(vim.tbl_keys(names))
  end)
end, { desc = "Restart the LSP clients on the current buffer", bang = true })

-- Buffer-local LSP keymaps. These MUST live in an LspAttach autocmd, not in an
-- `on_attach` on the "*" config: config merge (`:help lsp-config-merge`) uses
-- tbl_deep_extend("force"), and `on_attach` is a function, so a server-shipped
-- `lsp/<name>.lua` that defines its own `on_attach` (e.g. nvim-lspconfig's
-- pyright, which registers user commands) *replaces* the "*" one outright --
-- silently dropping these maps. LspAttach fires on every attach regardless.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local function set(mode, keys, fn)
      vim.keymap.set(mode, keys, fn, { buffer = args.buf, silent = true })
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
})

local symbol = (vim.env.TERM or ""):match("^linux") and "*" or "●"

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
