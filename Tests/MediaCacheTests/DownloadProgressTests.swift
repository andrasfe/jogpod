//
//  DownloadProgressTests.swift
//  JogPodTests
//
//  Created for JogPod Revival project.
//

import Testing
import Foundation
@testable import JogPod

/// Tests for DownloadProgress types and computed properties.
@Suite("DownloadProgress Tests")
struct DownloadProgressTests {

    // MARK: - Test URLs

    private let testURL = URL(string: "https://example.com/episode.mp3")!

    // MARK: - Basic Property Tests

    @Test("DownloadProgress stores URL correctly")
    func progressStoresURL() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 1000,
            totalBytes: 10000
        )

        #expect(progress.url == testURL)
    }

    @Test("DownloadProgress stores bytes downloaded correctly")
    func progressStoresBytesDownloaded() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000
        )

        #expect(progress.bytesDownloaded == 5000)
    }

    @Test("DownloadProgress stores total bytes correctly")
    func progressStoresTotalBytes() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000
        )

        #expect(progress.totalBytes == 10000)
    }

    @Test("DownloadProgress allows nil total bytes")
    func progressAllowsNilTotalBytes() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: nil
        )

        #expect(progress.totalBytes == nil)
    }

    // MARK: - Fraction Completed Tests

    @Test("Fraction completed calculates correctly")
    func fractionCompletedCalculates() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000
        )

        #expect(progress.fractionCompleted == 0.5)
    }

    @Test("Fraction completed returns nil when total is unknown")
    func fractionCompletedNilWhenTotalUnknown() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: nil
        )

        #expect(progress.fractionCompleted == nil)
    }

    @Test("Fraction completed returns nil when total is zero")
    func fractionCompletedNilWhenTotalZero() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 0,
            totalBytes: 0
        )

        #expect(progress.fractionCompleted == nil)
    }

    @Test("Fraction completed is 1.0 when complete")
    func fractionCompletedOneWhenComplete() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 10000,
            totalBytes: 10000
        )

        #expect(progress.fractionCompleted == 1.0)
    }

    // MARK: - Percent Complete Tests

    @Test("Percent complete calculates correctly")
    func percentCompleteCalculates() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 2500,
            totalBytes: 10000
        )

        #expect(progress.percentComplete == 25)
    }

    @Test("Percent complete returns nil when total is unknown")
    func percentCompleteNilWhenTotalUnknown() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: nil
        )

        #expect(progress.percentComplete == nil)
    }

    @Test("Percent complete is 100 when complete")
    func percentCompleteHundredWhenComplete() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 10000,
            totalBytes: 10000
        )

        #expect(progress.percentComplete == 100)
    }

    @Test("Percent complete rounds down fractional values")
    func percentCompleteRoundsDown() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 3333,
            totalBytes: 10000
        )

        #expect(progress.percentComplete == 33)
    }

    // MARK: - Speed and Time Remaining Tests

    @Test("Bytes per second is stored correctly")
    func bytesPerSecondStored() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000,
            bytesPerSecond: 1000.0
        )

        #expect(progress.bytesPerSecond == 1000.0)
    }

    @Test("Estimated time remaining calculates correctly")
    func estimatedTimeRemainingCalculates() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000,
            bytesPerSecond: 1000.0
        )

        // 5000 bytes remaining at 1000 bytes/sec = 5 seconds
        #expect(progress.estimatedTimeRemaining == 5.0)
    }

    @Test("Estimated time remaining nil when total unknown")
    func estimatedTimeRemainingNilWhenTotalUnknown() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: nil,
            bytesPerSecond: 1000.0
        )

        #expect(progress.estimatedTimeRemaining == nil)
    }

    @Test("Estimated time remaining nil when speed unknown")
    func estimatedTimeRemainingNilWhenSpeedUnknown() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000,
            bytesPerSecond: nil
        )

        #expect(progress.estimatedTimeRemaining == nil)
    }

    @Test("Estimated time remaining nil when speed is zero")
    func estimatedTimeRemainingNilWhenSpeedZero() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000,
            bytesPerSecond: 0.0
        )

        #expect(progress.estimatedTimeRemaining == nil)
    }

    // MARK: - Formatted Value Tests

    @Test("Formatted bytes downloaded shows human readable size")
    func formattedBytesDownloaded() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 1_500_000,
            totalBytes: 10_000_000
        )

        // ByteCountFormatter output varies by locale, just check it's not empty
        #expect(!progress.formattedBytesDownloaded.isEmpty)
    }

    @Test("Formatted total bytes shows human readable size")
    func formattedTotalBytes() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 1_500_000,
            totalBytes: 10_000_000
        )

        #expect(!progress.formattedTotalBytes.isEmpty)
        #expect(progress.formattedTotalBytes != "Unknown")
    }

    @Test("Formatted total bytes shows Unknown when nil")
    func formattedTotalBytesUnknownWhenNil() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 1_500_000,
            totalBytes: nil
        )

        #expect(progress.formattedTotalBytes == "Unknown")
    }

    @Test("Formatted speed includes per second unit")
    func formattedSpeedIncludesUnit() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 1_500_000,
            totalBytes: 10_000_000,
            bytesPerSecond: 500_000
        )

        #expect(progress.formattedSpeed?.contains("/s") == true)
    }

    @Test("Formatted speed nil when speed unknown")
    func formattedSpeedNilWhenUnknown() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 1_500_000,
            totalBytes: 10_000_000,
            bytesPerSecond: nil
        )

        #expect(progress.formattedSpeed == nil)
    }

    @Test("Formatted progress includes percentage when known")
    func formattedProgressIncludesPercentage() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5_000_000,
            totalBytes: 10_000_000
        )

        #expect(progress.formattedProgress.contains("50%") == true)
    }

    @Test("Formatted progress shows downloaded only when total unknown")
    func formattedProgressShowsDownloadedOnly() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5_000_000,
            totalBytes: nil
        )

        #expect(progress.formattedProgress.contains("downloaded") == true)
        #expect(progress.formattedProgress.contains("%") == false)
    }

    // MARK: - Factory Method Tests

    @Test("Starting factory method creates zero progress")
    func startingFactoryMethod() {
        let progress = DownloadProgress.starting(url: testURL, totalBytes: 10000)

        #expect(progress.url == testURL)
        #expect(progress.bytesDownloaded == 0)
        #expect(progress.totalBytes == 10000)
    }

    @Test("Starting factory method allows nil total")
    func startingFactoryMethodNilTotal() {
        let progress = DownloadProgress.starting(url: testURL)

        #expect(progress.totalBytes == nil)
    }

    @Test("Completed factory method creates full progress")
    func completedFactoryMethod() {
        let progress = DownloadProgress.completed(url: testURL, totalBytes: 10000)

        #expect(progress.url == testURL)
        #expect(progress.bytesDownloaded == 10000)
        #expect(progress.totalBytes == 10000)
        #expect(progress.fractionCompleted == 1.0)
    }

    // MARK: - Equatable Tests

    @Test("Same progress instances are equal")
    func sameProgressAreEqual() {
        let timestamp = Date()
        let progress1 = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000,
            bytesPerSecond: 1000,
            timestamp: timestamp
        )
        let progress2 = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000,
            bytesPerSecond: 1000,
            timestamp: timestamp
        )

        #expect(progress1 == progress2)
    }

    @Test("Different bytes downloaded are not equal")
    func differentBytesDownloadedNotEqual() {
        let timestamp = Date()
        let progress1 = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000,
            timestamp: timestamp
        )
        let progress2 = DownloadProgress(
            url: testURL,
            bytesDownloaded: 6000,
            totalBytes: 10000,
            timestamp: timestamp
        )

        #expect(progress1 != progress2)
    }

    // MARK: - CustomStringConvertible Tests

    @Test("Description includes progress info")
    func descriptionIncludesProgress() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5_000_000,
            totalBytes: 10_000_000,
            bytesPerSecond: 500_000
        )

        let description = progress.description
        #expect(description.contains("50%") == true)
        #expect(description.contains("/s") == true)
    }

    // MARK: - CustomDebugStringConvertible Tests

    @Test("Debug description includes all properties")
    func debugDescriptionIncludesAllProperties() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000,
            bytesPerSecond: 1000
        )

        let debug = progress.debugDescription
        #expect(debug.contains("DownloadProgress") == true)
        #expect(debug.contains("bytesDownloaded: 5000") == true)
        #expect(debug.contains("totalBytes: 10000") == true)
    }
}

// MARK: - DownloadState Tests

@Suite("DownloadState Tests")
struct DownloadStateTests {

    private let testURL = URL(string: "https://example.com/episode.mp3")!

    // MARK: - State Tests

    @Test("Idle state is not active")
    func idleStateNotActive() {
        let state = DownloadState.idle

        #expect(state.isActive == false)
        #expect(state.isComplete == false)
        #expect(state.isResumable == false)
    }

    @Test("Pending state is active")
    func pendingStateIsActive() {
        let state = DownloadState.pending

        #expect(state.isActive == true)
        #expect(state.isComplete == false)
    }

    @Test("Downloading state is active")
    func downloadingStateIsActive() {
        let progress = DownloadProgress(
            url: testURL,
            bytesDownloaded: 5000,
            totalBytes: 10000
        )
        let state = DownloadState.downloading(progress: progress)

        #expect(state.isActive == true)
        #expect(state.isComplete == false)
    }

    @Test("Paused state with resume data is resumable")
    func pausedStateWithResumeDataIsResumable() {
        let state = DownloadState.paused(resumeData: Data([1, 2, 3]))

        #expect(state.isResumable == true)
        #expect(state.isActive == false)
    }

    @Test("Paused state without resume data is not resumable")
    func pausedStateWithoutResumeDataNotResumable() {
        let state = DownloadState.paused(resumeData: nil)

        #expect(state.isResumable == false)
    }

    @Test("Completed state is complete")
    func completedStateIsComplete() {
        let localURL = URL(fileURLWithPath: "/cache/episode.mp3")
        let state = DownloadState.completed(localURL: localURL)

        #expect(state.isComplete == true)
        #expect(state.isActive == false)
    }

    @Test("Failed state is not active or complete")
    func failedStateNotActiveOrComplete() {
        let state = DownloadState.failed(error: .downloadCancelled(url: "test"))

        #expect(state.isActive == false)
        #expect(state.isComplete == false)
    }

    // MARK: - Equatable Tests

    @Test("Same states are equal")
    func sameStatesAreEqual() {
        let state1 = DownloadState.idle
        let state2 = DownloadState.idle

        #expect(state1 == state2)
    }

    @Test("Different states are not equal")
    func differentStatesNotEqual() {
        let state1 = DownloadState.idle
        let state2 = DownloadState.pending

        #expect(state1 != state2)
    }
}

// MARK: - DownloadTaskInfo Tests

@Suite("DownloadTaskInfo Tests")
struct DownloadTaskInfoTests {

    private let remoteURL = URL(string: "https://example.com/episode.mp3")!
    private let localURL = URL(fileURLWithPath: "/cache/episode.mp3")
    private let feedURL = URL(string: "https://example.com/feed.xml")!

    @Test("DownloadTaskInfo stores all properties correctly")
    func taskInfoStoresProperties() {
        let taskInfo = DownloadTaskInfo(
            remoteURL: remoteURL,
            localURL: localURL,
            feedURL: feedURL,
            isBackgroundDownload: true
        )

        #expect(taskInfo.remoteURL == remoteURL)
        #expect(taskInfo.localURL == localURL)
        #expect(taskInfo.feedURL == feedURL)
        #expect(taskInfo.state == .idle)
        #expect(taskInfo.isBackgroundDownload == true)
    }

    @Test("DownloadTaskInfo generates unique ID by default")
    func taskInfoGeneratesUniqueID() {
        let taskInfo1 = DownloadTaskInfo(
            remoteURL: remoteURL,
            localURL: localURL,
            feedURL: feedURL
        )
        let taskInfo2 = DownloadTaskInfo(
            remoteURL: remoteURL,
            localURL: localURL,
            feedURL: feedURL
        )

        #expect(taskInfo1.id != taskInfo2.id)
    }

    @Test("DownloadTaskInfo state can be modified")
    func taskInfoStateCanBeModified() {
        var taskInfo = DownloadTaskInfo(
            remoteURL: remoteURL,
            localURL: localURL,
            feedURL: feedURL
        )

        taskInfo.state = .pending
        #expect(taskInfo.state == .pending)

        taskInfo.state = .completed(localURL: localURL)
        #expect(taskInfo.state.isComplete == true)
    }

    @Test("DownloadTaskInfo defaults to foreground download")
    func taskInfoDefaultsForeground() {
        let taskInfo = DownloadTaskInfo(
            remoteURL: remoteURL,
            localURL: localURL,
            feedURL: feedURL
        )

        #expect(taskInfo.isBackgroundDownload == false)
    }
}
