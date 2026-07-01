require("items.apple")
require("items.menus")

-- Spaces module depends on the window manager (aerospace) which may not
-- be ready at startup.  Contain any failure so the rest of the bar loads.
local spaces_ok, spaces_err = pcall(require, "items.spaces")
if not spaces_ok then
    io.stderr:write("[sketchybar/items] spaces module failed: "
        .. tostring(spaces_err) .. "\n")
end

require("items.front_app")
require("items.calendar")
require("items.widgets")
require("items.media")