// Draws the app icon: swift scripts/make-icon.swift Brim/App/AppIcon.icns
import AppKit

let out = CommandLine.arguments[1]
let set = NSTemporaryDirectory() + "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
        let tile = rect.insetBy(dx: s * 0.06, dy: s * 0.06)
        let path = NSBezierPath(roundedRect: tile, xRadius: s * 0.22, yRadius: s * 0.22)
        NSGradient(colors: [NSColor(red: 0.42, green: 0.30, blue: 0.95, alpha: 1), NSColor(red: 0.10, green: 0.60, blue: 0.85, alpha: 1)])!.draw(in: path, angle: -60)
        // The island: a black pill hanging from the top edge of the tile, with three sound bars inside.
        let pill = NSRect(x: s * 0.27, y: tile.maxY - s * 0.26, width: s * 0.46, height: s * 0.26)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: pill, xRadius: s * 0.13, yRadius: s * 0.13).fill()
        NSColor.white.setFill()
        for (i, h) in [0.35, 0.6, 0.45].enumerated() {
            let bar = NSRect(x: pill.midX + CGFloat(i - 1) * s * 0.07 - s * 0.013, y: pill.midY - s * 0.26 * h / 2, width: s * 0.026, height: s * 0.26 * h)
            NSBezierPath(roundedRect: bar, xRadius: bar.width / 2, yRadius: bar.width / 2).fill()
        }
        // Two lyric lines below, the second dimmer, like Apple Music.
        for (i, w) in [0.5, 0.34].enumerated() {
            NSColor(white: 1, alpha: i == 0 ? 0.95 : 0.45).setFill()
            let line = NSRect(x: s * 0.5 - s * w / 2, y: s * 0.36 - CGFloat(i) * s * 0.12, width: s * w, height: s * 0.055)
            NSBezierPath(roundedRect: line, xRadius: line.height / 2, yRadius: line.height / 2).fill()
        }
        return true
    }
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try draw(base).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base).png"))
    try draw(base * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", set, "-o", out]
try task.run(); task.waitUntilExit()
