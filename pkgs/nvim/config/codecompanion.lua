local cc = require("codecompanion")

cc.setup({
  display = {
    diff = {
      enabled = true,
      provider = "mini_diff",
    },
    chat = {
      window = {
        layout = "float",
        height = 0.85,
        width = 0.80,
        row = math.floor(vim.o.lines * (1 - 0.85) * 0.35),
        col = math.floor(vim.o.columns * (1 - 0.80)  * 0.5),
        border = "rounded",
      },
    }
  },
  strategies = {
    chat = { adapter = "copilot" },
    inline = { adapter = "copilot" },
    -- cmd = { adapter = "copilot" },
  },
})

vim.api.nvim_create_autocmd(
  "VimResized",
  {
    pattern = {"*"},
    callback = function(ev)
      vim.print(ev)
      local window = require("codecompanion.config").config.display.chat.window;
      window.row = math.floor(vim.o.lines * (1 - 0.85) * 0.35)
      window.col = math.floor(vim.o.columns * (1 - 0.80)  * 0.5)
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
