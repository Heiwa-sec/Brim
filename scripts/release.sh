#!/bin/sh
# Builds a Release app and writes build/release/Brim.zip and Brim.dmg, each with a SHA-256 checksum.
# Publish all four files; users compare the checksum before opening the app.
set -e
cd "$(dirname "$0")/.."
xcodegen generate >/dev/null
xcodebuild -project Brim.xcodeproj -scheme Brim -configuration Release -derivedDataPath build build | tail -1
out=build/release
app=build/Build/Products/Release/Brim.app
rm -rf "$out" && mkdir -p "$out"
ditto -c -k --keepParent "$app" "$out/Brim.zip"
# The disk image holds the app and a link to /Applications, so the user drags one onto the other.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Brim.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Brim -srcfolder "$stage" -ov -format UDZO "$out/Brim.dmg" >/dev/null
(cd "$out" && shasum -a 256 Brim.zip | tee Brim.zip.sha256 && shasum -a 256 Brim.dmg | tee Brim.dmg.sha256)
