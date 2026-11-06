import SwiftUI

/// Turns the Lyrics module on and off, like the lyrics button in Apple Music. It writes the same key as Settings > Modules,
/// so `ModuleHost` stops the module (no lyrics fetch, no column) and restarts it, and the choice persists.
struct LyricsButton: View {
    var scale: CGFloat = 1
    @AppStorage("module.lyrics.enabled") private var on = LyricsModule.defaultEnabled

    var body: some View {
        CircleControlButton(symbol: on ? "quote.bubble.fill" : "quote.bubble", on: on, label: on ? "Hide lyrics" : "Show lyrics", scale: scale) { on.toggle() }
    }
}
