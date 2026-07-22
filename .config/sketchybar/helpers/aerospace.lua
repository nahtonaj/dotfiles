-- helpers/aerospace.lua
-- Thin CLI wrapper around the `aerospace` window manager.
--
-- SYNC NOTE: popen_lines (and the functions that use it) call io.popen
-- synchronously. This is intentional: get_workspaces, get_focused,
-- get_monitors, get_workspaces_for_monitor, and wait_for_aerospace all
-- run at module init time, before the sketchybar event loop starts.
-- Do NOT call them from event callbacks.
-- Use get_windows (sbar.exec-based) for any async / callback context.

local aerospace = {}

-- Internal sync helper: run cmd and return its output as a list of lines.
-- Init-time only; not safe to call from event callbacks.
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

-- Return list of all workspace names across all monitors.
-- Sync: call at init time only.
function aerospace.get_workspaces()
    return popen_lines(WORKSPACE_LIST_CMD)
end

-- Return the currently focused workspace name, or "" on failure.
-- Sync: call at init time only.
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
-- Sync: call at init time only.
function aerospace.get_monitors()
    local raw = popen_lines(MONITOR_COUNT_CMD)
    return tonumber(raw[1] or "1") or 1
end

-- Return workspace list for a given monitor index.
-- Sync: call at init time only.
function aerospace.get_workspaces_for_monitor(m)
    return popen_lines("aerospace list-workspaces --monitor " .. m)
end

-- Poll aerospace until it responds or ~10 s elapsed.
-- Returns true if aerospace is ready, false on timeout.
-- Sync: call at init time only.
function aerospace.wait_for_aerospace()
    for attempt = 1, 20 do
        local result = popen_lines(FOCUSED_CMD)
        if result[1] and result[1] ~= "" then return true end
        if attempt < 20 then os.execute("sleep 0.5") end
    end
    return false
end

-- Async: switch aerospace to the given workspace.
function aerospace.focus_workspace(ws)
    sbar.exec("aerospace workspace " .. ws)
end

return aerospace
