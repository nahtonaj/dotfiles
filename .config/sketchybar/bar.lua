local settings = require("settings")
local display = require("helpers.display_settings")

-- Get scale factor and calculate bar height
local scale = display.get_scale()
local bar_height = math.floor(settings.bar.height * scale)

-- Calculate notch-aware heights
-- MacBook Pro 14"/16" notch is approximately 32-37 logical points tall
local notch_bar_height = settings.bar.notch_height or math.floor(37 * scale)

-- Floating bar style settings
local corner_radius = settings.bar.corner_radius or 0
local margin = settings.bar.margin or 0
local y_offset = settings.bar.y_offset or 0
local blur_radius = settings.bar.blur_radius or 0

-- Get colors for border
local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
    topmost = "window",
    height = bar_height,
    notch_display_height = notch_bar_height,  -- Different height for notched displays
    notch_offset = settings.bar.notch_offset or 0,  -- Horizontal offset from notch center
    color = settings.bar.background,
    border_color = colors.bar.border,
    border_width = 1,
    padding_right = settings.bar.padding.x,
    padding_left = settings.bar.padding.x,
    sticky = true,
    position = "top",
    -- Visual enhancements
    blur_radius = blur_radius,          -- Frosted glass effect
    corner_radius = corner_radius,      -- Rounded corners for floating look
    margin = margin,                    -- Space around bar edges (floating effect)
    y_offset = y_offset,                -- Float bar below top edge
    shadow = settings.bar.shadow or false,
    font_smoothing = settings.bar.font_smoothing or true
})
