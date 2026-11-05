import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var host: ModuleHost?
    private var displays: DisplayManager?
    private var fullScreen: FullScreenController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let nowPlaying = NowPlayingModule()
        let lyrics = LyricsModule(nowPlaying: nowPlaying)
        let host = ModuleHost(modules: [nowPlaying, lyrics, FileTrayModule(), ChargingModule(), WeatherModule(), HUDModule(), NotificationsModule()])
        self.host = host
        displays = DisplayManager(host: host)
        fullScreen = FullScreenController(nowPlaying: nowPlaying, lyrics: lyrics)
        SettingsWindow.shared.modules = host.modules.map { type(of: $0) }
        SettingsWindow.shared.registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) { fullScreen?.shutdownNow() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.show()
        return true
    }
}
