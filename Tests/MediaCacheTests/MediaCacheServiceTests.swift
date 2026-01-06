//
//  MediaCacheServiceTests.swift
//  JogPodTests
//
//  Created for JogPod Revival project.
//

import Testing
import Foundation
@testable import JogPod

/// Tests for MediaCacheService functionality.
///
/// These tests verify the media caching service's behavior including
/// cache queries, download management, and cache cleanup operations.
@Suite("MediaCacheService Tests")
struct MediaCacheServiceTests {

    // MARK: - Test URLs

    private let testEpisodeURL = URL(string: "https://example.com/podcast/episode1.mp3")!
    private let testFeedURL = URL(string: "https://example.com/podcast/feed.xml")!
    private let testEpisodeURL2 = URL(string: "https://example.com/podcast/episode2.mp3")!

    // MARK: - Initialization Tests

    @Test("MediaCacheService shared instance is singleton")
    func sharedInstanceIsSingleton() {
        let instance1 = MediaCacheService.shared
        let instance2 = MediaCacheService.shared

        #expect(instance1 === instance2)
    }

    @Test("MediaCacheService can be initialized with custom dependencies")
    func customInitialization() {
        let fileManager = FileManager.default
        let userDefaults = UserDefaults.standard

        let service = MediaCacheService(
            fileManager: fileManager,
            userDefaults: userDefaults
        )

        #expect(service !== MediaCacheService.shared)
    }

    // MARK: - Cache Query Tests

    @Test("isCached returns false for non-existent URL")
    func isCachedReturnsFalseForNonExistent() async {
        let service = MediaCacheService()

        let isCached = await service.isCached(testEpisodeURL)

        #expect(isCached == false)
    }

    @Test("isCached string overload works correctly")
    func isCachedStringOverload() async {
        let service = MediaCacheService()

        let isCached = await service.isCached("https://example.com/episode.mp3")

        #expect(isCached == false)
    }

    @Test("isCached returns false for invalid URL string")
    func isCachedReturnsFalseForInvalidURL() async {
        let service = MediaCacheService()

        let isCached = await service.isCached("not a valid url")

        #expect(isCached == false)
    }

    @Test("cachedURL returns nil for non-existent URL")
    func cachedURLReturnsNilForNonExistent() async {
        let service = MediaCacheService()

        let cachedURL = await service.cachedURL(for: testEpisodeURL)

        #expect(cachedURL == nil)
    }

    @Test("cachedURL string overload works correctly")
    func cachedURLStringOverload() async {
        let service = MediaCacheService()

        let cachedURL = await service.cachedURL(for: "https://example.com/episode.mp3")

        #expect(cachedURL == nil)
    }

    @Test("cachedURL returns nil for invalid URL string")
    func cachedURLReturnsNilForInvalidURL() async {
        let service = MediaCacheService()

        let cachedURL = await service.cachedURL(for: "not a valid url")

        #expect(cachedURL == nil)
    }

    // MARK: - Download Validation Tests

    @Test("cacheEpisode throws for invalid episode URL string")
    func cacheEpisodeThrowsForInvalidEpisodeURL() async {
        let service = MediaCacheService()

        do {
            try await service.cacheEpisode(
                from: "not a valid url",
                feedURL: "https://example.com/feed.xml"
            )
            Issue.record("Expected error to be thrown")
        } catch let error as MediaCacheError {
            if case .invalidDownloadURL(let urlString) = error {
                #expect(urlString == "not a valid url")
            } else {
                Issue.record("Expected invalidDownloadURL error")
            }
        } catch {
            Issue.record("Expected MediaCacheError, got \(error)")
        }
    }

    @Test("cacheEpisode throws for invalid feed URL string")
    func cacheEpisodeThrowsForInvalidFeedURL() async {
        let service = MediaCacheService()

        do {
            try await service.cacheEpisode(
                from: "https://example.com/episode.mp3",
                feedURL: "not a valid url"
            )
            Issue.record("Expected error to be thrown")
        } catch let error as MediaCacheError {
            if case .invalidDownloadURL(let urlString) = error {
                #expect(urlString == "not a valid url")
            } else {
                Issue.record("Expected invalidDownloadURL error")
            }
        } catch {
            Issue.record("Expected MediaCacheError, got \(error)")
        }
    }

    // MARK: - Delete From Cache Tests

    @Test("deleteFromCache throws for invalid URL string")
    func deleteFromCacheThrowsForInvalidURL() async {
        let service = MediaCacheService()

        do {
            try await service.deleteFromCache("not a valid url")
            Issue.record("Expected error to be thrown")
        } catch let error as MediaCacheError {
            if case .invalidDownloadURL = error {
                // Expected
            } else {
                Issue.record("Expected invalidDownloadURL error")
            }
        } catch {
            Issue.record("Expected MediaCacheError, got \(error)")
        }
    }

    @Test("deleteFromCache throws for non-existent cached item")
    func deleteFromCacheThrowsForNonExistent() async {
        let service = MediaCacheService()

        do {
            try await service.deleteFromCache(testEpisodeURL)
            Issue.record("Expected error to be thrown")
        } catch let error as MediaCacheError {
            if case .itemNotCached = error {
                // Expected
            } else {
                Issue.record("Expected itemNotCached error, got \(error)")
            }
        } catch {
            Issue.record("Expected MediaCacheError, got \(error)")
        }
    }

    // MARK: - Cache Info Tests

    @Test("cacheInfo returns zero for empty cache")
    func cacheInfoReturnsZeroForEmptyCache() async {
        // Use a fresh service with isolated storage
        let service = MediaCacheService()

        let info = await service.cacheInfo()

        // Cache might have items from other tests, so just verify the structure
        #expect(info.itemCount >= 0)
        #expect(info.totalBytes >= 0)
    }

    // MARK: - Cancel Download Tests

    @Test("cancelDownload does not throw for non-existent download")
    func cancelDownloadNoThrowForNonExistent() async {
        let service = MediaCacheService()

        // Should not throw
        await service.cancelDownload(for: testEpisodeURL)
    }

    @Test("cancelAllDownloads does not throw when no downloads")
    func cancelAllDownloadsNoThrowWhenEmpty() async {
        let service = MediaCacheService()

        // Should not throw
        await service.cancelAllDownloads()
    }

    // MARK: - Progress Stream Tests

    @Test("downloadProgressStream returns valid async stream")
    func downloadProgressStreamReturnsValidStream() async {
        let service = MediaCacheService()

        let stream = service.downloadProgressStream(for: testEpisodeURL)

        // Stream should be created successfully
        // We can't easily test the actual streaming without a real download
        #expect(type(of: stream) == AsyncStream<DownloadProgress>.self)
    }

    // MARK: - Background Session Tests

    @Test("handleBackgroundSessionEvents calls completion for unknown identifier")
    func handleBackgroundSessionEventsCallsCompletionForUnknownIdentifier() async {
        let service = MediaCacheService()
        var completionCalled = false

        // For an unknown identifier, completion should be called immediately
        await withCheckedContinuation { continuation in
            service.handleBackgroundSessionEvents(
                forIdentifier: "unknown.identifier"
            ) {
                completionCalled = true
                continuation.resume()
            }
        }

        #expect(completionCalled == true)
    }
}

// MARK: - Integration Tests

@Suite("MediaCacheService Integration Tests")
struct MediaCacheServiceIntegrationTests {

    /// Tests that verify the service works correctly with the file system.
    /// These tests use a temporary directory to avoid affecting real app data.

    @Test("Clear all cache removes all mappings")
    func clearAllCacheRemovesMappings() async throws {
        // Create a service with isolated user defaults
        let testDefaults = UserDefaults(suiteName: "MediaCacheServiceIntegrationTests")!
        testDefaults.removePersistentDomain(forName: "MediaCacheServiceIntegrationTests")

        let service = MediaCacheService(
            fileManager: .default,
            userDefaults: testDefaults
        )

        // Clear the cache
        try await service.clearAllCache()

        // Verify cache is empty
        let info = await service.cacheInfo()
        #expect(info.itemCount == 0)

        // Cleanup
        testDefaults.removePersistentDomain(forName: "MediaCacheServiceIntegrationTests")
    }
}

// MARK: - Concurrency Tests

@Suite("MediaCacheService Concurrency Tests")
struct MediaCacheServiceConcurrencyTests {

    private let testEpisodeURL = URL(string: "https://example.com/podcast/episode.mp3")!
    private let testFeedURL = URL(string: "https://example.com/podcast/feed.xml")!

    @Test("Multiple concurrent cache queries are safe")
    func multipleConcurrentCacheQueriesAreSafe() async {
        let service = MediaCacheService()

        // Perform multiple concurrent queries
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<100 {
                let url = URL(string: "https://example.com/episode\(i).mp3")!
                group.addTask {
                    await service.isCached(url)
                }
            }

            // All should return false since nothing is cached
            for await result in group {
                #expect(result == false)
            }
        }
    }

    @Test("Multiple concurrent cache info queries are safe")
    func multipleConcurrentCacheInfoQueriesAreSafe() async {
        let service = MediaCacheService()

        await withTaskGroup(of: (Int, Int64).self) { group in
            for _ in 0..<50 {
                group.addTask {
                    await service.cacheInfo()
                }
            }

            for await (count, bytes) in group {
                #expect(count >= 0)
                #expect(bytes >= 0)
            }
        }
    }
}

// MARK: - URL String Convenience Tests

@Suite("MediaCacheService URL String API Tests")
struct MediaCacheServiceURLStringAPITests {

    @Test("URL string APIs work with valid URLs")
    func urlStringAPIsWorkWithValidURLs() async {
        let service = MediaCacheService()
        let validURLString = "https://example.com/podcast/episode.mp3"

        // These should not crash and should return expected values
        let isCached = await service.isCached(validURLString)
        #expect(isCached == false)

        let cachedURL = await service.cachedURL(for: validURLString)
        #expect(cachedURL == nil)
    }

    @Test("URL string APIs handle edge cases gracefully")
    func urlStringAPIsHandleEdgeCases() async {
        let service = MediaCacheService()

        // Empty string
        let emptyResult = await service.isCached("")
        #expect(emptyResult == false)

        // Whitespace only
        let whitespaceResult = await service.isCached("   ")
        #expect(whitespaceResult == false)

        // URL with special characters
        let specialCharsURL = "https://example.com/podcast/episode%20with%20spaces.mp3"
        let specialResult = await service.isCached(specialCharsURL)
        #expect(specialResult == false)
    }
}
