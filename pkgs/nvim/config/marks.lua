-- Sign-column marks. The event-driven rendering engine lives in
-- utils.render-marks; this file owns the appearance and wires it up.
-- MarkGutter colors the sign glyph; MarkGutterNr colors the marked line's
-- number (linked to CursorLineNr, so the number lights up like the cursor line).
vim.api.nvim_set_hl(0, "MarkGutter", { link = "Identifier", default = true })
vim.api.nvim_set_hl(0, "MarkGutterNr", { link = "CursorLineNr", default = true })

require("utils.render-marks").setup({
  hl_group = "MarkGutter",
  number_hl_group = "MarkGutterNr",
})
