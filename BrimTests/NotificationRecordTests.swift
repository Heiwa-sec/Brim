import XCTest

final class NotificationRecordTests: XCTestCase {
    private func blob(_ dict: [String: Any]) throws -> Data { try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) }

    func testParsesTitleSubtitleAndBody() throws {
        let data = try blob(["app": "com.apple.mobilesms", "req": ["titl": "Ana", "subt": "Group", "body": "Hi"]])
        let r = try XCTUnwrap(NotificationRecord(plist: data))
        XCTAssertEqual(r, NotificationRecord(plist: data))
        XCTAssertEqual(r.app, "com.apple.mobilesms")
        XCTAssertEqual(r.title, "Ana")
        XCTAssertEqual(r.body, "Group\nHi")
    }

    func testRejectsSystemEmptyAndGarbage() throws {
        XCTAssertNil(NotificationRecord(plist: try blob(["app": "_system_center_:com.apple.followup.alert", "req": ["titl": "x"]])))
        XCTAssertNil(NotificationRecord(plist: try blob(["app": "com.example", "req": ["titl": "", "body": ""]])))
        XCTAssertNil(NotificationRecord(plist: Data("nope".utf8)))
    }
}
