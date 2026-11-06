import SwiftUI

extension ChargingModule {
    var compactLeading: AnyView? {
        guard let info else { return nil }
        return AnyView(
            Image(systemName: info.onAC ? "bolt.fill" : "battery.50percent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(info.onAC ? .green : .white.opacity(0.9))
        )
    }

    var compactTrailing: AnyView? {
        guard let info else { return nil }
        return AnyView(Text("\(info.percent)%").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(.white))
    }

    var expanded: AnyView? {
        guard let info, info.onAC else { return nil }
        return AnyView(ChargingView(info: info))
    }
}

struct ChargingView: View {
    let info: PowerInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Battery").font(.headline)
            Text("\(info.percent)%").font(.system(size: 34, weight: .bold).monospacedDigit())
            ProgressView(value: Double(info.percent), total: 100).tint(.green)
            Text(detail).font(.caption).foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(width: IslandModel.columnWidth, alignment: .leading)
    }

    private var detail: String {
        guard info.charging, let m = info.minutesToFull else { return info.status }
        return "\(info.status) · \(m / 60)h \(m % 60)m to full"
    }
}
