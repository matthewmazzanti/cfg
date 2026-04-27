-- PLUGIN: Treesitter - better syntax highlighting for most languages
-- HOMEPAGE: https://github.com/nvim-treesitter/nvim-treesitter
local nvim_treesitter = require("nvim-treesitter")
nvim_treesitter.setup()

-- Start highlighting if a parser exists; don't blow up if it doesn't.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    pcall(vim.treesitter.start)
    if vim.bo.filetype == "markdown" then return end
    vim.bo.indentexpr = 'v:lua.require("nvim-treesitter").indentexpr()'
  end,
})

-- PLUGIN: nvim-treesitter-textobjects
-- HOMEPAGE: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    include_surrounding_whitespace = false,
  }
})

local textobjects_select = require("nvim-treesitter-textobjects.select")
local mappings = {
  af = "@function.outer",
  ["if"] = "@function.inner",
  aC = "@class.outer",
  iC = "@class.inner",
  ac = "@comment.outer",
  ic = "@comment.inner",
}

for keys, query in pairs(mappings) do
  vim.keymap.set({ "x", "o" }, keys, function()
    textobjects_select.select_textobject(query, "textobjects")
  end)
end

-- PLUGIN: nvim-ts-autotag -- Auto close tags intelligently in different
-- filetypes
-- HOMEPAGE: https://github.com/windwp/nvim-ts-autotag
require("nvim-ts-autotag").setup()

-- PLUGIN: TreeSJ -- Splitting for list-like structures
-- HOMEPAGE: https://github.com/Wansmer/treesj
local treesj = require("treesj")
treesj.setup({
  use_default_keymaps = false,
  max_join_length = 500,
})

vim.keymap.set("n", "<leader>s", treesj.toggle)
vim.keymap.set("n", "<leader>S", function()
  treesj.toggle({ split = { recursive = true } })
end)
