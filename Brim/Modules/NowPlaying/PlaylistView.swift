import SwiftUI

/// Toggles the playlist list. Hidden unless the playing app is Apple Music.
struct PlaylistButton: View {
    let module: NowPlayingModule
    var scale: CGFloat = 1

    var body: some View {
        if module.info?.bundleID == PlaylistModel.musicBundleID {
            let playlist = module.playlist
            Button {
                playlist.open.toggle()
                if playlist.open { playlist.load() }
            } label: {
                Image(systemName: playlist.open ? "list.bullet.circle.fill" : "list.bullet")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(playlist.open ? 1 : 0.55))
                    .frame(width: 34 * scale, height: 34 * scale)
            }
            .buttonStyle(.plain)
            .glassEffect(in: .circle)
            .accessibilityLabel(playlist.open ? "Hide playlist" : "Show playlist")
        }
    }
}

/// Scrollable list of the playlist. Click a row to play it; the playing row is highlighted and kept in view.
struct PlaylistView: View {
    let module: NowPlayingModule
    var fontSize: CGFloat = 13
    var rowPadding: CGFloat = 5

    var body: some View {
        let playlist = module.playlist
        let current = playlist.current(title: module.info?.title, artist: module.info?.artist)
        Group {
            if playlist.tracks.isEmpty {
                Text(playlist.loading ? "Loading…" : playlist.failed ? "Can't read the playlist. Allow Brim to control Music in System Settings > Privacy & Security > Automation." : "No tracks")
                    .font(.system(size: fontSize)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(playlist.tracks.indices, id: \.self) { i in row(playlist.tracks[i], index: i, isCurrent: i == current) }
                        }
                    }
                    // Jump (no animation) when the list first fills or reloads; animate for normal track changes.
                    .onAppear { if let current { proxy.scrollTo(current, anchor: .center) } }
                    .onChange(of: playlist.tracks) { _, _ in if let current { proxy.scrollTo(current, anchor: .center) } }
                    .onChange(of: current) { _, new in if let new { withAnimation { proxy.scrollTo(new, anchor: .center) } } }
                }
            }
        }
        // The song is not in the list: another playlist started, so read it again.
        .onChange(of: module.info?.title) { _, _ in
            if playlist.open, !playlist.loading, playlist.current(title: module.info?.title, artist: module.info?.artist) == nil { playlist.load() }
        }
    }

    private func row(_ track: PlaylistTrack, index: Int, isCurrent: Bool) -> some View {
        Button { module.playlist.play(index) } label: {
            HStack(spacing: 8) {
                Text("\(index + 1)").font(.system(size: fontSize - 2).monospacedDigit()).foregroundStyle(.white.opacity(0.4)).frame(width: fontSize * 2.2, alignment: .trailing)
                Text(track.title).fontWeight(isCurrent ? .bold : .regular).lineLimit(1)
                Text(track.artist).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.system(size: fontSize))
            .foregroundStyle(.white.opacity(isCurrent ? 1 : 0.8))
            .padding(.vertical, rowPadding).padding(.horizontal, 6)
            .background(isCurrent ? Color.white.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
