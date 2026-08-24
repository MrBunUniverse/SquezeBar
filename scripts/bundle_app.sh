#!/bin/bash
set -e

echo "🔨 Building SqueezeBar (Release)..."
swift build -c release

APP_NAME="SqueezeBar.app"
BUILD_BIN=".build/release/SqueezeBar"
DEST_APP="./${APP_NAME}"

echo "📦 Creating macOS App Bundle..."
rm -rf "${DEST_APP}"
mkdir -p "${DEST_APP}/Contents/MacOS"
mkdir -p "${DEST_APP}/Contents/Resources"

cp "${BUILD_BIN}" "${DEST_APP}/Contents/MacOS/SqueezeBar"
cp "Resources/Info.plist" "${DEST_APP}/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${DEST_APP}/Contents/Resources/AppIcon.icns"
fi

# Optional codesign with ad-hoc signature for local execution
if command -v codesign &> /dev/null; then
    echo "🔏 Signing App with entitlements..."
    codesign --force --deep --sign - --entitlements "Resources/SqueezeBar.entitlements" "${DEST_APP}"
fi

echo "✅ Successfully created ${APP_NAME}!"
echo "To run, execute: open ${APP_NAME}"
