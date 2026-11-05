import XCTest

final class PowerInfoTests: XCTestCase {
    private let base: [String: Any] = [
        "Type": "InternalBattery", "Current Capacity": 80, "Max Capacity": 100,
        "Power Source State": "AC Power", "Is Charging": true, "Time to Full Charge": 45,
    ]

    func testParsesChargingBattery() throws {
        let info = try XCTUnwrap(PowerInfo(base))
        XCTAssertEqual(info.percent, 80)
        XCTAssertTrue(info.onAC)
        XCTAssertEqual(info.minutesToFull, 45)
        XCTAssertEqual(info.status, "Charging")
    }

    func testUnknownTimeIsNil() throws {
        var d = base
        d["Time to Full Charge"] = -1
        XCTAssertNil(try XCTUnwrap(PowerInfo(d)).minutesToFull)
    }

    func testBatteryPowerAndNonBatteryRejected() throws {
        var d = base
        d["Power Source State"] = "Battery Power"
        d["Is Charging"] = false
        XCTAssertEqual(try XCTUnwrap(PowerInfo(d)).status, "On battery")
        d["Type"] = "UPS"
        XCTAssertNil(PowerInfo(d))
    }
}
