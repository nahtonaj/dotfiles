-- Hammerspoon config: SIP-free cross-space ops for yabai.
-- skhd triggers these via URL scheme:
--   open "hammerspoon://space_focus?n=1"
--   open "hammerspoon://window_to_space?n=1"
--   open "hammerspoon://window_to_space_and_follow?n=1"
--
-- Space index N is global across displays, matching yabai's numbering:
-- spaces are flattened in screen order (left-to-right / top-to-bottom).

-- Globally ordered list of space ids. We re-query each invocation so
-- that adding/removing macOS spaces at runtime is picked up.
local function ordered_space_ids()
    local by_display = hs.spaces.allSpaces()
    local out = {}
    for _, screen in ipairs(hs.screen.allScreens()) do
        local uuid = screen:getUUID()
        local spaces = by_display[uuid]
        if spaces then
            for _, id in ipairs(spaces) do
                table.insert(out, id)
            end
        end
    end
    return out
end

local function nth_space(n)
    if not n then return nil end
    return ordered_space_ids()[n]
end

hs.urlevent.bind("space_focus", function(_, params)
    local target = nth_space(tonumber(params.n))
    if target then hs.spaces.gotoSpace(target) end
end)

-- `force=true` so windows that aren't strictly "standard" still move.
-- moveWindowToSpace returns (true) or (nil, errMsg) — surface failures.
local function move_window_to(target)
    local win = hs.window.focusedWindow()
    if not win then return false, "no focused window" end
    local ok, err = hs.spaces.moveWindowToSpace(win, target, true)
    if not ok then return false, tostring(err) end
    return true
end

hs.urlevent.bind("window_to_space", function(_, params)
    local target = nth_space(tonumber(params.n))
    if not target then return end
    local ok, err = move_window_to(target)
    if not ok then hs.alert.show("move failed: " .. err) end
end)

hs.urlevent.bind("window_to_space_and_follow", function(_, params)
    local target = nth_space(tonumber(params.n))
    if not target then return end
    local ok, err = move_window_to(target)
    if not ok then hs.alert.show("move failed: " .. err) end
    -- Small delay so the move completes before we follow; WindowServer
    -- processes the request asynchronously.
    hs.timer.doAfter(0.05, function() hs.spaces.gotoSpace(target) end)
end)

-- Auto-reload when this file changes — handy since it's mkOutOfStoreSymlink'd
-- from the dotfiles repo.
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
    for _, f in ipairs(files) do
        if f:match("%.lua$") then
            hs.reload()
            return
        end
    end
end):start()

hs.alert.show("Hammerspoon loaded")
