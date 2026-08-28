#!/bin/bash
set -e
cd "$(dirname "$0")/.."

EXE_PATH="$(pwd)/dist/win-x64/SqueezeBar.exe"

if [ ! -f "${EXE_PATH}" ]; then
    echo "[SqueezeBar] Binary not found. Building win-x64 release package..."
    ./scripts/build_windows.sh
fi

echo "=========================================="
echo " Launching SqueezeBar in CrossOver / Wine"
echo "=========================================="

# Check for CrossOver or Wine
if [ -d "/Applications/CrossOver.app" ]; then
    echo "[SqueezeBar] Opening in CrossOver.app..."
    open -a "/Applications/CrossOver.app" "${EXE_PATH}"
elif command -v wine &> /dev/null; then
    echo "[SqueezeBar] Launching with wine..."
    wine "${EXE_PATH}"
else
    echo "[SqueezeBar] CrossOver or Wine not found in default paths."
    echo "[SqueezeBar] Executable ready for Windows at: ${EXE_PATH}"
    open -R "${EXE_PATH}"
fi
