#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "=========================================="
echo " Building SqueezeBar Single-File Executable"
echo "=========================================="

dotnet publish SqueezeBar/SqueezeBar.csproj \
  -c Release \
  -r win-x64 \
  --self-contained true \
  -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -o ./dist_single

cp ./dist_single/SqueezeBar.exe ./SqueezeBar.exe
rm -rf ./dist_single

echo "=========================================="
echo " Build Complete!"
echo " Location: ./SqueezeBar.exe"
echo " Size: $(du -h ./SqueezeBar.exe | awk '{print $1}')"
echo "=========================================="
