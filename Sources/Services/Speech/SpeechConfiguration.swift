//
//  SpeechConfiguration.swift
//  JogPod
//
//  Configuration types for the Speech service.
//

import Foundation
import AVFoundation

// MARK: - SpeechConfiguration

/// Configuration for speech synthesis.
///
/// This struct encapsulates all configurable options for the speech service,
/// including voice selection, rate, volume, and audio ducking behavior.
public struct SpeechConfiguration: Equatable, Sendable {

    // MARK: - Properties

    /// Whether speech announcements are enabled.
    public var isEnabled: Bool

    /// The voice identifier to use. If nil, uses the default system voice.
    public var voiceIdentifier: String?

    /// Speech rate (0.0 to 1.0, where 0.5 is normal).
    ///
    /// - Note: AVSpeechUtterance uses a rate scale where:
    ///   - 0.0 is minimum (very slow)
    ///   - 0.5 is default/normal
    ///   - 1.0 is maximum (very fast)
    public var rate: Float

    /// Speech pitch multiplier (0.5 to 2.0, where 1.0 is normal).
    public var pitchMultiplier: Float

    /// Speech volume (0.0 to 1.0).
    public var volume: Float

    /// Whether to duck other audio during speech.
    public var enableAudioDucking: Bool

    /// The duration to wait before speaking after ducking audio.
    public var duckingDelay: TimeInterval

    /// The language code for speech (e.g., "en-US").
    public var languageCode: String

    // MARK: - Initialization

    /// Creates a new SpeechConfiguration with the specified options.
    ///
    /// - Parameters:
    ///   - isEnabled: Whether speech is enabled. Defaults to true.
    ///   - voiceIdentifier: Voice identifier to use. Defaults to nil (system default).
    ///   - rate: Speech rate (0.0-1.0). Defaults to 0.5 (normal).
    ///   - pitchMultiplier: Pitch multiplier (0.5-2.0). Defaults to 1.0.
    ///   - volume: Volume level (0.0-1.0). Defaults to 1.0.
    ///   - enableAudioDucking: Whether to duck audio. Defaults to true.
    ///   - duckingDelay: Delay after ducking before speaking. Defaults to 0.2 seconds.
    ///   - languageCode: Language code. Defaults to "en-US".
    public init(
        isEnabled: Bool = true,
        voiceIdentifier: String? = nil,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitchMultiplier: Float = 1.0,
        volume: Float = 1.0,
        enableAudioDucking: Bool = true,
        duckingDelay: TimeInterval = 0.2,
        languageCode: String = "en-US"
    ) {
        self.isEnabled = isEnabled
        self.voiceIdentifier = voiceIdentifier
        self.rate = Self.clampRate(rate)
        self.pitchMultiplier = Self.clampPitch(pitchMultiplier)
        self.volume = Self.clampVolume(volume)
        self.enableAudioDucking = enableAudioDucking
        self.duckingDelay = duckingDelay
        self.languageCode = languageCode
    }

    // MARK: - Default Configuration

    /// The default configuration with standard settings.
    public static let `default` = SpeechConfiguration()

    // MARK: - Validation Helpers

    private static func clampRate(_ rate: Float) -> Float {
        max(AVSpeechUtteranceMinimumSpeechRate, min(rate, AVSpeechUtteranceMaximumSpeechRate))
    }

    private static func clampPitch(_ pitch: Float) -> Float {
        max(0.5, min(pitch, 2.0))
    }

    private static func clampVolume(_ volume: Float) -> Float {
        max(0.0, min(volume, 1.0))
    }
}

// MARK: - VoiceInfo

/// Information about an available speech voice.
public struct VoiceInfo: Identifiable, Equatable, Sendable {

    /// The unique identifier for this voice.
    public let id: String

    /// The display name of the voice.
    public let name: String

    /// The language code (e.g., "en-US").
    public let languageCode: String

    /// The quality level of the voice.
    public let quality: VoiceQuality

    /// Creates a VoiceInfo from an AVSpeechSynthesisVoice.
    ///
    /// - Parameter voice: The AVSpeechSynthesisVoice to wrap.
    public init(voice: AVSpeechSynthesisVoice) {
        self.id = voice.identifier
        self.name = voice.name
        self.languageCode = voice.language
        self.quality = VoiceQuality(rawQuality: voice.quality)
    }

    /// Creates a VoiceInfo with explicit values.
    ///
    /// - Parameters:
    ///   - id: The voice identifier.
    ///   - name: The display name.
    ///   - languageCode: The language code.
    ///   - quality: The quality level.
    public init(id: String, name: String, languageCode: String, quality: VoiceQuality) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
        self.quality = quality
    }
}

// MARK: - VoiceQuality

/// Quality level of a speech synthesis voice.
public enum VoiceQuality: Int, Sendable, Comparable {

    /// Default quality voice.
    case standard = 1

    /// Enhanced quality voice (downloaded).
    case enhanced = 2

    /// Premium quality voice.
    case premium = 3

    /// Creates a VoiceQuality from an AVSpeechSynthesisVoiceQuality.
    ///
    /// - Parameter rawQuality: The raw quality value from AVFoundation.
    public init(rawQuality: AVSpeechSynthesisVoiceQuality) {
        switch rawQuality {
        case .default:
            self = .standard
        case .enhanced:
            self = .enhanced
        case .premium:
            self = .premium
        @unknown default:
            self = .standard
        }
    }

    public static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - AnnouncementType

/// Types of announcements that can be spoken.
///
/// This enum maps to the legacy announcement preference keys.
public enum AnnouncementType: String, CaseIterable, Sendable {

    /// Current speed announcement.
    case currentSpeed = "announceCurrentSpeed"

    /// Average speed announcement.
    case averageSpeed = "announceAvgSpeed"

    /// Current heart rate announcement.
    case currentHeartRate = "announceCurrentHeartRate"

    /// Average heart rate announcement.
    case averageHeartRate = "announceAvgHeartRate"

    /// Total elevation gain (uphill) announcement.
    case totalAscent = "announceTotalAscent"

    /// Total elevation loss (downhill) announcement.
    case totalDescent = "announceTotalDescent"

    /// Calories burned announcement.
    case caloriesBurned = "announceCaloriesBurned"

    /// Workout duration announcement.
    case duration = "announceDuration"

    /// Distance traveled announcement.
    case distance = "announceDistance"

    /// Temperature announcement.
    case temperature = "announceTemperature"

    /// Humidity announcement.
    case humidity = "announceHumidity"

    /// Wind speed announcement.
    case windSpeed = "announceWindSpeed"

    /// Display name for the announcement type.
    public var displayName: String {
        switch self {
        case .currentSpeed: return "Current Speed"
        case .averageSpeed: return "Average Speed"
        case .currentHeartRate: return "Heart Rate"
        case .averageHeartRate: return "Average Heart Rate"
        case .totalAscent: return "Uphill"
        case .totalDescent: return "Downhill"
        case .caloriesBurned: return "Calories"
        case .duration: return "Duration"
        case .distance: return "Distance"
        case .temperature: return "Temperature"
        case .humidity: return "Humidity"
        case .windSpeed: return "Wind Speed"
        }
    }

    /// Whether this announcement type is enabled by default.
    public var isEnabledByDefault: Bool {
        switch self {
        case .currentSpeed, .averageSpeed, .caloriesBurned, .duration, .distance,
             .temperature, .humidity, .windSpeed:
            return true
        case .currentHeartRate, .averageHeartRate, .totalAscent, .totalDescent:
            return false
        }
    }
}
