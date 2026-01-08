//
//  WorkoutAnnouncementService.swift
//  JogPod
//
//  Manages workout announcements during active workouts.
//

import Foundation

// MARK: - WorkoutAnnouncementService

/// Manages periodic workout announcements during active workouts.
///
/// This service coordinates between the SpeechService and workout metrics,
/// rotating through enabled announcement types at a configurable interval.
///
/// ## Legacy Equivalence
///
/// This replaces the announcement rotation logic from the legacy codebase,
/// which was spread across `AnnouncementListAssemblyOperation` and
/// `WorkoutMetricsManager`. The rotation behavior is preserved:
///
/// 1. Enabled announcements are assembled into a list
/// 2. Each announcement interval, the next announcement in rotation is spoken
/// 3. Announcements with nil values (e.g., heart rate = 0) are skipped
///
/// ## Usage
///
/// ```swift
/// let announcementService = WorkoutAnnouncementService(
///     speechService: speechService,
///     unitSystem: .imperial
/// )
///
/// // Configure enabled announcements
/// announcementService.setEnabled([.currentSpeed, .distance, .calories])
///
/// // Update with latest metrics
/// announcementService.updateMetrics(workoutSnapshot)
///
/// // Speak next announcement in rotation
/// await announcementService.announceNext()
/// ```
public actor WorkoutAnnouncementService {

    // MARK: - Properties

    /// The speech service for speaking announcements.
    private let speechService: SpeechService

    /// The formatter for creating announcement strings.
    private let formatter: AnnouncementFormatter

    /// Currently enabled announcement types.
    private var enabledTypes: Set<AnnouncementType>

    /// Ordered list of enabled announcements for rotation.
    private var announcementRotation: [AnnouncementType] = []

    /// Current index in the announcement rotation.
    private var currentRotationIndex: Int = 0

    /// Current workout data for announcements.
    private var currentData: AnnouncementData = AnnouncementData()

    /// Weather data for announcements.
    private var weatherData: WeatherData?

    // MARK: - Initialization

    /// Creates a new WorkoutAnnouncementService.
    ///
    /// - Parameters:
    ///   - speechService: The speech service to use.
    ///   - unitSystem: The unit system for formatting. Defaults to `.imperial`.
    ///   - enabledTypes: Initially enabled announcement types. Defaults to defaults from AnnouncementType.
    public init(
        speechService: SpeechService,
        unitSystem: UnitSystem = .imperial,
        enabledTypes: Set<AnnouncementType>? = nil
    ) {
        self.speechService = speechService
        self.formatter = AnnouncementFormatter(unitSystem: unitSystem)

        // Use provided types or defaults
        let types: Set<AnnouncementType>
        if let provided = enabledTypes {
            types = provided
        } else {
            types = Set(AnnouncementType.allCases.filter { $0.isEnabledByDefault })
        }
        self.enabledTypes = types

        // Build initial rotation inline (actor init can access own state synchronously)
        self.announcementRotation = AnnouncementType.allCases.filter { types.contains($0) }
        self.currentRotationIndex = 0
    }

    // MARK: - Configuration

    /// Sets the enabled announcement types.
    ///
    /// - Parameter types: The set of announcement types to enable.
    public func setEnabled(_ types: Set<AnnouncementType>) {
        enabledTypes = types
        rebuildRotation()
    }

    /// Enables or disables a specific announcement type.
    ///
    /// - Parameters:
    ///   - type: The announcement type.
    ///   - enabled: Whether to enable the type.
    public func setAnnouncementType(_ type: AnnouncementType, enabled: Bool) {
        if enabled {
            enabledTypes.insert(type)
        } else {
            enabledTypes.remove(type)
        }
        rebuildRotation()
    }

    /// Returns whether an announcement type is enabled.
    ///
    /// - Parameter type: The announcement type.
    /// - Returns: True if the type is enabled.
    public func isEnabled(_ type: AnnouncementType) -> Bool {
        enabledTypes.contains(type)
    }

    /// Returns all currently enabled announcement types.
    public func getEnabledTypes() -> Set<AnnouncementType> {
        enabledTypes
    }

    /// Updates the unit system used for formatting.
    ///
    /// - Parameter unitSystem: The new unit system.
    /// - Returns: A new service with the updated unit system.
    public func withUnitSystem(_ unitSystem: UnitSystem) -> WorkoutAnnouncementService {
        let newService = WorkoutAnnouncementService(
            speechService: speechService,
            unitSystem: unitSystem,
            enabledTypes: enabledTypes
        )
        return newService
    }

    // MARK: - Metrics Updates

    /// Updates the current workout metrics.
    ///
    /// Call this method whenever workout metrics are updated to ensure
    /// announcements reflect the latest data.
    ///
    /// - Parameter data: The updated announcement data.
    public func updateMetrics(_ data: AnnouncementData) {
        currentData = data
    }

    /// Updates the current workout metrics from a WorkoutSnapshot.
    ///
    /// - Parameter snapshot: The workout snapshot.
    public func updateMetrics(from snapshot: WorkoutSnapshot) {
        currentData = formatter.createAnnouncementData(from: snapshot, weather: weatherData)
    }

    /// Updates the weather data for weather-related announcements.
    ///
    /// - Parameter weather: The weather data.
    public func updateWeather(_ weather: WeatherData) {
        weatherData = weather
        currentData.weather = weather
    }

    // MARK: - Announcements

    /// Announces the next metric in the rotation.
    ///
    /// This method rotates through enabled announcements, speaking the next
    /// one that has valid data. Announcements that return nil (e.g., heart rate
    /// when no heart rate data is available) are automatically skipped.
    ///
    /// - Returns: The announcement that was spoken, or nil if no valid announcement was available.
    @discardableResult
    public func announceNext() async -> String? {
        guard !announcementRotation.isEmpty else { return nil }

        // Try each announcement type until we find one with data
        var attempts = 0

        while attempts < announcementRotation.count {
            let type = announcementRotation[currentRotationIndex]
            advanceRotationIndex()
            attempts += 1

            if let announcement = formatter.format(type, data: currentData) {
                await speechService.speakSafely(announcement)
                return announcement
            }
        }

        return nil
    }

    /// Speaks a specific announcement type.
    ///
    /// - Parameter type: The announcement type to speak.
    /// - Returns: The announcement that was spoken, or nil if no valid data.
    @discardableResult
    public func announce(_ type: AnnouncementType) async -> String? {
        guard let announcement = formatter.format(type, data: currentData) else {
            return nil
        }
        await speechService.speakSafely(announcement)
        return announcement
    }

    /// Speaks all enabled announcements in order.
    ///
    /// This method speaks each enabled announcement that has valid data,
    /// with a brief pause between announcements.
    ///
    /// - Returns: The list of announcements that were spoken.
    public func announceAll() async -> [String] {
        var spoken: [String] = []

        for type in announcementRotation {
            if let announcement = formatter.format(type, data: currentData) {
                await speechService.speakSafely(announcement)
                spoken.append(announcement)

                // Brief pause between announcements
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }

        return spoken
    }

    /// Speaks a custom text announcement.
    ///
    /// - Parameter text: The text to speak.
    public func announceCustom(_ text: String) async {
        await speechService.speakSafely(text)
    }

    /// Resets the rotation index to the beginning.
    public func resetRotation() {
        currentRotationIndex = 0
    }

    // MARK: - Private Methods

    private func rebuildRotation() {
        // Maintain order from AnnouncementType.allCases but only include enabled types
        announcementRotation = AnnouncementType.allCases.filter { enabledTypes.contains($0) }

        // Reset index if it's now out of bounds
        if currentRotationIndex >= announcementRotation.count {
            currentRotationIndex = 0
        }
    }

    private func advanceRotationIndex() {
        currentRotationIndex = (currentRotationIndex + 1) % max(announcementRotation.count, 1)
    }
}

// MARK: - Timer-Based Announcements

extension WorkoutAnnouncementService {

    /// Creates a task that announces metrics at a regular interval.
    ///
    /// The returned task will continue announcing until cancelled.
    ///
    /// - Parameter interval: The interval between announcements in seconds.
    /// - Returns: A Task that performs periodic announcements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let announcementTask = announcementService.startPeriodicAnnouncements(interval: 60)
    ///
    /// // Later, when workout ends:
    /// announcementTask.cancel()
    /// ```
    public func startPeriodicAnnouncements(interval: TimeInterval) -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                await announceNext()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
}
