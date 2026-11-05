import Foundation

/// The system-defined media keys the HUD replaces (NX_KEYTYPE_* codes).
enum HUDKey: Int {
    case volumeUp = 0, volumeDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7

    var isBrightness: Bool { self == .brightnessUp || self == .brightnessDown }
    var isUp: Bool { self == .volumeUp || self == .brightnessUp }

    /// One key press moves the level by 1/16, snapping to the grid first.
    static func step(_ level: Float, up: Bool) -> Float {
        min(max((level * 16).rounded() + (up ? 1 : -1), 0), 16) / 16
    }

    func symbol(level: Float) -> String {
        if isBrightness { return level < 0.5 ? "sun.min.fill" : "sun.max.fill" }
        if level <= 0 { return "speaker.slash.fill" }
        return level < 1.0 / 3 ? "speaker.wave.1.fill" : level < 2.0 / 3 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }
}

/// A key press or release decoded from the `data1` field of an NX_SYSDEFINED (subtype 8) event.
struct MediaKeyEvent: Equatable {
    let key: HUDKey
    let down: Bool

    /// Nil for keys the HUD does not handle, or a key state that is neither press (0xA) nor release (0xB).
    init?(data1: Int) {
        guard let key = HUDKey(rawValue: (data1 >> 16) & 0xFFFF) else { return nil }
        switch (data1 >> 8) & 0xFF {
        case 0xA: down = true
        case 0xB: down = false
        default: return nil
        }
        self.key = key
    }
}
