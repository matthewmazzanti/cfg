local cc = require("codecompanion")
local config = require("codecompanion.config")

---@diagnostic disable-next-line: undefined-field
cc.setup({
  adapters = {
    openai = function()
      local path = vim.fs.abspath("~/.local/share/openai/key")
      ---@diagnostic disable-next-line: undefined-field
      if not vim.uv.fs_stat(path) then
        error("Key file: "..path.." did not exist")
      end

      local api_key = nil
      for line in io.lines(path) do
        api_key = line
        break
      end

      return require("codecompanion.adapters").extend("openai", {
        env = {
          api_key = api_key
        },
      })
    end,
  },
  display = {
    diff = {
      enabled = true,
      provider = "mini_diff",
    },
    chat = {
      window = {
        layout = "float",
        height = 0.85,
        width = 0.85,
        row = math.floor(vim.o.lines * (1 - 0.85) * 0.35),
        col = math.floor(vim.o.columns * (1 - 0.85)  * 0.5),
        border = "rounded",
        opts = {
          conceallevel = 2,
          colorcolumn = "",
          textwidth = nil,
          number = false,
          relativenumber = false,
          signcolumn = "yes:1",
        }
      },
    }
  },
  strategies = {
    chat = { adapter = "openai" },
    inline = { adapter = "openai" },
    -- cmd = { adapter = "copilot" },
  },
  opts = {
    log_level = "DEBUG",
  },
})

vim.api.nvim_create_autocmd(
  "VimResized",
  {
    pattern = {"*"},
    callback = function()
      local window = config.config.display.chat.window;
      window.row = math.floor(vim.o.lines * (1 - 0.85) * 0.35)
      window.col = math.floor(vim.o.columns * (1 - 0.85)  * 0.5)
    end
  }
)

local diff = require("mini.diff")
diff.setup({
  source = diff.gen_source.none(),
  options = {
    algorithm = "patience"
  }
})

vim.keymap.set(
  { "n", "v" },
  "<C-a>",
  "<cmd>CodeCompanionActions<cr>",
  { noremap = true, silent = true }
)
vim.keymap.set(
  { "n", "v" },
  "<leader>a",
  "<cmd>CodeCompanionChat Toggle<cr>",
  { noremap = true, silent = true }
)
vim.keymap.set(
  "v",
  "ga",
  "<cmd>CodeCompanionChat Add<cr>",
  { noremap = true, silent = true }
)
vim.keymap.set(
  "n",
  "<leader>i",
  "<cmd>CodeCompanion<cr>",
  { noremap = true, silent = true }
)
vim.keymap.set(
  "v",
  "<leader>i",
  "<cmd>'<,'>CodeCompanion<cr>",
  { noremap = true, silent = true }
)
