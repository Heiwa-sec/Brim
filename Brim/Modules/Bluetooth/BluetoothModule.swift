import AppKit
import IOBluetooth

/// Connected Bluetooth devices with battery levels. The compact pill flashes the newest device for a few seconds after
/// it connects; the expanded island lists every connected device.
@MainActor @Observable
final class BluetoothModule: IslandModule {
    static let id = "bluetooth"
    static let title = "Bluetooth"
    static let flashSeconds = 4.0

    struct Device: Identifiable, Equatable {
        let id: String
        let name: String
        var battery = BluetoothBattery(left: nil, right: nil, caseLevel: nil, single: nil)
    }

    private(set) var devices: [Device] = []
    private(set) var flashedID: String?

    @ObservationIgnored private var listener: Listener?
    @ObservationIgnored private var connectNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    @ObservationIgnored private var flashEnd: DispatchWorkItem?

    var flashed: Device? { devices.first { $0.id == flashedID } }
    var hasActivity: Bool { flashed != nil }

    func start() {
        let listener = Listener(
            onConnect: { [weak self] in self?.add($0, flash: true) },
            onDisconnect: { [weak self] in self?.remove($0) })
        self.listener = listener
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: listener, selector: #selector(Listener.connected(_:device:)))
        for case let device as IOBluetoothDevice in IOBluetoothDevice.pairedDevices() ?? [] where device.isConnected() {
            add(device, flash: false) // initial state: no flash
        }
    }

    func stop() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications = [:]
        listener = nil
        flashEnd?.cancel()
        flashedID = nil
        devices = []
    }

    private func add(_ device: IOBluetoothDevice, flash: Bool) {
        guard let id = device.addressString, let listener else { return }
        let new = Device(id: id, name: device.name ?? "Bluetooth device", battery: devices.first { $0.id == id }?.battery ?? .init(left: nil, right: nil, caseLevel: nil, single: nil))
        if let i = devices.firstIndex(where: { $0.id == id }) { devices[i] = new }
        else { devices.append(new); devices.sort { $0.name < $1.name } }
        if disconnectNotifications[id] == nil {
            disconnectNotifications[id] = device.register(forDisconnectNotification: listener, selector: #selector(Listener.disconnected(_:device:)))
        }
        if flash { self.flash(id) }
        refreshBatteries()
        // AirPods report their levels a moment after the connect event.
        if flash { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.refreshBatteries() } }
    }

    private func refreshBatteries() {
        Task {
            let data = await Task.detached { Self.profilerOutput() }.value
            let levels = BluetoothBattery.parse(profiler: data)
            for i in devices.indices {
                if let level = levels[devices[i].name], level != devices[i].battery { devices[i].battery = level }
            }
        }
    }

    private nonisolated static func profilerOutput() -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return Data() }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }

    private func remove(_ device: IOBluetoothDevice) {
        guard let id = device.addressString else { return }
        disconnectNotifications.removeValue(forKey: id)?.unregister()
        devices.removeAll { $0.id == id }
    }

    private func flash(_ id: String) {
        flashEnd?.cancel()
        flashedID = id
        let end = DispatchWorkItem { [weak self] in self?.flashedID = nil }
        flashEnd = end
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flashSeconds, execute: end)
    }
}

/// IOBluetooth delivers notifications through target/selector, which needs an NSObject, and calls them on a background
/// thread (it crashed the app on the first real connect), so each one hops to the main actor.
private final class Listener: NSObject, @unchecked Sendable {
    let onConnect: @MainActor (IOBluetoothDevice) -> Void
    let onDisconnect: @MainActor (IOBluetoothDevice) -> Void

    init(onConnect: @escaping @MainActor (IOBluetoothDevice) -> Void, onDisconnect: @escaping @MainActor (IOBluetoothDevice) -> Void) {
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
    }

    @objc func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        nonisolated(unsafe) let device = device
        DispatchQueue.main.async { MainActor.assumeIsolated { self.onConnect(device) } }
    }

    @objc func disconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        nonisolated(unsafe) let device = device
        DispatchQueue.main.async { MainActor.assumeIsolated { self.onDisconnect(device) } }
    }
}
