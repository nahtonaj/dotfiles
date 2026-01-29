local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local display = require("helpers.display_settings")

local scale = display.get_scale()

-- Focus mode icons and colors
local focus_modes = {
    ["Do Not Disturb"] = { icon = "󰍶", color = colors.red },
    ["Personal"] = { icon = "󰋑", color = colors.blue },
    ["Work"] = { icon = "󰔟", color = colors.green },
    ["Sleep"] = { icon = "󰒲", color = colors.magenta },
    ["Driving"] = { icon = "󰄋", color = colors.orange },
    ["Fitness"] = { icon = "󰖽", color = colors.green },
    ["Gaming"] = { icon = "󰊴", color = colors.magenta },
    ["Mindfulness"] = { icon = "󱅻", color = colors.blue },
    ["Reading"] = { icon = "󰂺", color = colors.yellow },
    -- Default for any custom focus modes
    ["default"] = { icon = "󰍶", color = colors.grey }
}

local focus = sbar.add("item", "widgets.focus", {
    position = "right",
    icon = {
        string = "󰍷",  -- Focus off icon (moon outline)
        font = { size = 15.0 * scale },
        color = colors.grey,
        padding_left = 6 * scale,
        padding_right = 6 * scale
    },
    label = { drawing = false },
    update_freq = 10  -- Check every 10 seconds
})

sbar.add("bracket", "widgets.focus.bracket", { focus.name }, {
    background = { color = colors.bg1 }
})

sbar.add("item", "widgets.focus.padding", {
    position = "right",
    width = settings.group_paddings * scale
})

local function update_focus()
    -- Check Focus/DND status using shortcuts or defaults read
    -- macOS Sonoma+ uses Focus modes
    sbar.exec([[
        focus_mode=$(defaults read com.apple.controlcenter "NSStatusItem Visible FocusModes" 2>/dev/null)

        # Try to get current focus mode name
        current_focus=$(plutil -extract data.currentProfile.identifier raw ~/Library/DoNotDisturb/DB/Assertions.json 2>/dev/null)

        if [ -z "$current_focus" ]; then
            # Alternative method: check if DND is enabled
            dnd_status=$(plutil -extract data.isActive raw ~/Library/DoNotDisturb/DB/Assertions.json 2>/dev/null)
            if [ "$dnd_status" = "true" ] || [ "$dnd_status" = "1" ]; then
                echo "active:Do Not Disturb"
            else
                echo "inactive"
            fi
        else
            echo "active:$current_focus"
        fi
    ]], function(result)
        result = result:gsub("%s+$", "")  -- Trim whitespace

        if result:match("^active:") then
            local mode_name = result:gsub("^active:", "")

            -- Clean up mode name (might be an ID like com.apple.donotdisturb.mode.default)
            if mode_name:match("%.") then
                -- Extract last component
                mode_name = mode_name:match("%.([^%.]+)$") or mode_name
                -- Capitalize first letter
                mode_name = mode_name:gsub("^%l", string.upper)
                -- Handle common mode IDs
                if mode_name == "Default" or mode_name == "Dnd" then
                    mode_name = "Do Not Disturb"
                end
            end

            local mode_config = focus_modes[mode_name] or focus_modes["default"]

            focus:set({
                icon = {
                    string = mode_config.icon,
                    color = mode_config.color
                }
            })
        else
            -- Focus/DND is off
            focus:set({
                icon = {
                    string = "󰍷",  -- Moon outline (focus off)
                    color = colors.grey
                }
            })
        end
    end)
end

focus:subscribe({"routine", "forced", "system_woke"}, update_focus)

focus:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
        -- Open Focus settings
        sbar.exec("open 'x-apple.systempreferences:com.apple.Focus'")
    else
        -- Toggle Do Not Disturb via shortcuts
        sbar.exec([[
            shortcuts run "Toggle Do Not Disturb" 2>/dev/null || \
            osascript -e 'tell application "System Events" to keystroke "D" using {command down, shift down, option down, control down}'
        ]])
        -- Update after a short delay
        sbar.delay(1, update_focus)
    end
end)
