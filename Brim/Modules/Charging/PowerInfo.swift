import Foundation

/// Battery state from one IOKit power-source description. Pure, so the key handling is testable.
struct PowerInfo: Equatable {
    let percent: Int
    let onAC: Bool
    let charging: Bool
    let full: Bool
    /// Minutes until full; nil while the system is still estimating.
    let minutesToFull: Int?

    /// Nil when the dictionary is not an internal battery (desktop Macs, UPS without capacity).
    init?(_ d: [String: Any]) {
        guard d["Type"] as? String == "InternalBattery",
              let current = d["Current Capacity"] as? Int,
              let max = d["Max Capacity"] as? Int, max > 0 else { return nil }
        percent = Int((Double(current) / Double(max) * 100).rounded())
        onAC = d["Power Source State"] as? String == "AC Power"
        charging = d["Is Charging"] as? Bool ?? false
        full = d["Is Charged"] as? Bool ?? false
        let minutes = d["Time to Full Charge"] as? Int ?? -1
        minutesToFull = minutes > 0 ? minutes : nil
    }

    var status: String {
        if full { return "Fully charged" }
        if charging { return "Charging" }
        return onAC ? "On power, not charging" : "On battery"
    }
}
