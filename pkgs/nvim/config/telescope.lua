-- PLUGIN: nvim-telescope
-- HOMEPAGE: https://github.com/nvim-telescope/telescope.nvim
local telescope = require("telescope")
local actions = require("telescope.actions")
local builtin = require("telescope.builtin")
local utils = require("telescope.utils")

telescope.setup({
    defaults = {
        layout_strategy = "vertical",
        layout_config = {
            vertical = {
                prompt_position = "top"
            }
        },
        sorting_strategy = "ascending",
        prompt_title = false,
        results_title = false,
        path_display = { "truncate" },
        mappings = {
            i = {
                ["<esc>"] = actions.close
            }
        }
    },
    pickers = {
        find_files = {
            find_command = {
                "fd",
                "--type", "f",
                "--hidden",
                "--exclude", ".git",
                "--strip-cwd-prefix"
            }
        }
    },
    extensions = {
        fzf = {
            override_file_sorter = true,
            override_generic_sorter = true
        }
    }
})

local function dir_files()
    return builtin.find_files({
        cwd = utils.buffer_dir(),
        prompt_title = "Local Files"
    })
end

local function spell()
    return builtin.spell_suggest({
        layout_strategy = "cursor",
        layout_config = {
            height = 10,
            width = 35,
        },
        prompt_title = "Spell",
        sorting_strategy = "ascending",
    })
end

vim.keymap.set("n", "<leader>f", builtin.find_files)
vim.keymap.set("n", "<leader>l", dir_files)
vim.keymap.set("n", "<leader>b", builtin.buffers)
vim.keymap.set("n", "<leader>j", builtin.jumplist)
vim.keymap.set("n", "<leader>g", builtin.live_grep)
vim.keymap.set("n", "z=", spell)

vim.api.nvim_set_hl(0, "TelescopeBorder", { link = "GruvboxGray" })
vim.api.nvim_set_hl(0, "TelescopePromptBorder", { link = "GruvboxGray" })
vim.api.nvim_set_hl(0, "TelescopeResultsBorder", { link = "GruvboxGray" })
vim.api.nvim_set_hl(0, "telescopepreviewborder", { link = "gruvboxgray" })

-- {
--     lsp = {
--         defs = builtin.lsp_definitions,
--         impls = builtin.lsp_implementations,
--         refs = builtin.lsp_references,
--         types = builtin.lsp_type_definitions,
--     }
-- }
