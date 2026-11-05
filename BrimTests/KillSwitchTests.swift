import XCTest

final class KillSwitchTests: XCTestCase {
    private func make(_ args: [String] = []) -> KillSwitch {
        let defaults = UserDefaults(suiteName: "KillSwitchTests-\(name)")!
        defaults.removePersistentDomain(forName: "KillSwitchTests-\(name)")
        return KillSwitch(defaults: defaults, arguments: args)
    }

    func testCleanRunsNeverTrip() {
        let k = make()
        for _ in 0..<3 { k.recordLaunch(); k.cardShown(); k.cardHidden() }
        XCTAssertFalse(k.tripped)
    }

    func testTwoCrashesInARowTripAndResetClears() {
        let k = make()
        k.recordLaunch(); k.cardShown()          // run 1 dies with the card up
        k.recordLaunch(); XCTAssertFalse(k.tripped); k.cardShown() // run 2 sees one crash, then dies too
        k.recordLaunch(); XCTAssertTrue(k.tripped)
        k.reset(); XCTAssertFalse(k.tripped)
    }

    func testACleanLaunchBreaksTheStreak() {
        let k = make()
        k.recordLaunch(); k.cardShown()
        k.recordLaunch()                         // one crash seen; this run exits cleanly
        k.recordLaunch(); k.recordLaunch()
        XCTAssertFalse(k.tripped)
    }

    func testLaunchArgumentTrips() { XCTAssertTrue(make(["Brim", "--disable-lockscreen"]).tripped) }
}
