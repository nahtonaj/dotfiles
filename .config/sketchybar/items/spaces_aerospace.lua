-- Aerospace spaces widget: virtual workspaces, queried via `aerospace` CLI.
-- Aerospace doesn't touch native macOS Spaces, so we hand-roll highlight
-- tracking by subscribing to aerospace's emitted `wm_workspace_change` event.
--
-- LOAD STRATEGY (non-blocking):
--   1. Always create the structural items (refresher, observer, indicator) at
--      load time so the bar is NEVER empty because of aerospace.
--   2. Query aerospace asynchronously via sbar.exec; build workspace items in
--      the callback.  If aerospace is not yet up the callback gets empty
--      output; an exponential-backoff retry schedules the next attempt via
--      another sbar.exec so the load path never sleeps.
--   3. Every aerospace event (wm_workspace_change, etc.) also attempts a
--      build, so the moment aerospace becomes available and emits any event
--      the spaces appear automatically.
--   4. `spaces_built` + `building` flags prevent duplicate concurrent builds.
--
-- DISPLAY MAPPING:
--   sketchybar `display` indexes are macOS AppKit arrangement-ids (1-based).
--   aerospace monitor IDs are NOT the same; the mapping is:
--     aerospace monitor -> sketchybar display
--   via `aerospace list-monitors --format '%{monitor-id}|%{monitor-appkit-nsscreen-screens-id}'`
--   This is queried async at init and on every display_change / monitor_change.
--
-- DYNAMIC WORKSPACES:
--   Items are never hard-deleted.  A "high-water mark" tracks the max slot
--   ever created.  Workspaces beyond the current set are hidden (drawing=off).
--   When the set grows, new items are created and existing hidden ones reused.
--   Guard: rebuild only when set actually changes (compare sorted list).

local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")
local display = require("helpers.display_settings")
local aerospace = require("helpers.aerospace")

local scale = display.get_scale()
local icon_font_size = 16.0 * scale
local scaled_icon_font = "sketchybar-app-font:Regular:" .. icon_font_size

-- ── State ─────────────────────────────────────────────────────────────────
local spaces = {}           -- integer slot -> space item
local padding_items = {}    -- integer slot -> padding item
local workspaces = {}       -- ordered list of active workspace names
local items_by_ws = {}      -- workspace name -> space item
local padding_by_ws = {}    -- workspace name -> padding item
local last_ws_set = ""      -- sorted joined snapshot, for change detection
local monitor_display_map = {}  -- aerospace monitor id -> sketchybar display id
local spaces_built = false  -- true once workspace items are successfully created
local building    = false   -- true while the async build pipeline is in flight
local retry_count = 0
local MAX_RETRIES = 8       -- ~0+1+2+4+8+16+32 = 63 s max cumulative delay

-- ── Helpers ───────────────────────────────────────────────────────────────

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

-- Return a sorted snapshot string of ws_list, used for change detection.
local function ws_set_key(ws_list)
    local copy = {}
    for _, v in ipairs(ws_list) do copy[#copy + 1] = v end
    table.sort(copy)
    return table.concat(copy, ",")
end

-- ── Async workspace-monitor map ───────────────────────────────────────────
-- Queries aerospace for the flat monitor→workspace mapping and the
-- monitor→display mapping, then calls done_cb(ws_to_sbar_display, ws_list).
-- ws_to_sbar_display: workspace name -> sketchybar display id (integer).
-- ws_list: ordered list of all workspace names.
local function build_ws_display_map_async(done_cb)
    -- First get monitor -> sketchybar-display mapping
    aerospace.get_monitor_display_map_async(function(mon_disp_map)
        monitor_display_map = mon_disp_map

        -- Get workspaces per monitor to build ws -> monitor map
        aerospace.get_monitors_async(function(count)
            local ws_to_display = {}
            local ws_order = {}  -- preserved order from --all
            local remaining = count

            if remaining == 0 then
                done_cb(ws_to_display, ws_order)
                return
            end

            -- We'll collect per-monitor results into a map, then re-order
            -- using the flat --all list to preserve workspace ordering.
            local ws_monitor_map = {}  -- ws name -> aerospace monitor id
            for m = 1, count do
                aerospace.get_workspaces_for_monitor_async(m, function(ws_list)
                    for _, ws in ipairs(ws_list) do
                        ws_monitor_map[ws] = m
                    end
                    remaining = remaining - 1
                    if remaining == 0 then
                        -- Re-fetch --all to get canonical ordering
                        aerospace.get_workspaces_async(function(all_ws)
                            for _, ws in ipairs(all_ws) do
                                ws_order[#ws_order + 1] = ws
                                local m_id = ws_monitor_map[ws]
                                if m_id then
                                    local sbar_disp = mon_disp_map[m_id]
                                    ws_to_display[ws] = sbar_disp or 1
                                else
                                    ws_to_display[ws] = 1
                                end
                            end
                            done_cb(ws_to_display, ws_order)
                        end)
                    end
                end)
            end
        end)
    end)
end

-- ── Core: create or reuse items for slot i ────────────────────────────────
-- Creates item.i if it doesn't exist yet; returns the space item.
local function ensure_item_slot(i, workspace, focused_ws, disp)
    local selected = workspace == focused_ws

    if spaces[i] then
        -- Item already exists; reconfigure it for its new workspace.
        spaces[i]:set({
            display = disp,
            drawing = true,
            icon = {
                string = i,
                color = settings.items.default_color(i),
                highlight_color = settings.items.highlight_color(i),
                highlight = selected
            },
            label = {
                color = settings.items.default_color(i),
                highlight_color = settings.items.highlight_color(i),
                highlight = selected
            },
            background = {
                border_color = selected
                    and settings.items.highlight_color(i)
                    or settings.items.default_color(i)
            }
        })
        if padding_items[i] then
            padding_items[i]:set({ display = disp, drawing = true })
        end
        return spaces[i]
    end

    -- Brand new slot: create.
    local space = sbar.add("item", "item." .. i, {
        display = disp,
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
            border_width = 0,
            height = settings.items.height * scale,
            border_color = selected
                and settings.items.highlight_color(i)
                or settings.items.default_color(i)
        },
        popup = {
            background = {
                border_width = 5 * scale,
                border_color = colors.black
            }
        }
    })

    spaces[i] = space

    local space_padding = sbar.add("item", "item." .. i .. "padding", {
        display = disp,
        script = "",
        width = settings.items.gap * scale
    })
    padding_items[i] = space_padding

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
                border_color = is_selected
                    and settings.items.highlight_color(i)
                    or settings.items.default_color(i)
            }
        })
    end)

    space:subscribe("mouse.clicked", function(env)
        local SID = split(env.NAME, ".")[2]
        if env.BUTTON == "other" then
            space_popup:set({ background = { image = "item." .. SID } })
            space:set({ popup = { drawing = "toggle" } })
        else
            sbar.exec("aerospace workspace " .. workspace)
        end
    end)

    space:subscribe("mouse.exited", function(_)
        space:set({ popup = { drawing = false } })
    end)

    return space
end

-- ── Core: reconcile items with current ws_list ────────────────────────────
-- Called both on first build and on every workspace-set change.
-- `ws_to_display`: workspace -> sketchybar display id.
-- `ws_list`: ordered list of current workspaces.
-- `focused_ws`: currently focused workspace name.
local function reconcile_spaces(ws_list, focused_ws, ws_to_display)
    workspaces = ws_list

    -- (Re)assign items_by_ws / padding_by_ws for this set.
    local old_items_by_ws = items_by_ws
    local old_padding_by_ws = padding_by_ws
    items_by_ws = {}
    padding_by_ws = {}

    for i, workspace in ipairs(workspaces) do
        local disp = ws_to_display[workspace] or 1
        local space = ensure_item_slot(i, workspace, focused_ws, disp)
        items_by_ws[workspace] = space
        padding_by_ws[workspace] = padding_items[i]

        -- Update window icons.
        aerospace.get_windows(workspace, function(apps)
            update_space_label(space, apps)
        end)
    end

    -- Hide any slots beyond current workspace count.
    local n = #workspaces
    local slot = n + 1
    while spaces[slot] do
        spaces[slot]:set({ drawing = false })
        if padding_items[slot] then
            padding_items[slot]:set({ drawing = false })
        end
        slot = slot + 1
    end
end

-- ── Async init with bounded retry ─────────────────────────────────────────
local function try_build_spaces()
    if building or spaces_built then return end
    building = true

    build_ws_display_map_async(function(ws_to_display, ws_list)
        if spaces_built then
            building = false
            return
        end

        if not ws_list or #ws_list == 0 then
            building = false
            retry_count = retry_count + 1
            if retry_count > MAX_RETRIES then
                io.stderr:write("[sketchybar/spaces_aerospace] aerospace did not"
                    .. " respond after " .. MAX_RETRIES .. " retries; giving up."
                    .. " Spaces will appear on the next aerospace event.\n")
                return
            end
            local delay = math.min(2 ^ (retry_count - 1), 30)
            sbar.exec("sleep " .. tostring(delay), function(_)
                try_build_spaces()
            end)
            return
        end

        aerospace.get_focused_async(function(focused_ws)
            if spaces_built then
                building = false
                return
            end
            local ok, err = pcall(reconcile_spaces, ws_list, focused_ws, ws_to_display)
            building = false
            if not ok then
                io.stderr:write("[sketchybar/spaces_aerospace] reconcile_spaces"
                    .. " failed: " .. tostring(err) .. "\n")
                return
            end
            spaces_built = true
            last_ws_set = ws_set_key(ws_list)
            retry_count = 0
        end)
    end)
end

-- ── Refresh: only display assignments, no structural changes ──────────────
local function refresh_displays()
    if not spaces_built then return end
    aerospace.get_monitor_display_map_async(function(mon_disp_map)
        monitor_display_map = mon_disp_map
        -- Rebuild the per-ws display map using current workspace-monitor info.
        aerospace.get_monitors_async(function(count)
            local remaining = count
            if remaining == 0 then return end
            local ws_monitor_map = {}
            for m = 1, count do
                aerospace.get_workspaces_for_monitor_async(m, function(ws_list)
                    for _, ws in ipairs(ws_list) do
                        ws_monitor_map[ws] = m
                    end
                    remaining = remaining - 1
                    if remaining == 0 then
                        for ws, item in pairs(items_by_ws) do
                            local m_id = ws_monitor_map[ws]
                            local d = (m_id and mon_disp_map[m_id]) or 1
                            item:set({ display = d })
                            if padding_by_ws[ws] then
                                padding_by_ws[ws]:set({ display = d })
                            end
                        end
                    end
                end)
            end
        end)
    end)
end

-- ── Refresh: dynamic workspace reconciliation ─────────────────────────────
-- Called on workspace-change events; rebuilds if the set has changed.
local function refresh_workspaces()
    if building then return end

    if not spaces_built then
        try_build_spaces()
        return
    end

    -- Check for set change before doing expensive reconcile.
    building = true
    build_ws_display_map_async(function(ws_to_display, ws_list)
        building = false
        if not ws_list or #ws_list == 0 then return end

        local new_key = ws_set_key(ws_list)
        if new_key == last_ws_set then
            -- Set unchanged; only refresh displays in case mapping shifted.
            for ws, item in pairs(items_by_ws) do
                local d = ws_to_display[ws] or 1
                item:set({ display = d })
                if padding_by_ws[ws] then
                    padding_by_ws[ws]:set({ display = d })
                end
            end
            return
        end

        aerospace.get_focused_async(function(focused_ws)
            local ok, err = pcall(reconcile_spaces, ws_list, focused_ws, ws_to_display)
            if not ok then
                io.stderr:write("[sketchybar/spaces_aerospace] refresh reconcile"
                    .. " failed: " .. tostring(err) .. "\n")
                return
            end
            last_ws_set = new_key
        end)
    end)
end

local function refresh_all_space_labels()
    for i, workspace in ipairs(workspaces) do
        aerospace.get_windows(workspace, function(apps)
            update_space_label(spaces[i], apps)
        end)
    end
end

local function ensure_spaces_built()
    if spaces_built or building then return end
    retry_count = 0
    try_build_spaces()
end

-- ── Structural items (always created at load time) ────────────────────────

sbar.add("event", "spaces_refresh")

local spaces_refresher = sbar.add("item", "spaces.refresher", {
    drawing = false,
    updates = true
})
spaces_refresher:subscribe("wm_workspace_change", function()
    refresh_workspaces()
end)
spaces_refresher:subscribe("aerospace_monitor_change", function()
    ensure_spaces_built()
    refresh_displays()
end)
spaces_refresher:subscribe("spaces_refresh", function()
    refresh_workspaces()
end)
spaces_refresher:subscribe("display_change", function()
    ensure_spaces_built()
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

space_window_observer:subscribe("space_windows_change", function(_)
    ensure_spaces_built()
    refresh_all_space_labels()
end)

space_window_observer:subscribe("wm_focus_change", function(_)
    ensure_spaces_built()
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

-- ── Kick off the async init (non-blocking) ────────────────────────────────
try_build_spaces()
