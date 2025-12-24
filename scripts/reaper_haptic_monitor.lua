-- ReaperHaptic Monitor Script
-- Monitors REAPER events and sends OSC messages to the ReaperHaptic plugin
-- Author: falami.studio
-- Version: 1.0

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
    grid_snap_enabled = true,    -- Detect grid snaps
    item_snap_enabled = true,    -- Detect item edge snaps
    marker_snap_enabled = true,  -- Detect marker snaps

    -- Clipping detection
    clip_threshold_db = 0.0,     -- dB threshold for clipping
    clip_check_master = true,    -- Check master track
    clip_check_tracks = false,   -- Check individual tracks (can be CPU intensive)

    -- Marker crossing
    marker_crossing_enabled = true,

    -- Debug output
    debug = false
}

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
        reaper.ShowConsoleMsg("ReaperHaptic: LuaSocket not found. Using REAPER's OSC output instead.\n")
        reaper.ShowConsoleMsg("Configure REAPER's OSC in Preferences > Control/OSC/Web\n")
        reaper.ShowConsoleMsg("Or install LuaSocket: https://luarocks.org/modules/luasocket/luasocket\n")
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

    -- Calculate exponent and mantissa manually
    local exponent = 0
    local mantissa = f

    -- Normalize: get mantissa between 1 and 2
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

    -- IEEE 754: exponent bias is 127
    exponent = exponent + 127

    -- Mantissa: remove leading 1 and scale to 23 bits
    mantissa = (mantissa - 1) * 8388608 -- 2^23
    mantissa = math.floor(mantissa + 0.5)

    -- Pack bytes (big-endian)
    local b0 = mantissa % 256
    local b1 = math.floor(mantissa / 256) % 256
    local b2 = math.floor(mantissa / 65536) % 128 + (exponent % 2) * 128
    local b3 = sign * 128 + math.floor(exponent / 2)

    return string.char(b3, b2, b1, b0)
end

-- Pack a 32-bit integer as big-endian
local function packInt(i)
    local b0 = i % 256
    local b1 = math.floor(i / 256) % 256
    local b2 = math.floor(i / 65536) % 256
    local b3 = math.floor(i / 16777216) % 256
    return string.char(b3, b2, b1, b0)
end

-- Pad string to 4-byte boundary
local function padString(s)
    local len = #s + 1  -- Include null terminator
    local padded = s .. string.char(0)
    local padding = (4 - (len % 4)) % 4
    for i = 1, padding do
        padded = padded .. string.char(0)
    end
    return padded
end

-- Create OSC message
local function createOscMessage(address, ...)
    local args = {...}
    local msg = padString(address)

    -- Build type tag
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

    -- Pack arguments
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

-- Send OSC message
local function sendOsc(address, ...)
    if udp then
        local msg = createOscMessage(address, ...)
        udp:send(msg)
        if CONFIG.debug then
            reaper.ShowConsoleMsg("OSC sent: " .. address .. "\n")
        end
    end
end

-- ============================================================================
-- STATE TRACKING
-- ============================================================================

local state = {
    -- Transport
    is_playing = false,
    is_recording = false,
    is_rendering = false,

    -- Playhead
    last_play_position = 0,
    last_marker_index = -1,

    -- Item dragging
    dragging_items = false,
    last_item_positions = {},
    mouse_down_time = 0,

    -- Clipping
    last_clip_time = 0,
    clip_debounce = 0.2,

    -- General
    last_update_time = 0
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function getGridDivision()
    local _, division = reaper.GetSetProjectGrid(0, false)
    return division
end

local function snapToGrid(pos)
    local division = getGridDivision()
    if division > 0 then
        return math.floor(pos / division + 0.5) * division
    end
    return pos
end

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

local function getItemEdges()
    local edges = {}
    local num_items = reaper.CountMediaItems(0)
    for i = 0, num_items - 1 do
        local item = reaper.GetMediaItem(0, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        table.insert(edges, pos)
        table.insert(edges, pos + length)
    end
    return edges
end

local function isNearAnyPosition(pos, positions, threshold)
    for _, p in ipairs(positions) do
        if math.abs(pos - p) < threshold then
            return true
        end
    end
    return false
end

-- ============================================================================
-- MONITORING FUNCTIONS
-- ============================================================================

-- Monitor transport state
local function monitorTransport()
    local playing = reaper.GetPlayState() & 1 == 1
    local recording = reaper.GetPlayState() & 4 == 4
    local rendering = reaper.GetToggleCommandState(41207) == 1 -- Render project

    -- Play state changes
    if playing ~= state.is_playing then
        if playing then
            sendOsc("/reaper/play/start")
        else
            sendOsc("/reaper/play/stop")
        end
        state.is_playing = playing
    end

    -- Record state changes
    if recording ~= state.is_recording then
        if recording then
            sendOsc("/reaper/record/start")
        else
            sendOsc("/reaper/record/stop")
        end
        state.is_recording = recording
    end

    -- Render complete detection
    if state.is_rendering and not rendering then
        sendOsc("/reaper/render/complete")
    end
    state.is_rendering = rendering
end

-- Monitor for clipping
local function monitorClipping()
    if not CONFIG.clip_check_master then return end

    local master = reaper.GetMasterTrack(0)
    local peak_l = reaper.Track_GetPeakInfo(master, 0)
    local peak_r = reaper.Track_GetPeakInfo(master, 1)
    local peak_db = 20 * math.log(math.max(peak_l, peak_r, 0.0000001)) / math.log(10)

    local now = reaper.time_precise()

    if peak_db >= CONFIG.clip_threshold_db and (now - state.last_clip_time) > state.clip_debounce then
        sendOsc("/reaper/clip", peak_db)
        state.last_clip_time = now
    end
end

-- Monitor for marker crossings during playback
local function monitorMarkerCrossings()
    if not CONFIG.marker_crossing_enabled then return end
    if not state.is_playing then
        state.last_play_position = reaper.GetPlayPosition()
        return
    end

    local current_pos = reaper.GetPlayPosition()
    local markers = getMarkerPositions()

    for _, marker in ipairs(markers) do
        -- Check if playhead crossed this marker since last update
        if (state.last_play_position < marker.pos and current_pos >= marker.pos) or
           (state.last_play_position > marker.pos and current_pos <= marker.pos) then
            sendOsc("/reaper/marker", marker.index)
        end
    end

    state.last_play_position = current_pos
end

-- Get all item edges (excluding selected items)
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

-- Get time selection edges
local function getTimeSelectionEdges()
    local edges = {}
    local sel_start, sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if sel_end > sel_start then
        table.insert(edges, { pos = sel_start, type = "selection_start" })
        table.insert(edges, { pos = sel_end, type = "selection_end" })
    end
    return edges
end

-- Check if position matches any edge
local function checkSnapToEdges(pos, edges, threshold)
    for _, edge in ipairs(edges) do
        if math.abs(pos - edge.pos) < threshold then
            return true, edge.type, edge.same_track
        end
    end
    return false, nil, nil
end

-- Monitor for item snapping during drag
local function monitorSnapping()
    local num_selected = reaper.CountSelectedMediaItems(0)
    if num_selected == 0 then
        state.last_snap_state = nil
        return
    end

    -- Get first selected item
    local item = reaper.GetSelectedMediaItem(0, 0)
    local curr_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local curr_end = curr_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    -- Threshold for snap detection (in seconds)
    local threshold = 0.001

    -- Collect all snap targets
    local snap_targets = {}

    -- 1. Other item edges (for alignment and touching)
    local item_edges = getOtherItemEdges(item)
    for _, edge in ipairs(item_edges) do
        table.insert(snap_targets, edge)
    end

    -- 2. Markers
    local markers = getMarkerPositions()
    for _, marker in ipairs(markers) do
        table.insert(snap_targets, { pos = marker.pos, type = "marker" })
    end

    -- 3. Time selection edges
    local sel_edges = getTimeSelectionEdges()
    for _, edge in ipairs(sel_edges) do
        table.insert(snap_targets, edge)
    end

    -- 4. Playhead (edit cursor)
    local cursor_pos = reaper.GetCursorPosition()
    table.insert(snap_targets, { pos = cursor_pos, type = "playhead" })

    -- Check current snap state
    local current_snaps = {}

    -- Check start edge
    local start_snapped, start_type, start_same_track = checkSnapToEdges(curr_start, snap_targets, threshold)
    if start_snapped then
        local key = "start_" .. start_type .. "_" .. tostring(start_same_track)
        current_snaps[key] = true
    end

    -- Check end edge
    local end_snapped, end_type, end_same_track = checkSnapToEdges(curr_end, snap_targets, threshold)
    if end_snapped then
        local key = "end_" .. end_type .. "_" .. tostring(end_same_track)
        current_snaps[key] = true
    end

    -- Compare with previous state - trigger only on NEW snaps
    if state.last_snap_state then
        local now = reaper.time_precise()
        local time_since_last = now - (state.last_snap_time or 0)

        for snap_key, _ in pairs(current_snaps) do
            if not state.last_snap_state[snap_key] and time_since_last > 0.1 then
                -- New snap detected!
                sendOsc("/reaper/snap")
                state.last_snap_time = now

                if CONFIG.debug then
                    reaper.ShowConsoleMsg("SNAP: " .. snap_key .. "\n")
                end
                break  -- Only one haptic per frame
            end
        end
    end

    state.last_snap_state = current_snaps
end

-- Monitor for item alignment
local function monitorAlignment()
    local num_selected = reaper.CountSelectedMediaItems(0)
    if num_selected < 2 then return end

    -- Get positions of all selected items
    local positions = {}
    for i = 0, num_selected - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        table.insert(positions, pos)
    end

    -- Check if any two items just became aligned
    table.sort(positions)
    for i = 2, #positions do
        if math.abs(positions[i] - positions[i-1]) < CONFIG.snap_threshold then
            sendOsc("/reaper/align")
            return
        end
    end
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

local function mainLoop()
    local now = reaper.time_precise()

    if (now - state.last_update_time) >= CONFIG.update_interval then
        monitorTransport()
        monitorClipping()
        monitorMarkerCrossings()
        monitorSnapping()
        monitorAlignment()

        state.last_update_time = now
    end

    reaper.defer(mainLoop)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function init()
    reaper.ShowConsoleMsg("\n========================================\n")
    reaper.ShowConsoleMsg("ReaperHaptic Monitor v1.0\n")
    reaper.ShowConsoleMsg("========================================\n")

    if initSocket() then
        reaper.ShowConsoleMsg("OSC target: " .. CONFIG.osc_host .. ":" .. CONFIG.osc_port .. "\n")
    end

    reaper.ShowConsoleMsg("Monitoring started.\n")
    reaper.ShowConsoleMsg("----------------------------------------\n\n")

    -- Send test message
    sendOsc("/reaper/snap")

    state.last_update_time = reaper.time_precise()
    mainLoop()
end

-- ============================================================================
-- SCRIPT ENTRY POINT
-- ============================================================================

-- Register exit handler
local function onExit()
    reaper.ShowConsoleMsg("\nReaperHaptic Monitor stopped.\n")
end

reaper.atexit(onExit)

-- Start the script
init()
