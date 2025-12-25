# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Windows support
- Additional DAW support
- Custom waveform intensity settings
- Multi-item drag support improvements

## [1.1.3] - 2025-12-25

### Added

- Toggle state support for REAPER toolbar - icon now properly shows active/inactive state
- Script registers as toggle action using `SetToggleCommandState`

## [1.1.2] - 2025-12-24

### Fixed

- Dock position now persists correctly - window opens in the same docker location after REAPER restart
- Saves actual docker index instead of just docked/undocked state

## [1.1.1] - 2025-12-24

### Changed

- Removed console output on script startup - no more console window appearing
- Console messages now only show for errors (LuaSocket not found) or when debug mode is enabled

## [1.1.0] - 2025-12-24

### Added

- **Configuration GUI**: Native REAPER gfx-based configuration panel
  - Toggle switches for all 8 haptic event types
  - LED indicator that flashes green on haptic feedback
  - Collapse/expand mode (click +/- button) for minimal footprint
  - Dock support (press `D` or click dock button) for REAPER Docker
  - Settings persistence via REAPER ExtState
  - Background operation - script continues when window is closed
- Screenshot in README documentation

### Changed

- Simplified CONFIG structure - event toggles now in `CONFIG.events` table
- Reduced console output for cleaner startup
- Streamlined OSC message code

### Removed

- Removed redundant config options (now controlled via GUI):
  - `grid_snap_enabled`
  - `item_snap_enabled`
  - `marker_snap_enabled`
  - `clip_check_tracks`
  - `marker_crossing_enabled`

## [1.0.0] - 2025-12-24

### Added

- Initial release of ReaperHaptic
- **Snap Detection**: Haptic feedback when items touch:
  - Other item edges (start/end)
  - Items on the same track (touching)
  - Markers
  - Time selection edges
  - Playhead (edit cursor)
- **Clipping Detection**: Alert when master track exceeds 0dB
- **Transport Events**:
  - Record start/stop
  - Play start/stop
  - Render complete
- **Marker Crossing**: Feedback when playhead crosses markers during playback
- **Item Alignment**: Feedback when multiple selected items align
- REAPER Lua monitoring script with OSC output
- Custom IEEE 754 float packing for OSC (no math.frexp dependency)
- Support for mavriq-lua-sockets (REAPER-compatible LuaSocket)
- Logi Options+ plugin package (.lplug4)
- YAML-based haptic event mapping

### Technical Details

- OSC over UDP on port 9000
- ~30 FPS monitoring loop in REAPER
- 100ms debounce on snap detection
- Per-event waveform configuration
- Debug mode for troubleshooting
