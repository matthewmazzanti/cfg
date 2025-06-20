local readline = require("utils.readline")
local api = vim.api
local cmd = vim.cmd

--- @class winconfig_opts
--- @field parent_win number
--- @field parent_buf number
--- @field cursor_pos table<number>
--- @field mode vim.api.keyset.get_mode
--- @field default string
--- @field prompt string

--- @param opts winconfig_opts
local function get_win_config(opts)
  -- Calculate a minimal width with a bit buffer
  -- Place the window near cursor or at the center of the window.
  local position
  if opts.prompt == "New Name: " then
    -- LSP rename: Small input box near word
    -- TODO: Position at start of treesitter token. Need to detect if treesitter
    -- is active, find node start, and calculate relative to screen location
    position = {
      relative = "cursor",
      row = 1,
      col = -1,
      width = math.max(
        api.nvim_strwidth(opts.default),
        api.nvim_strwidth(opts.prompt)
      ) + 15,
      title_pos = "left",
    }

  elseif opts.prompt == "Prompt " then
    -- Codecompanion inline
    local width = api.nvim_win_get_width(opts.parent_win)
    position = {
      relative = "cursor",
      row = 1,
      col = -10,
      width = math.floor(width * 3/4),
      title_pos = "center",
    }
  else
    local height = api.nvim_win_get_height(opts.parent_win)
    local width = api.nvim_win_get_width(opts.parent_win)
    position = {
      relative = "win",
      row = math.floor(height / 4) - 1,
      col = math.floor(width / 8),
      width = math.floor(width * 3/4),
      title_pos = "center",
    }
  end

  return vim.tbl_deep_extend(
    "force",
    {
      focusable = true,
      style = "minimal",
      height = 1,
      title = " "..opts.prompt,
      noautocmd = true,
    },
    position
  )
end

local function set_keymap(buf, confirm)
  local function set(lhs, rhs)
    vim.keymap.set("i", lhs, rhs, { buffer = buf })
  end
  set("<esc>", confirm)
  set("<C-k>", readline.kill_line)
  set("<C-u>", readline.backward_kill_line)
  set("<M-d>", readline.kill_word)
  set("<M-BS>", readline.backward_kill_word)
  set("<C-w>", readline.unix_word_rubout)
  set("<C-d>", "<Delete>")  -- delete-char
  set("<C-h>", "<BS>")      -- backward-delete-char
  set("<C-a>", readline.beginning_of_line)
  set("<C-e>", readline.end_of_line)
  set("<M-f>", readline.forward_word)
  set("<M-b>", readline.backward_word)
  set("<C-f>", "<Right>") -- forward-char
  set("<C-b>", "<Left>")  -- backward-char
end


local function input(opts, on_confirm)
  vim.validate('opts', opts, 'table', true)
  vim.validate('on_confirm', on_confirm, 'function')
  opts.prompt = opts.prompt or "Input: "
  opts.default = opts.default or ""

  local parent_win = api.nvim_get_current_win()
  local parent_buf = api.nvim_win_get_buf(parent_win)
  local cursor_pos = api.nvim_win_get_cursor(parent_win)
  local mode = api.nvim_get_mode()

  -- Create floating window.
  local buf = api.nvim_create_buf(false, true)
  local win_config = get_win_config({
    parent_win = parent_win,
    parent_buf = parent_buf,
    cursor_pos = cursor_pos,
    mode = mode,
    prompt = opts.prompt,
    default = opts.default
  })
  local win = api.nvim_open_win(buf, true, win_config)

  -- TODO: Move to callback?
  -- vim.b[buf].completion = false
  vim.bo[buf].buftype = "prompt"

  vim.fn.prompt_setprompt(buf, "")
  api.nvim_buf_set_lines(buf, 0, -1, false, { opts.default })
  api.nvim_win_call(win, function()
    cmd.startinsert({ bang = true })
  end)

  local function confirm(value)
    cmd.stopinsert()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_delete(buf, { force = true })
    end

    vim.schedule(function()
      if api.nvim_win_is_valid(parent_win) then
        api.nvim_set_current_win(parent_win)
        api.nvim_win_set_cursor(parent_win, cursor_pos)
        if mode == "i" then
          cmd.startinsert()
        else
        end
      end
      on_confirm(value)
    end)
  end

  vim.fn.prompt_setcallback(buf, confirm)
  vim.fn.prompt_setinterrupt(buf, confirm)
  -- TODO: Make configurable?
  set_keymap(buf, confirm)
end

vim.ui.input = input
