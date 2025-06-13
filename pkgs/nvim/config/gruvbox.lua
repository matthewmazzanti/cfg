-- PLUGIN: gruvbox.nvim
-- HOMEPAGE: https://github.com/ellisonleao/gruvbox.nvim
-- Color theme
-- TODO: develop own nix script for color injection?

local gruvbox = require("gruvbox")

vim.opt.background = "dark"

gruvbox.setup({
  undercurl = true,
  underline = true,
  bold = true,
  italic = {
    strings = false,
    comments = false,
    operators = false,
    folds = false,
  },
  overrides = {
    -- Make function calls not bold
    Function = { link = "GruvboxGreen" },
    -- Make SignColumn transparent (TODO: think this is built in now)
    SignColumn = { fg = "none", bg = "none" },
    GruvboxRedSign = { bg = "none" },
    GruvboxGreenSign = { bg = "none" },
    GruvboxYellowSign = { bg = "none" },
    GruvboxBlueSign = { bg = "none" },
    GruvboxPurpleSign = { bg = "none" },
    GruvboxAquaSign = { bg = "none" },
    GruvboxOrangeSign = { bg = "none" },
  },
})

vim.cmd("colorscheme gruvbox")

-- Set the floating border for LSP/default hover windows to normal background
-- gray
vim.api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })
vim.api.nvim_set_hl(0, "FloatBorder", { link = "GruvboxGray" })
vim.api.nvim_set_hl(0, "BlinkCmpMenu", { link = "Normal" })
vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder", { link = "GruvboxGray" })
