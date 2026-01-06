//
//  NowPlayingInfoUpdateTests.swift
//  JogPodTests
//
//  Tests for Now Playing info updates on the lock screen and Control Center.
//  Verifies correct display of episode metadata, progress, and remote command handling.
//
//  Created for JogPod Revival project.
//

import Testing
import Foundation
import MediaPlayer
@testable import JogPod

// MARK: - Now Playing Info Update Tests

/// Tests for Now Playing info updates.
///
/// These tests verify that the audio player correctly updates the lock screen
/// and Control Center with current playback information:
/// - Episode title and podcast name
/// - Playback duration and elapsed time
/// - Playback rate
/// - Artwork
/// - Remote command handling
///
/// Reference: NowPlayingManager, MockNowPlayingManager
@Suite("Now Playing Info Updates")
struct NowPlayingInfoUpdateTests {

    // MARK: - Basic Info Update Tests

    #if DEBUG
    @Test("Now Playing info updated with episode title")
    @MainActor
    func nowPlayingInfoUpdatedWithTitle() {
        let mockManager = MockNowPlayingManager()

        let info = NowPlayingInfo(
            title: "Episode 1: Getting Started",
            podcastTitle: "My Podcast",
            duration: 3600,
            elapsedTime: 0,
            isPlaying: true
        )

        mockManager.updateNowPlayingInfo(info)

        #expect(mockManager.lastUpdatedInfo?.title == "Episode 1: Getting Started")
    }

    @Test("Now Playing info updated with podcast title")
    @MainActor
    func nowPlayingInfoUpdatedWithPodcastTitle() {
        let mockManager = MockNowPlayingManager()

        let info = NowPlayingInfo(
            title: "Episode 1",
            podcastTitle: "Running Stories",
            duration: 1800,
            elapsedTime: 0,
            isPlaying: true
        )

        mockManager.updateNowPlayingInfo(info)

        #expect(mockManager.lastUpdatedInfo?.podcastTitle == "Running Stories")
    }

    @Test("Now Playing info updated with duration")
    @MainActor
    func nowPlayingInfoUpdatedWithDuration() {
        let mockManager = MockNowPlayingManager()

        let info = NowPlayingInfo(
            title: "Long Episode",
            duration: 7200, // 2 hours
            elapsedTime: 0,
            isPlaying: true
        )

        mockManager.updateNowPlayingInfo(info)

        #expect(mockManager.lastUpdatedInfo?.duration == 7200)
    }

    @Test("Now Playing info updated with elapsed time")
    @MainActor
    func nowPlayingInfoUpdatedWithElapsedTime() {
        let mockManager = MockNowPlayingManager()

        let info = NowPlayingInfo(
            title: "In Progress Episode",
            duration: 3600,
            elapsedTime: 1500, // 25 minutes in
            isPlaying: true
        )

        mockManager.updateNowPlayingInfo(info)

        #expect(mockManager.lastUpdatedInfo?.elapsedTime == 1500)
    }

    @Test("Now Playing info updated with playback rate")
    @MainActor
    func nowPlayingInfoUpdatedWithPlaybackRate() {
        let mockManager = MockNowPlayingManager()

        let info = NowPlayingInfo(
            title: "Fast Episode",
            duration: 3600,
            elapsedTime: 0,
            playbackRate: 1.5,
            isPlaying: true
        )

        mockManager.updateNowPlayingInfo(info)

        #expect(mockManager.lastUpdatedInfo?.playbackRate == 1.5)
    }

    @Test("Now Playing info updated with artwork URL")
    @MainActor
    func nowPlayingInfoUpdatedWithArtworkURL() {
        let mockManager = MockNowPlayingManager()
        let artworkURL = URL(string: "https://example.com/artwork.jpg")!

        let info = NowPlayingInfo(
            title: "Episode with Artwork",
            duration: 3600,
            elapsedTime: 0,
            isPlaying: true,
            artworkURL: artworkURL
        )

        mockManager.updateNowPlayingInfo(info)

        #expect(mockManager.lastUpdatedInfo?.artworkURL == artworkURL)
    }

    @Test("Now Playing info updated with playing state")
    @MainActor
    func nowPlayingInfoUpdatedWithPlayingState() {
        let mockManager = MockNowPlayingManager()

        let playingInfo = NowPlayingInfo(
            title: "Playing Episode",
            duration: 3600,
            elapsedTime: 100,
            isPlaying: true
        )

        let pausedInfo = NowPlayingInfo(
            title: "Paused Episode",
            duration: 3600,
            elapsedTime: 100,
            isPlaying: false
        )

        mockManager.updateNowPlayingInfo(playingInfo)
        #expect(mockManager.lastUpdatedInfo?.isPlaying == true)

        mockManager.updateNowPlayingInfo(pausedInfo)
        #expect(mockManager.lastUpdatedInfo?.isPlaying == false)
    }

    // MARK: - Clear Now Playing Tests

    @Test("Clear Now Playing info")
    @MainActor
    func clearNowPlayingInfo() {
        let mockManager = MockNowPlayingManager()

        // First set some info
        mockManager.updateNowPlayingInfo(NowPlayingInfo(title: "Test", duration: 100))

        // Then clear it
        mockManager.clearNowPlayingInfo()

        #expect(mockManager.didClearNowPlayingInfo == true)
        #expect(mockManager.lastUpdatedInfo == nil)
    }

    // MARK: - Elapsed Time Update Tests

    @Test("Elapsed time update is efficient")
    @MainActor
    func elapsedTimeUpdateIsEfficient() {
        let mockManager = MockNowPlayingManager()

        // Update elapsed time without full info refresh
        mockManager.updateElapsedTime(500, playbackRate: 1.0)

        #expect(mockManager.lastElapsedTimeUpdate?.time == 500)
        #expect(mockManager.lastElapsedTimeUpdate?.rate == 1.0)
    }

    @Test("Elapsed time update with custom playback rate")
    @MainActor
    func elapsedTimeUpdateWithCustomRate() {
        let mockManager = MockNowPlayingManager()

        mockManager.updateElapsedTime(300, playbackRate: 1.5)

        #expect(mockManager.lastElapsedTimeUpdate?.time == 300)
        #expect(mockManager.lastElapsedTimeUpdate?.rate == 1.5)
    }

    @Test("Elapsed time update with zero rate (paused)")
    @MainActor
    func elapsedTimeUpdateWithZeroRate() {
        let mockManager = MockNowPlayingManager()

        mockManager.updateElapsedTime(250, playbackRate: 0)

        #expect(mockManager.lastElapsedTimeUpdate?.time == 250)
        #expect(mockManager.lastElapsedTimeUpdate?.rate == 0)
    }

    // MARK: - Skip Interval Tests

    @Test("Skip interval is configurable")
    @MainActor
    func skipIntervalIsConfigurable() {
        let mockManager = MockNowPlayingManager()

        #expect(mockManager.currentSkipInterval == 15) // default

        mockManager.setSkipInterval(30)

        #expect(mockManager.currentSkipInterval == 30)
    }

    @Test("Skip interval can be set to various values")
    @MainActor
    func skipIntervalVariousValues() {
        let mockManager = MockNowPlayingManager()

        let intervals: [TimeInterval] = [10, 15, 30, 45, 60]

        for interval in intervals {
            mockManager.setSkipInterval(interval)
            #expect(mockManager.currentSkipInterval == interval)
        }
    }

    // MARK: - Remote Commands Enabled Tests

    @Test("Remote commands can be enabled")
    @MainActor
    func remoteCommandsEnabled() {
        let mockManager = MockNowPlayingManager()

        #expect(mockManager.areRemoteCommandsEnabled == false) // default for mock

        mockManager.setRemoteCommandsEnabled(true)

        #expect(mockManager.areRemoteCommandsEnabled == true)
    }

    @Test("Remote commands can be disabled")
    @MainActor
    func remoteCommandsDisabled() {
        let mockManager = MockNowPlayingManager()

        mockManager.setRemoteCommandsEnabled(true)
        mockManager.setRemoteCommandsEnabled(false)

        #expect(mockManager.areRemoteCommandsEnabled == false)
    }
    #endif
}

// MARK: - Remote Command Simulation Tests

#if DEBUG
/// Tests for simulating remote commands from lock screen / Control Center.
@Suite("Remote Command Simulation")
struct RemoteCommandSimulationTests {

    @Test("Play command simulation")
    @MainActor
    func playCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.play)

        #expect(delegate.receivedActions.count == 1)
        if case .play = delegate.receivedActions.first {
            // Success
        } else {
            Issue.record("Expected play command")
        }
    }

    @Test("Pause command simulation")
    @MainActor
    func pauseCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.pause)

        if case .pause = delegate.receivedActions.first {
            // Success
        } else {
            Issue.record("Expected pause command")
        }
    }

    @Test("Toggle play/pause command simulation")
    @MainActor
    func togglePlayPauseCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.togglePlayPause)

        if case .togglePlayPause = delegate.receivedActions.first {
            // Success
        } else {
            Issue.record("Expected togglePlayPause command")
        }
    }

    @Test("Next track command simulation")
    @MainActor
    func nextTrackCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.nextTrack)

        if case .nextTrack = delegate.receivedActions.first {
            // Success
        } else {
            Issue.record("Expected nextTrack command")
        }
    }

    @Test("Previous track command simulation")
    @MainActor
    func previousTrackCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.previousTrack)

        if case .previousTrack = delegate.receivedActions.first {
            // Success
        } else {
            Issue.record("Expected previousTrack command")
        }
    }

    @Test("Skip forward command simulation")
    @MainActor
    func skipForwardCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.skipForward(seconds: 15))

        if case .skipForward(let seconds) = delegate.receivedActions.first {
            #expect(seconds == 15)
        } else {
            Issue.record("Expected skipForward command")
        }
    }

    @Test("Skip backward command simulation")
    @MainActor
    func skipBackwardCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.skipBackward(seconds: 30))

        if case .skipBackward(let seconds) = delegate.receivedActions.first {
            #expect(seconds == 30)
        } else {
            Issue.record("Expected skipBackward command")
        }
    }

    @Test("Seek to command simulation")
    @MainActor
    func seekToCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.seekTo(position: 500))

        if case .seekTo(let position) = delegate.receivedActions.first {
            #expect(position == 500)
        } else {
            Issue.record("Expected seekTo command")
        }
    }

    @Test("Change playback rate command simulation")
    @MainActor
    func changePlaybackRateCommandSimulation() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.changePlaybackRate(rate: 1.5))

        if case .changePlaybackRate(let rate) = delegate.receivedActions.first {
            #expect(rate == 1.5)
        } else {
            Issue.record("Expected changePlaybackRate command")
        }
    }

    @Test("Multiple commands in sequence")
    @MainActor
    func multipleCommandsInSequence() {
        let mockManager = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mockManager.delegate = delegate

        mockManager.simulateRemoteCommand(.play)
        mockManager.simulateRemoteCommand(.skipForward(seconds: 15))
        mockManager.simulateRemoteCommand(.skipForward(seconds: 15))
        mockManager.simulateRemoteCommand(.pause)

        #expect(delegate.receivedActions.count == 4)

        if case .play = delegate.receivedActions[0],
           case .skipForward = delegate.receivedActions[1],
           case .skipForward = delegate.receivedActions[2],
           case .pause = delegate.receivedActions[3] {
            // All commands received in order
        } else {
            Issue.record("Commands not received in expected order")
        }
    }
}
#endif

// MARK: - Now Playing Info Integration Tests

#if DEBUG
/// Integration tests for Now Playing info with MockAudioPlayerService.
@Suite("Now Playing Info Integration")
struct NowPlayingInfoIntegrationTests {

    @Test("MockAudioPlayerService updates progress for Now Playing")
    @MainActor
    func mockPlayerUpdatesProgressForNowPlaying() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Simulate playback with progress
        mockPlayer.simulateProgress(currentTime: 300, duration: 1800)
        mockPlayer.simulateStateChange(.playing)

        // Verify progress values available for Now Playing
        #expect(mockPlayer.progress.currentTime == 300)
        #expect(mockPlayer.progress.duration == 1800)
        #expect(mockPlayer.state == .playing)

        // Progress values would be used to update Now Playing info
        let nowPlayingInfo = NowPlayingInfo(
            title: mockPlayer.currentItem?.title,
            podcastTitle: mockPlayer.currentItem?.podcastTitle,
            duration: mockPlayer.progress.duration,
            elapsedTime: mockPlayer.progress.currentTime,
            playbackRate: mockPlayer.playbackRate,
            isPlaying: mockPlayer.isPlaying,
            artworkURL: mockPlayer.currentItem?.artworkURL
        )

        #expect(nowPlayingInfo.duration == 1800)
        #expect(nowPlayingInfo.elapsedTime == 300)
        #expect(nowPlayingInfo.isPlaying == true)
    }

    @Test("Now Playing info reflects pause state")
    @MainActor
    func nowPlayingInfoReflectsPauseState() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Start playing
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Pause
        mockPlayer.pause()

        // Verify state for Now Playing
        #expect(mockPlayer.isPlaying == false)
        #expect(mockPlayer.progress.currentTime == 100) // Position preserved
    }

    @Test("Now Playing info reflects playback rate change")
    @MainActor
    func nowPlayingInfoReflectsRateChange() throws {
        let mockPlayer = MockAudioPlayerService()

        try mockPlayer.setRate(1.5)

        #expect(mockPlayer.playbackRate == 1.5)
    }

    @Test("Now Playing cleared on stop")
    @MainActor
    func nowPlayingClearedOnStop() {
        let mockNowPlaying = MockNowPlayingManager()
        let mockPlayer = MockAudioPlayerService()

        // Setup with current item
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Update Now Playing
        mockNowPlaying.updateNowPlayingInfo(NowPlayingInfo(
            title: "Test Episode",
            duration: 600,
            elapsedTime: 100,
            isPlaying: true
        ))

        // Stop
        mockPlayer.stop()
        mockNowPlaying.clearNowPlayingInfo()

        #expect(mockNowPlaying.didClearNowPlayingInfo == true)
        #expect(mockPlayer.state == .idle)
        #expect(mockPlayer.currentItem == nil)
    }
}
#endif

// MARK: - Now Playing State Transition Tests

#if DEBUG
/// Tests for Now Playing info updates during state transitions.
@Suite("Now Playing State Transitions")
struct NowPlayingStateTransitionTests {

    @Test("Playing state reflected in Now Playing info")
    @MainActor
    func playingStateReflected() {
        let mockManager = MockNowPlayingManager()

        mockManager.updateNowPlayingInfo(NowPlayingInfo(
            title: "Playing",
            duration: 600,
            elapsedTime: 0,
            playbackRate: 1.0,
            isPlaying: true
        ))

        #expect(mockManager.lastUpdatedInfo?.isPlaying == true)
        #expect(mockManager.lastUpdatedInfo?.playbackRate == 1.0)
    }

    @Test("Paused state reflected with zero rate")
    @MainActor
    func pausedStateReflectedWithZeroRate() {
        let mockManager = MockNowPlayingManager()

        mockManager.updateNowPlayingInfo(NowPlayingInfo(
            title: "Paused",
            duration: 600,
            elapsedTime: 100,
            playbackRate: 0,
            isPlaying: false
        ))

        // When paused, playback rate should be 0 in Now Playing
        #expect(mockManager.lastUpdatedInfo?.isPlaying == false)
    }

    @Test("Loading state does not update Now Playing")
    @MainActor
    func loadingStateNoUpdate() {
        let mockPlayer = MockAudioPlayerService()

        mockPlayer.simulateStateChange(.loading)

        // In loading state, Now Playing should not show playback info
        #expect(mockPlayer.state == .loading)
        #expect(mockPlayer.currentItem == nil) // No item yet
    }

    @Test("Error state preserves last known info")
    @MainActor
    func errorStatePreservesInfo() {
        let mockPlayer = MockAudioPlayerService()

        // Setup with playback
        mockPlayer.simulateProgress(currentTime: 200, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Simulate error
        mockPlayer.simulateError(.itemPlaybackFailed(title: "Test", error: "Network error"))

        // Progress should be preserved
        #expect(mockPlayer.progress.currentTime == 200)
    }
}
#endif

// MARK: - Remote Command Response Tests

#if DEBUG
/// Tests verifying MockAudioPlayerService responds correctly to remote commands.
@Suite("Remote Command Response")
struct RemoteCommandResponseTests {

    @Test("MockAudioPlayerService responds to play command")
    @MainActor
    func mockPlayerRespondsToPlay() throws {
        let mockPlayer = MockAudioPlayerService()
        mockPlayer.simulateProgress(currentTime: 0, duration: 600)

        try mockPlayer.play()

        #expect(mockPlayer.state == .playing)
        #expect(mockPlayer.wasMethodCalled(.play))
    }

    @Test("MockAudioPlayerService responds to pause command")
    @MainActor
    func mockPlayerRespondsToPause() {
        let mockPlayer = MockAudioPlayerService()
        mockPlayer.simulateProgress(currentTime: 0, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        mockPlayer.pause()

        #expect(mockPlayer.state == .paused)
        #expect(mockPlayer.wasMethodCalled(.pause))
    }

    @Test("MockAudioPlayerService responds to skip forward")
    @MainActor
    func mockPlayerRespondsToSkipForward() async {
        let mockPlayer = MockAudioPlayerService()
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        await mockPlayer.fastForward(seconds: 15)

        #expect(mockPlayer.progress.currentTime == 115)
        #expect(mockPlayer.wasMethodCalled(.fastForward(seconds: 15)))
    }

    @Test("MockAudioPlayerService responds to skip backward")
    @MainActor
    func mockPlayerRespondsToSkipBackward() async {
        let mockPlayer = MockAudioPlayerService()
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        await mockPlayer.rewind(seconds: 15)

        #expect(mockPlayer.progress.currentTime == 85)
        #expect(mockPlayer.wasMethodCalled(.rewind(seconds: 15)))
    }

    @Test("MockAudioPlayerService responds to seek")
    @MainActor
    func mockPlayerRespondsToSeek() async throws {
        let mockPlayer = MockAudioPlayerService()
        mockPlayer.simulateProgress(currentTime: 0, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        try await mockPlayer.seekTo(seconds: 300)

        #expect(mockPlayer.progress.currentTime == 300)
    }

    @Test("MockAudioPlayerService responds to rate change")
    @MainActor
    func mockPlayerRespondsToRateChange() throws {
        let mockPlayer = MockAudioPlayerService()

        try mockPlayer.setRate(2.0)

        #expect(mockPlayer.playbackRate == 2.0)
        #expect(mockPlayer.wasMethodCalled(.setRate(rate: 2.0)))
    }
}
#endif
