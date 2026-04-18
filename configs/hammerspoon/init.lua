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

hs.urlevent.bind("window_to_space", function(_, params)
    local target = nth_space(tonumber(params.n))
    local win = hs.window.focusedWindow()
    if target and win then
        hs.spaces.moveWindowToSpace(win:id(), target)
    end
end)

hs.urlevent.bind("window_to_space_and_follow", function(_, params)
    local target = nth_space(tonumber(params.n))
    local win = hs.window.focusedWindow()
    if not target then return end
    if win then
        hs.spaces.moveWindowToSpace(win:id(), target)
    end
    hs.spaces.gotoSpace(target)
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
