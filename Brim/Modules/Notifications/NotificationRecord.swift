import Foundation

/// The parts of one row of the notification database that Brim shows. Pure, so the format handling is testable.
struct NotificationRecord: Equatable {
    let app: String
    let title: String
    let body: String

    /// Nil when the blob is not a property list, names no app, or has neither title nor body.
    /// Keys are from the usernoted `record.data` plist on macOS 27 (database version 19).
    init?(plist data: Data) {
        guard let root = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let app = root["app"] as? String, !app.hasPrefix("_system_center_:") else { return nil }
        let request = root["req"] as? [String: Any] ?? [:]
        let title = request["titl"] as? String ?? ""
        let subtitle = request["subt"] as? String ?? ""
        let body = request["body"] as? String ?? ""
        guard !title.isEmpty || !body.isEmpty else { return nil }
        self.app = app
        self.title = title
        self.body = subtitle.isEmpty ? body : "\(subtitle)\n\(body)"
    }
}
