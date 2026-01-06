//
//  VoiceCommandTests.swift
//  JogPodTests
//
//  Unit tests for VoiceCommand enum.
//

import XCTest
@testable import JogPod

final class VoiceCommandTests: XCTestCase {

    // MARK: - All Cases Tests

    func testAllCasesCount() {
        // Ensure we have all expected commands
        XCTAssertEqual(VoiceCommand.allCases.count, 12)
    }

    func testAllCasesContainsLegacyCommands() {
        // These are the commands from the legacy OpenEars implementation
        let legacyCommands: [VoiceCommand] = [
            .startWorkout,
            .stopWorkout,
            .play,
            .pause,
            .next,
            .previous,
            .fastForward,
            .rewind,
            .stopListening,
            .announceMetrics
        ]

        for command in legacyCommands {
            XCTAssertTrue(VoiceCommand.allCases.contains(command))
        }
    }

    // MARK: - Category Tests

    func testWorkoutCategory() {
        XCTAssertEqual(VoiceCommand.startWorkout.category, .workout)
        XCTAssertEqual(VoiceCommand.stopWorkout.category, .workout)
    }

    func testMediaCategory() {
        XCTAssertEqual(VoiceCommand.play.category, .media)
        XCTAssertEqual(VoiceCommand.pause.category, .media)
        XCTAssertEqual(VoiceCommand.next.category, .media)
        XCTAssertEqual(VoiceCommand.previous.category, .media)
        XCTAssertEqual(VoiceCommand.fastForward.category, .media)
        XCTAssertEqual(VoiceCommand.rewind.category, .media)
    }

    func testSystemCategory() {
        XCTAssertEqual(VoiceCommand.stopListening.category, .system)
        XCTAssertEqual(VoiceCommand.announceMetrics.category, .system)
    }

    func testVolumeCategory() {
        XCTAssertEqual(VoiceCommand.volumeUp.category, .volume)
        XCTAssertEqual(VoiceCommand.volumeDown.category, .volume)
    }

    // MARK: - Default Phrase Tests

    func testDefaultPhrases() {
        XCTAssertEqual(VoiceCommand.startWorkout.defaultPhrase, "START WORKOUT")
        XCTAssertEqual(VoiceCommand.stopWorkout.defaultPhrase, "STOP WORKOUT")
        XCTAssertEqual(VoiceCommand.play.defaultPhrase, "PLAY")
        XCTAssertEqual(VoiceCommand.pause.defaultPhrase, "PAUSE")
        XCTAssertEqual(VoiceCommand.next.defaultPhrase, "NEXT")
        XCTAssertEqual(VoiceCommand.previous.defaultPhrase, "PREVIOUS")
        XCTAssertEqual(VoiceCommand.fastForward.defaultPhrase, "FAST FORWARD")
        XCTAssertEqual(VoiceCommand.rewind.defaultPhrase, "REWIND")
        XCTAssertEqual(VoiceCommand.stopListening.defaultPhrase, "STOP LISTENING")
        XCTAssertEqual(VoiceCommand.announceMetrics.defaultPhrase, "METRICS")
        XCTAssertEqual(VoiceCommand.volumeUp.defaultPhrase, "LOUDER")
        XCTAssertEqual(VoiceCommand.volumeDown.defaultPhrase, "SOFTER")
    }

    func testDefaultPhrasesAreUppercase() {
        for command in VoiceCommand.allCases {
            XCTAssertEqual(
                command.defaultPhrase,
                command.defaultPhrase.uppercased(),
                "\(command) default phrase should be uppercase"
            )
        }
    }

    // MARK: - Action Description Tests

    func testActionDescriptions() {
        for command in VoiceCommand.allCases {
            XCTAssertFalse(
                command.actionDescription.isEmpty,
                "\(command) should have an action description"
            )
        }
    }

    // MARK: - Raw Value Tests

    func testRawValues() {
        XCTAssertEqual(VoiceCommand.startWorkout.rawValue, "start_workout")
        XCTAssertEqual(VoiceCommand.stopWorkout.rawValue, "stop_workout")
        XCTAssertEqual(VoiceCommand.play.rawValue, "play")
        XCTAssertEqual(VoiceCommand.pause.rawValue, "pause")
    }

    func testRawValueRoundTrip() {
        for command in VoiceCommand.allCases {
            let reconstructed = VoiceCommand(rawValue: command.rawValue)
            XCTAssertEqual(reconstructed, command)
        }
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        let commands = VoiceCommand.allCases

        let encoder = JSONEncoder()
        let data = try encoder.encode(commands)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([VoiceCommand].self, from: data)

        XCTAssertEqual(decoded, commands)
    }
}

// MARK: - CommandCategory Tests

final class CommandCategoryTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(CommandCategory.allCases.count, 4)
    }

    func testTitles() {
        XCTAssertEqual(CommandCategory.workout.title, "Workout")
        XCTAssertEqual(CommandCategory.media.title, "Media")
        XCTAssertEqual(CommandCategory.system.title, "System")
        XCTAssertEqual(CommandCategory.volume.title, "Volume")
    }
}

// MARK: - VoiceCommandResult Tests

final class VoiceCommandResultTests: XCTestCase {

    func testInitialization() {
        let result = VoiceCommandResult(
            command: .play,
            confidence: 0.95,
            transcription: "PLAY"
        )

        XCTAssertEqual(result.command, .play)
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.transcription, "PLAY")
    }

    func testIsConfident_HighConfidence() {
        let result = VoiceCommandResult(
            command: .play,
            confidence: 0.8,
            transcription: "PLAY"
        )

        XCTAssertTrue(result.isConfident)
    }

    func testIsConfident_LowConfidence() {
        let result = VoiceCommandResult(
            command: .play,
            confidence: 0.3,
            transcription: "PLAY"
        )

        XCTAssertFalse(result.isConfident)
    }

    func testIsConfident_Threshold() {
        // Exactly at threshold
        let result = VoiceCommandResult(
            command: .play,
            confidence: 0.5,
            transcription: "PLAY"
        )

        XCTAssertTrue(result.isConfident)
    }

    func testEquality() {
        let timestamp = Date()

        let result1 = VoiceCommandResult(
            command: .play,
            confidence: 0.95,
            transcription: "PLAY",
            timestamp: timestamp
        )

        let result2 = VoiceCommandResult(
            command: .play,
            confidence: 0.95,
            transcription: "PLAY",
            timestamp: timestamp
        )

        XCTAssertEqual(result1, result2)
    }

    func testInequality_DifferentCommand() {
        let timestamp = Date()

        let result1 = VoiceCommandResult(
            command: .play,
            confidence: 0.95,
            transcription: "PLAY",
            timestamp: timestamp
        )

        let result2 = VoiceCommandResult(
            command: .pause,
            confidence: 0.95,
            transcription: "PAUSE",
            timestamp: timestamp
        )

        XCTAssertNotEqual(result1, result2)
    }
}
