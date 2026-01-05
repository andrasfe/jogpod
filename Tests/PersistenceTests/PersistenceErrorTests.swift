//
//  PersistenceErrorTests.swift
//  JogPodTests
//
//  Created for JogPod Revival project.
//

import XCTest
@testable import JogPod

/// Tests for PersistenceError types and their properties.
final class PersistenceErrorTests: XCTestCase {

    // MARK: - Equatable Tests

    func testContainerCreationFailedEquality() {
        let error1 = PersistenceError.containerCreationFailed("Test error")
        let error2 = PersistenceError.containerCreationFailed("Test error")
        let error3 = PersistenceError.containerCreationFailed("Different error")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testContainerUnavailableEquality() {
        let error1 = PersistenceError.containerUnavailable
        let error2 = PersistenceError.containerUnavailable

        XCTAssertEqual(error1, error2)
    }

    func testFetchFailedEquality() {
        let error1 = PersistenceError.fetchFailed(entityName: "Entity", reason: "Reason")
        let error2 = PersistenceError.fetchFailed(entityName: "Entity", reason: "Reason")
        let error3 = PersistenceError.fetchFailed(entityName: "Other", reason: "Reason")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testEntityNotFoundEquality() {
        let error1 = PersistenceError.entityNotFound(entityName: "Entity", identifier: "123")
        let error2 = PersistenceError.entityNotFound(entityName: "Entity", identifier: "123")
        let error3 = PersistenceError.entityNotFound(entityName: "Entity", identifier: "456")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testValidationFailedEquality() {
        let error1 = PersistenceError.validationFailed(entityName: "E", field: "f", reason: "r")
        let error2 = PersistenceError.validationFailed(entityName: "E", field: "f", reason: "r")
        let error3 = PersistenceError.validationFailed(entityName: "E", field: "other", reason: "r")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - LocalizedError Tests

    func testContainerCreationFailedDescription() {
        let error = PersistenceError.containerCreationFailed("Schema mismatch")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to create persistence container: Schema mismatch"
        )
        XCTAssertNotNil(error.failureReason)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testContainerUnavailableDescription() {
        let error = PersistenceError.containerUnavailable

        XCTAssertEqual(
            error.errorDescription,
            "Persistence container is not available"
        )
    }

    func testFetchFailedDescription() {
        let error = PersistenceError.fetchFailed(entityName: "PodcastFeed", reason: "Invalid predicate")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to fetch PodcastFeed: Invalid predicate"
        )
    }

    func testEntityNotFoundDescription() {
        let error = PersistenceError.entityNotFound(entityName: "PodcastEpisode", identifier: "ep-123")

        XCTAssertEqual(
            error.errorDescription,
            "PodcastEpisode with identifier 'ep-123' was not found"
        )
    }

    func testSaveFailedDescription() {
        let error = PersistenceError.saveFailed(reason: "Disk full")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to save changes: Disk full"
        )
    }

    func testInsertFailedDescription() {
        let error = PersistenceError.insertFailed(entityName: "Preference", reason: "Duplicate key")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to insert Preference: Duplicate key"
        )
    }

    func testDeleteFailedDescription() {
        let error = PersistenceError.deleteFailed(entityName: "WorkoutSession", reason: "Object in use")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to delete WorkoutSession: Object in use"
        )
    }

    func testUpdateFailedDescription() {
        let error = PersistenceError.updateFailed(entityName: "WorkoutTrackPoint", reason: "Conflict")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to update WorkoutTrackPoint: Conflict"
        )
    }

    func testValidationFailedDescription() {
        let error = PersistenceError.validationFailed(
            entityName: "Preference",
            field: "name",
            reason: "Cannot be empty"
        )

        XCTAssertEqual(
            error.errorDescription,
            "Validation failed for Preference.name: Cannot be empty"
        )
    }

    func testMissingRelationshipDescription() {
        let error = PersistenceError.missingRelationship(
            entityName: "PodcastEpisode",
            relationshipName: "feed"
        )

        XCTAssertEqual(
            error.errorDescription,
            "PodcastEpisode is missing required relationship 'feed'"
        )
    }

    func testContextMismatchDescription() {
        let error = PersistenceError.contextMismatch

        XCTAssertEqual(
            error.errorDescription,
            "Object belongs to a different model context"
        )
    }

    func testInvalidObjectDescription() {
        let error = PersistenceError.invalidObject

        XCTAssertEqual(
            error.errorDescription,
            "Operation attempted on an invalid or deleted object"
        )
    }

    func testMigrationFailedDescription() {
        let error = PersistenceError.migrationFailed(reason: "Schema version mismatch")

        XCTAssertEqual(
            error.errorDescription,
            "Data migration failed: Schema version mismatch"
        )
    }

    func testUnknownDescription() {
        let error = PersistenceError.unknown("Unexpected condition")

        XCTAssertEqual(
            error.errorDescription,
            "An unknown persistence error occurred: Unexpected condition"
        )
    }

    // MARK: - DebugDescription Tests

    func testContainerCreationFailedDebugDescription() {
        let error = PersistenceError.containerCreationFailed("Test")

        XCTAssertEqual(
            error.debugDescription,
            "PersistenceError.containerCreationFailed(Test)"
        )
    }

    func testFetchFailedDebugDescription() {
        let error = PersistenceError.fetchFailed(entityName: "E", reason: "R")

        XCTAssertEqual(
            error.debugDescription,
            "PersistenceError.fetchFailed(entityName: \"E\", reason: \"R\")"
        )
    }

    func testEntityNotFoundDebugDescription() {
        let error = PersistenceError.entityNotFound(entityName: "E", identifier: "123")

        XCTAssertEqual(
            error.debugDescription,
            "PersistenceError.entityNotFound(entityName: \"E\", identifier: \"123\")"
        )
    }

    func testValidationFailedDebugDescription() {
        let error = PersistenceError.validationFailed(entityName: "E", field: "f", reason: "r")

        XCTAssertEqual(
            error.debugDescription,
            "PersistenceError.validationFailed(entityName: \"E\", field: \"f\", reason: \"r\")"
        )
    }

    // MARK: - Recovery Suggestion Tests

    func testAllErrorsHaveRecoverySuggestions() {
        let errors: [PersistenceError] = [
            .containerCreationFailed("test"),
            .containerUnavailable,
            .fetchFailed(entityName: "E", reason: "R"),
            .entityNotFound(entityName: "E", identifier: "id"),
            .saveFailed(reason: "R"),
            .insertFailed(entityName: "E", reason: "R"),
            .deleteFailed(entityName: "E", reason: "R"),
            .updateFailed(entityName: "E", reason: "R"),
            .validationFailed(entityName: "E", field: "f", reason: "R"),
            .missingRelationship(entityName: "E", relationshipName: "r"),
            .contextMismatch,
            .invalidObject,
            .migrationFailed(reason: "R"),
            .unknown("test")
        ]

        for error in errors {
            XCTAssertNotNil(error.recoverySuggestion, "Missing recovery suggestion for \(error)")
            XCTAssertFalse(error.recoverySuggestion!.isEmpty, "Empty recovery suggestion for \(error)")
        }
    }

    // MARK: - Sendable Tests

    func testErrorIsSendable() async {
        let error = PersistenceError.fetchFailed(entityName: "Test", reason: "Reason")

        // This compiles and runs successfully if PersistenceError is Sendable
        await Task {
            let capturedError = error
            XCTAssertNotNil(capturedError.errorDescription)
        }.value
    }
}
