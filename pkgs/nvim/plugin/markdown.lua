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
--   vim.opt_local.indentkeys = "o,O,0-,0*,0+,00,01,02,03,04,05,06,07,08,09"

local M = {}

-- Content column of a list item line (indent + marker width), or nil when the
-- line is not a list item. Handles unordered (-, *, +) and ordered (1. / 1)).
local function marker_end(line)
  local m = line:match("^%s*[-*+]%s+") or line:match("^%s*%d+[.)]%s+")
  return m and #m or nil
end

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

function M.indentexpr()
  local lnum = vim.v.lnum

  -- Inside a code block a marker is just text: defer to the default indent
  -- rather than reflowing the line as a list. We read the tree the active
  -- highlighter already maintains (get_node does not parse -- see :h
  -- vim.treesitter.get_node()), so this is a cheap lookup, not a reparse. If no
  -- tree is available yet the node is nil and we fall through to the list logic
  -- -- a safe default, since the worst case is list-indenting a line in a fence.
  local ok, node = pcall(vim.treesitter.get_node, { pos = { lnum - 1, 0 } })
  while ok and node do
    local t = node:type()
    if t == "fenced_code_block" or t == "indented_code_block" then
      return -1
    end
    node = node:parent()
  end

  local cur = vim.fn.getline(lnum)

  -- A marker being typed on a hanging-indent line dedents to the enclosing
  -- item's marker column, starting a sibling. Scan up past continuation lines,
  -- stopping once we leave the list (a blank line or top-level text).
  if typing_marker(cur) then
    for r = lnum - 1, 1, -1 do
      local l = vim.fn.getline(r)
      if marker_end(l) then return indent_of(l) end
      if l:match("^%s*$") or indent_of(l) == 0 then break end
    end
    return -1
  end

  -- A finished list item carries intentional nesting we can't second-guess
  -- (e.g. under '='), so leave its indent untouched.
  if marker_end(cur) then return -1 end

  -- Otherwise this is a continuation line: hang under the item above. Match a
  -- preceding continuation's indent, or the item's content column.
  local prev = vim.fn.prevnonblank(lnum - 1)
  if prev == 0 then return -1 end
  local pl = vim.fn.getline(prev)
  local me = marker_end(pl)
  if me then return me end
  if indent_of(pl) > 0 then return indent_of(pl) end
  return -1
end

return M
