import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted by the ⌥⌘L hot key.
    static let brimFullScreen = Notification.Name("dev.brim.Brim.fullScreen")
}

/// An opt-in full-screen Now Playing view: drifting blurred artwork, the cover, and big synced lyrics.
/// macOS draws nothing from other apps over the lock screen, so this is a normal window and never touches the lock.
/// ⌥⌘L toggles it; Esc, or a click on the empty background, closes it. The transport buttons hide after 3 s without input.
@MainActor
final class FullScreenController {
    private static let duration = 0.5
    private static let animation = Animation.spring(duration: duration, bounce: 0.12)

    private let nowPlaying: NowPlayingModule
    private let lyrics: LyricsModule
    private var panels: [NSPanel] = []
    private var observer: NSObjectProtocol?
    private let state = FullScreenState()
    private var closing = false

    init(nowPlaying: NowPlayingModule, lyrics: LyricsModule) {
        self.nowPlaying = nowPlaying
        self.lyrics = lyrics
        observer = NotificationCenter.default.addObserver(forName: .brimFullScreen, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.toggle() }
        }
    }

    private func toggle() {
        guard !closing else { return }
        guard panels.isEmpty else { return hide() }
        guard nowPlaying.info != nil else { return } // nothing playing, nothing to show
        state.shown = false
        state.poke()
        panels = NSScreen.screens.map(makePanel)
        NSApp.activate()
        panels.first?.makeKey()
        DispatchQueue.main.async { withAnimation(Self.animation) { self.state.shown = true } }
    }

    /// Plays the collapse into the notch, then removes the panels.
    private func hide() {
        guard !panels.isEmpty, !closing else { return }
        closing = true
        state.stop()
        withAnimation(Self.animation) { state.shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration) { [weak self] in
            guard let self else { return }
            panels.forEach { $0.orderOut(nil) }
            panels = []
            closing = false
        }
    }

    /// Quit while open: no time to animate.
    func shutdownNow() { panels.forEach { $0.orderOut(nil) } }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = DismissPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.onDismiss = { [weak self] in self?.hide() }
        panel.onActivity = { [weak self] in self?.state.poke() }
        panel.isOpaque = false
        panel.backgroundColor = .clear // the view draws the black, so it can grow out of the notch
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: FullScreenView(nowPlaying: nowPlaying, lyrics: lyrics, state: state, close: { [weak self] in self?.hide() }))
        panel.orderFrontRegardless()
        return panel
    }
}

/// Esc closes; any other key only wakes the controls. Clicks are left to the view, so the scrubber and lyrics can use them.
private final class DismissPanel: NSPanel {
    var onDismiss: (() -> Void)?
    var onActivity: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else { return super.sendEvent(event) }
        if event.keyCode == 53 { onDismiss?() } else { onActivity?() }
    }
}

@MainActor @Observable
private final class FullScreenState {
    var shown = false
    var controlsVisible = true
    @ObservationIgnored private var hideWork: DispatchWorkItem?

    /// Shows the controls and restarts the 3 s countdown to hide them: one one-shot timer, nothing polls.
    func poke() {
        if !controlsVisible { withAnimation(.easeInOut(duration: 0.25)) { controlsVisible = true } }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { withAnimation(.easeInOut(duration: 0.4)) { self?.controlsVisible = false } }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    func stop() { hideWork?.cancel() }
}

private struct FullScreenView: View {
    let nowPlaying: NowPlayingModule
    let lyrics: LyricsModule
    let state: FullScreenState
    let close: () -> Void
    @State private var drift = false
    @AppStorage("lyricsFont") private var fontKey = LyricsFont.standard.rawValue

    var body: some View {
        ZStack {
            background.contentShape(Rectangle()).onTapGesture(perform: close)
            HStack(spacing: 90) {
                VStack(spacing: 28) {
                    ArtworkView(image: nowPlaying.artwork, size: 420, radius: 32).shadow(radius: 40)
                    VStack(spacing: 6) {
                        Text(nowPlaying.info?.title ?? "").font(.system(size: 34, weight: .bold)).lineLimit(1)
                        Text(nowPlaying.info?.artist ?? nowPlaying.info?.album ?? "").font(.system(size: 24)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    }
                    .frame(width: 420)
                    ScrubberView(module: nowPlaying).frame(width: 420)
                    TransportView(module: nowPlaying, scale: 1.5)
                        .overlay(alignment: .trailing) { LyricsButton(scale: 1.5) }
                        .frame(width: 420)
                        .opacity(state.controlsVisible ? 1 : 0)
                        .allowsHitTesting(state.controlsVisible)
                }
                if !lyrics.lines.isEmpty { LyricsView(module: lyrics, width: 780, fontSize: 56, fadeByDistance: true, style: LyricsFont(rawValue: fontKey) ?? .standard).frame(maxHeight: 900) }
            }
            .foregroundStyle(.white)
            .padding(60)
        }
        .onContinuousHover { _ in state.poke() }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: state.shown ? 0 : 60))
        // Grows out of, and shrinks back into, the top centre where the notch is.
        .scaleEffect(state.shown ? 1 : 0.06, anchor: .top)
        .opacity(state.shown ? 1 : 0)
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
