-- Sign-column marks, rendered by the event-driven engine in utils.render-marks
-- (which installs the default MarkGutter highlight; re-link it to restyle).
local marks = require("utils.render-marks")
marks.setup()

-- Handlers live on the module; bind them here to taste. Selectors default to the
-- current buffer, and a `dm`/`m`-prefixed lhs makes Vim pause after `d`/`m`.
-- vim.keymap.set("n", "dm", function()
--   local name = marks.prompt()
--   if name then marks.delete({ names = name }) end
-- end, { desc = "marks: delete (prompts for one)" })
-- vim.keymap.set("n", "dm-", function() marks.delete({ line = vim.fn.line(".") }) end, { desc = "marks: delete on line" })
-- vim.keymap.set("n", "dm<Space>", function() marks.delete() end, { desc = "marks: delete all in buffer" })
-- vim.keymap.set("n", "m,", marks.set_next, { desc = "marks: set next unused a-z" })
-- vim.keymap.set("n", "m;", marks.toggle, { desc = "marks: toggle on line" })
-- vim.keymap.set("n", "]m", marks.next, { desc = "marks: next" })
-- vim.keymap.set("n", "[m", marks.prev, { desc = "marks: prev" })
