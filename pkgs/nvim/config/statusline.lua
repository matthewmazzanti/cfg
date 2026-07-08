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

  -- Tabline: active tab as an accent block (mirrors the mode block), inactive
  -- tabs dim like the file section, empty fill on the editor bg -- darker than
  -- the tabs, so the tabs read as distinct blocks.
  set(0, "StTabSel", { fg = p.black, bg = p.gray, bold = true })
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

-- Highlight group per mode, keyed by first char of the mode code.
local mode_hl = {
  n = "StModeNormal",
  i = "StModeInsert",
  v = "StModeVisual", V = "StModeVisual", ["\22"] = "StModeVisual",
  s = "StModeVisual", S = "StModeVisual", ["\19"] = "StModeVisual",
  R = "StModeReplace",
  c = "StModeCommand", r = "StModeCommand", ["!"] = "StModeCommand",
  t = "StModeTerminal",
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

-- Section helpers return the section's text (or nil), not a highlight block --
-- render() wraps each in its top-level group. The returned text may itself
-- contain nested hl() switches for internal re-highlighting.

local function branch()
  if vim.fn.exists("*FugitiveHead") == 1 then
    local head = vim.fn.FugitiveHead()
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

local function diagnostics()
  local counts = vim.diagnostic.count(0)
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
-- there's no active highlighted search (so it clears on :nohlsearch).
local function search()
  if vim.v.hlsearch == 0 then
    return nil
  end
  local ok, s = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 250 })
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

local function render()
  local mode = vim.api.nvim_get_mode().mode
  local mg = mode_hl[mode:sub(1, 1)] or "StModeNormal"
  local name = mode_names[mode] or mode_names[mode:sub(1, 1)] or mode:upper()

  local br = branch()
  local diag = diagnostics()
  local sc = search()

  return table.concat({
    hl(mg, " " .. name .. " "),
    br and hl("StSection", br) or "",
    diag and hl("StSection", click(CLICK.diagnostics, diag)) or "",
    hl("StFile", " %t" .. flags(0) .. " "),
    "%=",
    hl("StFile", click(CLICK.filetype, " %{&filetype} ")),
    sc and hl("StSection", " " .. sc .. " ") or "",
    hl(mg, " %3l:%-2c "),
  })
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

-- Buffer that best represents a tab page: its active window, unless that's a
-- floating window (e.g. an fzf picker), in which case the first non-floating
-- window -- so a transient float doesn't hijack the tab's label.
local function tab_buf(tab)
  local win = vim.api.nvim_tabpage_get_win(tab)
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_get_config(w).relative == "" then
        win = w
        break
      end
    end
  end
  return vim.api.nvim_win_get_buf(win)
end

--- Tabline: one label per tab page, showing that tab's active buffer name and
--- its status flags. `%NT` makes each label switch to tab N on click (native, no
--- dispatcher needed); a trailing `%T` closes the last region so the fill area
--- to its right isn't part of the last tab's click target.
local function render_tabline()
  local cur = vim.api.nvim_get_current_tabpage()
  local parts = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local group = (tab == cur) and "StTabSel" or "StTab"
    local buf = tab_buf(tab)
    local fname = vim.api.nvim_buf_get_name(buf)
    local name = fname ~= "" and short_path(fname) or "[No Name]"
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
