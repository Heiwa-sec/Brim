import Foundation

/// One now-playing snapshot, decoded from the adapter's JSON (run with `--micros`, so times are microseconds).
struct NowPlayingInfo: Equatable, Sendable {
    var bundleID: String
    var title: String
    var artist: String?
    var album: String?
    var playing: Bool
    var duration: TimeInterval?
    /// Elapsed time as of `timestamp`.
    var elapsed: TimeInterval
    var timestamp: Date
    var rate: Double
    var artwork: Data?

    /// Returns nil unless the adapter's mandatory keys (bundle, title, playing) are present, i.e. nothing is playing.
    init?(json: [String: Any]) {
        guard let bundle = json["bundleIdentifier"] as? String,
              let title = json["title"] as? String,
              let playing = json["playing"] as? Bool else { return nil }
        func seconds(_ key: String) -> TimeInterval? { (json[key] as? NSNumber).map { $0.doubleValue / 1_000_000 } }
        bundleID = bundle
        self.title = title
        artist = json["artist"] as? String
        album = json["album"] as? String
        self.playing = playing
        duration = seconds("durationMicros")
        elapsed = seconds("elapsedTimeMicros") ?? 0
        timestamp = seconds("timestampEpochMicros").map { Date(timeIntervalSince1970: $0) } ?? .now
        rate = (json["playbackRate"] as? NSNumber)?.doubleValue ?? 1
        artwork = (json["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
    }

    /// Playback position at `date`, extrapolated from the last reported elapsed time, so no polling is needed.
    func position(at date: Date) -> TimeInterval {
        let live = playing ? elapsed + max(0, date.timeIntervalSince(timestamp)) * (rate > 0 ? rate : 1) : elapsed
        return min(max(live, 0), duration ?? .greatestFiniteMagnitude)
    }
}

enum NowPlayingMerge {
    /// Applies one `stream` message. A full message replaces the state; a diff updates changed keys and a null removes a key.
    static func apply(_ payload: [String: Any], diff: Bool, to state: inout [String: Any]) {
        guard diff else { state = payload; return }
        for (key, value) in payload { state[key] = value is NSNull ? nil : value }
    }
}
