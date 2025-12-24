#!/bin/bash

# Release packaging script for ReaperHaptic
# Creates a distributable release package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

VERSION="${1:-1.0.0}"
RELEASE_DIR="$PROJECT_DIR/releases/v$VERSION"

echo "========================================"
echo "ReaperHaptic Release Builder"
echo "Version: $VERSION"
echo "========================================"
echo ""

# Check for dotnet
if ! command -v dotnet &> /dev/null; then
    echo "Error: .NET SDK not found"
    echo "Install with: brew install dotnet-sdk@8"
    exit 1
fi

# Clean and build
echo "Building Release..."
dotnet clean src/ReaperHapticPlugin.csproj -c Release > /dev/null 2>&1 || true
dotnet build src/ReaperHapticPlugin.csproj -c Release

echo ""
echo "Creating release package..."

# Create release directory
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Copy scripts
cp scripts/reaper_haptic_monitor.lua "$RELEASE_DIR/"
cp scripts/install_luasocket.sh "$RELEASE_DIR/"

# Copy documentation
cp README.md "$RELEASE_DIR/"
cp LICENSE "$RELEASE_DIR/"
cp CHANGELOG.md "$RELEASE_DIR/"

# Try to create plugin package
if command -v logiplugintool &> /dev/null; then
    echo "Creating plugin package..."
    logiplugintool pack "./bin/Release" "$RELEASE_DIR/ReaperHaptic.lplug4"
else
    echo "Note: logiplugintool not found, copying build output instead"
    mkdir -p "$RELEASE_DIR/plugin"
    cp -r bin/Release/* "$RELEASE_DIR/plugin/"
fi

# Create zip archive
echo "Creating zip archive..."
cd releases
zip -r "ReaperHaptic-v$VERSION.zip" "v$VERSION" > /dev/null

echo ""
echo "========================================"
echo "Release package created!"
echo "========================================"
echo ""
echo "Files:"
ls -la "$RELEASE_DIR"
echo ""
echo "Archive: releases/ReaperHaptic-v$VERSION.zip"
echo ""
echo "Upload to GitHub Releases:"
echo "  gh release create v$VERSION releases/ReaperHaptic-v$VERSION.zip --title 'ReaperHaptic v$VERSION'"
echo ""
