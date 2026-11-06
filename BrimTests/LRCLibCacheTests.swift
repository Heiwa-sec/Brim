import XCTest

final class LRCLibCacheTests: XCTestCase {
    private let day: TimeInterval = 86_400

    func testFoundLyricsLastLongerThanNotFound() {
        XCTAssertTrue(LRCLibClient.isFresh(age: 30 * day, found: true))
        XCTAssertFalse(LRCLibClient.isFresh(age: 91 * day, found: true))
        XCTAssertTrue(LRCLibClient.isFresh(age: 6 * day, found: false))
        XCTAssertFalse(LRCLibClient.isFresh(age: 8 * day, found: false))
    }

    func testPruneRemovesOnlyOldFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let old = dir.appendingPathComponent("old.json"), recent = dir.appendingPathComponent("recent.json")
        for file in [old, recent] { try Data("{}".utf8).write(to: file) }
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-100 * day)], ofItemAtPath: old.path)
        LRCLibClient.pruneCache(in: dir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
    }
}
