local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local display = require("helpers.display_settings")

local scale = display.get_scale()

-- Execute the event provider binary which provides the event "memory_update" for
-- the memory load data, which is fired every 4.0 seconds.
sbar.exec("killall memory_load >/dev/null; $CONFIG_DIR/helpers/event_providers/memory_load/bin/memory_load memory_update 4.0")

local memory = sbar.add("graph", "widgets.memory", math.floor(42 * scale), {
    position = "right",
    graph = {
        color = colors.magenta
    },
    background = {
        height = 22 * scale,
        color = { alpha = 0 },
        border_color = { alpha = 0 },
        drawing = true
    },
    icon = {
        string = "󰍛",  -- Memory icon (nerd font) - fallback to text if not available
        font = {
            size = 14.0 * scale
        }
    },
    label = {
        string = "ram ??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0 * scale
        },
        align = "right",
        padding_right = 0,
        width = 0,
        y_offset = 4 * scale
    },
    padding_right = (settings.paddings + 6) * scale
})

memory:subscribe("memory_update", function(env)
    local used = tonumber(env.used_percent) or 0
    memory:push({ used / 100. })

    local color = colors.magenta
    if used > 50 then
        if used < 70 then
            color = colors.yellow
        elseif used < 85 then
            color = colors.orange
        else
            color = colors.red
        end
    end

    memory:set({
        graph = { color = color },
        label = "ram " .. env.used_percent .. "%"
    })
end)

memory:subscribe("mouse.clicked", function(env)
    sbar.exec("open -a 'Activity Monitor'")
end)

-- Background around the memory item
sbar.add("bracket", "widgets.memory.bracket", { memory.name }, {
    background = { color = colors.bg1 }
})

sbar.add("item", "widgets.memory.padding", {
    position = "right",
    width = settings.group_paddings * scale
})
