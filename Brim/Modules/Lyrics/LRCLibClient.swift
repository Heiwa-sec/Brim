import CryptoKit
import Foundation

/// Fetches synced lyrics from lrclib.net. Sends only title and artist. Results, including "not found", are cached on disk.
enum LRCLibClient {
    /// Returns the LRC text, or nil when LRCLIB has no synced lyrics for this track. Throws on network or server errors, which are not cached.
    static func syncedLyrics(title: String, artist: String) async throws -> String? {
        let file = cacheFile(title: title, artist: artist)
        if let cached = try? Data(contentsOf: file) { return decode(cached) }

        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        var request = URLRequest(url: components.url!, timeoutInterval: 10)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)

        let status = (response as? HTTPURLResponse)?.statusCode
        let body: Data
        switch status {
        case 200:
            guard (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw URLError(.cannotParseResponse) }
            body = data
        case 404:
            // shortcut: negative entries never expire; delete ~/Library/Caches/Brim/lyrics to retry
            body = Data("{}".utf8)
        default:
            throw URLError(.badServerResponse)
        }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? body.write(to: file, options: .atomic)
        return decode(body)
    }

    private static func decode(_ data: Data) -> String? {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["syncedLyrics"] as? String
    }

    private static var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return "Brim/\(version) (personal)"
    }

    private static func cacheFile(title: String, artist: String) -> URL {
        let digest = SHA256.hash(data: Data("\(artist)\n\(title)".utf8)).map { String(format: "%02x", $0) }.joined()
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Brim/lyrics/\(digest).json")
    }
}
