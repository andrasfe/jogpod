//
//  VoiceCommandError.swift
//  JogPod
//
//  Error types for voice command recognition service.
//

import Foundation

// MARK: - VoiceCommandError

/// Errors that can occur during voice command recognition.
///
/// This error type covers all failure modes of the voice command service,
/// from authorization failures to recognition issues.
///
/// ## Error Handling Strategy
///
/// Errors are categorized by whether they require user action:
///
/// - **Authorization errors**: Require user to grant permissions in Settings
/// - **Availability errors**: May be temporary (no network) or permanent (device limitation)
/// - **Runtime errors**: Usually recoverable by retrying
///
public enum VoiceCommandError: LocalizedError, Sendable, Equatable {

    // MARK: - Authorization Errors

    /// Speech recognition authorization was denied by the user.
    ///
    /// The user must go to Settings > Privacy > Speech Recognition
    /// to enable speech recognition for JogPod.
    case speechRecognitionDenied

    /// Speech recognition authorization has not been determined yet.
    ///
    /// The app should request authorization before attempting recognition.
    case speechRecognitionNotDetermined

    /// Speech recognition authorization is restricted on this device.
    ///
    /// Parental controls or MDM may restrict speech recognition.
    case speechRecognitionRestricted

    /// Microphone access was denied by the user.
    ///
    /// The user must go to Settings > Privacy > Microphone
    /// to enable microphone access for JogPod.
    case microphoneAccessDenied

    /// Microphone access has not been determined yet.
    case microphoneAccessNotDetermined

    // MARK: - Availability Errors

    /// Speech recognition is not available on this device.
    ///
    /// This can happen if:
    /// - The device does not support speech recognition
    /// - The specified locale is not supported
    /// - The speech recognition service is unavailable
    case speechRecognitionUnavailable

    /// On-device speech recognition is not available.
    ///
    /// On-device recognition requires iOS 13+ and device with Neural Engine.
    /// When unavailable, recognition requires network connectivity.
    ///
    /// - Note: The legacy OpenEars implementation worked fully offline.
    ///   This is a feature limitation of the modern implementation.
    case onDeviceRecognitionUnavailable

    /// Network connection is required but not available.
    ///
    /// This occurs when on-device recognition is unavailable and
    /// the device has no network connection.
    case networkRequired

    /// The specified locale is not supported for speech recognition.
    case localeNotSupported(locale: String)

    // MARK: - Runtime Errors

    /// The audio engine failed to start.
    case audioEngineStartFailed(reason: String)

    /// The audio session could not be configured.
    case audioSessionConfigurationFailed(reason: String)

    /// Recognition was cancelled before completion.
    case recognitionCancelled

    /// Recognition timed out waiting for speech input.
    case recognitionTimeout

    /// An error occurred during speech recognition.
    case recognitionFailed(reason: String)

    /// The recognition request failed to initialize.
    case recognitionRequestFailed(reason: String)

    /// No speech was detected within the expected time window.
    case noSpeechDetected

    // MARK: - State Errors

    /// Voice command recognition is already active.
    case alreadyListening

    /// Voice command recognition is not currently active.
    case notListening

    /// The service was deallocated while recognition was in progress.
    case serviceDeallocated

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .speechRecognitionDenied:
            return "Speech recognition access was denied"
        case .speechRecognitionNotDetermined:
            return "Speech recognition permission has not been requested"
        case .speechRecognitionRestricted:
            return "Speech recognition is restricted on this device"
        case .microphoneAccessDenied:
            return "Microphone access was denied"
        case .microphoneAccessNotDetermined:
            return "Microphone permission has not been requested"
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available"
        case .onDeviceRecognitionUnavailable:
            return "On-device speech recognition is not available"
        case .networkRequired:
            return "Network connection is required for speech recognition"
        case .localeNotSupported(let locale):
            return "Speech recognition is not supported for locale: \(locale)"
        case .audioEngineStartFailed(let reason):
            return "Failed to start audio engine: \(reason)"
        case .audioSessionConfigurationFailed(let reason):
            return "Failed to configure audio session: \(reason)"
        case .recognitionCancelled:
            return "Speech recognition was cancelled"
        case .recognitionTimeout:
            return "Speech recognition timed out"
        case .recognitionFailed(let reason):
            return "Speech recognition failed: \(reason)"
        case .recognitionRequestFailed(let reason):
            return "Failed to create recognition request: \(reason)"
        case .noSpeechDetected:
            return "No speech was detected"
        case .alreadyListening:
            return "Voice command recognition is already active"
        case .notListening:
            return "Voice command recognition is not active"
        case .serviceDeallocated:
            return "Voice command service was deallocated"
        }
    }

    public var failureReason: String? {
        switch self {
        case .speechRecognitionDenied, .microphoneAccessDenied:
            return "The user denied permission"
        case .speechRecognitionRestricted:
            return "Device restrictions prevent speech recognition"
        case .onDeviceRecognitionUnavailable:
            return "This device does not support on-device speech recognition"
        case .networkRequired:
            return "No network connection available for server-based recognition"
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .speechRecognitionDenied:
            return "Go to Settings > Privacy & Security > Speech Recognition and enable access for JogPod"
        case .speechRecognitionNotDetermined:
            return "The app will request permission when you start voice commands"
        case .speechRecognitionRestricted:
            return "Check with your device administrator about speech recognition restrictions"
        case .microphoneAccessDenied:
            return "Go to Settings > Privacy & Security > Microphone and enable access for JogPod"
        case .microphoneAccessNotDetermined:
            return "The app will request permission when you start voice commands"
        case .networkRequired:
            return "Connect to Wi-Fi or cellular data for voice commands, or wait for on-device recognition to become available"
        case .onDeviceRecognitionUnavailable:
            return "Voice commands require a network connection on this device"
        case .recognitionTimeout:
            return "Try speaking louder or closer to the microphone"
        case .noSpeechDetected:
            return "Speak clearly into the microphone"
        default:
            return nil
        }
    }

    // MARK: - Helpers

    /// Whether this error requires user action to resolve.
    public var requiresUserAction: Bool {
        switch self {
        case .speechRecognitionDenied,
             .speechRecognitionRestricted,
             .microphoneAccessDenied:
            return true
        default:
            return false
        }
    }

    /// Whether this error might be resolved by retrying.
    public var isRetryable: Bool {
        switch self {
        case .audioEngineStartFailed,
             .recognitionFailed,
             .recognitionRequestFailed,
             .recognitionTimeout,
             .noSpeechDetected,
             .networkRequired:
            return true
        default:
            return false
        }
    }

    /// Whether this error indicates a permanent device limitation.
    public var isPermanent: Bool {
        switch self {
        case .speechRecognitionRestricted,
             .speechRecognitionUnavailable,
             .localeNotSupported:
            return true
        default:
            return false
        }
    }
}
