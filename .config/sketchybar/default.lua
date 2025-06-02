local settings = require("settings")
local colors = require("colors")

-- Equivalent to the --default domain
sbar.default({
  updates = "when_shown",
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 21.0 -- Increased from 14.0 by factor of 1.5
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
    background = { image = { corner_radius = 14 } }, -- Increased from 9 by factor of ~1.5
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Semibold"],
      size = 19.5 -- Increased from 13.0 by factor of 1.5
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  background = {
    height = 42, -- Increased from 28 by factor of 1.5
    corner_radius = 14, -- Increased from 9 by factor of ~1.5
    border_width = 3, -- Increased from 2 by factor of 1.5
    border_color = colors.bg2,
    image = {
      corner_radius = 14, -- Increased from 9 by factor of ~1.5
      border_color = colors.grey,
      border_width = 2 -- Increased from 1 by factor of ~1.5
    }
  },
  popup = {
    background = {
      border_width = 3, -- Increased from 2 by factor of 1.5
      corner_radius = 14, -- Increased from 9 by factor of ~1.5
      border_color = colors.popup.border,
      color = colors.popup.bg,
      shadow = { drawing = true },
    },
    blur_radius = 75, -- Increased from 50 by factor of 1.5
  },
  padding_left = 8, -- Increased from 5 by factor of ~1.5
  padding_right = 8, -- Increased from 5 by factor of ~1.5
  scroll_texts = true,
})
