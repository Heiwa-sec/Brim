// THROWAWAY SPIKE. Usage: LockSpike [--seconds N (max 300, default 60)] [--level N (default 300)] [--shield]
// Shows a small click-through glass card at top-centre and logs lock/unlock events to LockSpike/spike.log.
// Hard deadline: the process always exits after --seconds, so a forced restart is never needed.
import AppKit
import SwiftUI

let args = CommandLine.arguments
func intArg(_ flag: String) -> Int? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return Int(args[i + 1])
}
let seconds = min(max(intArg("--seconds") ?? 60, 5), 300)
let level = Int32(clamping: intArg("--level") ?? 300)

let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer/Brim/LockSpike/spike.log")
func log(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: .now)) \(message)\n"
    print(line, terminator: "")
    fflush(stdout)
    if let data = line.data(using: .utf8) {
        if let handle = try? FileHandle(forWritingTo: logURL) { handle.seekToEndOfFile(); handle.write(data); try? handle.close() }
        else { try? data.write(to: logURL) }
    }
}

struct SpikeCard: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("LockSpike").font(.caption).foregroundStyle(.secondary)
            Text(Date.now, style: .time).font(.system(size: 34, weight: .semibold, design: .rounded))
        }
        .frame(width: 280, height: 110)
        .glassEffect(in: .rect(cornerRadius: 28))
    }
}

@MainActor final class SpikeApp: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var skyLight: SkyLight?
    var space: UInt64?

    func applicationDidFinishLaunching(_ note: Notification) {
        log("start macOS \(ProcessInfo.processInfo.operatingSystemVersionString) seconds=\(seconds) level=\(level)")
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let size = NSSize(width: 280, height: 110)
        let origin = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - screen.safeAreaInsets.top - size.height - 12)
        panel = NSPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = args.contains("--shield") ? NSWindow.Level(rawValue: Int(CGShieldingWindowLevel())) : .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true // click-through: nothing here may ever intercept the password field
        panel.contentView = NSHostingView(rootView: SpikeCard())
        panel.orderFrontRegardless()

        skyLight = SkyLight.load(log: log)
        if let skyLight {
            let result = skyLight.present(windowID: panel.windowNumber, level: level)
            space = result.space
            log("space=\(result.space) statuses=\(result.statuses)")
        }

        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.onLockChange("LOCKED") }
        center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.onLockChange("UNLOCKED") }

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) { [weak self] in
            self?.finish("deadline reached")
        }
        for sig in [SIGINT, SIGTERM] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in self?.finish("signal \(sig)") }
            source.resume()
            signalSources.append(source)
        }
    }

    var signalSources: [DispatchSourceSignal] = []

    func onLockChange(_ state: String) {
        // Ask the window server whether our window is really on screen; the human still confirms visually.
        let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(panel.windowNumber)) as? [[String: Any]]
        let onscreen = info?.first?[kCGWindowIsOnscreen as String] ?? "n/a"
        log("\(state) windowOnscreen=\(onscreen)")
    }

    func finish(_ reason: String) {
        if let space, let skyLight { skyLight.dismiss(space: space) }
        log("exit: \(reason)")
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = SpikeApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
