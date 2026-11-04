import SwiftUI

struct IslandView: View {
    let model: IslandModel
    let host: ModuleHost

    private let morph = Animation.spring(response: 0.42, dampingFraction: 0.78)

    var body: some View {
        IslandShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius)
            .fill(.black)
            .overlay { content }
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

    @ViewBuilder private var content: some View {
        switch model.state {
        case .collapsed: EmptyView()
        case .compact: compactBody
        case .expanded: expandedBody
        }
    }

    /// Leading activities sit left of the notch, trailing ones to its right.
    private var compactBody: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) { ForEach(host.compactLeading.indices, id: \.self) { host.compactLeading[$0] } }
                .frame(width: IslandModel.compactEar)
            Spacer(minLength: model.geometry.size.width)
            HStack(spacing: 6) { ForEach(host.compactTrailing.indices, id: \.self) { host.compactTrailing[$0] } }
                .frame(width: IslandModel.compactEar)
        }
        .transition(.opacity)
    }

    private var expandedBody: some View {
        Group {
            if let view = host.expandedViews.first {
                view
            } else {
                Text(host.emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .glassEffect(in: .capsule)
            }
        }
        .padding(.top, model.geometry.size.height + 4) // stay clear of the notch
        .padding(.horizontal, 28).padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.14))) // appear after the shape has grown
    }
}
