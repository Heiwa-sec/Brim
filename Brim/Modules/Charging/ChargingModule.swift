import AppKit
import IOKit.ps
import SwiftUI

/// Battery and power state from IOKit's power-source notifications. The compact pill flashes for a few seconds
/// when power is connected or removed; the expanded island shows a column only while on AC.
@MainActor @Observable
final class ChargingModule: IslandModule {
    static let id = "charging"
    static let title = "Charging"
    static let flashSeconds = 4.0

    private(set) var info: PowerInfo?
    private(set) var flashing = false

    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var flashEnd: DispatchWorkItem?

    var hasActivity: Bool { flashing && info != nil }

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let module = Unmanaged<ChargingModule>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { module.refresh() }
        }, context)?.takeRetainedValue() else { return }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        info = Self.read() // initial state: no flash
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
        source = nil
        flashEnd?.cancel()
        flashing = false
        info = nil
    }

    private func refresh() {
        let new = Self.read()
        if let new, let old = info, new.onAC != old.onAC { flash() }
        info = new
    }

    private func flash() {
        flashEnd?.cancel()
        flashing = true
        let end = DispatchWorkItem { [weak self] in self?.flashing = false }
        flashEnd = end
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flashSeconds, execute: end)
    }

    private static func read() -> PowerInfo? {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
        return sources.lazy
            .compactMap { IOPSGetPowerSourceDescription(blob, $0)?.takeUnretainedValue() as? [String: Any] }
            .compactMap(PowerInfo.init).first
    }
}
