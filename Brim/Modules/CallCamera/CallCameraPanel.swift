@preconcurrency import AVFoundation
import AppKit
import SwiftUI

/// The floating window for the call camera: your mirrored preview with a minimise button, or just the camera button.
final class CallCameraPanel: NSPanel {
    private static let full = NSSize(width: 240, height: 180)
    private static let small = NSSize(width: 44, height: 44)

    @MainActor init(session: AVCaptureSession, module: CallCameraModule) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = true
        contentView = NSHostingView(rootView: CallCameraView(session: session, module: module))
        fit(minimised: false)
    }

    /// Resizes towards the top-right corner of the screen, under the menu bar, keeping the top-right corner fixed once placed.
    @MainActor func fit(minimised: Bool) {
        let size = minimised ? Self.small : Self.full
        let anchor = frame == .zero
            ? NSPoint(x: (NSScreen.main?.visibleFrame.maxX ?? 800) - 16, y: (NSScreen.main?.visibleFrame.maxY ?? 600) - 16)
            : NSPoint(x: frame.maxX, y: frame.maxY)
        setFrame(NSRect(x: anchor.x - size.width, y: anchor.y - size.height, width: size.width, height: size.height), display: true, animate: false)
    }

    override var canBecomeKey: Bool { false }
}

private struct CallCameraView: View {
    let session: AVCaptureSession
    let module: CallCameraModule

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if module.minimised {
                button("video.fill", label: "Show the camera") { module.minimised = false }
            } else {
                CameraPreview(session: session)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                button("arrow.down.right.and.arrow.up.left", label: "Minimise the camera") { module.minimised = true }.padding(8)
            }
        }
    }

    private func button(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(in: .circle)
        .accessibilityLabel(label)
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.automaticallyAdjustsVideoMirroring = false
        layer.connection?.isVideoMirrored = true // like a mirror, so it feels natural
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
