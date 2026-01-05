import XCTest
@testable import JogPod

/// Unit tests for MigrationError type.
final class MigrationErrorTests: XCTestCase {

    // MARK: - LocalizedError Tests

    func testStoreNotFoundHasLocalizedDescription() {
        let error = MigrationError.storeNotFound(path: "/path/to/store.sqlite")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("/path/to/store.sqlite") ?? false)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testStoreAccessFailedHasUnderlyingError() {
        let underlyingError = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError,
            userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
        )
        let error = MigrationError.storeAccessFailed(
            path: "/path/to/store.sqlite",
            underlyingError: underlyingError
        )

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(error.failureReason?.contains("Permission denied") ?? false)
    }

    func testModelLoadFailedContainsReason() {
        let error = MigrationError.modelLoadFailed(reason: "Invalid schema version")

        XCTAssertTrue(error.errorDescription?.contains("Invalid schema version") ?? false)
    }

    func testFetchFailedContainsEntityName() {
        let underlyingError = NSError(domain: "CoreData", code: 1, userInfo: nil)
        let error = MigrationError.fetchFailed(
            entityName: "RSSEntity",
            underlyingError: underlyingError
        )

        XCTAssertTrue(error.errorDescription?.contains("RSSEntity") ?? false)
        XCTAssertNotNil(error.failureReason)
    }

    func testMissingRequiredAttributeDetails() {
        let error = MigrationError.missingRequiredAttribute(
            entityName: "WorkoutSession",
            attributeName: "workoutID",
            objectID: "x-coredata://ABC123"
        )

        XCTAssertTrue(error.errorDescription?.contains("WorkoutSession") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("workoutID") ?? false)
    }

    func testTransformableDecodeFailedDetails() {
        let error = MigrationError.transformableDecodeFailed(
            entityName: "WorkoutLocation",
            attributeName: "location",
            objectID: nil
        )

        XCTAssertTrue(error.errorDescription?.contains("WorkoutLocation") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("location") ?? false)
    }

    func testRelationshipResolutionFailedDetails() {
        let error = MigrationError.relationshipResolutionFailed(
            sourceEntity: "RSSEntry",
            relationshipName: "belongsTo",
            targetEntity: "RSSEntity",
            reason: "Target not found"
        )

        XCTAssertTrue(error.errorDescription?.contains("RSSEntry") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("belongsTo") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("RSSEntity") ?? false)
        XCTAssertEqual(error.failureReason, "Target not found")
    }

    func testInsuffientStorageFormatsBytes() {
        let error = MigrationError.insufficientStorage(
            required: 1_073_741_824, // 1 GB
            available: 536_870_912   // 512 MB
        )

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testValidationFailedCountsIssues() {
        let issues = [
            MigrationError.ValidationIssue(
                entityName: "Feed1",
                attributeName: nil,
                objectIdentifier: nil,
                message: "Issue 1"
            ),
            MigrationError.ValidationIssue(
                entityName: "Feed2",
                attributeName: nil,
                objectIdentifier: nil,
                message: "Issue 2"
            )
        ]
        let error = MigrationError.validationFailed(issues: issues)

        XCTAssertTrue(error.errorDescription?.contains("2 issues") ?? false)
    }

    func testValidationFailedSingleIssueGrammar() {
        let issues = [
            MigrationError.ValidationIssue(
                entityName: "Feed",
                attributeName: nil,
                objectIdentifier: nil,
                message: "Single issue"
            )
        ]
        let error = MigrationError.validationFailed(issues: issues)

        XCTAssertTrue(error.errorDescription?.contains("1 issue") ?? false)
        XCTAssertFalse(error.errorDescription?.contains("issues") ?? true)
    }

    func testCountMismatchDetails() {
        let error = MigrationError.countMismatch(
            entityName: "PodcastFeed",
            expected: 10,
            actual: 5
        )

        XCTAssertTrue(error.errorDescription?.contains("PodcastFeed") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("10") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("5") ?? false)
    }

    // MARK: - Equatable Tests

    func testStoreNotFoundEquality() {
        let error1 = MigrationError.storeNotFound(path: "/path/a")
        let error2 = MigrationError.storeNotFound(path: "/path/a")
        let error3 = MigrationError.storeNotFound(path: "/path/b")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testCancelledEquality() {
        let error1 = MigrationError.cancelled
        let error2 = MigrationError.cancelled

        XCTAssertEqual(error1, error2)
    }

    func testAlreadyInProgressEquality() {
        let error1 = MigrationError.alreadyInProgress
        let error2 = MigrationError.alreadyInProgress

        XCTAssertEqual(error1, error2)
    }

    func testInvalidStateEquality() {
        let error1 = MigrationError.invalidState(expected: "idle", actual: "running")
        let error2 = MigrationError.invalidState(expected: "idle", actual: "running")
        let error3 = MigrationError.invalidState(expected: "idle", actual: "completed")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testInsufficientStorageEquality() {
        let error1 = MigrationError.insufficientStorage(required: 100, available: 50)
        let error2 = MigrationError.insufficientStorage(required: 100, available: 50)
        let error3 = MigrationError.insufficientStorage(required: 200, available: 50)

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testCountMismatchEquality() {
        let error1 = MigrationError.countMismatch(entityName: "Feed", expected: 10, actual: 5)
        let error2 = MigrationError.countMismatch(entityName: "Feed", expected: 10, actual: 5)
        let error3 = MigrationError.countMismatch(entityName: "Feed", expected: 10, actual: 8)

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - ValidationIssue Tests

    func testValidationIssueDescription() {
        let issue = MigrationError.ValidationIssue(
            entityName: "WorkoutSession",
            attributeName: "workoutID",
            objectIdentifier: "ABC123",
            message: "Value is empty"
        )

        let description = issue.description
        XCTAssertTrue(description.contains("WorkoutSession"))
        XCTAssertTrue(description.contains("workoutID"))
        XCTAssertTrue(description.contains("ABC123"))
        XCTAssertTrue(description.contains("Value is empty"))
    }

    func testValidationIssueDescriptionWithoutOptionals() {
        let issue = MigrationError.ValidationIssue(
            entityName: "PodcastFeed",
            attributeName: nil,
            objectIdentifier: nil,
            message: "Generic issue"
        )

        let description = issue.description
        XCTAssertTrue(description.contains("PodcastFeed"))
        XCTAssertTrue(description.contains("Generic issue"))
        XCTAssertFalse(description.contains("ID:"))
    }

    // MARK: - Convenience Factory Tests

    func testMissingRelationshipTargetFactory() {
        let error = MigrationError.missingRelationshipTarget(
            source: "RSSEntry",
            relationship: "belongsTo",
            targetEntity: "RSSEntity",
            targetID: "feed-123"
        )

        if case .relationshipResolutionFailed(let source, let rel, let target, let reason) = error {
            XCTAssertEqual(source, "RSSEntry")
            XCTAssertEqual(rel, "belongsTo")
            XCTAssertEqual(target, "RSSEntity")
            XCTAssertTrue(reason.contains("feed-123"))
        } else {
            XCTFail("Expected relationshipResolutionFailed")
        }
    }

    // MARK: - Recovery Suggestion Tests

    func testStoreNotFoundRecoverySuggestion() {
        let error = MigrationError.storeNotFound(path: "/path")
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion?.contains("legacy") ?? false)
    }

    func testStoreCorruptedRecoverySuggestion() {
        let error = MigrationError.storeCorrupted(path: "/path", details: "Bad header")
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion?.contains("backup") ?? false)
    }

    func testInsufficientStorageRecoverySuggestion() {
        let error = MigrationError.insufficientStorage(required: 100, available: 50)
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion?.lowercased().contains("storage") ?? false)
    }

    func testAlreadyInProgressRecoverySuggestion() {
        let error = MigrationError.alreadyInProgress
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion?.contains("Wait") ?? false)
    }

    func testCancelledRecoverySuggestion() {
        let error = MigrationError.cancelled
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion?.contains("Restart") ?? false)
    }

    func testRollbackFailedRecoverySuggestion() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: nil)
        let error = MigrationError.rollbackFailed(underlyingError: underlyingError)
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion?.contains("support") ?? false)
    }
}
