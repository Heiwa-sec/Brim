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

final class BluetoothProfilerTests: XCTestCase {
    func testParsesConnectedDevicesByName() throws {
        let json = #"{"SPBluetoothDataType":[{"device_connected":[{"Pods":{"device_address":"E4:29:B2:F7:86:1B","device_batteryLevelCase":"94%","device_batteryLevelLeft":"100%","device_batteryLevelRight":"90%"}},{"Mouse":{"device_address":"AA:BB:CC:DD:EE:FF","device_batteryLevelMain":"40%"}},{"Speaker":{"device_address":"11:22:33:44:55:66"}}]}]}"#
        let levels = BluetoothBattery.parse(profiler: Data(json.utf8))
        let pods = try XCTUnwrap(levels["Pods"])
        XCTAssertEqual(pods.summary, "L 100% · R 90% · Case 94%")
        XCTAssertEqual(levels["Mouse"]?.summary, "40%")
        XCTAssertNil(levels["Speaker"]?.summary)
        XCTAssertTrue(BluetoothBattery.parse(profiler: Data()).isEmpty)
    }
}
