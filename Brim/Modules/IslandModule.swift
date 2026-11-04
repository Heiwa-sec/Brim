import SwiftUI
import Observation

/// A feature that lives in the island. Modules are observable, so views and the host react to their state without polling.
@MainActor
protocol IslandModule: AnyObject, Observable {
    static var id: String { get }
    /// Subscribe to OS events. Called when the module is switched on.
    func start()
    /// Unsubscribe and release everything. Called when the module is switched off.
    func stop()
    /// True while the module has something live to show in the compact pill.
    var hasActivity: Bool { get }
    var compactLeading: AnyView? { get }
    var compactTrailing: AnyView? { get }
    /// Content for the expanded island; nil when there is nothing to show.
    var expanded: AnyView? { get }
    /// A user-visible reason the module can't work, shown when there is no content.
    var problem: String? { get }
}

extension IslandModule {
    var hasActivity: Bool { false }
    var compactLeading: AnyView? { nil }
    var compactTrailing: AnyView? { nil }
    var expanded: AnyView? { nil }
    var problem: String? { nil }
}

/// Starts and stops modules from their `module.<id>.enabled` switches (default on) and tells the islands what to show.
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
            let enabled = UserDefaults.standard.object(forKey: "module.\(id).enabled") as? Bool ?? true
            if enabled, !running.contains(id) { module.start(); running.insert(id) }
            else if !enabled, running.contains(id) { module.stop(); running.remove(id) }
        }
    }

    private var active: [any IslandModule] { modules.filter { running.contains(type(of: $0).id) } }

    var activityCount: Int { active.filter(\.hasActivity).count }
    var compactLeading: [AnyView] { active.filter(\.hasActivity).compactMap(\.compactLeading) }
    var compactTrailing: [AnyView] { active.filter(\.hasActivity).compactMap(\.compactTrailing) }
    var expandedViews: [AnyView] { active.compactMap(\.expanded) }
    var emptyMessage: String { active.compactMap(\.problem).first ?? "Nothing playing" }
}
