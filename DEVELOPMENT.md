# Brim: development notes

Maintainer notes: what is built, how to build and ship it, and the gotchas. The public README is `README.md`.

Brim is a macOS agent app (`LSUIElement`) that turns the notch into a Dynamic Island: now playing, synced lyrics, a full-screen player, a playlist list for Apple Music, a to-do list, a file tray, charging, weather, notification mirroring, a volume and brightness HUD and a call camera. Original design; nothing is copied from other notch apps (Boring Notch and MewNotch are GPL-3.0 and were not read for code).

Target: macOS 26+, Apple Silicon, Swift 6, SwiftUI plus AppKit. Built and tested on macOS 27, Xcode 27. Signed with a free Personal Team (stable identity, so permissions survive rebuilds); no paid developer account, so releases are not notarized.

## Status

All features below are built, committed and were checked on a real Mac. Untested against real use: the call camera (never run against a real FaceTime call) and the volume/brightness HUD and notification mirroring beyond a synthetic test.

| Feature | Notes |
|---|---|
| Island, notch geometry | Expands from the notch; the window pre-grows before the spring starts. Hover delay, per-display options, hide-until-top |
| Now Playing | Cover, title, scrubber, transport buttons. Data comes from the vendored mediaremote-adapter (see Gotchas) |
| Lyrics | LRCLIB synced lyrics, current line filled with an artwork-colour gradient. Lyrics button turns the module on and off |
| Full-screen view | ⌥⌘L or click the cover: blurred drifting cover, big cover and lyrics, auto-hiding controls. Esc or a click on the background closes it. While it is open Brim switches to a regular app (Dock icon, ⌘Tab, Force Quit list) and back to an agent app when it closes (`FullScreenController`, `setActivationPolicy`) |
| Tabs | Now Playing, Weather, To-do, File tray; two-finger sideways scroll or click a page dot. `IslandTab`, `ModuleHost.tabs/views(in:)/resolve` |
| Playlist swap | Apple Music only. List button beside the transport buttons (island and full screen) lists the playlist; a click plays that song. See Gotchas |
| Keep the notch open | Island stays open; with the pointer away it shows only centred lyrics and shrinks (`IslandModel.narrowLyrics`); hover brings back the full view. A chevron beside the gear closes it |
| Frosted-glass island | `frostedIsland`, `frostedIntensity`; never below 45% black |
| Subtle controls | Island controls use a faint fill and dim icons (`controlBackground`, `CircleControlButton`, scale 1 only; full screen keeps the glass) |
| To-do | `Brim/Modules/Todo/`, UserDefaults `todo.list`; the panel takes keyboard focus only on this tab (`IslandPanel.acceptsKeys`) |
| File tray | File URLs in memory, drag out, Clear. Nothing is copied |
| Charging | IOKit power-source notifications; flashes in the ears for 4 s when AC changes; column while on AC |
| Weather (off by default) | CoreLocation reduced accuracy, Open-Meteo, 30 min cache, refetch only on wake or location change |
| HUD (off by default) | `CGEventTap` on media keys, CoreAudio volume, DisplayServices brightness through `dlsym`; needs Accessibility |
| Notification mirroring (off by default) | Reads usernoted's database read-only (Full Disk Access); a vnode source on the write-ahead log signals new rows; the banner lags about 5 s because macOS writes the database late |
| Call camera (off by default) | Your own camera in a floating window while FaceTime runs and the camera is in use by another app. The other person's video is not built: no public API; only ScreenCaptureKit window capture (Screen Recording permission) |
| Settings | General, Modules, Displays, Permissions; opens from the gear, ⌥⌘, or relaunching the app. Permissions tab: **Allow** shows the system prompt for Accessibility, Location and Camera; for Full Disk Access (no prompt exists, and macOS does not list the app by itself) it opens the pane and reveals Brim.app in Finder to drag in. General ends with **Uninstall Brim…** (`Uninstaller`: moves the app to the Trash first, so a failure changes nothing, then removes the login item, preferences, caches and `tccutil reset`s the permissions it can) |
| Lock screen | Dropped: nothing from a normal app can draw on the macOS 27 lock screen (private SkyLight calls are rejected, a shielding-level window never showed). The full-screen view replaces it |

## Rules for this project

- **Process:** plan new work first; build, run, check idle CPU and leaks, then commit.
- **Code:** small files, comments only where the logic is not obvious, no dead code, no fake data.
- **Privacy:** no analytics or telemetry. Only lyrics (LRCLIB) and weather (Open-Meteo) use the network, and both can be switched off.
- **Event-driven only:** no polling timers. Allowed one-shots: hover delay, delayed panel shrink, next-lyric-line timer, banner and HUD timeouts.
- **Commits** carry no co-author or generated-by trailers.

## Build, test, measure

```
xcodegen generate                    # regenerate Brim.xcodeproj from project.yml
xcodebuild -project Brim.xcodeproj -scheme Brim -configuration Debug -derivedDataPath build build
xcodebuild -project Brim.xcodeproj -scheme BrimTests -derivedDataPath build test
scripts/measure.sh 60                # average idle CPU, memory footprint, leaks of the running app
```
Idle: about 0.0% CPU, 15 MB, 0 leaks. An animated SF Symbol in the compact pill cost 8% CPU, so it is static. Do not run `leaks` while hover-testing: it suspends the process.

Building leaves `Brim.app` copies under `build/Build/Products/`, and macOS lists them as extra apps. Install the release build to `/Applications` and delete the copies in `build/`.

## Release

`main` is branch-protected on GitHub: no force-push and no deletion, also for the admin. A history rewrite needs the protection lifted in the repo settings first, then restored.

0. `BRIM_FORBIDDEN='<words that must not appear>' scripts/preflight.sh` must print PREFLIGHT PASSED (secrets, hosts, entitlements, code hazards, tests, signed Release build, binary strings).
1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `project.yml`.
2. `scripts/release.sh` builds a Release app and writes `Brim.pkg` (double-click installer: installs to /Applications, quits the old copy, opens the new one), `Brim.dmg` and `Brim.zip`, each with a `.sha256`.
3. `gh release create vX.Y build/release/Brim.{pkg,dmg,zip}{,.sha256} --repo Heiwa-sec/Brim`.
4. Update `version` and `sha256` (from `Brim.dmg.sha256`) in `Casks/brim.rb` of the Homebrew tap `Heiwa-sec/homebrew-brim` and push.

`scripts/install.sh` (the Terminal one-liner in the README) always downloads the latest release's `Brim.zip`, checks its checksum and installs it. Files fetched with curl are not quarantined, so macOS shows no warning. The `.pkg`, `.dmg` and Homebrew routes still need Open Anyway once, because the app is not notarized. The signing certificate's name, which contains an email address, ships inside the app's signature.

Security audit (2026-11-05): no secrets in code or history, only two HTTPS calls, reply-size caps, hardened runtime on. Open limits: not sandboxed, one private macOS function (brightness), the media helper runs through `/usr/bin/perl`, the vendored mediaremote-adapter was not read beyond its license.

## Layout

- `Brim/Island/`: `NotchGeometry` (pure, tested), `IslandShape`, `IslandModel`, `IslandView`, `IslandPanel`, `IslandController` (one per display), `DisplayManager`, `DisplaySettings`.
- `Brim/Modules/`: the `IslandModule` protocol and `ModuleHost` (starts and stops modules from `module.<id>.enabled`; default on unless a module says otherwise). Each module has its own folder. Every module with expanded content becomes a column; `IslandModel.expandedColumns` widens the island.
- `Brim/FullScreen/`: the ⌥⌘L view. `Brim/Settings/`: the settings window. `Brim/App/`: `main.swift` (explicit entry point; `@main` on a delegate would never create it without a nib) and `AppDelegate`.
- `Vendor/mediaremote-adapter/`: BSD-3, unmodified; built as the embedded `MediaRemoteAdapter.framework` (bundled, not linked). `test.m` is excluded.
- `BrimTests/`: unit tests. Pure files are compiled straight into the test bundle (listed under `BrimTests` in `project.yml`), so tests never launch the app.

## Per-display settings (also in Settings > Displays)

Keys are `display.<display-uuid>.enabled` and `display.<display-uuid>.hideUntilTop`, plus a global `hoverDelay` (seconds, default 0.12).

## Permissions

| Permission | Why | When |
|---|---|---|
| Accessibility | HUD key tap | HUD on |
| Full Disk Access | Notification database | Notification mirroring on |
| Location (reduced accuracy) | Weather | Weather on |
| Camera | Own camera in a call | Call camera on |
| Automation (Music) | List and play the playlist | The playlist button is tapped, or Next/Previous is first pressed while Apple Music plays |
| Network: lrclib.net, api.open-meteo.com | Lyrics, weather | Their toggles on |

Full Disk Access cannot be requested by a prompt: the user drags Brim into the list (or clicks +), enters their password and reopens Brim. No Screen Recording or Input Monitoring. Nothing is requested at launch.

## Gotchas

- **Unit tests need a Debug build of Brim first.** After `rm -rf build` (or deleting `build/Build/Products`), `xcodebuild ... -scheme BrimTests test` fails with "Unable to resolve module dependency: 'Brim'". Run `xcodebuild -scheme Brim -configuration Debug -derivedDataPath build build` once, then the tests (and `scripts/preflight.sh`) pass.

- **Adding a source file:** run `xcodegen generate`. `Brim.xcodeproj` is generated and not committed. SourceKit reports "Cannot find type ..." across files until it is regenerated; trust `xcodebuild`.
- **Now Playing** uses the vendored mediaremote-adapter, run through Apple's own `/usr/bin/perl`, because macOS locks MediaRemote for ordinary apps. `MediaAdapter` streams JSON from it and sends commands (`send 2`, `send 4`, `send 5`, `seek`).
- **Apple Music queue:** Music ignores its own Next/Previous (even from AppleScript) after a song is started with `play track N`, because that leaves no queue. `PlaylistModel` remembers that (`queueless`) and plays the neighbouring track directly. When Brim does not know, `NowPlayingModule.skipInMusic` sends the normal skip and `PlaylistModel.skipIfStuck` checks 0.7 s later. The playlist is read and played with JXA through `/usr/bin/osascript`, only when the list button is tapped. Spotify cannot list a playlist and browsers expose no queue, so the button only shows for Apple Music.
- **Click latency:** a click on an already-open island must not call `IslandController.grow`; it lays out and draws the whole island synchronously before the click reaches the button. Play/pause flips its icon at once and the stream confirms it later.
- **"No lyrics" is silent by design.** Instrumental and unknown tracks leave the island narrow. The lyrics cache expires (found lyrics 90 days, "not found" 7 days, stale lyrics are still used if the network fails; `LRCLibClient.pruneCache` deletes files older than 90 days when the module starts). Check `~/Library/Caches/Brim/lyrics/` to see what LRCLIB answered (`GET /api/get?track_name=&artist_name=`; 200 with `syncedLyrics`, or 404).
- **Drag events:** during a drag macOS sends `leftMouseDragged`, not `mouseMoved`; the controller listens for both. For synthetic drag tests, hover the notch first and wait about a second before pressing on the tray icon.
- **Column width:** the side columns are `IslandModel.columnWidth` (215 pt); 250 overflowed the island padding.
- **Full-screen controls** hide after 3 s without input and stop taking clicks; move the pointer first.
- **CPU measurements are noisy.** To judge a regression, build the previous commit in a scratch `git worktree` and measure it back to back. A `sample <pid> 3` with the main thread in `mach_msg` means nothing is polling. The global mouse monitor wakes the app when the pointer moves, which is expected.
- **IOBluetooth** (removed module) calls back off the main thread and its battery properties read 0 on macOS 27; if Bluetooth ever returns, use `system_profiler SPBluetoothDataType -json`.
- **Anything that needs real playback** (lyrics, scrubber, buttons) cannot be tested without music playing.

## Third-party

`ungive/mediaremote-adapter` (BSD-3-Clause) is vendored; see `THIRD_PARTY_LICENSES.md`.
