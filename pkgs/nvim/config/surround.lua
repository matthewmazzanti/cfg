vim.g.nvim_surround_no_mappings = true

require("nvim-surround").setup()

vim.keymap.set("n", "sa", "<Plug>(nvim-surround-normal)")
vim.keymap.set("n", "saa", "<Plug>(nvim-surround-normal-cur)")
vim.keymap.set("n", "sA", "<Plug>(nvim-surround-normal-line)")
vim.keymap.set("n", "sAA", "<Plug>(nvim-surround-normal-cur-line)")
vim.keymap.set("n", "sd", "<Plug>(nvim-surround-delete)")
vim.keymap.set("n", "sr", "<Plug>(nvim-surround-change)")
vim.keymap.set("n", "sR", "<Plug>(nvim-surround-change-line)")
vim.keymap.set("x", "sa", "<Plug>(nvim-surround-visual)")
vim.keymap.set("x", "sA", "<Plug>(nvim-surround-visual-line)")
