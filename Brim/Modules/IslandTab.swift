import Foundation

/// The tabs of the expanded island. A module's expanded content shows in its tab; a tab exists while one of its modules is on.
enum IslandTab: CaseIterable {
    case nowPlaying, weather, todo, fileTray

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .weather: "Weather"
        case .todo: "To-do"
        case .fileTray: "File tray"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "play.circle"
        case .weather: "cloud.sun"
        case .todo: "checklist"
        case .fileTray: "tray"
        }
    }

    var emptyMessage: String {
        switch self {
        case .nowPlaying: "Nothing playing"
        case .weather: "No weather yet"
        case .todo: ""
        case .fileTray: "Drop files here"
        }
    }
}
