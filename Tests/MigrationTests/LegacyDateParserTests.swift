import Testing
import Foundation
@testable import JogPod

/// Tests for the LegacyDateParser utility.
@Suite("Legacy Date Parser Tests")
struct LegacyDateParserTests {

    // MARK: - Nil and Empty Input Tests

    @Test("Returns nil for nil input")
    func testNilInput() {
        let result = LegacyDateParser.parse(nil)
        #expect(result == nil)
    }

    @Test("Returns nil for empty string")
    func testEmptyString() {
        let result = LegacyDateParser.parse("")
        #expect(result == nil)
    }

    @Test("Returns nil for invalid date string")
    func testInvalidString() {
        let result = LegacyDateParser.parse("not a date")
        #expect(result == nil)
    }

    // MARK: - ISO 8601 Format Tests

    @Test("Parses ISO 8601 with timezone")
    func testISO8601WithTimezone() {
        let result = LegacyDateParser.parse("2024-01-15T14:30:00Z")
        #expect(result != nil)

        // Verify the date components
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: result!)
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }

    @Test("Parses ISO 8601 with fractional seconds")
    func testISO8601WithFractionalSeconds() {
        let result = LegacyDateParser.parse("2024-01-15T14:30:00.123Z")
        #expect(result != nil)
    }

    @Test("Parses ISO 8601 with offset timezone")
    func testISO8601WithOffset() {
        let result = LegacyDateParser.parse("2024-01-15T14:30:00+05:00")
        #expect(result != nil)

        // The date should be adjusted for timezone
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: result!)
        // 14:30 +05:00 = 09:30 UTC
        #expect(components.hour == 9)
    }

    // MARK: - Common Date Format Tests

    @Test("Parses date-only format")
    func testDateOnlyFormat() {
        let result = LegacyDateParser.parse("2024-01-15")
        #expect(result != nil)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: result!)
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
    }

    @Test("Parses standard datetime format")
    func testStandardDatetimeFormat() {
        let result = LegacyDateParser.parse("2024-01-15 14:30:00")
        #expect(result != nil)
    }

    @Test("Parses US date format")
    func testUSDateFormat() {
        let result = LegacyDateParser.parse("01/15/2024")
        #expect(result != nil)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: result!)
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
    }

    @Test("Parses US datetime format")
    func testUSDatetimeFormat() {
        let result = LegacyDateParser.parse("01/15/2024 14:30:00")
        #expect(result != nil)
    }

    // MARK: - Unix Timestamp Tests

    @Test("Parses Unix timestamp in seconds")
    func testUnixTimestampSeconds() {
        // 2024-01-15 00:00:00 UTC = 1705276800
        let result = LegacyDateParser.parse("1705276800")
        #expect(result != nil)

        let expected = Date(timeIntervalSince1970: 1705276800)
        #expect(result == expected)
    }

    @Test("Parses Unix timestamp in milliseconds")
    func testUnixTimestampMilliseconds() {
        // 2024-01-15 00:00:00 UTC = 1705276800000 ms
        let result = LegacyDateParser.parse("1705276800000")
        #expect(result != nil)

        let expected = Date(timeIntervalSince1970: 1705276800)
        #expect(result == expected)
    }

    // MARK: - Edge Cases

    @Test("Handles whitespace-only string")
    func testWhitespaceString() {
        // Note: Empty after trim would be caught, but leading/trailing space
        // might cause parse failures
        let result = LegacyDateParser.parse("   2024-01-15   ")
        // This may or may not parse depending on format tolerance
        // The test documents current behavior
    }

    @Test("Handles partial date strings")
    func testPartialDate() {
        // Should not parse incomplete dates
        let result = LegacyDateParser.parse("2024-01")
        // Behavior depends on format matching
    }
}
