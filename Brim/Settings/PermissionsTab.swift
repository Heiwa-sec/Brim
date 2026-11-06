import ApplicationServices
import AVFoundation
import CoreLocation
import SwiftUI

/// Read-only status of the permissions Brim can ask for, with a shortcut to the matching System Settings pane.
/// Re-read whenever the app becomes active, so there is no polling.
struct PermissionsTab: View {
    @State private var accessibility = false
    @State private var fullDisk = false
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var location = CLLocationManager().authorizationStatus

    var body: some View {
        Form {
            row("Accessibility", "Volume and brightness HUD", granted: accessibility, pane: "Privacy_Accessibility")
            row("Location", "Weather (approximate only)", granted: location == .authorized || location == .authorizedAlways, pane: "Privacy_LocationServices")
            row("Camera", "Call camera (your own camera during FaceTime)", granted: camera == .authorized, pane: "Privacy_Camera")
            row("Full Disk Access", "Notification mirroring", granted: fullDisk, pane: "Privacy_AllFiles")
            Text("Notification mirroring reads only the title, text and app of new notifications from macOS's notification database, read-only, and keeps them in memory while the banner shows. Nothing is logged, saved or sent.").font(.caption).foregroundStyle(.secondary)
            Text("Brim asks only when you switch the matching module on. Nothing here is requested in advance.").font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func row(_ name: String, _ why: String, granted: Bool, pane: String) -> some View {
        LabeledContent {
            HStack {
                Text(granted ? "Allowed" : "Not allowed").foregroundStyle(granted ? .green : .secondary)
                Button("Open") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
                }
            }
        } label: {
            VStack(alignment: .leading) { Text(name); Text(why).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func refresh() {
        accessibility = AXIsProcessTrusted()
        let fd = open(NotificationsModule.directory + "/db", O_RDONLY)
        fullDisk = fd >= 0
        if fd >= 0 { close(fd) }
        camera = AVCaptureDevice.authorizationStatus(for: .video)
        location = CLLocationManager().authorizationStatus
    }
}
