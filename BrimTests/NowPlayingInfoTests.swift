import XCTest

final class NowPlayingInfoTests: XCTestCase {
    private let base: [String: Any] = [
        "bundleIdentifier": "com.apple.Music", "title": "Song", "artist": "Band", "playing": true,
        "durationMicros": 200_000_000, "elapsedTimeMicros": 10_000_000, "timestampEpochMicros": 1_000_000_000_000_000,
    ]

    func testParsesMicrosecondFields() throws {
        let info = try XCTUnwrap(NowPlayingInfo(json: base))
        XCTAssertEqual(info.title, "Song")
        XCTAssertEqual(info.duration, 200)
        XCTAssertEqual(info.elapsed, 10)
        XCTAssertEqual(info.timestamp, Date(timeIntervalSince1970: 1_000_000_000))
    }

    func testMissingMandatoryKeyMeansNothingPlaying() {
        var json = base
        json["title"] = nil
        XCTAssertNil(NowPlayingInfo(json: json))
        XCTAssertNil(NowPlayingInfo(json: [:]))
    }

    func testPositionExtrapolatesWhilePlayingAndHoldsWhenPaused() throws {
        var info = try XCTUnwrap(NowPlayingInfo(json: base))
        XCTAssertEqual(info.position(at: info.timestamp.addingTimeInterval(5)), 15)
        info.playing = false
        XCTAssertEqual(info.position(at: info.timestamp.addingTimeInterval(5)), 10)
    }

    func testPositionIsClampedToDuration() throws {
        let info = try XCTUnwrap(NowPlayingInfo(json: base))
        XCTAssertEqual(info.position(at: info.timestamp.addingTimeInterval(10_000)), 200)
    }

    func testDiffUpdatesAndNullRemovesKeys() {
        var state = base
        NowPlayingMerge.apply(["title": "Next", "artist": NSNull()], diff: true, to: &state)
        XCTAssertEqual(state["title"] as? String, "Next")
        XCTAssertNil(state["artist"])
        XCTAssertEqual(state["bundleIdentifier"] as? String, "com.apple.Music")
    }

    func testFullMessageReplacesState() {
        var state = base
        NowPlayingMerge.apply([:], diff: false, to: &state)
        XCTAssertTrue(state.isEmpty)
        XCTAssertNil(NowPlayingInfo(json: state))
    }
}
