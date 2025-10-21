local colors = require("colors")
local icons = require("icons")

return {
    -- Display scaling configuration
    displays = {
        builtin = 1.6,      -- Built-in retina display scale
        external = 1.0,     -- Default external display scale
        -- You can add specific display scales by resolution:
        -- ["3840x2160"] = 1.2,  -- Example for 4K display
        -- ["2560x1440"] = 1.0,  -- Example for 1440p display
    },
    builtin_scale = 1.6,  -- Fallback for compatibility

    -- Base dimensions (external display)
    paddings = 3,
    group_paddings = 5,
    calendar_width = 80,
    modes = {
        main = {
            icon = icons.apple,
            color = colors.white
        },
        service = {
            icon = icons.nuke,
            color = 0xffff9e64
        }
    },
    bar = {
        height = 36,                   -- External display height
        padding = {
            x = 10,
            y = 0
        },
        background = colors.bar.bg
    },
    items = {
        height = 26,
        gap = 5,
        padding = {
            right = 16,
            left = 12,
            top = 0,
            bottom = 0
        },
        -- default_color = function(workspace)
        --     return colors.rainbow[workspace + 1]
        -- end,
        default_color = function(workspace)
                return colors.grey
        end,
        highlight_color = function(workspace)
            return colors.white
        end,
        colors = {
            background = colors.bg1
        },
        corner_radius = 6
    },

    icons = "sketchybar-app-font:Regular:16.0", -- alternatively available: NerdFont

  -- This is a font configuration for SF Pro and SF Mono (installed manually)
    font = require("helpers.default_font"),

  -- Alternatively, this is a font config for JetBrainsMono Nerd Font
  -- font = {
  --   text = "JetBrainsMono Nerd Font", -- Used for text
  --   numbers = "JetBrainsMono Nerd Font", -- Used for numbers
  --   style_map = {
  --     ["Regular"] = "Regular",
  --     ["Semibold"] = "Medium",
  --     ["Bold"] = "SemiBold",
  --     ["Heavy"] = "Bold",
  --     ["Black"] = "ExtraBold",
  --   },
  -- },
}
