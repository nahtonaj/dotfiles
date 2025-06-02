local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- Padding item required because of bracket
sbar.add("item", { width = 8 }) -- Increased from 5 by factor of ~1.5

local apple = sbar.add("item", {
  icon = {
    font = { size = 24.0 }, -- Increased from 16.0 by factor of 1.5
    string = icons.apple,
    padding_right = 12, -- Increased from 8 by factor of 1.5
    padding_left = 12, -- Increased from 8 by factor of 1.5
  },
  label = { drawing = false },
  background = {
    color = colors.bg2,
    border_color = colors.black,
    border_width = 2 -- Increased from 1 by factor of ~1.5
  },
  padding_left = 2, -- Increased from 1 by factor of ~1.5
  padding_right = 2, -- Increased from 1 by factor of ~1.5
  click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0"
})

-- Double border for apple using a single item bracket
sbar.add("bracket", { apple.name }, {
  background = {
    color = colors.transparent,
    height = 45, -- Increased from 30 by factor of 1.5
    border_color = colors.grey,
  }
})

-- Padding item required because of bracket
sbar.add("item", { width = 11 }) -- Increased from 7 by factor of ~1.5
