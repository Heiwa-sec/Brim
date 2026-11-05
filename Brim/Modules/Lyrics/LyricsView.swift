import SwiftUI

struct LyricsView: View {
    static let width: CGFloat = 250

    let module: LyricsModule
    var width: CGFloat = Self.width
    var fontSize: CGFloat = 21
    /// Lines dim the further they are from the current one, and ease in and out as the current line moves.
    var fadeByDistance = false

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
                if let new { withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(new, anchor: .center) } }
            }
        }
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.25),
                                     .init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
    }

    private func line(_ line: LyricLine, isCurrent: Bool, distance: Int) -> some View {
        Text(line.text.isEmpty ? "♪" : line.text)
            .font(.system(size: fontSize, weight: .bold)) // Apple Music style: one big bold size, so lines never rewrap when highlighted
            .foregroundStyle(isCurrent ? AnyShapeStyle(gradient) : AnyShapeStyle(.white.opacity(fadeByDistance ? max(0.12, 0.5 - 0.1 * Double(distance)) : 0.35)))
            .animation(.easeInOut(duration: 0.45), value: isCurrent)
            .animation(.easeInOut(duration: 0.45), value: distance)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    private var gradient: LinearGradient {
        func color(_ c: HSB) -> Color { Color(hue: c.h, saturation: c.s, brightness: c.b) }
        return LinearGradient(colors: [color(module.palette.first), color(module.palette.second)], startPoint: .leading, endPoint: .trailing)
    }
}
