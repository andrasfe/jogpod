//
//  VoiceCommand.swift
//  JogPod
//
//  Voice commands supported during workout sessions.
//  These map to the legacy OpenEars/Pocketsphinx commands from SpeechCommandController.
//

import Foundation

// MARK: - VoiceCommand

/// Represents a voice command that can be recognized during workout sessions.
///
/// This enum defines all voice commands supported by JogPod. Each command corresponds
/// to a workout or media control action.
///
/// ## Legacy Equivalence
///
/// These commands map to the legacy Objective-C implementation in `SpeechCommandController.m`:
///
/// | Legacy Constant      | Swift Command      |
/// |---------------------|--------------------|
/// | kStartWorkoutText   | `.startWorkout`    |
/// | kStopWorkoutText    | `.stopWorkout`     |
/// | kPlayPodcastText    | `.play`            |
/// | kPausePodcastText   | `.pause`           |
/// | kSkipToNextText     | `.next`            |
/// | kSkipToPreviousText | `.previous`        |
/// | kFastForwardText    | `.fastForward`     |
/// | kRewindPodcastText  | `.rewind`          |
/// | kShutdownVoiceText  | `.stopListening`   |
/// | "METRICS"           | `.announceMetrics` |
///
public enum VoiceCommand: String, CaseIterable, Sendable, Equatable {

    // MARK: - Workout Commands

    /// Starts the workout session.
    case startWorkout = "start_workout"

    /// Stops the workout session.
    case stopWorkout = "stop_workout"

    // MARK: - Media Playback Commands

    /// Starts or resumes media playback.
    case play = "play"

    /// Pauses media playback.
    case pause = "pause"

    /// Skips to the next track/episode.
    case next = "next"

    /// Goes to the previous track/episode.
    case previous = "previous"

    /// Fast forwards within current media.
    case fastForward = "fast_forward"

    /// Rewinds within current media.
    case rewind = "rewind"

    // MARK: - System Commands

    /// Stops voice recognition listening.
    case stopListening = "stop_listening"

    /// Requests an announcement of current workout metrics.
    case announceMetrics = "announce_metrics"

    // MARK: - Volume Commands (iOS 26+ enhancement)

    /// Increases audio volume.
    case volumeUp = "volume_up"

    /// Decreases audio volume.
    case volumeDown = "volume_down"

    // MARK: - Properties

    /// The category of this command for grouping in UI.
    public var category: CommandCategory {
        switch self {
        case .startWorkout, .stopWorkout:
            return .workout
        case .play, .pause, .next, .previous, .fastForward, .rewind:
            return .media
        case .stopListening, .announceMetrics:
            return .system
        case .volumeUp, .volumeDown:
            return .volume
        }
    }

    /// A human-readable description of the command's action.
    public var actionDescription: String {
        switch self {
        case .startWorkout:
            return "Start the workout"
        case .stopWorkout:
            return "Stop the workout"
        case .play:
            return "Play podcast/music"
        case .pause:
            return "Pause podcast/music"
        case .next:
            return "Skip to next track"
        case .previous:
            return "Go to previous track"
        case .fastForward:
            return "Fast forward"
        case .rewind:
            return "Rewind"
        case .stopListening:
            return "Stop voice recognition"
        case .announceMetrics:
            return "Announce workout metrics"
        case .volumeUp:
            return "Increase volume"
        case .volumeDown:
            return "Decrease volume"
        }
    }

    /// The default phrase used to trigger this command.
    ///
    /// Users can customize these phrases in settings.
    public var defaultPhrase: String {
        switch self {
        case .startWorkout:
            return "START WORKOUT"
        case .stopWorkout:
            return "STOP WORKOUT"
        case .play:
            return "PLAY"
        case .pause:
            return "PAUSE"
        case .next:
            return "NEXT"
        case .previous:
            return "PREVIOUS"
        case .fastForward:
            return "FAST FORWARD"
        case .rewind:
            return "REWIND"
        case .stopListening:
            return "STOP LISTENING"
        case .announceMetrics:
            return "METRICS"
        case .volumeUp:
            return "LOUDER"
        case .volumeDown:
            return "SOFTER"
        }
    }
}

// MARK: - CommandCategory

/// Categories for grouping voice commands.
public enum CommandCategory: String, CaseIterable, Sendable {

    /// Workout control commands (start, stop).
    case workout

    /// Media playback commands (play, pause, skip, etc.).
    case media

    /// System commands (stop listening, announce metrics).
    case system

    /// Volume control commands.
    case volume

    /// Human-readable title for the category.
    public var title: String {
        switch self {
        case .workout:
            return "Workout"
        case .media:
            return "Media"
        case .system:
            return "System"
        case .volume:
            return "Volume"
        }
    }
}

// MARK: - VoiceCommandResult

/// The result of a voice command recognition attempt.
public struct VoiceCommandResult: Sendable, Equatable {

    /// The recognized command.
    public let command: VoiceCommand

    /// The confidence level of the recognition (0.0 to 1.0).
    public let confidence: Float

    /// The raw transcription text that matched the command.
    public let transcription: String

    /// The timestamp when the command was recognized.
    public let timestamp: Date

    /// Whether the recognition confidence meets the minimum threshold.
    public var isConfident: Bool {
        confidence >= 0.5
    }

    /// Creates a new voice command result.
    ///
    /// - Parameters:
    ///   - command: The recognized command.
    ///   - confidence: The confidence level (0.0 to 1.0).
    ///   - transcription: The raw transcription text.
    ///   - timestamp: The timestamp of recognition. Defaults to now.
    public init(
        command: VoiceCommand,
        confidence: Float,
        transcription: String,
        timestamp: Date = Date()
    ) {
        self.command = command
        self.confidence = confidence
        self.transcription = transcription
        self.timestamp = timestamp
    }
}
