-- Native statusline and tabline, replacing lualine. Inlined into this config file rather
-- than a utils module: render() and on_click() are exposed as globals
-- (StatuslineRender / StatuslineClick) so the 'statusline' `%!` expression and
-- the `%@..@` click labels can reach them via v:lua. A dofile'd config file
-- isn't on the Lua module path, so globals stand in for a require.
--
-- The statusline is redraw-driven, not event-subscribed: render() is called by
-- Neovim's redraw cycle (mode change, cursor move, win/buf switch, ...), so the
-- mode segment and location update on their own. render() therefore must stay
-- cheap -- every field here is O(1). Highlights are (re)derived from the active
-- gruvbox groups on ColorScheme.

--- Foreground color of a highlight group, or a fallback. Used for diagnostic
--- colors so they track the theme's Diagnostic* groups, as lualine did.
local function hl_fg(name, fallback)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and h and h.fg then
    return h.fg
  end
  return fallback
end

-- Reproduce lualine's bundled gruvbox_dark palette by mapping onto gruvbox.nvim's
-- own palette (its source of truth), rather than duplicating hexes. lualine's
-- names don't match gruvbox's: its "yellow" is gruvbox bright_orange, its "gray"
-- is light4, etc. -- so we map deliberately, not by name. Dark-mapped to match
-- our fixed `background = "dark"`. Fallbacks keep it working if the require fails.
local function palette()
  local ok, g = pcall(function()
    return require("gruvbox").palette
  end)
  g = (ok and g) or {}
  local function c(key, fallback)
    return g[key] or fallback
  end
  return {
    black = c("dark0", "#282828"),
    white = c("light1", "#ebdbb2"),
    red = c("bright_red", "#fb4934"),
    green = c("bright_green", "#b8bb26"),
    blue = c("bright_blue", "#83a598"),
    yellow = c("bright_orange", "#fe8019"), -- lualine's visual-mode accent
    gray = c("light4", "#a89984"),
    darkgray = c("dark1", "#3c3836"),
    lightgray = c("dark2", "#504945"),
  }
end

-- lualine section -> our groups:
--   a (mode) / z (location): accent bg, black fg, bold
--   b (branch, diagnostics): white on lightgray
--   c (filename) / x (filetype): gray on darkgray
local function setup_highlights()
  local p = palette()
  local set = vim.api.nvim_set_hl
  set(0, "StModeNormal", { fg = p.black, bg = p.gray, bold = true })
  set(0, "StModeInsert", { fg = p.black, bg = p.blue, bold = true })
  set(0, "StModeVisual", { fg = p.black, bg = p.yellow, bold = true })
  set(0, "StModeReplace", { fg = p.black, bg = p.red, bold = true })
  set(0, "StModeCommand", { fg = p.black, bg = p.green, bold = true })
  -- lualine has no terminal theme key, so it falls terminal back to normal.
  set(0, "StModeTerminal", { fg = p.black, bg = p.gray, bold = true })

  set(0, "StSection", { fg = p.white, bg = p.lightgray }) -- b: branch + diagnostics base
  set(0, "StFile", { fg = p.gray, bg = p.darkgray }) -- c/x: filename + filetype

  -- Diagnostics track the theme's Diagnostic* groups on the b-section bg.
  set(0, "StDiagError", { fg = hl_fg("DiagnosticError", 0xfb4934), bg = p.lightgray })
  set(0, "StDiagWarn", { fg = hl_fg("DiagnosticWarn", 0xfabd2f), bg = p.lightgray })
  set(0, "StDiagInfo", { fg = hl_fg("DiagnosticInfo", 0x83a598), bg = p.lightgray })
  set(0, "StDiagHint", { fg = hl_fg("DiagnosticHint", 0x8ec07c), bg = p.lightgray })

  -- Tabline: the active tab reuses the statusline's mode-block groups (StMode*),
  -- so it wears the current mode's accent; inactive tabs dim like the file section;
  -- empty fill on the editor bg -- darker than the tabs, so they read as distinct
  -- blocks.
  set(0, "StTab", { fg = p.gray, bg = p.darkgray })
  set(0, "StTabFill", { bg = p.black })
end

-- Display name per mode code (from nvim_get_mode().mode, which can be
-- multi-char). Falls back to first-char lookup, then uppercase.
local mode_names = {
  n = "NORMAL", no = "O-PENDING", niI = "NORMAL", niR = "NORMAL", niV = "NORMAL", nt = "NORMAL",
  v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
  s = "SELECT", S = "S-LINE", ["\19"] = "S-BLOCK",
  i = "INSERT", ic = "INSERT", ix = "INSERT",
  R = "REPLACE", Rc = "REPLACE", Rx = "REPLACE", Rv = "V-REPLACE",
  c = "COMMAND", cv = "EX", ce = "EX",
  r = "PROMPT", rm = "MORE", ["r?"] = "CONFIRM",
  ["!"] = "SHELL", t = "TERMINAL",
}

-- Highlight group per mode display name (see mode_names). Keyed by the name, not
-- the mode code, so the group is derived from what's actually shown -- keeping the
-- mode block and the location block that reuses it in agreement.
local mode_groups = {
  NORMAL = "StModeNormal", ["O-PENDING"] = "StModeNormal",
  INSERT = "StModeInsert",
  VISUAL = "StModeVisual", ["V-LINE"] = "StModeVisual", ["V-BLOCK"] = "StModeVisual",
  SELECT = "StModeVisual", ["S-LINE"] = "StModeVisual", ["S-BLOCK"] = "StModeVisual",
  REPLACE = "StModeReplace", ["V-REPLACE"] = "StModeReplace",
  COMMAND = "StModeCommand", EX = "StModeCommand", PROMPT = "StModeCommand",
  MORE = "StModeCommand", CONFIRM = "StModeCommand", SHELL = "StModeCommand",
  TERMINAL = "StModeTerminal",
}

--- Wrap a statusline snippet in a highlight block. Sticky: the group carries
--- through until the next hl()/`%#..#`, which is what lets a section's color
--- fill across the `%=` gap. render() applies the top-level group per section;
--- a section's text may embed further hl() switches to re-highlight internally
--- (see diagnostics()).
local function hl(group, snippet)
  return "%#" .. group .. "#" .. snippet
end

-- Click-target ids, routed by on_click.
local CLICK = { diagnostics = 1, filetype = 2 }

--- Wrap a snippet in a click region routed to on_click with `id`. Composes
--- inside hl(): highlight is the outer wrapper, the click region the inner.
local function click(id, snippet)
  return "%" .. id .. "@v:lua.StatuslineClick@" .. snippet .. "%X"
end

--- Standard one-space gutter on each side of a segment's text.
local function pad(s)
  return " " .. s .. " "
end

--- Concatenate statusline chunks, skipping any that are nil/false -- so an absent
--- optional section (branch, diagnostics, search) just contributes nothing rather
--- than needing an `... or ""` at each call site. `%=` is passed as a literal
--- chunk to split the left group from the right.
local function join(...)
  local out = {}
  for i = 1, select("#", ...) do
    local chunk = select(i, ...)
    if chunk then
      out[#out + 1] = chunk
    end
  end
  return table.concat(out)
end

-- Section helpers return the section's text (or nil), not a highlight block --
-- render() wraps each in its top-level group. The returned text may itself
-- contain nested hl() switches for internal re-highlighting.

local function branch(buf)
  if vim.fn.exists("*FugitiveHead") == 1 then
    -- Resolve in buf's context so the head tracks the shown buffer's repo, not
    -- whatever holds focus (a float has no fugitive dir -> "").
    local head = vim.api.nvim_buf_call(buf, function()
      return vim.fn.FugitiveHead()
    end)
    if head ~= "" then
      return " " .. head .. " "
    end
  end
  return nil
end

local diag_spec = {
  { 1, "StDiagError", "E" },
  { 2, "StDiagWarn", "W" },
  { 3, "StDiagInfo", "I" },
  { 4, "StDiagHint", "H" },
}

local function diagnostics(buf)
  local counts = vim.diagnostic.count(buf)
  local out = {}
  for _, s in ipairs(diag_spec) do
    local n = counts[s[1]]
    if n and n > 0 then
      out[#out + 1] = hl(s[2], s[3] .. ":" .. n) -- internal re-highlight per severity
    end
  end
  if #out > 0 then
    return " " .. table.concat(out, " ") .. " "
  end
  return nil
end

-- Search match count, e.g. "[6/10]", while hlsearch is active. Returns nil when
-- there's no active highlighted search (so it clears on :nohlsearch). Counted in
-- win's context (searchcount is window/cursor-relative), so the count and current
-- index track the shown window rather than a focused float.
local function search(win)
  if vim.v.hlsearch == 0 then
    return nil
  end
  local ok, s = pcall(vim.api.nvim_win_call, win, function()
    return vim.fn.searchcount({ maxcount = 999, timeout = 250 })
  end)
  if not ok or s.total == nil or s.total == 0 then
    return nil
  end
  if s.incomplete == 1 then -- count timed out
    return "[?/?]"
  end
  local total = s.incomplete == 2 and (">" .. s.maxcount) or s.total
  return string.format("[%s/%s]", tostring(s.current), tostring(total))
end

-- Buffer status indicator, shared by the statusline and the tabline so the two
-- never diverge: ● modified, ○ readonly (both may show). Replaces the native
-- `%m%r` -- which the tabline can't use, as it'd report the current buffer for
-- every tab. Returns a leading-space-padded string, or "" when nothing to show.
local function flags(buf)
  local bo = vim.bo[buf]
  local s = (bo.modified and "●" or "") .. (bo.readonly and "○" or "")
  return s ~= "" and (" " .. s) or ""
end

-- Filename tail followed by its status flags -- the file segment's text.
local function filename(buf)
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t") .. flags(buf)
end

-- Cursor position for win as "line:col", matching the native %3l:%-2c layout.
-- (%c counts bytes from 1; nvim_win_get_cursor's column is 0-based.)
local function location(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  return string.format("%3d:%-2d", row, col + 1)
end

-- Display name for the current mode, or NORMAL while a float has focus (the main
-- buffer isn't the one being edited). nvim_get_mode().mode may be multi-char; fall
-- back to a first-char lookup, then uppercase.
local function mode_name(floating)
  local mode = floating and "n" or vim.api.nvim_get_mode().mode
  return mode_names[mode] or mode_names[mode:sub(1, 1)] or mode:upper()
end

-- Highlight group for a mode display name (see mode_groups), shared by the mode
-- block and the location block. Unknown names fall back to normal.
local function mode_group(name)
  return mode_groups[name] or "StModeNormal"
end

-- fzf-lua module if available, else nil -- keeps the picker optional so the
-- click actions can fall back to native equivalents.
local function fzf()
  local ok, mod = pcall(require, "fzf-lua")
  return ok and mod or nil
end

local actions = {
  [CLICK.diagnostics] = function()
    local f = fzf()
    if f then
      f.diagnostics_document()
    else
      vim.diagnostic.setloclist({ open = true })
    end
  end,
  [CLICK.filetype] = function()
    local f = fzf()
    if f then
      f.filetypes()
    else
      vim.ui.select(vim.fn.getcompletion("", "filetype"), { prompt = "Filetype" }, function(ft)
        if ft then
          vim.bo.filetype = ft
        end
      end)
    end
  end,
}

--- Statusline click dispatcher. Exposed globally (below) so the `%@..@` label
--- can reach it via v:lua.
local function on_click(id, _clicks, _button, _mods)
  local action = actions[id]
  if not action then
    return
  end
  -- Defer to SafeState, not schedule/timer. The click fires mid-`<LeftMouse>`,
  -- with the `<LeftRelease>` still queued; fzf-lua runs `startinsert` after its
  -- terminal spawns, so a stray release lands afterward and drops it back to
  -- terminal-normal mode. SafeState fires only once all pending input has
  -- drained, guaranteeing fzf spawns into a clean queue and its insert sticks.
  vim.api.nvim_create_autocmd("SafeState", { once = true, callback = action })
end

-- The window/buffer that best represents a tab page: its active window, unless
-- that's a floating window (e.g. an fzf picker), in which case the first
-- non-floating window -- so a transient float doesn't hijack what we show for the
-- tab. Returns { win, buf, floating }, where `floating` reports that a float was
-- bypassed (the active window differs from the chosen one). Shared by the
-- statusline (current tab) and the tabline (every tab): with a global statusline
-- (laststatus=3) a focused float would otherwise replace the filename/filetype
-- with its own, just as it would a tab's label.
local function tab_target(tab)
  local active = vim.api.nvim_tabpage_get_win(tab)
  local win = active
  if vim.api.nvim_win_get_config(active).relative ~= "" then
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_get_config(w).relative == "" then
        win = w
        break
      end
    end
  end
  return { win = win, buf = vim.api.nvim_win_get_buf(win), floating = win ~= active }
end

local function render()
  -- Everything is resolved against a single window/buffer, picked once here: the
  -- focused window, or the first non-floating one when a float (fzf picker, etc.)
  -- has focus -- so a transient float never hijacks any segment. The section
  -- helpers take this win/buf explicitly (rather than reading the current window),
  -- which keeps them consistent with each other and with the file section. While a
  -- float has focus the mode reads NORMAL: the main buffer isn't being edited.
  local t = tab_target(vim.api.nvim_get_current_tabpage())

  local name = mode_name(t.floating)
  local mg = mode_group(name)
  local br = branch(t.buf)
  local diag = diagnostics(t.buf)
  local sc = search(t.win)

  -- Each line is one segment; optional ones fall to nil and join() drops them.
  return join(
    hl(mg, pad(name)),
    br and hl("StSection", br),
    diag and hl("StSection", click(CLICK.diagnostics, diag)),
    hl("StFile", pad(filename(t.buf))),
    "%=",
    hl("StFile", click(CLICK.filetype, pad(vim.bo[t.buf].filetype))),
    sc and hl("StSection", pad(sc)),
    hl(mg, pad(location(t.win)))
  )
end

-- Cwd-relative path, collapsing each dir to its first char and keeping the
-- filename whole. Unlike vim's `:.` (which only relativizes descendants of cwd
-- and otherwise returns an absolute path), this climbs out of shared ancestors
-- with `../`, so siblings/parents get a relative form too: ../o/thing.lua.
local function cwd_relative(fname)
  local cwd = vim.split(vim.fn.getcwd(), "/", { trimempty = true })
  local f = vim.split(vim.fn.fnamemodify(fname, ":p"), "/", { trimempty = true })
  local i = 1
  while cwd[i] and f[i] and cwd[i] == f[i] do
    i = i + 1
  end
  local out = {}
  for _ = i, #cwd do
    out[#out + 1] = ".." -- one level up per un-shared cwd component
  end
  for j = i, #f - 1 do
    out[#out + 1] = f[j]:sub(1, 1) -- shortened dir; `..` above is left intact
  end
  out[#out + 1] = f[#f] -- filename kept whole
  return table.concat(out, "/")
end

--- Shortest readable form of a path: home/root-anchored (~/.. or /..) vs
--- cwd-relative (../..), whichever is fewer chars, each with parent dirs
--- collapsed to their first char and the filename kept whole.
local function short_path(fname)
  local anchored = vim.fn.pathshorten(vim.fn.fnamemodify(fname, ":~"))
  local relative = cwd_relative(fname)
  return #relative < #anchored and relative or anchored
end

-- Display name for a tab's buffer. Special buffers get readable labels keyed off
-- buftype (more robust than matching paths/schemes -- no $VIMRUNTIME or store-path
-- dependency, catches plugin buffers too); normal files use short_path.
local function buf_name(buf)
  local bt = vim.bo[buf].buftype
  local name = vim.api.nvim_buf_get_name(buf)

  if bt == "help" then
    return "help: " .. vim.fn.fnamemodify(name, ":t")
  elseif bt == "terminal" then
    -- term://{cwd}//{pid}:{cmd} -- show the command's basename
    local cmd = name:match("//%d+:(%S+)")
    return "term: " .. (cmd and vim.fn.fnamemodify(cmd, ":t") or "?")
  elseif bt == "quickfix" then
    return "[Quickfix]"
  elseif bt ~= "" then
    -- other special buffers (nofile/acwrite/prompt): name tail, else [buftype]
    return name ~= "" and vim.fn.fnamemodify(name, ":t") or ("[" .. bt .. "]")
  end

  return name ~= "" and short_path(name) or "[No Name]"
end

--- Tabline: one label per tab page, showing that tab's active buffer name and
--- its status flags. `%NT` makes each label switch to tab N on click (native, no
--- dispatcher needed); a trailing `%T` closes the last region so the fill area
--- to its right isn't part of the last tab's click target.
local function render_tabline()
  local cur = vim.api.nvim_get_current_tabpage()
  -- Selected tab wears the current mode's accent, matching the statusline's mode
  -- block (NORMAL while a float has focus, as it reads there too).
  local sel = mode_group(mode_name(tab_target(cur).floating))
  local parts = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local group = (tab == cur) and sel or "StTab"
    local buf = tab_target(tab).buf
    local name = buf_name(buf)
    parts[#parts + 1] = "%" .. i .. "T" .. hl(group, " " .. name .. flags(buf) .. " ")
  end
  parts[#parts + 1] = "%T" .. hl("StTabFill", "")
  return table.concat(parts)
end

-- Expose for the v:lua references in 'statusline'/'tabline' and the click labels.
_G.StatuslineRender = render
_G.TablineRender = render_tabline
_G.StatuslineClick = on_click

setup_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = setup_highlights })

vim.o.laststatus = 3 -- global statusline (was lualine's globalstatus)
vim.o.showmode = false -- mode shown in the statusline instead
vim.o.statusline = "%!v:lua.StatuslineRender()"
-- The statusline shows the search count, so drop the native cmdline "[1/5]".
vim.opt.shortmess:append("S")

vim.o.showtabline = 1 -- tabline appears only with 2+ tab pages
vim.o.tabline = "%!v:lua.TablineRender()"

-- The statusline redraws on mode change on its own, but the tabline doesn't --
-- and the selected tab's color now tracks the mode -- so redraw it explicitly to
-- keep that accent in step.
vim.api.nvim_create_autocmd("ModeChanged", {
  callback = function()
    vim.cmd("redrawtabline")
  end,
})
