import AppKit

/// Borderless panel that never becomes main, and key only on the To-do tab, so it can't steal focus from the frontmost app.
final class IslandPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        acceptsMouseMovedEvents = true
        isMovable = false
    }

    /// True only on the To-do tab, so its text field can type; everywhere else the panel never takes focus.
    var acceptsKeys = false
    override var canBecomeKey: Bool { acceptsKeys }
    override var canBecomeMain: Bool { false }
    // Borderless windows may sit over the menu bar; don't let AppKit push the frame below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
