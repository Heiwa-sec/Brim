# Brim

A small macOS app that turns the notch into a Dynamic Island: what is playing, synced lyrics, a file shelf, charging, and more. Hover the notch to open it.

![status: early release](https://img.shields.io/badge/status-early%20release-orange)

## What it does

- **Now Playing:** cover, title, artist, progress bar and transport buttons for whatever is playing (Music, Spotify, a browser).
- **Lyrics:** synced lyrics next to the player, fetched from [LRCLIB](https://lrclib.net).
- **Full-screen view:** click the cover, or press **⌥⌘L**. A big cover, big lyrics and a slow animated background. Esc closes it.
- **File tray:** drag files to the notch to park them, drag them out later. Nothing is copied.
- **Charging:** a short flash when you plug in or unplug.
- **Off by default:** weather, volume and brightness HUD, and notification mirroring. Turn them on in Settings > Modules.

Open Settings with **⌥⌘,** or the gear in the island.

## Requirements

macOS 26 or later on an Apple Silicon Mac. Built and tested on a MacBook Air with a notch on macOS 27. Other setups are untested.

## Install

Brim is **not notarized** (that needs a paid Apple Developer account; this project uses a free one), so macOS shows one warning the first time you open the installer: it "cannot verify" Brim is free of malware. This is expected.

1. Download `Brim.pkg` and `Brim.pkg.sha256` from the [latest release](../../releases/latest).
2. Optional: in Terminal, in the download folder, run `shasum -a 256 -c Brim.pkg.sha256`. It must print `Brim.pkg: OK`.
3. Double-click `Brim.pkg`. If macOS blocks it, open **System Settings > Privacy & Security**, scroll down and click **Open Anyway** next to Brim.pkg (or right-click the file and choose Open).
4. Follow the installer. It puts Brim in Applications and opens it. To update, run the new installer: it quits the old copy first and keeps your settings.

A drag-to-Applications `Brim.dmg` and `Brim.zip` are on the release too, each with its own checksum. If you use one of those, macOS asks you to click Open Anyway once when you first open Brim.

Prefer not to trust a download? Build it yourself, below.

## Build from source

You need Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```
git clone <this repo>
cd Brim
xcodegen generate
xcodebuild -project Brim.xcodeproj -scheme Brim -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Brim.app
```

The project is set up for the author's Apple team. Open `project.yml`, change `DEVELOPMENT_TEAM` to your own team ID (or remove it to sign locally), and run `xcodegen generate` again. Run the tests with `xcodebuild -project Brim.xcodeproj -scheme BrimTests -derivedDataPath build test`.

## Permissions

Brim asks for nothing when it starts. Each permission is requested only when you switch on the feature that needs it.

| Permission | Used for | Needed when |
|---|---|---|
| Accessibility | Replacing the volume and brightness overlay | HUD is on |
| Full Disk Access | Reading new notifications from macOS's notification database | Notification mirroring is on |
| Location (approximate) | Local weather | Weather is on |
| Camera | Showing your own camera while a FaceTime call is active | Call camera is on |

Brim is not sandboxed, because those features cannot work inside the sandbox. It does not use Screen Recording, Input Monitoring, Contacts, Photos or the microphone.

## Privacy

No accounts, analytics or telemetry. Brim talks to the network in two places, both over HTTPS and both optional:

- **lrclib.net:** the title and artist of the current song, to find lyrics. Answers are cached in `~/Library/Caches/Brim/lyrics`.
- **api.open-meteo.com:** your location rounded to about 11 km, only if you turn Weather on.

Call camera shows your own camera on screen only while a FaceTime call is active. The video is never recorded, saved or sent anywhere.

Notification mirroring reads the title, text and app name of new notifications, read-only, keeps them in memory while the banner shows, and never logs, saves or sends them.

## Known limits

- **Not on the lock screen.** macOS does not let apps draw there. Use the full-screen view instead.
- The volume and brightness HUD uses an undocumented macOS function and could break in a future update.
- Now Playing relies on a helper that runs through Apple's own `/usr/bin/perl`, because macOS locks the media APIs for ordinary apps. A macOS update could break it.

## Reporting a problem

Open an issue. For a security problem, please report it privately through GitHub's "Report a vulnerability" button on the Security tab, not in a public issue.

## Credits and license

MIT, see [LICENSE](LICENSE). Brim bundles [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause), see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md). Lyrics come from LRCLIB and weather from Open-Meteo. Maintainer notes are in [DEVELOPMENT.md](DEVELOPMENT.md).
