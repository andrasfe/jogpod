//
//  DownloadProgress.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation

/// Represents the progress of a media download operation.
///
/// This struct provides detailed information about an ongoing download,
/// including bytes transferred, estimated time remaining, and download speed.
public struct DownloadProgress: Sendable, Equatable {

    // MARK: - Properties

    /// The URL of the resource being downloaded.
    public let url: URL

    /// The number of bytes downloaded so far.
    public let bytesDownloaded: Int64

    /// The total expected number of bytes, if known.
    ///
    /// This may be nil if the server does not provide a Content-Length header.
    public let totalBytes: Int64?

    /// The fraction of the download completed, from 0.0 to 1.0.
    ///
    /// Returns nil if the total size is unknown.
    public var fractionCompleted: Double? {
        guard let total = totalBytes, total > 0 else { return nil }
        return Double(bytesDownloaded) / Double(total)
    }

    /// The download progress as a percentage (0-100).
    ///
    /// Returns nil if the total size is unknown.
    public var percentComplete: Int? {
        guard let fraction = fractionCompleted else { return nil }
        return Int(fraction * 100)
    }

    /// The current download speed in bytes per second.
    ///
    /// May be nil if speed cannot be calculated.
    public let bytesPerSecond: Double?

    /// Estimated time remaining in seconds.
    ///
    /// May be nil if the total size is unknown or speed cannot be calculated.
    public var estimatedTimeRemaining: TimeInterval? {
        guard let total = totalBytes,
              let speed = bytesPerSecond,
              speed > 0 else { return nil }
        let remainingBytes = total - bytesDownloaded
        return TimeInterval(remainingBytes) / speed
    }

    /// The timestamp when this progress was recorded.
    public let timestamp: Date

    // MARK: - Initialization

    /// Creates a new download progress instance.
    ///
    /// - Parameters:
    ///   - url: The URL of the resource being downloaded.
    ///   - bytesDownloaded: The number of bytes downloaded so far.
    ///   - totalBytes: The total expected number of bytes, if known.
    ///   - bytesPerSecond: The current download speed, if known.
    ///   - timestamp: The timestamp of this progress update. Defaults to now.
    public init(
        url: URL,
        bytesDownloaded: Int64,
        totalBytes: Int64?,
        bytesPerSecond: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.url = url
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.bytesPerSecond = bytesPerSecond
        self.timestamp = timestamp
    }

    // MARK: - Formatted Values

    /// A human-readable string representation of bytes downloaded.
    ///
    /// Example: "15.2 MB"
    public var formattedBytesDownloaded: String {
        ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
    }

    /// A human-readable string representation of total bytes.
    ///
    /// Example: "150.0 MB" or "Unknown" if total is nil.
    public var formattedTotalBytes: String {
        guard let total = totalBytes else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    /// A human-readable string representation of download speed.
    ///
    /// Example: "2.5 MB/s" or nil if speed is unknown.
    public var formattedSpeed: String? {
        guard let speed = bytesPerSecond else { return nil }
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file)
        return "\(formatted)/s"
    }

    /// A human-readable string representation of time remaining.
    ///
    /// Example: "2 minutes remaining" or nil if unknown.
    public var formattedTimeRemaining: String? {
        guard let remaining = estimatedTimeRemaining else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: remaining)
    }

    /// A combined progress string suitable for display.
    ///
    /// Example: "15.2 MB of 150.0 MB (10%)"
    public var formattedProgress: String {
        if let percent = percentComplete {
            return "\(formattedBytesDownloaded) of \(formattedTotalBytes) (\(percent)%)"
        } else {
            return "\(formattedBytesDownloaded) downloaded"
        }
    }
}

// MARK: - CustomStringConvertible

extension DownloadProgress: CustomStringConvertible {

    public var description: String {
        var parts = [formattedProgress]
        if let speed = formattedSpeed {
            parts.append("at \(speed)")
        }
        if let remaining = formattedTimeRemaining {
            parts.append("\(remaining) remaining")
        }
        return parts.joined(separator: " - ")
    }
}

// MARK: - CustomDebugStringConvertible

extension DownloadProgress: CustomDebugStringConvertible {

    public var debugDescription: String {
        """
        DownloadProgress(
            url: \(url.absoluteString),
            bytesDownloaded: \(bytesDownloaded),
            totalBytes: \(totalBytes.map(String.init) ?? "nil"),
            fractionCompleted: \(fractionCompleted.map(String.init) ?? "nil"),
            bytesPerSecond: \(bytesPerSecond.map(String.init) ?? "nil"),
            estimatedTimeRemaining: \(estimatedTimeRemaining.map(String.init) ?? "nil")
        )
        """
    }
}

// MARK: - Factory Methods

extension DownloadProgress {

    /// Creates a progress instance representing the start of a download.
    ///
    /// - Parameters:
    ///   - url: The URL being downloaded.
    ///   - totalBytes: The total expected bytes, if known from headers.
    /// - Returns: A DownloadProgress at 0 bytes.
    public static func starting(url: URL, totalBytes: Int64? = nil) -> DownloadProgress {
        DownloadProgress(
            url: url,
            bytesDownloaded: 0,
            totalBytes: totalBytes
        )
    }

    /// Creates a progress instance representing a completed download.
    ///
    /// - Parameters:
    ///   - url: The URL that was downloaded.
    ///   - totalBytes: The total bytes downloaded.
    /// - Returns: A DownloadProgress at 100% completion.
    public static func completed(url: URL, totalBytes: Int64) -> DownloadProgress {
        DownloadProgress(
            url: url,
            bytesDownloaded: totalBytes,
            totalBytes: totalBytes
        )
    }
}

// MARK: - Download State

/// The current state of a download task.
public enum DownloadState: Sendable, Equatable {

    /// The download has not started.
    case idle

    /// The download is waiting to begin (e.g., queued).
    case pending

    /// The download is actively transferring data.
    ///
    /// - Parameter progress: The current download progress.
    case downloading(progress: DownloadProgress)

    /// The download is paused and can be resumed.
    ///
    /// - Parameter resumeData: Data needed to resume the download, if available.
    case paused(resumeData: Data?)

    /// The download completed successfully.
    ///
    /// - Parameter localURL: The local file URL of the downloaded content.
    case completed(localURL: URL)

    /// The download failed with an error.
    ///
    /// - Parameter error: The error that caused the failure.
    case failed(error: MediaCacheError)

    /// Whether the download is currently active.
    public var isActive: Bool {
        switch self {
        case .downloading, .pending:
            return true
        default:
            return false
        }
    }

    /// Whether the download can be resumed.
    public var isResumable: Bool {
        if case .paused(let data) = self {
            return data != nil
        }
        return false
    }

    /// Whether the download is complete.
    public var isComplete: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}

// MARK: - Download Task Info

/// Information about a managed download task.
public struct DownloadTaskInfo: Sendable, Equatable {

    /// Unique identifier for this download task.
    public let id: UUID

    /// The remote URL being downloaded.
    public let remoteURL: URL

    /// The local destination URL for the downloaded file.
    public let localURL: URL

    /// The RSS feed URL this entry belongs to.
    public let feedURL: URL

    /// The current state of the download.
    public var state: DownloadState

    /// Whether this is a background download.
    public let isBackgroundDownload: Bool

    /// When the download was initiated.
    public let startTime: Date

    /// Creates a new download task info instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - remoteURL: The URL to download from.
    ///   - localURL: The local destination for the file.
    ///   - feedURL: The RSS feed URL this entry belongs to.
    ///   - state: Initial state. Defaults to `.idle`.
    ///   - isBackgroundDownload: Whether to use background sessions.
    ///   - startTime: When the download started. Defaults to now.
    public init(
        id: UUID = UUID(),
        remoteURL: URL,
        localURL: URL,
        feedURL: URL,
        state: DownloadState = .idle,
        isBackgroundDownload: Bool = false,
        startTime: Date = Date()
    ) {
        self.id = id
        self.remoteURL = remoteURL
        self.localURL = localURL
        self.feedURL = feedURL
        self.state = state
        self.isBackgroundDownload = isBackgroundDownload
        self.startTime = startTime
    }
}
