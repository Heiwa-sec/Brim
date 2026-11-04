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
| a Panel, geometry, states | Done, committed | Hover verified by script; needs your hands-on test |
| b Now Playing | **Next** | |
| c Lyrics | | |
| d File tray | | |
| e Charging, Bluetooth/AirPods, weather, HUD | | |
| f Settings and polish | | |
| g Notification mirroring | | |
| h Lock-screen integration | | |

### Next step
Phase (b): Now Playing. Vendor `ungive/mediaremote-adapter` (BSD-3, keep its licence in `THIRD_PARTY_LICENSES.md`), run `perl … stream` as a child process, merge the JSON diffs, and show title/artist/artwork/scrubber/transport plus a compact live activity. Introduce the `IslandModule` protocol and `ModuleHost` here (not before; phase (a) had no modules).

### Open questions for the maintainer
- **Lock test was too short.** The spike log showed LOCKED then UNLOCKED two seconds apart. You saw the card, but we are not sure it showed *over the lock UI* rather than just before or after. Re-test with a longer lock (see below) before phase (h).

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
Measured after phase (a): 0.0% idle CPU, about 33 MB resident collapsed (about 50 MB after the first expand), 0 leaks.
Do not run `leaks` while hover-testing: it suspends the process.

## Layout

- `Brim/Island/`: `NotchGeometry` (pure, tested), `IslandShape`, `IslandModel`, `IslandView`, `IslandPanel`, `IslandController` (one per display), `DisplayManager`, `DisplaySettings`.
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

`ungive/mediaremote-adapter` (BSD-3-Clause) is vendored from phase (b). See `THIRD_PARTY_LICENSES.md` once added.
