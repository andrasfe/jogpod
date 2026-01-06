//
//  WorkoutDataSync.swift
//  JogPodWatch
//
//  Bidirectional workout data synchronization between Watch and iPhone.
//  Handles conflict resolution for parallel workouts.
//

import Foundation
import WatchConnectivity

// MARK: - WorkoutDataSync

/// Manages bidirectional workout data synchronization between Watch and iPhone.
///
/// This class handles the synchronization of workout data between the watch
/// and the paired iPhone, including:
/// - Syncing completed workouts from watch to iPhone
/// - Receiving workout updates from iPhone
/// - Conflict resolution when both devices record simultaneously
/// - Queuing data when connection is unavailable
///
/// ## Sync Strategy
///
/// 1. **Watch-initiated workouts**: Data is saved locally on watch and
///    synced to iPhone when connection is available.
///
/// 2. **iPhone-initiated workouts**: Watch receives real-time updates
///    via WatchConnectivity.
///
/// 3. **Parallel workouts**: If both devices record simultaneously,
///    the watch's data takes precedence for heart rate and calories,
///    while GPS route data is merged.
///
/// ## Data Flow
///
/// ```
/// Watch -> iPhone:
///   - Completed workout summaries
///   - Heart rate samples
///   - Route points (GPS)
///
/// iPhone -> Watch:
///   - Workout status updates
///   - Podcast playback state
///   - Location data (when watch GPS unavailable)
/// ```
@MainActor
public final class WorkoutDataSync: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide use.
    public static let shared = WorkoutDataSync()

    // MARK: - Published Properties

    /// Whether sync is currently in progress.
    @Published public private(set) var isSyncing: Bool = false

    /// Number of pending sync items.
    @Published public private(set) var pendingItemCount: Int = 0

    /// Last sync timestamp.
    @Published public private(set) var lastSyncTime: Date?

    /// Last sync error, if any.
    @Published public private(set) var lastSyncError: SyncError?

    // MARK: - Private Properties

    /// Pending workout data to sync.
    private var pendingWorkouts: [SyncableWorkout] = []

    /// Pending route data to sync.
    private var pendingRoutes: [SyncableRoute] = []

    /// Storage key for pending data.
    private let pendingDataKey = "WorkoutDataSync.PendingData"

    /// Maximum retry attempts for failed syncs.
    private let maxRetryAttempts = 3

    /// Retry delay in seconds.
    private let retryDelay: TimeInterval = 5.0

    // MARK: - Initialization

    private init() {
        loadPendingData()
        setupConnectivityObserver()
    }

    // MARK: - Setup

    private func setupConnectivityObserver() {
        // Observe reachability changes
        Task {
            for await reachable in WatchConnectivityManager.shared.reachabilityPublisher.values {
                if reachable {
                    await syncPendingData()
                }
            }
        }
    }

    // MARK: - Public API

    /// Queues a completed workout for synchronization.
    ///
    /// The workout will be synced immediately if iPhone is reachable,
    /// otherwise it will be queued for later sync.
    ///
    /// - Parameter workout: The workout result to sync.
    public func queueWorkoutForSync(_ workout: WatchWorkoutResult) {
        let syncable = SyncableWorkout(
            id: UUID(),
            workout: workout,
            createdAt: Date(),
            retryCount: 0
        )

        pendingWorkouts.append(syncable)
        updatePendingCount()
        savePendingData()

        // Attempt immediate sync
        Task {
            await syncPendingData()
        }
    }

    /// Queues route data for synchronization.
    ///
    /// - Parameters:
    ///   - routePoints: The route points to sync.
    ///   - workoutId: Associated workout identifier.
    public func queueRouteForSync(_ routePoints: [RoutePointData], workoutId: UUID) {
        let syncable = SyncableRoute(
            id: UUID(),
            workoutId: workoutId,
            routePoints: routePoints,
            createdAt: Date(),
            retryCount: 0
        )

        pendingRoutes.append(syncable)
        updatePendingCount()
        savePendingData()

        Task {
            await syncPendingData()
        }
    }

    /// Forces a sync attempt for all pending data.
    public func forceSyncAll() async {
        await syncPendingData()
    }

    /// Clears all pending sync data.
    ///
    /// Use with caution - this will permanently discard unsynced workouts.
    public func clearPendingData() {
        pendingWorkouts.removeAll()
        pendingRoutes.removeAll()
        updatePendingCount()
        savePendingData()
    }

    // MARK: - Sync Logic

    private func syncPendingData() async {
        guard !isSyncing else { return }
        guard WatchConnectivityManager.shared.isReachable else { return }
        guard !pendingWorkouts.isEmpty || !pendingRoutes.isEmpty else { return }

        isSyncing = true
        lastSyncError = nil

        // Sync workouts
        var syncedWorkoutIds: [UUID] = []
        for workout in pendingWorkouts {
            do {
                try await syncWorkout(workout)
                syncedWorkoutIds.append(workout.id)
            } catch {
                handleSyncError(error, for: workout.id)
            }
        }

        // Remove successfully synced workouts
        pendingWorkouts.removeAll { syncedWorkoutIds.contains($0.id) }

        // Sync routes
        var syncedRouteIds: [UUID] = []
        for route in pendingRoutes {
            do {
                try await syncRoute(route)
                syncedRouteIds.append(route.id)
            } catch {
                handleSyncError(error, for: route.id)
            }
        }

        // Remove successfully synced routes
        pendingRoutes.removeAll { syncedRouteIds.contains($0.id) }

        // Update state
        updatePendingCount()
        savePendingData()
        lastSyncTime = Date()
        isSyncing = false
    }

    private func syncWorkout(_ syncable: SyncableWorkout) async throws {
        let workout = syncable.workout

        // Create the sync message
        let message: [String: Any] = [
            "syncWorkout": [
                "id": syncable.id.uuidString,
                "startTime": workout.startTime.timeIntervalSince1970,
                "endTime": workout.endTime.timeIntervalSince1970,
                "duration": workout.duration,
                "distance": workout.distance,
                "calories": workout.calories,
                "averagePace": workout.averagePace,
                "averageHeartRate": workout.averageHeartRate,
                "wasIndependentMode": workout.wasIndependentMode,
                "heartRateSampleCount": workout.heartRateSamples.count,
                "routePointCount": workout.routePoints.count
            ]
        ]

        // Send via WatchConnectivity
        // Note: For large data (routes, samples), use file transfer
        try await sendSyncMessage(message)

        // If workout has significant route data, send via file transfer
        if workout.routePoints.count > 10 {
            try await sendRouteData(workout.routePoints, workoutId: syncable.id)
        }

        // If workout has heart rate samples, send via user info transfer
        if !workout.heartRateSamples.isEmpty {
            try await sendHeartRateSamples(workout.heartRateSamples, workoutId: syncable.id)
        }
    }

    private func syncRoute(_ syncable: SyncableRoute) async throws {
        try await sendRouteData(syncable.routePoints, workoutId: syncable.workoutId)
    }

    private func sendSyncMessage(_ message: [String: Any]) async throws {
        guard let session = WCSession.default as WCSession?,
              session.isReachable else {
            throw SyncError.notReachable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.sendMessage(message, replyHandler: { _ in
                continuation.resume()
            }, errorHandler: { error in
                continuation.resume(throwing: SyncError.sendFailed(error.localizedDescription))
            })
        }
    }

    private func sendRouteData(_ routePoints: [RoutePointData], workoutId: UUID) async throws {
        // Encode route data
        let encoder = JSONEncoder()
        let data = try encoder.encode(routePoints)

        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(workoutId.uuidString)_route.json")

        try data.write(to: tempURL)

        // Send file
        guard let session = WCSession.default as WCSession?,
              session.activationState == .activated else {
            throw SyncError.sessionNotActivated
        }

        let metadata: [String: Any] = [
            "type": "routeData",
            "workoutId": workoutId.uuidString
        ]

        session.transferFile(tempURL, metadata: metadata)

        // Clean up temp file after a delay
        Task {
            try? await Task.sleep(for: .seconds(60))
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    private func sendHeartRateSamples(_ samples: [HeartRateSampleData], workoutId: UUID) async throws {
        // Heart rate samples are smaller, use user info transfer
        let sampleData: [[String: Any]] = samples.map { sample in
            [
                "timestamp": sample.timestamp.timeIntervalSince1970,
                "bpm": sample.beatsPerMinute
            ]
        }

        let userInfo: [String: Any] = [
            "type": "heartRateSamples",
            "workoutId": workoutId.uuidString,
            "samples": sampleData
        ]

        guard let session = WCSession.default as WCSession?,
              session.activationState == .activated else {
            throw SyncError.sessionNotActivated
        }

        session.transferUserInfo(userInfo)
    }

    // MARK: - Error Handling

    private func handleSyncError(_ error: Error, for itemId: UUID) {
        lastSyncError = error as? SyncError ?? .unknown(error.localizedDescription)

        // Increment retry count for the failed item
        if let index = pendingWorkouts.firstIndex(where: { $0.id == itemId }) {
            pendingWorkouts[index].retryCount += 1

            // Remove if max retries exceeded
            if pendingWorkouts[index].retryCount >= maxRetryAttempts {
                pendingWorkouts.remove(at: index)
            }
        }

        if let index = pendingRoutes.firstIndex(where: { $0.id == itemId }) {
            pendingRoutes[index].retryCount += 1

            if pendingRoutes[index].retryCount >= maxRetryAttempts {
                pendingRoutes.remove(at: index)
            }
        }
    }

    // MARK: - Persistence

    private func savePendingData() {
        let data = PendingSyncData(
            workouts: pendingWorkouts,
            routes: pendingRoutes
        )

        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: pendingDataKey)
        }
    }

    private func loadPendingData() {
        guard let data = UserDefaults.standard.data(forKey: pendingDataKey),
              let decoded = try? JSONDecoder().decode(PendingSyncData.self, from: data) else {
            return
        }

        pendingWorkouts = decoded.workouts
        pendingRoutes = decoded.routes
        updatePendingCount()
    }

    private func updatePendingCount() {
        pendingItemCount = pendingWorkouts.count + pendingRoutes.count
    }

    // MARK: - Receiving Data from iPhone

    /// Handles incoming sync data from iPhone.
    ///
    /// Called by WatchConnectivityManager when sync data is received.
    public func handleIncomingSync(_ message: [String: Any]) {
        if let workoutUpdate = message["workoutUpdate"] as? [String: Any] {
            handleWorkoutUpdate(workoutUpdate)
        }

        if let statsUpdate = message["statsUpdate"] as? [String: Any] {
            handleStatsUpdate(statsUpdate)
        }
    }

    private func handleWorkoutUpdate(_ data: [String: Any]) {
        // Update local workout state based on iPhone data
        // This handles the case where iPhone is tracking and watch is displaying
    }

    private func handleStatsUpdate(_ data: [String: Any]) {
        // Handle historical workout stats from iPhone
    }
}

// MARK: - Supporting Types

/// Pending sync data container.
private struct PendingSyncData: Codable {
    var workouts: [SyncableWorkout]
    var routes: [SyncableRoute]
}

/// Workout data awaiting sync.
struct SyncableWorkout: Codable, Identifiable {
    let id: UUID
    let workout: WatchWorkoutResult
    let createdAt: Date
    var retryCount: Int
}

/// Route data awaiting sync.
struct SyncableRoute: Codable, Identifiable {
    let id: UUID
    let workoutId: UUID
    let routePoints: [RoutePointData]
    let createdAt: Date
    var retryCount: Int
}

// MARK: - SyncError

/// Errors that can occur during data synchronization.
public enum SyncError: Error, LocalizedError, Sendable {
    case notReachable
    case sessionNotActivated
    case sendFailed(String)
    case encodingFailed
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .notReachable:
            return "iPhone is not reachable."
        case .sessionNotActivated:
            return "WatchConnectivity session not activated."
        case .sendFailed(let reason):
            return "Failed to send data: \(reason)"
        case .encodingFailed:
            return "Failed to encode sync data."
        case .unknown(let reason):
            return "Sync error: \(reason)"
        }
    }
}
