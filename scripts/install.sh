#!/bin/sh
# Installs the latest Brim release: no Xcode, no Gatekeeper warning (curl downloads are not quarantined).
# Usage: curl -fsSL https://raw.githubusercontent.com/Heiwa-sec/Brim/main/scripts/install.sh | sh
set -e
base=https://github.com/Heiwa-sec/Brim/releases/latest/download
[ "$(uname -m)" = arm64 ] || { echo "Brim needs an Apple Silicon Mac." >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
echo "Downloading Brim..."
curl -fsSL -o Brim.zip "$base/Brim.zip"
curl -fsSL -o Brim.zip.sha256 "$base/Brim.zip.sha256"
shasum -a 256 -c Brim.zip.sha256 >/dev/null || { echo "Checksum mismatch, nothing installed." >&2; exit 1; }
ditto -x -k Brim.zip .
# The checksum comes from the same place as the download, so also require the maintainer's signing team: a swapped release fails here.
{ codesign --verify --deep --strict Brim.app && codesign -dv Brim.app 2>&1 | grep -qx "TeamIdentifier=CTGDR36LFJ"; } 2>/dev/null \
  || { echo "Signature check failed, nothing installed." >&2; exit 1; }
pkill -x Brim 2>/dev/null || true
rm -rf /Applications/Brim.app 2>/dev/null || sudo rm -rf /Applications/Brim.app
ditto Brim.app /Applications/Brim.app 2>/dev/null || sudo ditto Brim.app /Applications/Brim.app
open /Applications/Brim.app
echo "Brim installed. Hover the notch to open it."
