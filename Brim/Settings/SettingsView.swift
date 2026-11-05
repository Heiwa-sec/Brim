import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let modules: [any IslandModule.Type]

    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            ModulesTab(modules: modules).tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            DisplaysTab().tabItem { Label("Displays", systemImage: "display") }
            PermissionsTab().tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 420, height: 320)
    }
}

/// A switch bound to a UserDefaults key. `fallback` is what the app uses while the key is unset.
struct DefaultsToggle: View {
    let title: String
    @AppStorage private var isOn: Bool

    init(_ title: String, key: String, fallback: Bool) {
        self.title = title
        _isOn = AppStorage(wrappedValue: fallback, key)
    }

    var body: some View { Toggle(title, isOn: $isOn) }
}

private struct GeneralTab: View {
    @AppStorage("hoverDelay") private var hoverDelay = 0.12
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Toggle("Open Brim at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            LabeledContent("Hover delay") {
                HStack {
                    Slider(value: $hoverDelay, in: 0...0.6)
                    Text("\(Int(hoverDelay * 1000)) ms").monospacedDigit().frame(width: 56, alignment: .trailing)
                }
            }
            Text("How long the pointer rests on the notch before the island opens.").font(.caption).foregroundStyle(.secondary)
            Text("Open these settings any time with ⌥⌘, or the gear in the island.").font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct ModulesTab: View {
    let modules: [any IslandModule.Type]

    var body: some View {
        Form {
            ForEach(modules.indices, id: \.self) { i in
                let module = modules[i]
                DefaultsToggle(module.title, key: "module.\(module.id).enabled", fallback: module.defaultEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

private struct DisplaysTab: View {
    var body: some View {
        Form {
            ForEach(NSScreen.screens, id: \.displayUUID) { screen in
                if let id = screen.displayUUID {
                    Section(screen.localizedName) {
                        DefaultsToggle("Show the island", key: "display.\(id).enabled", fallback: true)
                        DefaultsToggle("Hide until the pointer reaches the top", key: "display.\(id).hideUntilTop", fallback: false)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
