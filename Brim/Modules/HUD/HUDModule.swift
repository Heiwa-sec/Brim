import AppKit
import AudioToolbox
import SwiftUI

/// Replaces the system volume and brightness HUD: a session event tap swallows the media keys, applies the change
/// itself and shows a symbol and level bar in the compact pill. A key is consumed only when the change was applied.
/// Needs Accessibility; without it no tap is installed and `problem` says why.
@MainActor @Observable
final class HUDModule: IslandModule {
    static let id = "hud"
    static let defaultEnabled = false
    static let showSeconds = 1.5

    private(set) var symbol = ""
    private(set) var level: Float = 0
    private(set) var showing = false
    private(set) var problem: String?

    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var tapSource: CFRunLoopSource?
    @ObservationIgnored private var trustObserver: NSObjectProtocol?
    @ObservationIgnored private var hideWork: DispatchWorkItem?
    @ObservationIgnored private var applied = false // whether the last key press was applied, so its release is consumed too

    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    @ObservationIgnored private var getBrightness: GetBrightness?
    @ObservationIgnored private var setBrightness: SetBrightness?

    var hasActivity: Bool { showing }

    func start() {
        if let lib = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            getBrightness = dlsym(lib, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: GetBrightness.self) }
            setBrightness = dlsym(lib, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: SetBrightness.self) }
        }
        // Fires when any app's Accessibility trust changes; the flag updates a moment later.
        trustObserver = DistributedNotificationCenter.default().addObserver(forName: .init("com.apple.accessibility.api"), object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { MainActor.assumeIsolated { self?.install() } }
        }
        install()
    }

    func stop() {
        if let trustObserver { DistributedNotificationCenter.default().removeObserver(trustObserver) }
        trustObserver = nil
        uninstall()
        hideWork?.cancel()
        showing = false
        problem = nil
        getBrightness = nil
        setBrightness = nil
    }

    private func install() {
        guard trustObserver != nil, tap == nil else { return }
        guard AXIsProcessTrusted() else {
            problem = "Volume HUD needs Accessibility: allow Brim in System Settings > Privacy & Security."
            return
        }
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let module = Unmanaged<HUDModule>.fromOpaque(info).takeUnretainedValue()
            let consume = MainActor.assumeIsolated { module.handle(type, event) }
            return consume ? nil : Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: 1 << 14, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            problem = "Volume HUD could not install its key tap."
            return
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        tapSource = source
        problem = nil
    }

    private func uninstall() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
    }

    /// Returns true when the event must be swallowed.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        guard type.rawValue == 14, let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8,
              let press = MediaKeyEvent(data1: ns.data1) else { return false }
        if press.down { applied = press.key.isBrightness ? applyBrightness(press.key) : applyVolume(press.key) }
        return applied
    }

    private func show(_ key: HUDKey, level: Float) {
        self.level = level
        symbol = key.symbol(level: level)
        showing = true
        hideWork?.cancel()
        let end = DispatchWorkItem { [weak self] in self?.showing = false }
        hideWork = end
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.showSeconds, execute: end)
    }

    // MARK: Brightness (private DisplayServices; if a symbol is missing the key goes to the system)

    private func applyBrightness(_ key: HUDKey) -> Bool {
        guard let getBrightness, let setBrightness else { return false }
        let display = CGMainDisplayID() // shortcut: main display only; an external main display refuses and the key passes through
        var current: Float = 0
        guard getBrightness(display, &current) == 0 else { return false }
        let new = HUDKey.step(current, up: key.isUp)
        guard setBrightness(display, new) == 0 else { return false }
        show(key, level: new)
        return true
    }

    // MARK: Volume (CoreAudio, default output device)

    private func applyVolume(_ key: HUDKey) -> Bool {
        guard let device: AudioObjectID = Self.read(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal),
              device != 0,
              let volume: Float32 = Self.read(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume) else { return false }
        let muted = (Self.read(device, kAudioDevicePropertyMute) as UInt32?) ?? 0 != 0
        if key == .mute {
            guard Self.write(device, kAudioDevicePropertyMute, UInt32(muted ? 0 : 1)) else { return false }
            show(key, level: muted ? volume : 0)
        } else {
            let new = HUDKey.step(volume, up: key.isUp)
            guard Self.write(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, new) else { return false }
            if muted { _ = Self.write(device, kAudioDevicePropertyMute, UInt32(0)) }
            show(key, level: new)
        }
        return true
    }

    private static func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func read<T: Numeric>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                         _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeOutput) -> T? {
        var a = address(selector, scope)
        var value: T = 0
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func write<T: Numeric>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: T) -> Bool {
        var a = address(selector, kAudioObjectPropertyScopeOutput)
        var settable: DarwinBoolean = false
        var value = value
        guard AudioObjectIsPropertySettable(id, &a, &settable) == noErr, settable.boolValue else { return false }
        return AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<T>.size), &value) == noErr
    }
}
