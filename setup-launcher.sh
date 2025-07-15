#!/bin/bash

# Setup script for capClone Project Launcher
# This script installs the launcher to Ubuntu applications menu

set -e

CURRENT_DIR="$(pwd)"
SCRIPT_PATH="$CURRENT_DIR/launcher.sh"
DESKTOP_FILE="$CURRENT_DIR/launcher.desktop"
APPLICATIONS_DIR="$HOME/.local/share/applications"

echo "🔧 Setting up capClone Project Launcher..."

# Check if the bash script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Error: launcher.sh not found in current directory"
    exit 1
fi

# Check if the desktop file exists
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "❌ Error: launcher.desktop not found in current directory"
    exit 1
fi

# Make the bash script executable
echo "📝 Making launcher script executable..."
chmod +x "$SCRIPT_PATH"

# Update the desktop file with the correct path
echo "📝 Updating desktop file with correct path..."
sed -i "s|Exec=.*|Exec=\"$SCRIPT_PATH\"|" "$DESKTOP_FILE"

# Create applications directory if it doesn't exist
mkdir -p "$APPLICATIONS_DIR"

# Copy the desktop file to applications directory
echo "📋 Installing capClone launcher to applications menu..."
cp "$DESKTOP_FILE" "$APPLICATIONS_DIR/CapExpert-launcher.desktop"

# Make the desktop file executable
chmod +x "$APPLICATIONS_DIR/CapExpert-launcher.desktop"

# Create desktop shortcut
DESKTOP_DIR="$HOME/Desktop"
if [ -d "$DESKTOP_DIR" ]; then
    echo "🖥️  Creating desktop shortcut..."
    cp "$DESKTOP_FILE" "$DESKTOP_DIR/CapExpert-launcher.desktop"
    chmod +x "$DESKTOP_DIR/CapExpert-launcher.desktop"
    
    # Trust the desktop file (Ubuntu 18.04+)
    if command -v gio &> /dev/null; then
        gio set "$DESKTOP_DIR/CapExpert-launcher.desktop" metadata::trusted true
    fi
    echo "✅ Desktop shortcut created!"
else
    echo "⚠️  Desktop directory not found - skipping desktop shortcut"
fi

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    echo "🔄 Updating desktop database..."
    update-desktop-database "$APPLICATIONS_DIR"
fi

echo "✅ capClone Project Launcher installed successfully!"
echo ""
echo "📱 You can now find 'capClone Project' in your applications menu"
echo "🖥️  Desktop shortcut created on your desktop"
echo "🔍 Look for it in the Development category"
echo ""
echo "📋 Manual launch: $SCRIPT_PATH"
echo ""
echo "⚠️  Important: Make sure to update the port numbers in the script"
echo "    capClone uses ports 8080 and 8081"
echo ""
echo "�� Setup complete!" 