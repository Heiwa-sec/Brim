#!/bin/sh
# Builds a Release app and writes build/release/Brim.pkg (double-click installer), Brim.dmg and Brim.zip, each with a SHA-256 checksum.
# Publish all six files; users compare the checksum before opening the app.
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
# The installer puts Brim in /Applications itself, quits a running copy first and opens the new one. Settings are untouched.
pkgbuild --component "$app" --install-location /Applications --scripts scripts/installer "$out/Brim.pkg" >/dev/null
(cd "$out" && for f in Brim.pkg Brim.dmg Brim.zip; do shasum -a 256 "$f" | tee "$f.sha256"; done)
