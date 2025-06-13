local function get_win_config(prompt, default)
  -- Calculate a minimal width with a bit buffer
  -- Place the window near cursor or at the center of the window.
  local position
  if prompt == "New Name: " then
    position = {
      relative = "cursor",
      row = 1,
      col = -1,
      width = math.max(
        vim.api.nvim_strwidth(default),
        vim.api.nvim_strwidth(prompt)
      ) + 10,
      title_pos = "left",
    }
  else
    local height = vim.api.nvim_win_get_height(0)
    local width = vim.api.nvim_win_get_width(0)
    position = {
      relative = "win",
      row = height / 3 - 1,
      col = width / 4,
      width = width / 2,
      title_pos = "center",
    }
  end

  return vim.tbl_deep_extend(
    "force",
    {
      focusable = true,
      style = "minimal",
      height = 1,
      title = prompt,
      noautocmd = true,
    },
    position
  )
end

local function input(opts, on_confirm)
  vim.validate('opts', opts, 'table', true)
  vim.validate('on_confirm', on_confirm, 'function')
  opts.prompt = opts.prompt or "Input: "
  opts.default = opts.default or ""

  local parent_win = vim.api.nvim_get_current_win()
  local cursor_pos = vim.api.nvim_win_get_cursor(parent_win)
  local mode = vim.api.nvim_get_mode()

  -- Create floating window.
  local buf = vim.api.nvim_create_buf(false, true)
  local win_config = get_win_config(opts.prompt, opts.default)
  local win = vim.api.nvim_open_win(buf, true, win_config)

  vim.b[buf].completion = false
  vim.bo[buf].buftype = "prompt"

  vim.fn.prompt_setprompt(buf, "")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { opts.default })
  vim.api.nvim_win_call(win, function()
    vim.cmd.startinsert({ bang = true })
  end)

  local function confirm(value)
    vim.cmd.stopinsert()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end

    vim.schedule(function()
      if vim.api.nvim_win_is_valid(parent_win) then
        vim.api.nvim_set_current_win(parent_win)
        vim.api.nvim_win_set_cursor(parent_win, cursor_pos)
        if mode == "i" then
          vim.cmd("startinsert")
        end
      end
      on_confirm(value)
    end)
  end

  vim.fn.prompt_setcallback(buf, confirm)
  vim.fn.prompt_setinterrupt(buf, confirm)
  vim.keymap.set("i", "<esc>", confirm, { buffer = buf })
end

vim.ui.input = input
