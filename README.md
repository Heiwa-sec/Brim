# Brim

A personal macOS agent app: a Dynamic Island-style surface around the notch, plus music on the lock screen. Original design; nothing copied from Canopy or from GPL notch apps (Boring Notch and MewNotch are GPL-3.0 and are not read for code).

Target: macOS 26+, Apple Silicon, Swift 6, SwiftUI plus AppKit, agent app (`LSUIElement`). Built and tested on macOS 27.0.1, Xcode 27.2. Signed with the free Personal Team (`CTGDR36LFJ`), so permissions survive rebuilds. No paid developer account is needed.

---

## PASTE THIS AT THE START OF EVERY SESSION


---

## Status

| Phase | State | Notes |
|---|---|---|
| 0 Lock-screen spike | Done, committed | See "Lock-screen findings" |
| a Panel, geometry, states | Done, committed | Expands from the notch (fixed: window pre-grows before the spring starts) |
| b Now Playing | Done, committed, **verified live by the maintainer (2026-11-04)** | Real playback works; buttons respond on the first click |
| c Lyrics | Built, 20 unit tests pass, committed. **Not yet verified live by the maintainer** (needs real music) | See "Next step" |
| d File tray | | |
| e Charging, Bluetooth/AirPods, weather, HUD | | |
| f Settings and polish | | |
| g Notification mirroring | | |
| h Lock-screen integration | | |

### Next step
the maintainer live-tests phase (c), then start phase (d), the file tray. Live test: play a well-known song in Music or Spotify, hover the notch. The island should widen and a lyrics column should appear on the right, following the song, with the current line in the artwork's colours. Also check: tap a line to seek; pause freezes the highlight; skipping a track refetches; an unknown track leaves the island narrow; replaying a song makes no network request (a file appears in `~/Library/Caches/Brim/lyrics/`); `defaults write dev.brim.Brim module.lyrics.enabled -bool false` removes the column.

Phase (c) as built: `Brim/Modules/Lyrics/` holds `LRC` (parser, tested), `LRCLibClient` (title and artist only; caches hits and 404s on disk; 404s never expire, so delete the cache folder to retry), `ArtworkPalette` (8x8 downsample, tested), `LyricsModule` (own module id `lyrics`, refetches when title or artist changes) and `LyricsView`. Timing has no timer: the view's `TimelineView` has one scheduled date per upcoming line, only while the island is expanded and playing. Not done on purpose: unsynced lyrics fallback, title cleaning ("Remastered"), no retry after a network failure until the track changes, settings UI (phase f).

### Open questions for the maintainer
- **Lock test was too short.** The spike log showed LOCKED then UNLOCKED two seconds apart. Re-test with a longer lock (see below) before phase (h). Not blocking phases (c) to (g).

### Session log
- **2026-11-05:** phase (c) Lyrics built and committed; build and 20 tests pass; app idle: 0 leaks, 12 MB, nothing running in a 3 s stack sample (CPU readings were noisy on this machine: 0.5 to 0.6% for this build against 2.0% for the previous commit measured minutes later, so no regression). Live test with real music is still owed.
- **2026-11-04 (evening):** phases 0, (a) and (b) done and committed. Expand-from-notch fix done. the maintainer confirmed Now Playing works with real music and buttons need one click. Phase (c), Lyrics, is next and has not been started.

---

## Lock-screen findings (phase 0)

- A plain high-level window (`CGShieldingWindowLevel`, no private API) was reported on screen during the lock (`windowOnscreen=1`). Needs a longer, deliberate re-test.
- Private SkyLight space calls (`SLSSpaceAddWindowsAndRemoveFromSpaces`, `SLSAddWindowsToSpaces`, `SLSMoveWindowsToManagedSpace`, `SLSShowSpaces`) are all rejected with `0xB0000000` for a normally signed app on macOS 27.0.1, with call signatures matching the MIT SkyLightWindow reference. Likely an entitlement check in WindowServer; not obtainable with a free account.
- The post-reboot login window (before the first sign-in) cannot show music: no user session exists. Only the lock screen is supported.

**Safe re-test** (click-through, never takes focus, exits itself):
`~/Developer/Brim/build/Build/Products/Debug/LockSpike.app/Contents/MacOS/LockSpike --seconds 60 --shield`, then lock with ⌃⌘Q, wait about 10 seconds with the screen locked, unlock with Touch ID, and send me `LockSpike/spike.log`.

---

## Rules for this project

- **Process:** plan first for new work; one phase at a time; each phase builds, runs, is checked for leaks and idle CPU, and is committed before the next.
- **Code:** small files, comments only where the logic is not obvious, no dead code, no fake data.
- **Privacy:** no analytics or telemetry. Only lyrics (LRCLIB) and weather (Open-Meteo) use the network, and both are toggleable.
- **Safety:** the lock-screen widget must never take focus and must pass clicks through. Kill switch: `--disable-lockscreen` plus auto-disable after two crashes in a row. Never test lock behaviour without Touch ID available.
- **Event-driven only:** no polling timers. Allowed one-shots: hover delay, delayed panel shrink, next-lyric-line timer.

---

## Build, test, measure

```
xcodegen generate                    # regenerate Brim.xcodeproj from project.yml
xcodebuild -project Brim.xcodeproj -scheme Brim -configuration Debug -derivedDataPath build build
xcodebuild -project Brim.xcodeproj -scheme BrimTests -derivedDataPath build test
build/Build/Products/Debug/Brim.app/Contents/MacOS/Brim &
scripts/measure.sh 60                # average idle CPU, memory footprint, leaks
```
Measured after phase (b), idle: 0.01% CPU, 13 MB footprint, 0 leaks. With a (fake) track: compact 0.01%, expanded 0.4% (scrubber timeline, only while expanded). An animated SF Symbol in the compact pill cost 8% CPU, so it is static.
Do not run `leaks` while hover-testing: it suspends the process.

## Layout

- `Brim/Island/`: `NotchGeometry` (pure, tested), `IslandShape`, `IslandModel`, `IslandView`, `IslandPanel`, `IslandController` (one per display), `DisplayManager`, `DisplaySettings`.
- `Brim/Modules/`: `IslandModule` protocol and `ModuleHost` (starts/stops modules from `module.<id>.enabled`, default on); `NowPlaying/` holds the module, views, `MediaAdapter` (Perl child process) and `NowPlayingInfo` (pure, tested); `Lyrics/` is described under "Next step". Every module with expanded content becomes a column; `IslandModel.expandedColumns` widens the island.
- `Vendor/mediaremote-adapter/`: BSD-3, unmodified; built as the embedded `MediaRemoteAdapter.framework` (bundled, not linked). `test.m` is excluded from the build.
- `Brim/App/`: `main.swift` (explicit entry point; `@main` on a delegate would never create it without a nib), `AppDelegate`.
- `LockSpike/`: throwaway lock-screen prototype, deleted after phase (h).
- `BrimTests/`: unit tests. Pure files are compiled straight into the test bundle, so tests never launch the app.

## Per-display settings (until the settings UI in phase f)

Keys are `display.<display-uuid>.enabled` and `display.<display-uuid>.hideUntilTop`, plus a global `hoverDelay` (seconds, default 0.12).
```
defaults write dev.brim.Brim display.<uuid>.hideUntilTop -bool true
```

## Permissions the finished app will request, and why

| Permission | Why | When |
|---|---|---|
| Accessibility | HUD replacement key tap | HUD module on |
| Full Disk Access | Read the notification database | Notification mirroring opted in |
| Bluetooth | Device and AirPods battery | Bluetooth module on |
| Location (reduced accuracy) | Weather | Weather opted in |
| Network: lrclib.net, api.open-meteo.com | Lyrics, weather | Their toggles on |

No Automation, Screen Recording or Input Monitoring. Phase (a) requests none.

## Third-party

`ungive/mediaremote-adapter` (BSD-3-Clause) is vendored; see `THIRD_PARTY_LICENSES.md`.
