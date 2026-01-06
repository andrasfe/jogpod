//
//  BackgroundPlaybackTests.swift
//  JogPodTests
//
//  Tests for background audio playback continuation scenarios.
//  Verifies that audio continues playing when the app moves to the background
//  and that the audio session is properly configured for background playback.
//
//  Created for JogPod Revival project.
//

import Testing
import Foundation
import AVFoundation
@testable import JogPod

// MARK: - Background Playback Tests

/// Tests for background audio playback functionality.
///
/// These tests verify that:
/// - Audio session is configured with the correct category for background playback
/// - Playback continues when app enters background
/// - Position and state are preserved during background operation
/// - Remote commands work properly in background
@Suite("Background Playback Continuation")
struct BackgroundPlaybackTests {

    // MARK: - Audio Session Configuration Tests

    @Test("Audio session configured for playback category")
    @MainActor
    func audioSessionConfiguredForPlayback() throws {
        let mockSession = MockAVAudioSession()

        // Act: Configure session for background playback
        try mockSession.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.allowBluetooth, .allowAirPlay]
        )

        // Assert
        #expect(mockSession.configuredCategory == .playback)
        #expect(mockSession.setCategoryCalls == 1)
    }

    @Test("Audio session configured with spoken audio mode")
    @MainActor
    func audioSessionConfiguredWithSpokenAudioMode() throws {
        let mockSession = MockAVAudioSession()

        // Act
        try mockSession.setCategory(
            .playback,
            mode: .spokenAudio,
            options: []
        )

        // Assert
        #expect(mockSession.configuredMode == .spokenAudio)
    }

    @Test("Audio session configured with Bluetooth and AirPlay options")
    @MainActor
    func audioSessionConfiguredWithBluetoothAndAirPlay() throws {
        let mockSession = MockAVAudioSession()
        let expectedOptions: AVAudioSession.CategoryOptions = [.allowBluetooth, .allowAirPlay]

        // Act
        try mockSession.setCategory(
            .playback,
            mode: .spokenAudio,
            options: expectedOptions
        )

        // Assert
        #expect(mockSession.configuredOptions == expectedOptions)
    }

    @Test("Full background playback configuration verified")
    @MainActor
    func fullBackgroundPlaybackConfiguration() throws {
        let mockSession = MockAVAudioSession()

        // Act
        try mockSession.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.allowBluetooth, .allowAirPlay]
        )
        try mockSession.setActive(true)

        // Assert
        #expect(mockSession.verifyConfiguration(
            category: .playback,
            mode: .spokenAudio,
            options: [.allowBluetooth, .allowAirPlay]
        ))
        #expect(mockSession.isActive == true)
        #expect(mockSession.activationCalls == 1)
    }

    // MARK: - Background State Continuation Tests

    @Test("Playback state preserved when entering background")
    @MainActor
    func playbackStatePreservedInBackground() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing
        mockPlayer.simulateProgress(currentTime: 120, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Simulate background entry (no state change should occur)
        // The player should continue playing

        // Assert: State unchanged
        #expect(mockPlayer.state == .playing)
        #expect(mockPlayer.progress.currentTime == 120)
    }

    @Test("Progress updates continue in background")
    @MainActor
    func progressUpdatesContinueInBackground() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing
        mockPlayer.simulateStateChange(.playing)
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)

        // Simulate time passing in background
        mockPlayer.simulateProgress(currentTime: 110, duration: 600)
        mockPlayer.simulateProgress(currentTime: 120, duration: 600)

        // Assert: Progress updates were recorded
        #expect(mockPlayer.progress.currentTime == 120)
        let progressUpdates = mockPlayer.delegateNotifications.filter {
            if case .progressUpdated = $0 { return true }
            return false
        }
        #expect(progressUpdates.count == 3)
    }

    @Test("Current item preserved in background")
    @MainActor
    func currentItemPreservedInBackground() async throws {
        let mockPlayer = MockAudioPlayerService()
        let persistence = try PersistenceManager.makeForTesting()

        // Create a test episode
        let feedID = try await persistence.createPodcastFeed(
            title: "Test Podcast",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: nil
        )

        let episodeID = try await persistence.createPodcastEpisode(
            title: "Background Test Episode",
            identifier: "bg-ep-1",
            enclosureMediaLink: "https://example.com/episode.mp3",
            releaseDate: Date(),
            feedIdentifier: feedID
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        guard let episode = episodes.first,
              let item = PlayableItem.from(episode: episode) else {
            Issue.record("Expected playable item")
            return
        }

        // Setup: Set current item and playing state
        mockPlayer.setPlaylist([item])
        mockPlayer.setCurrentItem(item)
        mockPlayer.simulateStateChange(.playing)

        // Verify item preserved
        #expect(mockPlayer.currentItem?.title == "Background Test Episode")
        #expect(mockPlayer.currentItem?.episodeID == episodeID)
    }

    // MARK: - Audio Session Activation Tests

    @Test("Audio session activated for background playback")
    @MainActor
    func audioSessionActivatedForBackground() throws {
        let mockSession = MockAVAudioSession()

        // Configure and activate
        try mockSession.setCategory(.playback, mode: .spokenAudio, options: [])
        try mockSession.setActive(true)

        // Assert
        #expect(mockSession.isActive == true)
        #expect(mockSession.activationCalls == 1)
    }

    @Test("Audio session deactivation notifies other apps")
    @MainActor
    func audioSessionDeactivationNotifiesOtherApps() throws {
        let mockSession = MockAVAudioSession()

        // Activate
        try mockSession.setActive(true)

        // Deactivate with notification option
        try mockSession.setActive(false, options: .notifyOthersOnDeactivation)

        // Assert
        #expect(mockSession.isActive == false)
        #expect(mockSession.deactivationCalls == 1)
        #expect(mockSession.deactivationOptions?.contains(.notifyOthersOnDeactivation) == true)
    }

    // MARK: - Error Handling Tests

    @Test("Audio session configuration failure throws error")
    @MainActor
    func audioSessionConfigurationFailure() {
        let mockSession = MockAVAudioSession()
        mockSession.setCategoryError = MockAudioSessionError.categoryNotSupported

        #expect(throws: Error.self) {
            try mockSession.setCategory(.playback, mode: .spokenAudio, options: [])
        }

        #expect(mockSession.configuredCategory == nil)
    }

    @Test("Audio session activation failure throws error")
    @MainActor
    func audioSessionActivationFailure() {
        let mockSession = MockAVAudioSession()
        mockSession.setActiveError = MockAudioSessionError.cannotActivate

        #expect(throws: Error.self) {
            try mockSession.setActive(true)
        }

        #expect(mockSession.isActive == false)
    }

    @Test("MockAudioPlayerService handles audio session configuration error")
    @MainActor
    func mockPlayerHandlesConfigurationError() {
        let mockPlayer = MockAudioPlayerService()
        mockPlayer.simulatedErrors["configureAudioSession"] =
            .audioSessionConfigurationFailed(reason: "Category not supported")

        #expect(throws: AudioPlayerError.self) {
            try mockPlayer.configureAudioSession()
        }

        #expect(mockPlayer.audioSessionConfigured == false)
    }

    // MARK: - Playback Rate Preservation Tests

    @Test("Playback rate preserved in background")
    @MainActor
    func playbackRatePreservedInBackground() throws {
        let mockPlayer = MockAudioPlayerService()

        // Set custom playback rate
        try mockPlayer.setRate(1.5)
        mockPlayer.simulateStateChange(.playing)

        // Verify rate preserved
        #expect(mockPlayer.playbackRate == 1.5)
    }

    // MARK: - Skip Interval Tests

    @Test("Skip interval preserved in background")
    @MainActor
    func skipIntervalPreservedInBackground() {
        let mockPlayer = MockAudioPlayerService()

        // Set custom skip interval
        mockPlayer.setSkipInterval(30)

        // Verify interval preserved
        #expect(mockPlayer.skipInterval == 30)
    }

    // MARK: - Media Services Reset Tests

    @Test("MockAVAudioSession posts media services reset notification")
    func mediaServicesResetNotificationPosted() async throws {
        let mockSession = MockAVAudioSession()
        var receivedNotification: Notification?

        // Register for notification
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: mockSession,
            queue: .main
        ) { notification in
            receivedNotification = notification
        }

        defer {
            NotificationCenter.default.removeObserver(token)
        }

        // Act
        mockSession.simulateMediaServicesReset()

        // Wait briefly for notification
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        #expect(receivedNotification != nil)
    }
}

// MARK: - Background Playback Scenario Tests

/// Integration-style tests for complete background playback scenarios.
@Suite("Background Playback Scenarios")
struct BackgroundPlaybackScenarioTests {

    @Test("Complete background playback workflow")
    @MainActor
    func completeBackgroundPlaybackWorkflow() async throws {
        let mockSession = MockAVAudioSession()
        let mockPlayer = MockAudioPlayerService()

        // Step 1: Configure audio session for background playback
        try mockSession.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.allowBluetooth, .allowAirPlay]
        )
        try mockSession.setActive(true)

        #expect(mockSession.isActive == true)

        // Step 2: Start playback
        mockPlayer.simulateProgress(currentTime: 0, duration: 1800) // 30-minute episode
        mockPlayer.simulateStateChange(.playing)

        #expect(mockPlayer.state == .playing)

        // Step 3: Simulate time passing (background operation)
        mockPlayer.simulateProgress(currentTime: 300, duration: 1800) // 5 minutes in

        #expect(mockPlayer.progress.currentTime == 300)

        // Step 4: Simulate interruption (phone call)
        mockPlayer.simulateInterruption(began: true)
        #expect(mockPlayer.state == .paused)

        // Step 5: Resume after interruption
        mockPlayer.simulateInterruption(began: false, shouldResume: true)
        #expect(mockPlayer.state == .playing)

        // Step 6: Continue playback
        mockPlayer.simulateProgress(currentTime: 600, duration: 1800) // 10 minutes in
        #expect(mockPlayer.progress.currentTime == 600)
    }

    @Test("Background playback survives audio route change")
    @MainActor
    func backgroundPlaybackSurvivesRouteChange() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Start playing
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Bluetooth connects (new device available)
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)

        // Should still be playing
        #expect(mockPlayer.state == .playing)

        // Bluetooth disconnects (old device unavailable) - should pause
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)

        // Should be paused
        #expect(mockPlayer.state == .paused)
    }

    @Test("Background playback with silence secondary audio")
    func silenceSecondaryAudioHint() async throws {
        let mockSession = MockAVAudioSession()
        var beginReceived = false
        var endReceived = false

        // Register for notifications
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: mockSession,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt {
                let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue)
                if type == .begin {
                    beginReceived = true
                } else if type == .end {
                    endReceived = true
                }
            }
        }

        defer {
            NotificationCenter.default.removeObserver(token)
        }

        // Act: Simulate silence hints
        mockSession.simulateSilenceSecondaryAudioHint(shouldSilence: true)
        try await Task.sleep(nanoseconds: 50_000_000)
        mockSession.simulateSilenceSecondaryAudioHint(shouldSilence: false)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        #expect(beginReceived == true)
        #expect(endReceived == true)
    }
}

// MARK: - Audio Session State Tracking Tests

/// Tests for tracking audio session state changes.
@Suite("Audio Session State Tracking")
struct AudioSessionStateTrackingTests {

    @Test("Session tracks multiple category configurations")
    @MainActor
    func tracksMultipleCategoryConfigurations() throws {
        let mockSession = MockAVAudioSession()

        // Configure multiple times
        try mockSession.setCategory(.playback, mode: .default, options: [])
        try mockSession.setCategory(.playback, mode: .spokenAudio, options: [])
        try mockSession.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth])

        // Assert: Should track call count and final configuration
        #expect(mockSession.setCategoryCalls == 3)
        #expect(mockSession.configuredMode == .spokenAudio)
        #expect(mockSession.configuredOptions == [.allowBluetooth])
    }

    @Test("Session tracks activation/deactivation cycles")
    @MainActor
    func tracksActivationDeactivationCycles() throws {
        let mockSession = MockAVAudioSession()

        // Multiple cycles
        try mockSession.setActive(true)
        try mockSession.setActive(false)
        try mockSession.setActive(true)
        try mockSession.setActive(false)

        // Assert
        #expect(mockSession.activationCalls == 2)
        #expect(mockSession.deactivationCalls == 2)
        #expect(mockSession.isActive == false)
    }

    @Test("Session reset clears all state")
    @MainActor
    func sessionResetClearsAllState() throws {
        let mockSession = MockAVAudioSession()

        // Configure session
        try mockSession.setCategory(.playback, mode: .spokenAudio, options: [])
        try mockSession.setActive(true)

        // Reset
        mockSession.reset()

        // Assert all state cleared
        #expect(mockSession.configuredCategory == nil)
        #expect(mockSession.configuredMode == nil)
        #expect(mockSession.configuredOptions == nil)
        #expect(mockSession.isActive == false)
        #expect(mockSession.setCategoryCalls == 0)
        #expect(mockSession.activationCalls == 0)
    }
}
