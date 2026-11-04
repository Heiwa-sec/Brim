import CoreGraphics

/// Collapsed footprint of the island on one display, derived from the screen's own notch metrics.
struct NotchGeometry: Equatable {
    let hasNotch: Bool
    /// Collapsed size. On a notch Mac this is exactly the notch cutout.
    let size: CGSize
    /// Gap between the screen's top edge and the island. Zero on a notch, small for the floating pill.
    let topInset: CGFloat
    /// Horizontal centre in screen coordinates; the notch is not always at the exact screen midpoint.
    let centerX: CGFloat

    // Design values for displays without a notch (the notch itself is never hardcoded).
    static let pillWidth: CGFloat = 170
    static let pillTopInset: CGFloat = 6

    static func make(screenFrame: CGRect, safeAreaTop: CGFloat, auxLeft: CGRect?, auxRight: CGRect?,
                     menuBarHeight: CGFloat) -> NotchGeometry {
        if safeAreaTop > 0, let left = auxLeft, let right = auxRight, right.minX > left.maxX {
            let width = right.minX - left.maxX
            return NotchGeometry(hasNotch: true, size: CGSize(width: width, height: safeAreaTop),
                                 topInset: 0, centerX: left.maxX + width / 2)
        }
        return NotchGeometry(hasNotch: false, size: CGSize(width: pillWidth, height: menuBarHeight),
                             topInset: pillTopInset, centerX: screenFrame.midX)
    }
}
