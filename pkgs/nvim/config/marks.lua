-- Sign-column marks, rendered by the event-driven engine in utils.marks
-- (which installs the default MarkGutter highlight; re-link it to restyle).
local marks = require("utils.marks")
marks.setup()

-- Styling is settable on the module (or via marks.setup({ ... })). Opt into
-- highlighting the marked line's number by pointing number_hl_group at a group:
-- marks.number_hl_group = "CursorLineNr"

-- One mapping on `m` that reads the next key and dispatches, composing
-- marks.nvim's whole `m`-prefix set under a single map. A lone `m` map (not `m`
-- plus separate `m]`/`m[`/`m,` maps) means no `timeoutlen` wait to disambiguate:
--   m{a-zA-Z}  toggle that mark (set/move, or remove if already on the line)
--   m] / m[    jump to next / prev mark
--   m,         set the next unused a-z mark at the cursor
-- Replaces native `m` (plain set); `` ` ``/`'` jumps are unchanged.
vim.keymap.set("n", "m", function()
  local ok, ch = pcall(vim.fn.getcharstr) -- pcall so <C-c> cancels cleanly
  if not ok then
    return
  end
  if ch == "]" then
    marks.next()
  elseif ch == "[" then
    marks.prev()
  elseif ch == "," then
    marks.set_next()
  else
    marks.toggle(ch)
  end
end, { desc = "marks: m{a-zA-Z} toggle, m]/m[ jump, m, set_next" })

-- Deletes, mirroring marks.nvim: `dm` prompts for the mark (its `dm{a-z}`),
-- `dm-`/`dm<Space>` clear the line/buffer. The `d` prefix keeps these clear of
-- the `m` map above.
vim.keymap.set("n", "dm", marks.delete, { desc = "marks: delete (prompts for one)" })
vim.keymap.set("n", "dm-", marks.delete_line, { desc = "marks: delete all on line" })
vim.keymap.set("n", "dm<Space>", marks.delete_buf, { desc = "marks: delete all in buffer" })
