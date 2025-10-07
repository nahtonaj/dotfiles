-- Function to determine the current display and set appropriate scale
local function get_display_scale()
  -- Log file for debugging
  local log_file = "/tmp/sketchybar_scale.log"
  local log = io.open(log_file, "a")
  log:write("\n--- Display scale check at " .. os.date() .. " ---\n")
  
  -- Get information about the current display
  local display_info = io.popen("system_profiler SPDisplaysDataType"):read("*all")
  
  -- Log the raw display info for debugging
  log:write("Display info:\n")
  log:write(display_info:sub(1, 500) .. "...\n") -- Log first 500 chars to avoid huge logs
  
  -- Check if the active display is the built-in display
  local is_builtin_active = display_info:match("Type: Built%-in") ~= nil
  local is_retina = display_info:match("Retina") ~= nil
  
  -- More reliable detection using multiple indicators
  local is_macbook_display = is_builtin_active or 
                            display_info:match("Apple Built%-in") ~= nil or
                            display_info:match("Built%-in Retina") ~= nil
  
  -- Determine scale factor
  -- local scale = (is_macbook_display and is_retina) and 1.5 or 0.7
  local scale = 1
  
  -- Log the detection results
  log:write("Built-in display detected: " .. tostring(is_macbook_display) .. "\n")
  log:write("Retina display detected: " .. tostring(is_retina) .. "\n")
  log:write("Using scale factor: " .. scale .. "\n")
  log:close()
  
  return scale
end

-- Get the appropriate scale factor for the current display
local scale = get_display_scale()

return {
  -- Display scale factor - automatically determined based on display
  scale_factor = scale,
  
  -- These values will be automatically scaled based on scale_factor
  paddings = 3,
  group_paddings = 5,

  icons = "sf-symbols", -- alternatively available: NerdFont

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
