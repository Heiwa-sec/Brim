import AppKit

/// Per-display options, stored in UserDefaults under `display.<uuid>.<key>` and edited in Settings (Displays tab).
struct DisplaySettings {
    let id: String

    var enabled: Bool { UserDefaults.standard.object(forKey: key("enabled")) as? Bool ?? true }
    var hideUntilTop: Bool { UserDefaults.standard.bool(forKey: key("hideUntilTop")) }

    /// Seconds the pointer must dwell before the island expands.
    static var hoverDelay: TimeInterval { UserDefaults.standard.object(forKey: "hoverDelay") as? Double ?? 0.12 }

    private func key(_ name: String) -> String { "display.\(id).\(name)" }
}

extension NSScreen {
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    var notchGeometry: NotchGeometry {
        NotchGeometry.make(screenFrame: frame, safeAreaTop: safeAreaInsets.top,
                           auxLeft: auxiliaryTopLeftArea, auxRight: auxiliaryTopRightArea,
                           menuBarHeight: NSStatusBar.system.thickness)
    }
}
