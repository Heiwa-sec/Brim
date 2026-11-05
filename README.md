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
| d File tray | Done, committed, **verified live by the maintainer (2026-11-05)** | Drop, drag out, Clear, three columns all work |
| e System (plan: the phase plan (kept outside the repo)) | e1 Charging, e2 Bluetooth, e3 Weather, e4 HUD all built, merged and committed; **none tested live by the maintainer yet** | Weather and HUD are off by default |
| f Settings and polish | Built and committed (settings window, 4 tabs); awaiting the maintainer's test. Per-display and hover options exist; polish items not done | Plan: the phase plan (kept outside the repo) |
| g Notification mirroring | Built, committed and **checked here** (real notifications mirrored with Full Disk Access); off by default; awaiting the maintainer's test | Plan: the phase plan (kept outside the repo) |
| h Lock-screen integration | **Dropped** (2026-11-05). Nothing from a normal app can show on the macOS 27 lock screen; the wallpaper trick was judged too risky for the Aerial wallpaper. Replaced by an opt-in full-screen Now Playing view on ⌥⌘L | Built, committed, checked here |

### Next step
the maintainer: (1) play music, then press ⌥⌘L or click the cover in the open island: full-screen view with drifting blurred cover, big cover, synced lyrics; Esc, or a click on the empty background, closes it (other keys only wake the controls); the bar under the title shows position and length and a click or drag on it seeks. Note what to change. (2) Test charging and notifications at home. Ideas not built: transport buttons on the full-screen view, a Settings toggle or other hot key for it.

Full-screen view as built (the cover in the expanded island is a plain `Button` that posts the same notification; verified through Accessibility, since synthetic mouse clicks were flaky): `Brim/FullScreen/FullScreenController.swift`. The ⌥⌘L Carbon hot key (registered with ⌥⌘, in `SettingsWindow.registerHotKey`, dispatched by hot key id) posts `.brimFullScreen`. One `.screenSaver`-level panel per screen (`DismissPanel` closes on any key or click) hosts `FullScreenView`: the cover blurred and slowly scaled and rotated by one SwiftUI animation, the cover, title and artist, and `LyricsView` at 640 pt wide, 40 pt font (it gained `width` and `fontSize` parameters). Nothing playing: the hot key does nothing. It never touches the lock. The panel is transparent and `FullScreenView` draws the black: it grows out of the top centre (the notch) with a spring and a shrinking corner radius, and shrinks back on close (`FullScreenState.shown`, 0.5 s; the panel is removed after the animation). The scrubber is the island's `ScrubberView`; under it is the island's `TransportView` (new `scale` parameter, 1.5 here), which fades out after 3 s without a mouse move or key press (`FullScreenState.poke()`, one one-shot work item, `onContinuousHover` plus the panel's key events) and stops taking clicks while hidden. Measured: about 5% CPU and 30 MB while open (the animated blur), 0.1% and 22 MB after closing.

**Test checklist (phase g, notification mirroring; off by default)**
Turn on "Notification mirroring" in Settings > Modules and add the app (or Terminal while running from it) to Full Disk Access; Settings > Permissions shows its state. Send yourself a Messages or Mail notification, or run `osascript -e 'display notification "hi" with title "t"'`: the island opens by itself for 5 s with an icon card. macOS writes the database a few seconds after it shows its own banner, so Brim's banner lags by about 5 s; this is the database, not Brim. Without Full Disk Access the island says so. Nothing is logged or stored.

**Test checklists (phase e)**
- *e1 Charging:* plug/unplug the charger: bolt (or battery) plus percent flash in the ears for 4 s. Hover on AC: Battery column. On battery: no column.
- *e2 Bluetooth:* allow the Bluetooth prompt. Connect AirPods: headphones glyph plus lowest earbud % flash for 4 s; hover lists connected devices with `L/R/Case` %. Disconnect: column goes. Off switch: `defaults write dev.brim.Brim module.bluetooth.enabled -bool false`. Checked here with AirPods Pro: shows `L 100% · R 100% · Case 94%`.
- *e3 Weather (off by default):* `defaults write dev.brim.Brim module.weather.enabled -bool true`, relaunch, allow Location, hover: symbol, temperature, description. Cache 30 min; refetch only on wake or location change. If the Location prompt never appears for an agent app, report it. Network: api.open-meteo.com only.
- *e4 HUD (off by default):* `defaults write dev.brim.Brim module.hud.enabled -bool true`, add Brim in Accessibility, then volume, mute and brightness keys: system HUD suppressed, our symbol plus bar in the ears for 1.5 s, 1/16 per press. Without Accessibility the island says so and keys behave normally. This is the spike: if brightness keys never reach the tap, say so and we add the listener fallback. Keyboard backlight keys are not handled.

Phase (e1) as built: `Brim/Modules/Charging/` holds `PowerInfo` (pure, tested, parses the IOKit description), `ChargingModule` (`IOPSNotificationCreateRunLoopSource` on the main run loop; flashes `hasActivity` for 4 s only when the AC state changes, using one one-shot work item) and `ChargingView`. Idle: 0.00% CPU, 13 MB, 0 leaks. Not tested here: a real plug event (the Mac was on battery).

Phases e2 to e4 as built: `Bluetooth/` (IOBluetooth connect/disconnect notifications, private battery properties behind `responds(to:)`, `BluetoothBattery` pure and tested), `Weather/` (CoreLocation reduced accuracy, Open-Meteo, `WeatherInfo` pure and tested), `HUD/` (`CGEventTap` on `NX_SYSDEFINED`, CoreAudio volume, DisplayServices brightness via dlsym, `HUDKey` pure and tested). `IslandModule` gained `static defaultEnabled` (default true; weather and HUD are false). They were built in parallel git worktrees, reviewed, then merged. Not run live: the Mac had no Bluetooth device connected, no Accessibility grant, no Location grant. Idle with all defaults: 0.00% CPU, 15 MB, 0 leaks (the first 30 s after launch read about 1% while IOBluetooth initialises; ignore it).

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
None open except the ⌥⌘L lock test in "Next step".

### Session log
- **2026-11-05 (lock dropped):** the ⌥⌘L show-then-lock panel vanished at lock, so lock-screen work was dropped. ⌥⌘L is now a full-screen Now Playing view with animated artwork background, cover and big lyrics. `Brim/LockScreen/` became `Brim/FullScreen/`; no private API remains. 37 tests pass.
- **2026-11-05 (lock fallback):** the maintainer reported the lock-screen card did not appear. Replaced the overlay with the ⌥⌘L pre-lock panel; deleted `LockSpike/`, `KillSwitch` (and its tests) and the Settings toggle; 37 tests pass. Panel and cancel verified by synthesizing the hot key; the real lock is owed by the maintainer.
- **2026-11-05 (phase h scaffolding):** kill switch, lock controller and Settings toggle built; rendering verified by posting the lock notification while unlocked; 41 tests pass. The real lock-screen test is owed by the maintainer.
- **2026-11-05 (phase g):** Notification mirroring built after the maintainer granted Full Disk Access. Schema checked on macOS 27 (db version 19): `record.data` is a bplist with `app`, `req.titl/subt/body`. Vnode source on `db-wal`; `IslandModule.wantsExpanded` plus `IslandModel.banner` open the island by themselves. Live test with `osascript display notification` worked; idle with the module on 0.0x% CPU.
- **2026-11-05 (Bluetooth fixes):** IOBluetooth's private battery properties read 0 on macOS 27, so batteries now come from `system_profiler SPBluetoothDataType -json` (about 70 ms, run on connect, at start and once 3 s after a connect), matched by device name because its addresses differ from IOBluetooth's. Removed the private-API code. Gear button moved to the menu-bar row.
- **2026-11-05 (phase f):** Settings window (`Brim/Settings/`): General (launch at login via SMAppService, hover delay), Modules (toggle per module), Displays (per screen), Permissions (status plus Open buttons). Opens from the island gear, ⌥⌘, (Carbon hot key, no permission) or relaunching Brim. Live launch found a real crash in e2: IOBluetooth calls the connect notification on a background thread and the `@MainActor` listener trapped; fixed by hopping to the main actor.
- **2026-11-05 (phase e run):** phase (e) sub-phases e1 to e4 built and merged; 34 tests pass; idle 0.00% CPU, 15 MB, 0 leaks. Awaiting the maintainer's live tests.
- **2026-11-05 (later, the maintainer confirmed phases c and d work):** phase (c) verified by the maintainer (the earlier "no lyrics" was an instrumental track; LRCLIB has no lyrics for it). Lyrics restyled like Apple Music. Phase (d) File tray built and committed: build and 20 tests pass; synthesized drag from Finder, drag-out to a folder and Clear all work; idle 0 leaks, main thread in `mach_msg`, 24 MB with the lyrics cache and artwork loaded.
- **2026-11-05:** phase (c) Lyrics built and committed; build and 20 tests pass; app idle: 0 leaks, 12 MB, nothing running in a 3 s stack sample (CPU readings were noisy on this machine: 0.5 to 0.6% for this build against 2.0% for the previous commit measured minutes later, so no regression). Live test with real music is still owed.
- **2026-11-04 (evening):** phases 0, (a) and (b) done and committed. Expand-from-notch fix done. the maintainer confirmed Now Playing works with real music and buttons need one click. Phase (c), Lyrics, is next and has not been started.

---

## Lock-screen findings (phase 0)

- A plain high-level window (`CGShieldingWindowLevel`, no private API) was reported on screen during the lock (`windowOnscreen=1`). Needs a longer, deliberate re-test.
- Private SkyLight space calls (`SLSSpaceAddWindowsAndRemoveFromSpaces`, `SLSAddWindowsToSpaces`, `SLSMoveWindowsToManagedSpace`, `SLSShowSpaces`) are all rejected with `0xB0000000` for a normally signed app on macOS 27.0.1, with call signatures matching the MIT SkyLightWindow reference. Likely an entitlement check in WindowServer; not obtainable with a free account.
- The post-reboot login window (before the first sign-in) cannot show music: no user session exists. Only the lock screen is supported.

**Result (2026-11-05):** the shielding-level window never showed on the real lock screen, and a show-then-lock panel vanishes at lock, so lock-screen work was dropped. Only untried idea: render the card into the wallpaper before locking (public API, but it overwrites the Aerial wallpaper setting and needs a backup of `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`).

---

## Rules for this project

- **Process:** plan first for new work; one phase at a time; each phase builds, runs, is checked for leaks and idle CPU, and is committed before the next.
- **Code:** small files, comments only where the logic is not obvious, no dead code, no fake data.
- **Privacy:** no analytics or telemetry. Only lyrics (LRCLIB) and weather (Open-Meteo) use the network, and both are toggleable.
- **Safety:** never test lock behaviour without Touch ID available (nothing in Brim locks the Mac now).
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
- `BrimTests/`: unit tests. Pure files are compiled straight into the test bundle, so tests never launch the app.

## Per-display settings (also in Settings, Displays tab)

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
