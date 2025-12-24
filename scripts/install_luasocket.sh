#!/bin/bash

# Install LuaSocket for REAPER
# This script downloads mavriq-lua-sockets which is compatible with REAPER's Lua interpreter

set -e

SCRIPTS_DIR="$HOME/Library/Application Support/REAPER/Scripts"
SOCKET_DIR="$SCRIPTS_DIR/socket"

echo "========================================"
echo "LuaSocket Installer for REAPER"
echo "========================================"
echo ""

# Check if already installed
if [ -f "$SOCKET_DIR/core.so" ]; then
    echo "LuaSocket already installed at:"
    echo "  $SOCKET_DIR/core.so"
    echo ""
    read -p "Reinstall? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Create directory
mkdir -p "$SOCKET_DIR"

echo "Downloading mavriq-lua-sockets..."
echo ""

# Download latest release
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Try to get the latest release
RELEASE_URL="https://github.com/mavriq-dev/mavriq-lua-sockets/releases/latest/download/mavriq-lua-sockets-macos.zip"

if curl -fSL "$RELEASE_URL" -o luasocket.zip 2>/dev/null; then
    echo "Downloaded successfully."
    unzip -q luasocket.zip

    # Find and copy socket/core.so
    if [ -f "socket/core.so" ]; then
        cp socket/core.so "$SOCKET_DIR/"
        echo ""
        echo "Installed to: $SOCKET_DIR/core.so"
    else
        echo "Error: socket/core.so not found in archive"
        echo "Please download manually from:"
        echo "  https://github.com/mavriq-dev/mavriq-lua-sockets/releases"
        exit 1
    fi
else
    echo ""
    echo "Could not download automatically."
    echo ""
    echo "Please download manually:"
    echo "1. Go to: https://github.com/mavriq-dev/mavriq-lua-sockets/releases"
    echo "2. Download the macOS release"
    echo "3. Extract socket/core.so to:"
    echo "   $SOCKET_DIR/"
    echo ""
    exit 1
fi

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "========================================"
echo "Installation complete!"
echo "========================================"
echo ""
echo "Restart REAPER and run reaper_haptic_monitor.lua"
echo "You should see: 'LuaSocket loaded successfully'"
echo ""
