import XCTest

final class WeatherInfoTests: XCTestCase {
    func testParsesCurrentBlock() throws {
        let json = Data(#"{"current":{"time":"2026-11-05T10:00","temperature_2m":12.3,"weather_code":61}}"#.utf8)
        let info = try XCTUnwrap(WeatherInfo(json: json))
        XCTAssertEqual(info.celsius, 12.3)
        XCTAssertEqual(info.symbol, "cloud.rain")
        XCTAssertEqual(info.description, "Rain")
    }

    func testRejectsMalformedBody() {
        XCTAssertNil(WeatherInfo(json: Data(#"{"error":true}"#.utf8)))
        XCTAssertNil(WeatherInfo(json: Data(#"{"current":{"temperature_2m":1.0}}"#.utf8)))
    }

    func testCodeMapping() {
        XCTAssertEqual(WeatherInfo.condition(wmo: 0).symbol, "sun.max")
        XCTAssertEqual(WeatherInfo.condition(wmo: 95).description, "Thunderstorm")
        XCTAssertEqual(WeatherInfo.condition(wmo: 12345).description, "Unknown conditions")
    }

    func testURLRoundsCoordinatesAndNamesHost() {
        let url = WeatherInfo.url(latitude: 37.77493, longitude: -122.41942)
        XCTAssertEqual(url.host, "api.open-meteo.com")
        let query = url.query ?? ""
        XCTAssertTrue(query.contains("latitude=37.8"))
        XCTAssertTrue(query.contains("longitude=-122.4"))
        XCTAssertTrue(query.contains("current=temperature_2m,weather_code"))
    }
}
