import AppKit
import CoreLocation

/// Current weather for the Mac's approximate location (reduced accuracy). Off by default. Only a location update
/// or a wake from sleep with a stale cache triggers a fetch; nothing polls.
@MainActor @Observable
final class WeatherModule: NSObject, IslandModule, CLLocationManagerDelegate {
    static let id = "weather"
    static let defaultEnabled = false

    private(set) var info: WeatherInfo?
    private(set) var problem: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var fetched: Date?
    @ObservationIgnored private var fetch: Task<Void, Never>?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshIfStale() }
        }
        authorizationChanged()
    }

    func stop() {
        manager.delegate = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        fetch?.cancel()
        fetch = nil
        fetched = nil
        info = nil
        problem = nil
    }

    private func authorizationChanged() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: problem = "Weather needs Location access (System Settings > Privacy & Security)"
        default: problem = nil; refreshIfStale()
        }
    }

    private func refreshIfStale() {
        // Without access requestLocation only fails and would overwrite the permission message.
        guard [.authorizedAlways, .authorized].contains(manager.authorizationStatus) else { return }
        if let fetched, Date.now.timeIntervalSince(fetched) < WeatherInfo.cacheSeconds { return }
        manager.requestLocation()
    }

    private func load(latitude: Double, longitude: Double) {
        fetch?.cancel()
        fetch = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: WeatherInfo.url(latitude: latitude, longitude: longitude))
                guard !Task.isCancelled else { return }
                guard let parsed = WeatherInfo(json: data) else { throw URLError(.cannotParseResponse) }
                info = parsed
                fetched = .now
                problem = nil
            } catch {
                if !Task.isCancelled { problem = "Weather unavailable" }
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated { authorizationChanged() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        MainActor.assumeIsolated { load(latitude: c.latitude, longitude: c.longitude) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { problem = "Couldn't get your location" }
    }
}
