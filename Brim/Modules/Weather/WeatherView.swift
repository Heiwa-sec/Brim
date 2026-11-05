import SwiftUI

extension WeatherModule {
    var expanded: AnyView? {
        guard let info else { return nil }
        return AnyView(WeatherView(info: info))
    }
}

struct WeatherView: View {
    static let width: CGFloat = 215 // same column width as the tray

    let info: WeatherInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weather").font(.headline)
            HStack(spacing: 10) {
                Image(systemName: info.symbol).font(.system(size: 30)).symbolRenderingMode(.multicolor)
                Text(Measurement(value: info.celsius, unit: UnitTemperature.celsius).formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))))
                    .font(.system(size: 34, weight: .bold).monospacedDigit())
            }
            Text(info.description).font(.caption).foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(width: Self.width, alignment: .leading)
    }
}
