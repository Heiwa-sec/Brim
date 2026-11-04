import Foundation

struct LyricLine: Equatable, Sendable {
    var time: TimeInterval
    var text: String
}

/// Parser for the LRC synced-lyrics format, as returned by LRCLIB.
enum LRC {
    /// A line becomes current this long before its timestamp, so a timer that fires exactly on the boundary picks the new line.
    static let tolerance: TimeInterval = 0.05

    /// Lines sorted by time. Metadata tags such as `[ar:...]` are skipped; `[offset:ms]` shifts every line.
    /// Empty text is kept: it marks an instrumental gap.
    static func parse(_ source: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        var offset: TimeInterval = 0
        for raw in source.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [TimeInterval] = []
            while rest.first == "[", let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                rest = rest[rest.index(after: close)...]
                if let time = time(tag) {
                    times.append(time)
                } else if tag.lowercased().hasPrefix("offset:"),
                          let ms = Double(tag.dropFirst(7).trimmingCharacters(in: .whitespaces)) {
                    offset = ms / 1000
                }
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            lines += times.map { LyricLine(time: $0, text: text) }
        }
        // LRC offset is positive when lyrics should appear earlier.
        return lines.map { LyricLine(time: max(0, $0.time - offset), text: $0.text) }.sorted { $0.time < $1.time }
    }

    /// Index of the line being sung at `position`, or nil before the first line.
    static func index(at position: TimeInterval, in lines: [LyricLine]) -> Int? {
        var low = 0, high = lines.count
        while low < high {
            let mid = (low + high) / 2
            if lines[mid].time <= position + tolerance { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? nil : low - 1
    }

    /// `mm:ss`, `mm:ss.xx` or `mm:ss.xxx`; nil for anything else (metadata tags).
    private static func time(_ tag: Substring) -> TimeInterval? {
        let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let minutes = Int(parts[0]), minutes >= 0,
              let seconds = Double(parts[1]), seconds.isFinite, seconds >= 0 else { return nil }
        return Double(minutes) * 60 + seconds
    }
}
