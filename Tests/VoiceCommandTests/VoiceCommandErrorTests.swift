//
//  VoiceCommandErrorTests.swift
//  JogPodTests
//
//  Unit tests for VoiceCommandError.
//

import XCTest
@testable import JogPod

final class VoiceCommandErrorTests: XCTestCase {

    // MARK: - LocalizedError Tests

    func testErrorDescriptions() {
        // All errors should have descriptions
        let errors: [VoiceCommandError] = [
            .speechRecognitionDenied,
            .speechRecognitionNotDetermined,
            .speechRecognitionRestricted,
            .microphoneAccessDenied,
            .microphoneAccessNotDetermined,
            .speechRecognitionUnavailable,
            .onDeviceRecognitionUnavailable,
            .networkRequired,
            .localeNotSupported(locale: "xx-XX"),
            .audioEngineStartFailed(reason: "test"),
            .audioSessionConfigurationFailed(reason: "test"),
            .recognitionCancelled,
            .recognitionTimeout,
            .recognitionFailed(reason: "test"),
            .recognitionRequestFailed(reason: "test"),
            .noSpeechDetected,
            .alreadyListening,
            .notListening,
            .serviceDeallocated
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have errorDescription")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) errorDescription should not be empty")
        }
    }

    // MARK: - Recovery Suggestion Tests

    func testAuthorizationErrorsHaveRecoverySuggestions() {
        let authErrors: [VoiceCommandError] = [
            .speechRecognitionDenied,
            .speechRecognitionNotDetermined,
            .speechRecognitionRestricted,
            .microphoneAccessDenied,
            .microphoneAccessNotDetermined
        ]

        for error in authErrors {
            XCTAssertNotNil(error.recoverySuggestion, "\(error) should have recovery suggestion")
        }
    }

    // MARK: - RequiresUserAction Tests

    func testRequiresUserAction_Authorization() {
        XCTAssertTrue(VoiceCommandError.speechRecognitionDenied.requiresUserAction)
        XCTAssertTrue(VoiceCommandError.speechRecognitionRestricted.requiresUserAction)
        XCTAssertTrue(VoiceCommandError.microphoneAccessDenied.requiresUserAction)
    }

    func testRequiresUserAction_Runtime() {
        XCTAssertFalse(VoiceCommandError.recognitionFailed(reason: "test").requiresUserAction)
        XCTAssertFalse(VoiceCommandError.recognitionTimeout.requiresUserAction)
        XCTAssertFalse(VoiceCommandError.noSpeechDetected.requiresUserAction)
    }

    // MARK: - IsRetryable Tests

    func testIsRetryable_RetryableErrors() {
        XCTAssertTrue(VoiceCommandError.audioEngineStartFailed(reason: "test").isRetryable)
        XCTAssertTrue(VoiceCommandError.recognitionFailed(reason: "test").isRetryable)
        XCTAssertTrue(VoiceCommandError.recognitionRequestFailed(reason: "test").isRetryable)
        XCTAssertTrue(VoiceCommandError.recognitionTimeout.isRetryable)
        XCTAssertTrue(VoiceCommandError.noSpeechDetected.isRetryable)
        XCTAssertTrue(VoiceCommandError.networkRequired.isRetryable)
    }

    func testIsRetryable_NonRetryableErrors() {
        XCTAssertFalse(VoiceCommandError.speechRecognitionDenied.isRetryable)
        XCTAssertFalse(VoiceCommandError.speechRecognitionRestricted.isRetryable)
        XCTAssertFalse(VoiceCommandError.speechRecognitionUnavailable.isRetryable)
    }

    // MARK: - IsPermanent Tests

    func testIsPermanent_PermanentErrors() {
        XCTAssertTrue(VoiceCommandError.speechRecognitionRestricted.isPermanent)
        XCTAssertTrue(VoiceCommandError.speechRecognitionUnavailable.isPermanent)
        XCTAssertTrue(VoiceCommandError.localeNotSupported(locale: "xx-XX").isPermanent)
    }

    func testIsPermanent_NonPermanentErrors() {
        XCTAssertFalse(VoiceCommandError.speechRecognitionDenied.isPermanent)
        XCTAssertFalse(VoiceCommandError.networkRequired.isPermanent)
        XCTAssertFalse(VoiceCommandError.recognitionFailed(reason: "test").isPermanent)
    }

    // MARK: - Equality Tests

    func testEquality_SameCase() {
        XCTAssertEqual(
            VoiceCommandError.speechRecognitionDenied,
            VoiceCommandError.speechRecognitionDenied
        )
    }

    func testEquality_SameCaseWithSamePayload() {
        XCTAssertEqual(
            VoiceCommandError.localeNotSupported(locale: "xx-XX"),
            VoiceCommandError.localeNotSupported(locale: "xx-XX")
        )
    }

    func testEquality_SameCaseWithDifferentPayload() {
        XCTAssertNotEqual(
            VoiceCommandError.localeNotSupported(locale: "xx-XX"),
            VoiceCommandError.localeNotSupported(locale: "yy-YY")
        )
    }

    func testEquality_DifferentCase() {
        XCTAssertNotEqual(
            VoiceCommandError.speechRecognitionDenied,
            VoiceCommandError.microphoneAccessDenied
        )
    }
}
