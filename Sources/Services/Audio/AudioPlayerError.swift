//
//  AudioPlayerError.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation
import AVFoundation

/// Errors that can occur during audio playback operations.
///
/// This enum provides structured error handling for the AudioPlayerService,
/// covering initialization, playback, seeking, and resource loading failures.
public enum AudioPlayerError: Error, Equatable, Sendable {

    // MARK: - Initialization Errors

    /// Failed to configure the audio session.
    ///
    /// - Parameter reason: Description of why the session configuration failed.
    case audioSessionConfigurationFailed(reason: String)

    /// Failed to activate the audio session.
    ///
    /// - Parameter reason: Description of why activation failed.
    case audioSessionActivationFailed(reason: String)

    // MARK: - Playback Errors

    /// No item is currently loaded for playback.
    case noCurrentItem

    /// The playlist is empty and no items can be played.
    case emptyPlaylist

    /// The requested item index is out of bounds.
    ///
    /// - Parameters:
    ///   - index: The requested index.
    ///   - count: The actual number of items in the playlist.
    case invalidItemIndex(index: Int, count: Int)

    /// The media item failed to load.
    ///
    /// - Parameters:
    ///   - title: The title of the failed item.
    ///   - reason: Description of why loading failed.
    case itemLoadFailed(title: String?, reason: String)

    /// The player item status indicates a failure.
    ///
    /// - Parameters:
    ///   - title: The title of the failed item.
    ///   - error: The underlying AVPlayerItem error, if available.
    case itemPlaybackFailed(title: String?, error: String?)

    /// Playback was interrupted by the system (e.g., phone call).
    ///
    /// - Parameter reason: The interruption type description.
    case playbackInterrupted(reason: String)

    // MARK: - Media URL Errors

    /// The episode does not have a valid media URL.
    ///
    /// - Parameter episodeTitle: The title of the episode missing a media URL.
    case missingMediaURL(episodeTitle: String?)

    /// The media URL is invalid or malformed.
    ///
    /// - Parameter urlString: The invalid URL string.
    case invalidMediaURL(urlString: String)

    /// The cached media file could not be found.
    ///
    /// - Parameter path: The expected cache path.
    case cachedFileNotFound(path: String)

    // MARK: - Seeking Errors

    /// A seek operation failed.
    ///
    /// - Parameter reason: Description of why the seek failed.
    case seekFailed(reason: String)

    /// The requested seek position is invalid.
    ///
    /// - Parameters:
    ///   - position: The requested position in seconds.
    ///   - duration: The total duration of the item in seconds.
    case invalidSeekPosition(position: TimeInterval, duration: TimeInterval)

    // MARK: - Rate Errors

    /// The requested playback rate is outside the valid range.
    ///
    /// - Parameters:
    ///   - rate: The requested rate.
    ///   - validRange: The range of valid rates.
    case invalidPlaybackRate(rate: Float, validRange: ClosedRange<Float>)

    // MARK: - State Errors

    /// The player is in an unexpected state for the requested operation.
    ///
    /// - Parameters:
    ///   - expected: The expected state.
    ///   - actual: The actual state.
    case unexpectedPlayerState(expected: String, actual: String)

    /// The player has been deallocated or is no longer available.
    case playerUnavailable

    // MARK: - Persistence Errors

    /// Failed to persist playback position.
    ///
    /// - Parameter reason: Description of why persistence failed.
    case positionPersistenceFailed(reason: String)

    /// Failed to restore playback position.
    ///
    /// - Parameter reason: Description of why restoration failed.
    case positionRestorationFailed(reason: String)

    // MARK: - Unknown Errors

    /// An unknown error occurred.
    ///
    /// - Parameter underlyingError: The original error description.
    case unknown(String)
}

// MARK: - LocalizedError Conformance

extension AudioPlayerError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .audioSessionConfigurationFailed(let reason):
            return "Failed to configure audio session: \(reason)"

        case .audioSessionActivationFailed(let reason):
            return "Failed to activate audio session: \(reason)"

        case .noCurrentItem:
            return "No audio item is currently loaded"

        case .emptyPlaylist:
            return "The playlist is empty"

        case .invalidItemIndex(let index, let count):
            return "Invalid item index \(index). Playlist contains \(count) items"

        case .itemLoadFailed(let title, let reason):
            let itemName = title ?? "Unknown item"
            return "Failed to load '\(itemName)': \(reason)"

        case .itemPlaybackFailed(let title, let error):
            let itemName = title ?? "Unknown item"
            let errorMessage = error ?? "Unknown error"
            return "Playback failed for '\(itemName)': \(errorMessage)"

        case .playbackInterrupted(let reason):
            return "Playback was interrupted: \(reason)"

        case .missingMediaURL(let title):
            let itemName = title ?? "Unknown episode"
            return "'\(itemName)' does not have a media URL"

        case .invalidMediaURL(let urlString):
            return "Invalid media URL: \(urlString)"

        case .cachedFileNotFound(let path):
            return "Cached media file not found at: \(path)"

        case .seekFailed(let reason):
            return "Seek operation failed: \(reason)"

        case .invalidSeekPosition(let position, let duration):
            return "Invalid seek position \(position)s. Duration is \(duration)s"

        case .invalidPlaybackRate(let rate, let validRange):
            return "Invalid playback rate \(rate). Valid range is \(validRange.lowerBound)-\(validRange.upperBound)x"

        case .unexpectedPlayerState(let expected, let actual):
            return "Expected player state '\(expected)' but found '\(actual)'"

        case .playerUnavailable:
            return "Audio player is not available"

        case .positionPersistenceFailed(let reason):
            return "Failed to save playback position: \(reason)"

        case .positionRestorationFailed(let reason):
            return "Failed to restore playback position: \(reason)"

        case .unknown(let error):
            return "An unknown audio error occurred: \(error)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .audioSessionConfigurationFailed:
            return "The audio session could not be configured for background playback"

        case .audioSessionActivationFailed:
            return "The audio session could not be activated"

        case .noCurrentItem:
            return "No media has been loaded into the player"

        case .emptyPlaylist:
            return "There are no episodes available for playback"

        case .invalidItemIndex:
            return "The requested episode does not exist in the playlist"

        case .itemLoadFailed:
            return "The media file could not be loaded from the source"

        case .itemPlaybackFailed:
            return "The media file could not be played"

        case .playbackInterrupted:
            return "Another application required audio playback"

        case .missingMediaURL:
            return "The episode metadata does not include a download URL"

        case .invalidMediaURL:
            return "The URL format is not recognized"

        case .cachedFileNotFound:
            return "The downloaded file was moved or deleted"

        case .seekFailed:
            return "The player could not jump to the requested position"

        case .invalidSeekPosition:
            return "The requested position is outside the media duration"

        case .invalidPlaybackRate:
            return "The playback speed is outside supported limits"

        case .unexpectedPlayerState:
            return "The player is in a state that prevents the requested operation"

        case .playerUnavailable:
            return "The player instance is no longer valid"

        case .positionPersistenceFailed:
            return "The current playback position could not be saved to storage"

        case .positionRestorationFailed:
            return "The saved playback position could not be read"

        case .unknown:
            return "An unexpected error occurred during audio playback"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .audioSessionConfigurationFailed:
            return "Restart the app. If the problem persists, check if another app is controlling audio."

        case .audioSessionActivationFailed:
            return "Close other audio apps and try again."

        case .noCurrentItem:
            return "Select an episode from your playlist to play."

        case .emptyPlaylist:
            return "Add podcasts to your playlist before attempting playback."

        case .invalidItemIndex:
            return "Refresh the playlist and try selecting the episode again."

        case .itemLoadFailed:
            return "Check your internet connection or try playing a cached episode."

        case .itemPlaybackFailed:
            return "Try downloading the episode for offline playback."

        case .playbackInterrupted:
            return "Playback will resume when the interruption ends."

        case .missingMediaURL:
            return "Try refreshing the podcast feed to get updated episode information."

        case .invalidMediaURL:
            return "The podcast feed may contain invalid data. Try removing and re-adding the podcast."

        case .cachedFileNotFound:
            return "Re-download the episode for offline playback."

        case .seekFailed:
            return "Wait for the episode to load fully before seeking."

        case .invalidSeekPosition:
            return "Choose a position within the episode duration."

        case .invalidPlaybackRate:
            return "Use a playback speed between 0.5x and 2.0x."

        case .unexpectedPlayerState:
            return "Stop playback and start again."

        case .playerUnavailable:
            return "Restart the app to reinitialize the audio player."

        case .positionPersistenceFailed:
            return "Your playback position may not be saved. Try again later."

        case .positionRestorationFailed:
            return "Playback will start from the beginning."

        case .unknown:
            return "Try the operation again. If the problem persists, restart the app."
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension AudioPlayerError: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case .audioSessionConfigurationFailed(let reason):
            return "AudioPlayerError.audioSessionConfigurationFailed(reason: \"\(reason)\")"

        case .audioSessionActivationFailed(let reason):
            return "AudioPlayerError.audioSessionActivationFailed(reason: \"\(reason)\")"

        case .noCurrentItem:
            return "AudioPlayerError.noCurrentItem"

        case .emptyPlaylist:
            return "AudioPlayerError.emptyPlaylist"

        case .invalidItemIndex(let index, let count):
            return "AudioPlayerError.invalidItemIndex(index: \(index), count: \(count))"

        case .itemLoadFailed(let title, let reason):
            return "AudioPlayerError.itemLoadFailed(title: \(title ?? "nil"), reason: \"\(reason)\")"

        case .itemPlaybackFailed(let title, let error):
            return "AudioPlayerError.itemPlaybackFailed(title: \(title ?? "nil"), error: \(error ?? "nil"))"

        case .playbackInterrupted(let reason):
            return "AudioPlayerError.playbackInterrupted(reason: \"\(reason)\")"

        case .missingMediaURL(let title):
            return "AudioPlayerError.missingMediaURL(episodeTitle: \(title ?? "nil"))"

        case .invalidMediaURL(let urlString):
            return "AudioPlayerError.invalidMediaURL(urlString: \"\(urlString)\")"

        case .cachedFileNotFound(let path):
            return "AudioPlayerError.cachedFileNotFound(path: \"\(path)\")"

        case .seekFailed(let reason):
            return "AudioPlayerError.seekFailed(reason: \"\(reason)\")"

        case .invalidSeekPosition(let position, let duration):
            return "AudioPlayerError.invalidSeekPosition(position: \(position), duration: \(duration))"

        case .invalidPlaybackRate(let rate, let validRange):
            return "AudioPlayerError.invalidPlaybackRate(rate: \(rate), validRange: \(validRange))"

        case .unexpectedPlayerState(let expected, let actual):
            return "AudioPlayerError.unexpectedPlayerState(expected: \"\(expected)\", actual: \"\(actual)\")"

        case .playerUnavailable:
            return "AudioPlayerError.playerUnavailable"

        case .positionPersistenceFailed(let reason):
            return "AudioPlayerError.positionPersistenceFailed(reason: \"\(reason)\")"

        case .positionRestorationFailed(let reason):
            return "AudioPlayerError.positionRestorationFailed(reason: \"\(reason)\")"

        case .unknown(let error):
            return "AudioPlayerError.unknown(\"\(error)\")"
        }
    }
}

// MARK: - AVPlayerItem Status Convenience

extension AudioPlayerError {

    /// Creates an appropriate error from an AVPlayerItem status.
    ///
    /// - Parameters:
    ///   - item: The AVPlayerItem with the error status.
    ///   - title: Optional title of the item for error context.
    /// - Returns: An AudioPlayerError if the status indicates failure, nil otherwise.
    public static func fromPlayerItemStatus(
        _ item: AVPlayerItem,
        title: String?
    ) -> AudioPlayerError? {
        switch item.status {
        case .failed:
            let errorMessage = item.error?.localizedDescription
            return .itemPlaybackFailed(title: title, error: errorMessage)
        case .unknown, .readyToPlay:
            return nil
        @unknown default:
            return nil
        }
    }
}
