#!/bin/bash

# ReaperHaptic Build Script
# Builds and optionally installs the plugin

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG="${1:-Release}"
PLUGIN_NAME="ReaperHaptic"
REAPER_SCRIPTS="$HOME/Library/Application Support/REAPER/Scripts"
LOGI_PLUGINS="$HOME/Library/Application Support/Logi/LogiPluginService/Plugins"

echo "========================================"
echo "Building $PLUGIN_NAME ($CONFIG)"
echo "========================================"

# Check for dotnet
if ! command -v dotnet &> /dev/null; then
    # Try homebrew location
    if [ -f "/opt/homebrew/opt/dotnet@8/bin/dotnet" ]; then
        export PATH="/opt/homebrew/opt/dotnet@8/bin:$PATH"
    elif [ -f "$HOME/.dotnet/dotnet" ]; then
        export PATH="$HOME/.dotnet:$PATH"
    else
        echo ""
        echo "Error: .NET SDK not found"
        echo ""
        echo "Install with one of:"
        echo "  brew install dotnet-sdk@8"
        echo "  # or download from https://dotnet.microsoft.com/download"
        exit 1
    fi
fi

echo ""
echo "Using: $(which dotnet)"
echo ".NET version: $(dotnet --version)"
echo ""

# Build
echo "Building..."
dotnet build src/ReaperHapticPlugin.csproj -c "$CONFIG"

echo ""
echo "Build complete!"
echo ""
echo "Output: bin/$CONFIG/"

# Install Lua script
if [ -d "$REAPER_SCRIPTS" ]; then
    echo ""
    echo "Installing Lua script to REAPER..."
    cp scripts/reaper_haptic_monitor.lua "$REAPER_SCRIPTS/"
    echo "  -> $REAPER_SCRIPTS/reaper_haptic_monitor.lua"
fi

# Check if logiplugintool is available for packaging
if command -v logiplugintool &> /dev/null; then
    echo ""
    echo "Creating plugin package..."
    logiplugintool pack "./bin/$CONFIG" "./$PLUGIN_NAME.lplug4"
    logiplugintool verify "./$PLUGIN_NAME.lplug4"
    echo ""
    echo "Package created: $PLUGIN_NAME.lplug4"
fi

echo ""
echo "========================================"
echo "Installation"
echo "========================================"
echo ""
echo "The plugin has been linked to Logi Plugin Service."
echo ""
echo "Next steps:"
echo "  1. Restart Logi Options+ (or logout/login)"
echo "  2. In REAPER: Actions > Load ReaScript > reaper_haptic_monitor.lua"
echo "  3. Run the script and enjoy haptic feedback!"
echo ""
echo "If LuaSocket is not installed, run:"
echo "  ./scripts/install_luasocket.sh"
echo ""
