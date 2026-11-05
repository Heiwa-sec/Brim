import XCTest

final class BluetoothBatteryTests: XCTestCase {
    func testZeroAndOutOfRangeAreHidden() {
        let b = BluetoothBattery(left: 0, right: 75, caseLevel: 255, single: nil)
        XCTAssertNil(b.left)
        XCTAssertNil(b.caseLevel)
        XCTAssertEqual(b.summary, "R 75%")
    }

    func testLowestIgnoresCase() {
        let b = BluetoothBattery(left: 80, right: 60, caseLevel: 10, single: nil)
        XCTAssertEqual(b.lowest, 60)
        XCTAssertEqual(b.summary, "L 80% · R 60% · Case 10%")
    }

    func testSingleAndUnknown() {
        XCTAssertEqual(BluetoothBattery(left: nil, right: nil, caseLevel: nil, single: 42).summary, "42%")
        let none = BluetoothBattery(left: 0, right: nil, caseLevel: nil, single: nil)
        XCTAssertNil(none.lowest)
        XCTAssertNil(none.summary)
    }
}
