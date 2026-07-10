-- GENERAL CONFIG --

-- Show numbers on each line next to text. Relative numbers for jumps
-- relativenumber may be a bit heavy on low-power systems
vim.opt.number = true
vim.opt.relativenumber = true

-- Movement stuff
-- Allow for mouse
vim.opt.mouse = "a"

-- Drop the default right-click "How-to disable mouse" entry (and its now-orphaned
-- separator) from the PopUp menu.
vim.cmd.aunmenu([[PopUp.How-to\ disable\ mouse]])
vim.cmd.aunmenu([[PopUp.-2-]])

-- Increase speed of mouse scrolling
if vim.env.TERM ~= "xterm-ghostty" then
  vim.keymap.set(
    {"n", "v", "i"},
    "<ScrollWheelUp>",
    "5<C-Y>",
    { silent = true }
  )
  vim.keymap.set(
    { "n", "v", "i" },
    "<ScrollWheelDown>",
    "5<C-E>",
    { silent = true }
  )
end
-- Remember cursor position during buffer switch
vim.opt.startofline = false
-- TODO: This still needed?
vim.opt.backspace = {"indent", "eol", "start"}


-- Line wrapping
vim.opt.colorcolumn = "81"
vim.opt.textwidth = 80
-- May be more options to explore here
vim.opt.formatoptions:append({
  c = true, -- Auto wrap comments
  r = true, -- Add comment leader on <CR> in insert mode
  o = true, -- Add comment leader when hitting "O" or "o"
  j = true, -- Remove comment leader when joining lines
  q = true, -- Format comments with gq
  l = true, -- Don't format long lines by default
})
vim.opt.linebreak = true
vim.opt.wrap = false

-- Indentation stuff
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

vim.opt.smarttab = true
vim.opt.autoindent = true
vim.opt.smartindent = true

-- Incremental search and better caps handling
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Set speeling
vim.opt.spelllang = "en_us"
vim.opt.spellfile = vim.fn.expand("~/.local/share/nvim/spell/en.utf-8.add")

-- Nice visualization of trailing space/tabs
vim.opt.list = true
if vim.env.TERM == "linux" then
  vim.opt.listchars = {
    -- Apparently some of these work?
    tab = "» ",
    extends = ">",
    precedes = "<",
    nbsp = "_",
    trail = "•",
  }
else
  vim.opt.listchars = {
    tab = "» ",
    extends = "›",
    precedes = "‹",
    nbsp = "␣",
    trail = "•",
  }
end

-- Persistent undo
vim.opt.undofile = true

-- Auto-read changed files
vim.opt.autoread = true

-- Always show sign column for marks, errors
vim.opt.signcolumn = "yes"

vim.opt.shortmess:append({
  c = true, -- Ignore insert completion messages
  I = true, -- Skip startup message
  s = true, -- No "search hit BOTTOM, continuing at TOP" wrap messages
})

-- Set leader key for other commands
vim.g.mapleader = ";"

-- Reset search highlighting.
-- TODO: the redrawstatus is only needed because our statusline renders the
-- search count -- a generic mapping coupled to one feature. Cleaner would be to
-- fire a `User SearchCleared` event here and let the statusline subscribe and
-- redraw itself. Part of the broader config-architecture question.
vim.keymap.set("n", "<leader>n", function()
  vim.cmd.nohlsearch()
  vim.cmd("redrawstatus")
end)

-- Toggle relative line numbers (useful for screen sharing)
local function toggle_relativenumber()
  local rnu = not vim.opt.relativenumber:get()
  vim.opt.relativenumber = rnu
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    vim.wo[win].relativenumber = rnu
  end
end
vim.api.nvim_create_user_command("Share", toggle_relativenumber, {})
vim.keymap.set("n", "<leader>l", toggle_relativenumber)

vim.filetype.add({
  filename = {
    [".envrc"] = "sh",
    ["Tiltfile"] = "starlark",
  },
  pattern = {
    ["*.conf"] = "conf",
    ["Tiltfile.*"] = "starlark",
    [".*"] = function(path, bufnr)
      local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1];
      if not first_line or not first_line:match("^#!") then
        return nil
      end

      if first_line:match("uv%s+run") then
        return "python"
      end

      return nil
    end,
  },
})

-- Stack like jump options, refresh on startup
vim.opt.jumpoptions = "stack"
vim.api.nvim_create_autocmd({"VimEnter"}, {
  pattern = {"*"},
  callback = function ()
    vim.cmd.clearjumps()
  end
})

-- Wipe the initial empty [No Name] buffer once the first real file opens, so it
-- doesn't linger. `:e` already reuses it (it becomes the file); this handles
-- `:tabe`/`:tabnew`, where it's left behind in the original tab -- close that
-- tab's window and wipe the buffer.
local initial_buf = vim.api.nvim_get_current_buf()
vim.api.nvim_create_autocmd({"BufReadPost", "BufNewFile"}, {
  once = true,
  callback = function(args)
    -- The file loaded into the initial buffer (e.g. `:e`) -- nothing to clean.
    if args.buf == initial_buf then
      return
    end
    vim.schedule(function()
      local buf = initial_buf
      local empty = vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buftype == ""
        and vim.api.nvim_buf_get_name(buf) == ""
        and not vim.bo[buf].modified
        and vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
      if not empty then
        return
      end
      -- Close any window still showing it (the original tab after `:tabe`),
      -- which closes that now-empty tab, then wipe the buffer.
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        pcall(vim.api.nvim_win_close, win, false)
      end
      pcall(vim.api.nvim_buf_delete, buf, {})
    end)
  end,
})

-- Use rounded borders around windows
if vim.env.TERM == "linux" then
  vim.opt.winborder = "single"
else
  vim.opt.winborder = "rounded"
end
