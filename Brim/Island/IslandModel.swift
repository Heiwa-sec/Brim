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
    /// Width added for each extra expanded column (the lyrics column is 250 pt).
    static let extraColumnWidth: CGFloat = 250 + columnGap

    var geometry: NotchGeometry
    var hideUntilTop = false
    var hovering = false { didSet { notify(oldValue != hovering) } }
    var pinned = false { didSet { notify(oldValue != pinned) } }
    /// A module's banner holds the island open without the pointer.
    var banner = false { didSet { notify(oldValue != banner) } }
    var activityCount = 0 { didSet { notify(oldValue != activityCount) } }
    var tab = IslandTab.nowPlaying { didSet { notify(oldValue != tab) } }
    /// Modules with content in the expanded island; each one beyond the first widens it.
    var expandedColumns = 1 { didSet { notify(oldValue != expandedColumns) } }

    /// Called when `state` may have changed, so the controller can resize the panel.
    @ObservationIgnored var onStateChange: (() -> Void)?

    init(geometry: NotchGeometry) { self.geometry = geometry }

    var state: IslandState {
        if hovering || pinned || banner { return .expanded }
        return activityCount > 0 ? .compact : .collapsed
    }

    /// With hide-until-top on, the idle island is invisible until the pointer reaches it.
    var isVisible: Bool { !hideUntilTop || state != .collapsed }

    var size: CGSize { Self.size(for: state, geometry: geometry, columns: expandedColumns) }
    var topRadius: CGFloat { state == .expanded ? 16 : 0 }
    var bottomRadius: CGFloat { state == .expanded ? 26 : (geometry.hasNotch ? 10 : geometry.size.height / 2) }

    static func size(for state: IslandState, geometry: NotchGeometry, columns: Int = 1) -> CGSize {
        switch state {
        case .collapsed: return geometry.size
        case .compact: return CGSize(width: geometry.size.width + compactEar * 2, height: geometry.size.height)
        case .expanded:
            let width = max(expandedSize.width, geometry.size.width + 120) + CGFloat(max(columns, 1) - 1) * extraColumnWidth
            return CGSize(width: width, height: expandedSize.height)
        }
    }

    private func notify(_ changed: Bool) { if changed { onStateChange?() } }
}
