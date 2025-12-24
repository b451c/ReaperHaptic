# Contributing to ReaperHaptic

Thank you for your interest in contributing to ReaperHaptic! This document provides guidelines for contributing to the project.

## Code of Conduct

Please be respectful and constructive in all interactions. We're all here to make a great tool for the audio production community.

## How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Use the bug report template** when creating a new issue
3. **Include:**
   - macOS version
   - REAPER version
   - Logi Options+ version
   - Steps to reproduce
   - Expected vs actual behavior
   - Console output (if applicable)

### Suggesting Features

1. **Check existing issues/discussions** for similar ideas
2. **Use the feature request template**
3. **Describe:**
   - The problem you're trying to solve
   - Your proposed solution
   - Alternative approaches considered

### Submitting Pull Requests

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Test thoroughly:**
   - Build the plugin
   - Test with REAPER
   - Verify haptic feedback works
5. **Commit with clear messages**
   ```bash
   git commit -m "Add feature: description of what you added"
   ```
6. **Push and create a Pull Request**

## Development Setup

### Prerequisites

- macOS 14+
- .NET 8 SDK
- REAPER (for testing)
- Logitech MX Master 4 (for testing haptics)
- Logi Options+

### Building

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/ReaperHaptic.git
cd ReaperHaptic

# Build
./build.sh

# Or manually
dotnet build src/ReaperHapticPlugin.csproj -c Debug
```

### Testing

1. Build the plugin
2. Restart Logi Options+
3. Open REAPER
4. Load `reaper_haptic_monitor.lua`
5. Test various scenarios:
   - Drag items near other items
   - Move items to markers
   - Start/stop recording
   - Play through markers
   - Create clipping

## Code Style

### C# Code

- Use C# 12 features where appropriate
- Follow standard .NET naming conventions
- Add XML documentation for public APIs
- Keep methods focused and small

### Lua Code

- Use local variables where possible
- Add comments for complex logic
- Keep the main loop efficient (runs at 30 FPS)
- Test with `debug = true` before submitting

## Areas for Contribution

### Current Needs

- [ ] Windows support
- [ ] Additional DAW support (Logic Pro, Ableton, etc.)
- [ ] More haptic event types
- [ ] Configuration UI
- [ ] Automated tests

### Plugin Improvements

- Better OSC parsing
- Additional event sources
- Custom waveform support
- Per-event intensity settings

### Script Improvements

- More snap detection scenarios
- Performance optimizations
- Better error handling
- Multi-item selection support

## Questions?

Feel free to open a Discussion for:
- Questions about the codebase
- Ideas you want feedback on
- Help with development setup

Thank you for contributing!
