local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local display = require("helpers.display_settings")

local scale = display.get_scale()
local popup_width = 280 * scale

-- Weather icons mapping (WMO weather codes)
local weather_icons = {
    [0] = "☀️",   -- Clear sky
    [1] = "🌤️",   -- Mainly clear
    [2] = "⛅",   -- Partly cloudy
    [3] = "☁️",   -- Overcast
    [45] = "🌫️",  -- Fog
    [48] = "🌫️",  -- Depositing rime fog
    [51] = "🌧️",  -- Light drizzle
    [53] = "🌧️",  -- Moderate drizzle
    [55] = "🌧️",  -- Dense drizzle
    [56] = "🌨️",  -- Light freezing drizzle
    [57] = "🌨️",  -- Dense freezing drizzle
    [61] = "🌧️",  -- Slight rain
    [63] = "🌧️",  -- Moderate rain
    [65] = "🌧️",  -- Heavy rain
    [66] = "🌨️",  -- Light freezing rain
    [67] = "🌨️",  -- Heavy freezing rain
    [71] = "❄️",   -- Slight snow
    [73] = "❄️",   -- Moderate snow
    [75] = "❄️",   -- Heavy snow
    [77] = "❄️",   -- Snow grains
    [80] = "🌦️",  -- Slight rain showers
    [81] = "🌦️",  -- Moderate rain showers
    [82] = "🌦️",  -- Violent rain showers
    [85] = "🌨️",  -- Slight snow showers
    [86] = "🌨️",  -- Heavy snow showers
    [95] = "⛈️",   -- Thunderstorm
    [96] = "⛈️",   -- Thunderstorm with slight hail
    [99] = "⛈️",   -- Thunderstorm with heavy hail
}

local weather_descriptions = {
    [0] = "Clear sky",
    [1] = "Mainly clear",
    [2] = "Partly cloudy",
    [3] = "Overcast",
    [45] = "Fog",
    [48] = "Freezing fog",
    [51] = "Light drizzle",
    [53] = "Drizzle",
    [55] = "Dense drizzle",
    [56] = "Freezing drizzle",
    [57] = "Heavy freezing drizzle",
    [61] = "Light rain",
    [63] = "Rain",
    [65] = "Heavy rain",
    [66] = "Light freezing rain",
    [67] = "Freezing rain",
    [71] = "Light snow",
    [73] = "Snow",
    [75] = "Heavy snow",
    [77] = "Snow grains",
    [80] = "Light showers",
    [81] = "Showers",
    [82] = "Heavy showers",
    [85] = "Light snow showers",
    [86] = "Heavy snow showers",
    [95] = "Thunderstorm",
    [96] = "Thunderstorm with hail",
    [99] = "Severe thunderstorm",
}

local weather = sbar.add("item", "widgets.weather", {
    position = "right",
    icon = {
        string = "🌡️",
        font = {
            size = 14.0 * scale
        },
        padding_left = 8 * scale,
        padding_right = 0
    },
    label = {
        string = "??°",
        font = {
            family = settings.font.numbers,
            size = 13.0 * scale
        },
        padding_right = 8 * scale
    },
    update_freq = 1800,  -- Update every 30 minutes
    popup = {
        align = "center",
        height = 30 * scale
    }
})

-- Popup items for forecast
local weather_location = sbar.add("item", {
    position = "popup." .. weather.name,
    icon = {
        string = "📍",
        width = 20 * scale
    },
    label = {
        string = "Loading...",
        width = popup_width - 20 * scale
    },
    background = {
        height = 2 * scale,
        color = colors.grey,
        y_offset = -12 * scale
    }
})

local weather_condition = sbar.add("item", {
    position = "popup." .. weather.name,
    icon = {
        string = "Condition:",
        width = popup_width / 2,
        align = "left"
    },
    label = {
        string = "---",
        width = popup_width / 2,
        align = "right"
    }
})

local weather_humidity = sbar.add("item", {
    position = "popup." .. weather.name,
    icon = {
        string = "Humidity:",
        width = popup_width / 2,
        align = "left"
    },
    label = {
        string = "??%",
        width = popup_width / 2,
        align = "right"
    }
})

local weather_wind = sbar.add("item", {
    position = "popup." .. weather.name,
    icon = {
        string = "Wind:",
        width = popup_width / 2,
        align = "left"
    },
    label = {
        string = "?? mph",
        width = popup_width / 2,
        align = "right"
    }
})

local weather_high_low = sbar.add("item", {
    position = "popup." .. weather.name,
    icon = {
        string = "High / Low:",
        width = popup_width / 2,
        align = "left"
    },
    label = {
        string = "??° / ??°",
        width = popup_width / 2,
        align = "right"
    }
})

sbar.add("bracket", "widgets.weather.bracket", { weather.name }, {
    background = { color = colors.bg1 }
})

sbar.add("item", "widgets.weather.padding", {
    position = "right",
    width = settings.group_paddings * scale
})

local function update_weather()
    -- First get location from IP (using ipinfo.io)
    sbar.exec("curl -s 'https://ipinfo.io/json' 2>/dev/null", function(location_result)
        local lat, lon, city

        -- Parse location JSON
        city = location_result:match('"city"%s*:%s*"([^"]+)"')
        local loc = location_result:match('"loc"%s*:%s*"([^"]+)"')

        if loc then
            lat, lon = loc:match("([^,]+),([^,]+)")
        end

        if not lat or not lon then
            -- Fallback to a default location (San Francisco)
            lat, lon = "37.7749", "-122.4194"
            city = "San Francisco"
        end

        -- Fetch weather from Open-Meteo (free, no API key)
        local weather_url = string.format(
            "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto",
            lat, lon
        )

        sbar.exec("curl -s '" .. weather_url .. "' 2>/dev/null", function(weather_result)
            -- Parse current weather
            local temp = weather_result:match('"temperature_2m"%s*:%s*([%d%.%-]+)')
            local humidity = weather_result:match('"relative_humidity_2m"%s*:%s*(%d+)')
            local weather_code = weather_result:match('"weather_code"%s*:%s*(%d+)')
            local wind = weather_result:match('"wind_speed_10m"%s*:%s*([%d%.]+)')

            -- Parse daily high/low
            local high = weather_result:match('"temperature_2m_max"%s*:%s*%[([%d%.%-]+)')
            local low = weather_result:match('"temperature_2m_min"%s*:%s*%[([%d%.%-]+)')

            if temp then
                local code = tonumber(weather_code) or 0
                local icon = weather_icons[code] or "🌡️"
                local desc = weather_descriptions[code] or "Unknown"

                weather:set({
                    icon = { string = icon },
                    label = { string = math.floor(tonumber(temp) + 0.5) .. "°F" }
                })

                weather_location:set({
                    label = { string = city or "Unknown" }
                })

                weather_condition:set({
                    label = { string = desc }
                })

                weather_humidity:set({
                    label = { string = (humidity or "??") .. "%" }
                })

                weather_wind:set({
                    label = { string = math.floor(tonumber(wind or 0) + 0.5) .. " mph" }
                })

                if high and low then
                    weather_high_low:set({
                        label = { string = math.floor(tonumber(high) + 0.5) .. "° / " .. math.floor(tonumber(low) + 0.5) .. "°" }
                    })
                end
            else
                weather:set({
                    icon = { string = "⚠️" },
                    label = { string = "N/A" }
                })
            end
        end)
    end)
end

weather:subscribe({"routine", "forced", "system_woke"}, update_weather)

weather:subscribe("mouse.clicked", function(env)
    weather:set({ popup = { drawing = "toggle" } })
end)

weather:subscribe("mouse.exited.global", function(env)
    weather:set({ popup = { drawing = false } })
end)
