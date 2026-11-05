import XCTest

final class HUDKeyTests: XCTestCase {
    /// data1 as macOS sends it: key code in the high 16 bits, state in the next byte (0xA down, 0xB up).
    private func data1(_ code: Int, _ state: Int) -> Int { code << 16 | state << 8 }

    func testDecodesPressAndRelease() {
        XCTAssertEqual(MediaKeyEvent(data1: data1(0, 0xA))?.key, .volumeUp)
        XCTAssertEqual(MediaKeyEvent(data1: data1(1, 0xA))?.key, .volumeDown)
        XCTAssertEqual(MediaKeyEvent(data1: data1(7, 0xB))?.down, false)
        XCTAssertEqual(MediaKeyEvent(data1: data1(3, 0xA) | 1)?.key, .brightnessDown) // repeat flag
    }

    func testIgnoresOtherKeysAndStates() {
        XCTAssertNil(MediaKeyEvent(data1: data1(16, 0xA))) // play/pause
        XCTAssertNil(MediaKeyEvent(data1: data1(0, 0x5)))
    }

    func testStepSnapsAndClamps() {
        XCTAssertEqual(HUDKey.step(0.5, up: true), 9.0 / 16)
        XCTAssertEqual(HUDKey.step(0.51, up: false), 7.0 / 16) // snaps to 8/16 first
        XCTAssertEqual(HUDKey.step(1, up: true), 1)
        XCTAssertEqual(HUDKey.step(0, up: false), 0)
    }

    func testSymbols() {
        XCTAssertEqual(HUDKey.mute.symbol(level: 0), "speaker.slash.fill")
        XCTAssertEqual(HUDKey.volumeUp.symbol(level: 0.5), "speaker.wave.2.fill")
        XCTAssertEqual(HUDKey.brightnessUp.symbol(level: 0.9), "sun.max.fill")
    }
}
