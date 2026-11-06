import SwiftUI

/// The typeface for the full-screen lyrics, chosen in Settings > General (`lyricsFont`).
enum LyricsFont: String, CaseIterable, Identifiable {
    case standard, rounded, bubbly, chalkboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Default"
        case .rounded: "Rounded"
        case .bubbly: "Bubbly"
        case .chalkboard: "Chalkboard"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .standard: .system(size: size, weight: .bold)
        case .rounded: .system(size: size, weight: .heavy, design: .rounded)
        case .bubbly: .custom("ArialRoundedMTBold", size: size)
        case .chalkboard: .custom("ChalkboardSE-Bold", size: size)
        }
    }
}

struct LyricsView: View {
    static let width: CGFloat = 250

    let module: LyricsModule
    @State private var browsing = false
    @State private var returnWork: DispatchWorkItem?
    var width: CGFloat = Self.width
    var fontSize: CGFloat = 21
    /// Lines dim the further they are from the current one, and ease in and out as the current line moves.
    var fadeByDistance = false
    var style = LyricsFont.standard
    var centered = false

    var body: some View {
        let lines = module.lines
        let info = module.nowPlaying.info
        // One wake-up per upcoming line and none while paused, so the view costs nothing between lines.
        // `.now` first: the timeline renders its initial frame at the first date.
        TimelineView(.explicit([.now] + wakeDates(lines: lines, info: info))) { context in
            column(lines: lines, current: LRC.index(at: info?.position(at: context.date) ?? 0, in: lines))
        }
        .frame(width: width)
    }

    private func wakeDates(lines: [LyricLine], info: NowPlayingInfo?) -> [Date] {
        guard let info, info.playing, info.rate > 0 else { return [] }
        let now = Date.now
        return lines.compactMap { line in
            let date = info.timestamp.addingTimeInterval((line.time - info.elapsed) / info.rate)
            return date > now ? date : nil
        }
    }

    private func column(lines: [LyricLine], current: Int?) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(lines.indices, id: \.self) { index in
                        line(lines[index], isCurrent: index == current, distance: current.map { abs(index - $0) } ?? 0)
                            .id(index)
                            .onTapGesture { module.nowPlaying.seek(to: lines[index].time) }
                    }
                }
                .padding(.vertical, 50)
            }
            .onAppear { if let current { proxy.scrollTo(current, anchor: .center) } }
            .onChange(of: current) { _, new in
                if let new, !browsing { withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(new, anchor: .center) } }
            }
            // Scrolling by hand shows every line; 3 s after the last touch the view returns to the sung line.
            .onScrollPhaseChange { _, phase in
                guard phase == .interacting || phase == .decelerating else { return }
                browsing = true
                returnWork?.cancel()
                let work = DispatchWorkItem {
                    browsing = false
                    if let current { withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(current, anchor: .center) } }
                }
                returnWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
            }
        }
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.25),
                                     .init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
    }

    private func line(_ line: LyricLine, isCurrent: Bool, distance: Int) -> some View {
        Text(line.text.isEmpty ? "♪" : line.text)
            .font(style.font(size: fontSize)) // one size for every line, so lines never rewrap when highlighted
            .foregroundStyle(isCurrent ? AnyShapeStyle(gradient) : AnyShapeStyle(.white.opacity(fadeByDistance ? browsing ? 0.45 : max(0, 0.7 - 0.2 * Double(distance)) : 0.35)))
            .animation(.easeInOut(duration: 0.7), value: isCurrent)
            .animation(.easeInOut(duration: 0.7), value: distance)
            .multilineTextAlignment(centered ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .contentShape(Rectangle())
    }

    private var gradient: LinearGradient {
        func color(_ c: HSB) -> Color { Color(hue: c.h, saturation: c.s, brightness: c.b) }
        return LinearGradient(colors: [color(module.palette.first), color(module.palette.second)], startPoint: .leading, endPoint: .trailing)
    }
}
