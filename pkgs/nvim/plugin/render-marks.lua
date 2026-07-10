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
-- restyle, e.g. require("utils.render-marks").number_hl_group = "CursorLineNr".
M.hl_group = "MarkGutter" -- sign glyph highlight group
M.number_hl_group = nil -- line-number highlight for marked lines (opt-in; nil = off)
M.priority = 10 -- sign priority

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

local function reconcile(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(buf)
  for _, m in ipairs(vim.fn.getmarklist(buf)) do -- buffer-local a-z
    local name = m.mark:sub(2)
    if name:match("^%l$") then
      place(buf, name, m.pos[2], line_count)
    end
  end
  for _, m in ipairs(vim.fn.getmarklist()) do -- global A-Z pointing into this buffer
    local name = m.mark:sub(2)
    if name:match("^%u$") and m.pos[1] == buf then
      place(buf, name, m.pos[2], line_count)
    end
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

-- Install the render triggers. opts (all optional) seed the styling fields;
-- equivalently, set M.hl_group / M.number_hl_group / M.priority directly, before
-- or after setup -- the next repaint picks up whatever they currently hold.
--   hl_group         sign glyph highlight group (default "MarkGutter")
--   number_hl_group  line-number highlight for marked lines (default nil / off)
--   priority         sign priority (default 10)
function M.setup(opts)
  opts = opts or {}
  M.hl_group = opts.hl_group or M.hl_group
  M.number_hl_group = opts.number_hl_group or M.number_hl_group
  M.priority = opts.priority or M.priority

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

-- Toggle a mark, reading its name from the next keypress -- bind to `m` for a
-- toggling m{a-zA-Z}. If the mark already sits on the current line, remove it;
-- otherwise set (or move) it to the cursor. Local vs global is implicit in the
-- case: "a" is buffer-local, "A" is a global mark.
--
-- The fuller selection/manipulation API -- list/delete/set by a { buf, line,
-- names } selector, set_next, jump/next/prev -- is deferred; see todo.md.
function M.toggle()
  -- pcall so <C-c> during the read (Vim:Interrupt) cancels cleanly.
  local ok, name = pcall(vim.fn.getcharstr)
  if not ok or not name:match("^%a$") then
    return
  end
  -- nvim_buf_* take 0 for the current buffer, and nvim_buf_get_mark is
  -- buffer-scoped: it returns { 0, 0 } when the mark isn't in this buffer (unset,
  -- or a global pointing elsewhere), so its row answers "is it on this line?".
  -- No explicit repaint anywhere: the set/del fires MarkSet, which reconciles.
  local cur = vim.api.nvim_win_get_cursor(0) -- { row (1-based), col (0-based) }
  if vim.api.nvim_buf_get_mark(0, name)[1] ~= cur[1] then
    vim.api.nvim_buf_set_mark(0, name, cur[1], cur[2], {}) -- not here -> set (or move) it
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

return M
