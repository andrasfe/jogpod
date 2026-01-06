//
//  SpeechError.swift
//  JogPod
//
//  Error types for the Speech service.
//

import Foundation

// MARK: - SpeechError

/// Errors that can occur during speech synthesis operations.
public enum SpeechError: Error, Equatable, Sendable {

    /// The speech synthesizer is not available.
    case synthesizerUnavailable

    /// Speech synthesis failed with the given reason.
    case synthesisFailed(reason: String)

    /// Audio session configuration failed.
    case audioSessionConfigurationFailed(reason: String)

    /// The specified voice was not found.
    case voiceNotFound(identifier: String)

    /// Speech is disabled in preferences.
    case speechDisabled

    /// The announcement text was empty or nil.
    case emptyAnnouncement

    /// Audio ducking failed.
    case audioDuckingFailed(reason: String)
}

// MARK: - LocalizedError

extension SpeechError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .synthesizerUnavailable:
            return "Speech synthesizer is not available"

        case .synthesisFailed(let reason):
            return "Speech synthesis failed: \(reason)"

        case .audioSessionConfigurationFailed(let reason):
            return "Audio session configuration failed: \(reason)"

        case .voiceNotFound(let identifier):
            return "Voice not found: \(identifier)"

        case .speechDisabled:
            return "Speech announcements are disabled"

        case .emptyAnnouncement:
            return "Announcement text is empty"

        case .audioDuckingFailed(let reason):
            return "Audio ducking failed: \(reason)"
        }
    }
}
