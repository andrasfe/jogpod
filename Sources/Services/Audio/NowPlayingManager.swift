//
//  NowPlayingManager.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation
import MediaPlayer
import AVFoundation

// MARK: - NowPlayingInfo

/// Information displayed on the lock screen and Control Center.
///
/// This struct encapsulates all metadata that can be shown in the system's
/// now playing UI, including playback progress and artwork.
public struct NowPlayingInfo: Equatable, Sendable {

    /// The title of the episode.
    public var title: String?

    /// The name of the podcast (artist).
    public var podcastTitle: String?

    /// Duration of the episode in seconds.
    public var duration: TimeInterval

    /// Current playback position in seconds.
    public var elapsedTime: TimeInterval

    /// Current playback rate (1.0 = normal speed).
    public var playbackRate: Float

    /// Whether playback is currently active.
    public var isPlaying: Bool

    /// URL to the episode or podcast artwork.
    public var artworkURL: URL?

    /// Creates a new NowPlayingInfo instance.
    ///
    /// - Parameters:
    ///   - title: The episode title.
    ///   - podcastTitle: The podcast name.
    ///   - duration: Total duration in seconds.
    ///   - elapsedTime: Current position in seconds.
    ///   - playbackRate: Playback speed multiplier.
    ///   - isPlaying: Whether audio is currently playing.
    ///   - artworkURL: Optional artwork URL.
    public init(
        title: String? = nil,
        podcastTitle: String? = nil,
        duration: TimeInterval = 0,
        elapsedTime: TimeInterval = 0,
        playbackRate: Float = 1.0,
        isPlaying: Bool = false,
        artworkURL: URL? = nil
    ) {
        self.title = title
        self.podcastTitle = podcastTitle
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate
        self.isPlaying = isPlaying
        self.artworkURL = artworkURL
    }
}

// MARK: - RemoteCommandAction

/// Actions triggered by remote control events.
///
/// These correspond to buttons on headphones, the lock screen,
/// and Control Center.
public enum RemoteCommandAction: Sendable {
    case play
    case pause
    case togglePlayPause
    case nextTrack
    case previousTrack
    case skipForward(seconds: TimeInterval)
    case skipBackward(seconds: TimeInterval)
    case seekTo(position: TimeInterval)
    case changePlaybackRate(rate: Float)
}

// MARK: - NowPlayingManagerDelegate

/// Protocol for receiving remote control command events.
///
/// Implement this delegate to handle user interactions from the lock screen,
/// Control Center, or external accessories like headphones.
public protocol NowPlayingManagerDelegate: AnyObject, Sendable {

    /// Called when a remote control command is received.
    ///
    /// - Parameter action: The command action to perform.
    func nowPlayingManager(didReceiveCommand action: RemoteCommandAction)
}

// MARK: - NowPlayingManaging Protocol

/// Protocol defining Now Playing management operations.
///
/// This protocol enables dependency injection and testing of
/// MPNowPlayingInfoCenter interactions.
public protocol NowPlayingManaging: AnyObject, Sendable {

    /// The delegate receiving remote command events.
    var delegate: NowPlayingManagerDelegate? { get set }

    /// Updates the Now Playing information displayed on the lock screen.
    ///
    /// - Parameter info: The now playing information to display.
    func updateNowPlayingInfo(_ info: NowPlayingInfo)

    /// Clears all Now Playing information.
    func clearNowPlayingInfo()

    /// Updates only the elapsed time without refreshing all metadata.
    ///
    /// - Parameters:
    ///   - elapsedTime: Current playback position in seconds.
    ///   - playbackRate: Current playback rate.
    func updateElapsedTime(_ elapsedTime: TimeInterval, playbackRate: Float)

    /// Configures the skip interval for forward/backward commands.
    ///
    /// - Parameter seconds: The number of seconds to skip.
    func setSkipInterval(_ seconds: TimeInterval)

    /// Enables or disables remote command handling.
    ///
    /// - Parameter enabled: Whether to receive remote commands.
    func setRemoteCommandsEnabled(_ enabled: Bool)
}

// MARK: - NowPlayingManager

/// Manages the lock screen, Control Center, and remote control integration.
///
/// This class handles all interactions with MPNowPlayingInfoCenter and
/// MPRemoteCommandCenter, providing a clean interface for updating playback
/// metadata and responding to remote control events.
///
/// ## Usage
///
/// ```swift
/// let manager = NowPlayingManager()
/// manager.delegate = self
///
/// // Update displayed info
/// manager.updateNowPlayingInfo(NowPlayingInfo(
///     title: "Episode 1",
///     podcastTitle: "My Podcast",
///     duration: 3600,
///     elapsedTime: 0,
///     isPlaying: true
/// ))
///
/// // Handle remote commands in delegate
/// func nowPlayingManager(didReceiveCommand action: RemoteCommandAction) {
///     switch action {
///     case .play: audioPlayer.play()
///     case .pause: audioPlayer.pause()
///     // ...
///     }
/// }
/// ```
///
/// ## Threading
///
/// All public methods are thread-safe. Remote command callbacks are delivered
/// on the main thread.
@MainActor
public final class NowPlayingManager: NowPlayingManaging {

    // MARK: - Properties

    /// The delegate receiving remote command events.
    public weak var delegate: NowPlayingManagerDelegate?

    /// The MPNowPlayingInfoCenter for updating metadata.
    private let nowPlayingInfoCenter: MPNowPlayingInfoCenter

    /// The MPRemoteCommandCenter for handling commands.
    private let remoteCommandCenter: MPRemoteCommandCenter

    /// Current skip interval in seconds.
    private var skipInterval: TimeInterval = 15

    /// Cached artwork image to avoid repeated loading.
    private var cachedArtwork: MPMediaItemArtwork?

    /// URL of the currently cached artwork.
    private var cachedArtworkURL: URL?

    /// Flag indicating whether remote commands are currently enabled.
    private var remoteCommandsEnabled: Bool = false

    // MARK: - Initialization

    /// Creates a new NowPlayingManager.
    ///
    /// - Parameters:
    ///   - nowPlayingInfoCenter: The info center to use. Defaults to `.default()`.
    ///   - remoteCommandCenter: The command center to use. Defaults to `.shared()`.
    public init(
        nowPlayingInfoCenter: MPNowPlayingInfoCenter = .default(),
        remoteCommandCenter: MPRemoteCommandCenter = .shared()
    ) {
        self.nowPlayingInfoCenter = nowPlayingInfoCenter
        self.remoteCommandCenter = remoteCommandCenter

        configureRemoteCommands()
    }

    deinit {
        Task { @MainActor [remoteCommandCenter] in
            disableAllRemoteCommands(remoteCommandCenter)
        }
    }

    // MARK: - NowPlayingManaging

    /// Updates the Now Playing information displayed on the lock screen.
    ///
    /// - Parameter info: The now playing information to display.
    public func updateNowPlayingInfo(_ info: NowPlayingInfo) {
        var nowPlayingDict: [String: Any] = [
            MPMediaItemPropertyPlaybackDuration: info.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: info.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: info.isPlaying ? info.playbackRate : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        if let title = info.title {
            nowPlayingDict[MPMediaItemPropertyTitle] = title
        }

        if let podcastTitle = info.podcastTitle {
            nowPlayingDict[MPMediaItemPropertyArtist] = podcastTitle
            nowPlayingDict[MPMediaItemPropertyAlbumTitle] = podcastTitle
        }

        // Load artwork if URL changed
        if let artworkURL = info.artworkURL {
            if artworkURL != cachedArtworkURL {
                loadArtwork(from: artworkURL) { [weak self] artwork in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.cachedArtwork = artwork
                        self.cachedArtworkURL = artworkURL
                        if let artwork = artwork {
                            var updatedDict = self.nowPlayingInfoCenter.nowPlayingInfo ?? [:]
                            updatedDict[MPMediaItemPropertyArtwork] = artwork
                            self.nowPlayingInfoCenter.nowPlayingInfo = updatedDict
                        }
                    }
                }
            } else if let cachedArtwork = cachedArtwork {
                nowPlayingDict[MPMediaItemPropertyArtwork] = cachedArtwork
            }
        }

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingDict
    }

    /// Clears all Now Playing information.
    public func clearNowPlayingInfo() {
        nowPlayingInfoCenter.nowPlayingInfo = nil
        cachedArtwork = nil
        cachedArtworkURL = nil
    }

    /// Updates only the elapsed time without refreshing all metadata.
    ///
    /// This is more efficient for frequent position updates during playback.
    ///
    /// - Parameters:
    ///   - elapsedTime: Current playback position in seconds.
    ///   - playbackRate: Current playback rate.
    public func updateElapsedTime(_ elapsedTime: TimeInterval, playbackRate: Float) {
        guard var nowPlayingDict = nowPlayingInfoCenter.nowPlayingInfo else { return }

        nowPlayingDict[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        nowPlayingDict[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingDict
    }

    /// Configures the skip interval for forward/backward commands.
    ///
    /// - Parameter seconds: The number of seconds to skip.
    public func setSkipInterval(_ seconds: TimeInterval) {
        skipInterval = seconds
        remoteCommandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: seconds)]
        remoteCommandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: seconds)]
    }

    /// Enables or disables remote command handling.
    ///
    /// - Parameter enabled: Whether to receive remote commands.
    public func setRemoteCommandsEnabled(_ enabled: Bool) {
        remoteCommandsEnabled = enabled

        remoteCommandCenter.playCommand.isEnabled = enabled
        remoteCommandCenter.pauseCommand.isEnabled = enabled
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = enabled
        remoteCommandCenter.nextTrackCommand.isEnabled = enabled
        remoteCommandCenter.previousTrackCommand.isEnabled = enabled
        remoteCommandCenter.skipForwardCommand.isEnabled = enabled
        remoteCommandCenter.skipBackwardCommand.isEnabled = enabled
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = enabled
        remoteCommandCenter.changePlaybackRateCommand.isEnabled = enabled
    }

    // MARK: - Private Methods

    /// Configures remote command handlers.
    private func configureRemoteCommands() {
        // Play
        remoteCommandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(didReceiveCommand: .play)
            }
            return .success
        }

        // Pause
        remoteCommandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(didReceiveCommand: .pause)
            }
            return .success
        }

        // Toggle Play/Pause (headphone button)
        remoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(didReceiveCommand: .togglePlayPause)
            }
            return .success
        }

        // Next Track
        remoteCommandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(didReceiveCommand: .nextTrack)
            }
            return .success
        }

        // Previous Track
        remoteCommandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(didReceiveCommand: .previousTrack)
            }
            return .success
        }

        // Skip Forward
        remoteCommandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(
                    didReceiveCommand: .skipForward(seconds: skipEvent.interval)
                )
            }
            return .success
        }

        // Skip Backward
        remoteCommandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(
                    didReceiveCommand: .skipBackward(seconds: skipEvent.interval)
                )
            }
            return .success
        }

        // Seek (scrubbing)
        remoteCommandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(
                    didReceiveCommand: .seekTo(position: positionEvent.positionTime)
                )
            }
            return .success
        }

        // Playback Rate
        remoteCommandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let rateEvent = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.delegate?.nowPlayingManager(
                    didReceiveCommand: .changePlaybackRate(rate: rateEvent.playbackRate)
                )
            }
            return .success
        }

        // Configure supported playback rates
        remoteCommandCenter.changePlaybackRateCommand.supportedPlaybackRates = [
            0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0
        ]

        // Set default skip intervals
        setSkipInterval(skipInterval)

        // Enable commands by default
        setRemoteCommandsEnabled(true)
    }

    /// Disables all remote commands (called on deinit).
    private nonisolated func disableAllRemoteCommands(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.changePlaybackRateCommand.isEnabled = false
    }

    /// Loads artwork from a URL asynchronously.
    ///
    /// - Parameters:
    ///   - url: The URL to load artwork from.
    ///   - completion: Callback with the loaded artwork, or nil on failure.
    private nonisolated func loadArtwork(
        from url: URL,
        completion: @escaping @Sendable (MPMediaItemArtwork?) -> Void
    ) {
        Task.detached(priority: .utility) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                #if canImport(UIKit)
                guard let image = UIImage(data: data) else {
                    await MainActor.run { completion(nil) }
                    return
                }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                await MainActor.run { completion(artwork) }
                #else
                await MainActor.run { completion(nil) }
                #endif
            } catch {
                await MainActor.run { completion(nil) }
            }
        }
    }
}

// MARK: - Preview/Testing Support

#if DEBUG
/// A mock implementation of NowPlayingManaging for testing.
public final class MockNowPlayingManager: NowPlayingManaging, @unchecked Sendable {

    public weak var delegate: NowPlayingManagerDelegate?

    /// The last info passed to updateNowPlayingInfo.
    public private(set) var lastUpdatedInfo: NowPlayingInfo?

    /// Whether clearNowPlayingInfo was called.
    public private(set) var didClearNowPlayingInfo: Bool = false

    /// The last elapsed time update.
    public private(set) var lastElapsedTimeUpdate: (time: TimeInterval, rate: Float)?

    /// The configured skip interval.
    public private(set) var currentSkipInterval: TimeInterval = 15

    /// Whether remote commands are enabled.
    public private(set) var areRemoteCommandsEnabled: Bool = false

    public init() {}

    public func updateNowPlayingInfo(_ info: NowPlayingInfo) {
        lastUpdatedInfo = info
    }

    public func clearNowPlayingInfo() {
        didClearNowPlayingInfo = true
        lastUpdatedInfo = nil
    }

    public func updateElapsedTime(_ elapsedTime: TimeInterval, playbackRate: Float) {
        lastElapsedTimeUpdate = (elapsedTime, playbackRate)
    }

    public func setSkipInterval(_ seconds: TimeInterval) {
        currentSkipInterval = seconds
    }

    public func setRemoteCommandsEnabled(_ enabled: Bool) {
        areRemoteCommandsEnabled = enabled
    }

    /// Simulates receiving a remote command for testing.
    public func simulateRemoteCommand(_ action: RemoteCommandAction) {
        delegate?.nowPlayingManager(didReceiveCommand: action)
    }
}
#endif
