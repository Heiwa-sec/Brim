import AppKit
import SQLite3
import SwiftUI

/// Mirrors new macOS notifications into the island as a short banner. Off by default; needs Full Disk Access to read
/// usernoted's database. The database is opened read-only, a vnode source on its write-ahead log signals new rows, and
/// nothing is polled. Content is kept in memory only while the banner shows; it is never logged, saved or sent.
@MainActor @Observable
final class NotificationsModule: IslandModule {
    static let id = "notifications"
    static let title = "Notification mirroring"
    static let defaultEnabled = false
    static let bannerSeconds = 5.0

    private(set) var current: NotificationRecord?
    private(set) var problem: String?

    @ObservationIgnored private var watcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var lastSeen: Int64 = 0
    @ObservationIgnored private var hideWork: DispatchWorkItem?
    @ObservationIgnored private var retryWork: DispatchWorkItem?

    static let directory = NSString("~/Library/Group Containers/group.com.apple.usernoted/db2").expandingTildeInPath
    private var dbPath: String { Self.directory + "/db" }

    var wantsExpanded: Bool { current != nil }

    func start() {
        problem = nil
        guard let latest = Self.query(path: dbPath, after: nil) else {
            problem = "Notification mirroring needs Full Disk Access (System Settings > Privacy & Security)"
            return
        }
        lastSeen = latest.maxID // history is never replayed
        watch()
    }

    func stop() {
        watcher?.cancel(); watcher = nil
        hideWork?.cancel(); retryWork?.cancel()
        current = nil
        problem = nil
    }

    /// The write-ahead log is replaced when SQLite checkpoints, so the source re-arms itself on delete or rename.
    private func watch() {
        watcher?.cancel()
        let fd = open(dbPath + "-wal", O_EVTONLY)
        guard fd >= 0 else {
            // shortcut: one retry; if the log never reappears the module stays quiet until it is switched off and on
            let work = DispatchWorkItem { [weak self] in self?.watch() }
            retryWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            MainActor.assumeIsolated {
                self.check()
                if !source.data.isDisjoint(with: [.delete, .rename]) { self.watch() }
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }

    private func check() {
        guard let result = Self.query(path: dbPath, after: lastSeen) else { return }
        lastSeen = max(lastSeen, result.maxID)
        guard let newest = result.records.last else { return }
        show(newest)
    }

    private func show(_ record: NotificationRecord) {
        hideWork?.cancel()
        current = record
        let work = DispatchWorkItem { [weak self] in self?.current = nil }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.bannerSeconds, execute: work)
    }

    /// Rows after `id` (all rows when nil, used only to learn the newest id). Nil means the database could not be read.
    private nonisolated static func query(path: String, after id: Int64?) -> (maxID: Int64, records: [NotificationRecord])? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { sqlite3_close(db); return nil }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        let sql = id == nil ? "select coalesce(max(rec_id), 0), null from record"
                            : "select rec_id, data from record where rec_id > ? order by rec_id"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        if let id { sqlite3_bind_int64(statement, 1, id) }
        var maxID: Int64 = id ?? 0
        var records: [NotificationRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            maxID = max(maxID, sqlite3_column_int64(statement, 0))
            if let blob = sqlite3_column_blob(statement, 1), let record = NotificationRecord(plist: Data(bytes: blob, count: Int(sqlite3_column_bytes(statement, 1)))) {
                records.append(record)
            }
        }
        return (maxID, records)
    }
}
