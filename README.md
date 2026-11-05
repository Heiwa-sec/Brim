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
| c Lyrics | Done, committed, **verified live by the maintainer (2026-11-05)** | Apple Music text style: 21 pt bold, current line gradient, others white 35% |
| d File tray | Built, committed. Drop and drag-out verified with synthesized events; **not yet tried by the maintainer** | See "Next step" |
| e Charging, Bluetooth/AirPods, weather, HUD | | |
| f Settings and polish | | |
| g Notification mirroring | | |
| h Lock-screen integration | | |

### Next step
the maintainer tries phase (d), the file tray, then phase (e) starts (plan first). Live test: drag a file from Finder up to the notch. The island opens and shows "Drop to add to tray"; drop it and a Tray column appears (icon, name, count). Also check: a second file adds a second item and the same file twice adds nothing; drag an item out to a folder or the Desktop (Finder copies it); "Clear" empties the tray and the island narrows; with music playing the island shows three columns (player, lyrics, tray); `defaults write dev.brim.Brim module.fileTray.enabled -bool false` removes the column and refuses drops.

Phase (d) as built: `Brim/Modules/FileTray/` holds `FileTrayModule` (file URLs in memory, de-duplicated; nothing copied; cleared on quit) and `FileTrayView` (215 pt column: count, Clear, a row of icons that drag out). `IslandModule` gained `receive(_:)` (default false) and `ModuleHost.drop(_:)`; `IslandView` has the drop destination. The controller's event mask now includes `leftMouseDragged`, so dragging a file to the notch opens the island like hovering does. Not done on purpose: persistence across relaunch, removing a single item, a compact-pill indicator.

### Decisions and gotchas worth knowing (so a new session need not rediscover them)
- **Plans:** the overall plan is the phase plan (kept outside the repo); the phase (c) plan is the phase plan (kept outside the repo). Each new phase gets its own short plan, approved before coding.
- **Lyrics layout (the maintainer chose):** the island widens with a lyrics column on the right (not a taller strip), and the artwork colour gradient fills only the current line's text; the island itself stays black.
- **"No lyrics" is silent by design.** Instrumental tracks (`instrumental: true`, `syncedLyrics: null`) and unknown tracks leave the island narrow. Check `~/Library/Caches/Brim/lyrics/` to see what LRCLIB answered.
- **LRCLIB** was probed live: `GET /api/get?track_name=&artist_name=` returns 200 with `syncedLyrics`, or 404 when there is no match. Duration and album are not sent.
- **Adding a source file:** run `xcodegen generate` first. Pure files that tests need must also be listed under `BrimTests` sources in `project.yml`. `Brim.xcodeproj` is generated and not committed.
- **SourceKit** in the editor reports "Cannot find type ..." across files until the project is regenerated. Trust `xcodebuild`, not those diagnostics.
- **CPU measurements are noisy** on this machine. To judge a regression, build the previous commit in a scratch `git worktree` and measure it back to back; do not compare against old numbers. A `sample <pid> 3` showing the main thread blocked in `mach_msg` means nothing is polling.
- **Pointer-driven wakeups:** the global mouse monitor wakes the app when the pointer moves anywhere, which is expected and not a leak.
- **Drag events:** while a drag is in progress macOS sends `leftMouseDragged`, not `mouseMoved`; the controller listens for both. The tray column is 215 pt, not 250: with player and lyrics beside it, 250 overflowed the island padding.
- **Synthetic drag tests:** hover the notch first, wait about a second for the island to open, then press on the tray icon; pressing before the island is open starts a drag on whatever is behind it.
- **Not tested without music:** anything depending on real playback (lyrics, scrubber, buttons). Build the feature, then hand the maintainer an exact checklist.

### Open questions for the maintainer
- **Lock test was too short.** The spike log showed LOCKED then UNLOCKED two seconds apart. Re-test with a longer lock (see below) before phase (h). Not blocking phases (c) to (g).

### Session log
- **2026-11-05 (later):** phase (c) verified by the maintainer (the earlier "no lyrics" was an instrumental track; LRCLIB has no lyrics for it). Lyrics restyled like Apple Music. Phase (d) File tray built and committed: build and 20 tests pass; synthesized drag from Finder, drag-out to a folder and Clear all work; idle 0 leaks, main thread in `mach_msg`, 24 MB with the lyrics cache and artwork loaded.
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
