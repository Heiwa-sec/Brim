import AppKit
import SwiftUI

/// Shows a read-only now-playing card over the lock screen. Experimental: no public API puts a window there, so this uses
/// a shielding-level window and may simply not be visible. The card never takes focus and passes every click through.
@MainActor
final class LockScreenController {
    private let nowPlaying: NowPlayingModule
    private let killSwitch = KillSwitch()
    private var panels: [NSPanel] = []
    private var observers: [NSObjectProtocol] = []

    init(nowPlaying: NowPlayingModule) {
        self.nowPlaying = nowPlaying
        killSwitch.recordLaunch()
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.show() }
        })
        observers.append(center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        })
    }

    /// Hide and clear the flag on a clean quit, so only a crash leaves it set.
    func shutdown() { hide() }

    private var enabled: Bool { UserDefaults.standard.bool(forKey: "lockscreen.enabled") }

    private func show() {
        guard enabled, !killSwitch.tripped, panels.isEmpty, nowPlaying.info != nil else { return } // nothing to show without a track
        killSwitch.cardShown()
        panels = NSScreen.screens.map(makePanel)
    }

    private func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels = []
        killSwitch.cardHidden()
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let size = NSSize(width: 320, height: 96)
        let top = screen.frame.maxY - screen.safeAreaInsets.top
        let panel = NSPanel(contentRect: NSRect(x: screen.frame.midX - size.width / 2, y: top - size.height - 12, width: size.width, height: size.height),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
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
        HStack(spacing: 14) {
            ArtworkView(image: module.artwork, size: 64, radius: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(module.info?.title ?? "Nothing playing").font(.headline).lineLimit(1)
                Text(module.info?.artist ?? module.info?.album ?? "").font(.subheadline).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(width: 320, height: 96)
        .glassEffect(in: .rect(cornerRadius: 28))
    }
}
