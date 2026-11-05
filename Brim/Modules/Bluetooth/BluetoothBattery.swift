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

    /// Lowest level of the parts in use; the case is left out because it says nothing about what is playing.
    var lowest: Int? { [left, right, single].compactMap { $0 }.min() }

    /// "L 80% · R 75% · Case 90%", or "80%" for a single battery; nil when nothing is known.
    var summary: String? {
        let parts = [("L", left), ("R", right), ("Case", caseLevel), ("", single)]
            .compactMap { label, value in value.map { label.isEmpty ? "\($0)%" : "\(label) \($0)%" } }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
