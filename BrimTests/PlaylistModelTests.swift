import XCTest
@testable import Brim

@MainActor
final class PlaylistModelTests: XCTestCase {
    func testCurrentMatchesTitleAndArtist() {
        let model = PlaylistModel()
        XCTAssertNil(model.current(title: "a", artist: "x"))
        model.tracks = [PlaylistTrack(title: "a", artist: "x"), PlaylistTrack(title: "a", artist: "y")]
        XCTAssertEqual(model.current(title: "a", artist: "y"), 1)
        XCTAssertNil(model.current(title: "a", artist: nil))
        XCTAssertEqual(PlaylistModel().current(title: nil, artist: nil), nil)
    }
}
