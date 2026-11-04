import XCTest

final class ArtworkPaletteTests: XCTestCase {
    func testPicksMostSaturatedThenFurthestHue() {
        let palette = ArtworkPalette.pick([(1, 0, 0), (0.3, 0.3, 1), (0.5, 0.5, 0.5)])
        XCTAssertEqual(palette.first.h, 0, accuracy: 0.001)
        XCTAssertEqual(palette.second.h, 2.0 / 3.0, accuracy: 0.001)
    }

    func testDarkColourIsBrightenedToReadOnBlack() {
        XCTAssertEqual(ArtworkPalette.pick([(0.5, 0, 0)]).first.b, 0.8, accuracy: 0.001)
    }

    func testGreyOrEmptyFallsBackToWhite() {
        XCTAssertEqual(ArtworkPalette.pick([(0.5, 0.5, 0.5)]), .white)
        XCTAssertEqual(ArtworkPalette.pick([]), .white)
    }
}
