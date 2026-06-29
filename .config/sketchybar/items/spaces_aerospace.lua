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

-- Poll aerospace until it responds or we time out (~10s).
-- Returns true if aerospace is ready, false otherwise.
-- Checks immediately first (no sleep on healthy startup), then retries
-- with 0.5s delays up to 20 attempts total.
local function wait_for_aerospace()
    for attempt = 1, 20 do
        local result = popen_lines(FOCUSED_CMD)
        if result[1] and result[1] ~= "" then return true end
        if attempt < 20 then os.execute("sleep 0.5") end
    end
    return false
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

-- Wait for aerospace, then query workspaces. If aerospace never becomes
-- ready, fall back to empty lists so the rest of the bar still loads.
local aerospace_ready = wait_for_aerospace()
local workspaces = aerospace_ready and popen_lines(WORKSPACE_LIST_CMD) or {}
local current_workspace = aerospace_ready and (popen_lines(FOCUSED_CMD)[1] or "") or ""

-- Build a workspace-name -> monitor-index map so each item draws on the
-- correct bar when multiple monitors are attached.
local function build_ws_monitor_map()
    if not aerospace_ready then return {} end
    local raw = popen_lines("aerospace list-monitors --count")
    local count = tonumber((raw[1] or "1")) or 1
    local map = {}
    for m = 1, count do
        for _, ws in ipairs(popen_lines("aerospace list-workspaces --monitor " .. m)) do
            map[ws] = m
        end
    end
    return map
end

local items_by_ws = {}      -- workspace name -> space item
local padding_by_ws = {}    -- workspace name -> padding item

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

-- Build workspace items inside pcall so a failure here cannot abort the
-- entire bar config (which would leave drawing:off, zero items).
local build_ok, build_err = pcall(function()
    local ws_map = build_ws_monitor_map()

    for i, workspace in ipairs(workspaces) do
        local selected = workspace == current_workspace
        local space = sbar.add("item", "item." .. i, {
            display = ws_map[workspace] or 1,
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
        items_by_ws[workspace] = space

        sbar.exec(list_windows_cmd(workspace), function(apps)
            update_space_label(space, apps)
        end)

        local space_padding = sbar.add("item", "item." .. i .. "padding", {
            display = ws_map[workspace] or 1,
            script = "",
            width = settings.items.gap * scale
        })
        padding_by_ws[workspace] = space_padding

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

    -- Recompute the workspace -> monitor map and update every item's display
    -- property so each bar shows only its own workspaces.
    local function refresh_displays_inner()
        local map = build_ws_monitor_map()
        for ws, item in pairs(items_by_ws) do
            local d = map[ws] or 1
            item:set({ display = d })
            if padding_by_ws[ws] then
                padding_by_ws[ws]:set({ display = d })
            end
        end
    end

    -- Initial refresh (items already have display set at creation, but this
    -- ensures consistency in case of a race with aerospace at load time).
    refresh_displays_inner()
end)

if not build_ok then
    io.stderr:write("[sketchybar/spaces_aerospace] workspace build failed: "
        .. tostring(build_err) .. "\n")
end

-- Recompute the workspace -> monitor map and update every item's display
-- property so each bar shows only its own workspaces.  Defined at module
-- scope so the event subscribers below can reference it even when the
-- build pcall above produced zero items (in which case this is a no-op).
local function refresh_displays()
    local map = build_ws_monitor_map()
    for ws, item in pairs(items_by_ws) do
        local d = map[ws] or 1
        item:set({ display = d })
        if padding_by_ws[ws] then
            padding_by_ws[ws]:set({ display = d })
        end
    end
end

-- Register the custom event so balance-spaces.sh can trigger it.
sbar.add("event", "spaces_refresh")

-- Hidden coordinator item that re-maps displays when workspaces move.
local spaces_refresher = sbar.add("item", "spaces.refresher", {
    drawing = false,
    updates = true
})
spaces_refresher:subscribe("wm_workspace_change", function()
    refresh_displays()
end)
spaces_refresher:subscribe("aerospace_monitor_change", function()
    refresh_displays()
end)
spaces_refresher:subscribe("spaces_refresh", function()
    refresh_displays()
end)
spaces_refresher:subscribe("display_change", function()
    refresh_displays()
end)

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
