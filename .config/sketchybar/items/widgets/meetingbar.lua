local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local display = require("helpers.display_settings")

local scale = display.get_scale()

-- MeetingBar is added as an alias to the macOS menu bar item
-- This requires screen capture permissions in System Preferences
local meetingbar = sbar.add("alias", "MeetingBar,Item-0", {
    position = "right",
    background = {
        color = colors.bg1,
        border_width = 0,
        height = 24 * scale,
        corner_radius = 9 * scale
    },
    icon = {
        string = icons.calendar,
        color = colors.white,
        padding_left = 8 * scale,
        padding_right = 0
    },
    label = {
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Semibold"],
            size = 11.0 * scale
        },
        color = colors.white,
        padding_right = 8 * scale,
        padding_left = 4 * scale
    },
    padding_right = (settings.paddings + 6) * scale
})

-- Click to open MeetingBar menu
meetingbar:subscribe("mouse.clicked", function(env)
    sbar.exec("open -a 'MeetingBar'")
end)

-- Background around the meetingbar item
sbar.add("bracket", "widgets.meetingbar.bracket", { meetingbar.name }, {
    background = { color = colors.bg1 }
})

-- Padding to the right of meetingbar (left of CPU widget)
sbar.add("item", "widgets.meetingbar.padding", {
    position = "right",
    width = settings.group_paddings * scale
})
