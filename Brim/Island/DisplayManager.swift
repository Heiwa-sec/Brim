import AppKit

/// Keeps exactly one island controller per enabled display, following screen and settings changes.
@MainActor
final class DisplayManager {
    private var controllers: [String: IslandController] = [:]
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        for name in [NSApplication.didChangeScreenParametersNotification, UserDefaults.didChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reconcile() }
            })
        }
        reconcile()
    }

    private func reconcile() {
        var live = Set<String>()
        for screen in NSScreen.screens {
            guard let id = screen.displayUUID else { continue }
            let settings = DisplaySettings(id: id)
            guard settings.enabled else { continue }
            live.insert(id)
            if let controller = controllers[id] {
                controller.update(screen: screen, settings: settings)
            } else {
                controllers[id] = IslandController(screen: screen, settings: settings)
            }
        }
        for id in controllers.keys where !live.contains(id) {
            controllers.removeValue(forKey: id)?.tearDown()
        }
    }
}
