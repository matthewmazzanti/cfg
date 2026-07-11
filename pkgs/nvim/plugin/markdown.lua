-- List-aware indentation for markdown, driven through 'indentexpr' so it works
-- with the normal <CR>, the '=' operator, and o/O without remapping any keys.
--
-- Pressing <CR> inside a list item opens a continuation line indented under the
-- item's text (a hanging indent), so a long item wraps cleanly. Typing a list
-- marker (-, *, + or a number) on that fresh line instead drops the indent back
-- to the enclosing item's marker column, starting a new sibling item. Wire it
-- from an ftplugin with:
--
--   vim.opt_local.indentexpr = "v:lua.require'utils.markdown'.indentexpr()"
--   vim.opt_local.indentkeys = require("utils.markdown").indentkeys
--
-- The work splits by which tool fits the question. Structure -- which list item
-- a settled line belongs to, and whether we're in a code block -- is read from
-- the tree the highlighter already maintains. The volatile current line is not:
-- mid-edit it is a half-typed marker ("  -") the parser reads as a setext
-- heading, so the two reads of the current line stay lexical. This assumes an
-- active treesitter parser; there is no lexical fallback for a missing tree.

local M = {}

-- Keystrokes that should re-run indentexpr, to pair with M.indentexpr when
-- wiring the ftplugin (:h indentkeys, :h cinkeys-format):
--   o, O   -- opening a line below / above. `o` also gates the <CR> newline
--            indent, so it's what makes the hanging wrap fire on <CR>.
--   0-,0*,0+ and 00..09 -- the `0` prefix means "only when this is the first
--            non-blank char", so typing a list marker (-, *, + or a digit) at
--            the line start re-indents it -- the dedent to a sibling. Digits are
--            spelled out because indentkeys has no range syntax.
M.indentkeys = "o,O,0-,0*,0+,00,01,02,03,04,05,06,07,08,09"

-- Leading-whitespace width of a line.
local function indent_of(line)
  return #line:match("^%s*")
end

-- A list marker still being typed: the marker with no item text yet, so its
-- trailing space may be absent -- "-", "  *", "1", "1.", "2)" ...
local function typing_marker(line)
  return line:match("^%s*[-*+]%s*$") ~= nil
      or line:match("^%s*%d+[.)]?%s*$") ~= nil
end

-- Does the current line already start a finished list item? Used to leave such
-- a line's indent alone (e.g. under '='). A lexical read, for the same reason
-- as typing_marker: the tree cannot be trusted for the line being edited.
local function starts_item(line)
  return line:match("^%s*[-*+]%s+") ~= nil or line:match("^%s*%d+[.)]%s+") ~= nil
end

-- The list_item node a settled line belongs to, from the tree (get_node does
-- not parse -- see :h vim.treesitter.get_node() -- so this is a cheap lookup),
-- or nil when the line is not inside a list item. Querying at the line's first
-- non-blank column selects the innermost item at that depth and resolves a
-- continuation line back to its owning item (so a loose, blank-separated nested
-- item still resolves to the right one). A code block enclosing the line before
-- any list item wins -- a fence or indented block nested in a list is code, not
-- continuation -- so we walk outward and stop at whichever comes first.
local function enclosing_item_node(row)
  local ok, node = pcall(vim.treesitter.get_node,
    { pos = { row, indent_of(vim.fn.getline(row + 1)) } })
  if not ok then return nil end
  while node do
    local t = node:type()
    if t == "fenced_code_block" or t == "indented_code_block" then return nil end
    if t == "list_item" then return node end
    node = node:parent()
  end
  return nil
end

-- The enclosing item's marker column (its indent, the dedent target) and content
-- column (the hang), or nil when the line is not list continuation.
local function enclosing_item(row)
  local item = enclosing_item_node(row)
  if not item then return nil end
  local marker = item:child(0)
  if not marker then return nil end
  -- The marker's end column is the content column and is stable. Its start
  -- column is not: tree-sitter folds a top-level item's <=3 leading spaces into
  -- the marker node, so take the visual indent from the marker's line.
  local marker_row, _, _, content_col = marker:range()
  return indent_of(vim.fn.getline(marker_row + 1)), content_col
end

function M.indentexpr()
  local lnum = vim.v.lnum
  local cur = vim.fn.getline(lnum)

  -- Resolve the item we're continuing from the previous settled line: it exists
  -- in the tree even though the just-edited current line may not. A nil result
  -- means we're not in list continuation (prose, or code), so we leave the
  -- indent to the default -- there is no separate code-block gate.
  local prev = vim.fn.prevnonblank(lnum - 1)
  local marker_col, content_col
  if prev > 0 then marker_col, content_col = enclosing_item(prev - 1) end

  -- A marker being typed dedents to the enclosing item's marker column,
  -- starting a sibling. A line opened above a more-indented item (O on a nested
  -- item) belongs to that item below, not the shallower one above, so prefer
  -- whichever neighbour is deeper.
  if typing_marker(cur) then
    local next = vim.fn.nextnonblank(lnum + 1)
    local below = next > 0 and enclosing_item(next - 1) or nil
    if below and (not marker_col or below > marker_col) then return below end
    return marker_col or -1
  end

  -- A finished list item carries intentional nesting we can't second-guess
  -- (e.g. under '='), so leave its indent untouched.
  if starts_item(cur) then return -1 end

  -- Otherwise this is a continuation line: hang under the item's content column.
  return content_col or -1
end

-- Toggle a GFM task checkbox on the list item under the cursor: a task item
-- ("- [ ] x") flips its state, [ ] <-> [x], and a plain item ("- x") gains an
-- unchecked box. A line outside any list item is left alone. Everything routes
-- through the enclosing list_item, so the cursor may sit on the marker line or
-- any of the item's wrapped/continuation lines, every marker (-, *, +, ordered)
-- and nesting depth is handled uniformly, and only the checkbox characters are
-- ever written -- the marker and its box always live on the item's first line.
-- Bound buffer-locally from the markdown ftplugin.
function M.toggle_check()
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local item = enclosing_item_node(row)
  if not item then return end

  -- A task item carries a checkbox node right after its marker; flip it.
  for child in item:iter_children() do
    local t = child:type()
    if t == "task_list_marker_checked" or t == "task_list_marker_unchecked" then
      local sr, sc, er, ec = child:range()
      local box = t == "task_list_marker_checked" and "[ ]" or "[x]"
      vim.api.nvim_buf_set_text(buf, sr, sc, er, ec, { box })
      return
    end
  end

  -- A plain item: insert an unchecked box at the marker's (stable) content
  -- column, on the marker's own line.
  local marker = item:child(0)
  if not marker then return end
  local marker_row, _, _, content_col = marker:range()
  vim.api.nvim_buf_set_text(buf, marker_row, content_col, marker_row, content_col,
    { "[ ] " })
end

return M
