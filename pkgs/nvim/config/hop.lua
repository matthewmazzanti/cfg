local hop = require("hop")
local dir = require("hop.hint").HintDirection

hop.setup()

local function set(key, fn)
    vim.keymap.set("", key, fn, { remap = true })
end

set("f", function()
    hop.hint_char1({
        direction = dir.AFTER_CURSOR,
        current_line_only = true
    })
end)

set("F", function()
    hop.hint_char1({
        direction = dir.BEFORE_CURSOR,
        current_line_only = true,
    })
end)

set("t", function()
    hop.hint_char1({
        direction = dir.AFTER_CURSOR,
        current_line_only = true,
        hint_offset = -1,
    })
end)

set("T", function()
    hop.hint_char1({
        direction = dir.BEFORE_CURSOR,
        current_line_only = true,
        hint_offset = 1,
    })
end)
