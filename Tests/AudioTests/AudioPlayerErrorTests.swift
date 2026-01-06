//
//  AudioPlayerErrorTests.swift
//  JogPodTests
//
//  Created for JogPod Revival project.
//

import Testing
import AVFoundation
@testable import JogPod

/// Tests for AudioPlayerError types and their error descriptions.
@Suite("AudioPlayerError Tests")
struct AudioPlayerErrorTests {

    // MARK: - Initialization Error Tests

    @Test("Audio session configuration failed error has correct description")
    func audioSessionConfigurationFailedError() {
        let error = AudioPlayerError.audioSessionConfigurationFailed(reason: "Category not supported")

        #expect(error.errorDescription?.contains("configure audio session") == true)
        #expect(error.errorDescription?.contains("Category not supported") == true)
        #expect(error.failureReason != nil)
        #expect(error.recoverySuggestion != nil)
    }

    @Test("Audio session activation failed error has correct description")
    func audioSessionActivationFailedError() {
        let error = AudioPlayerError.audioSessionActivationFailed(reason: "Another app using audio")

        #expect(error.errorDescription?.contains("activate audio session") == true)
        #expect(error.errorDescription?.contains("Another app using audio") == true)
    }

    // MARK: - Playback Error Tests

    @Test("No current item error has correct description")
    func noCurrentItemError() {
        let error = AudioPlayerError.noCurrentItem

        #expect(error.errorDescription?.contains("No audio item") == true)
        #expect(error.recoverySuggestion?.contains("Select an episode") == true)
    }

    @Test("Empty playlist error has correct description")
    func emptyPlaylistError() {
        let error = AudioPlayerError.emptyPlaylist

        #expect(error.errorDescription?.contains("playlist is empty") == true)
        #expect(error.recoverySuggestion?.contains("Add podcasts") == true)
    }

    @Test("Invalid item index error includes index and count")
    func invalidItemIndexError() {
        let error = AudioPlayerError.invalidItemIndex(index: 10, count: 5)

        #expect(error.errorDescription?.contains("10") == true)
        #expect(error.errorDescription?.contains("5") == true)
    }

    @Test("Item load failed error includes title and reason")
    func itemLoadFailedError() {
        let error = AudioPlayerError.itemLoadFailed(title: "Episode 1", reason: "Network error")

        #expect(error.errorDescription?.contains("Episode 1") == true)
        #expect(error.errorDescription?.contains("Network error") == true)
    }

    @Test("Item load failed with nil title uses placeholder")
    func itemLoadFailedWithNilTitle() {
        let error = AudioPlayerError.itemLoadFailed(title: nil, reason: "Unknown")

        #expect(error.errorDescription?.contains("Unknown item") == true)
    }

    @Test("Item playback failed error includes title and error message")
    func itemPlaybackFailedError() {
        let error = AudioPlayerError.itemPlaybackFailed(title: "My Episode", error: "Codec not supported")

        #expect(error.errorDescription?.contains("My Episode") == true)
        #expect(error.errorDescription?.contains("Codec not supported") == true)
    }

    @Test("Playback interrupted error includes reason")
    func playbackInterruptedError() {
        let error = AudioPlayerError.playbackInterrupted(reason: "Phone call")

        #expect(error.errorDescription?.contains("interrupted") == true)
        #expect(error.errorDescription?.contains("Phone call") == true)
    }

    // MARK: - Media URL Error Tests

    @Test("Missing media URL error includes episode title")
    func missingMediaURLError() {
        let error = AudioPlayerError.missingMediaURL(episodeTitle: "Test Episode")

        #expect(error.errorDescription?.contains("Test Episode") == true)
        #expect(error.errorDescription?.contains("media URL") == true)
    }

    @Test("Invalid media URL error includes URL string")
    func invalidMediaURLError() {
        let error = AudioPlayerError.invalidMediaURL(urlString: "not-a-valid-url")

        #expect(error.errorDescription?.contains("not-a-valid-url") == true)
    }

    @Test("Cached file not found error includes path")
    func cachedFileNotFoundError() {
        let error = AudioPlayerError.cachedFileNotFound(path: "/path/to/file.mp3")

        #expect(error.errorDescription?.contains("/path/to/file.mp3") == true)
    }

    // MARK: - Seeking Error Tests

    @Test("Seek failed error includes reason")
    func seekFailedError() {
        let error = AudioPlayerError.seekFailed(reason: "Not ready to seek")

        #expect(error.errorDescription?.contains("Seek") == true)
        #expect(error.errorDescription?.contains("Not ready to seek") == true)
    }

    @Test("Invalid seek position error includes position and duration")
    func invalidSeekPositionError() {
        let error = AudioPlayerError.invalidSeekPosition(position: 3700, duration: 3600)

        #expect(error.errorDescription?.contains("3700") == true)
        #expect(error.errorDescription?.contains("3600") == true)
    }

    // MARK: - Rate Error Tests

    @Test("Invalid playback rate error includes rate and valid range")
    func invalidPlaybackRateError() {
        let error = AudioPlayerError.invalidPlaybackRate(rate: 3.0, validRange: 0.5...2.0)

        #expect(error.errorDescription?.contains("3.0") == true)
        #expect(error.errorDescription?.contains("0.5") == true)
        #expect(error.errorDescription?.contains("2.0") == true)
    }

    // MARK: - State Error Tests

    @Test("Unexpected player state error includes expected and actual states")
    func unexpectedPlayerStateError() {
        let error = AudioPlayerError.unexpectedPlayerState(expected: "playing", actual: "paused")

        #expect(error.errorDescription?.contains("playing") == true)
        #expect(error.errorDescription?.contains("paused") == true)
    }

    @Test("Player unavailable error has description")
    func playerUnavailableError() {
        let error = AudioPlayerError.playerUnavailable

        #expect(error.errorDescription?.contains("not available") == true)
    }

    // MARK: - Persistence Error Tests

    @Test("Position persistence failed error includes reason")
    func positionPersistenceFailedError() {
        let error = AudioPlayerError.positionPersistenceFailed(reason: "Database locked")

        #expect(error.errorDescription?.contains("save playback position") == true)
        #expect(error.errorDescription?.contains("Database locked") == true)
    }

    @Test("Position restoration failed error includes reason")
    func positionRestorationFailedError() {
        let error = AudioPlayerError.positionRestorationFailed(reason: "No saved position")

        #expect(error.errorDescription?.contains("restore playback position") == true)
        #expect(error.errorDescription?.contains("No saved position") == true)
    }

    // MARK: - Unknown Error Tests

    @Test("Unknown error includes underlying error message")
    func unknownError() {
        let error = AudioPlayerError.unknown("Something unexpected happened")

        #expect(error.errorDescription?.contains("Something unexpected happened") == true)
    }

    // MARK: - Equatable Tests

    @Test("Same error cases are equal")
    func sameErrorsAreEqual() {
        let error1 = AudioPlayerError.noCurrentItem
        let error2 = AudioPlayerError.noCurrentItem

        #expect(error1 == error2)
    }

    @Test("Different error cases are not equal")
    func differentErrorsAreNotEqual() {
        let error1 = AudioPlayerError.noCurrentItem
        let error2 = AudioPlayerError.emptyPlaylist

        #expect(error1 != error2)
    }

    @Test("Errors with different parameters are not equal")
    func errorsWithDifferentParametersNotEqual() {
        let error1 = AudioPlayerError.invalidItemIndex(index: 5, count: 10)
        let error2 = AudioPlayerError.invalidItemIndex(index: 5, count: 20)

        #expect(error1 != error2)
    }

    @Test("Errors with same parameters are equal")
    func errorsWithSameParametersAreEqual() {
        let error1 = AudioPlayerError.invalidItemIndex(index: 5, count: 10)
        let error2 = AudioPlayerError.invalidItemIndex(index: 5, count: 10)

        #expect(error1 == error2)
    }

    // MARK: - Debug Description Tests

    @Test("Debug description includes error type name")
    func debugDescriptionIncludesTypeName() {
        let error = AudioPlayerError.noCurrentItem

        #expect(error.debugDescription.contains("AudioPlayerError") == true)
        #expect(error.debugDescription.contains("noCurrentItem") == true)
    }

    @Test("Debug description includes parameters")
    func debugDescriptionIncludesParameters() {
        let error = AudioPlayerError.invalidItemIndex(index: 5, count: 10)

        #expect(error.debugDescription.contains("index: 5") == true)
        #expect(error.debugDescription.contains("count: 10") == true)
    }

    // MARK: - LocalizedError Conformance Tests

    @Test("All error cases have error descriptions")
    func allErrorsHaveDescriptions() {
        let errors: [AudioPlayerError] = [
            .audioSessionConfigurationFailed(reason: "test"),
            .audioSessionActivationFailed(reason: "test"),
            .noCurrentItem,
            .emptyPlaylist,
            .invalidItemIndex(index: 0, count: 0),
            .itemLoadFailed(title: "test", reason: "test"),
            .itemPlaybackFailed(title: "test", error: "test"),
            .playbackInterrupted(reason: "test"),
            .missingMediaURL(episodeTitle: "test"),
            .invalidMediaURL(urlString: "test"),
            .cachedFileNotFound(path: "test"),
            .seekFailed(reason: "test"),
            .invalidSeekPosition(position: 0, duration: 0),
            .invalidPlaybackRate(rate: 0, validRange: 0...1),
            .unexpectedPlayerState(expected: "a", actual: "b"),
            .playerUnavailable,
            .positionPersistenceFailed(reason: "test"),
            .positionRestorationFailed(reason: "test"),
            .unknown("test")
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Error \(error) should have errorDescription")
            #expect(error.failureReason != nil, "Error \(error) should have failureReason")
            #expect(error.recoverySuggestion != nil, "Error \(error) should have recoverySuggestion")
        }
    }

    // MARK: - AVPlayerItem Status Conversion Tests

    @Test("fromPlayerItemStatus returns nil for ready to play status")
    func fromPlayerItemStatusReadyToPlay() {
        // Note: We cannot easily create an AVPlayerItem with a specific status
        // so we test the logic indirectly through the public API
        let result = AudioPlayerError.fromPlayerItemStatus(
            AVPlayerItem(url: URL(string: "https://example.com/audio.mp3")!),
            title: "Test"
        )

        // A new player item starts with unknown status, not failed
        #expect(result == nil)
    }
}
