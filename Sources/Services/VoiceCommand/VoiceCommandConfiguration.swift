//
//  VoiceCommandConfiguration.swift
//  JogPod
//
//  Configuration for voice command recognition service.
//

import Foundation

// MARK: - VoiceCommandConfiguration

/// Configuration for the voice command recognition service.
///
/// This struct allows customization of trigger phrases for each command,
/// recognition parameters, and service behavior.
///
/// ## Legacy Equivalence
///
/// In the legacy implementation, command phrases were stored in `PersistenceManager`
/// using keys like `kStartWorkoutText`, `kStopWorkoutText`, etc. This configuration
/// provides a type-safe replacement that can be persisted and restored.
///
/// ## Phrase Customization
///
/// Users can customize the phrases that trigger each command:
///
/// ```swift
/// var config = VoiceCommandConfiguration.default
/// config.setPhrase("BEGIN EXERCISE", for: .startWorkout)
/// config.setPhrase("END EXERCISE", for: .stopWorkout)
/// ```
///
public struct VoiceCommandConfiguration: Sendable, Equatable, Codable {

    // MARK: - Properties

    /// Custom phrases mapped to commands. If a command is not in this dictionary,
    /// the default phrase from `VoiceCommand.defaultPhrase` is used.
    public var customPhrases: [VoiceCommand: String]

    /// The locale to use for speech recognition.
    ///
    /// Defaults to the user's current locale. The recognizer will attempt to
    /// use on-device recognition if available for this locale.
    public var locale: Locale

    /// Whether to require on-device recognition only.
    ///
    /// When `true`, recognition will fail if on-device recognition is unavailable,
    /// rather than falling back to server-based recognition. This preserves the
    /// offline capability of the legacy OpenEars implementation.
    ///
    /// - Note: On-device recognition requires iOS 13+ and a device with Neural Engine.
    ///   When unavailable and this is `true`, voice commands will not work.
    public var requireOnDeviceRecognition: Bool

    /// The minimum confidence threshold for accepting a command (0.0 to 1.0).
    ///
    /// Recognized commands with confidence below this threshold will be ignored.
    /// Higher values reduce false positives but may miss valid commands.
    public var confidenceThreshold: Float

    /// Whether to use partial results during recognition.
    ///
    /// When `true`, commands may be triggered before the user finishes speaking,
    /// providing faster response. When `false`, only final results are used.
    public var usePartialResults: Bool

    /// Maximum duration to wait for speech input before timing out.
    ///
    /// Set to `nil` for no timeout (continuous listening).
    public var recognitionTimeout: TimeInterval?

    /// Whether to add contextual strings to improve recognition accuracy.
    ///
    /// When `true`, the recognizer is hinted with the expected command phrases,
    /// improving accuracy for workout-specific vocabulary.
    public var useContextualStrings: Bool

    /// Whether to enable audio feedback when a command is recognized.
    public var enableAudioFeedback: Bool

    /// Whether to enable haptic feedback when a command is recognized.
    public var enableHapticFeedback: Bool

    /// Task priority hint for speech recognition.
    ///
    /// Set to `.userInitiated` for responsive voice commands during workouts.
    public var taskHint: TaskHint

    // MARK: - Initialization

    /// Creates a voice command configuration with the specified parameters.
    ///
    /// - Parameters:
    ///   - customPhrases: Custom phrases for commands. Defaults to empty (use default phrases).
    ///   - locale: The locale for recognition. Defaults to current locale.
    ///   - requireOnDeviceRecognition: Whether to require offline recognition. Defaults to `false`.
    ///   - confidenceThreshold: Minimum confidence for accepting commands. Defaults to 0.5.
    ///   - usePartialResults: Whether to use partial results. Defaults to `true`.
    ///   - recognitionTimeout: Timeout for speech input. Defaults to `nil` (no timeout).
    ///   - useContextualStrings: Whether to hint recognizer with command phrases. Defaults to `true`.
    ///   - enableAudioFeedback: Whether to play audio on recognition. Defaults to `true`.
    ///   - enableHapticFeedback: Whether to trigger haptic on recognition. Defaults to `true`.
    ///   - taskHint: Priority hint for recognition task. Defaults to `.userInitiated`.
    public init(
        customPhrases: [VoiceCommand: String] = [:],
        locale: Locale = .current,
        requireOnDeviceRecognition: Bool = false,
        confidenceThreshold: Float = 0.5,
        usePartialResults: Bool = true,
        recognitionTimeout: TimeInterval? = nil,
        useContextualStrings: Bool = true,
        enableAudioFeedback: Bool = true,
        enableHapticFeedback: Bool = true,
        taskHint: TaskHint = .userInitiated
    ) {
        self.customPhrases = customPhrases
        self.locale = locale
        self.requireOnDeviceRecognition = requireOnDeviceRecognition
        self.confidenceThreshold = confidenceThreshold
        self.usePartialResults = usePartialResults
        self.recognitionTimeout = recognitionTimeout
        self.useContextualStrings = useContextualStrings
        self.enableAudioFeedback = enableAudioFeedback
        self.enableHapticFeedback = enableHapticFeedback
        self.taskHint = taskHint
    }

    // MARK: - Static Configurations

    /// The default configuration.
    public static let `default` = VoiceCommandConfiguration()

    /// Configuration optimized for outdoor workout use.
    ///
    /// Uses lower confidence threshold and partial results for better
    /// recognition in noisy environments.
    public static let outdoor: VoiceCommandConfiguration = {
        var config = VoiceCommandConfiguration.default
        config.confidenceThreshold = 0.4
        config.usePartialResults = true
        config.enableHapticFeedback = true
        return config
    }()

    /// Configuration for offline-only operation.
    ///
    /// Requires on-device recognition, matching the legacy OpenEars behavior.
    /// Will fail on devices that don't support on-device recognition.
    public static let offlineOnly: VoiceCommandConfiguration = {
        var config = VoiceCommandConfiguration.default
        config.requireOnDeviceRecognition = true
        return config
    }()

    // MARK: - Phrase Management

    /// Returns the phrase for the specified command.
    ///
    /// Returns the custom phrase if set, otherwise returns the default phrase.
    ///
    /// - Parameter command: The command to get the phrase for.
    /// - Returns: The phrase that triggers this command.
    public func phrase(for command: VoiceCommand) -> String {
        customPhrases[command] ?? command.defaultPhrase
    }

    /// Sets a custom phrase for the specified command.
    ///
    /// - Parameters:
    ///   - phrase: The phrase to trigger this command.
    ///   - command: The command to customize.
    public mutating func setPhrase(_ phrase: String, for command: VoiceCommand) {
        customPhrases[command] = phrase.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Resets the phrase for the specified command to its default.
    ///
    /// - Parameter command: The command to reset.
    public mutating func resetPhrase(for command: VoiceCommand) {
        customPhrases.removeValue(forKey: command)
    }

    /// Resets all phrases to their defaults.
    public mutating func resetAllPhrases() {
        customPhrases.removeAll()
    }

    /// Returns all phrases mapped to their commands.
    ///
    /// This includes both custom and default phrases.
    public func allPhrases() -> [(command: VoiceCommand, phrase: String)] {
        VoiceCommand.allCases.map { command in
            (command: command, phrase: phrase(for: command))
        }
    }

    // MARK: - Validation

    /// Validates the configuration.
    ///
    /// - Returns: An array of validation issues, or empty if valid.
    public func validate() -> [ConfigurationIssue] {
        var issues: [ConfigurationIssue] = []

        // Check confidence threshold
        if confidenceThreshold < 0.0 || confidenceThreshold > 1.0 {
            issues.append(.invalidConfidenceThreshold(confidenceThreshold))
        }

        // Check for duplicate phrases
        let allPhrasesList = allPhrases()
        var seenPhrases: [String: VoiceCommand] = [:]
        for (command, phrase) in allPhrasesList {
            let normalizedPhrase = phrase.uppercased()
            if let existingCommand = seenPhrases[normalizedPhrase] {
                issues.append(.duplicatePhrase(phrase: phrase, commands: [existingCommand, command]))
            } else {
                seenPhrases[normalizedPhrase] = command
            }
        }

        // Check for empty phrases
        for (command, phrase) in allPhrasesList {
            if phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.emptyPhrase(command: command))
            }
        }

        return issues
    }

    /// Whether the configuration is valid.
    public var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - TaskHint

/// Priority hint for speech recognition tasks.
public enum TaskHint: String, Sendable, Codable, CaseIterable {

    /// Default priority.
    case unspecified

    /// Dictation-style input.
    case dictation

    /// Search queries.
    case search

    /// User-initiated command recognition (recommended for voice commands).
    case userInitiated

    /// Background processing.
    case background
}

// MARK: - ConfigurationIssue

/// An issue found during configuration validation.
public enum ConfigurationIssue: Equatable, Sendable {

    /// The confidence threshold is outside the valid range (0.0 to 1.0).
    case invalidConfidenceThreshold(Float)

    /// Two or more commands share the same phrase.
    case duplicatePhrase(phrase: String, commands: [VoiceCommand])

    /// A command has an empty phrase.
    case emptyPhrase(command: VoiceCommand)

    /// Human-readable description of the issue.
    public var description: String {
        switch self {
        case .invalidConfidenceThreshold(let value):
            return "Confidence threshold \(value) is outside valid range 0.0-1.0"
        case .duplicatePhrase(let phrase, let commands):
            let commandNames = commands.map { $0.rawValue }.joined(separator: ", ")
            return "Phrase '\(phrase)' is used by multiple commands: \(commandNames)"
        case .emptyPhrase(let command):
            return "Command '\(command.rawValue)' has an empty phrase"
        }
    }
}

// MARK: - Codable Extensions

extension VoiceCommand: Codable {}

extension Locale: @retroactive Equatable {
    public static func == (lhs: Locale, rhs: Locale) -> Bool {
        lhs.identifier == rhs.identifier
    }
}
