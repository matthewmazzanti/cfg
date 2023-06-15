-- GENERAL CONFIG --

-- Show numbers on each line next to text. Relative numbers for jumps
-- relativenumber may be a bit heavy on low-power systems
vim.opt.number = true
vim.opt.relativenumber = true

-- Movement stuff
-- Allow for mouse
vim.opt.mouse = "a"
-- Increase speed of mouse scrolling
vim.keymap.set({"n", "v", "i"}, "<ScrollWheelUp>", "5<C-Y>", { silent = true })
vim.keymap.set({ "n", "v", "i" }, "<ScrollWheelDown>", "5<C-E>", { silent = true })
-- Remember cursor position during buffer switch
vim.opt.startofline = false
-- TODO: This still needed?
vim.opt.backspace = {"indent", "eol", "start"}


-- Line wrapping
vim.opt.colorcolumn = "81"
vim.opt.textwidth = 80
-- May be more options to explore here
vim.opt.formatoptions = table.concat({
    "c", -- Auto wrap comments
    "r", -- Add comment leader on <CR> in insert mode
    "o", -- Add comment leader when hitting "O" or "o"
    "j", -- Remove comment leader when joining lines
    "q", -- Format comments with gq
    "l", -- Don't format long lines by default
}, "")
vim.opt.linebreak = true
vim.opt.wrap = false


-- Indentation stuff
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

vim.opt.smarttab = true
vim.opt.autoindent = true
vim.opt.smartindent = true

-- Incremental search and better caps handling
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Nice visualization of trailing space/tabs
vim.opt.list = true
vim.opt.listchars = {
    tab = "» ",
    extends = "›",
    precedes = "‹",
    nbsp = "␣",
    trail = "•",
}

-- Persistent undo
vim.opt.undofile = true

-- Auto-read changed files
vim.opt.autoread = true

-- Always show sign column for marks, errors
vim.opt.signcolumn = "yes"

-- Ignore insert completion messages
vim.opt.shortmess:append("c")

-- Set leader key for other commands
vim.g.mapleader = ";"

-- Reset search highlighing
vim.keymap.set("n", "<leader>n", function()
    vim.cmd("nohlsearch")
end)

-- Copy to system clipboard where available
vim.opt.clipboard = "unnamedplus"

vim.filetype.add({
    filename = {
        [".envrc"] = "sh",
    },
    pattern = {
        ["*.conf"] = "conf",
    },
})

vim.cmd("clearjumps")
