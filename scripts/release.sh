#!/bin/sh
# Builds a Release app and writes build/release/Brim.zip plus its SHA-256 checksum.
# Publish both files; users compare the checksum before opening the app.
set -e
cd "$(dirname "$0")/.."
xcodegen generate >/dev/null
xcodebuild -project Brim.xcodeproj -scheme Brim -configuration Release -derivedDataPath build build | tail -1
out=build/release
rm -rf "$out" && mkdir -p "$out"
ditto -c -k --keepParent build/Build/Products/Release/Brim.app "$out/Brim.zip"
(cd "$out" && shasum -a 256 Brim.zip | tee Brim.zip.sha256)
