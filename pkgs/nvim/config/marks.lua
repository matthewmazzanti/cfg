-- Sign-column marks, rendered by the event-driven engine in utils.render-marks
-- (which installs the default MarkGutter highlight; re-link it to restyle).
local marks = require("utils.render-marks")
marks.setup()

-- Mark-manipulation handlers, bound here rather than in the plugin. Uncomment /
-- adjust to taste. Note a `dm`/`m`-prefixed lhs makes Vim wait after `d`/`m`
-- before running the operator, so pick keys you're happy to pause on.
-- vim.keymap.set("n", "dm", marks.delete, { desc = "marks: delete (prompts for one)" })
-- vim.keymap.set("n", "dm-", marks.delete_line, { desc = "marks: delete on line" })
-- vim.keymap.set("n", "dm<Space>", marks.delete_buf, { desc = "marks: delete all in buffer" })
-- vim.keymap.set("n", "m,", marks.set_next, { desc = "marks: set next unused a-z" })
-- vim.keymap.set("n", "m;", marks.toggle, { desc = "marks: toggle on line" })
-- vim.keymap.set("n", "]m", marks.next, { desc = "marks: next" })
-- vim.keymap.set("n", "[m", marks.prev, { desc = "marks: prev" })
