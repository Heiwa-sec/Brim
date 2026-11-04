import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var displays: DisplayManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        displays = DisplayManager()
    }
}
