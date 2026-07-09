-- d = destroy, x = cut, y = yank; each is a motion operator. d always goes to
-- the black hole, so it never disturbs what x/y stored.
--
-- Locally, the system clipboard (+) is the default register (unnamedplus), so
-- x/y/p all sync with it. Over SSH we leave 'clipboard' empty so nothing reaches
-- OSC 52 — every op stays in nvim's own registers. The mappings are identical
-- either way and hardcode no register, so an explicit prefix (`"ap`) still works.
if not vim.env.SSH_TTY then
  vim.opt.clipboard = "unnamedplus"
end

local map = vim.keymap.set

-- destroy → black hole
map({ "n", "x" }, "d", '"_d')
map("n", "D", '"_D')

-- cut → default register (reuse the delete operator)
map({ "n", "x" }, "x", "d")
map("n", "X", "D")
map("n", "xx", "dd") -- op-pending `x` isn't a motion, so linewise needs its own map

-- yank → default register; only Y needs a map (built-in Y is linewise, not to-EOL)
map("n", "Y", "y$")

-- paste: normal p/P already read the default register and repeat cleanly; only
-- visual needs P so replacing a selection doesn't clobber the register
map("x", "p", "P")
