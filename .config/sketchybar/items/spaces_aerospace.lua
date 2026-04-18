-- Aerospace spaces widget: virtual workspaces, queried via `aerospace` CLI.
-- Aerospace doesn't touch native macOS Spaces, so we hand-roll highlight
-- tracking by subscribing to aerospace's emitted `wm_workspace_change` event.
local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")
local display = require("helpers.display_settings")

local scale = display.get_scale()
local icon_font_size = 16.0 * scale
local scaled_icon_font = "sketchybar-app-font:Regular:" .. icon_font_size
local spaces = {}

local WORKSPACE_LIST_CMD = "aerospace list-workspaces --all"
local FOCUSED_CMD = "aerospace list-workspaces --focused"

local function popen_lines(cmd)
    local f = io.popen(cmd)
    if not f then return {} end
    local out = f:read("*a")
    f:close()
    local lines = {}
    for line in out:gmatch("([^\n]+)") do
        table.insert(lines, line)
    end
    return lines
end

local function list_windows_cmd(workspace)
    return table.concat({
        "aerospace list-windows --workspace ", workspace,
        " --format '%{app-name}' --json",
    })
end

local function focus_cmd(workspace)
    return "aerospace workspace " .. workspace
end

local workspaces = popen_lines(WORKSPACE_LIST_CMD)
local current_workspace = popen_lines(FOCUSED_CMD)[1]

local function split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do
        table.insert(result, each)
    end
    return result
end

local function update_space_label(space_item, apps)
    local icon_line = ""
    local no_app = true
    for _, app in ipairs(apps) do
        no_app = false
        local app_name = app["app-name"]
        local icon = app_icons[app_name] or app_icons["default"] or ":default:"
        icon_line = icon_line .. " " .. icon
    end
    if no_app then icon_line = " —" end
    sbar.animate("tanh", 10, function()
        space_item:set({ label = icon_line })
    end)
end

for i, workspace in ipairs(workspaces) do
    local selected = workspace == current_workspace
    local space = sbar.add("item", "item." .. i, {
        icon = {
            font = { family = settings.font.numbers },
            string = i,
            padding_left = settings.items.padding.left * scale,
            padding_right = (settings.items.padding.left / 2) * scale,
            color = settings.items.default_color(i),
            highlight_color = settings.items.highlight_color(i),
            highlight = selected
        },
        label = {
            padding_right = settings.items.padding.right * scale,
            color = settings.items.default_color(i),
            highlight_color = settings.items.highlight_color(i),
            font = scaled_icon_font,
            y_offset = -1 * scale,
            highlight = selected
        },
        padding_right = math.max(1, math.floor(1 * scale)),
        padding_left = math.max(1, math.floor(1 * scale)),
        background = {
            color = settings.items.colors.background,
            border_width = math.max(1, math.floor(1 * scale)),
            height = settings.items.height * scale,
            border_color = selected and settings.items.highlight_color(i) or settings.items.default_color(i)
        },
        popup = {
            background = {
                border_width = 5 * scale,
                border_color = colors.black
            }
        }
    })

    spaces[i] = space

    sbar.exec(list_windows_cmd(workspace), function(apps)
        update_space_label(space, apps)
    end)

    sbar.add("item", "item." .. i .. "padding", {
        script = "",
        width = settings.items.gap * scale
    })

    local space_popup = sbar.add("item", {
        position = "popup." .. space.name,
        padding_left = 5 * scale,
        padding_right = 0,
        background = {
            drawing = true,
            image = {
                corner_radius = 9 * scale,
                scale = 0.2 * scale
            }
        }
    })

    space:subscribe("wm_workspace_change", function(env)
        local is_selected = env.FOCUSED_WORKSPACE == workspace
        space:set({
            icon = { highlight = is_selected },
            label = { highlight = is_selected },
            background = {
                border_color = is_selected and settings.items.highlight_color(i) or settings.items.default_color(i)
            }
        })
    end)

    space:subscribe("mouse.clicked", function(env)
        local SID = split(env.NAME, ".")[2]
        if env.BUTTON == "other" then
            space_popup:set({ background = { image = "item." .. SID } })
            space:set({ popup = { drawing = "toggle" } })
        else
            sbar.exec(focus_cmd(SID))
        end
    end)

    space:subscribe("mouse.exited", function(_)
        space:set({ popup = { drawing = false } })
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
    for i, workspace in ipairs(workspaces) do
        sbar.exec(list_windows_cmd(workspace), function(apps)
            update_space_label(spaces[i], apps)
        end)
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
