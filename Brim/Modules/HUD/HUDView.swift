import SwiftUI

extension HUDModule {
    var compactLeading: AnyView? {
        AnyView(Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white))
    }

    var compactTrailing: AnyView? {
        AnyView(
            Capsule().fill(.white.opacity(0.25))
                .overlay(alignment: .leading) { GeometryReader { Capsule().fill(.white).frame(width: $0.size.width * CGFloat(self.level)) } }
                .frame(width: 44, height: 5)
        )
    }
}
