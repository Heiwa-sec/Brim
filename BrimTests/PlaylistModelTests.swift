import XCTest
@testable import Brim

@MainActor
final class PlaylistModelTests: XCTestCase {
    private let a = PlaylistTrack(title: "a", artist: "x"), b = PlaylistTrack(title: "b", artist: "y")

    func testCurrentMatchesTitleAndArtist() {
        let model = PlaylistModel()
        XCTAssertNil(model.current(title: "a", artist: "x"))
        model.tracks = [a, PlaylistTrack(title: "a", artist: "y")]
        XCTAssertEqual(model.current(title: "a", artist: "y"), 1)
        XCTAssertNil(model.current(title: "a", artist: nil))
    }

    /// Brim steps through the list only while the playing song is the one it started itself.
    func testSkipDirectOnlyForTheSongBrimStarted() {
        let model = PlaylistModel()
        model.tracks = [a, b]
        XCTAssertFalse(model.skipDirect(forward: true, title: "a", artist: "x"))   // nothing started by Brim
        model.queuelessTrack = b
        XCTAssertFalse(model.skipDirect(forward: true, title: "a", artist: "x"))   // another song is playing: Music is in charge
        XCTAssertTrue(model.skipDirect(forward: true, title: "b", artist: "y"))    // last song, nothing to play, still handled
        XCTAssertEqual(model.queuelessTrack, b)
    }
}
