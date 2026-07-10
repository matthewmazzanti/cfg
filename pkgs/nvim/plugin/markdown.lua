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
--
-- The work splits by which tool fits the question. Structure -- which list item
-- a settled line belongs to, and whether we're in a code block -- is read from
-- the tree the highlighter already maintains. The volatile current line is not:
-- a half-typed marker ("  -") parses as a setext heading, so it is classified
-- lexically. And when no tree exists yet (a cold buffer, pre-first-parse) the
-- tree lookups return nil and everything falls back to the lexical path.

local M = {}

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

-- Lexical fallback: content column of a list item line (indent + marker width),
-- or nil when the line is not a list item.
local function marker_end(line)
  local m = line:match("^%s*[-*+]%s+") or line:match("^%s*%d+[.)]%s+")
  return m and #m or nil
end

-- Is `lnum` inside a code block? Reads the highlighter's tree (get_node does not
-- parse -- see :h vim.treesitter.get_node()), so it is a cheap lookup. nil (no
-- tree yet) reads as "not in a block", the safe default.
local function in_code_block(lnum)
  local ok, node = pcall(vim.treesitter.get_node, { pos = { lnum - 1, 0 } })
  while ok and node do
    local t = node:type()
    if t == "fenced_code_block" or t == "indented_code_block" then return true end
    node = node:parent()
  end
  return false
end

-- The list item a settled line belongs to, from the tree. Querying at the
-- line's first non-blank column selects the innermost item at that depth and
-- resolves a continuation line back to its owning item (so a loose, blank-
-- separated nested item still dedents to the right column). Returns the item's
-- marker column (its indent, the dedent target) and content column (the hang),
-- or nil when there is no tree or the line is not in a list.
local function enclosing_item(row)
  local ok, node = pcall(vim.treesitter.get_node,
    { pos = { row, indent_of(vim.fn.getline(row + 1)) } })
  if not ok then return nil end
  while node and node:type() ~= "list_item" do node = node:parent() end
  if not node then return nil end
  local marker = node:child(0)
  if not marker then return nil end
  -- The marker's end column is the content column and is stable. Its start
  -- column is not: tree-sitter folds a top-level item's <=3 leading spaces into
  -- the marker node, so take the visual indent from the marker's own line.
  local marker_row, _, _, content_col = marker:range()
  return indent_of(vim.fn.getline(marker_row + 1)), content_col
end

function M.indentexpr()
  local lnum = vim.v.lnum
  if in_code_block(lnum) then return -1 end

  local cur = vim.fn.getline(lnum)

  -- Resolve the item we're working within from the previous settled line: it
  -- exists in the tree even though the just-edited current line may not.
  local prev = vim.fn.prevnonblank(lnum - 1)
  local marker_col, content_col
  if prev > 0 then marker_col, content_col = enclosing_item(prev - 1) end

  -- A marker being typed dedents to the enclosing item's marker column,
  -- starting a sibling.
  if typing_marker(cur) then
    if marker_col then return marker_col end
    -- Fallback: nearest lexical marker above, stopping when we leave the list.
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

  -- Otherwise this is a continuation line: hang under the item's content column.
  if content_col then return content_col end
  -- Fallback: a preceding lexical marker's content column, or its own indent.
  if prev > 0 then
    local pl = vim.fn.getline(prev)
    local me = marker_end(pl)
    if me then return me end
    if indent_of(pl) > 0 then return indent_of(pl) end
  end
  return -1
end

return M
