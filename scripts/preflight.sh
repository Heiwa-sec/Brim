#!/bin/bash
# Run before every release: scripts/preflight.sh [--fast]   (--fast skips the tests and the Release build)
# Prints PASS / FAIL per check and exits 1 if any FAIL. Changes no file.
# Optional: BRIM_FORBIDDEN='word1|word2' scripts/preflight.sh also checks that no tracked file, commit or author contains those words.
cd "$(dirname "$0")/.." || exit 2
FAILS=0
check() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; FAILS=$((FAILS+1)); fi; }

echo "== Secrets"
check "no secret-like text or key/certificate/database files in any commit" "scripts/scan-secrets.sh"
[ -n "$BRIM_FORBIDDEN" ] && check "no forbidden words in tracked files, history or authors" \
  "! git ls-files -z | xargs -0 grep -qIiE '$BRIM_FORBIDDEN' && ! git log --all -p --format='%an %ae %cn %ce %s%n%b' | grep -qiE '$BRIM_FORBIDDEN'"

echo "== Network and dependencies"
check "only lrclib.net and api.open-meteo.com are contacted, over https" \
  "! grep -rhoE 'https?://[A-Za-z0-9.-]+' Brim --include='*.swift' | grep -vE '^https://(lrclib.net|api.open-meteo.com)\$'"
check "no third-party packages (only the vendored mediaremote-adapter)" "[ ! -f Package.swift ] && [ ! -f Podfile ] && [ \"\$(ls Vendor)\" = mediaremote-adapter ]"

echo "== Code"
check "no try!, as!, fatalError, print or NSLog in the app" "! grep -rnE 'try!|as!|fatalError|\\bprint\\(|NSLog' Brim --include='*.swift'"
check "entitlements are only camera and apple-events" "[ \"\$(grep -c '<key>' Brim/App/Brim.entitlements)\" = 2 ] && grep -q automation.apple-events Brim/App/Brim.entitlements && grep -q device.camera Brim/App/Brim.entitlements"
check "install.sh parses and pins the signing team" "sh -n scripts/install.sh && grep -q 'TeamIdentifier=' scripts/install.sh"

if [ "$1" != "--fast" ]; then
  echo "== Tests and Release build"
  check "unit tests pass" "xcodebuild -project Brim.xcodeproj -scheme BrimTests -derivedDataPath build test"
  APP=build/Build/Products/Release/Brim.app
  check "Release build succeeds" "xcodebuild -project Brim.xcodeproj -scheme Brim -configuration Release -derivedDataPath build build"
  check "signature valid and hardened runtime on" "codesign --verify --deep --strict $APP && codesign -dv $APP 2>&1 | grep -q 'flags=.*runtime'"
  check "usage strings for camera, location and Apple events are in Info.plist" \
    "for k in NSCameraUsageDescription NSLocationWhenInUseUsageDescription NSAppleEventsUsageDescription; do plutil -extract \$k raw $APP/Contents/Info.plist || exit 1; done"
  check "binary has no absolute user paths" "! strings -a $APP/Contents/MacOS/Brim | grep -qE '/Users/[A-Za-z]'"
  # the build leaves a second Brim.app in build/, which macOS then lists as a duplicate app
  rm -rf build/Build/Products/Release/Brim.app build/Build/Products/Debug/Brim.app
fi

echo
if [ $FAILS -eq 0 ]; then echo "PREFLIGHT PASSED"; else echo "PREFLIGHT: $FAILS item(s) to fix before you release"; exit 1; fi
