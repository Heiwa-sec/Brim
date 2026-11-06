import SwiftUI

struct IslandView: View {
    let model: IslandModel
    let host: ModuleHost
    @State private var dropTargeted = false
    @AppStorage("keepOpen") private var keepOpen = false
    @AppStorage("frostedIsland") private var frosted = false
    @AppStorage("frostedIntensity") private var frostedIntensity = 0.5

    private let morph = Animation.spring(response: 0.42, dampingFraction: 0.78)

    var body: some View {
        IslandShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius)
            .fill(fill)
            .background { if frosted && model.state == .expanded { IslandShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius).fill(.ultraThinMaterial) } }
            .overlay { content }
            .clipShape(IslandShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius))
            .frame(width: model.size.width, height: model.size.height)
            .dropDestination(for: URL.self) { urls, _ in host.drop(urls) } isTargeted: { dropTargeted = $0 }
            // The spring stops here: the panel itself resizes instantly, and animating the alignment frame
            // below would make the shape drift in from the middle of the panel instead of the notch.
            .animation(morph, value: model.size) // size, not state, so adding the lyrics column springs too
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea() // a window over the notch gets a top safe-area inset that would push the shape down
            .padding(.top, model.geometry.topInset)
            .opacity(model.isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: model.isVisible)
    }

    /// Frosted glass: black that thins toward the bottom, never below 45% so white text stays readable on a bright wallpaper.
    /// The compact ears stay solid black so they join the notch.
    private var fill: AnyShapeStyle {
        guard frosted, model.state == .expanded else { return AnyShapeStyle(.black) }
        let s = min(max(frostedIntensity, 0), 1)
        return AnyShapeStyle(LinearGradient(colors: [.black.opacity(1 - 0.1 * s), .black.opacity(1 - 0.55 * s)], startPoint: .top, endPoint: .bottom))
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

    /// Kept open and idle: only the lyrics show, with no controls. Falls back to the normal view when there are none.
    private var lyricsMode: Bool { model.narrowLyrics }

    private var expandedBody: some View {
        Group {
            let tab = host.resolve(model.tab)
            let views = host.views(in: tab)
            if dropTargeted {
                Text("Drop to add to tray")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .glassEffect(in: .capsule)
            } else if lyricsMode, let lyrics = host.lyrics {
                LyricsView(module: lyrics, width: model.size.width - 56, fontSize: 22, fadeByDistance: true, centered: true)
                    .transition(.opacity)
            } else if !views.isEmpty {
                HStack(spacing: IslandModel.columnGap) { ForEach(views.indices, id: \.self) { views[$0] } }
                    .id(tab)
            } else {
                Text(host.emptyMessage(in: tab))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .glassEffect(in: .capsule)
            }
        }
        .padding(.top, model.geometry.size.height + 4) // stay clear of the notch
        .padding(.horizontal, 28).padding(.bottom, host.tabs.count > 1 ? 24 : 16)
        .animation(.easeInOut(duration: 0.2), value: host.resolve(model.tab))
        .animation(.easeInOut(duration: 0.25), value: lyricsMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) { // beside the notch, in the menu-bar row
                if keepOpen {
                    Button { model.dismissed = true; model.hovering = false; model.pinned = false } label: { Image(systemName: "chevron.up").font(.system(size: 12, weight: .bold)) }
                        .accessibilityLabel("Close the island")
                }
                Button { SettingsWindow.shared.show() } label: { Image(systemName: "gearshape.fill").font(.system(size: 12)) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, 8).padding(.trailing, 18)
            .opacity(lyricsMode ? 0 : 1).allowsHitTesting(!lyricsMode)
        }
        .overlay(alignment: .bottom) { tabDots.opacity(lyricsMode ? 0 : 1) }
        .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.14))) // appear after the shape has grown
    }

    /// Page dots like the iOS home screen: the current tab is a wide white pill. Scroll sideways on the island, or click a dot.
    @ViewBuilder private var tabDots: some View {
        let tabs = host.tabs
        if tabs.count > 1 {
            HStack(spacing: 6) {
                ForEach(tabs, id: \.self) { tab in
                    let current = tab == host.resolve(model.tab)
                    Button { model.tab = tab } label: {
                        Capsule().fill(.white.opacity(current ? 0.6 : 0.22)).frame(width: current ? 16 : 6, height: 6)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.tab)
            .padding(.bottom, 4)
        }
    }
}
