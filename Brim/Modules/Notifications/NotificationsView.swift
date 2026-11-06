import AppKit
import SwiftUI

extension NotificationsModule {
    var expanded: AnyView? { current.map { AnyView(NotificationCard(record: $0)) } }
}

struct NotificationCard: View {
    let record: NotificationRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(nsImage: icon).resizable().frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                if !record.title.isEmpty { Text(record.title).font(.system(size: 13, weight: .semibold)).lineLimit(1) }
                if !record.body.isEmpty { Text(record.body).font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(3) }
            }
        }
        .foregroundStyle(.white)
        .frame(width: IslandModel.columnWidth, alignment: .leading)
    }

    private var icon: NSImage {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: record.app)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)!
    }
}
