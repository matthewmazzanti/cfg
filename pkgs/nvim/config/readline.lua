local readline = require("utils.readline")
vim.keymap.set("c", "<C-k>", readline.kill_line)
vim.keymap.set("c", "<C-u>", readline.backward_kill_line)
vim.keymap.set("c", "<M-d>", readline.kill_word)
vim.keymap.set("c", "<M-BS>", readline.backward_kill_word)
vim.keymap.set("c", "<C-w>", readline.unix_word_rubout)
vim.keymap.set("c", "<C-d>", "<Delete>")  -- delete-char
vim.keymap.set("c", "<C-h>", "<BS>")      -- backward-delete-char
vim.keymap.set("c", "<C-a>", readline.beginning_of_line)
vim.keymap.set("c", "<C-e>", readline.end_of_line)
vim.keymap.set("c", "<M-f>", readline.forward_word)
vim.keymap.set("c", "<M-b>", readline.backward_word)
vim.keymap.set("c", "<C-f>", "<Right>") -- forward-char
vim.keymap.set("c", "<C-b>", "<Left>")  -- backward-char
-- vim.keymap.set("c", "<C-n>", "<Down>")  -- next-line
-- vim.keymap.set("c", "<C-p>", "<Up>")    -- previous-line
