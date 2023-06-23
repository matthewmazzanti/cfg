-- PLUGIN: gruvbox.nvim
-- HOMEPAGE: https://github.com/ellisonleao/gruvbox.nvim
-- Color theme
-- TODO: develop own nix script for color injection?

local gruvbox = require("gruvbox")

vim.opt.background = "dark"

gruvbox.setup({
    undercurl = true,
    underline = true,
    bold = false,
    italic = {
        strings = false,
        comments = false,
        operators = false,
        folds = false,
    },
    overrides = {
        SignColumn = { fg = "none", bg = "none" },
        GruvboxRedSign = { bg = "none" },
        GruvboxGreenSign = { bg = "none" },
        GruvboxYellowSign = { bg = "none" },
        GruvboxBlueSign = { bg = "none" },
        GruvboxPurpleSign = { bg = "none" },
        GruvboxAquaSign = { bg = "none" },
        GruvboxOrangeSign = { bg = "none" }
    }
})

vim.cmd("colorscheme gruvbox")
