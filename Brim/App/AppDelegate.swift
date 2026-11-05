import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var host: ModuleHost?
    private var displays: DisplayManager?
    private var lockScreen: LockScreenController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let nowPlaying = NowPlayingModule()
        let host = ModuleHost(modules: [nowPlaying, LyricsModule(nowPlaying: nowPlaying), FileTrayModule(), ChargingModule(), BluetoothModule(), WeatherModule(), HUDModule(), NotificationsModule()])
        self.host = host
        displays = DisplayManager(host: host)
        lockScreen = LockScreenController(nowPlaying: nowPlaying)
        SettingsWindow.shared.modules = host.modules.map { type(of: $0) }
        SettingsWindow.shared.registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) { lockScreen?.shutdown() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.show()
        return true
    }
}
