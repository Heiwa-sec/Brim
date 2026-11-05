import ApplicationServices
import CoreBluetooth
import CoreLocation
import SwiftUI

/// Read-only status of the permissions Brim can ask for, with a shortcut to the matching System Settings pane.
/// Re-read whenever the app becomes active, so there is no polling.
struct PermissionsTab: View {
    @State private var accessibility = false
    @State private var bluetooth = CBManager.authorization
    @State private var location = CLLocationManager().authorizationStatus

    var body: some View {
        Form {
            row("Accessibility", "Volume and brightness HUD", granted: accessibility, pane: "Privacy_Accessibility")
            row("Bluetooth", "Device and AirPods battery", granted: bluetooth == .allowedAlways, pane: "Privacy_Bluetooth")
            row("Location", "Weather (approximate only)", granted: location == .authorized || location == .authorizedAlways, pane: "Privacy_LocationServices")
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
        bluetooth = CBManager.authorization
        location = CLLocationManager().authorizationStatus
    }
}
