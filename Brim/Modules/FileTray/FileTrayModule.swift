import AppKit
import SwiftUI

/// A shelf of dropped files. Holds file URLs only, in memory; nothing is copied and nothing survives a relaunch.
@MainActor @Observable
final class FileTrayModule: IslandModule {
    static let id = "fileTray"
    static let title = "File tray"

    private(set) var items: [URL] = []

    var tab: IslandTab { .fileTray }
    var expanded: AnyView? { items.isEmpty ? nil : AnyView(FileTrayView(module: self)) }

    func start() {}
    func stop() { clear() }

    func receive(_ urls: [URL]) -> Bool {
        let files = urls.filter(\.isFileURL)
        items += files.filter { !items.contains($0) }
        return !files.isEmpty
    }

    func clear() { items = [] }
}
