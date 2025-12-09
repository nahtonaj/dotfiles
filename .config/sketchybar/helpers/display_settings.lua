local settings = require("settings")

-- Parse all displays from sketchybar query
local function get_all_displays()
    local handle = io.popen("sketchybar --query displays")
    local result = handle:read("*a")
    handle:close()

    local displays = {}
    local display_num = 0

    -- Parse each display block
    for display_block in result:gmatch('%{[^}]+frame[^}]+%}') do
        display_num = display_num + 1
        local x = tonumber(display_block:match('"x":([%d%.%-]+)'))
        local y = tonumber(display_block:match('"y":([%d%.%-]+)'))
        local w = tonumber(display_block:match('"w":([%d%.%-]+)'))
        local h = tonumber(display_block:match('"h":([%d%.%-]+)'))

        if w and h then
            local resolution = math.floor(w) .. "x" .. math.floor(h)
            displays[display_num] = {
                id = display_num,
                x = x or 0,
                y = y or 0,
                width = math.floor(w),
                height = math.floor(h),
                resolution = resolution,
                is_builtin = (resolution == "3456x2234")
            }
        end
    end

    return displays
end

-- Get scale factor for a specific display number
local function get_scale_for_display(display_num)
    local displays = get_all_displays()
    local display = displays[display_num]

    if not display then
        -- Fallback to default external scale
        return settings.displays.external or 1.0
    end

    -- Check for resolution-specific scale first
    if settings.displays[display.resolution] then
        return settings.displays[display.resolution]
    end

    -- Fall back to builtin vs external
    if display.is_builtin then
        return settings.displays.builtin or settings.builtin_scale or 1.0
    else
        return settings.displays.external or 1.0
    end
end

-- Get current display information (primary/main display)
local function get_display_info()
    local displays = get_all_displays()

    if not displays or #displays == 0 then
        return {
            count = 0,
            is_builtin = false,
            resolution = nil
        }
    end

    -- Find the primary display (typically arrangement-id 1 or y=0)
    local main_display = displays[1]

    return {
        count = #displays,
        is_builtin = main_display.is_builtin,
        resolution = main_display.resolution
    }
end

-- Helper function to detect if we're on a built-in display
local function is_builtin_display()
    local info = get_display_info()
    return info.is_builtin
end

-- Get scale factor based on display
local function get_scale()
    local info = get_display_info()

    -- Check for resolution-specific scale first
    if info.resolution and settings.displays[info.resolution] then
        return settings.displays[info.resolution]
    end

    -- Fall back to builtin vs external
    if info.is_builtin then
        return settings.displays.builtin or settings.builtin_scale or 1.0
    else
        return settings.displays.external or 1.0
    end
end

-- Scale a value based on current display
local function scale(value)
    return math.floor(value * get_scale())
end

-- Get display-aware settings for items
local function get_item_settings()
    local s = get_scale()
    return {
        height = math.floor(settings.items.height * s),
        gap = math.floor(settings.items.gap * s),
        padding = {
            left = math.floor(settings.items.padding.left * s),
            right = math.floor(settings.items.padding.right * s),
            top = settings.items.padding.top,
            bottom = settings.items.padding.bottom
        }
    }
end

-- Get display-aware font sizes
local function get_font_sizes()
    local s = get_scale()
    return {
        icon = settings.font.size.icon * s,
        label = settings.font.size.label * s
    }
end

-- Get display-aware paddings
local function get_paddings()
    return scale(settings.paddings)
end

-- Get average scale across all displays (for global bar properties)
local function get_average_scale()
    local displays = get_all_displays()
    if not displays or #displays == 0 then
        return 1.0
    end

    local total_scale = 0
    for _, display in pairs(displays) do
        total_scale = total_scale + get_scale_for_display(display.id)
    end

    return total_scale / #displays
end

-- Apply default configuration per display with appropriate scaling
local function apply_defaults_per_display()
    local displays = get_all_displays()
    local colors = require("colors")

    for display_id, display in pairs(displays) do
        local s = get_scale_for_display(display_id)

        -- Calculate scaled values for this display
        local icon_size = 14.0 * s
        local label_size = 13.0 * s
        local corner_radius = settings.items.corner_radius * s
        local bg_height = settings.items.height * s
        local border_width = math.max(1, math.floor(2 * s))
        local border_width_small = math.max(1, math.floor(1 * s))
        local padding = settings.paddings * s

        -- Apply defaults for this display
        sbar.default({
            display = display_id,
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
                blur_radius = 50 * s
            },
            padding_left = 5 * s,
            padding_right = 5 * s,
            scroll_texts = true
        })
    end
end

return {
    get_display_info = get_display_info,
    get_all_displays = get_all_displays,
    get_scale_for_display = get_scale_for_display,
    get_average_scale = get_average_scale,
    is_builtin_display = is_builtin_display,
    get_scale = get_scale,
    scale = scale,
    get_item_settings = get_item_settings,
    get_font_sizes = get_font_sizes,
    get_paddings = get_paddings,
    apply_defaults_per_display = apply_defaults_per_display
}
