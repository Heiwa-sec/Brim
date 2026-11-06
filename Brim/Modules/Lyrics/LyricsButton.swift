import SwiftUI

/// Turns the Lyrics module on and off, like the lyrics button in Apple Music. It writes the same key as Settings > Modules,
/// so `ModuleHost` stops the module (no lyrics fetch, no column) and restarts it, and the choice persists.
struct LyricsButton: View {
    var scale: CGFloat = 1
    @AppStorage("module.lyrics.enabled") private var on = LyricsModule.defaultEnabled

    var body: some View {
        Button { on.toggle() } label: {
            Image(systemName: on ? "quote.bubble.fill" : "quote.bubble")
                .font(.system(size: 15 * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(on ? 1 : 0.55))
                .frame(width: 34 * scale, height: 34 * scale)
        }
        .buttonStyle(.plain)
        .glassEffect(in: .circle)
        .accessibilityLabel(on ? "Hide lyrics" : "Show lyrics")
    }
}
