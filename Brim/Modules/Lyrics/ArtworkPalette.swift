import AppKit

struct HSB: Equatable, Sendable {
    var h: Double, s: Double, b: Double
}

/// Two accent colours sampled from the album art, used to fill the current lyric line.
struct ArtworkPalette: Equatable, Sendable {
    var first: HSB
    var second: HSB

    static let white = ArtworkPalette(first: HSB(h: 0, s: 0, b: 1), second: HSB(h: 0, s: 0, b: 1))

    /// The most saturated colour, plus the saturated colour furthest from it in hue. Both are brightened to read on black.
    /// Grey or dark art has no usable accent, so it falls back to white.
    static func pick(_ pixels: [(r: Double, g: Double, b: Double)]) -> ArtworkPalette {
        let colors = pixels.map(hsb).filter { $0.s >= 0.25 && $0.b >= 0.2 }
        guard let first = colors.max(by: { $0.s < $1.s }) else { return .white }
        let second = colors.max(by: { hueDistance($0, first) < hueDistance($1, first) }) ?? first
        func lift(_ c: HSB) -> HSB { HSB(h: c.h, s: c.s, b: max(c.b, 0.8)) }
        return ArtworkPalette(first: lift(first), second: lift(second))
    }

    /// Downsamples the image to 8x8, so the cost does not depend on the artwork size.
    static func sample(_ image: NSImage) -> ArtworkPalette {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .white }
        let n = 8
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard drawn else { return .white }
        let pixels = stride(from: 0, to: bytes.count, by: 4).map {
            (r: Double(bytes[$0]) / 255, g: Double(bytes[$0 + 1]) / 255, b: Double(bytes[$0 + 2]) / 255)
        }
        return pick(pixels)
    }

    private static func hsb(_ p: (r: Double, g: Double, b: Double)) -> HSB {
        let top = max(p.r, p.g, p.b), delta = top - min(p.r, p.g, p.b)
        guard delta > 0 else { return HSB(h: 0, s: 0, b: top) }
        let sector: Double
        switch top {
        case p.r: sector = ((p.g - p.b) / delta).truncatingRemainder(dividingBy: 6)
        case p.g: sector = (p.b - p.r) / delta + 2
        default: sector = (p.r - p.g) / delta + 4
        }
        return HSB(h: (sector < 0 ? sector + 6 : sector) / 6, s: delta / top, b: top)
    }

    private static func hueDistance(_ a: HSB, _ b: HSB) -> Double {
        let d = abs(a.h - b.h)
        return min(d, 1 - d)
    }
}
