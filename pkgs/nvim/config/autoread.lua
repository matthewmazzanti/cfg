-- Event-driven 'autoread': watch each file-backed buffer with a libuv fs_event
-- (inotify on Linux) and run :checktime on change, so external edits -- e.g.
-- Claude Code writing to disk -- reload promptly instead of waiting for
-- FocusGained or a manual :checktime. This is a backport of Neovim's built-in
-- watcher (PR #37971, merged into 0.13). On 0.13+ `set autoread` covers this
-- natively, so the shim bows out and we can delete this file.
-- has("nvim-0.13") is true on 0.13 AND any later version (0.14+, 1.0, ...),
-- so this guard also fires on everything past 0.13. At that point the native
-- watcher has superseded this shim -- warn (deferred so it survives startup)
-- and bail. To clear the warning, delete this file and its entry in
-- default.nix.
if vim.fn.has("nvim-0.13") == 1 then
  vim.schedule(function()
    vim.notify(
      "autoread.lua: nvim>=0.13 has a built-in fs watcher; remove this shim "
        .. "(pkgs/nvim/config/autoread.lua + its line in pkgs/nvim/default.nix)",
      vim.log.levels.WARN
    )
  end)
  return
end

-- Conservative by design: we only ever poke :checktime. checktime respects
-- 'autoread' and silently reloads ONLY unmodified buffers; if you have unsaved
-- changes it prompts (W12) rather than clobbering them. So the watcher can
-- never lose your edits -- it just removes the latency.
local grp = vim.api.nvim_create_augroup("fs_watch_autoread", { clear = true })
local watchers = {} -- bufnr -> { handle = uv_fs_event, timer = uv_timer }

local function unwatch(bufnr)
  local w = watchers[bufnr]
  if not w then
    return
  end
  w.handle:stop()
  if not w.handle:is_closing() then
    w.handle:close()
  end
  w.timer:stop()
  if not w.timer:is_closing() then
    w.timer:close()
  end
  watchers[bufnr] = nil
end

local function watch(bufnr)
  if watchers[bufnr] then
    return
  end
  -- Only real, on-disk file buffers: skip terminals, help, quickfix, etc.
  if vim.bo[bufnr].buftype ~= "" then
    return
  end
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" or vim.fn.filereadable(path) == 0 then
    return
  end

  local handle = vim.uv.new_fs_event()
  local timer = vim.uv.new_timer()
  if not handle or not timer then
    return
  end
  watchers[bufnr] = { handle = handle, timer = timer }

  local function reload()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    -- File gone from disk. Atomic-rename saves swap the inode but keep the
    -- path readable, so this branch only fires on genuine deletes (rm, branch
    -- switch, etc.) -- not on ordinary writes. Running checktime here would
    -- error with E211 "File no longer available", so handle it ourselves.
    if vim.fn.filereadable(path) == 0 then
      -- The watch tracks an inode that's now unlinked -- it's dead either way
      -- (the re-arm fails silently on the missing path), so stop it first
      -- regardless of what we do with the buffer.
      unwatch(bufnr)
      if vim.bo[bufnr].modified then
        -- The buffer holds the only copy of unsaved edits. Never discard it;
        -- warn and keep it so :w can recreate the file.
        vim.notify(
          ("autoread: %s deleted on disk; buffer kept (modified). :w to restore."):format(path),
          vim.log.levels.WARN
        )
        return
      end
      -- Unmodified: the buffer just mirrors a file that no longer exists.
      vim.api.nvim_buf_delete(bufnr, { force = false })
      return
    end
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("checktime")
    end)
  end

  local function arm()
    -- fs_event callbacks run on the libuv loop thread where the vim API is
    -- off-limits; debounce on a timer and bounce the reload onto the main loop
    -- via schedule_wrap. 100ms matches upstream and coalesces write bursts.
    handle:start(path, {}, function(err)
      if err then
        return
      end
      -- Debounce: each event restarts the 100ms one-shot, so a burst of
      -- inotify events from one save collapses into a single reload.
      timer:stop()
      timer:start(100, 0, vim.schedule_wrap(reload))
      -- Re-arm: atomic-rename writers (write temp + rename) move the inode out
      -- from under the watch, killing it after one event. In-place writes keep
      -- firing, but re-arming is cheap and covers both.
      handle:stop()
      pcall(arm)
    end)
  end
  arm()
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = grp,
  callback = function(args)
    watch(args.buf)
  end,
})

-- Path can change under us (:saveas, rename) -- re-point the watcher.
vim.api.nvim_create_autocmd("BufFilePost", {
  group = grp,
  callback = function(args)
    unwatch(args.buf)
    watch(args.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = grp,
  callback = function(args)
    unwatch(args.buf)
  end,
})
