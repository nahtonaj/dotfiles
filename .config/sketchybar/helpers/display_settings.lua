local settings = require("settings")

-- Get current display information
local function get_display_info()
    local handle = io.popen("sketchybar --query displays")
    local result = handle:read("*a")
    handle:close()

    -- Parse display information
    local display_count = 0
    for _ in result:gmatch('"arrangement%-id":%d+') do
        display_count = display_count + 1
    end

    -- Get resolution if available (from system_profiler or displays query)
    local resolution = nil
    if result:match('"width":(%d+)') and result:match('"height":(%d+)') then
        local width = result:match('"width":(%d+)')
        local height = result:match('"height":(%d+)')
        resolution = width .. "x" .. height
    end

    return {
        count = display_count,
        is_builtin = (display_count == 1),
        resolution = resolution
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

return {
    get_display_info = get_display_info,
    is_builtin_display = is_builtin_display,
    get_scale = get_scale,
    scale = scale,
    get_item_settings = get_item_settings,
    get_font_sizes = get_font_sizes,
    get_paddings = get_paddings
}
