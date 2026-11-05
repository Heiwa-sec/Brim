import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted by the ⌥⌘L hot key.
    static let brimLockNow = Notification.Name("dev.brim.Brim.lockNow")
}

/// macOS draws nothing from other apps over the lock screen, so Brim shows Now Playing full screen for a moment
/// before it locks the Mac itself. Pressing the hot key again during that moment cancels the lock.
@MainActor
final class LockScreenController {
    private static let delay: TimeInterval = 3

    private let nowPlaying: NowPlayingModule
    private var panels: [NSPanel] = []
    private var pending: DispatchWorkItem?
    private var observer: NSObjectProtocol?

    init(nowPlaying: NowPlayingModule) {
        self.nowPlaying = nowPlaying
        observer = NotificationCenter.default.addObserver(forName: .brimLockNow, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.toggle() }
        }
    }

    func shutdown() { hide() }

    private func toggle() {
        guard panels.isEmpty else { return hide() }
        guard nowPlaying.info != nil else { return lock() } // nothing to show, so lock straight away
        panels = NSScreen.screens.map(makePanel)
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.hide(); self?.lock() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: work)
    }

    private func hide() {
        pending?.cancel()
        pending = nil
        panels.forEach { $0.orderOut(nil) }
        panels = []
    }

    /// `SACLockScreenImmediate` is a private login.framework call (the same one the Lock Screen menu item uses); if it is
    /// ever missing the Mac simply does not lock.
    private func lock() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else { return }
        unsafeBitCast(symbol, to: (@convention(c) () -> Void).self)()
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .black
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: LockCard(module: nowPlaying))
        panel.orderFrontRegardless()
        return panel
    }
}

private struct LockCard: View {
    let module: NowPlayingModule

    var body: some View {
        VStack(spacing: 20) {
            ArtworkView(image: module.artwork, size: 240, radius: 24)
            VStack(spacing: 4) {
                Text(module.info?.title ?? "").font(.title.bold()).lineLimit(1)
                Text(module.info?.artist ?? module.info?.album ?? "").font(.title3).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
