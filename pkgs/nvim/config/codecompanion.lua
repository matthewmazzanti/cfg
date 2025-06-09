require("codecompanion").setup({
  display = {
    action_palette = {
      provider = "telescope",
    },
    diff = {
      enabled = true,
      layout = "horizontal",
      provider = "mini_diff",
    },
    window = {
      layout = "horizontal",
    },
  },
  strategies = {
    chat = { adapter = "copilot" },
    inline = { adapter = "copilot" },
    -- cmd = { adapter = "copilot" },
  },
})

local diff = require("mini.diff")
diff.setup({
  source = diff.gen_source.none(),
  options = {
    algorithm = "patience"
  }
})
