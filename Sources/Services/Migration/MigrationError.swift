import Foundation

/// Errors that can occur during data migration from legacy Core Data to SwiftData.
///
/// This error type provides detailed information about migration failures,
/// enabling proper error handling, logging, and user feedback.
enum MigrationError: Error, Sendable {

    // MARK: - Store Access Errors

    /// The legacy Core Data store file was not found at the expected location.
    case storeNotFound(path: String)

    /// Failed to open or read the legacy Core Data store.
    case storeAccessFailed(path: String, underlyingError: Error)

    /// The Core Data model could not be loaded or is incompatible.
    case modelLoadFailed(reason: String)

    /// The store appears to be corrupted or unreadable.
    case storeCorrupted(path: String, details: String)

    // MARK: - Data Reading Errors

    /// Failed to fetch entities from the legacy store.
    case fetchFailed(entityName: String, underlyingError: Error)

    /// An entity is missing required attributes.
    case missingRequiredAttribute(entityName: String, attributeName: String, objectID: String?)

    /// Failed to decode a transformable attribute.
    case transformableDecodeFailed(entityName: String, attributeName: String, objectID: String?)

    /// A relationship could not be resolved.
    case relationshipResolutionFailed(
        sourceEntity: String,
        relationshipName: String,
        targetEntity: String,
        reason: String
    )

    // MARK: - Data Writing Errors

    /// Failed to insert a migrated entity into SwiftData.
    case insertFailed(modelType: String, underlyingError: Error)

    /// Failed to save the SwiftData context after migration.
    case saveFailed(underlyingError: Error)

    /// A unique constraint was violated during migration.
    case uniqueConstraintViolation(modelType: String, attributeName: String, value: String)

    // MARK: - Migration Process Errors

    /// Migration was cancelled by the user or system.
    case cancelled

    /// Migration is already in progress.
    case alreadyInProgress

    /// A previous migration is incomplete and rollback failed.
    case rollbackFailed(underlyingError: Error)

    /// The migration state is invalid for the requested operation.
    case invalidState(expected: String, actual: String)

    /// Migration cannot proceed due to insufficient storage.
    case insufficientStorage(required: Int64, available: Int64)

    // MARK: - Validation Errors

    /// Post-migration validation detected data integrity issues.
    case validationFailed(issues: [ValidationIssue])

    /// The migrated data counts do not match the source.
    case countMismatch(entityName: String, expected: Int, actual: Int)
}

// MARK: - ValidationIssue

extension MigrationError {

    /// Represents a single data validation issue found during migration verification.
    struct ValidationIssue: Sendable, CustomStringConvertible {
        let entityName: String
        let attributeName: String?
        let objectIdentifier: String?
        let message: String

        var description: String {
            var parts = [entityName]
            if let attr = attributeName {
                parts.append(".\(attr)")
            }
            if let id = objectIdentifier {
                parts.append(" (ID: \(id))")
            }
            parts.append(": \(message)")
            return parts.joined()
        }
    }
}

// MARK: - LocalizedError Conformance

extension MigrationError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .storeNotFound(let path):
            return "Legacy database not found at: \(path)"

        case .storeAccessFailed(let path, _):
            return "Failed to access legacy database at: \(path)"

        case .modelLoadFailed(let reason):
            return "Failed to load Core Data model: \(reason)"

        case .storeCorrupted(let path, let details):
            return "Database appears corrupted at \(path): \(details)"

        case .fetchFailed(let entityName, _):
            return "Failed to read \(entityName) records from legacy database"

        case .missingRequiredAttribute(let entityName, let attributeName, _):
            return "\(entityName) is missing required attribute: \(attributeName)"

        case .transformableDecodeFailed(let entityName, let attributeName, _):
            return "Failed to decode \(attributeName) in \(entityName)"

        case .relationshipResolutionFailed(let source, let relationship, let target, let reason):
            return "Failed to link \(source).\(relationship) to \(target): \(reason)"

        case .insertFailed(let modelType, _):
            return "Failed to create \(modelType) in new database"

        case .saveFailed:
            return "Failed to save migrated data"

        case .uniqueConstraintViolation(let modelType, let attributeName, let value):
            return "Duplicate \(modelType).\(attributeName) value: \(value)"

        case .cancelled:
            return "Migration was cancelled"

        case .alreadyInProgress:
            return "A migration is already in progress"

        case .rollbackFailed:
            return "Failed to rollback incomplete migration"

        case .invalidState(let expected, let actual):
            return "Invalid migration state: expected \(expected), got \(actual)"

        case .insufficientStorage(let required, let available):
            let formatter = ByteCountFormatter()
            let reqStr = formatter.string(fromByteCount: required)
            let availStr = formatter.string(fromByteCount: available)
            return "Insufficient storage: need \(reqStr), have \(availStr)"

        case .validationFailed(let issues):
            let issueCount = issues.count
            return "Migration validation failed with \(issueCount) issue\(issueCount == 1 ? "" : "s")"

        case .countMismatch(let entityName, let expected, let actual):
            return "Record count mismatch for \(entityName): expected \(expected), got \(actual)"
        }
    }

    var failureReason: String? {
        switch self {
        case .storeAccessFailed(_, let error),
             .fetchFailed(_, let error),
             .insertFailed(_, let error),
             .saveFailed(let error),
             .rollbackFailed(let error):
            return error.localizedDescription

        case .storeCorrupted(_, let details):
            return details

        case .relationshipResolutionFailed(_, _, _, let reason):
            return reason

        case .validationFailed(let issues):
            return issues.map(\.description).joined(separator: "\n")

        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storeNotFound:
            return "Ensure the legacy app data exists. If this is a fresh install, no migration is needed."

        case .storeCorrupted:
            return "The legacy database may be damaged. Consider restoring from a backup if available."

        case .insufficientStorage:
            return "Free up storage space and try again."

        case .alreadyInProgress:
            return "Wait for the current migration to complete."

        case .cancelled:
            return "Restart the migration when ready."

        case .rollbackFailed:
            return "Manual cleanup may be required. Contact support if issues persist."

        default:
            return "Try running migration again. If the problem persists, contact support."
        }
    }
}

// MARK: - Equatable Conformance

extension MigrationError: Equatable {

    static func == (lhs: MigrationError, rhs: MigrationError) -> Bool {
        switch (lhs, rhs) {
        case (.storeNotFound(let l), .storeNotFound(let r)):
            return l == r

        case (.modelLoadFailed(let l), .modelLoadFailed(let r)):
            return l == r

        case (.cancelled, .cancelled),
             (.alreadyInProgress, .alreadyInProgress):
            return true

        case (.invalidState(let le, let la), .invalidState(let re, let ra)):
            return le == re && la == ra

        case (.insufficientStorage(let lr, let la), .insufficientStorage(let rr, let ra)):
            return lr == rr && la == ra

        case (.countMismatch(let le, let lexp, let lact), .countMismatch(let re, let rexp, let ract)):
            return le == re && lexp == rexp && lact == ract

        default:
            // For errors with underlying errors or complex types, compare descriptions
            return lhs.errorDescription == rhs.errorDescription
        }
    }
}

// MARK: - Convenience Factories

extension MigrationError {

    /// Creates a validation issue for a missing relationship target.
    static func missingRelationshipTarget(
        source: String,
        relationship: String,
        targetEntity: String,
        targetID: String
    ) -> MigrationError {
        .relationshipResolutionFailed(
            sourceEntity: source,
            relationshipName: relationship,
            targetEntity: targetEntity,
            reason: "Target with ID '\(targetID)' not found"
        )
    }
}
