#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "=========================================="
echo " Building SqueezeBar for Windows (win-x64)"
echo "=========================================="

OUTPUT_DIR="./dist/win-x64"
rm -rf "${OUTPUT_DIR}"

dotnet publish SqueezeBar/SqueezeBar.csproj \
  -c Release \
  -r win-x64 \
  --self-contained true \
  -p:PublishSingleFile=false \
  -o "${OUTPUT_DIR}"

echo "=========================================="
echo " Build Succeeded!"
echo " Windows Binary: ${OUTPUT_DIR}/SqueezeBar.exe"
echo " Total Package Size: $(du -sh "${OUTPUT_DIR}" | awk '{print $1}')"
echo "=========================================="
