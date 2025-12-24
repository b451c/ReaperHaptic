# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-24

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

## [Unreleased]

### Planned

- Windows support
- Additional DAW support
- Configuration UI in Logi Options+
- Custom waveform intensity settings
- Multi-item drag support improvements
