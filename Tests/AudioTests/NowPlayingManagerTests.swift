//
//  NowPlayingManagerTests.swift
//  JogPodTests
//
//  Created for JogPod Revival project.
//

import Testing
import MediaPlayer
@testable import JogPod

/// Tests for NowPlayingInfo struct.
@Suite("NowPlayingInfo Tests")
struct NowPlayingInfoTests {

    @Test("NowPlayingInfo initializes with default values")
    func defaultInitialization() {
        let info = NowPlayingInfo()

        #expect(info.title == nil)
        #expect(info.podcastTitle == nil)
        #expect(info.duration == 0)
        #expect(info.elapsedTime == 0)
        #expect(info.playbackRate == 1.0)
        #expect(info.isPlaying == false)
        #expect(info.artworkURL == nil)
    }

    @Test("NowPlayingInfo initializes with custom values")
    func customInitialization() {
        let artworkURL = URL(string: "https://example.com/artwork.jpg")!

        let info = NowPlayingInfo(
            title: "Episode 1",
            podcastTitle: "My Podcast",
            duration: 3600,
            elapsedTime: 1800,
            playbackRate: 1.5,
            isPlaying: true,
            artworkURL: artworkURL
        )

        #expect(info.title == "Episode 1")
        #expect(info.podcastTitle == "My Podcast")
        #expect(info.duration == 3600)
        #expect(info.elapsedTime == 1800)
        #expect(info.playbackRate == 1.5)
        #expect(info.isPlaying == true)
        #expect(info.artworkURL == artworkURL)
    }

    @Test("NowPlayingInfo is Equatable")
    func equatable() {
        let info1 = NowPlayingInfo(title: "Test", duration: 100)
        let info2 = NowPlayingInfo(title: "Test", duration: 100)
        let info3 = NowPlayingInfo(title: "Other", duration: 100)

        #expect(info1 == info2)
        #expect(info1 != info3)
    }
}

/// Tests for RemoteCommandAction enum.
@Suite("RemoteCommandAction Tests")
struct RemoteCommandActionTests {

    @Test("RemoteCommandAction cases are distinct")
    func actionCasesAreDistinct() {
        let actions: [RemoteCommandAction] = [
            .play,
            .pause,
            .togglePlayPause,
            .nextTrack,
            .previousTrack,
            .skipForward(seconds: 15),
            .skipBackward(seconds: 15),
            .seekTo(position: 100),
            .changePlaybackRate(rate: 1.5)
        ]

        // Verify all actions can be created
        #expect(actions.count == 9)
    }

    @Test("Skip actions include seconds parameter")
    func skipActionsIncludeSeconds() {
        let forward = RemoteCommandAction.skipForward(seconds: 30)
        let backward = RemoteCommandAction.skipBackward(seconds: 10)

        if case .skipForward(let seconds) = forward {
            #expect(seconds == 30)
        } else {
            Issue.record("Expected skipForward case")
        }

        if case .skipBackward(let seconds) = backward {
            #expect(seconds == 10)
        } else {
            Issue.record("Expected skipBackward case")
        }
    }

    @Test("SeekTo action includes position")
    func seekToIncludesPosition() {
        let action = RemoteCommandAction.seekTo(position: 123.5)

        if case .seekTo(let position) = action {
            #expect(position == 123.5)
        } else {
            Issue.record("Expected seekTo case")
        }
    }

    @Test("ChangePlaybackRate action includes rate")
    func changePlaybackRateIncludesRate() {
        let action = RemoteCommandAction.changePlaybackRate(rate: 2.0)

        if case .changePlaybackRate(let rate) = action {
            #expect(rate == 2.0)
        } else {
            Issue.record("Expected changePlaybackRate case")
        }
    }
}

#if DEBUG
/// Tests for MockNowPlayingManager.
@Suite("MockNowPlayingManager Tests")
struct MockNowPlayingManagerTests {

    @Test("MockNowPlayingManager tracks updateNowPlayingInfo calls")
    func tracksUpdateNowPlayingInfo() {
        let mock = MockNowPlayingManager()
        let info = NowPlayingInfo(title: "Test Episode", duration: 600)

        mock.updateNowPlayingInfo(info)

        #expect(mock.lastUpdatedInfo == info)
    }

    @Test("MockNowPlayingManager tracks clearNowPlayingInfo calls")
    func tracksClearNowPlayingInfo() {
        let mock = MockNowPlayingManager()

        #expect(mock.didClearNowPlayingInfo == false)

        mock.clearNowPlayingInfo()

        #expect(mock.didClearNowPlayingInfo == true)
        #expect(mock.lastUpdatedInfo == nil)
    }

    @Test("MockNowPlayingManager tracks updateElapsedTime calls")
    func tracksUpdateElapsedTime() {
        let mock = MockNowPlayingManager()

        mock.updateElapsedTime(123.5, playbackRate: 1.5)

        #expect(mock.lastElapsedTimeUpdate?.time == 123.5)
        #expect(mock.lastElapsedTimeUpdate?.rate == 1.5)
    }

    @Test("MockNowPlayingManager tracks setSkipInterval calls")
    func tracksSetSkipInterval() {
        let mock = MockNowPlayingManager()

        #expect(mock.currentSkipInterval == 15) // default

        mock.setSkipInterval(30)

        #expect(mock.currentSkipInterval == 30)
    }

    @Test("MockNowPlayingManager tracks setRemoteCommandsEnabled calls")
    func tracksSetRemoteCommandsEnabled() {
        let mock = MockNowPlayingManager()

        #expect(mock.areRemoteCommandsEnabled == false) // default

        mock.setRemoteCommandsEnabled(true)

        #expect(mock.areRemoteCommandsEnabled == true)

        mock.setRemoteCommandsEnabled(false)

        #expect(mock.areRemoteCommandsEnabled == false)
    }

    @Test("MockNowPlayingManager can simulate remote commands")
    func simulatesRemoteCommands() async {
        let mock = MockNowPlayingManager()
        let delegate = TestNowPlayingDelegate()
        mock.delegate = delegate

        mock.simulateRemoteCommand(.play)

        #expect(delegate.receivedActions.count == 1)
        if case .play = delegate.receivedActions.first {
            // Success
        } else {
            Issue.record("Expected play command")
        }
    }
}

/// Test delegate for capturing remote command actions.
final class TestNowPlayingDelegate: NowPlayingManagerDelegate, @unchecked Sendable {
    var receivedActions: [RemoteCommandAction] = []

    func nowPlayingManager(didReceiveCommand action: RemoteCommandAction) {
        receivedActions.append(action)
    }
}
#endif

/// Tests for NowPlayingManaging protocol.
@Suite("NowPlayingManaging Protocol Tests")
struct NowPlayingManagingProtocolTests {

    #if DEBUG
    @Test("MockNowPlayingManager conforms to NowPlayingManaging")
    func mockConformsToProtocol() {
        let mock: NowPlayingManaging = MockNowPlayingManager()

        // Verify all protocol methods can be called
        mock.updateNowPlayingInfo(NowPlayingInfo())
        mock.clearNowPlayingInfo()
        mock.updateElapsedTime(0, playbackRate: 1.0)
        mock.setSkipInterval(15)
        mock.setRemoteCommandsEnabled(true)

        // No assertions needed - compile-time check that protocol is satisfied
        #expect(mock.delegate == nil)
    }
    #endif
}
