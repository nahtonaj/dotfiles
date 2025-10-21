local settings = require("settings")
local colors = require("colors")
local display = require("helpers.display_settings")

-- Get scale factor
local scale = display.get_scale()

-- Calculate scaled values
local icon_size = 14.0 * scale
local label_size = 13.0 * scale
local corner_radius = settings.items.corner_radius * scale
local bg_height = settings.items.height * scale
local border_width = math.max(1, math.floor(2 * scale))
local border_width_small = math.max(1, math.floor(1 * scale))
local padding = settings.paddings * scale

-- Equivalent to the --default domain
sbar.default({
    updates = "when_shown",
    icon = {
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
            size = icon_size
        },
        color = colors.white,
        padding_left = padding,
        padding_right = padding,
        background = {
            image = {
                corner_radius = corner_radius
            }
        }
    },
    label = {
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Semibold"],
            size = label_size
        },
        color = colors.white,
        padding_left = padding,
        padding_right = padding
    },
    background = {
        height = bg_height,
        corner_radius = corner_radius,
        border_width = border_width,
        border_color = colors.bg2,
        image = {
            corner_radius = corner_radius,
            border_color = colors.grey,
            border_width = border_width_small
        }
    },
    popup = {
        background = {
            border_width = border_width,
            corner_radius = corner_radius,
            border_color = colors.popup.border,
            color = colors.popup.bg,
            shadow = {
                drawing = true
            }
        },
        blur_radius = 50 * scale
    },
    padding_left = 5 * scale,
    padding_right = 5 * scale,
    scroll_texts = true
})
