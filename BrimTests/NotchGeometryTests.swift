import XCTest

final class NotchGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)

    func testNotchSizeComesFromAuxiliaryAreas() {
        let g = NotchGeometry.make(screenFrame: screen, safeAreaTop: 32,
                                   auxLeft: CGRect(x: 0, y: 1080, width: 755, height: 32),
                                   auxRight: CGRect(x: 955, y: 1080, width: 755, height: 32), menuBarHeight: 24)
        XCTAssertTrue(g.hasNotch)
        XCTAssertEqual(g.size, CGSize(width: 200, height: 32))
        XCTAssertEqual(g.centerX, 855)
        XCTAssertEqual(g.topInset, 0)
    }

    func testOffCentreNotchUsesRealCentre() {
        let g = NotchGeometry.make(screenFrame: screen, safeAreaTop: 30,
                                   auxLeft: CGRect(x: 0, y: 0, width: 700, height: 30),
                                   auxRight: CGRect(x: 900, y: 0, width: 810, height: 30), menuBarHeight: 24)
        XCTAssertEqual(g.centerX, 800)
    }

    func testNoNotchGivesFloatingPill() {
        let g = NotchGeometry.make(screenFrame: screen, safeAreaTop: 0, auxLeft: nil, auxRight: nil, menuBarHeight: 24)
        XCTAssertFalse(g.hasNotch)
        XCTAssertEqual(g.size.height, 24)
        XCTAssertEqual(g.centerX, screen.midX)
        XCTAssertGreaterThan(g.topInset, 0)
    }

    func testInsetWithoutAuxiliaryAreasFallsBackToPill() {
        let g = NotchGeometry.make(screenFrame: screen, safeAreaTop: 32, auxLeft: nil, auxRight: nil, menuBarHeight: 24)
        XCTAssertFalse(g.hasNotch)
    }
}
