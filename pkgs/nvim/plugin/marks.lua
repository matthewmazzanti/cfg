-- Event-driven mark rendering for the sign column, with zero idle cost -- no
-- polling timer. Draws the a-z (buffer-local) and A-Z (global) marks. Rendering
-- is a plain loop over getmarklist(); the interesting part is knowing when to
-- re-run it:
--   * add / remove / re-set -> MarkSet   (fires for m, :mark, :delmarks, and API)
--   * line drift / reorder  -> on_lines  (gated to structural changes only)
--   * entering a buffer     -> BufEnter  (initial paint)
-- All funnel through one schedule-once reconcile, so a burst of triggers
-- collapses to a single redraw. We always re-derive from getmarklist rather than
-- trusting a placed extmark to track the mark: :sort keeps a-z marks at their
-- line numbers but shoves a generic extmark elsewhere, so the two desync without
-- a re-derive.
local M = {}

local ns = vim.api.nvim_create_namespace("marks_gutter")

-- Publicly settable styling -- set these on the module (before or after setup) to
-- restyle, e.g. require("utils.marks").number_hl_group = "CursorLineNr".
M.hl_group = "MarkGutter" -- sign glyph highlight group
M.number_hl_group = nil -- line-number highlight for marked lines (opt-in; nil = off)
M.priority = 10 -- sign priority

---@param buf integer
---@param name string mark letter
---@param lnum integer 1-based line
---@param line_count integer buffer line count
local function place(buf, name, lnum, line_count)
  if lnum < 1 or lnum > line_count then
    return -- mark left dangling past EOF by an edit; skip until it's back in range
  end
  vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
    sign_text = name,
    sign_hl_group = M.hl_group,
    number_hl_group = M.number_hl_group, -- nil unless opted in
    priority = M.priority,
  })
end

---@class marks.Mark
---@field name string letter (a-z buffer-local, A-Z global)
---@field lnum integer 1-based line
---@field col integer 0-based column
---@field global? boolean set for A-Z global marks pointing into the buffer

-- The letter marks relevant to `buf`: buffer-local a-z plus global A-Z that
-- point into buf. Columns are 0-based (for cursor APIs); rendering ignores them.
-- This is the single source the renderer and every handler enumerate from.
---@param buf integer
---@return marks.Mark[]
local function marks_for(buf)
  local out = {}
  for _, m in ipairs(vim.fn.getmarklist(buf)) do -- buffer-local a-z
    local name = m.mark:sub(2)
    if name:match("^%l$") then
      out[#out + 1] = { name = name, lnum = m.pos[2], col = math.max(0, m.pos[3] - 1) }
    end
  end
  for _, m in ipairs(vim.fn.getmarklist()) do -- global A-Z pointing into this buffer
    local name = m.mark:sub(2)
    if name:match("^%u$") and m.pos[1] == buf then
      out[#out + 1] = { name = name, lnum = m.pos[2], col = math.max(0, m.pos[3] - 1), global = true }
    end
  end
  return out
end

---@param buf integer
---@param mk marks.Mark
local function del(buf, mk)
  if mk.global then
    vim.api.nvim_del_mark(mk.name)
  else
    vim.api.nvim_buf_del_mark(buf, mk.name)
  end
end

---@param buf integer
local function reconcile(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(buf)
  for _, mk in ipairs(marks_for(buf)) do
    place(buf, mk.name, mk.lnum, line_count)
  end
end

-- Collapse a burst of triggers into a single reconcile on the next tick.
local pending = {}
---@param buf integer
local function schedule(buf)
  if pending[buf] then return end
  pending[buf] = true
  vim.schedule(function()
    pending[buf] = nil
    reconcile(buf)
  end)
end

-- Drift/reorder: attach a buffer-update listener that redraws on line-structure
-- changes only (see the on_lines gate below). Nvim already coalesces bulk edits,
-- so a :%s touching many lines fires on_lines once, not per line.
local attached = {}
---@param attach_buf integer
local function attach(attach_buf)
  if attached[attach_buf] then
    return
  end

  -- nvim_buf_attach fails on an unloaded buffer -- at launch the config is
  -- sourced before the argument file is read, so the current buffer isn't loaded
  -- yet. Only set the guard on success, so the BufReadPost/BufEnter that fires
  -- once the buffer *is* loaded gets to retry instead of being blocked.
  local ok = vim.api.nvim_buf_attach(attach_buf, false, {
    -- on_lines reports an old range [first, last) replaced by [first, new_last)
    -- (all 0-based). Redraw only on structural changes -- a differing line count
    -- (new_last ~= last) or a multi-line span (a reorder like :sort keeps the
    -- count but permutes lines). Skip single-line in-place edits so ordinary
    -- typing costs nothing. Examples (line numbers 0-based):
    --   type on line 4      first=4 last=5 new_last=5  span 1, no delta -> skip
    --   insert below line 4 first=5 last=5 new_last=6  delta            -> redraw
    --   delete line 4       first=4 last=5 new_last=4  delta            -> redraw
    --   :sort 6 lines       first=0 last=6 new_last=6  span 6, no delta -> redraw
    on_lines = function(_, buf, _, first, last, new_last)
      if new_last ~= last or (last - first) > 1 then
        schedule(buf)
      end
    end,
    on_reload = function(_, buf) -- whole buffer replaced
      schedule(buf)
    end,
    on_detach = function(_, buf)
      attached[buf] = nil
      pending[buf] = nil
    end,
  })
  if ok then
    attached[attach_buf] = true
  end
end

-- Install the render triggers. opts (all optional) seed the styling fields;
-- equivalently, set M.hl_group / M.number_hl_group / M.priority directly, before
-- or after setup -- the next repaint picks up whatever they currently hold.
--   hl_group         sign glyph highlight group (default "MarkGutter")
--   number_hl_group  line-number highlight for marked lines (default nil / off)
--   priority         sign priority (default 10)
---@class marks.Opts
---@field hl_group? string sign glyph highlight group
---@field number_hl_group? string line-number highlight for marked lines
---@field priority? integer sign priority
---@param opts? marks.Opts
function M.setup(opts)
  opts = opts or {}
  M.hl_group = opts.hl_group or M.hl_group
  M.number_hl_group = opts.number_hl_group or M.number_hl_group
  M.priority = opts.priority or M.priority

  -- Default sign highlight; `default = true` lets a colorscheme override the link.
  vim.api.nvim_set_hl(0, "MarkGutter", { link = "Identifier", default = true })

  -- Idempotent: a re-run (live :source) clears the group rather than stacking.
  local group = vim.api.nvim_create_augroup("marks", { clear = true })

  -- Add/remove/re-set: universal, so no need to remap m/dm to notice.
  vim.api.nvim_create_autocmd("MarkSet", {
    group = group,
    pattern = "*",
    callback = function(ev)
      schedule(ev.buf)
    end,
  })

  -- Attach + initial paint. BufReadPost/BufNewFile catch (re)loads -- a plain
  -- :edit detaches the buffer callbacks but doesn't fire BufEnter (you never
  -- left) -- and BufEnter catches buffer switches. attach() is guarded, so
  -- overlap is cheap.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufEnter" }, {
    group = group,
    callback = function(ev)
      attach(ev.buf)
      schedule(ev.buf)
    end,
  })

  -- Cover buffers already loaded when setup runs -- a live :source, or a
  -- restored session with several buffers open. (Args like `nvim foo bar baz`
  -- load only the first now; the rest are unloaded until visited, where
  -- BufEnter takes over.) attach()/schedule() are guarded, so revisiting these
  -- is cheap.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      attach(buf)
      schedule(buf)
    end
  end
end

-- Force an immediate repaint. nil repaints every loaded buffer; a buffer number
-- repaints just that one (0 = current buffer, per the usual convention --
-- getmarklist() won't accept a literal 0, so resolve it). Rendering is
-- event-driven, so this is only an escape hatch for changes that bypass the
-- tracked triggers.
---@param bufno? integer nil = every loaded buffer; 0 = current buffer
function M.render(bufno)
  if bufno == nil then
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        reconcile(buf)
      end
    end
    return
  end
  if bufno == 0 then
    bufno = vim.api.nvim_get_current_buf()
  end
  reconcile(bufno)
end

-- Handlers -- pure functions, no key mappings. Bind them in your own config.
-- Each mutates marks and lets the MarkSet-driven reconcile repaint (as toggle
-- does -- the set/del APIs fire MarkSet), then returns the mark name(s) affected
-- so a mapping can echo feedback if it wants. They act only on the current
-- buffer. Local vs global is implicit in the case: "a" is buffer-local, "A" is a
-- global mark pointing into this buffer.

-- Toggle a mark. Without `name`, reads it from the next keypress -- bind to `m`
-- for a toggling m{a-zA-Z}. If the mark already sits on the current line, remove
-- it; otherwise set (or move) it to the cursor.
---@param name? string mark letter; reads the next keypress if omitted
---@return string? name toggled mark, or nil if the read was cancelled/invalid
function M.toggle(name)
  if not name then
    -- pcall so <C-c> during the read (Vim:Interrupt) cancels cleanly.
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then return end
    name = ch
  end
  if not name:match("^%a$") then
    return
  end
  -- nvim_buf_* take 0 for the current buffer, and nvim_buf_get_mark is
  -- buffer-scoped: it returns { 0, 0 } when the mark isn't in this buffer (unset,
  -- or a global pointing elsewhere), so its row answers "is it on this line?".
  -- No explicit repaint anywhere: the set/del fires MarkSet, which reconciles.
  local row, col = unpack(vim.api.nvim_win_get_cursor(0)) -- row 1-based, col 0-based
  if vim.api.nvim_buf_get_mark(0, name)[1] ~= row then
    vim.api.nvim_buf_set_mark(0, name, row, col, {}) -- not here -> set (or move) it
    return name
  end

  -- Already on this line -> remove it. Global marks aren't tied to a buffer.
  if name:match("%u") then
    vim.api.nvim_del_mark(name)
  else
    vim.api.nvim_buf_del_mark(0, name)
  end
  return name
end

-- Delete a mark on the current buffer. Without `name`, reads the next keypress
-- to choose it. A no-op (returns nil) if the mark isn't set in this buffer, so a
-- global pointing elsewhere is left alone. Returns the name when it deletes.
---@param name? string mark letter; reads the next keypress if omitted
---@return string? name deleted mark, or nil if none matched in this buffer
function M.delete(name)
  if not name then
    -- pcall so <C-c> during the read (Vim:Interrupt) cancels cleanly.
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then return end
    name = ch
  end

  if not name:match("^%a$") then return end

  local buf = vim.api.nvim_get_current_buf()
  for _, mk in ipairs(marks_for(buf)) do
    if mk.name == name then
      del(buf, mk)
      return name
    end
  end
end

-- Delete every letter mark on the current line.
---@return string[] deleted names cleared from the line
function M.delete_line()
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.fn.line(".")
  local deleted = {}
  for _, mk in ipairs(marks_for(buf)) do
    if mk.lnum == lnum then
      del(buf, mk)
      deleted[#deleted + 1] = mk.name
    end
  end
  return deleted
end

-- Delete every letter mark in the buffer (a-z and any A-Z pointing here).
---@return string[] deleted names cleared from the buffer
function M.delete_buf()
  local buf = vim.api.nvim_get_current_buf()
  local deleted = {}
  for _, mk in ipairs(marks_for(buf)) do
    del(buf, mk)
    deleted[#deleted + 1] = mk.name
  end
  return deleted
end

-- Place the next unused a-z mark at the cursor. Returns nil if all are taken.
---@return string? name placed mark, or nil if a-z are all in use
function M.set_next()
  local buf = vim.api.nvim_get_current_buf()
  local used = {}
  for _, mk in ipairs(marks_for(buf)) do
    used[mk.name] = true
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0)) -- row 1-based, col 0-based
  for c = string.byte("a"), string.byte("z") do
    local name = string.char(c)
    if not used[name] then
      vim.api.nvim_buf_set_mark(buf, name, row, col, {})
      return name
    end
  end
end

---@class marks.JumpOpts
---@field wrap? boolean cycle past the last/first mark (default true)

-- Jump to the next/prev mark by file position. opts.wrap (default true) cycles
-- past the last/first mark. Jumps via the mark itself, so the jumplist updates.
---@param step integer 1 to go forward, -1 to go backward
---@param opts? marks.JumpOpts
---@return string? name mark jumped to, or nil if there are none
local function goto_mark(step, opts)
  local wrap = not (opts and opts.wrap == false)
  local buf = vim.api.nvim_get_current_buf()
  local marks = marks_for(buf)
  if #marks == 0 then
    return
  end

  -- Ascending file-order delta between two positions. Multiplying by `step` (+-1)
  -- flips the sign for prev, so one comparator drives both directions: sort into
  -- travel order, then the target is the first mark strictly past the cursor
  -- (treated as a pseudo-mark), wrapping to marks[1] -- always the travel-first.
  local function poscmp(a, b)
    if a.lnum ~= b.lnum then return a.lnum - b.lnum end
    return a.col - b.col
  end
  table.sort(marks, function(a, b) return step * poscmp(a, b) < 0 end)

  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0)) -- row 1-based, col 0-based
  local cursor = { lnum = crow, col = ccol }
  local target
  for _, mk in ipairs(marks) do
    if step * poscmp(cursor, mk) < 0 then
      target = mk
      break
    end
  end
  target = target or (wrap and marks[1] or nil)

  if not target then return end
  vim.cmd.normal({ "`" .. target.name, bang = true }) -- bang so it ignores mappings
  return target.name
end

---@param opts? marks.JumpOpts
---@return string? name mark jumped to, or nil if there are none
function M.next(opts)
  return goto_mark(1, opts)
end

---@param opts? marks.JumpOpts
---@return string? name mark jumped to, or nil if there are none
function M.prev(opts)
  return goto_mark(-1, opts)
end

return M
