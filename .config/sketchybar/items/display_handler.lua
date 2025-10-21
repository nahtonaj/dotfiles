local display = require("helpers.display_settings")
local colors = require("colors")

-- Create an invisible item to handle display changes
local display_handler = sbar.add("item", "display.handler", {
    drawing = false,
    updates = true
})

-- Store the current display info to detect changes
local current_display_info = display.get_display_info()
local current_scale = display.get_scale()

-- Log initial display setup
print(string.format("Display initialized: %d display(s), builtin: %s, scale: %.2f",
    current_display_info.count,
    tostring(current_display_info.is_builtin),
    current_scale))

-- Subscribe to display change event
display_handler:subscribe("display_change", function(env)
    local new_display_info = display.get_display_info()
    local new_scale = display.get_scale()

    -- Check if display configuration has changed
    local display_changed = (new_display_info.count ~= current_display_info.count) or
                           (new_display_info.is_builtin ~= current_display_info.is_builtin) or
                           (new_display_info.resolution ~= current_display_info.resolution)

    if display_changed or (new_scale ~= current_scale) then
        print(string.format("Display changed: %d display(s), builtin: %s, scale: %.2f -> %.2f",
            new_display_info.count,
            tostring(new_display_info.is_builtin),
            current_scale,
            new_scale))

        -- Update stored values
        current_display_info = new_display_info
        current_scale = new_scale

        -- Reload the entire configuration to apply new scaling
        sbar.exec("sketchybar --reload")
    end
end)

-- Also subscribe to system_woke to handle display changes after sleep
display_handler:subscribe("system_woke", function(env)
    -- Small delay to let the system settle
    sbar.delay(1, function()
        local new_display_info = display.get_display_info()
        local new_scale = display.get_scale()

        local display_changed = (new_display_info.count ~= current_display_info.count) or
                               (new_display_info.is_builtin ~= current_display_info.is_builtin)

        if display_changed or (new_scale ~= current_scale) then
            print(string.format("Display changed after wake: %d display(s), builtin: %s, scale: %.2f -> %.2f",
                new_display_info.count,
                tostring(new_display_info.is_builtin),
                current_scale,
                new_scale))

            current_display_info = new_display_info
            current_scale = new_scale

            sbar.exec("sketchybar --reload")
        end
    end)
end)
