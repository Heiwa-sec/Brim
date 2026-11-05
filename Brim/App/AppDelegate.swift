import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var host: ModuleHost?
    private var displays: DisplayManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let nowPlaying = NowPlayingModule()
        let host = ModuleHost(modules: [nowPlaying, LyricsModule(nowPlaying: nowPlaying), FileTrayModule(), ChargingModule(), BluetoothModule(), WeatherModule(), HUDModule()])
        self.host = host
        displays = DisplayManager(host: host)
    }
}
