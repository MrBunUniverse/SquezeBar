#!/bin/bash
set -e

# ==============================================================================
# SqueezeBar DMG Installer Builder
# Creates a professional drag-and-drop macOS DMG installer
# ==============================================================================

APP_NAME="SqueezeBar"
VERSION="0.98"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOL_NAME="${APP_NAME} Installer"
BUILD_DIR=".build/dmg_temp"
DMG_STAGING=".build/dmg_staging"
OUTPUT_DMG="${DMG_NAME}"

echo "=========================================="
echo " Building ${APP_NAME} DMG Installer"
echo "=========================================="

# 1. Ensure the app bundle exists and is fresh
./scripts/bundle_app.sh

if [ ! -d "${APP_NAME}.app" ]; then
    echo "Error: ${APP_NAME}.app not found!"
    exit 1
fi

# 2. Clean previous staging directories and DMG
rm -rf "${BUILD_DIR}" "${DMG_STAGING}" "${OUTPUT_DMG}" "${BUILD_DIR}_rw.dmg"
mkdir -p "${BUILD_DIR}"
mkdir -p "${DMG_STAGING}"

echo "[1/4] Staging app and Applications symlink..."
cp -R "${APP_NAME}.app" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

# 3. Create a temporary read-write DMG
echo "[2/4] Creating temporary disk image..."
hdiutil create -srcfolder "${DMG_STAGING}" \
    -volname "${VOL_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 120m \
    "${BUILD_DIR}_rw.dmg"

# 4. Mount the RW DMG to configure Finder view
echo "[3/4] Mounting and styling Finder window layout..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${BUILD_DIR}_rw.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_DIR="/Volumes/${VOL_NAME}"

# Wait for volume to appear
sleep 2

# Run AppleScript to arrange icons nicely
osascript <<EOF || true
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 940, 560}
        
        set theViewOptions to the icon view options of container window
        set icon size of theViewOptions to 110
        set text size of theViewOptions to 12
        set label position of theViewOptions to bottom
        set arrangement of theViewOptions to not arranged
        
        -- Position App icon on the left, Applications folder on the right
        set position of item "${APP_NAME}.app" of container window to {140, 180}
        set position of item "Applications" of container window to {400, 180}
        
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Sync changes and unmount
sync
hdiutil detach "${DEVICE}" || hdiutil detach "${MOUNT_DIR}" -force || true
sleep 2

# 5. Convert to compressed, read-only final DMG
echo "[4/4] Converting to final compressed DMG..."
hdiutil convert "${BUILD_DIR}_rw.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${OUTPUT_DMG}"

# Clean up temporary files
rm -rf "${BUILD_DIR}" "${DMG_STAGING}" "${BUILD_DIR}_rw.dmg"

echo "=========================================="
echo " Successfully created DMG installer:"
echo " File: ./${OUTPUT_DMG}"
echo " Size: $(du -h "${OUTPUT_DMG}" | awk '{print $1}')"
echo "=========================================="
