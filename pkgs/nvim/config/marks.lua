-- Sign-column marks. The event-driven rendering engine lives in
-- utils.render-marks; this file owns the appearance and wires it up.
vim.api.nvim_set_hl(0, "MarkGutter", { link = "Identifier", default = true })

require("utils.render-marks").setup({ hl_group = "MarkGutter" })
