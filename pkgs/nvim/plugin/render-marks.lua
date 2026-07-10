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
local hl_group = "MarkGutter"
local priority = 10

local function place(buf, name, lnum, line_count)
  if lnum < 1 or lnum > line_count then
    return -- mark left dangling past EOF by an edit; skip until it's back in range
  end
  vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
    sign_text = name,
    sign_hl_group = hl_group,
    priority = priority,
  })
end

-- The letter marks relevant to `buf`: buffer-local a-z plus global A-Z that
-- point into buf. Columns are 0-based (for cursor APIs); rendering ignores them.
-- This is the single source the renderer and every handler enumerate from.
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

local function del(buf, mk)
  if mk.global then
    vim.api.nvim_del_mark(mk.name)
  else
    vim.api.nvim_buf_del_mark(buf, mk.name)
  end
end

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

-- opts:
--   hl_group  sign glyph highlight group (default "MarkGutter")
--   priority  sign priority (default 10)
function M.setup(opts)
  opts = opts or {}
  hl_group = opts.hl_group or hl_group
  priority = opts.priority or priority

  -- Default sign highlight; `default = true` lets a colorscheme override the link.
  vim.api.nvim_set_hl(0, "MarkGutter", { link = "Identifier", default = true })

  -- Idempotent: a re-run (live :source) clears the group rather than stacking.
  local group = vim.api.nvim_create_augroup("render_marks", { clear = true })

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
-- Each mutates marks then repaints synchronously (MarkSet would repaint too, but
-- an explicit reconcile keeps them self-contained). They return the mark
-- name(s) affected, so a mapping can echo feedback if it wants.

-- Delete a mark. Without `name`, reads the next keypress to choose it.
function M.delete(name)
  name = name or vim.fn.getcharstr()
  if not name:match("^%a$") then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  del(buf, { name = name, global = name:match("%u") ~= nil })
  reconcile(buf)
  return name
end

-- Delete every letter mark on the current line.
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
  reconcile(buf)
  return deleted
end

-- Delete every letter mark in the buffer (a-z and any A-Z pointing here).
function M.delete_buf()
  local buf = vim.api.nvim_get_current_buf()
  local deleted = {}
  for _, mk in ipairs(marks_for(buf)) do
    del(buf, mk)
    deleted[#deleted + 1] = mk.name
  end
  reconcile(buf)
  return deleted
end

-- Place the next unused a-z mark at the cursor. Returns nil if all are taken.
function M.set_next()
  local buf = vim.api.nvim_get_current_buf()
  local used = {}
  for _, mk in ipairs(marks_for(buf)) do
    used[mk.name] = true
  end
  local cur = vim.api.nvim_win_get_cursor(0) -- { row (1-based), col (0-based) }
  for c = string.byte("a"), string.byte("z") do
    local name = string.char(c)
    if not used[name] then
      vim.api.nvim_buf_set_mark(buf, name, cur[1], cur[2], {})
      reconcile(buf)
      return name
    end
  end
end

-- If the current line has any letter mark, clear the line; else place the next.
function M.toggle()
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.fn.line(".")
  for _, mk in ipairs(marks_for(buf)) do
    if mk.lnum == lnum then
      return M.delete_line()
    end
  end
  return M.set_next()
end

-- Jump to the next/prev mark by file position. opts.wrap (default true) cycles
-- past the last/first mark. Jumps via the mark itself, so the jumplist updates.
local function goto_mark(step, opts)
  local wrap = not (opts and opts.wrap == false)
  local buf = vim.api.nvim_get_current_buf()
  local marks = marks_for(buf)
  if #marks == 0 then
    return
  end
  table.sort(marks, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)
  local cur = vim.api.nvim_win_get_cursor(0)
  local crow, ccol = cur[1], cur[2]
  local target
  if step > 0 then
    for _, mk in ipairs(marks) do
      if mk.lnum > crow or (mk.lnum == crow and mk.col > ccol) then
        target = mk
        break
      end
    end
    target = target or (wrap and marks[1] or nil)
  else
    for i = #marks, 1, -1 do
      local mk = marks[i]
      if mk.lnum < crow or (mk.lnum == crow and mk.col < ccol) then
        target = mk
        break
      end
    end
    target = target or (wrap and marks[#marks] or nil)
  end
  if target then
    vim.cmd("normal! `" .. target.name)
    return target.name
  end
end

function M.next(opts)
  return goto_mark(1, opts)
end

function M.prev(opts)
  return goto_mark(-1, opts)
end

return M
