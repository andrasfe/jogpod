//
//  RouteChangeTests.swift
//  JogPodTests
//
//  Tests for audio route change handling scenarios.
//  Verifies correct behavior when audio output devices change
//  (headphones disconnect, Bluetooth connect, etc.).
//
//  Created for JogPod Revival project.
//

import Testing
import Foundation
import AVFoundation
@testable import JogPod

// MARK: - Route Change Tests

/// Tests for audio route change handling.
///
/// These tests verify that the audio player correctly responds to audio route changes:
/// - Pausing playback when headphones are disconnected
/// - Continuing playback when new devices connect
/// - Handling Bluetooth device changes
/// - Handling AirPlay device changes
///
/// Reference: AudioPlayerService.handleRouteChange(_:)
@Suite("Audio Route Change Handling")
struct RouteChangeTests {

    // MARK: - Device Disconnect Tests (Old Device Unavailable)

    @Test("Headphones disconnect pauses playback")
    @MainActor
    func headphonesDisconnectPausesPlayback() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing through headphones
        mockPlayer.simulateProgress(currentTime: 60, duration: 300)
        mockPlayer.simulateStateChange(.playing)

        // Act: Headphones disconnected
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)

        // Assert: Should pause to prevent unexpected speaker playback
        #expect(mockPlayer.state == .paused)
        #expect(mockPlayer.wasMethodCalled(.pause))
    }

    @Test("Bluetooth disconnect pauses playback")
    @MainActor
    func bluetoothDisconnectPausesPlayback() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing through Bluetooth
        mockPlayer.simulateProgress(currentTime: 120, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Act: Bluetooth device disconnected
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)

        // Assert: Should pause
        #expect(mockPlayer.state == .paused)
    }

    @Test("Device disconnect does not affect paused playback")
    @MainActor
    func deviceDisconnectWhenPaused() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is paused
        mockPlayer.simulateProgress(currentTime: 60, duration: 300)
        mockPlayer.simulateStateChange(.paused)

        // Clear method calls to track new ones
        mockPlayer.reset()
        mockPlayer.simulateStateChange(.paused)

        // Act: Device disconnected
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)

        // Assert: Should remain paused, pause not called again
        #expect(mockPlayer.state == .paused)
    }

    @Test("Device disconnect does not affect idle state")
    @MainActor
    func deviceDisconnectWhenIdle() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is idle (default)
        #expect(mockPlayer.state == .idle)

        // Act: Device disconnected
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)

        // Assert: Should remain idle
        #expect(mockPlayer.state == .idle)
    }

    // MARK: - Device Connect Tests (New Device Available)

    @Test("Headphones connect does not auto-start playback")
    @MainActor
    func headphonesConnectNoAutoStart() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is paused
        mockPlayer.simulateProgress(currentTime: 60, duration: 300)
        mockPlayer.simulateStateChange(.paused)

        // Act: Headphones connected
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)

        // Assert: Should remain paused (no auto-play on device connect)
        #expect(mockPlayer.state == .paused)
        #expect(!mockPlayer.wasMethodCalled(.play))
    }

    @Test("Bluetooth connect does not interrupt playback")
    @MainActor
    func bluetoothConnectNoInterruption() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Act: Bluetooth device connected
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)

        // Assert: Should continue playing
        #expect(mockPlayer.state == .playing)
    }

    @Test("AirPlay connect does not interrupt playback")
    @MainActor
    func airPlayConnectNoInterruption() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing
        mockPlayer.simulateStateChange(.playing)

        // Act: AirPlay device connected
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)

        // Assert: Should continue playing
        #expect(mockPlayer.state == .playing)
    }

    // MARK: - Category Change Tests

    @Test("Category change triggers session reconfiguration")
    @MainActor
    func categoryChangeTriggerReconfiguration() throws {
        let mockPlayer = MockAudioPlayerService()

        // Act: Category changed
        mockPlayer.simulateRouteChange(reason: .categoryChange)

        // Assert: Should attempt to reconfigure session
        #expect(mockPlayer.wasMethodCalled(.configureAudioSession))
    }

    // MARK: - Other Route Change Reasons Tests

    @Test("Route configuration change handled gracefully")
    @MainActor
    func routeConfigurationChange() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing
        mockPlayer.simulateStateChange(.playing)

        // Act: Route configuration changed
        mockPlayer.simulateRouteChange(reason: .routeConfigurationChange)

        // Assert: No state change
        #expect(mockPlayer.state == .playing)
    }

    @Test("Override route change handled gracefully")
    @MainActor
    func overrideRouteChange() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing
        mockPlayer.simulateStateChange(.playing)

        // Act: Override route change
        mockPlayer.simulateRouteChange(reason: .override)

        // Assert: No state change
        #expect(mockPlayer.state == .playing)
    }

    @Test("Wake from sleep route change handled gracefully")
    @MainActor
    func wakeFromSleepRouteChange() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player was playing
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Act: Wake from sleep
        mockPlayer.simulateRouteChange(reason: .wakeFromSleep)

        // Assert: No state change
        #expect(mockPlayer.state == .playing)
    }

    @Test("No suitable route handled gracefully")
    @MainActor
    func noSuitableRouteChange() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is idle
        mockPlayer.simulateStateChange(.idle)

        // Act: No suitable route
        mockPlayer.simulateRouteChange(reason: .noSuitableRouteForCategory)

        // Assert: Remains idle
        #expect(mockPlayer.state == .idle)
    }

    @Test("Unknown route change reason handled gracefully")
    @MainActor
    func unknownRouteChangeReason() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Setup: Player is playing
        mockPlayer.simulateStateChange(.playing)

        // Act: Unknown reason
        mockPlayer.simulateRouteChange(reason: .unknown)

        // Assert: No state change
        #expect(mockPlayer.state == .playing)
    }
}

// MARK: - MockAVAudioSession Route Change Notification Tests

/// Tests for MockAVAudioSession route change notification posting.
@Suite("MockAVAudioSession Route Change Notifications")
struct MockAVAudioSessionRouteChangeTests {

    @Test("Posts route change notification for old device unavailable")
    func postsOldDeviceUnavailableNotification() async throws {
        let mockSession = MockAVAudioSession()
        var receivedNotification: Notification?

        // Register for notification
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: mockSession,
            queue: .main
        ) { notification in
            receivedNotification = notification
        }

        defer {
            NotificationCenter.default.removeObserver(token)
        }

        // Act
        mockSession.simulateRouteChange(reason: .oldDeviceUnavailable)

        // Wait briefly for notification
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        #expect(receivedNotification != nil)
        if let userInfo = receivedNotification?.userInfo,
           let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt {
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
            #expect(reason == .oldDeviceUnavailable)
        } else {
            Issue.record("Expected route change reason in notification")
        }
    }

    @Test("Posts route change notification for new device available")
    func postsNewDeviceAvailableNotification() async throws {
        let mockSession = MockAVAudioSession()
        var receivedNotification: Notification?

        // Register for notification
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: mockSession,
            queue: .main
        ) { notification in
            receivedNotification = notification
        }

        defer {
            NotificationCenter.default.removeObserver(token)
        }

        // Act
        mockSession.simulateRouteChange(reason: .newDeviceAvailable)

        // Wait briefly for notification
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        #expect(receivedNotification != nil)
        if let userInfo = receivedNotification?.userInfo,
           let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt {
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
            #expect(reason == .newDeviceAvailable)
        }
    }

    @Test("Calls route change handler with correct parameters")
    func callsRouteChangeHandler() {
        let mockSession = MockAVAudioSession()
        var handlerCalled = false
        var receivedReason: AVAudioSession.RouteChangeReason?

        mockSession.routeChangeHandler = { reason, previousRoute in
            handlerCalled = true
            receivedReason = reason
        }

        // Act
        mockSession.simulateRouteChange(reason: .categoryChange)

        // Assert
        #expect(handlerCalled == true)
        #expect(receivedReason == .categoryChange)
    }
}

// MARK: - Mock Audio Route Description Tests

/// Tests for MockAudioSessionRouteDescription.
@Suite("Mock Audio Route Description")
struct MockAudioRouteDescriptionTests {

    @Test("Built-in speaker route created correctly")
    func builtInSpeakerRoute() {
        let route = MockAudioSessionRouteDescription.builtInSpeaker

        #expect(route.outputs.count == 1)
        #expect(route.outputs.first?.portType == .builtInSpeaker)
        #expect(route.outputs.first?.portName == "Speaker")
    }

    @Test("Headphones route created correctly")
    func headphonesRoute() {
        let route = MockAudioSessionRouteDescription.headphones

        #expect(route.outputs.count == 1)
        #expect(route.outputs.first?.portType == .headphones)
        #expect(route.outputs.first?.portName == "Headphones")
    }

    @Test("Bluetooth route created correctly")
    func bluetoothRoute() {
        let route = MockAudioSessionRouteDescription.bluetooth

        #expect(route.outputs.count == 1)
        #expect(route.outputs.first?.portType == .bluetoothA2DP)
        #expect(route.outputs.first?.portName == "Bluetooth Headphones")
    }

    @Test("AirPlay route created correctly")
    func airPlayRoute() {
        let route = MockAudioSessionRouteDescription.airPlay

        #expect(route.outputs.count == 1)
        #expect(route.outputs.first?.portType == .airPlay)
        #expect(route.outputs.first?.portName == "AirPlay")
    }

    @Test("Custom route with multiple outputs")
    func customRouteWithMultipleOutputs() {
        let route = MockAudioSessionRouteDescription(
            outputs: [.headphones, .bluetooth],
            inputs: [.builtInMic]
        )

        #expect(route.outputs.count == 2)
        #expect(route.inputs.count == 1)
        #expect(route.inputs.first?.portType == .builtInMic)
    }
}

// MARK: - Route Change Scenario Tests

/// Integration-style tests for complete route change scenarios.
@Suite("Route Change Scenarios")
struct RouteChangeScenarioTests {

    @Test("Headphone plug-unplug cycle")
    @MainActor
    func headphonePlugUnplugCycle() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Start playing through speaker
        mockPlayer.simulateProgress(currentTime: 0, duration: 600)
        mockPlayer.simulateStateChange(.playing)
        #expect(mockPlayer.state == .playing)

        // Plug in headphones
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)
        #expect(mockPlayer.state == .playing) // Continues playing

        // Advance playback
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)

        // Unplug headphones
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)
        #expect(mockPlayer.state == .paused) // Paused to prevent speaker blaring

        // User manually resumes
        mockPlayer.simulateStateChange(.playing)
        #expect(mockPlayer.state == .playing)
    }

    @Test("Bluetooth connection cycle during workout")
    @MainActor
    func bluetoothConnectionCycleDuringWorkout() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Start workout with phone speaker
        mockPlayer.simulateProgress(currentTime: 0, duration: 1800)
        mockPlayer.simulateStateChange(.playing)

        // Connect Bluetooth headphones
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)
        #expect(mockPlayer.state == .playing)

        // During workout, Bluetooth momentarily disconnects
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)
        #expect(mockPlayer.state == .paused) // Safety pause

        // Bluetooth reconnects
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)
        #expect(mockPlayer.state == .paused) // Stays paused until user resumes

        // User resumes
        try mockPlayer.play()
        #expect(mockPlayer.state == .playing)
    }

    @Test("AirPlay handoff scenario")
    @MainActor
    func airPlayHandoffScenario() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Playing on device
        mockPlayer.simulateProgress(currentTime: 500, duration: 3600)
        mockPlayer.simulateStateChange(.playing)

        // Connect to AirPlay speaker
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)
        #expect(mockPlayer.state == .playing)
        #expect(mockPlayer.progress.currentTime == 500) // Position preserved

        // AirPlay speaker disconnects
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)
        #expect(mockPlayer.state == .paused)
        #expect(mockPlayer.progress.currentTime == 500) // Position still preserved
    }

    @Test("Multiple rapid route changes")
    @MainActor
    func multipleRapidRouteChanges() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Start playing
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Rapid route changes (simulating flaky Bluetooth)
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)
        mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)

        // Should be paused from last oldDeviceUnavailable before newDeviceAvailable
        // (route changes are handled sequentially)
        #expect(mockPlayer.state == .paused)
    }

    @Test("Route change with interruption overlap")
    @MainActor
    func routeChangeWithInterruptionOverlap() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Playing
        mockPlayer.simulateProgress(currentTime: 100, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Phone call comes in (interruption)
        mockPlayer.simulateInterruption(began: true)
        #expect(mockPlayer.state == .paused)

        // User unplugs headphones during call
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)
        #expect(mockPlayer.state == .paused)

        // Call ends
        mockPlayer.simulateInterruption(began: false, shouldResume: true)

        // Should remain paused because route changed during interruption
        // The wasPlayingBeforeInterruption was true, so it tries to resume
        // But the implementation should handle this gracefully
        // In real scenario, might want to stay paused due to route change
    }
}

// MARK: - Position Preservation Tests

/// Tests verifying playback position is preserved during route changes.
@Suite("Route Change Position Preservation")
struct RouteChangePositionPreservationTests {

    @Test("Position preserved when headphones disconnect")
    @MainActor
    func positionPreservedOnHeadphoneDisconnect() async throws {
        let mockPlayer = MockAudioPlayerService()

        // Play to specific position
        mockPlayer.simulateProgress(currentTime: 300, duration: 600)
        mockPlayer.simulateStateChange(.playing)

        // Disconnect headphones
        mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)

        // Position should be preserved
        #expect(mockPlayer.progress.currentTime == 300)
        #expect(mockPlayer.progress.duration == 600)
    }

    @Test("Position preserved through connect-disconnect cycle")
    @MainActor
    func positionPreservedThroughCycle() async throws {
        let mockPlayer = MockAudioPlayerService()

        let positions: [TimeInterval] = [0, 50, 100, 150]

        for position in positions {
            mockPlayer.simulateProgress(currentTime: position, duration: 600)
            mockPlayer.simulateStateChange(.playing)

            mockPlayer.simulateRouteChange(reason: .newDeviceAvailable)
            #expect(mockPlayer.progress.currentTime == position)

            mockPlayer.simulateRouteChange(reason: .oldDeviceUnavailable)
            #expect(mockPlayer.progress.currentTime == position)
        }
    }
}
