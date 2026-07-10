-- Sign-column marks, rendered by the event-driven engine in utils.render-marks
-- (which installs the default MarkGutter highlight; re-link it to restyle).
local marks = require("utils.render-marks")
marks.setup()

-- Make `m{a-zA-Z}` a toggle: set the mark, or remove it if it's already on the
-- line. Replaces native `m` (plain set); `` ` ``/`'` jumps are unchanged.
vim.keymap.set("n", "m", marks.toggle, { desc = "marks: toggle m{a-zA-Z}" })
