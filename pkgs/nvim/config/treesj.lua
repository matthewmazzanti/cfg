-- PLUGIN: TreeSJ -- Splitting for list-like structures
-- HOMEPAGE: https://github.com/Wansmer/treesj
local treesj = require("treesj")

treesj.setup({
    use_default_keymaps = false,
})

vim.keymap.set("n", "<leader>s", treesj.toggle)
vim.keymap.set("n", "<leader>S", function()
    treesj.toggle({ split = { recursive = true } })
end)
