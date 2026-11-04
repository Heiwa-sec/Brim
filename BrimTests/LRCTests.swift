import XCTest

final class LRCTests: XCTestCase {
    func testParsesTimesAndText() {
        let lines = LRC.parse("[00:12.50] Hello\n[01:02.5]World\n[00:03]Bare")
        XCTAssertEqual(lines, [LyricLine(time: 3, text: "Bare"), LyricLine(time: 12.5, text: "Hello"), LyricLine(time: 62.5, text: "World")])
    }

    func testThreeDigitFraction() {
        XCTAssertEqual(LRC.parse("[00:01.250]x").first?.time, 1.25)
    }

    func testSeveralTagsOnOneLine() {
        let lines = LRC.parse("[00:10.00][00:20.00]Chorus")
        XCTAssertEqual(lines.map(\.time), [10, 20])
        XCTAssertEqual(lines.map(\.text), ["Chorus", "Chorus"])
    }

    func testMetadataIsSkippedAndOffsetApplied() {
        let lines = LRC.parse("[ar:Queen]\n[ti:Song]\n[offset:500]\n[00:10.00]A")
        XCTAssertEqual(lines, [LyricLine(time: 9.5, text: "A")])
    }

    func testEmptyTextIsKept() {
        XCTAssertEqual(LRC.parse("[00:05.00]").first, LyricLine(time: 5, text: ""))
    }

    func testRejectsNonFiniteAndNegativeTimes() {
        XCTAssertTrue(LRC.parse("[00:nan]x\n[00:inf]y\n[-1:00]z").isEmpty)
    }

    func testIndexBoundaries() {
        let lines = [LyricLine(time: 1, text: "a"), LyricLine(time: 5, text: "b")]
        XCTAssertNil(LRC.index(at: 0.5, in: lines))
        XCTAssertEqual(LRC.index(at: 1, in: lines), 0)
        XCTAssertEqual(LRC.index(at: 4.9, in: lines), 0)
        XCTAssertEqual(LRC.index(at: 4.96, in: lines), 1) // inside the 50 ms tolerance
        XCTAssertEqual(LRC.index(at: 99, in: lines), 1)
        XCTAssertNil(LRC.index(at: 3, in: []))
    }
}
