local settings = require("settings")
local display = require("helpers.display_settings")

-- Get scale factor and calculate bar height
local scale = display.get_scale()
local bar_height = math.floor(settings.bar.height * scale)

-- Equivalent to the --bar domain
sbar.bar({
    topmost = "window",
    height = bar_height,
    color = settings.bar.background,
    padding_right = settings.bar.padding.x,
    padding_left = settings.bar.padding.x,
    -- padding_top = settings.bar.padding.y,
    -- padding_bottom = settings.bar.padding.y,
    sticky = true,
    position = "top",
    shadow = false
})
