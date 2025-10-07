-- Require the sketchybar module
sbar = require("sketchybar")

-- Set the bar name, if you are using another bar instance than sketchybar
-- sbar.set_bar_name("bottom_bar")

-- Kill any existing display detector processes
sbar.exec("pkill -f 'display_detector/display_change.sh' || true")
sbar.exec("pkill -f 'display_detector/display_watcher.sh' || true")

-- Start the display change detector in the background
-- Use the new more reliable watcher script
sbar.exec("$HOME/.config/sketchybar/helpers/display_detector/display_watcher.sh &")

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()
require("bar")
require("default")
require("items")
sbar.end_config()

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
