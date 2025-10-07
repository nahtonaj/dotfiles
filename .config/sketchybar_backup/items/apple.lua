local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local scale = settings.scale_factor

-- Padding item required because of bracket
sbar.add("item", { width = 5 * scale })

local apple = sbar.add("item", {
  icon = {
    font = { size = 16.0 * scale },
    string = icons.apple,
    padding_right = 8 * scale,
    padding_left = 8 * scale,
  },
  label = { drawing = false },
  background = {
    color = colors.bg2,
    border_color = colors.black,
    border_width = math.max(1, math.floor(1 * scale))
  },
  padding_left = math.max(1, math.floor(1 * scale)),
  padding_right = math.max(1, math.floor(1 * scale)),
  click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0"
})

-- Double border for apple using a single item bracket
sbar.add("bracket", { apple.name }, {
  background = {
    color = colors.transparent,
    height = 30 * scale,
    border_color = colors.grey,
  }
})

-- Padding item required because of bracket
sbar.add("item", { width = 7 * scale })
