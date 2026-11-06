# Brim

A small macOS app that turns the notch into a Dynamic Island: what is playing, synced lyrics, a file shelf, charging, and more. Hover the notch to open it.

![status: early release](https://img.shields.io/badge/status-early%20release-orange)

## What it does

- **Now Playing:** cover, title, artist, progress bar and transport buttons for whatever is playing (Music, Spotify, a browser).
- **Lyrics:** synced lyrics next to the player, fetched from [LRCLIB](https://lrclib.net).
- **Full-screen view:** click the cover, or press **⌥⌘L**. A big cover, big lyrics and a slow animated background. Esc closes it.
- **Playlist swap (Apple Music):** tap the list button next to the transport buttons, in the island or the full-screen view, to see the playlist that is playing and click any song to jump to it. Other players (Spotify, browsers) do not expose their playlists, so the button only shows for Apple Music.
- **File tray:** drag files to the notch to park them, drag them out later. Nothing is copied.
- **Charging:** a short flash when you plug in or unplug.
- **Off by default:** weather, volume and brightness HUD, and notification mirroring. Turn them on in Settings > Modules.

Open Settings with **⌥⌘,** or the gear in the island.

## Requirements

macOS 26 or later on an Apple Silicon Mac. Built and tested on a MacBook Air with a notch on macOS 27. Other setups are untested.

## Install

You do **not** need Xcode. Brim is a ready-to-run app; pick whichever route you like.

**1. One line in Terminal (no warning from macOS):**
```
curl -fsSL https://raw.githubusercontent.com/Heiwa-sec/Brim/main/scripts/install.sh | sh
```
It downloads the latest release, checks its SHA-256, puts Brim in Applications and opens it. Run it again to update. You can read the script first: [scripts/install.sh](scripts/install.sh).

**2. Normal installer (double-click):**
1. Download `Brim.pkg` from the [latest release](../../releases/latest).
2. Double-click it and follow the steps. Brim lands in Applications and opens.
3. Brim is **not notarized** (that needs a paid Apple Developer account), so macOS warns the first time. Open **System Settings > Privacy & Security**, scroll down and click **Open Anyway** next to Brim.pkg. This is expected.
4. To update, run the new installer: it quits the old copy and keeps your settings.

Optional: check the download with `shasum -a 256 -c Brim.pkg.sha256` (it must print `Brim.pkg: OK`). A drag-to-Applications `Brim.dmg` and a `Brim.zip` are on the release too; macOS asks for **Open Anyway** once with those.

**3. Homebrew:**
```
brew tap Heiwa-sec/brim
brew trust Heiwa-sec/brim
brew install --cask brim
```
Recent Homebrew versions need the `brew trust` step once for third-party taps. macOS still asks for Open Anyway the first time you open Brim.

Prefer not to trust a download? Build it yourself, below.

## Build from source

Only needed if you want to change the code. You need Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

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
| Automation (Music) | Listing and playing the songs of the current Apple Music playlist | You tap the playlist button |
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
