import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The one settings window. An agent app has no menu, so it opens from the island's gear button, ⌥⌘, and relaunching the app.
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?
    private var hotKey: EventHotKeyRef?
    var modules: [any IslandModule.Type] = []

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(modules: modules)))
            w.title = "Brim Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Carbon hot keys need no permission, unlike a key event monitor.
    func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { SettingsWindow.shared.show() } }
            return noErr
        }, 1, &spec, nil, nil)
        RegisterEventHotKey(UInt32(kVK_ANSI_Comma), UInt32(cmdKey | optionKey), EventHotKeyID(signature: OSType(0x4252494D), id: 1),
                            GetApplicationEventTarget(), 0, &hotKey)
    }
}
