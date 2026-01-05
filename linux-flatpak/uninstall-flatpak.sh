#!/bin/bash
# Uninstallation script for Discord Drover on Flatpak Discord

set -e

FLATPAK_APP="com.discordapp.Discord"
INSTALL_DIR="$HOME/.var/app/$FLATPAK_APP/drover"

echo "Discord Drover for Linux (Flatpak) - Uninstaller"
echo "================================================="
echo ""

# Check if Flatpak Discord is installed
if ! flatpak list | grep -q "$FLATPAK_APP"; then
    echo "✗ Warning: Discord is not installed via Flatpak"
    echo ""
fi

# Remove Flatpak override
echo "Removing Flatpak override..."
flatpak override --user --reset "$FLATPAK_APP" 2>/dev/null || true
echo "✓ Flatpak override removed"

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo ""
    echo "Removing installation directory..."
    rm -rf "$INSTALL_DIR"
    echo "✓ Files removed: $INSTALL_DIR"
else
    echo ""
    echo "Installation directory not found (already uninstalled?)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Uninstallation complete!"
echo ""
echo "Please restart Discord for changes to take effect."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
