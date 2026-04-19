#!/bin/bash

# Build script for Simon's Lights macOS app

set -e

echo "🎨 Building Simon's Lights..."

cd "$(dirname "$0")/HueControl"

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo "❌ Swift not found. Install Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

# Build
echo "📦 Building..."
swift build -c release

# Find the built binary
BINARY=".build/release/SimonsLights"

if [ ! -f "$BINARY" ]; then
    echo "❌ Build failed - binary not found at $BINARY"
    echo "🔍 Looking for binary..."
    find .build -name "*Lights*" -type f
    exit 1
fi

echo "✅ Build successful!"

# Create app bundle
APP_NAME="Simon's Lights.app"
BUNDLE_PATH="$APP_NAME"

echo "📁 Creating app bundle: $APP_NAME"

rm -rf "$BUNDLE_PATH"
mkdir -p "$BUNDLE_PATH/Contents/MacOS"
mkdir -p "$BUNDLE_PATH/Contents/Resources"

# Copy binary
cp "$BINARY" "$BUNDLE_PATH/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$BUNDLE_PATH/Contents/"

# Copy config.json
cp config.json "$BUNDLE_PATH/Contents/Resources/"

# Copy control_monkey.py if it exists
if [ -f "control_monkey.py" ]; then
    cp control_monkey.py "$BUNDLE_PATH/Contents/Resources/"
    echo "✅ Copied control_monkey.py"
elif [ -f "$HOME/.openclaw/workspace/control_monkey.py" ]; then
    cp "$HOME/.openclaw/workspace/control_monkey.py" "$BUNDLE_PATH/Contents/Resources/"
    echo "✅ Copied control_monkey.py from workspace"
else
    echo "⚠️ control_monkey.py not found - Monkey light won't work"
fi

# Set executable permissions
chmod +x "$BUNDLE_PATH/Contents/MacOS/SimonsLights"

# Ad-hoc code sign
echo "🔏 Signing app..."
codesign --force --deep --sign - "$BUNDLE_PATH" 2>/dev/null || echo "⚠️ Codesign failed (non-critical)"

echo ""
echo "🎉 Done!"
echo ""
echo "📍 App location: $(pwd)/$BUNDLE_PATH"
echo ""
echo "IMPORTANT: Set your Tuya password in environment:"
echo "   export TUYA_PASSWORD='your_password'"
echo ""
echo "Macro Pad Mappings:"
echo "   B = All On"
echo "   C = All Off"
echo "   D = Party Mode"
echo "   E = Movie Mode"
echo "   ← = Monkey Toggle"
echo "   → = BigBoy Toggle"
echo "   ↓ = Color Cycle"
echo ""
echo "To install:"
echo "   cp -r '$BUNDLE_PATH' /Applications/"
