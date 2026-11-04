import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var host: ModuleHost?
    private var displays: DisplayManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = ModuleHost(modules: [NowPlayingModule()])
        self.host = host
        displays = DisplayManager(host: host)
    }
}
