import AppKit
import SwiftUI

/// MediaRemote command IDs understood by `mediaremote-adapter send`.
enum MediaCommand: Int {
    case togglePlayPause = 2, next = 4, previous = 5
}

@MainActor @Observable
final class NowPlayingModule: IslandModule {
    static let id = "nowPlaying"
    static let title = "Now Playing"

    private(set) var info: NowPlayingInfo?
    private(set) var artwork: NSImage?
    private(set) var unavailable = false
    let playlist = PlaylistModel()

    /// The playlist list is showing: it is open and Apple Music is the player.
    var showsPlaylist: Bool { playlist.open && info?.bundleID == PlaylistModel.musicBundleID }

    @ObservationIgnored private var adapter: MediaAdapter?
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var restartWork: DispatchWorkItem?

    var hasActivity: Bool { info?.playing == true }
    var problem: String? { unavailable ? "Now Playing is unavailable" : nil }

    func start() {
        failures = 0
        unavailable = false
        launch()
    }

    func stop() {
        restartWork?.cancel()
        adapter?.stop()
        adapter = nil
        info = nil
        artwork = nil
    }

    func send(_ command: MediaCommand) {
        if info?.bundleID == PlaylistModel.musicBundleID, command != .togglePlayPause {
            let forward = command == .next
            // Previous restarts a song that is well under way, like the system controls do.
            if !forward, let info, info.position(at: .now) > 3 { return seek(to: 0) }
            if playlist.skipDirect(forward: forward, title: info?.title, artist: info?.artist) { return }
            MediaAdapter.run(["send", String(command.rawValue)])
            if let title = info?.title {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [playlist] in playlist.skipIfStuck(forward: forward, title: title) }
            }
            return
        }
        if command == .togglePlayPause, var now = info { // show the new state at once; the stream confirms it a moment later
            now.elapsed = now.position(at: .now)
            now.timestamp = .now
            now.playing.toggle()
            info = now
        }
        MediaAdapter.run(["send", String(command.rawValue)])
    }

    func seek(to seconds: TimeInterval) { MediaAdapter.run(["seek", String(Int(seconds * 1_000_000))]) }

    private func launch() {
        let adapter = MediaAdapter()
        self.adapter = adapter
        adapter.start { [weak self] event in
            Task { @MainActor in self?.handle(event, from: adapter) }
        }
    }

    private func handle(_ event: MediaAdapter.Event, from source: MediaAdapter) {
        guard source === adapter else { return } // late event from an adapter we already stopped
        switch event {
        case .info(let new):
            failures = 0
            if new?.artwork != info?.artwork { artwork = new?.artwork.flatMap { NSImage(data: $0) } }
            info = new
        case .ended:
            // The script died on its own (macOS update, missing file). Retry a few times, then give up visibly.
            failures += 1
            guard failures <= 3 else { unavailable = true; return }
            let work = DispatchWorkItem { [weak self] in self?.launch() }
            restartWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
        }
    }
}
