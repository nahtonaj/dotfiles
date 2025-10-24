-- Pull in the wezterm API
local wezterm = require "wezterm"
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Configure your preferences:
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 16
-- config.enable_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.9
config.macos_window_background_blur = 10
config.color_scheme = "ForestBlue"

config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Make URLs with line breaks work better in tmux
-- This improves detection of URLs that wrap across lines
table.insert(config.hyperlink_rules, {
  -- Match URLs that might be wrapped across lines
  -- Matches common URL patterns more aggressively
  regex = [[(https?://[^\s,\)'"]+)]],
  format = '$1',
})

-- Match URLs without the protocol
table.insert(config.hyperlink_rules, {
  regex = [[\b[a-z0-9-]+\.[a-z]{2,}(?:[/?#][^\s,\)'"]*)?]],
  format = 'https://$0',
})

-- Example: Match file paths with line numbers (common in stack traces)
table.insert(config.hyperlink_rules, {
regex = [[\b\w+\.(\w+):(\d+)\b]],
format = 'file://$0',
})

-- Configure mouse behavior in tmux
-- By default, Shift+Click opens links when tmux has mouse mode enabled
config.bypass_mouse_reporting_modifiers = 'SHIFT'

-- Improve URL detection for wrapped text
-- This helps wezterm recognize URLs that span multiple visual lines
config.quick_select_patterns = {
  -- Match URLs more aggressively
  'https?://\\S+',
  -- Match common URL patterns without protocol
  '[a-z0-9-]+\\.[a-z]{2,}[/\\w\\-._~:/?#\\[\\]@!$&\'()*+,;=]*',
}

-- Optional: Require Ctrl+Click instead of Shift+Click
-- Uncomment if you prefer Ctrl as the modifier:
-- config.mouse_bindings = {
--   {
--     event = { Up = { streak = 1, button = 'Left' } },
--     mods = 'CTRL',
--     action = wezterm.action.OpenLinkAtMouseCursor,
--   },
-- }
    

-- config.mouse_bindings = {
--
--   -- Change the default click behavior so that it only selects
--   -- text and doesn't open hyperlinks
--   {
--     event = { Up = { streak = 1, button = 'Left' } },
--     mods = 'NONE',
--     action = act.CompleteSelection 'ClipboardAndPrimarySelection',
--   },
--
--   -- and make CTRL-Click open hyperlinks
--   {
--     event = { Up = { streak = 1, button = 'Left' } },
--     mods = 'CTRL',
--     action = act.OpenLinkAtMouseCursor,
--   },
--   -- NOTE that binding only the 'Up' event can give unexpected behaviors.
--   -- Read more below on the gotcha of binding an 'Up' event only.
-- }

-- Finally, return the configuration to wezterm
return config

