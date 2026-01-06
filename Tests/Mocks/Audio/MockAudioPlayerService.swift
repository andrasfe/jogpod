//
//  MockAudioPlayerService.swift
//  JogPodTests
//
//  Mock implementation of audio player service for testing playback scenarios
//  without actual audio playback.
//
//  Created for JogPod Revival project.
//

import Foundation
import AVFoundation
import Combine
import SwiftData
@testable import JogPod

// MARK: - MockAudioPlayerService

/// A mock implementation of audio player functionality for testing.
///
/// This mock allows tests to simulate various playback scenarios including:
/// - State transitions (idle, paused, playing, loading, error)
/// - Progress updates
/// - Interruption handling
/// - Route changes
/// - Playback controls
///
/// ## Usage
///
/// ```swift
/// let mock = MockAudioPlayerService()
/// mock.simulateStateChange(.playing)
/// mock.simulateProgress(currentTime: 60, duration: 300)
/// mock.simulateInterruption(began: true)
/// ```
@MainActor
public final class MockAudioPlayerService: @unchecked Sendable {

    // MARK: - Published Properties (Mirror AudioPlayerService)

    /// Current playback state.
    @Published public private(set) var state: PlaybackState = .idle

    /// Current playback progress.
    @Published public private(set) var progress: PlaybackProgress = PlaybackProgress()

    /// Current item being played.
    @Published public private(set) var currentItem: PlayableItem?

    /// Current playback rate (1.0 = normal speed).
    @Published public private(set) var playbackRate: Float = 1.0

    /// Playlist of playable items.
    @Published public private(set) var playlist: [PlayableItem] = []

    // MARK: - Delegate

    /// Delegate for receiving playback events.
    public weak var delegate: AudioPlayerServiceDelegate?

    // MARK: - Tracking Properties

    /// Tracks all state changes that occurred.
    public private(set) var stateHistory: [PlaybackState] = []

    /// Tracks all delegate notifications sent.
    public private(set) var delegateNotifications: [DelegateNotification] = []

    /// Tracks method calls for verification.
    public private(set) var methodCalls: [MethodCall] = []

    /// Whether the audio session was configured.
    public private(set) var audioSessionConfigured: Bool = false

    /// Whether the audio session is active.
    public private(set) var audioSessionActive: Bool = false

    /// Flag to track if we were playing before interruption.
    public private(set) var wasPlayingBeforeInterruption: Bool = false

    /// The current index in the playlist.
    public private(set) var currentIndex: Int = 0

    /// The skip interval in seconds.
    public private(set) var skipInterval: TimeInterval = 15

    /// Simulated errors to throw on specific operations.
    public var simulatedErrors: [String: AudioPlayerError] = [:]

    // MARK: - Types

    /// Represents a notification sent to the delegate.
    public enum DelegateNotification: Equatable {
        case stateChanged(PlaybackState)
        case itemChanged
        case progressUpdated(currentTime: TimeInterval, duration: TimeInterval)
        case error(AudioPlayerError)
        case itemFinished
    }

    /// Represents a method call for tracking.
    public enum MethodCall: Equatable {
        case configureAudioSession
        case loadPlaylist
        case play
        case pause
        case stop
        case togglePlayPause
        case advanceToNextItem
        case goToPreviousItem
        case goToItem(index: Int)
        case seekTo(seconds: TimeInterval)
        case fastForward(seconds: TimeInterval?)
        case rewind(seconds: TimeInterval?)
        case setRate(rate: Float)
        case setSkipInterval(seconds: TimeInterval)
        case deactivateAudioSession
        case reactivateAudioSession
    }

    // MARK: - Initialization

    /// Creates a new MockAudioPlayerService.
    public init() {
        stateHistory.append(.idle)
    }

    // MARK: - Audio Session Configuration

    /// Simulates configuring the audio session.
    public func configureAudioSession() throws {
        methodCalls.append(.configureAudioSession)

        if let error = simulatedErrors["configureAudioSession"] {
            throw error
        }

        audioSessionConfigured = true
        audioSessionActive = true
    }

    // MARK: - Playlist Management

    /// Simulates loading the playlist.
    public func loadPlaylist() async throws {
        methodCalls.append(.loadPlaylist)

        if let error = simulatedErrors["loadPlaylist"] {
            throw error
        }
    }

    /// Sets the mock playlist for testing.
    public func setPlaylist(_ items: [PlayableItem]) {
        playlist = items
    }

    /// Sets the current item for testing.
    public func setCurrentItem(_ item: PlayableItem?) {
        currentItem = item
        delegate?.audioPlayerService(self as! AudioPlayerService, didChangeItem: item)
        delegateNotifications.append(.itemChanged)
    }

    // MARK: - Playback Controls

    /// Simulates starting playback.
    public func play() throws {
        methodCalls.append(.play)

        if let error = simulatedErrors["play"] {
            throw error
        }

        guard currentItem != nil else {
            throw AudioPlayerError.noCurrentItem
        }

        simulateStateChange(.playing)
    }

    /// Simulates pausing playback.
    public func pause() {
        methodCalls.append(.pause)
        simulateStateChange(.paused)
    }

    /// Simulates stopping playback.
    public func stop() {
        methodCalls.append(.stop)
        currentItem = nil
        simulateStateChange(.idle)
        progress = PlaybackProgress()
    }

    /// Simulates toggling play/pause.
    public func togglePlayPause() throws {
        methodCalls.append(.togglePlayPause)

        if state == .playing {
            pause()
        } else {
            try play()
        }
    }

    // MARK: - Navigation

    /// Simulates advancing to the next item.
    public func advanceToNextItem() async {
        methodCalls.append(.advanceToNextItem)

        guard !playlist.isEmpty else { return }

        currentIndex = (currentIndex + 1) % playlist.count
        if currentIndex < playlist.count {
            currentItem = playlist[currentIndex]
            delegateNotifications.append(.itemChanged)
        }
    }

    /// Simulates going to the previous item.
    public func goToPreviousItem() async {
        methodCalls.append(.goToPreviousItem)

        guard !playlist.isEmpty else { return }

        currentIndex = currentIndex > 0 ? currentIndex - 1 : playlist.count - 1
        if currentIndex < playlist.count {
            currentItem = playlist[currentIndex]
            delegateNotifications.append(.itemChanged)
        }
    }

    /// Simulates going to a specific item.
    public func goToItem(at index: Int) async throws {
        methodCalls.append(.goToItem(index: index))

        guard index >= 0 && index < playlist.count else {
            throw AudioPlayerError.invalidItemIndex(index: index, count: playlist.count)
        }

        currentIndex = index
        currentItem = playlist[index]
        delegateNotifications.append(.itemChanged)
    }

    // MARK: - Seeking

    /// Simulates seeking to a specific position.
    public func seekTo(seconds: TimeInterval) async throws {
        methodCalls.append(.seekTo(seconds: seconds))

        if let error = simulatedErrors["seekTo"] {
            throw error
        }

        let duration = progress.duration
        guard duration > 0 else {
            throw AudioPlayerError.seekFailed(reason: "Duration not available")
        }

        let clampedSeconds = max(0, min(seconds, duration))
        simulateProgress(currentTime: clampedSeconds, duration: duration)
    }

    /// Simulates fast forward.
    public func fastForward(seconds: TimeInterval? = nil) async {
        let skipAmount = seconds ?? skipInterval
        methodCalls.append(.fastForward(seconds: seconds))

        let newPosition = progress.currentTime + skipAmount
        try? await seekTo(seconds: newPosition)
    }

    /// Simulates rewind.
    public func rewind(seconds: TimeInterval? = nil) async {
        let skipAmount = seconds ?? skipInterval
        methodCalls.append(.rewind(seconds: seconds))

        let newPosition = max(0, progress.currentTime - skipAmount)
        try? await seekTo(seconds: newPosition)
    }

    // MARK: - Playback Rate

    /// Simulates setting the playback rate.
    public func setRate(_ rate: Float) throws {
        methodCalls.append(.setRate(rate: rate))

        guard AudioPlayerService.validPlaybackRateRange.contains(rate) else {
            throw AudioPlayerError.invalidPlaybackRate(
                rate: rate,
                validRange: AudioPlayerService.validPlaybackRateRange
            )
        }

        playbackRate = rate
    }

    /// Sets the skip interval.
    public func setSkipInterval(_ seconds: TimeInterval) {
        methodCalls.append(.setSkipInterval(seconds: seconds))
        skipInterval = max(1, seconds)
    }

    // MARK: - Audio Session

    /// Simulates deactivating the audio session.
    public func deactivateAudioSession() {
        methodCalls.append(.deactivateAudioSession)
        audioSessionActive = false
    }

    /// Simulates reactivating the audio session.
    public func reactivateAudioSession() throws {
        methodCalls.append(.reactivateAudioSession)

        if let error = simulatedErrors["reactivateAudioSession"] {
            throw error
        }

        audioSessionActive = true
    }

    // MARK: - Query Methods

    /// Whether the player is currently playing.
    public var isPlaying: Bool {
        state == .playing
    }

    /// Whether the playlist is empty.
    public var isEmpty: Bool {
        playlist.isEmpty
    }

    /// The number of items in the playlist.
    public var itemCount: Int {
        playlist.count
    }

    /// Whether the current item is at the last position.
    public var isAtLastItem: Bool {
        currentIndex >= playlist.count - 1
    }

    /// The duration of the current item in seconds.
    public var currentItemDuration: TimeInterval {
        progress.duration
    }

    /// The current playback position in seconds.
    public var currentPosition: TimeInterval {
        progress.currentTime
    }

    // MARK: - Simulation Methods

    /// Simulates a state change.
    ///
    /// - Parameter newState: The new playback state.
    public func simulateStateChange(_ newState: PlaybackState) {
        state = newState
        stateHistory.append(newState)
        delegateNotifications.append(.stateChanged(newState))
    }

    /// Simulates a progress update.
    ///
    /// - Parameters:
    ///   - currentTime: Current position in seconds.
    ///   - duration: Total duration in seconds.
    public func simulateProgress(currentTime: TimeInterval, duration: TimeInterval) {
        progress = PlaybackProgress(currentTime: currentTime, duration: duration)
        delegateNotifications.append(.progressUpdated(currentTime: currentTime, duration: duration))
    }

    /// Simulates an audio session interruption.
    ///
    /// - Parameter began: True if interruption began, false if ended.
    /// - Parameter shouldResume: Whether playback should resume after interruption ends.
    public func simulateInterruption(began: Bool, shouldResume: Bool = true) {
        if began {
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                pause()
            }
        } else {
            if wasPlayingBeforeInterruption && shouldResume {
                try? play()
            }
            wasPlayingBeforeInterruption = false
        }
    }

    /// Simulates an audio route change (e.g., headphones disconnected).
    ///
    /// - Parameter reason: The route change reason.
    public func simulateRouteChange(reason: AVAudioSession.RouteChangeReason) {
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones disconnected - pause playback
            if isPlaying {
                pause()
            }
        case .newDeviceAvailable:
            // New device connected - no action needed
            break
        case .categoryChange:
            // Category changed - reconfigure session
            try? configureAudioSession()
        default:
            break
        }
    }

    /// Simulates an error occurring.
    ///
    /// - Parameter error: The error to simulate.
    public func simulateError(_ error: AudioPlayerError) {
        simulateStateChange(.error(error))
        delegateNotifications.append(.error(error))
    }

    /// Simulates an item finishing playback.
    public func simulateItemFinished() {
        delegateNotifications.append(.itemFinished)
    }

    // MARK: - Test Helpers

    /// Resets all tracking data.
    public func reset() {
        state = .idle
        progress = PlaybackProgress()
        currentItem = nil
        playbackRate = 1.0
        playlist = []
        stateHistory = [.idle]
        delegateNotifications = []
        methodCalls = []
        audioSessionConfigured = false
        audioSessionActive = false
        wasPlayingBeforeInterruption = false
        currentIndex = 0
        skipInterval = 15
        simulatedErrors = [:]
    }

    /// Verifies that a specific method was called.
    ///
    /// - Parameter method: The method call to verify.
    /// - Returns: True if the method was called.
    public func wasMethodCalled(_ method: MethodCall) -> Bool {
        methodCalls.contains(method)
    }

    /// Returns the count of times a method was called.
    ///
    /// - Parameter method: The method call to count.
    /// - Returns: The number of times the method was called.
    public func methodCallCount(_ method: MethodCall) -> Int {
        methodCalls.filter { $0 == method }.count
    }

    /// Verifies that the state transitioned through expected states.
    ///
    /// - Parameter expectedStates: The expected sequence of states.
    /// - Returns: True if the state history matches.
    public func verifyStateTransitions(_ expectedStates: [PlaybackState]) -> Bool {
        stateHistory == expectedStates
    }
}

// MARK: - Publisher Convenience

public extension MockAudioPlayerService {

    /// Publisher for playback state changes.
    var statePublisher: AnyPublisher<PlaybackState, Never> {
        $state.eraseToAnyPublisher()
    }

    /// Publisher for progress updates.
    var progressPublisher: AnyPublisher<PlaybackProgress, Never> {
        $progress.eraseToAnyPublisher()
    }

    /// Publisher for current item changes.
    var currentItemPublisher: AnyPublisher<PlayableItem?, Never> {
        $currentItem.eraseToAnyPublisher()
    }

    /// Publisher for playback rate changes.
    var playbackRatePublisher: AnyPublisher<Float, Never> {
        $playbackRate.eraseToAnyPublisher()
    }
}
