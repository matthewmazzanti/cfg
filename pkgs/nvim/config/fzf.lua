local fzf = require("fzf-lua")
local actions = fzf.actions

fzf.setup({
  winopts = {
    backdrop = 100,
    preview = {
      vertical = "up:45%",
      horizontal = "right:50%",
      delay = 50,
      winopts = { number = false },
    }
  },
  keymap     = {
    builtin = {
      true,
      ["<C-d>"] = "preview-page-down",
      ["<C-u>"] = "preview-page-up",
    },
    fzf = {
      true,
      ["ctrl-q"] = "select-all+accept",
    },
  },
  actions    = {
    files = {
      ["enter"] = actions.file_edit_or_qf,
      ["ctrl-x"] = actions.file_split,
      ["ctrl-v"] = actions.file_vsplit,
      ["ctrl-t"] = actions.file_tabedit,
      ["alt-q"] = actions.file_sel_to_qf,
      ["alt-i"] = actions.toggle_ignore,
      ["alt-h"] = actions.toggle_hidden,
      ["alt-f"] = actions.toggle_follow,
    },
  },
  files = {
    cwd_prompt = false;
    header = false;
  },
  defaults   = {
    git_icons = false,
  },
})

local function resolve_project(buf_dir)
  local default = { cwd = buf_dir, query = "" }

  -- Find if we're in a project
  local project_dir = vim.fs.dirname(
    vim.fs.find({ ".git" }, { upward = true, path = buf_dir })[1]
  )
  if project_dir == nil then
    return default
  end

  -- Get the relative buffer path within the project
  local rel_buf_dir = vim.fs.relpath(project_dir, buf_dir)
  if rel_buf_dir == nil then
    return default
  end

  -- Fixup query for usability
  if rel_buf_dir == "." then
    rel_buf_dir = ""
  else
    rel_buf_dir = rel_buf_dir.."/"
  end
  return { cwd = project_dir, query = rel_buf_dir }
end

local function files()
  local buf_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local opts = resolve_project(buf_dir)
  fzf.files(opts)
end

vim.keymap.set("n", "<leader>f", files)
vim.keymap.set("n", "<leader>b", fzf.buffers)
vim.keymap.set("n", "<leader>j", fzf.jumps)
vim.keymap.set("n", "<leader>m", fzf.marks)
vim.keymap.set("n", "<leader>g", fzf.live_grep)
vim.keymap.set("n", "z=", fzf.spell_suggest)
