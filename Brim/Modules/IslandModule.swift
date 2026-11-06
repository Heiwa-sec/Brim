import SwiftUI
import Observation

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

/// A feature that lives in the island. Modules are observable, so views and the host react to their state without polling.
@MainActor
protocol IslandModule: AnyObject, Observable {
    static var id: String { get }
    /// Name shown in Settings.
    static var title: String { get }
    /// Whether the module runs before the user has set `module.<id>.enabled`.
    static var defaultEnabled: Bool { get }
    /// Subscribe to OS events. Called when the module is switched on.
    func start()
    /// Unsubscribe and release everything. Called when the module is switched off.
    func stop()
    /// True while the module has something live to show in the compact pill.
    var hasActivity: Bool { get }
    var compactLeading: AnyView? { get }
    var compactTrailing: AnyView? { get }
    /// True while the module wants the island open by itself (a banner), regardless of the pointer.
    var wantsExpanded: Bool { get }
    /// The tab the expanded content belongs to.
    var tab: IslandTab { get }
    /// Content for the expanded island; nil when there is nothing to show.
    var expanded: AnyView? { get }
    /// A user-visible reason the module can't work, shown when there is no content.
    var problem: String? { get }
    /// Offered files dropped on the island. Return true to take them.
    func receive(_ urls: [URL]) -> Bool
}

extension IslandModule {
    static var defaultEnabled: Bool { true }
    var hasActivity: Bool { false }
    var compactLeading: AnyView? { nil }
    var compactTrailing: AnyView? { nil }
    var tab: IslandTab { .nowPlaying }
    var expanded: AnyView? { nil }
    var problem: String? { nil }
    var wantsExpanded: Bool { false }
    func receive(_ urls: [URL]) -> Bool { false }
}

/// Starts and stops modules from their `module.<id>.enabled` switches (default on unless the module says otherwise) and tells the islands what to show.
@MainActor @Observable
final class ModuleHost {
    let modules: [any IslandModule]
    private var running: Set<String> = []
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(modules: [any IslandModule]) {
        self.modules = modules
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }
        reconcile()
    }

    private func reconcile() {
        for module in modules {
            let id = type(of: module).id
            let enabled = UserDefaults.standard.object(forKey: "module.\(id).enabled") as? Bool ?? type(of: module).defaultEnabled
            if enabled, !running.contains(id) { module.start(); running.insert(id) }
            else if !enabled, running.contains(id) { module.stop(); running.remove(id) }
        }
    }

    private var active: [any IslandModule] { modules.filter { running.contains(type(of: $0).id) } }

    var wantsExpanded: Bool { active.contains(where: \.wantsExpanded) }
    var activityCount: Int { active.filter(\.hasActivity).count }
    var compactLeading: [AnyView] { active.filter(\.hasActivity).compactMap(\.compactLeading) }
    var compactTrailing: [AnyView] { active.filter(\.hasActivity).compactMap(\.compactTrailing) }
    var tabs: [IslandTab] { IslandTab.allCases.filter { tab in active.contains { $0.tab == tab } } }
    func views(in tab: IslandTab) -> [AnyView] { active.filter { $0.tab == tab }.compactMap(\.expanded) }
    /// The selected tab, or the first one left when its module has been switched off.
    func resolve(_ tab: IslandTab) -> IslandTab { tabs.contains(tab) ? tab : tabs.first ?? .nowPlaying }
    func drop(_ urls: [URL]) -> Bool { active.contains { $0.receive(urls) } }
    func emptyMessage(in tab: IslandTab) -> String { active.filter { $0.tab == tab }.compactMap(\.problem).first ?? tab.emptyMessage }
}
