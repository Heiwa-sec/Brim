import AppKit

// Explicit entry point: @main on a delegate would call NSApplicationMain, which only instantiates a delegate from a nib.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
