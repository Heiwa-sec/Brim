import Foundation
import Observation

enum IslandState { case collapsed, compact, expanded }

/// Per-display island state. Inputs are set by the controller (pointer) and modules (live activities).
@MainActor @Observable
final class IslandModel {
    // Design values for the expanded and compact footprints.
    static let expandedSize = CGSize(width: 460, height: 190)
    static let compactEar: CGFloat = 70
    static let columnGap: CGFloat = 20
    /// Kept open and showing only lyrics: a little wider than a plain expanded island, much narrower than one with the lyrics column.
    static let lyricsOnlyExtra: CGFloat = 60
    /// Width added for each extra expanded column (the lyrics column is 250 pt).
    static let extraColumnWidth: CGFloat = 250 + columnGap

    var geometry: NotchGeometry
    var hideUntilTop = false
    var hovering = false { didSet { notify(oldValue != hovering) } }
    var pinned = false { didSet { notify(oldValue != pinned) } }
    /// A module's banner holds the island open without the pointer.
    var banner = false { didSet { notify(oldValue != banner) } }
    var activityCount = 0 { didSet { notify(oldValue != activityCount) } }
    /// Settings > General > "Keep the notch open": the island stays expanded until the close button is pressed.
    var keepOpen = false { didSet { notify(oldValue != keepOpen) } }
    /// Set by the close button; cleared when the pointer next rests on the notch.
    var dismissed = false { didSet { notify(oldValue != dismissed) } }
    var tab = IslandTab.nowPlaying { didSet { notify(oldValue != tab) } }
    /// Modules with content in the expanded island; each one beyond the first widens it.
    var expandedColumns = 1 { didSet { notify(oldValue != expandedColumns) } }

    /// Kept open with the pointer away: the island shows only the lyrics until the pointer comes back.
    var lyricsOnly: Bool { keepOpen && !dismissed && !hovering && !pinned && !banner }

    /// Set by the controller: the selected tab is Now Playing and there are lyrics to show.
    var lyricsAvailable = false { didSet { notify(oldValue != lyricsAvailable) } }
    /// The island shows only the lyrics and shrinks to fit them.
    var narrowLyrics: Bool { lyricsOnly && lyricsAvailable }

    /// Called when `state` may have changed, so the controller can resize the panel.
    @ObservationIgnored var onStateChange: (() -> Void)?

    init(geometry: NotchGeometry) { self.geometry = geometry }

    var state: IslandState {
        if hovering || pinned || banner || (keepOpen && !dismissed) { return .expanded }
        return activityCount > 0 ? .compact : .collapsed
    }

    /// With hide-until-top on, the idle island is invisible until the pointer reaches it.
    var isVisible: Bool { !hideUntilTop || state != .collapsed }

    var size: CGSize { Self.size(for: state, geometry: geometry, columns: expandedColumns, lyricsOnly: narrowLyrics) }
    var topRadius: CGFloat { state == .expanded ? 16 : 0 }
    var bottomRadius: CGFloat { state == .expanded ? 26 : (geometry.hasNotch ? 10 : geometry.size.height / 2) }

    static func size(for state: IslandState, geometry: NotchGeometry, columns: Int = 1, lyricsOnly: Bool = false) -> CGSize {
        switch state {
        case .collapsed: return geometry.size
        case .compact: return CGSize(width: geometry.size.width + compactEar * 2, height: geometry.size.height)
        case .expanded:
            let base = max(expandedSize.width, geometry.size.width + 120)
            let width = lyricsOnly ? base + lyricsOnlyExtra : base + CGFloat(max(columns, 1) - 1) * extraColumnWidth
            return CGSize(width: width, height: expandedSize.height)
        }
    }

    private func notify(_ changed: Bool) { if changed { onStateChange?() } }
}
