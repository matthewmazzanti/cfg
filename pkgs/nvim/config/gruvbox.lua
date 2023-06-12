-- PLUGIN: gruvbox.nvim
-- HOMEPAGE: https://github.com/ellisonleao/gruvbox.nvim
-- Color theme
-- TODO: develop own nix script for color injection?

require("gruvbox").setup({
  undercurl = true,
  underline = true,
  bold = false,
  italic = {
    strings = false,
    comments = false,
    operators = false,
    folds = false,
  },
})

vim.opt.background = "dark"
vim.cmd("colorscheme gruvbox")
vim.api.nvim_set_hl(0, "SignColumn", { ctermfg = "none", ctermbg = "none" })
