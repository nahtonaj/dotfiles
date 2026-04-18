-- Yabai spaces widget: native macOS Spaces, queried via `yabai`.
-- Uses sketchybar's built-in `space` item type which auto-handles highlight
-- via `associated_space` — no manual subscription needed for focus changes.
local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")
local display = require("helpers.display_settings")

local scale = display.get_scale()
local icon_font_size = 16.0 * scale
local scaled_icon_font = "sketchybar-app-font:Regular:" .. icon_font_size
local spaces = {}

local function popen_text(cmd)
    local f = io.popen(cmd)
    if not f then return "" end
    local out = f:read("*a") or ""
    f:close()
    return out
end

local function list_windows_cmd(space_index)
    return table.concat({
        "yabai -m query --windows --space ", tostring(space_index),
        [[ | jq -c '[.[] | {"app-name": .app}]']],
    })
end

local function focus_cmd(space_index)
    return "yabai -m space --focus " .. tostring(space_index)
end

local num_spaces = tonumber(popen_text("yabai -m query --spaces | jq 'length'")) or 0
if num_spaces == 0 then
    -- Fallback: if yabai isn't responsive at startup, create 10 slots so
    -- the bar still renders something useful.
    num_spaces = 10
end

local function update_space_label(space_item, apps)
    local icon_line = ""
    local no_app = true
    for _, app in ipairs(apps) do
        no_app = false
        local app_name = app["app-name"]
        local lookup = app_icons[app_name]
        local icon = ((lookup == nil) and app_icons["default"] or lookup)
        icon_line = icon_line .. " " .. icon
    end
    if no_app then icon_line = " —" end
    sbar.animate("tanh", 10, function()
        space_item:set({ label = icon_line })
    end)
end

for i = 1, num_spaces do
    local space = sbar.add("space", "space." .. i, {
        space = i,
        icon = {
            font = { family = settings.font.numbers },
            string = i,
            padding_left = settings.items.padding.left * scale,
            padding_right = (settings.items.padding.left / 2) * scale,
            color = settings.items.default_color(i),
            highlight_color = settings.items.highlight_color(i),
        },
        label = {
            padding_right = settings.items.padding.right * scale,
            color = settings.items.default_color(i),
            highlight_color = settings.items.highlight_color(i),
            font = scaled_icon_font,
            y_offset = -1 * scale,
        },
        padding_right = math.max(1, math.floor(1 * scale)),
        padding_left = math.max(1, math.floor(1 * scale)),
        background = {
            color = settings.items.colors.background,
            border_width = math.max(1, math.floor(1 * scale)),
            height = settings.items.height * scale,
            border_color = settings.items.default_color(i),
        },
    })

    spaces[i] = space

    sbar.exec(list_windows_cmd(i), function(apps)
        update_space_label(space, apps)
    end)

    sbar.add("item", "space." .. i .. "padding", {
        script = "",
        width = settings.items.gap * scale
    })

    space:subscribe("space_change", function(env)
        local is_active = tostring(env.SELECTED) == "true"
        space:set({
            background = {
                border_color = is_active and settings.items.highlight_color(i) or settings.items.default_color(i)
            }
        })
    end)

    space:subscribe("mouse.clicked", function(_)
        sbar.exec(focus_cmd(i))
    end)
end

local space_window_observer = sbar.add("item", {
    drawing = false,
    updates = true
})

local spaces_indicator = sbar.add("item", {
    padding_left = -3 * scale,
    padding_right = 0,
    icon = {
        padding_left = 8 * scale,
        padding_right = 9 * scale,
        color = colors.grey,
        string = icons.switch.on
    },
    label = {
        width = 0,
        padding_left = 0,
        padding_right = 8 * scale,
        string = "Spaces",
        color = colors.bg1
    },
    background = {
        color = colors.with_alpha(colors.grey, 0.0),
        border_color = colors.with_alpha(colors.bg1, 0.0)
    }
})

local function refresh_all_space_labels()
    for i = 1, num_spaces do
        if spaces[i] then
            sbar.exec(list_windows_cmd(i), function(apps)
                update_space_label(spaces[i], apps)
            end)
        end
    end
end

space_window_observer:subscribe("space_windows_change", function(_)
    refresh_all_space_labels()
end)

space_window_observer:subscribe("wm_focus_change", function(_)
    refresh_all_space_labels()
end)

spaces_indicator:subscribe("swap_menus_and_spaces", function(_)
    local currently_on = spaces_indicator:query().icon.value == icons.switch.on
    spaces_indicator:set({
        icon = currently_on and icons.switch.off or icons.switch.on
    })
end)

spaces_indicator:subscribe("mouse.entered", function(_)
    sbar.animate("tanh", 30, function()
        spaces_indicator:set({
            background = {
                color = { alpha = 1.0 },
                border_color = { alpha = 1.0 }
            },
            icon = { color = colors.bg1 },
            label = { width = "dynamic" }
        })
    end)
end)

spaces_indicator:subscribe("mouse.exited", function(_)
    sbar.animate("tanh", 30, function()
        spaces_indicator:set({
            background = {
                color = { alpha = 0.0 },
                border_color = { alpha = 0.0 }
            },
            icon = { color = colors.grey },
            label = { width = 0 }
        })
    end)
end)

spaces_indicator:subscribe("mouse.clicked", function(_)
    sbar.trigger("swap_menus_and_spaces")
end)
