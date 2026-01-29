local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local display = require("helpers.display_settings")

local scale = display.get_scale()
local popup_width = 180 * scale

-- Pomodoro state
local pomodoro_state = {
    running = false,
    paused = false,
    remaining_seconds = 0,
    mode = "work",  -- "work" or "break"
    work_duration = 25 * 60,  -- 25 minutes
    short_break = 5 * 60,     -- 5 minutes
    long_break = 15 * 60,     -- 15 minutes
    sessions_completed = 0
}

local pomodoro = sbar.add("item", "widgets.pomodoro", {
    position = "right",
    icon = {
        string = "🍅",
        font = { size = 14.0 * scale },
        padding_left = 8 * scale,
        padding_right = 0
    },
    label = {
        string = "25:00",
        font = {
            family = settings.font.numbers,
            size = 12.0 * scale
        },
        padding_right = 8 * scale,
        color = colors.grey
    },
    popup = {
        align = "center",
        height = 30 * scale
    }
})

-- Popup controls
local pomodoro_status = sbar.add("item", {
    position = "popup." .. pomodoro.name,
    icon = {
        string = "Status:",
        width = popup_width / 2,
        align = "left"
    },
    label = {
        string = "Idle",
        width = popup_width / 2,
        align = "right",
        color = colors.grey
    },
    background = {
        height = 2 * scale,
        color = colors.grey,
        y_offset = -12 * scale
    }
})

local pomodoro_sessions = sbar.add("item", {
    position = "popup." .. pomodoro.name,
    icon = {
        string = "Sessions:",
        width = popup_width / 2,
        align = "left"
    },
    label = {
        string = "0",
        width = popup_width / 2,
        align = "right"
    }
})

-- Control buttons
local pomodoro_start = sbar.add("item", "pomodoro.start", {
    position = "popup." .. pomodoro.name,
    background = {
        color = colors.green,
        corner_radius = 5 * scale,
        height = 24 * scale
    },
    icon = { drawing = false },
    label = {
        string = "▶ Start Work",
        color = colors.black,
        align = "center",
        width = popup_width,
        font = { style = settings.font.style_map["Bold"] }
    }
})

local pomodoro_break = sbar.add("item", "pomodoro.break", {
    position = "popup." .. pomodoro.name,
    background = {
        color = colors.blue,
        corner_radius = 5 * scale,
        height = 24 * scale
    },
    icon = { drawing = false },
    label = {
        string = "☕ Short Break",
        color = colors.black,
        align = "center",
        width = popup_width,
        font = { style = settings.font.style_map["Bold"] }
    }
})

local pomodoro_reset = sbar.add("item", "pomodoro.reset", {
    position = "popup." .. pomodoro.name,
    background = {
        color = colors.red,
        corner_radius = 5 * scale,
        height = 24 * scale
    },
    icon = { drawing = false },
    label = {
        string = "⏹ Reset",
        color = colors.white,
        align = "center",
        width = popup_width,
        font = { style = settings.font.style_map["Bold"] }
    }
})

sbar.add("bracket", "widgets.pomodoro.bracket", { pomodoro.name }, {
    background = { color = colors.bg1 }
})

sbar.add("item", "widgets.pomodoro.padding", {
    position = "right",
    width = settings.group_paddings * scale
})

local function format_time(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

local function update_display()
    local time_str = format_time(pomodoro_state.remaining_seconds)
    local color = colors.grey
    local status = "Idle"

    if pomodoro_state.running then
        if pomodoro_state.mode == "work" then
            color = colors.red
            status = "Working"
        else
            color = colors.green
            status = "Break"
        end
    elseif pomodoro_state.paused then
        color = colors.yellow
        status = "Paused"
    end

    pomodoro:set({
        label = {
            string = time_str,
            color = color
        }
    })

    pomodoro_status:set({
        label = {
            string = status,
            color = color
        }
    })

    pomodoro_sessions:set({
        label = { string = tostring(pomodoro_state.sessions_completed) }
    })
end

local function notify(title, message)
    sbar.exec(string.format(
        'osascript -e \'display notification "%s" with title "%s" sound name "Glass"\'',
        message, title
    ))
end

local function start_timer(duration, mode)
    pomodoro_state.running = true
    pomodoro_state.paused = false
    pomodoro_state.remaining_seconds = duration
    pomodoro_state.mode = mode
    update_display()

    pomodoro_start:set({
        label = { string = "⏸ Pause" },
        background = { color = colors.yellow }
    })
end

local function stop_timer()
    pomodoro_state.running = false
    pomodoro_state.paused = false
    pomodoro_state.remaining_seconds = pomodoro_state.work_duration
    pomodoro_state.mode = "work"
    update_display()

    pomodoro_start:set({
        label = { string = "▶ Start Work" },
        background = { color = colors.green }
    })
end

local function pause_timer()
    pomodoro_state.running = false
    pomodoro_state.paused = true
    update_display()

    pomodoro_start:set({
        label = { string = "▶ Resume" },
        background = { color = colors.green }
    })
end

local function resume_timer()
    pomodoro_state.running = true
    pomodoro_state.paused = false
    update_display()

    pomodoro_start:set({
        label = { string = "⏸ Pause" },
        background = { color = colors.yellow }
    })
end

-- Timer tick (runs every second when active)
sbar.add("item", "pomodoro.ticker", {
    drawing = false,
    update_freq = 1
}):subscribe("routine", function()
    if pomodoro_state.running and pomodoro_state.remaining_seconds > 0 then
        pomodoro_state.remaining_seconds = pomodoro_state.remaining_seconds - 1
        update_display()

        if pomodoro_state.remaining_seconds == 0 then
            if pomodoro_state.mode == "work" then
                pomodoro_state.sessions_completed = pomodoro_state.sessions_completed + 1
                notify("Pomodoro Complete!", "Time for a break! Sessions: " .. pomodoro_state.sessions_completed)
                -- Auto-start break
                if pomodoro_state.sessions_completed % 4 == 0 then
                    start_timer(pomodoro_state.long_break, "break")
                else
                    start_timer(pomodoro_state.short_break, "break")
                end
            else
                notify("Break Over!", "Ready to work?")
                stop_timer()
            end
        end
    end
end)

-- Event handlers
pomodoro:subscribe("mouse.clicked", function(env)
    pomodoro:set({ popup = { drawing = "toggle" } })
end)

pomodoro:subscribe("mouse.exited.global", function(env)
    pomodoro:set({ popup = { drawing = false } })
end)

pomodoro_start:subscribe("mouse.clicked", function(env)
    if pomodoro_state.running then
        pause_timer()
    elseif pomodoro_state.paused then
        resume_timer()
    else
        start_timer(pomodoro_state.work_duration, "work")
    end
end)

pomodoro_break:subscribe("mouse.clicked", function(env)
    start_timer(pomodoro_state.short_break, "break")
end)

pomodoro_reset:subscribe("mouse.clicked", function(env)
    stop_timer()
    pomodoro_state.sessions_completed = 0
    update_display()
end)

-- Initialize display
update_display()
