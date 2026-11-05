import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The one settings window. An agent app has no menu, so it opens from the island's gear button, ⌥⌘, and relaunching the app.
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?
    private var hotKeys: [EventHotKeyRef?] = [nil, nil]
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
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if id.id == 1 { SettingsWindow.shared.show() } else { NotificationCenter.default.post(name: .brimLockNow, object: nil) }
                }
            }
            return noErr
        }, 1, &spec, nil, nil)
        // ⌥⌘, opens settings; ⌥⌘L shows Now Playing, then locks.
        for (n, key) in [kVK_ANSI_Comma, kVK_ANSI_L].enumerated() {
            RegisterEventHotKey(UInt32(key), UInt32(cmdKey | optionKey), EventHotKeyID(signature: OSType(0x4252494D), id: UInt32(n + 1)),
                                GetApplicationEventTarget(), 0, &hotKeys[n])
        }
    }
}
