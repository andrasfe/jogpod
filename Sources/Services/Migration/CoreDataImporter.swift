import Foundation
import CoreData
import CoreLocation

/// Imports data from the legacy Core Data SQLite store.
///
/// This class is responsible for reading all entities from the legacy JogPod/JogCast
/// Core Data database. It handles:
/// - Opening the legacy SQLite store
/// - Fetching all entity types
/// - Decoding transformable attributes (especially CLLocation)
/// - Providing structured data for migration
///
/// - Important: This importer is read-only and does not modify the legacy store.
final class CoreDataImporter: Sendable {

    // MARK: - Types

    /// Raw data extracted from a legacy RSSEntity (podcast feed).
    struct LegacyPodcastFeed: Sendable {
        let objectID: String
        let imageUrl: String?
        let link: String?
        let summary: String?
        let title: String?
        let episodeObjectIDs: [String]
    }

    /// Raw data extracted from a legacy RSSEntry (podcast episode).
    struct LegacyPodcastEpisode: Sendable {
        let objectID: String
        let isCurrentInPlayer: Bool
        let date: Date?
        let enclosureMediaLink: String?
        let identifier: String?
        let index: Int32
        let lastUpdated: Date?
        let link: String?
        let name: String?
        let preferredPlayDurationInMinutes: Int32
        let releaseDate: Date?
        let summary: String?
        let title: String?
        let type: Int16
        let url: String?
        let feedObjectID: String?
    }

    /// Raw data extracted from a legacy Preference.
    struct LegacyPreference: Sendable {
        let objectID: String
        let name: String
        let boolValue: Bool?
        let dateValue: Date?
        let floatValue: Float?
        let intValue: Int16?
        let latCoord: Double?
        let longCoord: Double?
        let stringValue: String?
    }

    /// Raw data extracted from a legacy WorkoutHistory.
    struct LegacyWorkoutSession: Sendable {
        let objectID: String
        let workoutID: String?
        let address: String?
        let startTime: Date?
        let humidity: Float?
        let temperatureInCelsius: Float?
        let windSpeedInKmh: Float?
        let weatherIconUrl: String?
        let alertDate: String?
        let alertDescription: String?
        let alertExpires: String?
        let alertType: String?
    }

    /// Raw data extracted from a legacy WorkoutLocation.
    struct LegacyWorkoutTrackPoint: Sendable {
        let objectID: String
        let workoutID: String
        let time: Date?
        let heartRate: Int16?
        let steps: Int16?
        // Decomposed from CLLocation transformable
        let latitude: Double?
        let longitude: Double?
        let altitude: Double?
        let horizontalAccuracy: Double?
        let speed: Double?
        let course: Double?
    }

    /// Raw data extracted from a legacy WorkoutListeningLog.
    struct LegacyWorkoutListeningLog: Sendable {
        let objectID: String
        let workoutID: String?
        let time: Date?
        let entityTitle: String?
        let entryTitle: String?
        let entrySummary: String?
    }

    /// Container for all imported legacy data.
    struct ImportedData: Sendable {
        let feeds: [LegacyPodcastFeed]
        let episodes: [LegacyPodcastEpisode]
        let preferences: [LegacyPreference]
        let workoutSessions: [LegacyWorkoutSession]
        let trackPoints: [LegacyWorkoutTrackPoint]
        let listeningLogs: [LegacyWorkoutListeningLog]

        var isEmpty: Bool {
            feeds.isEmpty &&
            episodes.isEmpty &&
            preferences.isEmpty &&
            workoutSessions.isEmpty &&
            trackPoints.isEmpty &&
            listeningLogs.isEmpty
        }

        var totalCount: Int {
            feeds.count +
            episodes.count +
            preferences.count +
            workoutSessions.count +
            trackPoints.count +
            listeningLogs.count
        }
    }

    // MARK: - Properties

    private let storeURL: URL
    private let fileManager: FileManager

    // MARK: - Initialization

    /// Creates an importer for the legacy Core Data store.
    ///
    /// - Parameters:
    ///   - storeURL: URL to the legacy SQLite store file.
    ///   - fileManager: File manager for file system operations.
    init(storeURL: URL, fileManager: FileManager = .default) {
        self.storeURL = storeURL
        self.fileManager = fileManager
    }

    /// Creates an importer using the default legacy store location.
    ///
    /// The legacy store is expected at:
    /// `~/Library/Application Support/JogCast/JogCast.sqlite`
    ///
    /// - Parameter fileManager: File manager for file system operations.
    /// - Returns: A configured importer, or nil if the default path cannot be determined.
    static func defaultImporter(fileManager: FileManager = .default) -> CoreDataImporter? {
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let storeURL = appSupport
            .appendingPathComponent("JogCast", isDirectory: true)
            .appendingPathComponent("JogCast.sqlite")

        return CoreDataImporter(storeURL: storeURL, fileManager: fileManager)
    }

    // MARK: - Store Validation

    /// Checks if the legacy store exists and is accessible.
    ///
    /// - Returns: `true` if the store file exists.
    func storeExists() -> Bool {
        fileManager.fileExists(atPath: storeURL.path)
    }

    /// Validates the legacy store can be opened.
    ///
    /// - Throws: `MigrationError` if the store cannot be accessed.
    func validateStore() throws {
        guard storeExists() else {
            throw MigrationError.storeNotFound(path: storeURL.path)
        }

        // Check if the file is readable
        guard fileManager.isReadableFile(atPath: storeURL.path) else {
            throw MigrationError.storeAccessFailed(
                path: storeURL.path,
                underlyingError: NSError(
                    domain: NSCocoaErrorDomain,
                    code: NSFileReadNoPermissionError,
                    userInfo: [NSLocalizedDescriptionKey: "File is not readable"]
                )
            )
        }
    }

    // MARK: - Import All Data

    /// Imports all data from the legacy Core Data store.
    ///
    /// This method reads all entities from the legacy store and returns them
    /// as structured Swift types ready for migration to SwiftData.
    ///
    /// - Parameter progressHandler: Optional callback for progress updates.
    /// - Returns: Container with all imported data.
    /// - Throws: `MigrationError` if import fails.
    func importAllData(
        progressHandler: (@Sendable (String, Int, Int) -> Void)? = nil
    ) async throws -> ImportedData {
        try validateStore()

        // Create the managed object model programmatically
        let model = createLegacyModel()

        // Set up the persistent store coordinator
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: false,
            NSInferMappingModelAutomaticallyOption: false,
            NSReadOnlyPersistentStoreOption: true
        ]

        do {
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
        } catch {
            throw MigrationError.storeAccessFailed(path: storeURL.path, underlyingError: error)
        }

        // Create context for reading
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        return try await context.perform {
            var currentStep = 0
            let totalSteps = 6

            // Import all entity types
            progressHandler?("Importing podcast feeds...", currentStep, totalSteps)
            let feeds = try self.importFeeds(context: context)
            currentStep += 1

            progressHandler?("Importing podcast episodes...", currentStep, totalSteps)
            let episodes = try self.importEpisodes(context: context)
            currentStep += 1

            progressHandler?("Importing preferences...", currentStep, totalSteps)
            let preferences = try self.importPreferences(context: context)
            currentStep += 1

            progressHandler?("Importing workout sessions...", currentStep, totalSteps)
            let sessions = try self.importWorkoutSessions(context: context)
            currentStep += 1

            progressHandler?("Importing workout track points...", currentStep, totalSteps)
            let trackPoints = try self.importTrackPoints(context: context)
            currentStep += 1

            progressHandler?("Importing listening logs...", currentStep, totalSteps)
            let logs = try self.importListeningLogs(context: context)
            currentStep += 1

            return ImportedData(
                feeds: feeds,
                episodes: episodes,
                preferences: preferences,
                workoutSessions: sessions,
                trackPoints: trackPoints,
                listeningLogs: logs
            )
        }
    }

    // MARK: - Individual Entity Imports

    private func importFeeds(context: NSManagedObjectContext) throws -> [LegacyPodcastFeed] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "RSSEntity")

        let objects: [NSManagedObject]
        do {
            objects = try context.fetch(request)
        } catch {
            throw MigrationError.fetchFailed(entityName: "RSSEntity", underlyingError: error)
        }

        return objects.map { object in
            let objectID = object.objectID.uriRepresentation().absoluteString

            // Get related episode IDs
            var episodeIDs: [String] = []
            if let episodes = object.value(forKey: "contains") as? Set<NSManagedObject> {
                episodeIDs = episodes.map { $0.objectID.uriRepresentation().absoluteString }
            }

            return LegacyPodcastFeed(
                objectID: objectID,
                imageUrl: object.value(forKey: "imageUrl") as? String,
                link: object.value(forKey: "link") as? String,
                summary: object.value(forKey: "summary") as? String,
                title: object.value(forKey: "title") as? String,
                episodeObjectIDs: episodeIDs
            )
        }
    }

    private func importEpisodes(context: NSManagedObjectContext) throws -> [LegacyPodcastEpisode] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "RSSEntry")

        let objects: [NSManagedObject]
        do {
            objects = try context.fetch(request)
        } catch {
            throw MigrationError.fetchFailed(entityName: "RSSEntry", underlyingError: error)
        }

        return objects.map { object in
            let objectID = object.objectID.uriRepresentation().absoluteString

            // Get parent feed ID
            var feedID: String?
            if let feed = object.value(forKey: "belongsTo") as? NSManagedObject {
                feedID = feed.objectID.uriRepresentation().absoluteString
            }

            return LegacyPodcastEpisode(
                objectID: objectID,
                isCurrentInPlayer: (object.value(forKey: "currentInPlayer") as? Bool) ?? false,
                date: object.value(forKey: "date") as? Date,
                enclosureMediaLink: object.value(forKey: "enclosureMediaLink") as? String,
                identifier: object.value(forKey: "identifier") as? String,
                index: (object.value(forKey: "index") as? Int32) ?? 0,
                lastUpdated: object.value(forKey: "lastUpdated") as? Date,
                link: object.value(forKey: "link") as? String,
                name: object.value(forKey: "name") as? String,
                preferredPlayDurationInMinutes: (object.value(forKey: "preferredPlayDurationInMinutes") as? Int32) ?? 0,
                releaseDate: object.value(forKey: "releaseDate") as? Date,
                summary: object.value(forKey: "summary") as? String,
                title: object.value(forKey: "title") as? String,
                type: (object.value(forKey: "type") as? Int16) ?? 0,
                url: object.value(forKey: "url") as? String,
                feedObjectID: feedID
            )
        }
    }

    private func importPreferences(context: NSManagedObjectContext) throws -> [LegacyPreference] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Preference")

        let objects: [NSManagedObject]
        do {
            objects = try context.fetch(request)
        } catch {
            throw MigrationError.fetchFailed(entityName: "Preference", underlyingError: error)
        }

        return objects.compactMap { object in
            let objectID = object.objectID.uriRepresentation().absoluteString

            guard let name = object.value(forKey: "name") as? String else {
                // Skip preferences without a name - they're invalid
                return nil
            }

            return LegacyPreference(
                objectID: objectID,
                name: name,
                boolValue: object.value(forKey: "boolValue") as? Bool,
                dateValue: object.value(forKey: "dateValue") as? Date,
                floatValue: object.value(forKey: "floatValue") as? Float,
                intValue: object.value(forKey: "intValue") as? Int16,
                latCoord: object.value(forKey: "latCoord") as? Double,
                longCoord: object.value(forKey: "longCoord") as? Double,
                stringValue: object.value(forKey: "stringValue") as? String
            )
        }
    }

    private func importWorkoutSessions(context: NSManagedObjectContext) throws -> [LegacyWorkoutSession] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutHistory")

        let objects: [NSManagedObject]
        do {
            objects = try context.fetch(request)
        } catch {
            throw MigrationError.fetchFailed(entityName: "WorkoutHistory", underlyingError: error)
        }

        return objects.map { object in
            let objectID = object.objectID.uriRepresentation().absoluteString

            return LegacyWorkoutSession(
                objectID: objectID,
                workoutID: object.value(forKey: "workoutID") as? String,
                address: object.value(forKey: "address") as? String,
                startTime: object.value(forKey: "startTime") as? Date,
                humidity: object.value(forKey: "humidity") as? Float,
                temperatureInCelsius: object.value(forKey: "temperatureInCelsius") as? Float,
                windSpeedInKmh: object.value(forKey: "windSpeedInKmh") as? Float,
                weatherIconUrl: object.value(forKey: "weatherIconUrl") as? String,
                alertDate: object.value(forKey: "alertDate") as? String,
                alertDescription: object.value(forKey: "alertDescription") as? String,
                alertExpires: object.value(forKey: "alertExpires") as? String,
                alertType: object.value(forKey: "alertType") as? String
            )
        }
    }

    private func importTrackPoints(context: NSManagedObjectContext) throws -> [LegacyWorkoutTrackPoint] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutLocation")

        let objects: [NSManagedObject]
        do {
            objects = try context.fetch(request)
        } catch {
            throw MigrationError.fetchFailed(entityName: "WorkoutLocation", underlyingError: error)
        }

        return objects.compactMap { object -> LegacyWorkoutTrackPoint? in
            let objectID = object.objectID.uriRepresentation().absoluteString

            guard let workoutID = object.value(forKey: "workoutID") as? String else {
                // Skip track points without a workout ID - they're orphaned
                return nil
            }

            // Decode CLLocation from transformable
            var latitude: Double?
            var longitude: Double?
            var altitude: Double?
            var horizontalAccuracy: Double?
            var speed: Double?
            var course: Double?

            if let location = object.value(forKey: "location") as? CLLocation {
                latitude = location.coordinate.latitude
                longitude = location.coordinate.longitude
                altitude = location.altitude
                horizontalAccuracy = location.horizontalAccuracy
                speed = location.speed >= 0 ? location.speed : nil
                course = location.course >= 0 ? location.course : nil
            }

            return LegacyWorkoutTrackPoint(
                objectID: objectID,
                workoutID: workoutID,
                time: object.value(forKey: "time") as? Date,
                heartRate: object.value(forKey: "heartRate") as? Int16,
                steps: object.value(forKey: "steps") as? Int16,
                latitude: latitude,
                longitude: longitude,
                altitude: altitude,
                horizontalAccuracy: horizontalAccuracy,
                speed: speed,
                course: course
            )
        }
    }

    private func importListeningLogs(context: NSManagedObjectContext) throws -> [LegacyWorkoutListeningLog] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutListeningLog")

        let objects: [NSManagedObject]
        do {
            objects = try context.fetch(request)
        } catch {
            throw MigrationError.fetchFailed(entityName: "WorkoutListeningLog", underlyingError: error)
        }

        return objects.map { object in
            let objectID = object.objectID.uriRepresentation().absoluteString

            return LegacyWorkoutListeningLog(
                objectID: objectID,
                workoutID: object.value(forKey: "workoutID") as? String,
                time: object.value(forKey: "time") as? Date,
                entityTitle: object.value(forKey: "entityTitle") as? String,
                entryTitle: object.value(forKey: "entryTitle") as? String,
                entrySummary: object.value(forKey: "entrySummary") as? String
            )
        }
    }

    // MARK: - Core Data Model Creation

    /// Creates the legacy Core Data model programmatically.
    ///
    /// This avoids needing to include the .xcdatamodeld file in the new project.
    private func createLegacyModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Create all entities
        let preferenceEntity = createPreferenceEntity()
        let rssEntityEntity = createRSSEntityEntity()
        let rssEntryEntity = createRSSEntryEntity()
        let workoutHistoryEntity = createWorkoutHistoryEntity()
        let workoutLocationEntity = createWorkoutLocationEntity()
        let workoutListeningLogEntity = createWorkoutListeningLogEntity()

        // Set up relationships
        setupRSSRelationships(entity: rssEntityEntity, entry: rssEntryEntity)

        model.entities = [
            preferenceEntity,
            rssEntityEntity,
            rssEntryEntity,
            workoutHistoryEntity,
            workoutLocationEntity,
            workoutListeningLogEntity
        ]

        return model
    }

    private func createPreferenceEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "Preference"
        entity.managedObjectClassName = "NSManagedObject"

        entity.properties = [
            createAttribute(name: "name", type: .stringAttributeType, optional: false, indexed: true),
            createAttribute(name: "boolValue", type: .booleanAttributeType, optional: true),
            createAttribute(name: "dateValue", type: .dateAttributeType, optional: true),
            createAttribute(name: "floatValue", type: .floatAttributeType, optional: true),
            createAttribute(name: "intValue", type: .integer16AttributeType, optional: true),
            createAttribute(name: "latCoord", type: .doubleAttributeType, optional: true),
            createAttribute(name: "longCoord", type: .doubleAttributeType, optional: true),
            createAttribute(name: "stringValue", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private func createRSSEntityEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "RSSEntity"
        entity.managedObjectClassName = "NSManagedObject"

        entity.properties = [
            createAttribute(name: "imageUrl", type: .stringAttributeType, optional: true),
            createAttribute(name: "link", type: .stringAttributeType, optional: true),
            createAttribute(name: "summary", type: .stringAttributeType, optional: true),
            createAttribute(name: "title", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private func createRSSEntryEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "RSSEntry"
        entity.managedObjectClassName = "NSManagedObject"

        entity.properties = [
            createAttribute(name: "currentInPlayer", type: .booleanAttributeType, optional: true),
            createAttribute(name: "date", type: .dateAttributeType, optional: true),
            createAttribute(name: "enclosureMediaLink", type: .stringAttributeType, optional: true),
            createAttribute(name: "identifier", type: .stringAttributeType, optional: true),
            createAttribute(name: "index", type: .integer32AttributeType, optional: true),
            createAttribute(name: "lastUpdated", type: .dateAttributeType, optional: true),
            createAttribute(name: "link", type: .stringAttributeType, optional: true),
            createAttribute(name: "name", type: .stringAttributeType, optional: true),
            createAttribute(name: "preferredPlayDurationInMinutes", type: .integer32AttributeType, optional: true),
            createAttribute(name: "releaseDate", type: .dateAttributeType, optional: true),
            createAttribute(name: "summary", type: .stringAttributeType, optional: true),
            createAttribute(name: "title", type: .stringAttributeType, optional: true),
            createAttribute(name: "type", type: .integer16AttributeType, optional: true),
            createAttribute(name: "url", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private func createWorkoutHistoryEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "WorkoutHistory"
        entity.managedObjectClassName = "NSManagedObject"

        entity.properties = [
            createAttribute(name: "workoutID", type: .stringAttributeType, optional: true),
            createAttribute(name: "address", type: .stringAttributeType, optional: true),
            createAttribute(name: "startTime", type: .dateAttributeType, optional: true),
            createAttribute(name: "humidity", type: .floatAttributeType, optional: true),
            createAttribute(name: "temperatureInCelsius", type: .floatAttributeType, optional: true),
            createAttribute(name: "windSpeedInKmh", type: .floatAttributeType, optional: true),
            createAttribute(name: "weatherIconUrl", type: .stringAttributeType, optional: true),
            createAttribute(name: "alertDate", type: .stringAttributeType, optional: true),
            createAttribute(name: "alertDescription", type: .stringAttributeType, optional: true),
            createAttribute(name: "alertExpires", type: .stringAttributeType, optional: true),
            createAttribute(name: "alertType", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private func createWorkoutLocationEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "WorkoutLocation"
        entity.managedObjectClassName = "NSManagedObject"

        // Register custom value transformer for CLLocation that handles legacy data
        CLLocationValueTransformer.register()

        let locationAttr = NSAttributeDescription()
        locationAttr.name = "location"
        locationAttr.attributeType = .transformableAttributeType
        locationAttr.isOptional = true
        // Use our custom transformer that handles both secure and legacy unarchiving
        locationAttr.valueTransformerName = CLLocationValueTransformer.transformerName.rawValue
        locationAttr.attributeValueClassName = "CLLocation"

        entity.properties = [
            createAttribute(name: "workoutID", type: .stringAttributeType, optional: false, indexed: true),
            createAttribute(name: "time", type: .dateAttributeType, optional: true),
            createAttribute(name: "heartRate", type: .integer16AttributeType, optional: true),
            createAttribute(name: "steps", type: .integer16AttributeType, optional: true),
            locationAttr
        ]

        return entity
    }

    private func createWorkoutListeningLogEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "WorkoutListeningLog"
        entity.managedObjectClassName = "NSManagedObject"

        entity.properties = [
            createAttribute(name: "workoutID", type: .stringAttributeType, optional: true),
            createAttribute(name: "time", type: .dateAttributeType, optional: true),
            createAttribute(name: "entityTitle", type: .stringAttributeType, optional: true),
            createAttribute(name: "entryTitle", type: .stringAttributeType, optional: true),
            createAttribute(name: "entrySummary", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private func createAttribute(
        name: String,
        type: NSAttributeType,
        optional: Bool,
        indexed: Bool = false
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        attr.isIndexed = indexed
        return attr
    }

    private func setupRSSRelationships(entity: NSEntityDescription, entry: NSEntityDescription) {
        // RSSEntity.contains -> RSSEntry (to-many)
        let containsRelation = NSRelationshipDescription()
        containsRelation.name = "contains"
        containsRelation.destinationEntity = entry
        containsRelation.isOptional = true
        containsRelation.deleteRule = .nullifyDeleteRule
        containsRelation.minCount = 0
        containsRelation.maxCount = 0 // 0 means to-many

        // RSSEntry.belongsTo -> RSSEntity (to-one)
        let belongsToRelation = NSRelationshipDescription()
        belongsToRelation.name = "belongsTo"
        belongsToRelation.destinationEntity = entity
        belongsToRelation.isOptional = true
        belongsToRelation.deleteRule = .nullifyDeleteRule
        belongsToRelation.minCount = 1
        belongsToRelation.maxCount = 1

        // Set inverse relationships
        containsRelation.inverseRelationship = belongsToRelation
        belongsToRelation.inverseRelationship = containsRelation

        // Add to entities
        var entityProps = entity.properties
        entityProps.append(containsRelation)
        entity.properties = entityProps

        var entryProps = entry.properties
        entryProps.append(belongsToRelation)
        entry.properties = entryProps
    }
}

// MARK: - Import Statistics

extension CoreDataImporter.ImportedData {

    /// Summary statistics for the imported data.
    var statistics: [String: Int] {
        [
            "Podcast Feeds": feeds.count,
            "Podcast Episodes": episodes.count,
            "Preferences": preferences.count,
            "Workout Sessions": workoutSessions.count,
            "Track Points": trackPoints.count,
            "Listening Logs": listeningLogs.count,
            "Total Records": totalCount
        ]
    }

    /// Returns a formatted summary string.
    func summaryDescription() -> String {
        let lines = [
            "Imported Data Summary:",
            "  - Podcast Feeds: \(feeds.count)",
            "  - Podcast Episodes: \(episodes.count)",
            "  - Preferences: \(preferences.count)",
            "  - Workout Sessions: \(workoutSessions.count)",
            "  - Track Points: \(trackPoints.count)",
            "  - Listening Logs: \(listeningLogs.count)",
            "  Total: \(totalCount) records"
        ]
        return lines.joined(separator: "\n")
    }
}
