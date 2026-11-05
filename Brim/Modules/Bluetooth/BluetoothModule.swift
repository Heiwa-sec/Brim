import AppKit
import IOBluetooth

/// Connected Bluetooth devices with battery levels. The compact pill flashes the newest device for a few seconds after
/// it connects; the expanded island lists every connected device.
@MainActor @Observable
final class BluetoothModule: IslandModule {
    static let id = "bluetooth"
    static let flashSeconds = 4.0

    struct Device: Identifiable, Equatable {
        let id: String
        let name: String
        let battery: BluetoothBattery
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
        let new = Device(id: id, name: device.name ?? "Bluetooth device", battery: Self.battery(of: device))
        if let i = devices.firstIndex(where: { $0.id == id }) { devices[i] = new }
        else { devices.append(new); devices.sort { $0.name < $1.name } }
        if disconnectNotifications[id] == nil {
            disconnectNotifications[id] = device.register(forDisconnectNotification: listener, selector: #selector(Listener.disconnected(_:device:)))
        }
        if flash { self.flash(id) }
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

    /// The battery properties are private API: ask `responds(to:)` first, since key-value access to a missing one throws.
    private static func battery(of device: IOBluetoothDevice) -> BluetoothBattery {
        func level(_ key: String) -> Int? {
            guard device.responds(to: NSSelectorFromString(key)) else { return nil }
            return (device.value(forKey: key) as? NSNumber)?.intValue
        }
        return BluetoothBattery(left: level("batteryPercentLeft"), right: level("batteryPercentRight"),
                                caseLevel: level("batteryPercentCase"), single: level("batteryPercentSingle"))
    }
}

/// IOBluetooth delivers notifications through target/selector, which needs an NSObject.
@MainActor
private final class Listener: NSObject {
    let onConnect: (IOBluetoothDevice) -> Void
    let onDisconnect: (IOBluetoothDevice) -> Void

    init(onConnect: @escaping (IOBluetoothDevice) -> Void, onDisconnect: @escaping (IOBluetoothDevice) -> Void) {
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
    }

    @objc func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) { onConnect(device) }
    @objc func disconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) { onDisconnect(device) }
}
