local colors = require("colors")
local settings = require("settings")

-- Equivalent to the --bar domain
sbar.bar({
  height = 40 * settings.scale_factor, -- Base height scaled by scale_factor
  color = colors.bar.bg,
  padding_right = 2,
  padding_left = 2,
})
