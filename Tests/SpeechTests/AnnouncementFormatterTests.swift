//
//  AnnouncementFormatterTests.swift
//  JogPodTests
//
//  Tests for AnnouncementFormatter - verifying legacy format equivalence.
//

import Testing
@testable import JogPod

@Suite("AnnouncementFormatter Tests")
struct AnnouncementFormatterTests {

    // MARK: - Speed Announcements

    @Test("Current speed format - imperial")
    func testCurrentSpeedImperial() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        // 2.3 m/s = 5.14 mph
        let data = AnnouncementData(currentSpeed: 2.3)

        let result = formatter.format(.currentSpeed, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Current speed"))
        #expect(result!.contains("miles per hour"))
        #expect(result!.contains("5.1")) // Rounded to 1 decimal
    }

    @Test("Current speed format - metric")
    func testCurrentSpeedMetric() {
        let formatter = AnnouncementFormatter(unitSystem: .metric)
        // 2.3 m/s = 8.28 km/h
        let data = AnnouncementData(currentSpeed: 2.3)

        let result = formatter.format(.currentSpeed, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Current speed"))
        #expect(result!.contains("kilometers per hour"))
        #expect(result!.contains("8.3")) // Rounded to 1 decimal
    }

    @Test("Average speed format - imperial")
    func testAverageSpeedImperial() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(averageSpeed: 3.0) // 6.7 mph

        let result = formatter.format(.averageSpeed, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Average speed"))
        #expect(result!.contains("miles per hour"))
    }

    @Test("Average speed format - metric")
    func testAverageSpeedMetric() {
        let formatter = AnnouncementFormatter(unitSystem: .metric)
        let data = AnnouncementData(averageSpeed: 3.0) // 10.8 km/h

        let result = formatter.format(.averageSpeed, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Average speed"))
        #expect(result!.contains("kilometers per hour"))
    }

    // MARK: - Heart Rate Announcements

    @Test("Current heart rate format")
    func testCurrentHeartRate() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(currentHeartRate: 142)

        let result = formatter.format(.currentHeartRate, data: data)

        #expect(result != nil)
        #expect(result == "Heart rate 142")
    }

    @Test("Current heart rate returns nil when zero")
    func testCurrentHeartRateZero() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(currentHeartRate: 0)

        let result = formatter.format(.currentHeartRate, data: data)

        #expect(result == nil)
    }

    @Test("Average heart rate format")
    func testAverageHeartRate() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(averageHeartRate: 135)

        let result = formatter.format(.averageHeartRate, data: data)

        #expect(result != nil)
        #expect(result == "Average heart rate 135")
    }

    @Test("Average heart rate returns nil when zero")
    func testAverageHeartRateZero() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(averageHeartRate: 0)

        let result = formatter.format(.averageHeartRate, data: data)

        #expect(result == nil)
    }

    // MARK: - Distance Announcements

    @Test("Distance format - imperial")
    func testDistanceImperial() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        // 5000 meters = 3.1 miles
        let data = AnnouncementData(distance: 5000)

        let result = formatter.format(.distance, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Distance"))
        #expect(result!.contains("miles"))
        #expect(result!.contains("3.1"))
    }

    @Test("Distance format - metric")
    func testDistanceMetric() {
        let formatter = AnnouncementFormatter(unitSystem: .metric)
        // 5000 meters = 5.0 km
        let data = AnnouncementData(distance: 5000)

        let result = formatter.format(.distance, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Distance"))
        #expect(result!.contains("kilometers"))
        #expect(result!.contains("5.0"))
    }

    // MARK: - Elevation Announcements

    @Test("Total ascent format - imperial")
    func testTotalAscentImperial() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        // 50 meters = 164 feet
        let data = AnnouncementData(totalAscent: 50)

        let result = formatter.format(.totalAscent, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Uphill"))
        #expect(result!.contains("feet"))
        #expect(result!.contains("164"))
    }

    @Test("Total ascent format - metric")
    func testTotalAscentMetric() {
        let formatter = AnnouncementFormatter(unitSystem: .metric)
        let data = AnnouncementData(totalAscent: 50)

        let result = formatter.format(.totalAscent, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Uphill"))
        #expect(result!.contains("meters"))
        #expect(result!.contains("50"))
    }

    @Test("Total descent format - imperial")
    func testTotalDescentImperial() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(totalDescent: 30) // ~98 feet

        let result = formatter.format(.totalDescent, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Downhill"))
        #expect(result!.contains("feet"))
    }

    @Test("Total descent format - metric")
    func testTotalDescentMetric() {
        let formatter = AnnouncementFormatter(unitSystem: .metric)
        let data = AnnouncementData(totalDescent: 30)

        let result = formatter.format(.totalDescent, data: data)

        #expect(result != nil)
        #expect(result!.starts(with: "Downhill"))
        #expect(result!.contains("meters"))
    }

    // MARK: - Other Metrics

    @Test("Calories burned format")
    func testCaloriesBurned() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(caloriesBurned: 350)

        let result = formatter.format(.caloriesBurned, data: data)

        #expect(result != nil)
        #expect(result == "Calories burned 350")
    }

    @Test("Duration format")
    func testDuration() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        // 25 minutes = 1500 seconds
        let data = AnnouncementData(duration: 1500)

        let result = formatter.format(.duration, data: data)

        #expect(result != nil)
        #expect(result == "Duration 25 minutes")
    }

    // MARK: - Weather Announcements

    @Test("Temperature format - imperial")
    func testTemperatureImperial() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let weather = WeatherData(temperature: 72)
        let data = AnnouncementData(weather: weather)

        let result = formatter.format(.temperature, data: data)

        #expect(result != nil)
        #expect(result!.contains("Temperature"))
        #expect(result!.contains("72"))
        #expect(result!.contains("FAHRENHEIT"))
    }

    @Test("Temperature format - metric")
    func testTemperatureMetric() {
        let formatter = AnnouncementFormatter(unitSystem: .metric)
        let weather = WeatherData(temperature: 22)
        let data = AnnouncementData(weather: weather)

        let result = formatter.format(.temperature, data: data)

        #expect(result != nil)
        #expect(result!.contains("Temperature"))
        #expect(result!.contains("22"))
        #expect(result!.contains("CELSIUS"))
    }

    @Test("Temperature returns nil when not available")
    func testTemperatureNil() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(weather: nil)

        let result = formatter.format(.temperature, data: data)

        #expect(result == nil)
    }

    @Test("Temperature returns nil when zero")
    func testTemperatureZero() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let weather = WeatherData(temperature: 0)
        let data = AnnouncementData(weather: weather)

        let result = formatter.format(.temperature, data: data)

        #expect(result == nil)
    }

    @Test("Humidity format")
    func testHumidity() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let weather = WeatherData(humidity: 65)
        let data = AnnouncementData(weather: weather)

        let result = formatter.format(.humidity, data: data)

        #expect(result != nil)
        #expect(result!.contains("Humidity"))
        #expect(result!.contains("65"))
        #expect(result!.contains("percent"))
    }

    @Test("Wind speed format")
    func testWindSpeed() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let weather = WeatherData(windSpeed: 12)
        let data = AnnouncementData(weather: weather)

        let result = formatter.format(.windSpeed, data: data)

        #expect(result != nil)
        #expect(result!.contains("Wind speed"))
        #expect(result!.contains("12"))
    }

    // MARK: - Format All

    @Test("Format all with enabled types")
    func testFormatAll() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(
            currentSpeed: 2.0,
            averageSpeed: 2.5,
            distance: 3000,
            caloriesBurned: 200,
            duration: 1200
        )

        let enabled: Set<AnnouncementType> = [.currentSpeed, .distance, .caloriesBurned]
        let results = formatter.formatAll(data: data, enabled: enabled)

        #expect(results.count == 3)
        #expect(results.contains { $0.contains("Current speed") })
        #expect(results.contains { $0.contains("Distance") })
        #expect(results.contains { $0.contains("Calories") })
    }

    @Test("Format all skips nil values")
    func testFormatAllSkipsNil() {
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(
            currentSpeed: 2.0,
            currentHeartRate: 0 // Zero = nil announcement
        )

        let enabled: Set<AnnouncementType> = [.currentSpeed, .currentHeartRate]
        let results = formatter.formatAll(data: data, enabled: enabled)

        #expect(results.count == 1)
        #expect(results.first?.contains("Current speed") == true)
    }

    // MARK: - Legacy Format String Equivalence

    @Test("Legacy format equivalence - speed imperial")
    func testLegacyFormatSpeedImperial() {
        // Legacy: @"Current speed %0.1f %@" with "miles per hour"
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(currentSpeed: 2.3) // 5.14 mph

        let result = formatter.format(.currentSpeed, data: data)

        // Should match: "Current speed 5.1 miles per hour"
        #expect(result == "Current speed 5.1 miles per hour")
    }

    @Test("Legacy format equivalence - speed metric")
    func testLegacyFormatSpeedMetric() {
        // Legacy: @"Current speed %0.1f %@" with "kilometers per hour"
        let formatter = AnnouncementFormatter(unitSystem: .metric)
        let data = AnnouncementData(currentSpeed: 2.3) // 8.28 km/h

        let result = formatter.format(.currentSpeed, data: data)

        // Should match: "Current speed 8.3 kilometers per hour"
        #expect(result == "Current speed 8.3 kilometers per hour")
    }

    @Test("Legacy format equivalence - heart rate")
    func testLegacyFormatHeartRate() {
        // Legacy: @"Heart rate %d"
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(currentHeartRate: 142)

        let result = formatter.format(.currentHeartRate, data: data)

        #expect(result == "Heart rate 142")
    }

    @Test("Legacy format equivalence - calories")
    func testLegacyFormatCalories() {
        // Legacy: @"Calories burned %d"
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(caloriesBurned: 350)

        let result = formatter.format(.caloriesBurned, data: data)

        #expect(result == "Calories burned 350")
    }

    @Test("Legacy format equivalence - duration")
    func testLegacyFormatDuration() {
        // Legacy: @"Duration %.0f minutes"
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(duration: 1500) // 25 minutes

        let result = formatter.format(.duration, data: data)

        #expect(result == "Duration 25 minutes")
    }

    @Test("Legacy format equivalence - uphill imperial")
    func testLegacyFormatUphillImperial() {
        // Legacy: @"Uphill %.0f %@" with "feet"
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let data = AnnouncementData(totalAscent: 50) // ~164 feet

        let result = formatter.format(.totalAscent, data: data)

        #expect(result == "Uphill 164 feet")
    }

    @Test("Legacy format equivalence - uphill metric")
    func testLegacyFormatUphillMetric() {
        // Legacy: @"Uphill %.0f %@" with "meters"
        let formatter = AnnouncementFormatter(unitSystem: .metric)
        let data = AnnouncementData(totalAscent: 50)

        let result = formatter.format(.totalAscent, data: data)

        #expect(result == "Uphill 50 meters")
    }

    @Test("Legacy format equivalence - temperature imperial")
    func testLegacyFormatTemperatureImperial() {
        // Legacy: @"Temperature %.0f %@" with "FAHRENHEIT"
        let formatter = AnnouncementFormatter(unitSystem: .imperial)
        let weather = WeatherData(temperature: 72)
        let data = AnnouncementData(weather: weather)

        let result = formatter.format(.temperature, data: data)

        #expect(result == "Temperature 72 FAHRENHEIT")
    }
}

@Suite("WeatherData Tests")
struct WeatherDataTests {

    @Test("Has temperature when valid")
    func testHasTemperature() {
        let weather1 = WeatherData(temperature: 72)
        #expect(weather1.hasTemperature)

        let weather2 = WeatherData(temperature: 0)
        #expect(!weather2.hasTemperature)

        let weather3 = WeatherData(temperature: nil)
        #expect(!weather3.hasTemperature)
    }
}
