//
//  MediaCacheError.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation

/// Errors that can occur during media caching operations.
///
/// This enum provides structured error handling for the MediaCacheService,
/// covering download failures, file system errors, and cache management issues.
public enum MediaCacheError: Error, Equatable, Sendable {

    // MARK: - Initialization Errors

    /// Failed to create the cache directory.
    ///
    /// - Parameter reason: Description of why directory creation failed.
    case cacheDirectoryCreationFailed(reason: String)

    /// The cache directory is not available.
    case cacheDirectoryUnavailable

    // MARK: - Download Errors

    /// The download URL is invalid or malformed.
    ///
    /// - Parameter urlString: The invalid URL string.
    case invalidDownloadURL(urlString: String)

    /// The download failed due to a network error.
    ///
    /// - Parameters:
    ///   - url: The URL that failed to download.
    ///   - reason: Description of the network failure.
    case downloadFailed(url: String, reason: String)

    /// The download was cancelled.
    ///
    /// - Parameter url: The URL whose download was cancelled.
    case downloadCancelled(url: String)

    /// The download timed out.
    ///
    /// - Parameter url: The URL that timed out.
    case downloadTimeout(url: String)

    /// No response was received from the server.
    ///
    /// - Parameter url: The URL that received no response.
    case noServerResponse(url: String)

    /// The server returned an error status code.
    ///
    /// - Parameters:
    ///   - url: The URL that returned an error.
    ///   - statusCode: The HTTP status code received.
    case httpError(url: String, statusCode: Int)

    // MARK: - File System Errors

    /// Failed to move the downloaded file to the cache location.
    ///
    /// - Parameters:
    ///   - source: The source path of the downloaded file.
    ///   - destination: The intended destination path.
    ///   - reason: Description of why the move failed.
    case fileMoveError(source: String, destination: String, reason: String)

    /// Failed to delete a cached file.
    ///
    /// - Parameters:
    ///   - path: The path of the file that could not be deleted.
    ///   - reason: Description of why deletion failed.
    case fileDeletionError(path: String, reason: String)

    /// Failed to read from the cache.
    ///
    /// - Parameters:
    ///   - path: The path that could not be read.
    ///   - reason: Description of why reading failed.
    case fileReadError(path: String, reason: String)

    /// Failed to write to the cache.
    ///
    /// - Parameters:
    ///   - path: The path that could not be written.
    ///   - reason: Description of why writing failed.
    case fileWriteError(path: String, reason: String)

    // MARK: - Cache State Errors

    /// The requested item is not in the cache.
    ///
    /// - Parameter url: The URL of the item not found in cache.
    case itemNotCached(url: String)

    /// The item is already being downloaded.
    ///
    /// - Parameter url: The URL that is already downloading.
    case downloadInProgress(url: String)

    /// The item is already cached.
    ///
    /// - Parameter url: The URL that is already cached.
    case itemAlreadyCached(url: String)

    // MARK: - Mapping Errors

    /// Failed to persist the cache mapping.
    ///
    /// - Parameter reason: Description of why persistence failed.
    case mappingPersistenceFailed(reason: String)

    /// The RSS feed URL for the entry could not be found.
    ///
    /// - Parameter entryURL: The entry URL without a mapping.
    case missingFeedMapping(entryURL: String)

    // MARK: - Background Session Errors

    /// Background session configuration failed.
    ///
    /// - Parameter reason: Description of the configuration failure.
    case backgroundSessionConfigurationFailed(reason: String)

    /// Background download cannot be resumed.
    ///
    /// - Parameter url: The URL whose background download cannot resume.
    case backgroundDownloadNotResumable(url: String)

    // MARK: - Unknown Errors

    /// An unknown error occurred.
    ///
    /// - Parameter underlyingError: The original error description.
    case unknown(String)
}

// MARK: - LocalizedError Conformance

extension MediaCacheError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .cacheDirectoryCreationFailed(let reason):
            return "Failed to create cache directory: \(reason)"

        case .cacheDirectoryUnavailable:
            return "Cache directory is not available"

        case .invalidDownloadURL(let urlString):
            return "Invalid download URL: \(urlString)"

        case .downloadFailed(let url, let reason):
            return "Download failed for '\(url)': \(reason)"

        case .downloadCancelled(let url):
            return "Download was cancelled for '\(url)'"

        case .downloadTimeout(let url):
            return "Download timed out for '\(url)'"

        case .noServerResponse(let url):
            return "No server response for '\(url)'"

        case .httpError(let url, let statusCode):
            return "HTTP error \(statusCode) for '\(url)'"

        case .fileMoveError(_, let destination, let reason):
            return "Failed to cache file to '\(destination)': \(reason)"

        case .fileDeletionError(let path, let reason):
            return "Failed to delete '\(path)': \(reason)"

        case .fileReadError(let path, let reason):
            return "Failed to read '\(path)': \(reason)"

        case .fileWriteError(let path, let reason):
            return "Failed to write '\(path)': \(reason)"

        case .itemNotCached(let url):
            return "Item not found in cache: '\(url)'"

        case .downloadInProgress(let url):
            return "Download already in progress for '\(url)'"

        case .itemAlreadyCached(let url):
            return "Item is already cached: '\(url)'"

        case .mappingPersistenceFailed(let reason):
            return "Failed to save cache mapping: \(reason)"

        case .missingFeedMapping(let entryURL):
            return "No feed mapping found for '\(entryURL)'"

        case .backgroundSessionConfigurationFailed(let reason):
            return "Background session configuration failed: \(reason)"

        case .backgroundDownloadNotResumable(let url):
            return "Background download cannot be resumed for '\(url)'"

        case .unknown(let error):
            return "An unknown cache error occurred: \(error)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .cacheDirectoryCreationFailed:
            return "The system could not create the required directory structure"

        case .cacheDirectoryUnavailable:
            return "The cache directory has not been initialized or is inaccessible"

        case .invalidDownloadURL:
            return "The URL format is not recognized"

        case .downloadFailed:
            return "A network error prevented the download from completing"

        case .downloadCancelled:
            return "The download operation was explicitly cancelled"

        case .downloadTimeout:
            return "The server did not respond within the allowed time"

        case .noServerResponse:
            return "The server is unreachable or not responding"

        case .httpError(_, let statusCode):
            if (400..<500).contains(statusCode) {
                return "The server rejected the request"
            } else if (500..<600).contains(statusCode) {
                return "The server encountered an error"
            }
            return "The server returned an unexpected status"

        case .fileMoveError:
            return "The downloaded file could not be moved to the cache location"

        case .fileDeletionError:
            return "The file system prevented deletion of the cached file"

        case .fileReadError:
            return "The cached file could not be read"

        case .fileWriteError:
            return "The file could not be written to cache"

        case .itemNotCached:
            return "The requested episode has not been downloaded"

        case .downloadInProgress:
            return "A download is already active for this episode"

        case .itemAlreadyCached:
            return "This episode has already been downloaded"

        case .mappingPersistenceFailed:
            return "User defaults could not be updated"

        case .missingFeedMapping:
            return "The cache entry does not have an associated podcast feed"

        case .backgroundSessionConfigurationFailed:
            return "The background download session could not be configured"

        case .backgroundDownloadNotResumable:
            return "The interrupted download cannot be continued"

        case .unknown:
            return "An unexpected error occurred during cache operations"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .cacheDirectoryCreationFailed:
            return "Check available storage space and restart the app."

        case .cacheDirectoryUnavailable:
            return "Restart the app to reinitialize the cache system."

        case .invalidDownloadURL:
            return "Try refreshing the podcast feed."

        case .downloadFailed:
            return "Check your internet connection and try again."

        case .downloadCancelled:
            return "Start the download again when ready."

        case .downloadTimeout:
            return "Check your internet connection speed and try again."

        case .noServerResponse:
            return "Check your internet connection. The podcast server may be temporarily unavailable."

        case .httpError(_, let statusCode):
            if statusCode == 404 {
                return "The episode may have been removed. Try refreshing the podcast feed."
            } else if (500..<600).contains(statusCode) {
                return "Try again later. The server may be experiencing issues."
            }
            return "Try refreshing the podcast feed or contact support."

        case .fileMoveError:
            return "Clear some storage space and try the download again."

        case .fileDeletionError:
            return "Try restarting the app or clearing the entire cache."

        case .fileReadError:
            return "Re-download the episode."

        case .fileWriteError:
            return "Check available storage space and try again."

        case .itemNotCached:
            return "Download the episode first for offline playback."

        case .downloadInProgress:
            return "Wait for the current download to complete."

        case .itemAlreadyCached:
            return "The episode is ready for offline playback."

        case .mappingPersistenceFailed:
            return "Restart the app. The cache may need to be cleared."

        case .missingFeedMapping:
            return "Clear the cache and re-download the episode."

        case .backgroundSessionConfigurationFailed:
            return "Restart the app to reinitialize background downloads."

        case .backgroundDownloadNotResumable:
            return "Start the download again from the beginning."

        case .unknown:
            return "Try the operation again. If the problem persists, restart the app."
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension MediaCacheError: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case .cacheDirectoryCreationFailed(let reason):
            return "MediaCacheError.cacheDirectoryCreationFailed(reason: \"\(reason)\")"

        case .cacheDirectoryUnavailable:
            return "MediaCacheError.cacheDirectoryUnavailable"

        case .invalidDownloadURL(let urlString):
            return "MediaCacheError.invalidDownloadURL(urlString: \"\(urlString)\")"

        case .downloadFailed(let url, let reason):
            return "MediaCacheError.downloadFailed(url: \"\(url)\", reason: \"\(reason)\")"

        case .downloadCancelled(let url):
            return "MediaCacheError.downloadCancelled(url: \"\(url)\")"

        case .downloadTimeout(let url):
            return "MediaCacheError.downloadTimeout(url: \"\(url)\")"

        case .noServerResponse(let url):
            return "MediaCacheError.noServerResponse(url: \"\(url)\")"

        case .httpError(let url, let statusCode):
            return "MediaCacheError.httpError(url: \"\(url)\", statusCode: \(statusCode))"

        case .fileMoveError(let source, let destination, let reason):
            return "MediaCacheError.fileMoveError(source: \"\(source)\", destination: \"\(destination)\", reason: \"\(reason)\")"

        case .fileDeletionError(let path, let reason):
            return "MediaCacheError.fileDeletionError(path: \"\(path)\", reason: \"\(reason)\")"

        case .fileReadError(let path, let reason):
            return "MediaCacheError.fileReadError(path: \"\(path)\", reason: \"\(reason)\")"

        case .fileWriteError(let path, let reason):
            return "MediaCacheError.fileWriteError(path: \"\(path)\", reason: \"\(reason)\")"

        case .itemNotCached(let url):
            return "MediaCacheError.itemNotCached(url: \"\(url)\")"

        case .downloadInProgress(let url):
            return "MediaCacheError.downloadInProgress(url: \"\(url)\")"

        case .itemAlreadyCached(let url):
            return "MediaCacheError.itemAlreadyCached(url: \"\(url)\")"

        case .mappingPersistenceFailed(let reason):
            return "MediaCacheError.mappingPersistenceFailed(reason: \"\(reason)\")"

        case .missingFeedMapping(let entryURL):
            return "MediaCacheError.missingFeedMapping(entryURL: \"\(entryURL)\")"

        case .backgroundSessionConfigurationFailed(let reason):
            return "MediaCacheError.backgroundSessionConfigurationFailed(reason: \"\(reason)\")"

        case .backgroundDownloadNotResumable(let url):
            return "MediaCacheError.backgroundDownloadNotResumable(url: \"\(url)\")"

        case .unknown(let error):
            return "MediaCacheError.unknown(\"\(error)\")"
        }
    }
}

// MARK: - URLError Convenience

extension MediaCacheError {

    /// Creates an appropriate MediaCacheError from a URLError.
    ///
    /// - Parameters:
    ///   - urlError: The URLError to convert.
    ///   - url: The URL associated with the error.
    /// - Returns: A MediaCacheError that best represents the URLError.
    public static func fromURLError(_ urlError: URLError, url: String) -> MediaCacheError {
        switch urlError.code {
        case .cancelled:
            return .downloadCancelled(url: url)
        case .timedOut:
            return .downloadTimeout(url: url)
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return .noServerResponse(url: url)
        case .badURL:
            return .invalidDownloadURL(urlString: url)
        default:
            return .downloadFailed(url: url, reason: urlError.localizedDescription)
        }
    }
}
