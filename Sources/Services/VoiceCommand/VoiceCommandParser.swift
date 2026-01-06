//
//  VoiceCommandParser.swift
//  JogPod
//
//  Parses transcribed speech text into voice commands.
//  This logic is separated from audio input to enable unit testing.
//

import Foundation

// MARK: - VoiceCommandParser

/// Parses transcribed speech text into voice commands.
///
/// This class is the core command recognition logic, separated from the
/// audio input and speech recognition systems. This separation enables:
///
/// - Unit testing of command parsing without audio/microphone access
/// - Testing in CI environments that cannot grant microphone permissions
/// - Verification of phrase matching logic in isolation
///
/// ## Matching Strategy
///
/// The parser uses a multi-stage matching strategy:
///
/// 1. **Exact match**: The transcription matches a command phrase exactly
/// 2. **Normalized match**: Case-insensitive, whitespace-normalized matching
/// 3. **Contains match**: The transcription contains the command phrase
/// 4. **Fuzzy match**: Levenshtein distance for typo tolerance (configurable)
///
/// ## Thread Safety
///
/// This struct is value-type and `Sendable`, safe to use from any context.
///
public struct VoiceCommandParser: Sendable {

    // MARK: - Properties

    /// The configuration containing command phrases.
    public let configuration: VoiceCommandConfiguration

    /// Whether to use fuzzy matching for typo tolerance.
    public let useFuzzyMatching: Bool

    /// Maximum edit distance for fuzzy matching (default: 2).
    public let maxEditDistance: Int

    // MARK: - Initialization

    /// Creates a new parser with the specified configuration.
    ///
    /// - Parameters:
    ///   - configuration: The configuration containing command phrases.
    ///   - useFuzzyMatching: Whether to enable fuzzy matching. Defaults to `false`.
    ///   - maxEditDistance: Maximum edit distance for fuzzy matches. Defaults to 2.
    public init(
        configuration: VoiceCommandConfiguration,
        useFuzzyMatching: Bool = false,
        maxEditDistance: Int = 2
    ) {
        self.configuration = configuration
        self.useFuzzyMatching = useFuzzyMatching
        self.maxEditDistance = maxEditDistance
    }

    // MARK: - Parsing

    /// Parses a transcription into a voice command.
    ///
    /// - Parameters:
    ///   - transcription: The transcribed speech text.
    ///   - confidence: The confidence level from the recognizer (0.0 to 1.0).
    /// - Returns: A `VoiceCommandResult` if a command was matched, `nil` otherwise.
    public func parse(transcription: String, confidence: Float = 1.0) -> VoiceCommandResult? {
        let normalizedTranscription = normalize(transcription)

        guard !normalizedTranscription.isEmpty else {
            return nil
        }

        // Try each matching strategy in order of strictness
        if let result = tryExactMatch(normalizedTranscription, confidence: confidence) {
            return result
        }

        if let result = tryContainsMatch(normalizedTranscription, confidence: confidence) {
            return result
        }

        if useFuzzyMatching, let result = tryFuzzyMatch(normalizedTranscription, confidence: confidence) {
            return result
        }

        return nil
    }

    /// Parses a transcription and returns all possible matches sorted by confidence.
    ///
    /// Useful for debugging or presenting alternatives to the user.
    ///
    /// - Parameters:
    ///   - transcription: The transcribed speech text.
    ///   - confidence: The confidence level from the recognizer.
    /// - Returns: An array of possible matches, sorted by match quality.
    public func parseAllMatches(transcription: String, confidence: Float = 1.0) -> [VoiceCommandResult] {
        let normalizedTranscription = normalize(transcription)

        guard !normalizedTranscription.isEmpty else {
            return []
        }

        var matches: [(result: VoiceCommandResult, quality: MatchQuality)] = []

        for command in VoiceCommand.allCases {
            let phrase = normalize(configuration.phrase(for: command))

            if normalizedTranscription == phrase {
                matches.append((
                    result: VoiceCommandResult(
                        command: command,
                        confidence: confidence,
                        transcription: transcription
                    ),
                    quality: .exact
                ))
            } else if normalizedTranscription.contains(phrase) || phrase.contains(normalizedTranscription) {
                // Adjust confidence based on how much of the phrase matched
                let matchRatio = Float(min(phrase.count, normalizedTranscription.count)) /
                                 Float(max(phrase.count, normalizedTranscription.count))
                matches.append((
                    result: VoiceCommandResult(
                        command: command,
                        confidence: confidence * matchRatio,
                        transcription: transcription
                    ),
                    quality: .contains
                ))
            } else if useFuzzyMatching {
                let distance = levenshteinDistance(normalizedTranscription, phrase)
                if distance <= maxEditDistance {
                    let matchConfidence = confidence * (1.0 - Float(distance) / Float(max(phrase.count, 1)))
                    matches.append((
                        result: VoiceCommandResult(
                            command: command,
                            confidence: matchConfidence,
                            transcription: transcription
                        ),
                        quality: .fuzzy(distance: distance)
                    ))
                }
            }
        }

        // Sort by quality (exact > contains > fuzzy) then by confidence
        return matches
            .sorted { lhs, rhs in
                if lhs.quality.priority != rhs.quality.priority {
                    return lhs.quality.priority > rhs.quality.priority
                }
                return lhs.result.confidence > rhs.result.confidence
            }
            .map { $0.result }
    }

    // MARK: - Private Matching Methods

    private func tryExactMatch(_ normalizedTranscription: String, confidence: Float) -> VoiceCommandResult? {
        for command in VoiceCommand.allCases {
            let phrase = normalize(configuration.phrase(for: command))
            if normalizedTranscription == phrase {
                return VoiceCommandResult(
                    command: command,
                    confidence: confidence,
                    transcription: normalizedTranscription
                )
            }
        }
        return nil
    }

    private func tryContainsMatch(_ normalizedTranscription: String, confidence: Float) -> VoiceCommandResult? {
        // First, try to find phrases that the transcription contains
        var bestMatch: (command: VoiceCommand, phrase: String, confidence: Float)?

        for command in VoiceCommand.allCases {
            let phrase = normalize(configuration.phrase(for: command))

            if normalizedTranscription.contains(phrase) {
                // Prefer longer phrases (more specific match)
                if bestMatch == nil || phrase.count > bestMatch!.phrase.count {
                    let matchRatio = Float(phrase.count) / Float(normalizedTranscription.count)
                    bestMatch = (command, phrase, confidence * min(matchRatio + 0.3, 1.0))
                }
            }
        }

        if let match = bestMatch {
            return VoiceCommandResult(
                command: match.command,
                confidence: match.confidence,
                transcription: normalizedTranscription
            )
        }

        return nil
    }

    private func tryFuzzyMatch(_ normalizedTranscription: String, confidence: Float) -> VoiceCommandResult? {
        var bestMatch: (command: VoiceCommand, distance: Int)?

        for command in VoiceCommand.allCases {
            let phrase = normalize(configuration.phrase(for: command))
            let distance = levenshteinDistance(normalizedTranscription, phrase)

            if distance <= maxEditDistance {
                if bestMatch == nil || distance < bestMatch!.distance {
                    bestMatch = (command, distance)
                }
            }
        }

        if let match = bestMatch {
            let matchConfidence = confidence * (1.0 - Float(match.distance) / Float(maxEditDistance + 1))
            return VoiceCommandResult(
                command: match.command,
                confidence: matchConfidence,
                transcription: normalizedTranscription
            )
        }

        return nil
    }

    // MARK: - Normalization

    /// Normalizes text for comparison.
    ///
    /// - Converts to uppercase
    /// - Trims whitespace
    /// - Collapses multiple spaces to single space
    /// - Removes punctuation
    private func normalize(_ text: String) -> String {
        text
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .punctuationCharacters)
            .joined()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Fuzzy Matching

    /// Calculates the Levenshtein (edit) distance between two strings.
    ///
    /// - Parameters:
    ///   - s1: First string.
    ///   - s2: Second string.
    /// - Returns: The minimum number of single-character edits needed to transform s1 into s2.
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        let m = s1Array.count
        let n = s2Array.count

        guard m > 0 else { return n }
        guard n > 0 else { return m }

        // Use two rows to save memory
        var previousRow = Array(0...n)
        var currentRow = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            currentRow[0] = i

            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,      // deletion
                    currentRow[j - 1] + 1,   // insertion
                    previousRow[j - 1] + cost // substitution
                )
            }

            swap(&previousRow, &currentRow)
        }

        return previousRow[n]
    }
}

// MARK: - MatchQuality

/// The quality of a command match.
private enum MatchQuality: Sendable {

    /// Exact string match.
    case exact

    /// The transcription contains or is contained by the phrase.
    case contains

    /// Fuzzy match with the given edit distance.
    case fuzzy(distance: Int)

    /// Priority for sorting (higher is better).
    var priority: Int {
        switch self {
        case .exact:
            return 100
        case .contains:
            return 50
        case .fuzzy(let distance):
            return max(0, 25 - distance * 5)
        }
    }
}

// MARK: - Convenience Extensions

public extension VoiceCommandParser {

    /// Creates a parser with default phrases.
    static var `default`: VoiceCommandParser {
        VoiceCommandParser(configuration: .default)
    }

    /// Checks if a transcription matches any command.
    ///
    /// - Parameter transcription: The text to check.
    /// - Returns: `true` if the transcription matches a command.
    func isCommand(_ transcription: String) -> Bool {
        parse(transcription: transcription) != nil
    }

    /// Returns the command that best matches the transcription, if any.
    ///
    /// - Parameter transcription: The text to parse.
    /// - Returns: The matching command, or `nil` if no match.
    func command(from transcription: String) -> VoiceCommand? {
        parse(transcription: transcription)?.command
    }
}
