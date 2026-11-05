import AppKit
import SwiftUI

struct FileTrayView: View {
    static let width: CGFloat = 215 // with player and lyrics beside it, 250 overflowed the island padding

    let module: FileTrayModule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tray · \(module.items.count)").font(.headline)
                Spacer()
                Button("Clear") { module.clear() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .glassEffect(in: .capsule)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(module.items, id: \.self) { url in
                        VStack(spacing: 4) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 44, height: 44)
                            Text(url.lastPathComponent).font(.caption2).lineLimit(1).truncationMode(.middle).frame(width: 64)
                        }
                        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: Self.width)
    }
}
