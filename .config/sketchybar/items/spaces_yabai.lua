-- Yabai spaces widget: leans on sketchybar's native macOS Spaces integration.
-- - `sbar.add("space", name, { space = i, ... })` binds the item to space i.
-- - `space_change` fires with env.SELECTED="true" when this space becomes active.
-- - `space_windows_change` fires with env.INFO.apps and env.INFO.space — the
--   app list is populated by sketchybar automatically for space-bound items.
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

local fs_query = popen_text([[yabai -m query --spaces | jq -r '.[]."is-native-fullscreen"']])
local fullscreen_flags = {}
for flag in string.gmatch(fs_query, "([^\n]+)") do
    table.insert(fullscreen_flags, flag == "true")
end
local num_spaces = #fullscreen_flags
if num_spaces < 1 then num_spaces = 10 end

local workspace_counter = 0
for i = 1, num_spaces do
    local is_fullscreen = fullscreen_flags[i] or false
    local icon_string
    if is_fullscreen then
        icon_string = "\xe2\x9b\xb6"
    else
        workspace_counter = workspace_counter + 1
        icon_string = tostring(workspace_counter)
    end
    local space = sbar.add("space", "space." .. i, {
        space = i,
        icon = {
            font = { family = settings.font.numbers },
            string = icon_string,
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

    sbar.add("space", "space.padding." .. i, {
        space = i,
        script = "",
        width = settings.items.gap * scale,
    })

    space:subscribe("space_change", function(env)
        local selected = env.SELECTED == "true"
        space:set({
            icon = { highlight = selected },
            label = { highlight = selected },
            background = {
                border_color = selected and settings.items.highlight_color(i) or settings.items.default_color(i)
            }
        })
    end)

    -- Focus space on click. Uses Hammerspoon (SIP-free) since yabai's own
    -- `--focus` needs the scripting addition.
    space:subscribe("mouse.clicked", function(env)
        sbar.exec("open 'hammerspoon://space_focus?n=" .. env.SID .. "'")
    end)
end

local space_window_observer = sbar.add("item", {
    drawing = false,
    updates = true,
})

local spaces_indicator = sbar.add("item", {
    padding_left = -3 * scale,
    padding_right = 0,
    icon = {
        padding_left = 8 * scale,
        padding_right = 9 * scale,
        color = colors.grey,
        string = icons.switch.on,
    },
    label = {
        width = 0,
        padding_left = 0,
        padding_right = 8 * scale,
        string = "Spaces",
        color = colors.bg1,
    },
    background = {
        color = colors.with_alpha(colors.grey, 0.0),
        border_color = colors.with_alpha(colors.bg1, 0.0),
    }
})

-- env.INFO.apps from sketchybar's native integration turned out to be
-- incomplete (only covers a subset of yabai's window list), so query yabai
-- directly for each space and rebuild labels.
local function refresh_space(idx)
    if not spaces[idx] then return end
    -- Filter to standard, visible windows so ghost entries (apps with an
    -- empty AXRole, invisible helper windows, etc.) don't inflate the label.
    local cmd = "yabai -m query --windows --space " .. idx ..
        [[ 2>/dev/null | jq -r '.[] | select(."is-minimized" == false and ."is-hidden" == false and .role == "AXWindow" and .subrole == "AXStandardWindow") | .app' | sort -u]]
    sbar.exec(cmd, function(output)
        local icon_line = ""
        local no_app = true
        for app in string.gmatch(tostring(output), "([^\n]+)") do
            no_app = false
            local icon = app_icons[app] or app_icons["default"] or ":default:"
            icon_line = icon_line .. " " .. icon
        end
        if no_app then icon_line = " —" end
        sbar.animate("tanh", 10, function()
            spaces[idx]:set({ label = icon_line })
        end)
    end)
end

local function refresh_all_spaces()
    for i = 1, num_spaces do refresh_space(i) end
end

-- Populate labels at startup.
refresh_all_spaces()

space_window_observer:subscribe("space_windows_change", function(env)
    local idx = env.INFO and tonumber(env.INFO.space)
    if idx then
        refresh_space(idx)
    else
        refresh_all_spaces()
    end
end)

-- Window focus change — covers app launches / closes that don't produce a
-- space_windows_change event (e.g. newly unmanaged windows).
space_window_observer:subscribe("wm_focus_change", function(_)
    refresh_all_spaces()
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
            background = { color = { alpha = 1.0 }, border_color = { alpha = 1.0 } },
            icon = { color = colors.bg1 },
            label = { width = "dynamic" }
        })
    end)
end)

spaces_indicator:subscribe("mouse.exited", function(_)
    sbar.animate("tanh", 30, function()
        spaces_indicator:set({
            background = { color = { alpha = 0.0 }, border_color = { alpha = 0.0 } },
            icon = { color = colors.grey },
            label = { width = 0 }
        })
    end)
end)

spaces_indicator:subscribe("mouse.clicked", function(_)
    sbar.trigger("swap_menus_and_spaces")
end)
