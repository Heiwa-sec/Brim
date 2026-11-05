import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted by the ⌥⌘L hot key.
    static let brimFullScreen = Notification.Name("dev.brim.Brim.fullScreen")
}

/// An opt-in full-screen Now Playing view: drifting blurred artwork, the cover, and big synced lyrics.
/// macOS draws nothing from other apps over the lock screen, so this is a normal window and never touches the lock.
/// ⌥⌘L toggles it; any key or click closes it.
@MainActor
final class FullScreenController {
    private let nowPlaying: NowPlayingModule
    private let lyrics: LyricsModule
    private var panels: [NSPanel] = []
    private var observer: NSObjectProtocol?

    init(nowPlaying: NowPlayingModule, lyrics: LyricsModule) {
        self.nowPlaying = nowPlaying
        self.lyrics = lyrics
        observer = NotificationCenter.default.addObserver(forName: .brimFullScreen, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.toggle() }
        }
    }

    func shutdown() { hide() }

    private func toggle() {
        guard panels.isEmpty else { return hide() }
        guard nowPlaying.info != nil else { return } // nothing playing, nothing to show
        panels = NSScreen.screens.map(makePanel)
        NSApp.activate()
        panels.first?.makeKey()
    }

    private func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels = []
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = DismissPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.onDismiss = { [weak self] in self?.hide() }
        panel.backgroundColor = .black
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: FullScreenView(nowPlaying: nowPlaying, lyrics: lyrics))
        panel.orderFrontRegardless()
        return panel
    }
}

/// Closes on the first key press or click, wherever it lands.
private final class DismissPanel: NSPanel {
    var onDismiss: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown || event.type == .leftMouseDown || event.type == .rightMouseDown { onDismiss?() } else { super.sendEvent(event) }
    }
}

private struct FullScreenView: View {
    let nowPlaying: NowPlayingModule
    let lyrics: LyricsModule
    @State private var drift = false

    var body: some View {
        ZStack {
            background
            HStack(spacing: 90) {
                VStack(spacing: 28) {
                    ArtworkView(image: nowPlaying.artwork, size: 420, radius: 32).shadow(radius: 40)
                    VStack(spacing: 6) {
                        Text(nowPlaying.info?.title ?? "").font(.system(size: 34, weight: .bold)).lineLimit(1)
                        Text(nowPlaying.info?.artist ?? nowPlaying.info?.album ?? "").font(.system(size: 24)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    }
                    .frame(width: 420)
                }
                if !lyrics.lines.isEmpty { LyricsView(module: lyrics, width: 640, fontSize: 40).frame(maxHeight: 760) }
            }
            .foregroundStyle(.white)
            .padding(60)
        }
        .ignoresSafeArea()
        .onAppear { drift = true }
    }

    /// Slow drift of the heavily blurred cover. Pre-scaled so the edges never show, and animated by Core Animation, not per frame.
    private var background: some View {
        ZStack {
            if let art = nowPlaying.artwork {
                Image(nsImage: art).resizable().scaledToFill().blur(radius: 90)
                    .scaleEffect(drift ? 2.2 : 1.7).rotationEffect(.degrees(drift ? 14 : -14))
                    .animation(.easeInOut(duration: 24).repeatForever(autoreverses: true), value: drift)
            }
            Color.black.opacity(0.35)
        }
        .clipped()
    }
}
