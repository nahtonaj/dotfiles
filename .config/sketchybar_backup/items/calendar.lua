local settings = require("settings")
local colors = require("colors")

local scale = settings.scale_factor

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings * scale })

local cal = sbar.add("item", {
  icon = {
    color = colors.white,
    padding_left = 8 * scale,
    font = {
      style = settings.font.style_map["Black"],
      size = 12.0 * scale,
    },
  },
  label = {
    color = colors.white,
    padding_right = 8 * scale,
    width = 79 * scale,
    align = "right",
    font = { family = settings.font.numbers },
  },
  position = "right",
  update_freq = 30,
  padding_left = math.max(1, math.floor(1 * scale)),
  padding_right = math.max(1, math.floor(1 * scale)),
  background = {
    color = colors.bg2,
    border_color = colors.black,
    border_width = math.max(1, math.floor(1 * scale))
  },
  click_script = "open -a 'Calendar'"
})

-- Double border for calendar using a single item bracket
sbar.add("bracket", { cal.name }, {
  background = {
    color = colors.transparent,
    height = 30 * scale,
    border_color = colors.grey,
  }
})

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings * scale })

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
 cal:set({ icon = os.date("%a. %b. %d"), label = os.date("%I:%M %p") })
end)
