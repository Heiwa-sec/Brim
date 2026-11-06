import ApplicationServices
import AVFoundation
import CoreLocation
import SwiftUI

/// Status of the permissions Brim can ask for. "Allow" shows the system's own prompt where macOS has one,
/// otherwise it opens the matching System Settings pane; "Open" always opens the pane.
/// Re-read whenever the app becomes active, so there is no polling.
struct PermissionsTab: View {
    @State private var accessibility = false
    @State private var fullDisk = false
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var locationManager = CLLocationManager() // must outlive the prompt
    @State private var location = CLLocationManager().authorizationStatus

    var body: some View {
        Form {
            row("Accessibility", "Volume and brightness HUD", granted: accessibility, pane: "Privacy_Accessibility") {
                // The string is kAXTrustedCheckOptionPrompt; the global is not concurrency-safe in Swift 6.
                _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            }
            row("Location", "Weather (approximate only)", granted: location == .authorized || location == .authorizedAlways, pane: "Privacy_LocationServices") {
                if location == .notDetermined { locationManager.requestWhenInUseAuthorization() } else { openPane("Privacy_LocationServices") }
            }
            row("Camera", "Call camera (your own camera during FaceTime)", granted: camera == .authorized, pane: "Privacy_Camera") {
                if camera == .notDetermined { AVCaptureDevice.requestAccess(for: .video) { _ in DispatchQueue.main.async { refresh() } } } else { openPane("Privacy_Camera") }
            }
            row("Full Disk Access", "Notification mirroring", granted: fullDisk, pane: "Privacy_AllFiles") {
                // macOS has no prompt for Full Disk Access and does not list the app on its own, so show Brim.app to drag into the list.
                openPane("Privacy_AllFiles")
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            }
            Text("Notification mirroring reads only the title, text and app of new notifications from macOS's notification database, read-only, and keeps them in memory while the banner shows. Nothing is logged, saved or sent.").font(.caption).foregroundStyle(.secondary)
            Text("Brim asks only when you switch the matching module on or press Allow. Nothing is requested in advance. Full Disk Access has no prompt in macOS: Allow opens its list and shows Brim in Finder. Drag Brim into the list (or click +), enter your password, then reopen Brim.").font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func row(_ name: String, _ why: String, granted: Bool, pane: String, ask: @escaping () -> Void) -> some View {
        LabeledContent {
            HStack {
                Text(granted ? "Allowed" : "Not allowed").foregroundStyle(granted ? .green : .secondary)
                Button(granted ? "Open" : "Allow") { if granted { openPane(pane) } else { ask() } }
            }
        } label: {
            VStack(alignment: .leading) { Text(name); Text(why).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func openPane(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
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
