-- PLUGIN: lualine
-- HOMEPAGE: https://github.com/nvim-lualine/lualine.nvim
local lualine = require("lualine")

lualine.setup({
    options = {
        icons_enabled = false,
        component_separators = {
            left = "",
            right = ""
        },
        section_separators = {
            left = "",
            right = ""
        },
        globalstatus = true
    },
    sections = {
        lualine_a = {"mode"},
        lualine_b = {"branch", "diagnostics"},
        lualine_c = {"filename"},
        lualine_x = {"filetype"},
        lualine_y = {},
        lualine_z = {"location"}
    }
})

-- Don't show mode in command window
vim.opt.showmode = false
