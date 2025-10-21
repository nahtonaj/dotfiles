local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local display = require("helpers.display_settings")

local scale = display.get_scale()

local apple = sbar.add("item", {
    icon = {
        font = {
            size = 14.0 * scale
        },
        string = settings.modes.main.icon,
        padding_right = 8 * scale,
        padding_left = 8 * scale,
        highlight_color = settings.modes.service.color
    },
    label = {
        drawing = false
    },
    background = {
        color = settings.items.colors.background,
        border_color = settings.modes.main.color,
        border_width = math.max(1, math.floor(1 * scale))
    },

    padding_left = math.max(1, math.floor(1 * scale)),
    padding_right = math.max(1, math.floor(1 * scale)),
    click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0"
})

apple:subscribe("aerospace_enter_service_mode", function(_)
    sbar.animate("tanh", 10, function()
        apple:set({
            background = {
                border_color = settings.modes.service.color,
                border_width = 3 * scale
            },
            icon = {
                highlight = true,
                string = settings.modes.service.icon
            }
        })

    end)
end)

apple:subscribe("aerospace_leave_service_mode", function(_)
    sbar.animate("tanh", 10, function()
        apple:set({
            background = {
                border_color = settings.modes.main.color,
                border_width = math.max(1, math.floor(1 * scale))
            },
            icon = {
                highlight = false,
                string = settings.modes.main.icon
            }
        })
    end)
end)

-- Padding to the right of the main button
sbar.add("item", {
    width = 7 * scale
})
