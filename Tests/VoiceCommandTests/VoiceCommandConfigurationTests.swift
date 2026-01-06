//
//  VoiceCommandConfigurationTests.swift
//  JogPodTests
//
//  Unit tests for VoiceCommandConfiguration.
//

import XCTest
@testable import JogPod

final class VoiceCommandConfigurationTests: XCTestCase {

    // MARK: - Default Configuration Tests

    func testDefaultConfiguration() {
        let config = VoiceCommandConfiguration.default

        XCTAssertTrue(config.customPhrases.isEmpty)
        XCTAssertFalse(config.requireOnDeviceRecognition)
        XCTAssertEqual(config.confidenceThreshold, 0.5)
        XCTAssertTrue(config.usePartialResults)
        XCTAssertNil(config.recognitionTimeout)
        XCTAssertTrue(config.useContextualStrings)
        XCTAssertTrue(config.enableAudioFeedback)
        XCTAssertTrue(config.enableHapticFeedback)
    }

    func testOutdoorConfiguration() {
        let config = VoiceCommandConfiguration.outdoor

        XCTAssertEqual(config.confidenceThreshold, 0.4)
        XCTAssertTrue(config.usePartialResults)
        XCTAssertTrue(config.enableHapticFeedback)
    }

    func testOfflineOnlyConfiguration() {
        let config = VoiceCommandConfiguration.offlineOnly

        XCTAssertTrue(config.requireOnDeviceRecognition)
    }

    // MARK: - Phrase Management Tests

    func testSetPhrase() {
        var config = VoiceCommandConfiguration.default

        config.setPhrase("BEGIN", for: .startWorkout)

        XCTAssertEqual(config.phrase(for: .startWorkout), "BEGIN")
    }

    func testSetPhrase_Normalized() {
        var config = VoiceCommandConfiguration.default

        config.setPhrase("  begin  ", for: .startWorkout)

        // Should be trimmed and uppercased
        XCTAssertEqual(config.phrase(for: .startWorkout), "BEGIN")
    }

    func testPhraseDefaultFallback() {
        let config = VoiceCommandConfiguration.default

        // No custom phrase set, should return default
        XCTAssertEqual(config.phrase(for: .startWorkout), "START WORKOUT")
        XCTAssertEqual(config.phrase(for: .play), "PLAY")
    }

    func testResetPhrase() {
        var config = VoiceCommandConfiguration.default

        config.setPhrase("BEGIN", for: .startWorkout)
        XCTAssertEqual(config.phrase(for: .startWorkout), "BEGIN")

        config.resetPhrase(for: .startWorkout)
        XCTAssertEqual(config.phrase(for: .startWorkout), "START WORKOUT")
    }

    func testResetAllPhrases() {
        var config = VoiceCommandConfiguration.default

        config.setPhrase("BEGIN", for: .startWorkout)
        config.setPhrase("END", for: .stopWorkout)
        config.setPhrase("GO", for: .play)

        XCTAssertEqual(config.customPhrases.count, 3)

        config.resetAllPhrases()

        XCTAssertTrue(config.customPhrases.isEmpty)
        XCTAssertEqual(config.phrase(for: .startWorkout), "START WORKOUT")
    }

    func testAllPhrases() {
        var config = VoiceCommandConfiguration.default
        config.setPhrase("BEGIN", for: .startWorkout)

        let allPhrases = config.allPhrases()

        XCTAssertEqual(allPhrases.count, VoiceCommand.allCases.count)

        // Check custom phrase is included
        let startWorkoutPhrase = allPhrases.first { $0.command == .startWorkout }
        XCTAssertEqual(startWorkoutPhrase?.phrase, "BEGIN")

        // Check default phrases are included
        let playPhrase = allPhrases.first { $0.command == .play }
        XCTAssertEqual(playPhrase?.phrase, "PLAY")
    }

    // MARK: - Validation Tests

    func testValidConfiguration() {
        let config = VoiceCommandConfiguration.default
        let issues = config.validate()

        XCTAssertTrue(issues.isEmpty)
        XCTAssertTrue(config.isValid)
    }

    func testInvalidConfidenceThreshold_TooLow() {
        var config = VoiceCommandConfiguration.default
        config.confidenceThreshold = -0.1

        let issues = config.validate()

        XCTAssertEqual(issues.count, 1)
        XCTAssertFalse(config.isValid)

        if case .invalidConfidenceThreshold(let value) = issues.first {
            XCTAssertEqual(value, -0.1)
        } else {
            XCTFail("Expected invalidConfidenceThreshold issue")
        }
    }

    func testInvalidConfidenceThreshold_TooHigh() {
        var config = VoiceCommandConfiguration.default
        config.confidenceThreshold = 1.5

        let issues = config.validate()

        XCTAssertEqual(issues.count, 1)

        if case .invalidConfidenceThreshold(let value) = issues.first {
            XCTAssertEqual(value, 1.5)
        } else {
            XCTFail("Expected invalidConfidenceThreshold issue")
        }
    }

    func testDuplicatePhrases() {
        var config = VoiceCommandConfiguration.default

        // Set same phrase for two different commands
        config.setPhrase("ACTION", for: .startWorkout)
        config.setPhrase("ACTION", for: .stopWorkout)

        let issues = config.validate()

        XCTAssertEqual(issues.count, 1)

        if case .duplicatePhrase(let phrase, let commands) = issues.first {
            XCTAssertEqual(phrase, "ACTION")
            XCTAssertTrue(commands.contains(.startWorkout))
            XCTAssertTrue(commands.contains(.stopWorkout))
        } else {
            XCTFail("Expected duplicatePhrase issue")
        }
    }

    func testEmptyPhrase() {
        var config = VoiceCommandConfiguration.default
        config.customPhrases[.startWorkout] = ""

        let issues = config.validate()

        XCTAssertEqual(issues.count, 1)

        if case .emptyPhrase(let command) = issues.first {
            XCTAssertEqual(command, .startWorkout)
        } else {
            XCTFail("Expected emptyPhrase issue")
        }
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        var config = VoiceCommandConfiguration.default
        config.setPhrase("BEGIN", for: .startWorkout)
        config.confidenceThreshold = 0.7
        config.requireOnDeviceRecognition = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VoiceCommandConfiguration.self, from: data)

        XCTAssertEqual(decoded.phrase(for: .startWorkout), "BEGIN")
        XCTAssertEqual(decoded.confidenceThreshold, 0.7)
        XCTAssertTrue(decoded.requireOnDeviceRecognition)
    }

    func testEncodeDecodeAllPhrases() throws {
        var config = VoiceCommandConfiguration.default

        // Set custom phrases for all commands
        for command in VoiceCommand.allCases {
            config.setPhrase("CUSTOM_\(command.rawValue.uppercased())", for: command)
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VoiceCommandConfiguration.self, from: data)

        for command in VoiceCommand.allCases {
            XCTAssertEqual(
                decoded.phrase(for: command),
                "CUSTOM_\(command.rawValue.uppercased())"
            )
        }
    }
}
