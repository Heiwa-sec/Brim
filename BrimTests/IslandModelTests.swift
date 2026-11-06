import XCTest
@testable import Brim

@MainActor
final class IslandModelTests: XCTestCase {
    private let geometry = NotchGeometry(hasNotch: true, size: CGSize(width: 200, height: 32), topInset: 0, centerX: 500)

    private func model(keepOpen: Bool = true, lyrics: Bool = true) -> IslandModel {
        let m = IslandModel(geometry: geometry)
        m.keepOpen = keepOpen
        m.lyricsAvailable = lyrics
        return m
    }

    func testLyricsOnlyWidthBetweenPlainAndFull() {
        let plain = IslandModel.size(for: .expanded, geometry: geometry).width
        let lyricsOnly = IslandModel.size(for: .expanded, geometry: geometry, columns: 2, lyricsOnly: true).width
        let full = IslandModel.size(for: .expanded, geometry: geometry, columns: 2).width
        XCTAssertEqual(lyricsOnly, plain + IslandModel.lyricsOnlyExtra)
        XCTAssertEqual(full, plain + IslandModel.extraColumnWidth)
        XCTAssertLessThan(lyricsOnly, full)
    }

    func testLyricsOnlyNeedsKeepOpenAndAnIdlePointer() {
        XCTAssertTrue(model().narrowLyrics)
        XCTAssertFalse(model(keepOpen: false).narrowLyrics)   // not kept open
        XCTAssertFalse(model(lyrics: false).narrowLyrics)     // nothing to show: the normal view
        for change in [{ (m: IslandModel) in m.hovering = true }, { $0.pinned = true }, { $0.banner = true }, { $0.dismissed = true }] {
            let m = model()
            change(m)
            XCTAssertFalse(m.narrowLyrics)
        }
    }
}
