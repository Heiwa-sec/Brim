import Foundation

/// Current conditions from an Open-Meteo `forecast` response. Pure, so the code mapping and URL are testable.
struct WeatherInfo: Equatable {
    /// Degrees Celsius, as Open-Meteo returns it; formatted for the user's locale in the view.
    let celsius: Double
    let symbol: String
    let description: String

    static let cacheSeconds: TimeInterval = 30 * 60

    /// Nil when the body is not a `current` block with both fields.
    init?(json data: Data) {
        struct Response: Decodable {
            struct Current: Decodable { let temperature_2m: Double; let weather_code: Int }
            let current: Current
        }
        guard let current = (try? JSONDecoder().decode(Response.self, from: data))?.current else { return nil }
        celsius = current.temperature_2m
        (symbol, description) = Self.condition(wmo: current.weather_code)
    }

    /// Coordinates are rounded to one decimal (about 11 km) so the server never learns a precise position.
    static func url(latitude: Double, longitude: Double) -> URL {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.1f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.1f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
        ]
        return c.url!
    }

    /// WMO weather interpretation codes as used by Open-Meteo.
    static func condition(wmo code: Int) -> (symbol: String, description: String) {
        switch code {
        case 0: ("sun.max", "Clear")
        case 1: ("sun.max", "Mainly clear")
        case 2: ("cloud.sun", "Partly cloudy")
        case 3: ("cloud", "Overcast")
        case 45, 48: ("cloud.fog", "Fog")
        case 51, 53, 55, 56, 57: ("cloud.drizzle", "Drizzle")
        case 61, 63, 66, 80, 81: ("cloud.rain", "Rain")
        case 65, 67, 82: ("cloud.heavyrain", "Heavy rain")
        case 71, 73, 75, 77, 85, 86: ("cloud.snow", "Snow")
        case 95: ("cloud.bolt", "Thunderstorm")
        case 96, 99: ("cloud.bolt.rain", "Thunderstorm with hail")
        default: ("cloud", "Unknown conditions")
        }
    }
}
