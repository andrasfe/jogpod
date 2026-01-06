//
//  MediaCacheErrorTests.swift
//  JogPodTests
//
//  Created for JogPod Revival project.
//

import Testing
import Foundation
@testable import JogPod

/// Tests for MediaCacheError types and their error descriptions.
@Suite("MediaCacheError Tests")
struct MediaCacheErrorTests {

    // MARK: - Initialization Error Tests

    @Test("Cache directory creation failed error has correct description")
    func cacheDirectoryCreationFailedError() {
        let error = MediaCacheError.cacheDirectoryCreationFailed(reason: "Permission denied")

        #expect(error.errorDescription?.contains("cache directory") == true)
        #expect(error.errorDescription?.contains("Permission denied") == true)
        #expect(error.failureReason != nil)
        #expect(error.recoverySuggestion != nil)
    }

    @Test("Cache directory unavailable error has correct description")
    func cacheDirectoryUnavailableError() {
        let error = MediaCacheError.cacheDirectoryUnavailable

        #expect(error.errorDescription?.contains("not available") == true)
        #expect(error.recoverySuggestion?.contains("Restart") == true)
    }

    // MARK: - Download Error Tests

    @Test("Invalid download URL error includes URL string")
    func invalidDownloadURLError() {
        let error = MediaCacheError.invalidDownloadURL(urlString: "not-a-valid-url")

        #expect(error.errorDescription?.contains("not-a-valid-url") == true)
        #expect(error.errorDescription?.contains("Invalid") == true)
    }

    @Test("Download failed error includes URL and reason")
    func downloadFailedError() {
        let error = MediaCacheError.downloadFailed(
            url: "https://example.com/episode.mp3",
            reason: "Network timeout"
        )

        #expect(error.errorDescription?.contains("example.com") == true)
        #expect(error.errorDescription?.contains("Network timeout") == true)
    }

    @Test("Download cancelled error includes URL")
    func downloadCancelledError() {
        let error = MediaCacheError.downloadCancelled(url: "https://example.com/episode.mp3")

        #expect(error.errorDescription?.contains("cancelled") == true)
        #expect(error.errorDescription?.contains("example.com") == true)
    }

    @Test("Download timeout error includes URL")
    func downloadTimeoutError() {
        let error = MediaCacheError.downloadTimeout(url: "https://example.com/episode.mp3")

        #expect(error.errorDescription?.contains("timed out") == true)
        #expect(error.errorDescription?.contains("example.com") == true)
    }

    @Test("No server response error includes URL")
    func noServerResponseError() {
        let error = MediaCacheError.noServerResponse(url: "https://example.com/episode.mp3")

        #expect(error.errorDescription?.contains("No server response") == true)
        #expect(error.errorDescription?.contains("example.com") == true)
    }

    @Test("HTTP error includes URL and status code")
    func httpError() {
        let error = MediaCacheError.httpError(
            url: "https://example.com/episode.mp3",
            statusCode: 404
        )

        #expect(error.errorDescription?.contains("404") == true)
        #expect(error.errorDescription?.contains("example.com") == true)
    }

    @Test("HTTP 404 error has appropriate recovery suggestion")
    func http404ErrorRecoverySuggestion() {
        let error = MediaCacheError.httpError(
            url: "https://example.com/episode.mp3",
            statusCode: 404
        )

        #expect(error.recoverySuggestion?.contains("removed") == true)
    }

    @Test("HTTP 500 error has appropriate failure reason")
    func http500ErrorFailureReason() {
        let error = MediaCacheError.httpError(
            url: "https://example.com/episode.mp3",
            statusCode: 500
        )

        #expect(error.failureReason?.contains("server encountered an error") == true)
    }

    // MARK: - File System Error Tests

    @Test("File move error includes source, destination, and reason")
    func fileMoveError() {
        let error = MediaCacheError.fileMoveError(
            source: "/tmp/download.mp3",
            destination: "/caches/media/episode.mp3",
            reason: "Disk full"
        )

        #expect(error.errorDescription?.contains("Disk full") == true)
        #expect(error.debugDescription.contains("/tmp/download.mp3") == true)
        #expect(error.debugDescription.contains("/caches/media/episode.mp3") == true)
    }

    @Test("File deletion error includes path and reason")
    func fileDeletionError() {
        let error = MediaCacheError.fileDeletionError(
            path: "/caches/media/episode.mp3",
            reason: "File in use"
        )

        #expect(error.errorDescription?.contains("File in use") == true)
        #expect(error.errorDescription?.contains("episode.mp3") == true)
    }

    @Test("File read error includes path and reason")
    func fileReadError() {
        let error = MediaCacheError.fileReadError(
            path: "/caches/media/episode.mp3",
            reason: "File corrupted"
        )

        #expect(error.errorDescription?.contains("File corrupted") == true)
        #expect(error.recoverySuggestion?.contains("download") == true)
    }

    @Test("File write error includes path and reason")
    func fileWriteError() {
        let error = MediaCacheError.fileWriteError(
            path: "/caches/media/episode.mp3",
            reason: "No space left"
        )

        #expect(error.errorDescription?.contains("No space left") == true)
        #expect(error.recoverySuggestion?.contains("storage space") == true)
    }

    // MARK: - Cache State Error Tests

    @Test("Item not cached error includes URL")
    func itemNotCachedError() {
        let error = MediaCacheError.itemNotCached(url: "https://example.com/episode.mp3")

        #expect(error.errorDescription?.contains("not found in cache") == true)
        #expect(error.recoverySuggestion?.contains("Download") == true)
    }

    @Test("Download in progress error includes URL")
    func downloadInProgressError() {
        let error = MediaCacheError.downloadInProgress(url: "https://example.com/episode.mp3")

        #expect(error.errorDescription?.contains("already in progress") == true)
        #expect(error.recoverySuggestion?.contains("Wait") == true)
    }

    @Test("Item already cached error includes URL")
    func itemAlreadyCachedError() {
        let error = MediaCacheError.itemAlreadyCached(url: "https://example.com/episode.mp3")

        #expect(error.errorDescription?.contains("already cached") == true)
        #expect(error.recoverySuggestion?.contains("ready for offline") == true)
    }

    // MARK: - Mapping Error Tests

    @Test("Mapping persistence failed error includes reason")
    func mappingPersistenceFailedError() {
        let error = MediaCacheError.mappingPersistenceFailed(reason: "UserDefaults full")

        #expect(error.errorDescription?.contains("UserDefaults full") == true)
        #expect(error.failureReason?.contains("defaults") == true)
    }

    @Test("Missing feed mapping error includes entry URL")
    func missingFeedMappingError() {
        let error = MediaCacheError.missingFeedMapping(entryURL: "https://example.com/episode.mp3")

        #expect(error.errorDescription?.contains("No feed mapping") == true)
        #expect(error.errorDescription?.contains("episode.mp3") == true)
    }

    // MARK: - Background Session Error Tests

    @Test("Background session configuration failed error includes reason")
    func backgroundSessionConfigurationFailedError() {
        let error = MediaCacheError.backgroundSessionConfigurationFailed(reason: "Invalid identifier")

        #expect(error.errorDescription?.contains("Invalid identifier") == true)
        #expect(error.recoverySuggestion?.contains("Restart") == true)
    }

    @Test("Background download not resumable error includes URL")
    func backgroundDownloadNotResumableError() {
        let error = MediaCacheError.backgroundDownloadNotResumable(url: "https://example.com/episode.mp3")

        #expect(error.errorDescription?.contains("cannot be resumed") == true)
        #expect(error.recoverySuggestion?.contains("beginning") == true)
    }

    // MARK: - Unknown Error Tests

    @Test("Unknown error includes underlying error message")
    func unknownError() {
        let error = MediaCacheError.unknown("Something unexpected happened")

        #expect(error.errorDescription?.contains("Something unexpected happened") == true)
    }

    // MARK: - Equatable Tests

    @Test("Same error cases are equal")
    func sameErrorsAreEqual() {
        let error1 = MediaCacheError.cacheDirectoryUnavailable
        let error2 = MediaCacheError.cacheDirectoryUnavailable

        #expect(error1 == error2)
    }

    @Test("Different error cases are not equal")
    func differentErrorsAreNotEqual() {
        let error1 = MediaCacheError.cacheDirectoryUnavailable
        let error2 = MediaCacheError.unknown("test")

        #expect(error1 != error2)
    }

    @Test("Errors with different parameters are not equal")
    func errorsWithDifferentParametersNotEqual() {
        let error1 = MediaCacheError.httpError(url: "url1", statusCode: 404)
        let error2 = MediaCacheError.httpError(url: "url1", statusCode: 500)

        #expect(error1 != error2)
    }

    @Test("Errors with same parameters are equal")
    func errorsWithSameParametersAreEqual() {
        let error1 = MediaCacheError.httpError(url: "url1", statusCode: 404)
        let error2 = MediaCacheError.httpError(url: "url1", statusCode: 404)

        #expect(error1 == error2)
    }

    // MARK: - Debug Description Tests

    @Test("Debug description includes error type name")
    func debugDescriptionIncludesTypeName() {
        let error = MediaCacheError.cacheDirectoryUnavailable

        #expect(error.debugDescription.contains("MediaCacheError") == true)
        #expect(error.debugDescription.contains("cacheDirectoryUnavailable") == true)
    }

    @Test("Debug description includes parameters")
    func debugDescriptionIncludesParameters() {
        let error = MediaCacheError.httpError(url: "https://example.com", statusCode: 404)

        #expect(error.debugDescription.contains("https://example.com") == true)
        #expect(error.debugDescription.contains("404") == true)
    }

    // MARK: - LocalizedError Conformance Tests

    @Test("All error cases have error descriptions")
    func allErrorsHaveDescriptions() {
        let errors: [MediaCacheError] = [
            .cacheDirectoryCreationFailed(reason: "test"),
            .cacheDirectoryUnavailable,
            .invalidDownloadURL(urlString: "test"),
            .downloadFailed(url: "test", reason: "test"),
            .downloadCancelled(url: "test"),
            .downloadTimeout(url: "test"),
            .noServerResponse(url: "test"),
            .httpError(url: "test", statusCode: 404),
            .fileMoveError(source: "a", destination: "b", reason: "test"),
            .fileDeletionError(path: "test", reason: "test"),
            .fileReadError(path: "test", reason: "test"),
            .fileWriteError(path: "test", reason: "test"),
            .itemNotCached(url: "test"),
            .downloadInProgress(url: "test"),
            .itemAlreadyCached(url: "test"),
            .mappingPersistenceFailed(reason: "test"),
            .missingFeedMapping(entryURL: "test"),
            .backgroundSessionConfigurationFailed(reason: "test"),
            .backgroundDownloadNotResumable(url: "test"),
            .unknown("test")
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Error \(error) should have errorDescription")
            #expect(error.failureReason != nil, "Error \(error) should have failureReason")
            #expect(error.recoverySuggestion != nil, "Error \(error) should have recoverySuggestion")
        }
    }

    // MARK: - URLError Conversion Tests

    @Test("fromURLError converts cancelled error correctly")
    func fromURLErrorCancelled() {
        let urlError = URLError(.cancelled)
        let result = MediaCacheError.fromURLError(urlError, url: "https://example.com")

        #expect(result == .downloadCancelled(url: "https://example.com"))
    }

    @Test("fromURLError converts timeout error correctly")
    func fromURLErrorTimeout() {
        let urlError = URLError(.timedOut)
        let result = MediaCacheError.fromURLError(urlError, url: "https://example.com")

        #expect(result == .downloadTimeout(url: "https://example.com"))
    }

    @Test("fromURLError converts connection errors to no server response")
    func fromURLErrorNoConnection() {
        let connectionErrors: [URLError.Code] = [
            .cannotConnectToHost,
            .networkConnectionLost,
            .notConnectedToInternet
        ]

        for code in connectionErrors {
            let urlError = URLError(code)
            let result = MediaCacheError.fromURLError(urlError, url: "https://example.com")

            #expect(result == .noServerResponse(url: "https://example.com"))
        }
    }

    @Test("fromURLError converts bad URL error correctly")
    func fromURLErrorBadURL() {
        let urlError = URLError(.badURL)
        let result = MediaCacheError.fromURLError(urlError, url: "bad-url")

        #expect(result == .invalidDownloadURL(urlString: "bad-url"))
    }

    @Test("fromURLError converts unknown errors to download failed")
    func fromURLErrorUnknown() {
        let urlError = URLError(.unknown)
        let result = MediaCacheError.fromURLError(urlError, url: "https://example.com")

        if case .downloadFailed(let url, _) = result {
            #expect(url == "https://example.com")
        } else {
            Issue.record("Expected downloadFailed error")
        }
    }
}
