import SwiftUI

extension NowPlayingModule {
    var compactLeading: AnyView? { AnyView(ArtworkView(image: artwork, size: 24, radius: 6)) }

    var compactTrailing: AnyView? {
        AnyView(
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9)) // static on purpose: an animated symbol cost ~8% CPU for as long as music plays
        )
    }

    var expanded: AnyView? { info == nil ? nil : AnyView(NowPlayingExpandedView(module: self)) }
}

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.1))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct NowPlayingExpandedView: View {
    let module: NowPlayingModule

    var body: some View {
        HStack(spacing: 18) {
            Button { NotificationCenter.default.post(name: .brimFullScreen, object: nil) } label: {
                ArtworkView(image: module.artwork, size: 110, radius: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show full screen")
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(module.info?.title ?? "").font(.headline).lineLimit(1)
                    Text(module.info?.artist ?? module.info?.album ?? "").font(.subheadline).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }
                ScrubberView(module: module)
                TransportView(module: module)
            }
        }
        .foregroundStyle(.white)
    }
}

struct TransportView: View {
    let module: NowPlayingModule

    var body: some View {
        HStack(spacing: 26) {
            button("backward.fill", .previous, size: 15)
            button(module.info?.playing == true ? "pause.fill" : "play.fill", .togglePlayPause, size: 20)
            button("forward.fill", .next, size: 15)
        }
        .padding(.horizontal, 22).padding(.vertical, 7)
        .glassEffect(in: .capsule)
        .frame(maxWidth: .infinity)
    }

    private func button(_ symbol: String, _ command: MediaCommand, size: CGFloat) -> some View {
        Button { module.send(command) } label: {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold)).contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

struct ScrubberView: View {
    let module: NowPlayingModule
    @State private var dragging: Double?

    var body: some View {
        let info = module.info
        let duration = info?.duration ?? 0
        // The timeline exists only while this view is on screen, and pauses with playback, so it costs nothing when idle.
        TimelineView(.animation(minimumInterval: 0.5, paused: info?.playing != true || dragging != nil)) { context in
            let position = dragging.map { $0 * duration } ?? info?.position(at: context.date) ?? 0
            VStack(spacing: 2) {
                track(fraction: duration > 0 ? position / duration : 0, duration: duration)
                HStack {
                    Text(format(position))
                    Spacer()
                    Text(duration > 0 ? format(duration) : "")
                }
                .font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func track(fraction: Double, duration: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25)).frame(height: 5)
                Capsule().fill(.white).frame(width: geo.size.width * min(max(fraction, 0), 1), height: 5)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { if duration > 0 { dragging = clamp($0.location.x / geo.size.width) } }
                .onEnded { value in
                    dragging = nil
                    if duration > 0 { module.seek(to: clamp(value.location.x / geo.size.width) * duration) }
                })
        }
        .frame(height: 14)
    }

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
