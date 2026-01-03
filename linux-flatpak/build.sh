#!/bin/bash
# Build script for Discord Drover Linux library

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Discord Drover for Linux (Flatpak)..."

# Build the shared library
gcc -shared -fPIC -o libdrover.so drover.c -ldl -lpthread -O2 -Wall

if [ $? -eq 0 ]; then
    echo "✓ Build successful: libdrover.so"
    ls -lh libdrover.so
else
    echo "✗ Build failed"
    exit 1
fi

echo ""
echo "To install for Flatpak Discord, run: ./install-flatpak.sh"
