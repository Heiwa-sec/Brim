@preconcurrency import AVFoundation
import AppKit
import SwiftUI

/// Shows your own camera in a small floating window while a FaceTime call is going on. Off by default; the camera
/// permission is requested the moment you switch it on. A call counts as active while FaceTime is running and another
/// app is using the camera: both are events (workspace notifications and a KVO key path), so nothing polls.
/// Our own session does not count as "another application", so it can stay up without keeping itself alive.
@MainActor @Observable
final class CallCameraModule: IslandModule {
    static let id = "callCamera"
    static let title = "Call camera"
    static let defaultEnabled = false
    private static let faceTime = "com.apple.FaceTime"

    private(set) var problem: String?
    /// The user's choice to shrink the window to a button; the call resets nothing.
    var minimised = false { didSet { panel?.fit(minimised: minimised) } }

    @ObservationIgnored private let session = AVCaptureSession()
    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "dev.brim.Brim.callCamera")
    @ObservationIgnored private var panel: CallCameraPanel?
    @ObservationIgnored private var busyObservation: NSKeyValueObservation?
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: watch()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [self] in granted ? watch() : (problem = "Call camera needs Camera access (System Settings > Privacy & Security)") }
            }
        default: problem = "Call camera needs Camera access (System Settings > Privacy & Security)"
        }
    }

    func stop() {
        busyObservation = nil
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers = []
        hide()
        problem = nil
    }

    private func watch() {
        problem = nil
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else {
            problem = "No camera found"
            return
        }
        if session.inputs.isEmpty, session.canAddInput(input) { session.addInput(input) }
        busyObservation = device.observe(\.isInUseByAnotherApplication, options: [.initial]) { [weak self] _, _ in
            Task { @MainActor in self?.update() }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            })
        }
    }

    private func update() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        let faceTimeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.faceTime).isEmpty
        if faceTimeRunning && device.isInUseByAnotherApplication { show() } else { hide() }
    }

    private func show() {
        guard panel == nil else { return }
        minimised = false
        let panel = CallCameraPanel(session: session, module: self)
        self.panel = panel
        sessionQueue.async { [session] in session.startRunning() } // startRunning blocks, so keep it off the main thread
        panel.orderFrontRegardless()
    }

    private func hide() {
        guard let panel else { return }
        sessionQueue.async { [session] in session.stopRunning() }
        panel.orderOut(nil)
        self.panel = nil
    }
}
