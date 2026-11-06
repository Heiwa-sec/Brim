import CryptoKit
import Foundation

/// Fetches synced lyrics from lrclib.net. Sends only title and artist. Results, including "not found", are cached on disk
/// and expire: lyrics after 90 days, "not found" after a week (LRCLIB may have added them since).
enum LRCLibClient {
    private static let maxBytes = 512_000
    static let foundLifetime: TimeInterval = 90 * 86_400
    static let missLifetime: TimeInterval = 7 * 86_400

    /// Returns the LRC text, or nil when LRCLIB has no synced lyrics for this track. Throws on network or server errors, which are not cached.
    /// When the cached answer has expired but the network fails, the old lyrics are still better than none.
    static func syncedLyrics(title: String, artist: String) async throws -> String? {
        let file = cacheFile(title: title, artist: artist)
        let cached = try? Data(contentsOf: file)
        if let cached, isFresh(age: age(of: file), found: decode(cached) != nil) { return decode(cached) }
        do {
            return decode(try await fetch(title: title, artist: artist, into: file))
        } catch {
            if let cached, let stale = decode(cached) { return stale }
            throw error
        }
    }

    /// Whether a cached answer of this `age` may still be used.
    static func isFresh(age: TimeInterval, found: Bool) -> Bool { age < (found ? foundLifetime : missLifetime) }

    /// Deletes cached answers older than `foundLifetime`, so the folder cannot grow for ever. Run once at start.
    static func pruneCache(in directory: URL = cacheDirectory, now: Date = .now) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where now.timeIntervalSince(modified(file) ?? now) > foundLifetime { try? FileManager.default.removeItem(at: file) }
    }

    private static func fetch(title: String, artist: String, into file: URL) async throws -> Data {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        var request = URLRequest(url: components.url!, timeoutInterval: 10)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard data.count <= maxBytes else { throw URLError(.dataLengthExceedsMaximum) } // a real answer is a few KB; never cache a huge one
        let body: Data
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200:
            guard (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw URLError(.cannotParseResponse) }
            body = data
        case 404:
            body = Data("{}".utf8)
        default:
            throw URLError(.badServerResponse)
        }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? body.write(to: file, options: .atomic) // a fresh write also refreshes the file's age
        return body
    }

    private static func modified(_ file: URL) -> Date? {
        try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func age(of file: URL) -> TimeInterval { Date.now.timeIntervalSince(modified(file) ?? .distantPast) }

    private static func decode(_ data: Data) -> String? {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["syncedLyrics"] as? String
    }

    private static var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return "Brim/\(version) (personal)"
    }

    static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Brim/lyrics")
    }

    private static func cacheFile(title: String, artist: String) -> URL {
        let digest = SHA256.hash(data: Data("\(artist)\n\(title)".utf8)).map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(digest).json")
    }
}
