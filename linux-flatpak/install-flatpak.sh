#!/bin/bash
# Installation script for Discord Drover on Flatpak Discord

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLATPAK_APP="com.discordapp.Discord"
INSTALL_DIR="$HOME/.var/app/$FLATPAK_APP/drover"
LIB_NAME="libdrover.so"
INI_NAME="drover.ini"

echo "Discord Drover for Linux (Flatpak) - Installer"
echo "==============================================="
echo ""

# Check if Flatpak Discord is installed
if ! flatpak list | grep -q "$FLATPAK_APP"; then
    echo "✗ Error: Discord is not installed via Flatpak"
    echo ""
    echo "Install Discord with:"
    echo "  flatpak install flathub $FLATPAK_APP"
    exit 1
fi

echo "✓ Found Flatpak Discord installation"

# Build if not already built
if [ ! -f "$SCRIPT_DIR/$LIB_NAME" ]; then
    echo ""
    echo "Building library..."
    cd "$SCRIPT_DIR"
    bash build.sh
fi

# Create installation directory
echo ""
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Installing files..."
cp "$SCRIPT_DIR/$LIB_NAME" "$INSTALL_DIR/"
chmod 755 "$INSTALL_DIR/$LIB_NAME"

# Create default config if it doesn't exist
if [ ! -f "$INSTALL_DIR/$INI_NAME" ]; then
    cat > "$INSTALL_DIR/$INI_NAME" << 'EOF'
[drover]
# Discord Drover configuration for Linux
# Leave proxy empty for Direct Mode (UDP manipulation only)
proxy = 
EOF
    echo "✓ Created default configuration"
fi

# Set up Flatpak override for LD_PRELOAD
echo ""
echo "Configuring Flatpak override..."

# Get the library path that will be accessible inside the Flatpak sandbox
# Flatpak maps ~/.var/app/APP_ID to /var/config inside the sandbox
SANDBOX_LIB_PATH="/var/config/drover/$LIB_NAME"

# Apply the override
flatpak override --user "$FLATPAK_APP" \
    --env=LD_PRELOAD="$SANDBOX_LIB_PATH" \
    --filesystem=home

echo "✓ Flatpak override applied"

# Show what was configured
echo ""
echo "Installation complete!"
echo ""
echo "Installed files:"
echo "  Library: $INSTALL_DIR/$LIB_NAME"
echo "  Config:  $INSTALL_DIR/$INI_NAME"
echo ""
echo "Flatpak configuration:"
flatpak override --show "$FLATPAK_APP" | grep -E "(LD_PRELOAD|filesystem)" || true
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "IMPORTANT: Please completely quit Discord and restart it"
echo "for the changes to take effect."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To verify it's working, you can check the logs:"
echo "  journalctl -f | grep drover"
echo ""
