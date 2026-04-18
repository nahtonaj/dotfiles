-- Dispatcher: load the spaces widget implementation matching the active
-- window manager. /etc/window-manager-backend is written by nix-darwin
-- (see nix/hosts/window-manager.nix).

local function detect_backend()
    local f = io.open("/etc/window-manager-backend", "r")
    if not f then return "aerospace" end
    local s = (f:read("*a") or ""):gsub("%s+$", "")
    f:close()
    if s == "yabai" then return "yabai" end
    return "aerospace"
end

require("items.spaces_" .. detect_backend())
