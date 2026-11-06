import Foundation
import Observation

struct PlaylistTrack: Equatable, Sendable {
    var title: String
    var artist: String
}

/// The tracks of the playlist Apple Music is playing, and a way to jump to one.
/// Only Music exposes this: Spotify's scripting cannot list a playlist and browsers expose no queue, so `supported` is false for them.
@MainActor @Observable
final class PlaylistModel {
    static let musicBundleID = "com.apple.Music"

    var tracks: [PlaylistTrack] = [] // settable so tests can fill it
    private(set) var loading = false
    private(set) var failed = false
    var open = false

    /// Index of the playing song, matched by title and artist so Next and Previous keep the highlight right with no polling.
    func current(title: String?, artist: String?) -> Int? {
        tracks.firstIndex { $0.title == title && $0.artist == (artist ?? "") }
    }

    func load() {
        guard !loading else { return }
        loading = true
        failed = false
        Task {
            let result = await Self.run(#"""
            const M = Application("Music"), p = M.currentPlaylist();
            const t = p.tracks.name(), a = p.tracks.artist();
            JSON.stringify(t.map((n, i) => ({ title: n, artist: a[i] })))
            """#)
            loading = false
            guard let data = result?.data(using: .utf8),
                  let list = try? JSONDecoder().decode([PlaylistTrack].self, from: data) else { failed = true; return }
            tracks = list
        }
    }

    /// True once a song was started from the list: Music then has no queue behind it and ignores its own skip command.
    private(set) var queueless = false

    /// Plays track `index` of the playlist.
    func play(_ index: Int) {
        guard tracks.indices.contains(index) else { return }
        queueless = true
        Task { _ = await Self.run("const M = Application('Music'); M.play(M.currentPlaylist().tracks[\(index)])") }
    }

    /// Next or Previous when Music has no queue (`queueless`): it ignores its own skip, so play the neighbouring song at once.
    /// Returns false when this does not apply and the normal skip command should be sent.
    func skipDirect(forward: Bool, title: String?, artist: String?) -> Bool {
        guard queueless, let i = current(title: title, artist: artist) else { return false }
        if tracks.indices.contains(i + (forward ? 1 : -1)) { play(i + (forward ? 1 : -1)) }
        return true
    }

    /// Safety net, run shortly after a normal skip: if Music is still on `title` it had no queue (for example a song
    /// started before Brim restarted), so step through the playlist ourselves. A no-op when the skip worked.
    func skipIfStuck(forward: Bool, title: String) {
        Task {
            let result = await Self.run("""
            function run(argv) {
              const M = Application('Music'), forward = argv[0] === 'true';
              if (M.currentTrack().name() !== argv[1]) return 'ok';
              const id = M.currentTrack().persistentID(), p = M.currentPlaylist();
              const i = p.tracks.persistentID().indexOf(id), j = i + (forward ? 1 : -1);
              if (i < 0 || j < 0 || j >= p.tracks.length) return 'ok';
              M.play(p.tracks[j]);
              return 'queueless';
            }
            """, arguments: [String(forward), title])
            if result?.hasPrefix("queueless") == true { queueless = true; if tracks.isEmpty { load() } } // load it, so the next skips take the instant path
        }
    }

    /// Runs a JXA script off the main thread. Returns its output, or nil when Music is gone or macOS denied Automation.
    private static func run(_ script: String, arguments: [String] = []) async -> String? {
        await Task.detached {
            let process = Process(), out = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", script] + arguments
            process.standardOutput = out
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? String(data: data, encoding: .utf8) : nil
        }.value
    }
}

extension PlaylistTrack: Decodable {}
