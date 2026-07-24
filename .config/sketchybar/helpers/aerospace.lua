-- helpers/aerospace.lua
-- Thin CLI wrapper around the `aerospace` window manager.
--
-- SYNC NOTE: popen_lines and the sync functions (get_workspaces, get_focused,
-- get_monitors, get_workspaces_for_monitor) use io.popen synchronously.
-- They are safe to call from event callbacks (aerospace is up when events fire)
-- but MUST NOT be called at module load time (aerospace may not be ready yet).
-- Use the async variants (get_workspaces_async, etc.) for the load/init path.

local aerospace = {}

-- Internal sync helper: run cmd and return its output as a list of lines.
-- Safe from event callbacks; avoid at load time.
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

local WORKSPACE_LIST_CMD = "aerospace list-workspaces --all"
local FOCUSED_CMD        = "aerospace list-workspaces --focused"
local MONITOR_COUNT_CMD  = "aerospace list-monitors --count"

-- ── Display mapping: DirectDisplayID -> sketchybar arrangement-id ─────────
-- Built once at module-load time via io.popen("sketchybar --query displays").
-- This is safe because sketchybar is already running when this module loads.
-- The table is keyed by DirectDisplayID (number) -> arrangement-id (number).
-- aerospace list-monitors --format '%{monitor-appkit-nsscreen-screens-id}'
-- emits the CGDirectDisplayID for each monitor, which equals DirectDisplayID.
local direct_id_to_arrangement = (function()
    local map = {}
    local f = io.popen("sketchybar --query displays 2>/dev/null")
    if not f then return map end
    local raw = f:read("*a")
    f:close()
    -- Parse JSON array: extract each object's arrangement-id and DirectDisplayID
    -- We do simple pattern matching to avoid a JSON library dependency.
    for obj in raw:gmatch("%b{}") do
        local arr = obj:match('"arrangement%-id"%s*:%s*(%d+)')
        local did = obj:match('"DirectDisplayID"%s*:%s*(%d+)')
        if arr and did then
            map[tonumber(did)] = tonumber(arr)
        end
    end
    return map
end)()

-- Return list of all workspace names across all monitors.
-- Sync: safe to call from event callbacks; avoid at load time.
function aerospace.get_workspaces()
    return popen_lines(WORKSPACE_LIST_CMD)
end

-- Return the currently focused workspace name, or "" on failure.
-- Sync: safe to call from event callbacks; avoid at load time.
function aerospace.get_focused()
    return popen_lines(FOCUSED_CMD)[1] or ""
end

-- Pure predicate: is ws the currently selected workspace given focused_ws?
function aerospace.is_workspace_selected(ws, focused_ws)
    return ws == focused_ws
end

-- Async: list windows in ws, then call callback(apps_json_table).
function aerospace.get_windows(ws, callback)
    local cmd = "aerospace list-windows --workspace " .. ws
        .. " --format '%{app-name}' --json"
    sbar.exec(cmd, callback)
end

-- Return total monitor count as a number.
-- Sync: safe to call from event callbacks; avoid at load time.
function aerospace.get_monitors()
    local raw = popen_lines(MONITOR_COUNT_CMD)
    return tonumber(raw[1] or "1") or 1
end

-- Return workspace list for a given monitor index.
-- Sync: safe to call from event callbacks; avoid at load time.
function aerospace.get_workspaces_for_monitor(m)
    return popen_lines("aerospace list-workspaces --monitor " .. m)
end

-- wait_for_aerospace: formerly a blocking 90-second poll loop.
-- Now a non-blocking no-op that always returns false immediately.
-- Use the async init pattern in spaces_aerospace.lua instead.
function aerospace.wait_for_aerospace()
    return false
end

-- ── Async variants (use on the load/init path) ────────────────────────────

-- Async: list all workspaces, call callback(lines_table).
function aerospace.get_workspaces_async(callback)
    sbar.exec(WORKSPACE_LIST_CMD, function(out)
        local lines = {}
        for line in (out or ""):gmatch("([^\n]+)") do
            table.insert(lines, line)
        end
        callback(lines)
    end)
end

-- Async: get focused workspace name, call callback(name_string).
function aerospace.get_focused_async(callback)
    sbar.exec(FOCUSED_CMD, function(out)
        callback((out or ""):match("([^\n]+)") or "")
    end)
end

-- Async: get monitor count, call callback(count_number).
function aerospace.get_monitors_async(callback)
    sbar.exec(MONITOR_COUNT_CMD, function(out)
        callback(tonumber((out or ""):match("%d+") or "1") or 1)
    end)
end

-- Async: list workspaces for monitor m, call callback(lines_table).
function aerospace.get_workspaces_for_monitor_async(m, callback)
    sbar.exec("aerospace list-workspaces --monitor " .. tostring(m), function(out)
        local lines = {}
        for line in (out or ""):gmatch("([^\n]+)") do
            table.insert(lines, line)
        end
        callback(lines)
    end)
end

-- Async: switch aerospace to the given workspace.
function aerospace.focus_workspace(ws)
    sbar.exec("aerospace workspace " .. ws)
end

-- Async: build map of aerospace_monitor_id -> sketchybar_display_id.
--
-- sketchybar `display=N` uses its own 1-based arrangement-id, NOT the AppKit
-- NSScreen id or CGDirectDisplayID.  The mapping requires two steps:
--
--   1. At module-load time, `direct_id_to_arrangement` maps each
--      CGDirectDisplayID to its sketchybar arrangement-id.  This is built
--      once via io.popen("sketchybar --query displays") and is valid for
--      the lifetime of this sketchybar session (arrangement changes trigger
--      a display_change event, which calls refresh_displays, which rebuilds
--      the display map via this function).
--   2. aerospace `%{monitor-appkit-nsscreen-screens-id}` emits each
--      monitor's CGDirectDisplayID, so we translate:
--        aero monitor-id -> DirectDisplayID -> sbar arrangement-id.
--
-- The table is refreshed at display_change via a fresh module reload;
-- for mid-session display reconfigurations the function rebuilds from
-- a fresh io.popen so arrangement shifts are always picked up.
function aerospace.get_monitor_display_map_async(callback)
    -- Rebuild DirectDisplayID->arrangement table fresh for each call
    -- (handles display reconfiguration at runtime).
    local d2a = (function()
        local map = {}
        local f = io.popen("sketchybar --query displays 2>/dev/null")
        if not f then return direct_id_to_arrangement end
        local raw = f:read("*a")
        f:close()
        for obj in raw:gmatch("%b{}") do
            local arr = obj:match('"arrangement%-id"%s*:%s*(%d+)')
            local did = obj:match('"DirectDisplayID"%s*:%s*(%d+)')
            if arr and did then
                map[tonumber(did)] = tonumber(arr)
            end
        end
        -- Fall back to module-load snapshot if query returned nothing
        if next(map) == nil then return direct_id_to_arrangement end
        return map
    end)()

    -- Async: aerospace monitor-id -> CGDirectDisplayID (via appkit nsscreen id)
    sbar.exec(
        "aerospace list-monitors"
            .. " --format '%{monitor-id}|%{monitor-appkit-nsscreen-screens-id}'",
        function(out)
            local map = {}
            for line in (out or ""):gmatch("([^\n]+)") do
                local mid, did_str = line:match("^(%d+)|(%d+)$")
                if mid and did_str then
                    local direct_id = tonumber(did_str)
                    -- Translate CGDirectDisplayID -> sketchybar arrangement-id
                    local arrangement = d2a[direct_id]
                    map[tonumber(mid)] = arrangement or 1
                end
            end
            callback(map)
        end
    )
end

return aerospace
