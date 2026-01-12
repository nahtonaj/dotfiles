local settings = require("settings")
local display = require("helpers.display_settings")

-- Get scale factor and calculate bar height
local scale = display.get_scale()
local bar_height = math.floor(settings.bar.height * scale)

-- Calculate notch-aware heights
-- MacBook Pro 14"/16" notch is approximately 32-37 logical points tall
local notch_bar_height = settings.bar.notch_height or math.floor(37 * scale)

-- Equivalent to the --bar domain
sbar.bar({
    topmost = "window",
    height = bar_height,
    notch_display_height = notch_bar_height,  -- Different height for notched displays
    notch_offset = settings.bar.notch_offset or 0,  -- Horizontal offset from notch center
    color = settings.bar.background,
    padding_right = settings.bar.padding.x,
    padding_left = settings.bar.padding.x,
    -- padding_top = settings.bar.padding.y,
    -- padding_bottom = settings.bar.padding.y,
    sticky = true,
    position = "top",
    shadow = false
})
