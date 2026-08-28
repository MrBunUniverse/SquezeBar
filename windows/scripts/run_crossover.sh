#!/bin/bash
set -e
cd "$(dirname "$0")/.."

EXE_PATH="$(pwd)/SqueezeBar.exe"

if [ ! -f "${EXE_PATH}" ]; then
    echo "[SqueezeBar] Binary not found. Building SqueezeBar.exe..."
    ./scripts/build_windows.sh
fi

echo "=========================================="
echo " Opening SqueezeBar.exe in CrossOver / Wine"
echo "=========================================="

if [ -d "/Applications/CrossOver.app" ]; then
    echo "[SqueezeBar] Launching with CrossOver..."
    open -a "/Applications/CrossOver.app" "${EXE_PATH}"
elif command -v wine &> /dev/null; then
    echo "[SqueezeBar] Launching with wine..."
    wine "${EXE_PATH}"
else
    echo "[SqueezeBar] Opening folder in Finder for manual CrossOver drag-and-drop..."
    open -R "${EXE_PATH}"
fi
