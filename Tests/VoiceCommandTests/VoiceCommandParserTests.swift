//
//  VoiceCommandParserTests.swift
//  JogPodTests
//
//  Unit tests for VoiceCommandParser.
//  These tests verify command recognition without requiring microphone access.
//

import XCTest
@testable import JogPod

/// Tests for the VoiceCommandParser.
///
/// These tests verify the command parsing logic in isolation from the
/// speech recognition system. This enables:
///
/// - Testing in CI environments without microphone access
/// - Fast, deterministic test execution
/// - Complete coverage of matching edge cases
///
final class VoiceCommandParserTests: XCTestCase {

    // MARK: - Properties

    private var parser: VoiceCommandParser!
    private var configuration: VoiceCommandConfiguration!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        configuration = .default
        parser = VoiceCommandParser(configuration: configuration)
    }

    override func tearDown() {
        parser = nil
        configuration = nil
        super.tearDown()
    }

    // MARK: - Exact Match Tests

    func testExactMatch_StartWorkout() {
        let result = parser.parse(transcription: "START WORKOUT")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
        XCTAssertEqual(result?.confidence, 1.0)
    }

    func testExactMatch_StopWorkout() {
        let result = parser.parse(transcription: "STOP WORKOUT")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .stopWorkout)
    }

    func testExactMatch_Play() {
        let result = parser.parse(transcription: "PLAY")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .play)
    }

    func testExactMatch_Pause() {
        let result = parser.parse(transcription: "PAUSE")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .pause)
    }

    func testExactMatch_Next() {
        let result = parser.parse(transcription: "NEXT")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .next)
    }

    func testExactMatch_Previous() {
        let result = parser.parse(transcription: "PREVIOUS")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .previous)
    }

    func testExactMatch_FastForward() {
        let result = parser.parse(transcription: "FAST FORWARD")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .fastForward)
    }

    func testExactMatch_Rewind() {
        let result = parser.parse(transcription: "REWIND")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .rewind)
    }

    func testExactMatch_StopListening() {
        let result = parser.parse(transcription: "STOP LISTENING")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .stopListening)
    }

    func testExactMatch_Metrics() {
        let result = parser.parse(transcription: "METRICS")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .announceMetrics)
    }

    func testExactMatch_VolumeUp() {
        let result = parser.parse(transcription: "LOUDER")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .volumeUp)
    }

    func testExactMatch_VolumeDown() {
        let result = parser.parse(transcription: "SOFTER")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .volumeDown)
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitive_LowerCase() {
        let result = parser.parse(transcription: "start workout")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    func testCaseInsensitive_MixedCase() {
        let result = parser.parse(transcription: "Start Workout")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    func testCaseInsensitive_RandomCase() {
        let result = parser.parse(transcription: "sTaRt WoRkOuT")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    // MARK: - Whitespace Handling Tests

    func testWhitespace_LeadingTrailing() {
        let result = parser.parse(transcription: "   START WORKOUT   ")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    func testWhitespace_MultipleSpaces() {
        let result = parser.parse(transcription: "START    WORKOUT")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    func testWhitespace_TabsAndNewlines() {
        let result = parser.parse(transcription: "START\tWORKOUT\n")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    // MARK: - Contains Match Tests

    func testContainsMatch_CommandWithContext() {
        let result = parser.parse(transcription: "Please start workout now")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
        // Confidence should be reduced for contains match
        XCTAssertLessThan(result?.confidence ?? 1.0, 1.0)
    }

    func testContainsMatch_CommandAtEnd() {
        let result = parser.parse(transcription: "I want to start workout")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    func testContainsMatch_CommandAtStart() {
        let result = parser.parse(transcription: "Start workout please")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    // MARK: - No Match Tests

    func testNoMatch_EmptyString() {
        let result = parser.parse(transcription: "")

        XCTAssertNil(result)
    }

    func testNoMatch_WhitespaceOnly() {
        let result = parser.parse(transcription: "   \t\n   ")

        XCTAssertNil(result)
    }

    func testNoMatch_UnrelatedText() {
        let result = parser.parse(transcription: "The weather is nice today")

        XCTAssertNil(result)
    }

    func testNoMatch_PartialCommand() {
        let result = parser.parse(transcription: "START")

        // "START" alone should not match "START WORKOUT"
        XCTAssertNil(result)
    }

    // MARK: - Custom Phrase Tests

    func testCustomPhrase_Override() {
        var customConfig = VoiceCommandConfiguration.default
        customConfig.setPhrase("BEGIN EXERCISE", for: .startWorkout)

        let customParser = VoiceCommandParser(configuration: customConfig)

        // Custom phrase should work
        let result1 = customParser.parse(transcription: "BEGIN EXERCISE")
        XCTAssertNotNil(result1)
        XCTAssertEqual(result1?.command, .startWorkout)

        // Original phrase should not work
        let result2 = customParser.parse(transcription: "START WORKOUT")
        XCTAssertNil(result2)
    }

    func testCustomPhrase_MultipleOverrides() {
        var customConfig = VoiceCommandConfiguration.default
        customConfig.setPhrase("BEGIN", for: .startWorkout)
        customConfig.setPhrase("END", for: .stopWorkout)
        customConfig.setPhrase("GO", for: .play)
        customConfig.setPhrase("HOLD", for: .pause)

        let customParser = VoiceCommandParser(configuration: customConfig)

        XCTAssertEqual(customParser.parse(transcription: "BEGIN")?.command, .startWorkout)
        XCTAssertEqual(customParser.parse(transcription: "END")?.command, .stopWorkout)
        XCTAssertEqual(customParser.parse(transcription: "GO")?.command, .play)
        XCTAssertEqual(customParser.parse(transcription: "HOLD")?.command, .pause)
    }

    // MARK: - Fuzzy Match Tests

    func testFuzzyMatch_SingleTypo() {
        let fuzzyParser = VoiceCommandParser(
            configuration: configuration,
            useFuzzyMatching: true,
            maxEditDistance: 2
        )

        // "STATR WORKOUT" has 1 edit (typo in START)
        let result = fuzzyParser.parse(transcription: "STATR WORKOUT")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
        // Confidence should be reduced for fuzzy match
        XCTAssertLessThan(result?.confidence ?? 1.0, 1.0)
    }

    func testFuzzyMatch_TwoTypos() {
        let fuzzyParser = VoiceCommandParser(
            configuration: configuration,
            useFuzzyMatching: true,
            maxEditDistance: 2
        )

        // "STRAT WORKUT" has 2 edits
        let result = fuzzyParser.parse(transcription: "STRAT WORKUT")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    func testFuzzyMatch_ExceedsMaxDistance() {
        let fuzzyParser = VoiceCommandParser(
            configuration: configuration,
            useFuzzyMatching: true,
            maxEditDistance: 2
        )

        // "XXXXX WORKOUT" has more than 2 edits in "START"
        let result = fuzzyParser.parse(transcription: "XXXXX WORKOUT")

        XCTAssertNil(result)
    }

    func testFuzzyMatch_Disabled() {
        // Default parser has fuzzy matching disabled
        let result = parser.parse(transcription: "STATR WORKOUT")

        XCTAssertNil(result)
    }

    // MARK: - Punctuation Handling Tests

    func testPunctuation_Exclamation() {
        let result = parser.parse(transcription: "PLAY!")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .play)
    }

    func testPunctuation_Period() {
        let result = parser.parse(transcription: "PAUSE.")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .pause)
    }

    func testPunctuation_Question() {
        let result = parser.parse(transcription: "NEXT?")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .next)
    }

    func testPunctuation_MixedPunctuation() {
        let result = parser.parse(transcription: "START... WORKOUT!!")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.command, .startWorkout)
    }

    // MARK: - Confidence Tests

    func testConfidence_PreservedOnExactMatch() {
        let result = parser.parse(transcription: "PLAY", confidence: 0.95)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.confidence, 0.95)
    }

    func testConfidence_ReducedOnContainsMatch() {
        let result = parser.parse(transcription: "Can you play please", confidence: 0.95)

        XCTAssertNotNil(result)
        XCTAssertLessThan(result?.confidence ?? 1.0, 0.95)
    }

    // MARK: - Convenience Method Tests

    func testIsCommand_Valid() {
        XCTAssertTrue(parser.isCommand("PLAY"))
        XCTAssertTrue(parser.isCommand("PAUSE"))
        XCTAssertTrue(parser.isCommand("START WORKOUT"))
    }

    func testIsCommand_Invalid() {
        XCTAssertFalse(parser.isCommand("HELLO"))
        XCTAssertFalse(parser.isCommand(""))
        XCTAssertFalse(parser.isCommand("RANDOM TEXT"))
    }

    func testCommandFrom_Valid() {
        XCTAssertEqual(parser.command(from: "PLAY"), .play)
        XCTAssertEqual(parser.command(from: "PAUSE"), .pause)
        XCTAssertEqual(parser.command(from: "NEXT"), .next)
    }

    func testCommandFrom_Invalid() {
        XCTAssertNil(parser.command(from: "HELLO"))
        XCTAssertNil(parser.command(from: ""))
    }

    // MARK: - All Matches Tests

    func testParseAllMatches_SingleExactMatch() {
        let matches = parser.parseAllMatches(transcription: "PLAY")

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.command, .play)
    }

    func testParseAllMatches_Empty() {
        let matches = parser.parseAllMatches(transcription: "HELLO WORLD")

        XCTAssertTrue(matches.isEmpty)
    }

    func testParseAllMatches_SortedByConfidence() {
        // Create config where "PLAY" might partially match multiple commands
        var customConfig = VoiceCommandConfiguration.default
        customConfig.setPhrase("PLAY NOW", for: .play)
        customConfig.setPhrase("PLAY LATER", for: .pause) // Unusual but for testing

        let customParser = VoiceCommandParser(configuration: customConfig)
        let matches = customParser.parseAllMatches(transcription: "PLAY NOW")

        XCTAssertGreaterThanOrEqual(matches.count, 1)
        // First match should be exact
        XCTAssertEqual(matches.first?.command, .play)
    }

    // MARK: - Legacy Command Compatibility Tests

    /// Tests that all legacy OpenEars commands are recognized with default phrases.
    func testLegacyCommandCompatibility() {
        // These match the legacy kStartWorkoutText etc. defaults
        let legacyCommands: [(phrase: String, expected: VoiceCommand)] = [
            ("START WORKOUT", .startWorkout),
            ("STOP WORKOUT", .stopWorkout),
            ("PLAY", .play),
            ("PAUSE", .pause),
            ("NEXT", .next),
            ("PREVIOUS", .previous),
            ("FAST FORWARD", .fastForward),
            ("REWIND", .rewind),
            ("STOP LISTENING", .stopListening),
            ("METRICS", .announceMetrics)
        ]

        for (phrase, expected) in legacyCommands {
            let result = parser.parse(transcription: phrase)
            XCTAssertNotNil(result, "Failed to recognize: \(phrase)")
            XCTAssertEqual(result?.command, expected, "Wrong command for: \(phrase)")
        }
    }
}
