-- PLUGIN: render-markdown.nvim
-- HOMEPAGE: https://github.com/MeanderingProgrammer/render-markdown.nvim

-- Rainbow heading colors (render mode)
vim.api.nvim_set_hl(0, "RenderMarkdownH1", { link = "GruvboxRedBold" })
vim.api.nvim_set_hl(0, "RenderMarkdownH2", { link = "GruvboxOrangeBold" })
vim.api.nvim_set_hl(0, "RenderMarkdownH3", { link = "GruvboxYellowBold" })
vim.api.nvim_set_hl(0, "RenderMarkdownH4", { link = "GruvboxGreenBold" })
vim.api.nvim_set_hl(0, "RenderMarkdownH5", { link = "GruvboxAquaBold" })
vim.api.nvim_set_hl(0, "RenderMarkdownH6", { link = "GruvboxPurpleBold" })

-- Rainbow heading colors (edit mode via treesitter)
vim.api.nvim_set_hl(0, "@markup.heading.1.markdown", { link = "GruvboxRedBold" })
vim.api.nvim_set_hl(0, "@markup.heading.2.markdown", { link = "GruvboxOrangeBold" })
vim.api.nvim_set_hl(0, "@markup.heading.3.markdown", { link = "GruvboxYellowBold" })
vim.api.nvim_set_hl(0, "@markup.heading.4.markdown", { link = "GruvboxGreenBold" })
vim.api.nvim_set_hl(0, "@markup.heading.5.markdown", { link = "GruvboxAquaBold" })
vim.api.nvim_set_hl(0, "@markup.heading.6.markdown", { link = "GruvboxPurpleBold" })

-- Code blocks
local palette = require("gruvbox").palette
vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = palette.dark0_soft })
vim.api.nvim_set_hl(0, "RenderMarkdownCodeLanguage", { fg = palette.gray, bg = palette.dark0_soft })

-- Override heading backgrounds (defaults use Diff* which looks odd)
vim.api.nvim_set_hl(0, "RenderMarkdownH1Bg", { link = "GruvboxRedSign" })
vim.api.nvim_set_hl(0, "RenderMarkdownH2Bg", { link = "GruvboxOrangeSign" })
vim.api.nvim_set_hl(0, "RenderMarkdownH3Bg", { link = "GruvboxYellowSign" })
vim.api.nvim_set_hl(0, "RenderMarkdownH4Bg", { link = "GruvboxGreenSign" })
vim.api.nvim_set_hl(0, "RenderMarkdownH5Bg", { link = "GruvboxAquaSign" })
vim.api.nvim_set_hl(0, "RenderMarkdownH6Bg", { link = "GruvboxPurpleSign" })

require("render-markdown").setup({
  debounce = 50,
  sign = { enabled = false },
  heading = {
    position = "inline",
    icons = { "| ", "| ", "| ", "| ", "| ", "| " },
  },
  code = {
    border = "thick",
    highlight_language = "RenderMarkdownCodeLanguage",
  },
})
