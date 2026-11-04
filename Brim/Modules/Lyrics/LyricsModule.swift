import AppKit
import SwiftUI

/// Fetches and holds synced lyrics for whatever `NowPlayingModule` reports. Shows nothing when there are none.
@MainActor @Observable
final class LyricsModule: IslandModule {
    static let id = "lyrics"

    let nowPlaying: NowPlayingModule
    private(set) var lines: [LyricLine] = []
    private(set) var palette = ArtworkPalette.white

    @ObservationIgnored private var key: String?
    @ObservationIgnored private var artwork: NSImage?
    @ObservationIgnored private var fetch: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(nowPlaying: NowPlayingModule) { self.nowPlaying = nowPlaying }

    var expanded: AnyView? { lines.isEmpty ? nil : AnyView(LyricsView(module: self)) }

    func start() {
        generation += 1
        track(generation)
    }

    func stop() {
        generation += 1 // retires any pending observation callback
        fetch?.cancel()
        lines = []
        key = nil
        artwork = nil
        palette = .white
    }

    /// Re-arms itself because observation fires once per change.
    private func track(_ generation: Int) {
        let (info, art) = withObservationTracking {
            (nowPlaying.info, nowPlaying.artwork)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.track(generation)
            }
        }
        refresh(info, art)
    }

    private func refresh(_ info: NowPlayingInfo?, _ art: NSImage?) {
        if art !== artwork {
            artwork = art
            palette = art.map(ArtworkPalette.sample) ?? .white
        }
        let newKey = info.map { "\($0.artist ?? "")\n\($0.title)" }
        guard newKey != key else { return }
        key = newKey
        fetch?.cancel()
        lines = []
        // LRCLIB needs an artist; without one there is nothing sensible to look up.
        guard let info, let artist = info.artist, !artist.isEmpty else { return }
        let title = info.title
        fetch = Task {
            let text = try? await LRCLibClient.syncedLyrics(title: title, artist: artist)
            guard !Task.isCancelled, key == newKey else { return } // the track changed while we waited
            lines = text.map(LRC.parse) ?? []
        }
    }
}
