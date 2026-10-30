#!/usr/bin/env bash
set -euo pipefail

# File Finder — Quick installer for macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/velusgautam/file-finder/main/scripts/install.sh | bash

REPO="velusgautam/file-finder"
APP_NAME="File Finder"
INSTALL_DIR="/Applications"
TARGET_APP="${INSTALL_DIR}/${APP_NAME}.app"

echo "================================================="
echo "   File Finder — Scandinavian Minimalist Finder"
echo "================================================="

OS="$(uname -s)"
if [ "$OS" != "Darwin" ]; then
    echo "Error: File Finder is a native macOS application and requires macOS (Darwin)."
    exit 1
fi

TMP_DIR="$(mktemp -d -t filefinder_install_XXXXXX)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

DMG_URL="https://github.com/${REPO}/releases/latest/download/File-Finder.dmg"
DMG_PATH="${TMP_DIR}/File-Finder.dmg"

echo "==> Downloading latest release..."
if ! curl -fSL --progress-bar "$DMG_URL" -o "$DMG_PATH"; then
    echo "Direct release download failed. Falling back to repository artifact if available..."
    # Fallback to main branch raw or fallback link if release not yet published
    FALLBACK_URL="https://raw.githubusercontent.com/${REPO}/main/dist/File-Finder.dmg"
    curl -fSL --progress-bar "$FALLBACK_URL" -o "$DMG_PATH" || {
        echo "Error: Could not download File-Finder.dmg installer."
        exit 1
    }
fi

echo "==> Mounting disk image..."
MOUNT_POINT="$(mktemp -d /Volumes/FileFinder_XXXXXX 2>/dev/null || echo "/Volumes/File Finder")"
hdiutil attach "$DMG_PATH" -nobrowse -quiet -mountpoint "$MOUNT_POINT"

SOURCE_APP="${MOUNT_POINT}/${APP_NAME}.app"

if [ ! -d "$SOURCE_APP" ]; then
    echo "Error: ${APP_NAME}.app not found in disk image."
    hdiutil detach "$MOUNT_POINT" -quiet || true
    exit 1
fi

echo "==> Installing to ${INSTALL_DIR}..."
# If app is running, prompt or close
pkill -f "File Finder" 2>/dev/null || true

rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"

echo "==> Unmounting installer..."
hdiutil detach "$MOUNT_POINT" -quiet || true

# Remove quarantine attribute so macOS allows direct launch
echo "==> Clearing gatekeeper quarantine..."
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

echo "================================================="
echo "  ✓ File Finder successfully installed to:"
echo "    ${TARGET_APP}"
echo "================================================="
echo ""
read -r -p "Launch File Finder now? [Y/n] " response || response="y"
if [[ "$response" =~ ^([yY][eE][sS]|[yY]|"")$ ]]; then
    open "$TARGET_APP"
fi
