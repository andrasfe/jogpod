//
//  AudioPlayerService.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer
import SwiftData
import os.log

private let audioLogger = Logger(subsystem: "com.motionscapes.jogpod", category: "AudioPlayer")

// MARK: - Playback State

/// Represents the current state of the audio player.
public enum PlaybackState: Equatable, Sendable {
    /// Player is stopped with no item loaded.
    case idle

    /// An item is loaded but not playing.
    case paused

    /// Actively playing audio.
    case playing

    /// Loading or buffering media.
    case loading

    /// An error occurred during playback.
    case error(AudioPlayerError)

    public static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.paused, .paused),
             (.playing, .playing),
             (.loading, .loading):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - Playback Progress

/// Current playback progress information.
public struct PlaybackProgress: Equatable, Sendable {
    /// Current position in seconds.
    public let currentTime: TimeInterval

    /// Total duration in seconds. Negative if unknown.
    public let duration: TimeInterval

    /// Progress as a fraction (0.0 to 1.0).
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    /// Remaining time in seconds.
    public var remainingTime: TimeInterval {
        guard duration > 0 else { return 0 }
        return max(duration - currentTime, 0)
    }

    public init(currentTime: TimeInterval = 0, duration: TimeInterval = -1) {
        self.currentTime = currentTime
        self.duration = duration
    }
}

// MARK: - Player Item Wrapper

/// Represents a playable episode in the queue.
///
/// This struct wraps a PodcastEpisode with additional playback state.
public struct PlayableItem: Identifiable, Equatable, Sendable {
    /// Unique identifier for the item.
    public let id: String

    /// The episode's persistent identifier.
    public let episodeID: PersistentIdentifier

    /// Episode title.
    public let title: String?

    /// Podcast (feed) title.
    public let podcastTitle: String?

    /// URL to the media file.
    public let mediaURL: URL

    /// Whether this item is cached for offline playback.
    public let isCached: Bool

    /// Artwork URL.
    public let artworkURL: URL?

    /// Saved playback position in seconds.
    public var savedPosition: TimeInterval

    /// Creates a PlayableItem from a PodcastEpisode.
    ///
    /// - Parameters:
    ///   - episode: The source episode.
    ///   - cachedURL: Optional cached file URL.
    /// - Returns: A PlayableItem, or nil if the episode has no media URL.
    public static func from(
        episode: PodcastEpisode,
        cachedURL: URL? = nil
    ) -> PlayableItem? {
        guard let mediaURLString = episode.enclosureMediaLink,
              let mediaURL = cachedURL ?? URL(string: mediaURLString) else {
            return nil
        }

        return PlayableItem(
            id: episode.identifier ?? UUID().uuidString,
            episodeID: episode.persistentModelID,
            title: episode.displayTitle,
            podcastTitle: episode.feed?.title,
            mediaURL: mediaURL,
            isCached: cachedURL != nil,
            artworkURL: episode.feed?.imageUrl.flatMap { URL(string: $0) },
            savedPosition: 0 // Position will be loaded from persistence
        )
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when the player status changes (playing/paused).
    static let playerStatusChanged = Notification.Name("playerStatusChanged")

    /// Posted when the current podcast item changes.
    static let podcastItemChanged = Notification.Name("podcastItemChanged")

    /// Posted when the playlist is refreshed.
    static let playlistRefreshed = Notification.Name("playlistRefreshed")

    /// Posted when playback position is updated.
    static let playbackPositionUpdated = Notification.Name("playbackPositionUpdated")
}

// MARK: - AudioPlayerServiceDelegate

/// Delegate protocol for receiving audio player events.
public protocol AudioPlayerServiceDelegate: AnyObject {
    /// Called when playback state changes.
    func audioPlayerService(_ service: AudioPlayerService, didChangeState state: PlaybackState)

    /// Called when the current item changes.
    func audioPlayerService(_ service: AudioPlayerService, didChangeItem item: PlayableItem?)

    /// Called periodically during playback with progress updates.
    func audioPlayerService(_ service: AudioPlayerService, didUpdateProgress progress: PlaybackProgress)

    /// Called when an error occurs.
    func audioPlayerService(_ service: AudioPlayerService, didEncounterError error: AudioPlayerError)

    /// Called when an item finishes playing.
    func audioPlayerService(_ service: AudioPlayerService, didFinishItem item: PlayableItem)
}

// MARK: - Default Delegate Implementation

public extension AudioPlayerServiceDelegate {
    func audioPlayerService(_ service: AudioPlayerService, didChangeState state: PlaybackState) {}
    func audioPlayerService(_ service: AudioPlayerService, didChangeItem item: PlayableItem?) {}
    func audioPlayerService(_ service: AudioPlayerService, didUpdateProgress progress: PlaybackProgress) {}
    func audioPlayerService(_ service: AudioPlayerService, didEncounterError error: AudioPlayerError) {}
    func audioPlayerService(_ service: AudioPlayerService, didFinishItem item: PlayableItem) {}
}

// MARK: - AudioPlayerService

/// Unified audio playback service for podcast episodes.
///
/// This service replaces the legacy UniversalPlayerController/PlayerController hierarchy,
/// providing modern Swift async/await APIs, Combine publishers, and proper handling
/// of background audio, interruptions, and lock screen controls.
///
/// ## Features
///
/// - Background audio playback
/// - Lock screen and Control Center integration
/// - Audio interruption handling (phone calls, etc.)
/// - Playback position persistence
/// - Variable playback speed (0.5x - 2.0x)
/// - Skip forward/backward
///
/// ## Usage
///
/// ```swift
/// let player = AudioPlayerService(
///     persistenceManager: persistenceManager,
///     nowPlayingManager: nowPlayingManager
/// )
///
/// // Load playlist
/// try await player.loadPlaylist()
///
/// // Control playback
/// try player.play()
/// player.pause()
/// try await player.seekTo(seconds: 120)
/// ```
///
/// ## Notifications
///
/// The service posts these notifications:
/// - `playerStatusChanged`: When play/pause state changes
/// - `podcastItemChanged`: When the current episode changes
/// - `playbackPositionUpdated`: When playback position updates
@MainActor
public final class AudioPlayerService: NSObject, Sendable {

    // MARK: - Constants

    /// Valid range for playback rate.
    public static let validPlaybackRateRange: ClosedRange<Float> = 0.5...2.0

    /// Default skip interval in seconds.
    public static let defaultSkipInterval: TimeInterval = 15

    // MARK: - Published Properties

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

    // MARK: - Properties

    /// Delegate for receiving playback events.
    public weak var delegate: AudioPlayerServiceDelegate?

    /// The persistence manager for saving/loading state.
    private let persistenceManager: PersistenceManager

    /// The Now Playing manager for lock screen integration.
    private let nowPlayingManager: NowPlayingManaging

    /// The underlying AVQueuePlayer.
    private var queuePlayer: AVQueuePlayer?

    /// Time observer for periodic progress updates.
    private var timeObserver: Any?

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Key-Value observers.
    private var playerItemObservers: [NSKeyValueObservation] = []

    /// Audio session for background playback.
    private let audioSession: AVAudioSession

    /// Current index in the playlist.
    private var currentIndex: Int = 0

    /// Skip interval in seconds.
    private var skipInterval: TimeInterval = AudioPlayerService.defaultSkipInterval

    /// Flag to track if we were playing before interruption.
    private var wasPlayingBeforeInterruption: Bool = false

    // MARK: - Initialization

    /// Creates a new AudioPlayerService.
    ///
    /// - Parameters:
    ///   - persistenceManager: Manager for saving playback state.
    ///   - nowPlayingManager: Manager for lock screen integration.
    ///   - audioSession: Audio session to use. Defaults to shared instance.
    public init(
        persistenceManager: PersistenceManager,
        nowPlayingManager: NowPlayingManaging,
        audioSession: AVAudioSession = .sharedInstance()
    ) {
        self.persistenceManager = persistenceManager
        self.nowPlayingManager = nowPlayingManager
        self.audioSession = audioSession

        super.init()

        Task { @MainActor in
            self.setupNowPlayingDelegate()
            try? self.configureAudioSession()
            self.observeInterruptions()
            self.observeRouteChanges()
            await self.loadSkipIntervalFromPreferences()
        }
    }

    deinit {
        Task { @MainActor in
            self.cleanup()
        }
    }

    // MARK: - Audio Session Configuration

    /// Configures the audio session for background playback.
    ///
    /// - Throws: `AudioPlayerError` if configuration fails.
    public func configureAudioSession() throws {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowBluetooth, .allowAirPlay]
            )
            try audioSession.setActive(true)
        } catch {
            throw AudioPlayerError.audioSessionConfigurationFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Playlist Management

    /// Loads the playlist from persistence.
    ///
    /// This fetches all episodes from the database and creates playable items.
    ///
    /// - Throws: Error if loading fails.
    public func loadPlaylist() async throws {
        // Only load episodes that have been explicitly added to the queue
        let episodes = try await persistenceManager.fetchQueuedEpisodes(sortedByIndex: true)

        print("[AudioPlayer] loadPlaylist: fetched \(episodes.count) queued episodes")

        playlist = episodes.compactMap { episode in
            // TODO: Check media cache for cached URL
            PlayableItem.from(episode: episode, cachedURL: nil)
        }

        print("[AudioPlayer] loadPlaylist: \(playlist.count) playable items in queue")

        // Find and restore current episode, or load first item
        if let currentEpisode = try await persistenceManager.fetchCurrentEpisode(),
           let index = playlist.firstIndex(where: { $0.episodeID == currentEpisode.persistentModelID }) {
            currentIndex = index
            await loadItem(at: index)
            print("[AudioPlayer] Restored current episode at index \(index)")
        } else if !playlist.isEmpty {
            // No saved episode - load the first item by default
            await loadItem(at: 0)
            print("[AudioPlayer] Loaded first item by default")
        } else {
            currentItem = nil
            print("[AudioPlayer] Queue is empty - no items to load")
        }

        NotificationCenter.default.post(name: .playlistRefreshed, object: self)
    }

    /// Loads an item at the specified index.
    ///
    /// - Parameter index: The index of the item to load.
    private func loadItem(at index: Int) async {
        guard index >= 0 && index < playlist.count else {
            state = .error(.invalidItemIndex(index: index, count: playlist.count))
            return
        }

        currentIndex = index
        var item = playlist[index]

        // Create player if needed
        if queuePlayer == nil {
            queuePlayer = AVQueuePlayer()
            setupTimeObserver()
        }

        // Create AVPlayerItem
        let playerItem = AVPlayerItem(url: item.mediaURL)
        observePlayerItem(playerItem)

        // Replace current item
        queuePlayer?.removeAllItems()
        queuePlayer?.insert(playerItem, after: nil)

        // Restore saved position from persistence
        let savedPosition = await loadSavedPosition(for: item.episodeID)
        item.savedPosition = savedPosition

        if savedPosition > 0 {
            let time = CMTime(seconds: savedPosition, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            await queuePlayer?.seek(to: time)
        }

        currentItem = item
        state = .paused

        // Update persistence
        try? await persistenceManager.setCurrentEpisode(item.episodeID)

        // Update Now Playing
        updateNowPlayingInfo()

        // Notify
        delegate?.audioPlayerService(self, didChangeItem: item)
        NotificationCenter.default.post(
            name: .podcastItemChanged,
            object: self,
            userInfo: ["item": item]
        )
    }

    // MARK: - Playback Controls

    /// Starts or resumes playback.
    ///
    /// - Throws: `AudioPlayerError` if playback cannot start.
    public func play() throws {
        guard let player = queuePlayer else {
            throw AudioPlayerError.playerUnavailable
        }

        guard currentItem != nil else {
            throw AudioPlayerError.noCurrentItem
        }

        audioLogger.info("play() called, setting rate to \(self.playbackRate)")
        print("[AudioPlayer] play() - playbackRate: \(playbackRate)")
        player.rate = playbackRate
        print("[AudioPlayer] play() - player.rate after set: \(player.rate)")
        audioLogger.info("player.rate is now \(player.rate)")
        state = .playing

        updateNowPlayingInfo()
        postStatusNotification(playing: true)

        delegate?.audioPlayerService(self, didChangeState: .playing)
    }

    /// Pauses playback.
    public func pause() {
        queuePlayer?.pause()
        state = .paused

        // Save current position
        Task {
            await saveCurrentPosition()
        }

        updateNowPlayingInfo()
        postStatusNotification(playing: false)

        delegate?.audioPlayerService(self, didChangeState: .paused)
    }

    /// Toggles between play and pause.
    public func togglePlayPause() throws {
        if state == .playing {
            pause()
        } else {
            try play()
        }
    }

    /// Stops playback and clears the current item.
    public func stop() {
        pause()
        queuePlayer?.removeAllItems()
        currentItem = nil
        state = .idle
        progress = PlaybackProgress()

        nowPlayingManager.clearNowPlayingInfo()

        delegate?.audioPlayerService(self, didChangeState: .idle)
        delegate?.audioPlayerService(self, didChangeItem: nil)
    }

    // MARK: - Navigation

    /// Advances to the next item in the playlist.
    ///
    /// If at the last item, wraps around to the first item.
    public func advanceToNextItem() async {
        let nextIndex = (currentIndex + 1) % max(playlist.count, 1)
        await loadItem(at: nextIndex)

        if state == .playing {
            try? play()
        }
    }

    /// Goes to the previous item in the playlist.
    ///
    /// If at the first item, wraps around to the last item.
    public func goToPreviousItem() async {
        let prevIndex = currentIndex > 0 ? currentIndex - 1 : max(playlist.count - 1, 0)
        await loadItem(at: prevIndex)

        if state == .playing {
            try? play()
        }
    }

    /// Goes to a specific item in the playlist.
    ///
    /// - Parameter index: The index of the item to play.
    /// - Throws: `AudioPlayerError` if the index is invalid.
    public func goToItem(at index: Int) async throws {
        guard index >= 0 && index < playlist.count else {
            throw AudioPlayerError.invalidItemIndex(index: index, count: playlist.count)
        }

        let wasPlaying = state == .playing
        await loadItem(at: index)

        if wasPlaying {
            try play()
        }
    }

    /// Goes to a specific episode by its identifier.
    ///
    /// - Parameter episodeID: The persistent identifier of the episode.
    /// - Throws: `AudioPlayerError` if the episode is not in the playlist.
    public func goToEpisode(_ episodeID: PersistentIdentifier) async throws {
        guard let index = playlist.firstIndex(where: { $0.episodeID == episodeID }) else {
            throw AudioPlayerError.itemLoadFailed(title: nil, reason: "Episode not found in playlist")
        }

        try await goToItem(at: index)
    }

    // MARK: - Queue Management

    /// Adds an episode to the end of the playlist queue.
    ///
    /// - Parameter episodeID: The persistent identifier of the episode to add.
    /// - Throws: Error if the episode cannot be found or added.
    public func addToEndOfQueue(_ episodeID: PersistentIdentifier) async throws {
        // First, ensure the episode is marked as in queue
        try await persistenceManager.addEpisodeToQueue(episodeID)

        // Check if it's already in our local playlist
        if let existingIndex = playlist.firstIndex(where: { $0.episodeID == episodeID }) {
            // If it's already the last item, nothing more to do
            if existingIndex == playlist.count - 1 {
                return
            }

            // Move the item to the end
            let item = playlist.remove(at: existingIndex)
            playlist.append(item)

            // Adjust currentIndex if needed
            if existingIndex < currentIndex {
                currentIndex -= 1
            } else if existingIndex == currentIndex {
                currentIndex = playlist.count - 1
            }

            // Update indices in persistence
            await updatePlaylistIndices()
        } else {
            // Episode wasn't in playlist - reload to pick it up
            try await loadPlaylist()
        }

        NotificationCenter.default.post(name: .playlistRefreshed, object: self)
    }

    /// Adds an episode to play immediately after the current item.
    ///
    /// - Parameter episodeID: The persistent identifier of the episode to add.
    /// - Throws: Error if the episode cannot be found or added.
    public func addToPlayNext(_ episodeID: PersistentIdentifier) async throws {
        // First, ensure the episode is marked as in queue
        try await persistenceManager.addEpisodeToQueue(episodeID)

        // Check if it's already in our local playlist
        if let existingIndex = playlist.firstIndex(where: { $0.episodeID == episodeID }) {
            let targetIndex = currentIndex + 1

            // If it's already in the target position, nothing to do
            if existingIndex == targetIndex {
                return
            }

            // Remove from current position
            let item = playlist.remove(at: existingIndex)

            // Calculate the adjusted target index after removal
            let adjustedTargetIndex: Int
            if existingIndex < targetIndex {
                adjustedTargetIndex = min(targetIndex - 1, playlist.count)
            } else {
                adjustedTargetIndex = min(targetIndex, playlist.count)
            }

            // Insert at the adjusted position
            playlist.insert(item, at: adjustedTargetIndex)

            // Adjust currentIndex if needed
            if existingIndex < currentIndex && adjustedTargetIndex >= currentIndex {
                currentIndex -= 1
            } else if existingIndex > currentIndex && adjustedTargetIndex <= currentIndex {
                currentIndex += 1
            }

            // Update indices in persistence
            await updatePlaylistIndices()
        } else {
            // Episode wasn't in playlist - reload to pick it up, then reposition
            try await loadPlaylist()

            // Now find and reposition the newly added episode
            if let newIndex = playlist.firstIndex(where: { $0.episodeID == episodeID }) {
                let targetIndex = min(currentIndex + 1, playlist.count - 1)

                if newIndex != targetIndex && newIndex < playlist.count {
                    let item = playlist.remove(at: newIndex)
                    playlist.insert(item, at: min(targetIndex, playlist.count))
                    await updatePlaylistIndices()
                }
            }
        }

        NotificationCenter.default.post(name: .playlistRefreshed, object: self)
    }

    /// Updates the index values in persistence to match the current playlist order.
    private func updatePlaylistIndices() async {
        for (index, item) in playlist.enumerated() {
            try? await persistenceManager.updateEpisodeIndex(item.episodeID, newIndex: Int32(index))
        }
    }

    // MARK: - Seeking

    /// Seeks to a specific position.
    ///
    /// - Parameter seconds: The position to seek to in seconds.
    /// - Throws: `AudioPlayerError` if seeking fails.
    public func seekTo(seconds: TimeInterval) async throws {
        guard let player = queuePlayer,
              let item = player.currentItem else {
            throw AudioPlayerError.noCurrentItem
        }

        let duration = item.duration.seconds
        guard duration.isFinite else {
            throw AudioPlayerError.seekFailed(reason: "Duration not available")
        }

        let clampedSeconds = max(0, min(seconds, duration))
        let time = CMTime(seconds: clampedSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        await player.seek(to: time)
        updateProgress()
        updateNowPlayingInfo()
    }

    /// Skips forward by the configured skip interval.
    ///
    /// - Parameter seconds: Optional override for seconds to skip forward.
    ///                      If nil, uses the configured skip interval.
    public func fastForward(seconds: TimeInterval? = nil) async {
        let skipAmount = seconds ?? skipInterval
        let newPosition = progress.currentTime + skipAmount
        try? await seekTo(seconds: newPosition)
    }

    /// Rewinds by the configured skip interval.
    ///
    /// - Parameter seconds: Optional override for seconds to rewind.
    ///                      If nil, uses the configured skip interval.
    public func rewind(seconds: TimeInterval? = nil) async {
        let skipAmount = seconds ?? skipInterval
        let newPosition = max(0, progress.currentTime - skipAmount)
        try? await seekTo(seconds: newPosition)
    }

    /// Updates the skip interval from user preferences.
    ///
    /// This loads the "forwardRewindTime" preference (in minutes) and converts
    /// it to seconds. Falls back to `defaultSkipInterval` if no preference exists.
    public func loadSkipIntervalFromPreferences() async {
        do {
            // Legacy preference is stored in minutes
            if let minutes: Int = try await persistenceManager.fetchPreference(
                name: "forwardRewindTime",
                as: Int.self
            ) {
                skipInterval = TimeInterval(minutes * 60)
            }
        } catch {
            // Use default on error
            skipInterval = Self.defaultSkipInterval
        }

        // Update Now Playing manager
        nowPlayingManager.setSkipInterval(skipInterval)
    }

    /// Sets a custom skip interval.
    ///
    /// - Parameter seconds: The new skip interval in seconds.
    public func setSkipInterval(_ seconds: TimeInterval) {
        skipInterval = max(1, seconds) // Minimum 1 second
        nowPlayingManager.setSkipInterval(skipInterval)
    }

    // MARK: - Playback Rate

    /// Sets the playback rate.
    ///
    /// - Parameter rate: The new playback rate (0.5 to 2.0).
    /// - Throws: `AudioPlayerError` if the rate is outside the valid range.
    public func setRate(_ rate: Float) throws {
        print("[AudioPlayer] setRate() called with rate: \(rate)")
        audioLogger.info("setRate() called with rate: \(rate)")
        guard Self.validPlaybackRateRange.contains(rate) else {
            audioLogger.error("Invalid rate: \(rate)")
            throw AudioPlayerError.invalidPlaybackRate(
                rate: rate,
                validRange: Self.validPlaybackRateRange
            )
        }

        playbackRate = rate
        audioLogger.info("playbackRate property set to: \(self.playbackRate)")

        if state == .playing {
            queuePlayer?.rate = rate
            audioLogger.info("Applied rate to playing player: \(rate)")
        } else {
            audioLogger.info("Player not playing (state: \(String(describing: self.state))), rate will apply on next play()")
        }

        updateNowPlayingInfo()
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
        guard let item = queuePlayer?.currentItem else { return -1 }
        let duration = item.duration.seconds
        return duration.isFinite ? duration : -1
    }

    /// The current playback position in seconds.
    public var currentPosition: TimeInterval {
        progress.currentTime
    }

    // MARK: - Private Methods

    /// Sets up the time observer for progress updates.
    private func setupTimeObserver() {
        guard let player = queuePlayer else { return }

        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time)
            }
        }
    }

    /// Handles periodic time updates.
    private func handleTimeUpdate(_ time: CMTime) {
        updateProgress()

        // Update Now Playing elapsed time
        nowPlayingManager.updateElapsedTime(
            progress.currentTime,
            playbackRate: state == .playing ? playbackRate : 0
        )

        // Post notification
        NotificationCenter.default.post(
            name: .playbackPositionUpdated,
            object: self,
            userInfo: [
                "currentTime": progress.currentTime,
                "duration": progress.duration
            ]
        )

        // Notify delegate
        delegate?.audioPlayerService(self, didUpdateProgress: progress)
    }

    /// Updates the progress property from the current player state.
    private func updateProgress() {
        guard let player = queuePlayer,
              let item = player.currentItem else {
            progress = PlaybackProgress()
            return
        }

        let currentTime = player.currentTime().seconds
        let duration = item.duration.seconds

        progress = PlaybackProgress(
            currentTime: currentTime.isFinite ? currentTime : 0,
            duration: duration.isFinite ? duration : -1
        )
    }

    /// Observes an AVPlayerItem for status changes.
    private func observePlayerItem(_ item: AVPlayerItem) {
        // Clear old observers
        playerItemObservers.forEach { $0.invalidate() }
        playerItemObservers.removeAll()

        // Status observer
        let statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.handlePlayerItemStatusChange(item)
            }
        }
        playerItemObservers.append(statusObserver)

        // Did play to end notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    /// Handles player item status changes.
    private func handlePlayerItemStatusChange(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            if state == .loading {
                state = .paused
            }
            updateProgress()
            updateNowPlayingInfo()

        case .failed:
            let error = AudioPlayerError.itemPlaybackFailed(
                title: currentItem?.title,
                error: item.error?.localizedDescription
            )
            state = .error(error)
            delegate?.audioPlayerService(self, didEncounterError: error)

        case .unknown:
            state = .loading

        @unknown default:
            break
        }
    }

    /// Called when a player item finishes playing.
    @objc private func playerItemDidPlayToEnd(_ notification: Notification) {
        guard let finishedItem = currentItem else { return }

        delegate?.audioPlayerService(self, didFinishItem: finishedItem)

        // Auto-advance to next item
        Task {
            await advanceToNextItem()
        }
    }

    /// Observes audio session interruptions.
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
    }

    /// Handles audio session interruptions (phone calls, etc.).
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                pause()
            }

        case .ended:
            if wasPlayingBeforeInterruption {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        try? play()
                    }
                }
            }
            wasPlayingBeforeInterruption = false

        @unknown default:
            break
        }
    }

    /// Observes audio route changes (headphones disconnected, etc.).
    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
    }

    /// Handles audio route changes.
    ///
    /// When headphones are disconnected, playback is paused to avoid
    /// audio playing through the speaker unexpectedly.
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were disconnected - pause playback
            if isPlaying {
                pause()
            }

        case .newDeviceAvailable:
            // New device connected (e.g., headphones) - no action needed
            break

        case .categoryChange:
            // Category changed, may need to reconfigure
            try? configureAudioSession()

        case .override, .wakeFromSleep, .noSuitableRouteForCategory,
             .routeConfigurationChange, .unknown:
            // No action needed for these cases
            break

        @unknown default:
            break
        }
    }

    /// Sets up the Now Playing manager delegate.
    private func setupNowPlayingDelegate() {
        if let manager = nowPlayingManager as? NowPlayingManager {
            manager.delegate = self
        }
        nowPlayingManager.setSkipInterval(skipInterval)
    }

    /// Updates the Now Playing info center.
    private func updateNowPlayingInfo() {
        guard let item = currentItem else {
            nowPlayingManager.clearNowPlayingInfo()
            return
        }

        let info = NowPlayingInfo(
            title: item.title,
            podcastTitle: item.podcastTitle,
            duration: progress.duration > 0 ? progress.duration : 0,
            elapsedTime: progress.currentTime,
            playbackRate: playbackRate,
            isPlaying: isPlaying,
            artworkURL: item.artworkURL
        )

        nowPlayingManager.updateNowPlayingInfo(info)
    }

    /// Saves the current playback position to persistence.
    ///
    /// This method saves the current playback position for the current episode,
    /// allowing playback to resume from where it left off.
    private func saveCurrentPosition() async {
        guard let item = currentItem else { return }

        let position = progress.currentTime

        // Only save if position is meaningful (greater than 1 second)
        guard position > 1 else { return }

        do {
            try await persistenceManager.saveEpisodePosition(
                episodeID: item.episodeID,
                position: position
            )
        } catch {
            // Log but don't propagate - position saving is non-critical
            delegate?.audioPlayerService(
                self,
                didEncounterError: .positionPersistenceFailed(reason: error.localizedDescription)
            )
        }
    }

    /// Loads the saved playback position for an episode.
    ///
    /// - Parameter episodeID: The persistent identifier of the episode.
    /// - Returns: The saved position in seconds, or 0 if none exists.
    private func loadSavedPosition(for episodeID: PersistentIdentifier) async -> TimeInterval {
        do {
            return try await persistenceManager.fetchEpisodePosition(episodeID: episodeID) ?? 0
        } catch {
            return 0
        }
    }

    /// Posts a status changed notification.
    private func postStatusNotification(playing: Bool) {
        NotificationCenter.default.post(
            name: .playerStatusChanged,
            object: self,
            userInfo: ["playing": playing]
        )
    }

    /// Cleans up resources.
    private func cleanup() {
        if let observer = timeObserver, let player = queuePlayer {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil

        playerItemObservers.forEach { $0.invalidate() }
        playerItemObservers.removeAll()

        NotificationCenter.default.removeObserver(self)

        queuePlayer?.pause()
        queuePlayer = nil

        // Deactivate audio session
        deactivateAudioSession()
    }

    /// Deactivates the audio session.
    ///
    /// This should be called when playback is completely finished and the
    /// service is being cleaned up. It allows other apps to use audio.
    public func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Log but don't fail - deactivation is best effort
            #if DEBUG
            print("AudioPlayerService: Failed to deactivate audio session: \(error)")
            #endif
        }
    }

    /// Reactivates the audio session after deactivation.
    ///
    /// This should be called before resuming playback after the audio session
    /// was deactivated.
    ///
    /// - Throws: `AudioPlayerError` if activation fails.
    public func reactivateAudioSession() throws {
        do {
            try audioSession.setActive(true)
        } catch {
            throw AudioPlayerError.audioSessionActivationFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - NowPlayingManagerDelegate

extension AudioPlayerService: NowPlayingManagerDelegate {

    nonisolated public func nowPlayingManager(didReceiveCommand action: RemoteCommandAction) {
        Task { @MainActor in
            await handleRemoteCommand(action)
        }
    }

    private func handleRemoteCommand(_ action: RemoteCommandAction) async {
        switch action {
        case .play:
            try? play()

        case .pause:
            pause()

        case .togglePlayPause:
            try? togglePlayPause()

        case .nextTrack:
            await advanceToNextItem()

        case .previousTrack:
            await goToPreviousItem()

        case .skipForward(let seconds):
            await fastForward(seconds: seconds)

        case .skipBackward(let seconds):
            await rewind(seconds: seconds)

        case .seekTo(let position):
            try? await seekTo(seconds: position)

        case .changePlaybackRate(let rate):
            try? setRate(rate)
        }
    }
}

// MARK: - Publisher Convenience

public extension AudioPlayerService {

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
