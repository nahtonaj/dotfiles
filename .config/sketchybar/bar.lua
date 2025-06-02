local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
  height = 60, -- Increased from 55 for better visibility at 1x scale
  color = colors.bar.bg,
  padding_right = 2,
  padding_left = 2,
})
