#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_1024x1024_png>"
    exit 1
fi

INPUT_PNG="$1"
RESOURCES_DIR="Resources"
ICONSET_DIR="${RESOURCES_DIR}/AppIcon.iconset"
ICNS_FILE="${RESOURCES_DIR}/AppIcon.icns"

mkdir -p "${ICONSET_DIR}"

echo "=== Generating multi-resolution macOS iconset ==="
sips -z 16 16     "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_16x16.png"
sips -z 32 32     "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_16x16@2x.png"
sips -z 32 32     "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_32x32.png"
sips -z 64 64     "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_32x32@2x.png"
sips -z 128 128   "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_128x128.png"
sips -z 256 256   "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_128x128@2x.png"
sips -z 256 256   "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_256x256.png"
sips -z 512 512   "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_256x256@2x.png"
sips -z 512 512   "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_512x512.png"
sips -z 1024 1024 "${INPUT_PNG}" --out "${ICONSET_DIR}/icon_512x512@2x.png"

echo "=== Compiling into AppIcon.icns ==="
iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_FILE}"
rm -rf "${ICONSET_DIR}"

echo "Successfully generated: ${ICNS_FILE}"
