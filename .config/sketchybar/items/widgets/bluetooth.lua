local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local display = require("helpers.display_settings")

local scale = display.get_scale()
local popup_width = 220 * scale

local bluetooth = sbar.add("item", "widgets.bluetooth", {
    position = "right",
    icon = {
        string = "󰂯",  -- Bluetooth icon
        font = { size = 16.0 * scale },
        color = colors.blue,
        padding_left = 8 * scale,
        padding_right = 8 * scale
    },
    label = { drawing = false },
    update_freq = 60,
    popup = {
        align = "center",
        height = 30 * scale
    }
})

local bluetooth_status = sbar.add("item", {
    position = "popup." .. bluetooth.name,
    icon = {
        string = "Bluetooth",
        font = { style = settings.font.style_map["Bold"] },
        width = popup_width,
        align = "center"
    },
    label = { drawing = false },
    background = {
        height = 2 * scale,
        color = colors.grey,
        y_offset = -12 * scale
    }
})

sbar.add("bracket", "widgets.bluetooth.bracket", { bluetooth.name }, {
    background = { color = colors.bg1 }
})

sbar.add("item", "widgets.bluetooth.padding", {
    position = "right",
    width = settings.group_paddings * scale
})

local function get_device_icon(device_type, device_name)
    local name_lower = device_name:lower()

    -- Check for specific device types
    if name_lower:match("airpods") then
        if name_lower:match("pro") then
            return "󰥰"  -- AirPods Pro
        elseif name_lower:match("max") then
            return "󰋎"  -- AirPods Max (headphones)
        else
            return "󰥰"  -- Regular AirPods
        end
    elseif name_lower:match("keyboard") or name_lower:match("magic keyboard") then
        return "󰌌"  -- Keyboard
    elseif name_lower:match("mouse") or name_lower:match("magic mouse") then
        return "󰍽"  -- Mouse
    elseif name_lower:match("trackpad") or name_lower:match("magic trackpad") then
        return "󰟸"  -- Trackpad
    elseif name_lower:match("headphone") or name_lower:match("beats") or name_lower:match("sony") then
        return "󰋎"  -- Headphones
    elseif name_lower:match("speaker") or name_lower:match("homepod") then
        return "󰓃"  -- Speaker
    elseif name_lower:match("watch") then
        return "󰖉"  -- Watch
    elseif name_lower:match("iphone") or name_lower:match("phone") then
        return "󰄜"  -- Phone
    elseif name_lower:match("ipad") or name_lower:match("tablet") then
        return "󰓶"  -- Tablet
    elseif name_lower:match("controller") or name_lower:match("gamepad") or name_lower:match("xbox") or name_lower:match("playstation") or name_lower:match("dualsense") then
        return "󰖺"  -- Game controller
    else
        return "󰂱"  -- Generic Bluetooth device
    end
end

local function get_battery_color(level)
    if level > 60 then
        return colors.green
    elseif level > 30 then
        return colors.yellow
    elseif level > 10 then
        return colors.orange
    else
        return colors.red
    end
end

local function update_bluetooth()
    -- Check if Bluetooth is powered on
    sbar.exec("blueutil --power", function(power_state)
        local is_on = power_state:match("1")

        if not is_on then
            bluetooth:set({
                icon = {
                    string = "󰂲",  -- Bluetooth off icon
                    color = colors.grey
                }
            })
            bluetooth_status:set({
                icon = { string = "Bluetooth Off", color = colors.grey }
            })
            return
        end

        bluetooth:set({
            icon = {
                string = "󰂯",
                color = colors.blue
            }
        })

        -- Get connected devices with battery info using system_profiler
        sbar.exec([[system_profiler SPBluetoothDataType -json 2>/dev/null]], function(result)
            -- Remove old device items
            sbar.remove('/bluetooth.device\\.*/')

            local device_count = 0

            -- Parse JSON to find connected devices
            -- Look for device entries with "device_connected" = "attrib_Yes"
            for device_block in result:gmatch('"([^"]+)"%s*:%s*{[^{}]*"device_connected"%s*:%s*"attrib_Yes"[^{}]*}') do
                -- This is a connected device, try to get its info
                local name = device_block

                -- Try to find the full block for this device to get battery info
                local pattern = '"' .. name:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. '"%s*:%s*({[^{}]*})'
                local device_info = result:match(pattern) or ""

                -- Extract battery info if available
                local battery_level = device_info:match('"device_batteryLevelMain"%s*:%s*"?(%d+)"?')
                    or device_info:match('"device_batteryLevel"%s*:%s*"?(%d+)"?')
                    or device_info:match('"device_batteryPercent"%s*:%s*"?(%d+)"?')

                local device_icon = get_device_icon("", name)
                local battery_str = ""
                local battery_color = colors.white

                if battery_level then
                    battery_level = tonumber(battery_level)
                    battery_str = " " .. battery_level .. "%"
                    battery_color = get_battery_color(battery_level)
                end

                device_count = device_count + 1
                sbar.add("item", "bluetooth.device." .. device_count, {
                    position = "popup." .. bluetooth.name,
                    icon = {
                        string = device_icon,
                        width = 30 * scale,
                        align = "left",
                        font = { size = 14 * scale }
                    },
                    label = {
                        string = name .. battery_str,
                        width = popup_width - 30 * scale,
                        align = "left",
                        color = battery_color,
                        max_chars = 20
                    }
                })
            end

            -- Alternative: also try to get connected devices via blueutil
            if device_count == 0 then
                sbar.exec("blueutil --connected --format json 2>/dev/null", function(connected_result)
                    -- Parse connected devices from blueutil
                    for address, name in connected_result:gmatch('"address"%s*:%s*"([^"]+)"[^}]*"name"%s*:%s*"([^"]+)"') do
                        device_count = device_count + 1
                        local device_icon = get_device_icon("", name)

                        sbar.add("item", "bluetooth.device." .. device_count, {
                            position = "popup." .. bluetooth.name,
                            icon = {
                                string = device_icon,
                                width = 30 * scale,
                                align = "left",
                                font = { size = 14 * scale }
                            },
                            label = {
                                string = name,
                                width = popup_width - 30 * scale,
                                align = "left",
                                max_chars = 20
                            }
                        })
                    end

                    if device_count == 0 then
                        sbar.add("item", "bluetooth.device.none", {
                            position = "popup." .. bluetooth.name,
                            icon = { drawing = false },
                            label = {
                                string = "No devices connected",
                                width = popup_width,
                                align = "center",
                                color = colors.grey
                            }
                        })
                    end

                    bluetooth_status:set({
                        icon = { string = "Connected: " .. device_count }
                    })
                end)
            else
                bluetooth_status:set({
                    icon = { string = "Connected: " .. device_count }
                })
            end
        end)
    end)
end

bluetooth:subscribe({"routine", "forced", "system_woke"}, update_bluetooth)

bluetooth:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
        sbar.exec("open /System/Library/PreferencePanes/Bluetooth.prefPane")
    else
        update_bluetooth()
        bluetooth:set({ popup = { drawing = "toggle" } })
    end
end)

bluetooth:subscribe("mouse.exited.global", function(env)
    bluetooth:set({ popup = { drawing = false } })
end)
