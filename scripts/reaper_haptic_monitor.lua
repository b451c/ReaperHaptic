-- ReaperHaptic Monitor Script
-- Monitors REAPER events and sends OSC messages to the ReaperHaptic plugin
-- Author: falami.studio
-- Version: 1.1 (with GUI)

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local CONFIG = {
    -- OSC settings
    osc_host = "127.0.0.1",
    osc_port = 9000,

    -- Monitoring intervals (seconds)
    update_interval = 0.03,     -- ~30 FPS monitoring

    -- Snap detection
    snap_threshold = 0.001,      -- Threshold in seconds for snap detection

    -- Clipping detection
    clip_threshold_db = 0.0,     -- dB threshold for clipping
    clip_debounce = 0.2,         -- Debounce time for clipping

    -- Debug output
    debug = false,

    -- Event toggles (controlled by GUI)
    events = {
        item_snap = true,
        playhead = true,
        markers = true,
        selection = true,
        clipping = true,
        record = true,
        play = true,
        render = true
    }
}

-- ============================================================================
-- GUI STATE
-- ============================================================================

local gui = {
    -- Window dimensions
    w = 220,
    h_full = 320,
    h_mini = 44,
    h = 320,

    -- Window state
    visible = true,
    collapsed = false,
    was_closed = false,
    docked = false,

    -- LED state
    led_on = false,
    led_time = 0,
    led_duration = 0.15,

    -- Mouse state
    mouse_last_cap = 0,
    last_click_time = 0,

    -- Colors
    colors = {
        bg = {0.18, 0.18, 0.20},
        header = {0.12, 0.12, 0.14},
        text = {0.9, 0.9, 0.9},
        text_dim = {0.5, 0.5, 0.5},
        checkbox_on = {0.2, 0.7, 0.3},
        checkbox_off = {0.3, 0.3, 0.35},
        led_on = {0.2, 0.9, 0.3},
        led_off = {0.25, 0.25, 0.28},
        border = {0.3, 0.3, 0.35},
        btn_hover = {0.25, 0.25, 0.28}
    },

    -- Toggle definitions
    toggles = {
        { key = "item_snap", label = "Item Snap" },
        { key = "playhead", label = "Playhead" },
        { key = "markers", label = "Markers" },
        { key = "selection", label = "Selection" },
        { key = "clipping", label = "Clipping" },
        { key = "record", label = "Record" },
        { key = "play", label = "Play" },
        { key = "render", label = "Render" }
    }
}

-- ============================================================================
-- SETTINGS PERSISTENCE
-- ============================================================================

local function saveSettings()
    local settings = ""
    for key, val in pairs(CONFIG.events) do
        settings = settings .. key .. "=" .. (val and "1" or "0") .. ";"
    end
    reaper.SetExtState("ReaperHaptic", "events", settings, true)

    -- Save GUI state
    reaper.SetExtState("ReaperHaptic", "collapsed", gui.collapsed and "1" or "0", true)
    reaper.SetExtState("ReaperHaptic", "docked", gui.docked and "1" or "0", true)
end

local function loadSettings()
    local settings = reaper.GetExtState("ReaperHaptic", "events")
    if settings ~= "" then
        for key, val in string.gmatch(settings, "(%w+)=(%d);") do
            if CONFIG.events[key] ~= nil then
                CONFIG.events[key] = (val == "1")
            end
        end
    end

    -- Load GUI state
    local collapsed = reaper.GetExtState("ReaperHaptic", "collapsed")
    gui.collapsed = (collapsed == "1")
    gui.h = gui.collapsed and gui.h_mini or gui.h_full

    local docked = reaper.GetExtState("ReaperHaptic", "docked")
    gui.docked = (docked == "1")
end

-- ============================================================================
-- GUI DRAWING FUNCTIONS
-- ============================================================================

local function setColor(color)
    gfx.set(color[1], color[2], color[3], 1)
end

local function drawRoundRect(x, y, w, h, r)
    -- Simple rectangle (REAPER gfx doesn't have native rounded rect)
    gfx.rect(x, y, w, h, 1)
end

local function drawLED(x, y, on)
    local radius = 8
    if on then
        -- Glow effect
        setColor({0.1, 0.5, 0.15})
        gfx.circle(x, y, radius + 3, 1)
        setColor(gui.colors.led_on)
    else
        setColor(gui.colors.led_off)
    end
    gfx.circle(x, y, radius, 1)

    -- Border
    setColor(gui.colors.border)
    gfx.circle(x, y, radius, 0)
end

local function drawCheckbox(x, y, checked)
    local size = 16
    if checked then
        setColor(gui.colors.checkbox_on)
        gfx.rect(x, y, size, size, 1)
        -- Checkmark
        setColor({1, 1, 1})
        gfx.line(x + 3, y + 8, x + 6, y + 12)
        gfx.line(x + 6, y + 12, x + 13, y + 4)
    else
        setColor(gui.colors.checkbox_off)
        gfx.rect(x, y, size, size, 1)
    end
    -- Border
    setColor(gui.colors.border)
    gfx.rect(x, y, size, size, 0)

    return x, y, size, size
end

local function drawToggle(x, y, label, enabled, index)
    local checkbox_x, checkbox_y, checkbox_w, checkbox_h = drawCheckbox(x, y, enabled)

    setColor(enabled and gui.colors.text or gui.colors.text_dim)
    gfx.x = x + 24
    gfx.y = y + 1
    gfx.drawstr(label)

    -- Store hit area for click detection
    gui.toggles[index].hit = {
        x = x,
        y = y,
        w = gui.w - 40,
        h = 20
    }
end

local function drawCollapseButton(x, y, collapsed)
    local size = 12
    setColor(gui.colors.text_dim)

    if collapsed then
        -- Draw "+"
        gfx.line(x + 2, y + size/2, x + size - 2, y + size/2)
        gfx.line(x + size/2, y + 2, x + size/2, y + size - 2)
    else
        -- Draw "-"
        gfx.line(x + 2, y + size/2, x + size - 2, y + size/2)
    end

    gui.collapse_btn = { x = x - 5, y = y - 5, w = size + 10, h = size + 10 }
end

local function drawDockButton(x, y, docked)
    local size = 14
    setColor(gui.colors.text_dim)

    -- Draw dock icon (rectangle with arrow or pinned icon)
    if docked then
        -- Filled rectangle (docked)
        gfx.rect(x + 2, y + 2, size - 4, size - 4, 1)
    else
        -- Empty rectangle with corner (undocked)
        gfx.rect(x + 2, y + 2, size - 4, size - 4, 0)
        gfx.line(x + size - 5, y + 2, x + size - 2, y + 2)
        gfx.line(x + size - 2, y + 2, x + size - 2, y + 5)
    end

    gui.dock_btn = { x = x - 3, y = y - 3, w = size + 6, h = size + 6 }
end

local function toggleDock()
    gui.docked = not gui.docked
    if gui.docked then
        gfx.dock(1)  -- Dock to default position
    else
        gfx.dock(0)  -- Undock
    end
    saveSettings()
end

local function drawGui()
    -- Check if window is still open
    local char = gfx.getchar()

    -- Window was closed - keep running in background
    if char == -1 then
        gui.visible = false
        gui.was_closed = true
        return true  -- Return true to keep script running!
    end

    -- Check for 'D' key to toggle dock
    if char == string.byte('d') or char == string.byte('D') then
        toggleDock()
    end

    -- Sync dock state with actual gfx dock state
    local current_dock = gfx.dock(-1)
    gui.docked = (current_dock ~= 0)

    -- Clear background
    setColor(gui.colors.bg)
    gfx.rect(0, 0, gui.w, gui.h_full, 1)

    -- Header
    setColor(gui.colors.header)
    gfx.rect(0, 0, gui.w, 40, 1)

    -- Collapse/Expand button (highlighted on hover)
    local btn = gui.collapse_btn
    if btn and gfx.mouse_x >= btn.x and gfx.mouse_x <= btn.x + btn.w and
       gfx.mouse_y >= btn.y and gfx.mouse_y <= btn.y + btn.h then
        setColor(gui.colors.btn_hover)
        gfx.rect(btn.x, btn.y, btn.w, btn.h, 1)
    end
    drawCollapseButton(10, 14, gui.collapsed)

    -- Dock button (highlighted on hover)
    local dock_btn = gui.dock_btn
    if dock_btn and gfx.mouse_x >= dock_btn.x and gfx.mouse_x <= dock_btn.x + dock_btn.w and
       gfx.mouse_y >= dock_btn.y and gfx.mouse_y <= dock_btn.y + dock_btn.h then
        setColor(gui.colors.btn_hover)
        gfx.rect(dock_btn.x, dock_btn.y, dock_btn.w, dock_btn.h, 1)
    end
    drawDockButton(gui.w - 55, 13, gui.docked)

    -- Title
    setColor(gui.colors.text)
    gfx.setfont(1, "Arial", 14, 98) -- Bold
    gfx.x = 28
    gfx.y = 12
    gfx.drawstr("ReaperHaptic")

    -- LED
    local now = reaper.time_precise()
    if gui.led_on and (now - gui.led_time) > gui.led_duration then
        gui.led_on = false
    end
    drawLED(gui.w - 25, 20, gui.led_on)

    -- Separator
    setColor(gui.colors.border)
    gfx.line(0, 40, gui.w, 40)

    -- If collapsed, draw minimal info and stop
    if gui.collapsed then
        setColor(gui.colors.text_dim)
        gfx.setfont(1, "Arial", 11, 0)
        gfx.x = 15
        gfx.y = 50
        gfx.drawstr("(click + to expand)")
        gfx.update()
        return true
    end

    -- Toggles
    gfx.setfont(1, "Arial", 13, 0)
    local toggle_y = 55
    local toggle_spacing = 28

    for i, toggle in ipairs(gui.toggles) do
        drawToggle(20, toggle_y, toggle.label, CONFIG.events[toggle.key], i)
        toggle_y = toggle_y + toggle_spacing
    end

    -- Footer
    setColor(gui.colors.border)
    gfx.line(0, gui.h_full - 25, gui.w, gui.h_full - 25)

    setColor(gui.colors.text_dim)
    gfx.setfont(1, "Arial", 10, 0)
    gfx.x = 15
    gfx.y = gui.h_full - 18
    gfx.drawstr("OSC: " .. CONFIG.osc_host .. ":" .. CONFIG.osc_port)

    gfx.update()
    return true
end

-- ============================================================================
-- GUI MOUSE HANDLING
-- ============================================================================

local function handleMouse()
    if not gui.visible then return end

    local mouse_cap = gfx.mouse_cap
    local mouse_x = gfx.mouse_x
    local mouse_y = gfx.mouse_y

    -- Detect click (mouse down this frame, was up last frame)
    local clicked = (mouse_cap & 1 == 1) and (gui.mouse_last_cap & 1 == 0)

    if clicked then
        -- Check collapse button click
        local btn = gui.collapse_btn
        if btn and mouse_x >= btn.x and mouse_x <= btn.x + btn.w and
           mouse_y >= btn.y and mouse_y <= btn.y + btn.h then
            gui.collapsed = not gui.collapsed
            saveSettings()
        -- Check dock button click
        elseif gui.dock_btn and mouse_x >= gui.dock_btn.x and mouse_x <= gui.dock_btn.x + gui.dock_btn.w and
               mouse_y >= gui.dock_btn.y and mouse_y <= gui.dock_btn.y + gui.dock_btn.h then
            toggleDock()
        elseif not gui.collapsed then
            -- Check each toggle (only if not collapsed)
            for i, toggle in ipairs(gui.toggles) do
                if toggle.hit then
                    local h = toggle.hit
                    if mouse_x >= h.x and mouse_x <= h.x + h.w and
                       mouse_y >= h.y and mouse_y <= h.y + h.h then
                        CONFIG.events[toggle.key] = not CONFIG.events[toggle.key]
                        saveSettings()
                        break
                    end
                end
            end
        end
    end

    gui.mouse_last_cap = mouse_cap
end

-- Show window function (can be called to restore hidden window)
local function showWindow()
    if not gui.visible then
        gui.visible = true
        gui.was_closed = false
        gfx.init("ReaperHaptic", gui.w, gui.h, 0, 100, 100)
    end
end

-- ============================================================================
-- GUI INITIALIZATION
-- ============================================================================

local function initGui()
    -- Update height based on collapsed state
    gui.h = gui.collapsed and gui.h_mini or gui.h_full

    -- Initialize graphics window (dock parameter: 0=normal, 1=docked)
    local dock_state = gui.docked and 1 or 0
    gfx.init("ReaperHaptic", gui.w, gui.h, dock_state, 100, 100)
    gui.visible = true

    -- Try to set always on top when not docked (works on some systems with JS extension)
    if not gui.docked then
        local hwnd = reaper.JS_Window_Find and reaper.JS_Window_Find("ReaperHaptic", true)
        if hwnd then
            reaper.JS_Window_SetZOrder(hwnd, "TOPMOST")
        end
    end

    gfx.setfont(1, "Arial", 13, 0)
end

-- ============================================================================
-- LED FLASH FUNCTION
-- ============================================================================

local function flashLED()
    gui.led_on = true
    gui.led_time = reaper.time_precise()
end

-- ============================================================================
-- OSC SENDER (using LuaSocket or fallback)
-- ============================================================================

local socket = nil
local udp = nil

-- Add REAPER Scripts folder to package paths
local function setupPackagePaths()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@(.+[/\\])")
    if script_path then
        package.path = script_path .. "?.lua;" .. package.path
        package.cpath = script_path .. "socket/?.so;" .. script_path .. "?.so;" .. package.cpath
    end
end

-- Try to load LuaSocket
local function initSocket()
    setupPackagePaths()
    local success, sock = pcall(require, "socket")
    if success then
        socket = sock
        udp = socket.udp()
        udp:setpeername(CONFIG.osc_host, CONFIG.osc_port)
        if CONFIG.debug then
            reaper.ShowConsoleMsg("ReaperHaptic: LuaSocket loaded successfully\n")
        end
        return true
    else
        reaper.ShowConsoleMsg("ReaperHaptic: LuaSocket not found.\n")
        reaper.ShowConsoleMsg("Install from: https://github.com/mavriq-dev/mavriq-lua-sockets\n")
        return false
    end
end

-- Pack a float as 32-bit big-endian IEEE 754 (without math.frexp)
local function packFloat(f)
    if f == 0 then
        return string.char(0, 0, 0, 0)
    end

    local sign = 0
    if f < 0 then
        sign = 1
        f = -f
    end

    local exponent = 0
    local mantissa = f

    if mantissa >= 2 then
        while mantissa >= 2 do
            mantissa = mantissa / 2
            exponent = exponent + 1
        end
    elseif mantissa < 1 then
        while mantissa < 1 do
            mantissa = mantissa * 2
            exponent = exponent - 1
        end
    end

    exponent = exponent + 127
    mantissa = (mantissa - 1) * 8388608
    mantissa = math.floor(mantissa + 0.5)

    local b0 = mantissa % 256
    local b1 = math.floor(mantissa / 256) % 256
    local b2 = math.floor(mantissa / 65536) % 128 + (exponent % 2) * 128
    local b3 = sign * 128 + math.floor(exponent / 2)

    return string.char(b3, b2, b1, b0)
end

local function packInt(i)
    local b0 = i % 256
    local b1 = math.floor(i / 256) % 256
    local b2 = math.floor(i / 65536) % 256
    local b3 = math.floor(i / 16777216) % 256
    return string.char(b3, b2, b1, b0)
end

local function padString(s)
    local len = #s + 1
    local padded = s .. string.char(0)
    local padding = (4 - (len % 4)) % 4
    for i = 1, padding do
        padded = padded .. string.char(0)
    end
    return padded
end

local function createOscMessage(address, ...)
    local args = {...}
    local msg = padString(address)

    local typetag = ","
    for _, arg in ipairs(args) do
        if type(arg) == "number" then
            if arg == math.floor(arg) and arg >= -2147483648 and arg <= 2147483647 then
                typetag = typetag .. "i"
            else
                typetag = typetag .. "f"
            end
        elseif type(arg) == "string" then
            typetag = typetag .. "s"
        end
    end
    msg = msg .. padString(typetag)

    for _, arg in ipairs(args) do
        if type(arg) == "number" then
            if arg == math.floor(arg) and arg >= -2147483648 and arg <= 2147483647 then
                msg = msg .. packInt(arg)
            else
                msg = msg .. packFloat(arg)
            end
        elseif type(arg) == "string" then
            msg = msg .. padString(arg)
        end
    end

    return msg
end

local function sendOsc(address, ...)
    if udp then
        local msg = createOscMessage(address, ...)
        udp:send(msg)
        flashLED()  -- Flash LED on send
        if CONFIG.debug then
            reaper.ShowConsoleMsg("OSC sent: " .. address .. "\n")
        end
    end
end

-- ============================================================================
-- STATE TRACKING
-- ============================================================================

local state = {
    is_playing = false,
    is_recording = false,
    is_rendering = false,
    last_play_position = 0,
    last_marker_index = -1,
    dragging_items = false,
    last_item_positions = {},
    mouse_down_time = 0,
    last_clip_time = 0,
    last_update_time = 0,
    last_snap_state = nil,
    last_snap_time = 0
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function getMarkerPositions()
    local markers = {}
    local num_markers = reaper.CountProjectMarkers(0)
    for i = 0, num_markers - 1 do
        local _, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        table.insert(markers, { pos = pos, is_region = isrgn, name = name, index = markrgnindexnumber })
        if isrgn then
            table.insert(markers, { pos = rgnend, is_region = true, name = name .. " (end)", index = markrgnindexnumber })
        end
    end
    return markers
end

local function getOtherItemEdges(selected_item)
    local edges = {}
    local selected_track = reaper.GetMediaItem_Track(selected_item)
    local num_items = reaper.CountMediaItems(0)

    for i = 0, num_items - 1 do
        local item = reaper.GetMediaItem(0, i)
        if item ~= selected_item and not reaper.IsMediaItemSelected(item) then
            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_track = reaper.GetMediaItem_Track(item)
            local same_track = (item_track == selected_track)

            table.insert(edges, { pos = pos, type = "item_start", same_track = same_track })
            table.insert(edges, { pos = pos + length, type = "item_end", same_track = same_track })
        end
    end
    return edges
end

local function getTimeSelectionEdges()
    local edges = {}
    local sel_start, sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if sel_end > sel_start then
        table.insert(edges, { pos = sel_start, type = "selection_start" })
        table.insert(edges, { pos = sel_end, type = "selection_end" })
    end
    return edges
end

local function checkSnapToEdges(pos, edges, threshold)
    for _, edge in ipairs(edges) do
        if math.abs(pos - edge.pos) < threshold then
            return true, edge.type, edge.same_track
        end
    end
    return false, nil, nil
end

-- ============================================================================
-- MONITORING FUNCTIONS
-- ============================================================================

local function monitorTransport()
    local playing = reaper.GetPlayState() & 1 == 1
    local recording = reaper.GetPlayState() & 4 == 4
    local rendering = reaper.GetToggleCommandState(41207) == 1

    -- Play state changes
    if CONFIG.events.play and playing ~= state.is_playing then
        if playing then
            sendOsc("/reaper/play/start")
        else
            sendOsc("/reaper/play/stop")
        end
    end
    state.is_playing = playing

    -- Record state changes
    if CONFIG.events.record and recording ~= state.is_recording then
        if recording then
            sendOsc("/reaper/record/start")
        else
            sendOsc("/reaper/record/stop")
        end
    end
    state.is_recording = recording

    -- Render complete detection
    if CONFIG.events.render and state.is_rendering and not rendering then
        sendOsc("/reaper/render/complete")
    end
    state.is_rendering = rendering
end

local function monitorClipping()
    if not CONFIG.events.clipping then return end

    local master = reaper.GetMasterTrack(0)
    local peak_l = reaper.Track_GetPeakInfo(master, 0)
    local peak_r = reaper.Track_GetPeakInfo(master, 1)
    local peak_db = 20 * math.log(math.max(peak_l, peak_r, 0.0000001)) / math.log(10)

    local now = reaper.time_precise()

    if peak_db >= CONFIG.clip_threshold_db and (now - state.last_clip_time) > CONFIG.clip_debounce then
        sendOsc("/reaper/clip", peak_db)
        state.last_clip_time = now
    end
end

local function monitorMarkerCrossings()
    if not CONFIG.events.markers then return end
    if not state.is_playing then
        state.last_play_position = reaper.GetPlayPosition()
        return
    end

    local current_pos = reaper.GetPlayPosition()
    local markers = getMarkerPositions()

    for _, marker in ipairs(markers) do
        if (state.last_play_position < marker.pos and current_pos >= marker.pos) or
           (state.last_play_position > marker.pos and current_pos <= marker.pos) then
            sendOsc("/reaper/marker", marker.index)
        end
    end

    state.last_play_position = current_pos
end

local function monitorSnapping()
    local num_selected = reaper.CountSelectedMediaItems(0)
    if num_selected == 0 then
        state.last_snap_state = nil
        return
    end

    local item = reaper.GetSelectedMediaItem(0, 0)
    local curr_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local curr_end = curr_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    local threshold = CONFIG.snap_threshold
    local snap_targets = {}

    -- 1. Other item edges (if enabled)
    if CONFIG.events.item_snap then
        local item_edges = getOtherItemEdges(item)
        for _, edge in ipairs(item_edges) do
            table.insert(snap_targets, edge)
        end
    end

    -- 2. Markers (if enabled)
    if CONFIG.events.markers then
        local markers = getMarkerPositions()
        for _, marker in ipairs(markers) do
            table.insert(snap_targets, { pos = marker.pos, type = "marker" })
        end
    end

    -- 3. Time selection edges (if enabled)
    if CONFIG.events.selection then
        local sel_edges = getTimeSelectionEdges()
        for _, edge in ipairs(sel_edges) do
            table.insert(snap_targets, edge)
        end
    end

    -- 4. Playhead (if enabled)
    if CONFIG.events.playhead then
        local cursor_pos = reaper.GetCursorPosition()
        table.insert(snap_targets, { pos = cursor_pos, type = "playhead" })
    end

    local current_snaps = {}

    local start_snapped, start_type, start_same_track = checkSnapToEdges(curr_start, snap_targets, threshold)
    if start_snapped then
        local key = "start_" .. start_type .. "_" .. tostring(start_same_track)
        current_snaps[key] = true
    end

    local end_snapped, end_type, end_same_track = checkSnapToEdges(curr_end, snap_targets, threshold)
    if end_snapped then
        local key = "end_" .. end_type .. "_" .. tostring(end_same_track)
        current_snaps[key] = true
    end

    if state.last_snap_state then
        local now = reaper.time_precise()
        local time_since_last = now - (state.last_snap_time or 0)

        for snap_key, _ in pairs(current_snaps) do
            if not state.last_snap_state[snap_key] and time_since_last > 0.1 then
                sendOsc("/reaper/snap")
                state.last_snap_time = now
                if CONFIG.debug then
                    reaper.ShowConsoleMsg("SNAP: " .. snap_key .. "\n")
                end
                break
            end
        end
    end

    state.last_snap_state = current_snaps
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

local function mainLoop()
    -- Handle GUI if visible
    if gui.visible then
        if not drawGui() then
            -- drawGui returned false means script should stop
            return
        end
        handleMouse()
    end

    -- Monitor at configured interval (always runs, even when hidden)
    local now = reaper.time_precise()
    if (now - state.last_update_time) >= CONFIG.update_interval then
        monitorTransport()
        monitorClipping()
        monitorMarkerCrossings()
        monitorSnapping()
        state.last_update_time = now
    end

    reaper.defer(mainLoop)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function init()
    reaper.ShowConsoleMsg("\n========================================\n")
    reaper.ShowConsoleMsg("ReaperHaptic Monitor v1.2 (with GUI)\n")
    reaper.ShowConsoleMsg("========================================\n")

    -- Load saved settings
    loadSettings()

    -- Initialize socket
    if initSocket() then
        reaper.ShowConsoleMsg("OSC target: " .. CONFIG.osc_host .. ":" .. CONFIG.osc_port .. "\n")
    end

    -- Initialize GUI
    initGui()

    reaper.ShowConsoleMsg("Monitoring started.\n")
    reaper.ShowConsoleMsg("Tips:\n")
    reaper.ShowConsoleMsg("  - Click +/- to collapse/expand\n")
    reaper.ShowConsoleMsg("  - Click dock icon or press 'D' to dock/undock\n")
    reaper.ShowConsoleMsg("  - Close window to run in background\n")
    reaper.ShowConsoleMsg("  - Re-run script to show window again\n")
    reaper.ShowConsoleMsg("----------------------------------------\n\n")

    -- Send test message
    sendOsc("/reaper/snap")

    state.last_update_time = reaper.time_precise()
    mainLoop()
end

-- ============================================================================
-- SCRIPT ENTRY POINT
-- ============================================================================

local function onExit()
    gfx.quit()
    reaper.ShowConsoleMsg("\nReaperHaptic Monitor stopped.\n")
end

reaper.atexit(onExit)

-- Start the script
init()
