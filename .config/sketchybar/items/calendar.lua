local settings = require("settings")
local colors = require("colors")

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

local cal = sbar.add("item", {
  icon = {
    color = colors.white,
    padding_left = 12, -- Increased from 8 by factor of 1.5
    font = {
      style = settings.font.style_map["Black"],
      size = 18.0, -- Increased from 12.0 by factor of 1.5
    },
  },
  label = {
    color = colors.white,
    padding_right = 12, -- Increased from 8 by factor of 1.5
    width = 119, -- Increased from 79 by factor of 1.5
    align = "right",
    font = { family = settings.font.numbers },
  },
  position = "right",
  update_freq = 30,
  padding_left = 2, -- Increased from 1 by factor of ~1.5
  padding_right = 2, -- Increased from 1 by factor of ~1.5
  background = {
    color = colors.bg2,
    border_color = colors.black,
    border_width = 2 -- Increased from 1 by factor of ~1.5
  },
  click_script = "open -a 'Calendar'"
})

-- Double border for calendar using a single item bracket
sbar.add("bracket", { cal.name }, {
  background = {
    color = colors.transparent,
    height = 45, -- Increased from 30 by factor of 1.5
    border_color = colors.grey,
  }
})

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
 cal:set({ icon = os.date("%a. %b. %d"), label = os.date("%I:%M %p") })
end)
