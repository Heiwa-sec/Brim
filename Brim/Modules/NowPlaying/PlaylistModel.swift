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
    private(set) var name = ""
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
            JSON.stringify({ name: p.name(), tracks: t.map((n, i) => ({ title: n, artist: a[i] })) })
            """#)
            loading = false
            guard let data = result?.data(using: .utf8),
                  let json = try? JSONDecoder().decode(Payload.self, from: data) else { failed = true; return }
            name = json.name
            tracks = json.tracks
        }
    }

    /// Plays track `index` inside the same playlist, so playback carries on from there.
    func play(_ index: Int) {
        guard tracks.indices.contains(index) else { return }
        Task { _ = await Self.run("const M = Application('Music'); M.play(M.currentPlaylist().tracks[\(index)])") }
    }

    private struct Payload: Decodable { var name: String; var tracks: [PlaylistTrack] }

    /// Runs a JXA script off the main thread. Returns its output, or nil when Music is gone or macOS denied Automation.
    private static func run(_ script: String) async -> String? {
        await Task.detached {
            let process = Process(), out = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", script]
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
