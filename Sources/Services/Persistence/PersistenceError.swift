//
//  PersistenceError.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation
import SwiftData

/// Errors that can occur during persistence operations.
///
/// This enum provides structured error handling for all database operations
/// in the JogPod application. Each case includes associated values that provide
/// context about the specific failure.
public enum PersistenceError: Error, Equatable, Sendable {

    // MARK: - Container Errors

    /// Failed to create the ModelContainer.
    ///
    /// - Parameter underlyingError: The original error from SwiftData.
    case containerCreationFailed(String)

    /// The ModelContainer is not available.
    ///
    /// This typically occurs when attempting operations before initialization.
    case containerUnavailable

    // MARK: - Fetch Errors

    /// A fetch operation failed.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity being fetched.
    ///   - reason: Description of why the fetch failed.
    case fetchFailed(entityName: String, reason: String)

    /// The requested entity was not found.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity type.
    ///   - identifier: The identifier used to search for the entity.
    case entityNotFound(entityName: String, identifier: String)

    // MARK: - Save Errors

    /// A save operation failed.
    ///
    /// - Parameter reason: Description of why the save failed.
    case saveFailed(reason: String)

    /// An insert operation failed.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity being inserted.
    ///   - reason: Description of why the insert failed.
    case insertFailed(entityName: String, reason: String)

    // MARK: - Delete Errors

    /// A delete operation failed.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity being deleted.
    ///   - reason: Description of why the delete failed.
    case deleteFailed(entityName: String, reason: String)

    // MARK: - Update Errors

    /// An update operation failed.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity being updated.
    ///   - reason: Description of why the update failed.
    case updateFailed(entityName: String, reason: String)

    // MARK: - Validation Errors

    /// A validation error occurred.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity being validated.
    ///   - field: The field that failed validation.
    ///   - reason: Description of why validation failed.
    case validationFailed(entityName: String, field: String, reason: String)

    /// A required relationship is missing.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity.
    ///   - relationshipName: The name of the missing relationship.
    case missingRelationship(entityName: String, relationshipName: String)

    // MARK: - Concurrency Errors

    /// A context mismatch occurred during an operation.
    ///
    /// This happens when attempting to use an object from a different ModelContext.
    case contextMismatch

    /// An operation was attempted on an invalid or deleted object.
    case invalidObject

    // MARK: - Migration Errors

    /// A migration operation failed.
    ///
    /// - Parameter reason: Description of why the migration failed.
    case migrationFailed(reason: String)

    // MARK: - Unknown Errors

    /// An unknown error occurred.
    ///
    /// - Parameter underlyingError: The original error, if available.
    case unknown(String)
}

// MARK: - LocalizedError Conformance

extension PersistenceError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .containerCreationFailed(let error):
            return "Failed to create persistence container: \(error)"

        case .containerUnavailable:
            return "Persistence container is not available"

        case .fetchFailed(let entityName, let reason):
            return "Failed to fetch \(entityName): \(reason)"

        case .entityNotFound(let entityName, let identifier):
            return "\(entityName) with identifier '\(identifier)' was not found"

        case .saveFailed(let reason):
            return "Failed to save changes: \(reason)"

        case .insertFailed(let entityName, let reason):
            return "Failed to insert \(entityName): \(reason)"

        case .deleteFailed(let entityName, let reason):
            return "Failed to delete \(entityName): \(reason)"

        case .updateFailed(let entityName, let reason):
            return "Failed to update \(entityName): \(reason)"

        case .validationFailed(let entityName, let field, let reason):
            return "Validation failed for \(entityName).\(field): \(reason)"

        case .missingRelationship(let entityName, let relationshipName):
            return "\(entityName) is missing required relationship '\(relationshipName)'"

        case .contextMismatch:
            return "Object belongs to a different model context"

        case .invalidObject:
            return "Operation attempted on an invalid or deleted object"

        case .migrationFailed(let reason):
            return "Data migration failed: \(reason)"

        case .unknown(let error):
            return "An unknown persistence error occurred: \(error)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .containerCreationFailed:
            return "The SwiftData container could not be initialized"

        case .containerUnavailable:
            return "No container exists to perform the operation"

        case .fetchFailed:
            return "The database query could not be executed"

        case .entityNotFound:
            return "No matching record exists in the database"

        case .saveFailed:
            return "Changes could not be persisted to disk"

        case .insertFailed:
            return "A new record could not be created"

        case .deleteFailed:
            return "The record could not be removed from the database"

        case .updateFailed:
            return "The record could not be modified"

        case .validationFailed:
            return "The data does not meet validation requirements"

        case .missingRelationship:
            return "A required related object is not set"

        case .contextMismatch:
            return "Cross-context operations are not allowed"

        case .invalidObject:
            return "The object reference is no longer valid"

        case .migrationFailed:
            return "Schema migration could not be completed"

        case .unknown:
            return "An unexpected error occurred"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .containerCreationFailed:
            return "Try restarting the application. If the problem persists, reinstall the app."

        case .containerUnavailable:
            return "Ensure the persistence layer is properly initialized before use."

        case .fetchFailed:
            return "Check the fetch predicate and try again."

        case .entityNotFound:
            return "Verify the identifier is correct or create a new record."

        case .saveFailed:
            return "Check available storage space and try again."

        case .insertFailed:
            return "Verify all required fields are provided and valid."

        case .deleteFailed:
            return "Ensure the object exists and is not locked by another operation."

        case .updateFailed:
            return "Fetch the latest version of the object and try again."

        case .validationFailed:
            return "Correct the invalid field value and try again."

        case .missingRelationship:
            return "Set the required relationship before saving."

        case .contextMismatch:
            return "Fetch the object from the current context before modifying."

        case .invalidObject:
            return "Refresh the object from the database."

        case .migrationFailed:
            return "Contact support if the problem persists."

        case .unknown:
            return "Try the operation again. If the problem persists, restart the app."
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension PersistenceError: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case .containerCreationFailed(let error):
            return "PersistenceError.containerCreationFailed(\(error))"

        case .containerUnavailable:
            return "PersistenceError.containerUnavailable"

        case .fetchFailed(let entityName, let reason):
            return "PersistenceError.fetchFailed(entityName: \"\(entityName)\", reason: \"\(reason)\")"

        case .entityNotFound(let entityName, let identifier):
            return "PersistenceError.entityNotFound(entityName: \"\(entityName)\", identifier: \"\(identifier)\")"

        case .saveFailed(let reason):
            return "PersistenceError.saveFailed(reason: \"\(reason)\")"

        case .insertFailed(let entityName, let reason):
            return "PersistenceError.insertFailed(entityName: \"\(entityName)\", reason: \"\(reason)\")"

        case .deleteFailed(let entityName, let reason):
            return "PersistenceError.deleteFailed(entityName: \"\(entityName)\", reason: \"\(reason)\")"

        case .updateFailed(let entityName, let reason):
            return "PersistenceError.updateFailed(entityName: \"\(entityName)\", reason: \"\(reason)\")"

        case .validationFailed(let entityName, let field, let reason):
            return "PersistenceError.validationFailed(entityName: \"\(entityName)\", field: \"\(field)\", reason: \"\(reason)\")"

        case .missingRelationship(let entityName, let relationshipName):
            return "PersistenceError.missingRelationship(entityName: \"\(entityName)\", relationshipName: \"\(relationshipName)\")"

        case .contextMismatch:
            return "PersistenceError.contextMismatch"

        case .invalidObject:
            return "PersistenceError.invalidObject"

        case .migrationFailed(let reason):
            return "PersistenceError.migrationFailed(reason: \"\(reason)\")"

        case .unknown(let error):
            return "PersistenceError.unknown(\(error))"
        }
    }
}
