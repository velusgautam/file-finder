#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Packaging File Finder into macOS DMG Installer ==="

APP_NAME="File Finder"
APP_BUNDLE="dist/${APP_NAME}.app"
VERSION="1.0.0"
DMG_NAME="File-Finder-${VERSION}.dmg"
DMG_PATH="dist/${DMG_NAME}"
LATEST_DMG="dist/File-Finder.dmg"
STAGING_DIR="dist/dmg_staging"

# 1. Ensure app bundle exists
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "App bundle not found. Building first..."
    ./scripts/build_app.sh
fi

# 2. Prepare staging directory
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

echo "Copying ${APP_BUNDLE} to installer staging..."
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

echo "Creating /Applications drag-and-drop symlink..."
ln -s /Applications "${STAGING_DIR}/Applications"

# 3. Create DMG using hdiutil
echo "Creating compressed read-only DMG with hdiutil..."
rm -f "${DMG_PATH}" "${LATEST_DMG}"

hdiutil create \
    -volname "File Finder" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

# Create convenient unversioned link
cp "${DMG_PATH}" "${LATEST_DMG}"

# 4. Sign DMG if signing identity provided
if [ -n "${CODESIGN_IDENTITY:-}" ] && [ "${CODESIGN_IDENTITY}" != "-" ]; then
    echo "=== Signing DMG with '${CODESIGN_IDENTITY}' ==="
    codesign --force --sign "${CODESIGN_IDENTITY}" "${DMG_PATH}"
    if [ -f "${LATEST_DMG}" ]; then
        codesign --force --sign "${CODESIGN_IDENTITY}" "${LATEST_DMG}"
    fi
fi

# 5. Clean up staging
rm -rf "${STAGING_DIR}"

echo "=== DMG Build Successful! ==="
echo "Created: ${DMG_PATH}"
echo "Latest:  ${LATEST_DMG}"
ls -lh "${DMG_PATH}"
