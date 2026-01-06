//
//  MediaCacheService.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation
import OSLog

/// A service for downloading and caching podcast media files.
///
/// MediaCacheService manages the download and local caching of podcast episodes,
/// supporting both foreground and background downloads with progress tracking.
///
/// ## Overview
///
/// This service replaces the legacy Objective-C MediaCache singleton with a modern
/// Swift implementation using async/await and the Observation framework.
///
/// ## Features
///
/// - Async/await API for all cache operations
/// - Background download support for large files
/// - Real-time download progress tracking via AsyncStream
/// - Persistent entry-to-RSS feed mapping using UserDefaults
/// - Automatic cleanup of orphaned cache entries
///
/// ## Usage
///
/// ```swift
/// let cacheService = MediaCacheService.shared
///
/// // Check if episode is cached
/// if let localURL = await cacheService.cachedURL(for: episodeURL) {
///     // Use local file
/// }
///
/// // Download episode with progress
/// for try await progress in cacheService.downloadProgressStream(for: episodeURL) {
///     print("Progress: \(progress.percentComplete ?? 0)%")
/// }
/// ```
///
/// ## Thread Safety
///
/// This service is designed to be used from any context. Internal state
/// is protected by an actor, ensuring thread-safe access to the download
/// queue and cache mappings.
@Observable
public final class MediaCacheService: Sendable {

    // MARK: - Shared Instance

    /// The shared media cache service instance.
    public static let shared = MediaCacheService()

    // MARK: - Constants

    private enum Constants {
        static let mediaCacheDirectoryName = "media"
        static let entryToRSSMappingKey = "entryToRSSMapping"
        static let backgroundSessionIdentifier = "com.jogpod.mediacache.background"
        static let maxConcurrentDownloads = 3
    }

    // MARK: - Private Properties

    /// The actor managing internal state for thread safety.
    private let stateManager: MediaCacheStateManager

    /// Logger for cache operations.
    private let logger = Logger(subsystem: "com.jogpod", category: "MediaCache")

    /// The file manager instance.
    private let fileManager: FileManager

    /// UserDefaults for persistence.
    private let userDefaults: UserDefaults

    // MARK: - Observable Properties

    /// The current active downloads.
    @ObservationIgnored
    public private(set) var activeDownloads: [URL: DownloadTaskInfo] = [:]

    /// The total number of items in the cache.
    @ObservationIgnored
    public private(set) var cachedItemCount: Int = 0

    /// The total size of cached files in bytes.
    @ObservationIgnored
    public private(set) var totalCacheSizeBytes: Int64 = 0

    // MARK: - Initialization

    /// Creates a new media cache service.
    ///
    /// - Parameters:
    ///   - fileManager: The file manager to use. Defaults to `.default`.
    ///   - userDefaults: The user defaults to use. Defaults to `.standard`.
    public init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.stateManager = MediaCacheStateManager(
            fileManager: fileManager,
            userDefaults: userDefaults
        )
    }

    // MARK: - Public API - Cache Queries

    /// Returns the local cached URL for a podcast episode, if available.
    ///
    /// - Parameter remoteURL: The remote URL of the episode.
    /// - Returns: The local file URL if cached, nil otherwise.
    public func cachedURL(for remoteURL: URL) async -> URL? {
        await stateManager.cachedURL(for: remoteURL)
    }

    /// Returns the local cached URL for a podcast episode URL string, if available.
    ///
    /// - Parameter remoteURLString: The remote URL string of the episode.
    /// - Returns: The local file URL if cached, nil otherwise.
    public func cachedURL(for remoteURLString: String) async -> URL? {
        guard let url = URL(string: remoteURLString) else { return nil }
        return await cachedURL(for: url)
    }

    /// Checks whether an episode is cached.
    ///
    /// - Parameter remoteURL: The remote URL of the episode.
    /// - Returns: True if the episode is cached locally.
    public func isCached(_ remoteURL: URL) async -> Bool {
        await cachedURL(for: remoteURL) != nil
    }

    /// Checks whether an episode is cached.
    ///
    /// - Parameter remoteURLString: The remote URL string of the episode.
    /// - Returns: True if the episode is cached locally.
    public func isCached(_ remoteURLString: String) async -> Bool {
        guard let url = URL(string: remoteURLString) else { return false }
        return await isCached(url)
    }

    // MARK: - Public API - Downloads

    /// Downloads and caches a podcast episode.
    ///
    /// - Parameters:
    ///   - remoteURL: The remote URL of the episode to download.
    ///   - feedURL: The RSS feed URL this episode belongs to.
    ///   - useBackgroundSession: Whether to use a background download session.
    ///     Background sessions continue downloading even when the app is suspended.
    /// - Throws: `MediaCacheError` if the download fails.
    public func cacheEpisode(
        from remoteURL: URL,
        feedURL: URL,
        useBackgroundSession: Bool = false
    ) async throws {
        logger.info("Starting cache operation for: \(remoteURL.absoluteString)")

        // Check if already cached
        if await isCached(remoteURL) {
            logger.info("Episode already cached: \(remoteURL.absoluteString)")
            throw MediaCacheError.itemAlreadyCached(url: remoteURL.absoluteString)
        }

        // Check if download already in progress
        if await stateManager.isDownloadInProgress(for: remoteURL) {
            logger.info("Download already in progress: \(remoteURL.absoluteString)")
            throw MediaCacheError.downloadInProgress(url: remoteURL.absoluteString)
        }

        try await stateManager.downloadEpisode(
            from: remoteURL,
            feedURL: feedURL,
            useBackgroundSession: useBackgroundSession
        )

        logger.info("Successfully cached: \(remoteURL.absoluteString)")
    }

    /// Downloads and caches a podcast episode using URL strings.
    ///
    /// - Parameters:
    ///   - remoteURLString: The remote URL string of the episode.
    ///   - feedURLString: The RSS feed URL string this episode belongs to.
    ///   - useBackgroundSession: Whether to use a background download session.
    /// - Throws: `MediaCacheError` if URLs are invalid or download fails.
    public func cacheEpisode(
        from remoteURLString: String,
        feedURL feedURLString: String,
        useBackgroundSession: Bool = false
    ) async throws {
        guard let remoteURL = URL(string: remoteURLString) else {
            throw MediaCacheError.invalidDownloadURL(urlString: remoteURLString)
        }
        guard let feedURL = URL(string: feedURLString) else {
            throw MediaCacheError.invalidDownloadURL(urlString: feedURLString)
        }
        try await cacheEpisode(
            from: remoteURL,
            feedURL: feedURL,
            useBackgroundSession: useBackgroundSession
        )
    }

    /// Returns an async stream of download progress updates.
    ///
    /// - Parameter remoteURL: The URL being downloaded.
    /// - Returns: An async stream emitting progress updates.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// Task {
    ///     for await progress in cacheService.downloadProgressStream(for: url) {
    ///         updateUI(with: progress)
    ///     }
    /// }
    /// ```
    public func downloadProgressStream(
        for remoteURL: URL
    ) -> AsyncStream<DownloadProgress> {
        AsyncStream { continuation in
            Task {
                await stateManager.observeProgress(for: remoteURL) { progress in
                    continuation.yield(progress)
                }
                continuation.onTermination = { @Sendable _ in
                    Task {
                        await self.stateManager.stopObservingProgress(for: remoteURL)
                    }
                }
            }
        }
    }

    /// Cancels an in-progress download.
    ///
    /// - Parameter remoteURL: The URL of the download to cancel.
    public func cancelDownload(for remoteURL: URL) async {
        logger.info("Cancelling download: \(remoteURL.absoluteString)")
        await stateManager.cancelDownload(for: remoteURL)
    }

    /// Cancels all in-progress downloads.
    public func cancelAllDownloads() async {
        logger.info("Cancelling all downloads")
        await stateManager.cancelAllDownloads()
    }

    // MARK: - Public API - Cache Management

    /// Deletes a cached episode.
    ///
    /// - Parameter remoteURL: The remote URL of the episode to delete.
    /// - Throws: `MediaCacheError` if deletion fails.
    public func deleteFromCache(_ remoteURL: URL) async throws {
        logger.info("Deleting from cache: \(remoteURL.absoluteString)")
        try await stateManager.deleteFromCache(remoteURL)
    }

    /// Deletes a cached episode using a URL string.
    ///
    /// - Parameter remoteURLString: The remote URL string of the episode to delete.
    /// - Throws: `MediaCacheError` if the URL is invalid or deletion fails.
    public func deleteFromCache(_ remoteURLString: String) async throws {
        guard let url = URL(string: remoteURLString) else {
            throw MediaCacheError.invalidDownloadURL(urlString: remoteURLString)
        }
        try await deleteFromCache(url)
    }

    /// Clears all cached media files.
    ///
    /// This removes all downloaded episodes and clears the entry-to-RSS mapping.
    public func clearAllCache() async throws {
        logger.info("Clearing all cached media")
        try await stateManager.clearAllCache()
    }

    /// Returns information about the current cache state.
    ///
    /// - Returns: A tuple containing the number of cached items and total size.
    public func cacheInfo() async -> (itemCount: Int, totalBytes: Int64) {
        await stateManager.cacheInfo()
    }

    // MARK: - Background Session Support

    /// Handles events for a background URL session.
    ///
    /// Call this from your AppDelegate's `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    ///
    /// - Parameters:
    ///   - identifier: The background session identifier.
    ///   - completionHandler: The completion handler provided by the system.
    public func handleBackgroundSessionEvents(
        forIdentifier identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        guard identifier == Constants.backgroundSessionIdentifier else {
            completionHandler()
            return
        }
        Task {
            await stateManager.setBackgroundCompletionHandler(completionHandler)
        }
    }
}

// MARK: - MediaCacheStateManager Actor

/// An actor managing the internal state of MediaCacheService.
///
/// This actor ensures thread-safe access to the cache directory,
/// download tasks, and entry mappings.
private actor MediaCacheStateManager {

    // MARK: - Properties

    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.jogpod", category: "MediaCacheState")

    private var cacheDirectory: URL?
    private var downloadTasks: [URL: URLSessionDownloadTask] = [:]
    private var progressObservers: [URL: (DownloadProgress) -> Void] = [:]
    private var progressData: [URL: ProgressTracker] = [:]
    private var backgroundCompletionHandler: (@Sendable () -> Void)?

    private lazy var foregroundSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 3600 // 1 hour for large files
        return URLSession(configuration: configuration)
    }()

    private var backgroundSession: URLSession?
    private var backgroundDelegate: BackgroundDownloadDelegate?

    // MARK: - Initialization

    init(fileManager: FileManager, userDefaults: UserDefaults) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        initializeCacheDirectory()
        initializeEntryMapping()
    }

    // MARK: - Directory Management

    private func initializeCacheDirectory() {
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            logger.error("Could not locate caches directory")
            return
        }

        let mediaCacheURL = cachesURL.appendingPathComponent("media", isDirectory: true)

        do {
            if !fileManager.fileExists(atPath: mediaCacheURL.path) {
                try fileManager.createDirectory(at: mediaCacheURL, withIntermediateDirectories: true)
                logger.info("Created media cache directory")
            }
            cacheDirectory = mediaCacheURL
        } catch {
            logger.error("Failed to create cache directory: \(error.localizedDescription)")
        }
    }

    private func initializeEntryMapping() {
        if userDefaults.dictionary(forKey: "entryToRSSMapping") == nil {
            userDefaults.set([String: String](), forKey: "entryToRSSMapping")
        }
    }

    // MARK: - Cache Queries

    func cachedURL(for remoteURL: URL) -> URL? {
        guard let cacheDir = cacheDirectory else { return nil }

        let feedURL = entryToFeedMapping(for: remoteURL.absoluteString)
        guard let feedURLString = feedURL else { return nil }

        let fileName = self.fileName(forFeedURL: feedURLString, entryURL: remoteURL.absoluteString)
        let localPath = cacheDir.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: localPath.path) {
            return localPath
        }
        return nil
    }

    func isDownloadInProgress(for url: URL) -> Bool {
        downloadTasks[url] != nil
    }

    // MARK: - Download Operations

    func downloadEpisode(
        from remoteURL: URL,
        feedURL: URL,
        useBackgroundSession: Bool
    ) async throws {
        guard let cacheDir = cacheDirectory else {
            throw MediaCacheError.cacheDirectoryUnavailable
        }

        // Check if already cached
        let existingMapping = entryToFeedMapping(for: remoteURL.absoluteString)
        let fileName = self.fileName(forFeedURL: feedURL.absoluteString, entryURL: remoteURL.absoluteString)
        let localURL = cacheDir.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: localURL.path) {
            if existingMapping != nil {
                // File exists with valid mapping
                throw MediaCacheError.itemAlreadyCached(url: remoteURL.absoluteString)
            } else {
                // Orphaned file, remove it
                try? fileManager.removeItem(at: localURL)
            }
        } else if existingMapping != nil {
            // Mapping exists but file doesn't - clean up orphaned mapping
            removeEntryToFeedMapping(for: remoteURL.absoluteString)
        }

        // Perform download
        let session = useBackgroundSession ? getBackgroundSession() : foregroundSession

        do {
            let (tempURL, response) = try await session.download(from: remoteURL)

            // Validate response
            if let httpResponse = response as? HTTPURLResponse {
                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw MediaCacheError.httpError(
                        url: remoteURL.absoluteString,
                        statusCode: httpResponse.statusCode
                    )
                }
            }

            // Move to cache location
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }

            try fileManager.moveItem(at: tempURL, to: localURL)

            // Save mapping
            saveEntryToFeedMapping(entryURL: remoteURL.absoluteString, feedURL: feedURL.absoluteString)

            logger.info("Successfully downloaded and cached: \(remoteURL.absoluteString)")

        } catch let urlError as URLError {
            throw MediaCacheError.fromURLError(urlError, url: remoteURL.absoluteString)
        } catch let cacheError as MediaCacheError {
            throw cacheError
        } catch {
            throw MediaCacheError.downloadFailed(
                url: remoteURL.absoluteString,
                reason: error.localizedDescription
            )
        }
    }

    private func getBackgroundSession() -> URLSession {
        if let session = backgroundSession {
            return session
        }

        let configuration = URLSessionConfiguration.background(
            withIdentifier: "com.jogpod.mediacache.background"
        )
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true

        let delegate = BackgroundDownloadDelegate()
        self.backgroundDelegate = delegate

        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        self.backgroundSession = session
        return session
    }

    // MARK: - Progress Observation

    func observeProgress(for url: URL, callback: @escaping (DownloadProgress) -> Void) {
        progressObservers[url] = callback
    }

    func stopObservingProgress(for url: URL) {
        progressObservers.removeValue(forKey: url)
    }

    func reportProgress(_ progress: DownloadProgress, for url: URL) {
        progressObservers[url]?(progress)
    }

    // MARK: - Cancel Operations

    func cancelDownload(for url: URL) {
        if let task = downloadTasks.removeValue(forKey: url) {
            task.cancel()
        }
        progressObservers.removeValue(forKey: url)
        progressData.removeValue(forKey: url)
    }

    func cancelAllDownloads() {
        for (_, task) in downloadTasks {
            task.cancel()
        }
        downloadTasks.removeAll()
        progressObservers.removeAll()
        progressData.removeAll()
    }

    // MARK: - Cache Management

    func deleteFromCache(_ url: URL) throws {
        guard let cacheDir = cacheDirectory else {
            throw MediaCacheError.cacheDirectoryUnavailable
        }

        guard let feedURLString = entryToFeedMapping(for: url.absoluteString) else {
            throw MediaCacheError.itemNotCached(url: url.absoluteString)
        }

        let fileName = self.fileName(forFeedURL: feedURLString, entryURL: url.absoluteString)
        let localURL = cacheDir.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: localURL.path) {
            do {
                try fileManager.removeItem(at: localURL)
                removeEntryToFeedMapping(for: url.absoluteString)
                logger.info("Deleted cached file: \(url.absoluteString)")
            } catch {
                throw MediaCacheError.fileDeletionError(
                    path: localURL.path,
                    reason: error.localizedDescription
                )
            }
        } else {
            // File doesn't exist but mapping does - clean up mapping
            removeEntryToFeedMapping(for: url.absoluteString)
        }
    }

    func clearAllCache() throws {
        guard let cacheDir = cacheDirectory else {
            throw MediaCacheError.cacheDirectoryUnavailable
        }

        // Clear all mappings
        userDefaults.set([String: String](), forKey: "entryToRSSMapping")

        // Delete all files in cache directory
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
            logger.info("Cleared all cached media files")
        } catch {
            throw MediaCacheError.fileDeletionError(
                path: cacheDir.path,
                reason: error.localizedDescription
            )
        }
    }

    func cacheInfo() -> (itemCount: Int, totalBytes: Int64) {
        guard let cacheDir = cacheDirectory else {
            return (0, 0)
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.fileSizeKey]
            )

            var totalSize: Int64 = 0
            for fileURL in contents {
                if let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }

            return (contents.count, totalSize)
        } catch {
            return (0, 0)
        }
    }

    // MARK: - Entry-to-RSS Mapping

    private func entryToFeedMapping(for entryURL: String) -> String? {
        guard let mappings = userDefaults.dictionary(forKey: "entryToRSSMapping") as? [String: String] else {
            return nil
        }
        return mappings[entryURL]
    }

    private func saveEntryToFeedMapping(entryURL: String, feedURL: String) {
        var mappings = (userDefaults.dictionary(forKey: "entryToRSSMapping") as? [String: String]) ?? [:]
        mappings[entryURL] = feedURL
        userDefaults.set(mappings, forKey: "entryToRSSMapping")
        logger.debug("Saved mapping: \(entryURL) -> \(feedURL)")
    }

    private func removeEntryToFeedMapping(for entryURL: String) {
        var mappings = (userDefaults.dictionary(forKey: "entryToRSSMapping") as? [String: String]) ?? [:]
        mappings.removeValue(forKey: entryURL)
        userDefaults.set(mappings, forKey: "entryToRSSMapping")
        logger.debug("Removed mapping for: \(entryURL)")
    }

    // MARK: - File Naming

    /// Generates a unique file name for a cached entry.
    ///
    /// This mirrors the legacy Objective-C behavior of using base64-encoded URLs
    /// with file extensions preserved.
    private func fileName(forFeedURL feedURL: String, entryURL: String) -> String {
        // Use base64 encoding of the feed URL as the base name
        let encodedString = Data(feedURL.utf8).base64EncodedString()
        let safeFileName = encodedString.replacingOccurrences(of: "/", with: "_")

        // Extract extension from entry URL, limited to 3 chars if longer than 5
        var fileExtension = (entryURL as NSString).pathExtension
        if fileExtension.count > 5 {
            fileExtension = String(fileExtension.prefix(3))
        }

        if fileExtension.isEmpty {
            return safeFileName
        }
        return "\(safeFileName).\(fileExtension)"
    }

    // MARK: - Background Session Support

    func setBackgroundCompletionHandler(_ handler: @escaping @Sendable () -> Void) {
        backgroundCompletionHandler = handler
    }

    func invokeBackgroundCompletionHandler() {
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}

// MARK: - Progress Tracker

private struct ProgressTracker {
    var lastBytesWritten: Int64 = 0
    var lastTimestamp: Date = Date()

    mutating func calculateSpeed(currentBytes: Int64) -> Double? {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTimestamp)

        guard elapsed > 0.1 else { return nil } // Avoid division by near-zero

        let bytesThisInterval = currentBytes - lastBytesWritten
        let speed = Double(bytesThisInterval) / elapsed

        lastBytesWritten = currentBytes
        lastTimestamp = now

        return speed
    }
}

// MARK: - BackgroundDownloadDelegate

private final class BackgroundDownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Background downloads are handled by the state manager
        // This delegate captures events for the background session
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Progress tracking for background downloads
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        if let error = error {
            // Log error for background downloads
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Called when all background tasks complete
    }
}
