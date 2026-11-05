import SwiftUI

extension BluetoothModule {
    var compactLeading: AnyView? {
        flashed.map { _ in AnyView(Image(systemName: "headphones").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)) }
    }

    var compactTrailing: AnyView? {
        guard let lowest = flashed?.battery.lowest else { return nil }
        return AnyView(Text("\(lowest)%").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(.white))
    }

    var expanded: AnyView? {
        devices.isEmpty ? nil : AnyView(BluetoothView(devices: devices))
    }
}

struct BluetoothView: View {
    static let width: CGFloat = 215 // same column width as the tray

    let devices: [BluetoothModule.Device]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bluetooth").font(.headline)
            ForEach(devices) { device in
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    if let summary = device.battery.summary {
                        Text(summary).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: Self.width, alignment: .leading)
    }
}
