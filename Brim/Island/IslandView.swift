import SwiftUI

struct IslandView: View {
    let model: IslandModel

    private let morph = Animation.spring(response: 0.42, dampingFraction: 0.78)

    var body: some View {
        IslandShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius)
            .fill(.black)
            .overlay { if model.state == .expanded { expandedBody } }
            .clipShape(IslandShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius))
            .frame(width: model.size.width, height: model.size.height)
            // The spring stops here: the panel itself resizes instantly, and animating the alignment frame
            // below would make the shape drift in from the middle of the panel instead of the notch.
            .animation(morph, value: model.state)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea() // a window over the notch gets a top safe-area inset that would push the shape down
            .padding(.top, model.geometry.topInset)
            .opacity(model.isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: model.isVisible)
    }

    private var expandedBody: some View {
        Text("Nothing playing")
            .font(.callout)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .glassEffect(in: .capsule)
            .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.14))) // appear after the shape has grown
    }
}
