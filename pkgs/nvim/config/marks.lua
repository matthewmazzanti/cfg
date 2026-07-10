-- Sign-column marks, rendered by the event-driven engine in utils.render-marks
-- (which installs the default MarkGutter highlight; re-link it to restyle).
local marks = require("utils.render-marks")
marks.setup()

-- Styling is settable on the module (or via marks.setup({ ... })). Opt into
-- highlighting the marked line's number by pointing number_hl_group at a group:
-- marks.number_hl_group = "CursorLineNr"

-- Make `m{a-zA-Z}` a toggle: set the mark, or remove it if it's already on the
-- line. Replaces native `m` (plain set); `` ` ``/`'` jumps are unchanged.
vim.keymap.set("n", "m", marks.toggle, { desc = "marks: toggle m{a-zA-Z}" })
