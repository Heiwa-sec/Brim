import Foundation

/// Battery levels of one Bluetooth device. Pure, so the hiding and ordering rules are testable.
struct BluetoothBattery: Equatable {
    let left, right, caseLevel, single: Int?

    /// Zero and out-of-range readings (what the private properties report for "unknown") become nil.
    init(left: Int?, right: Int?, caseLevel: Int?, single: Int?) {
        func clean(_ v: Int?) -> Int? { v.flatMap { (1...100).contains($0) ? $0 : nil } }
        self.left = clean(left)
        self.right = clean(right)
        self.caseLevel = clean(caseLevel)
        self.single = clean(single)
    }

    /// One `device_connected` entry of `system_profiler SPBluetoothDataType -json`, whose levels look like "94%".
    /// IOBluetooth's own battery properties read 0 on macOS 27, so this is the source that works.
    init(profiler entry: [String: Any]) {
        func level(_ key: String) -> Int? { (entry[key] as? String).flatMap { Int($0.dropLast()) } }
        self.init(left: level("device_batteryLevelLeft"), right: level("device_batteryLevelRight"),
                  caseLevel: level("device_batteryLevelCase"), single: level("device_batteryLevelMain"))
    }

    /// Batteries of every connected device in profiler output, keyed by device name. The profiler's addresses differ
    /// from the ones IOBluetooth reports for the same AirPods, so the name is the only shared key.
    static func parse(profiler data: Data) -> [String: BluetoothBattery] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let controller = (root["SPBluetoothDataType"] as? [[String: Any]])?.first,
              let connected = controller["device_connected"] as? [[String: [String: Any]]] else { return [:] }
        return Dictionary(connected.flatMap { $0 }.map { ($0.key, BluetoothBattery(profiler: $0.value)) }) { first, _ in first }
    }

    /// Lowest level of the parts in use; the case is left out because it says nothing about what is playing.
    var lowest: Int? { [left, right, single].compactMap { $0 }.min() }

    /// "L 80% · R 75% · Case 90%", or "80%" for a single battery; nil when nothing is known.
    var summary: String? {
        let parts = [("L", left), ("R", right), ("Case", caseLevel), ("", single)]
            .compactMap { label, value in value.map { label.isEmpty ? "\($0)%" : "\(label) \($0)%" } }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
