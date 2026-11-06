import AppKit
import ServiceManagement

/// Removes Brim: moves the app to the Trash first (so a failure leaves everything as it was), then deletes the login item,
/// settings, to-do list and caches, resets the macOS permissions it can, and quits.
@MainActor
enum Uninstaller {
    static func run() {
        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, error in
            Task { @MainActor in
                if error == nil { removeTraces(); NSApp.terminate(nil) } else { failed(error) }
            }
        }
    }

    private static func removeTraces() {
        let id = Bundle.main.bundleIdentifier ?? "dev.brim.Brim"
        try? SMAppService.mainApp.unregister()
        UserDefaults.standard.removePersistentDomain(forName: id)
        UserDefaults.standard.synchronize() // flush now, or macOS writes an empty preferences file back after it is deleted below
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        for path in ["Caches/Brim", "Caches/\(id)", "HTTPStorages/\(id)", "Preferences/\(id).plist"] {
            try? FileManager.default.removeItem(at: library.appendingPathComponent(path))
        }
        // Camera, Location and Apple events are cleared this way; Accessibility and Full Disk Access need an admin, so macOS keeps those rows.
        let tccutil = Process()
        tccutil.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        tccutil.arguments = ["reset", "All", id]
        try? tccutil.run()
        tccutil.waitUntilExit()
    }

    private static func failed(_ error: Error?) {
        let alert = NSAlert()
        alert.messageText = "Brim could not be moved to the Trash"
        alert.informativeText = (error?.localizedDescription ?? "") + "\nNothing was deleted. Drag Brim from Applications to the Trash yourself."
        alert.runModal()
    }
}
