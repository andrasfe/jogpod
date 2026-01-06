//
//  VoiceCommandServiceProtocol.swift
//  JogPod
//
//  Protocol abstraction for voice command recognition service.
//  Enables dependency injection and unit testing.
//

import Foundation
import Combine

// MARK: - VoiceCommandServiceProtocol

/// Protocol defining the voice command recognition service interface.
///
/// This abstraction enables:
/// - Unit testing with mock implementations
/// - Dependency injection for better testability
/// - Future alternative implementations (e.g., different speech engines)
///
/// ## Legacy Equivalence
///
/// This protocol replaces the legacy `SpeechCommandDelegate` pattern:
///
/// ```objc
/// // Legacy
/// @protocol SpeechCommandDelegate <NSObject>
/// -(void)speechCommandReceived:(NSString*)command;
/// @end
/// ```
///
/// The modern implementation uses Swift Concurrency and Combine for
/// reactive command delivery.
///
public protocol VoiceCommandServiceProtocol: AnyObject, Sendable {

    // MARK: - State

    /// Whether voice command recognition is currently active.
    var isListening: Bool { get async }

    /// The current configuration.
    var configuration: VoiceCommandConfiguration { get async }

    /// Publisher for recognized voice commands.
    ///
    /// Subscribe to receive commands as they are recognized:
    ///
    /// ```swift
    /// voiceCommandService.commandPublisher
    ///     .sink { result in
    ///         print("Recognized: \(result.command)")
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    var commandPublisher: AnyPublisher<VoiceCommandResult, Never> { get }

    /// Publisher for service state changes.
    var statePublisher: AnyPublisher<VoiceCommandServiceState, Never> { get }

    /// Publisher for errors.
    var errorPublisher: AnyPublisher<VoiceCommandError, Never> { get }

    // MARK: - Authorization

    /// The current authorization status for speech recognition.
    var authorizationStatus: VoiceCommandAuthorizationStatus { get async }

    /// Requests authorization for speech recognition and microphone access.
    ///
    /// This method requests both speech recognition and microphone permissions
    /// if not already granted.
    ///
    /// - Returns: The resulting authorization status.
    /// - Throws: `VoiceCommandError` if authorization fails.
    @discardableResult
    func requestAuthorization() async throws -> VoiceCommandAuthorizationStatus

    // MARK: - Lifecycle

    /// Starts listening for voice commands.
    ///
    /// This method:
    /// 1. Checks authorization (throws if not authorized)
    /// 2. Configures the audio session
    /// 3. Starts the speech recognizer
    /// 4. Begins publishing recognized commands
    ///
    /// - Throws: `VoiceCommandError` if listening cannot be started.
    func startListening() async throws

    /// Stops listening for voice commands.
    ///
    /// This method stops the speech recognizer and releases audio resources.
    /// Any pending recognition is cancelled.
    func stopListening() async

    // MARK: - Configuration

    /// Updates the service configuration.
    ///
    /// If the service is currently listening, it will be restarted with
    /// the new configuration.
    ///
    /// - Parameter configuration: The new configuration to apply.
    func updateConfiguration(_ configuration: VoiceCommandConfiguration) async

    // MARK: - Capability Queries

    /// Returns whether on-device speech recognition is available.
    ///
    /// On-device recognition provides:
    /// - Offline operation (like legacy OpenEars)
    /// - Better privacy (audio not sent to server)
    /// - Lower latency
    ///
    /// - Note: Requires iOS 13+ and device with Neural Engine.
    var isOnDeviceRecognitionAvailable: Bool { get async }

    /// Returns whether speech recognition is available for the current locale.
    var isRecognitionAvailableForLocale: Bool { get async }
}

// MARK: - VoiceCommandServiceState

/// The state of the voice command recognition service.
public enum VoiceCommandServiceState: Sendable, Equatable {

    /// Service is idle, not listening.
    case idle

    /// Service is starting up (initializing audio, speech recognizer).
    case starting

    /// Service is actively listening for commands.
    case listening

    /// Service detected speech and is processing.
    case processing

    /// Service encountered an error.
    case error(VoiceCommandError)

    /// Service is stopping.
    case stopping

    /// Whether the service is in an active state (listening or processing).
    public var isActive: Bool {
        switch self {
        case .listening, .processing:
            return true
        default:
            return false
        }
    }

    /// Whether the service is in a transitional state.
    public var isTransitioning: Bool {
        switch self {
        case .starting, .stopping:
            return true
        default:
            return false
        }
    }
}

// MARK: - VoiceCommandAuthorizationStatus

/// The authorization status for voice command recognition.
///
/// Combines the status of both speech recognition and microphone permissions.
public enum VoiceCommandAuthorizationStatus: Sendable, Equatable {

    /// Both speech recognition and microphone access are authorized.
    case authorized

    /// Authorization has not been requested yet.
    case notDetermined

    /// Speech recognition or microphone access was denied.
    case denied(reason: DenialReason)

    /// Speech recognition or microphone access is restricted.
    case restricted

    /// Whether voice commands can be used.
    public var isAuthorized: Bool {
        self == .authorized
    }

    /// Whether the user can grant authorization.
    public var canRequestAuthorization: Bool {
        self == .notDetermined
    }

    /// The reason for denial, if denied.
    public enum DenialReason: Sendable, Equatable {
        /// Speech recognition permission was denied.
        case speechRecognition

        /// Microphone permission was denied.
        case microphone

        /// Both permissions were denied.
        case both
    }
}

// MARK: - VoiceCommandDelegate

/// Delegate protocol for receiving voice command events.
///
/// Use this protocol for delegate-based event handling as an alternative
/// to the Combine publishers.
///
/// ## Usage
///
/// ```swift
/// class MyViewController: VoiceCommandDelegate {
///     func voiceCommandService(_ service: any VoiceCommandServiceProtocol,
///                              didRecognizeCommand result: VoiceCommandResult) {
///         switch result.command {
///         case .startWorkout:
///             startWorkout()
///         case .stopWorkout:
///             stopWorkout()
///         // ...
///         }
///     }
/// }
/// ```
///
public protocol VoiceCommandDelegate: AnyObject, Sendable {

    /// Called when a voice command is recognized.
    ///
    /// - Parameters:
    ///   - service: The voice command service.
    ///   - result: The recognized command result.
    func voiceCommandService(
        _ service: any VoiceCommandServiceProtocol,
        didRecognizeCommand result: VoiceCommandResult
    )

    /// Called when the service state changes.
    ///
    /// - Parameters:
    ///   - service: The voice command service.
    ///   - state: The new state.
    func voiceCommandService(
        _ service: any VoiceCommandServiceProtocol,
        didChangeState state: VoiceCommandServiceState
    )

    /// Called when an error occurs.
    ///
    /// - Parameters:
    ///   - service: The voice command service.
    ///   - error: The error that occurred.
    func voiceCommandService(
        _ service: any VoiceCommandServiceProtocol,
        didEncounterError error: VoiceCommandError
    )
}

// MARK: - Default Delegate Implementation

public extension VoiceCommandDelegate {

    func voiceCommandService(
        _ service: any VoiceCommandServiceProtocol,
        didChangeState state: VoiceCommandServiceState
    ) {}

    func voiceCommandService(
        _ service: any VoiceCommandServiceProtocol,
        didEncounterError error: VoiceCommandError
    ) {}
}
