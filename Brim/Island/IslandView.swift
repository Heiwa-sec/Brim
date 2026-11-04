import SwiftUI

struct IslandView: View {
    let model: IslandModel

    private let morph = Animation.spring(response: 0.42, dampingFraction: 0.78)

    var body: some View {
        IslandShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius)
            .fill(.black)
            .frame(width: model.size.width, height: model.size.height)
            .overlay { if model.state == .expanded { expandedBody } }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, model.geometry.topInset)
            .opacity(model.isVisible ? 1 : 0)
            .animation(morph, value: model.state)
            .animation(.easeOut(duration: 0.2), value: model.isVisible)
    }

    private var expandedBody: some View {
        Text("Nothing playing")
            .font(.callout)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .glassEffect(in: .capsule)
            .transition(.opacity)
    }
}
