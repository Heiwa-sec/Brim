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
        .frame(width: 420, height: 540)
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
    @AppStorage("lyricsFont") private var lyricsFont = LyricsFont.standard.rawValue
    @AppStorage("keepOpen") private var keepOpen = false
    @AppStorage("frostedIsland") private var frosted = false
    @AppStorage("frostedIntensity") private var frostedIntensity = 0.5
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmUninstall = false

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
            Picker("Full-screen lyrics font", selection: $lyricsFont) {
                ForEach(LyricsFont.allCases) { Text($0.title).tag($0.rawValue) }
            }
            LabeledContent("Hover delay") {
                HStack {
                    Slider(value: $hoverDelay, in: 0...0.6)
                    Text("\(Int(hoverDelay * 1000)) ms").monospacedDigit().frame(width: 56, alignment: .trailing)
                }
            }
            Text("How long the pointer rests on the notch before the island opens.").font(.caption).foregroundStyle(.secondary)
            Toggle("Keep the notch open", isOn: $keepOpen)
            Text("The island stays open without hovering. Close it with the ⌃ button beside the gear; hover the notch to open it again.").font(.caption).foregroundStyle(.secondary)
            Toggle("Frosted-glass island", isOn: $frosted)
            LabeledContent("Intensity") { Slider(value: $frostedIntensity, in: 0...1).disabled(!frosted) }
            Text("Semi-transparent, clearer toward the bottom. It never drops below 45% black, so text stays readable.").font(.caption).foregroundStyle(.secondary)
            Text("Open these settings any time with ⌥⌘, or the gear in the island.").font(.caption).foregroundStyle(.secondary)
            Text("⌥⌘L shows what is playing full screen, with lyrics. Press any key or click to close it.").font(.caption).foregroundStyle(.secondary)
            Button("Uninstall Brim…", role: .destructive) { confirmUninstall = true }
                .confirmationDialog("Uninstall Brim?", isPresented: $confirmUninstall) {
                    Button("Uninstall", role: .destructive, action: Uninstaller.run)
                } message: {
                    Text("Moves Brim to the Trash and deletes its settings, to-do list and cached lyrics.")
                }
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
