//
//  MockVoiceCommandService.swift
//  JogPodTests
//
//  Mock implementation of VoiceCommandServiceProtocol for testing.
//

import Foundation
import Combine
@testable import JogPod

/// Mock voice command service for unit testing.
///
/// This mock enables testing of voice command handling without requiring:
/// - Microphone access
/// - Speech recognition authorization
/// - Audio engine initialization
///
/// ## Usage
///
/// ```swift
/// let mockService = MockVoiceCommandService()
///
/// // Simulate authorization
/// mockService.mockAuthorizationStatus = .authorized
///
/// // Start listening
/// try await mockService.startListening()
///
/// // Simulate a command
/// mockService.simulateCommand(.play, confidence: 0.9)
///
/// // Verify handler was called
/// XCTAssertEqual(receivedCommand, .play)
/// ```
///
public actor MockVoiceCommandService: VoiceCommandServiceProtocol {

    // MARK: - Mock State

    /// The authorization status to return.
    public var mockAuthorizationStatus: VoiceCommandAuthorizationStatus = .authorized

    /// Whether on-device recognition is available.
    public var mockOnDeviceAvailable: Bool = true

    /// Whether recognition is available for the locale.
    public var mockRecognitionAvailable: Bool = true

    /// Error to throw on startListening.
    public var startListeningError: VoiceCommandError?

    /// Error to throw on requestAuthorization.
    public var requestAuthorizationError: VoiceCommandError?

    /// Track method calls for verification.
    public private(set) var startListeningCallCount = 0
    public private(set) var stopListeningCallCount = 0
    public private(set) var requestAuthorizationCallCount = 0

    // MARK: - Protocol Properties

    public private(set) var isListening: Bool = false
    public private(set) var configuration: VoiceCommandConfiguration

    private let commandSubject = PassthroughSubject<VoiceCommandResult, Never>()
    private let stateSubject = CurrentValueSubject<VoiceCommandServiceState, Never>(.idle)
    private let errorSubject = PassthroughSubject<VoiceCommandError, Never>()

    public nonisolated var commandPublisher: AnyPublisher<VoiceCommandResult, Never> {
        commandSubject.eraseToAnyPublisher()
    }

    public nonisolated var statePublisher: AnyPublisher<VoiceCommandServiceState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public nonisolated var errorPublisher: AnyPublisher<VoiceCommandError, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    public var authorizationStatus: VoiceCommandAuthorizationStatus {
        get async { mockAuthorizationStatus }
    }

    public var isOnDeviceRecognitionAvailable: Bool {
        get async { mockOnDeviceAvailable }
    }

    public var isRecognitionAvailableForLocale: Bool {
        get async { mockRecognitionAvailable }
    }

    // MARK: - Initialization

    public init(configuration: VoiceCommandConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Protocol Methods

    @discardableResult
    public func requestAuthorization() async throws -> VoiceCommandAuthorizationStatus {
        requestAuthorizationCallCount += 1

        if let error = requestAuthorizationError {
            throw error
        }

        return mockAuthorizationStatus
    }

    public func startListening() async throws {
        startListeningCallCount += 1

        if let error = startListeningError {
            stateSubject.send(.error(error))
            throw error
        }

        guard mockAuthorizationStatus == .authorized else {
            let error = VoiceCommandError.speechRecognitionDenied
            stateSubject.send(.error(error))
            throw error
        }

        isListening = true
        stateSubject.send(.listening)
    }

    public func stopListening() async {
        stopListeningCallCount += 1
        isListening = false
        stateSubject.send(.idle)
    }

    public func updateConfiguration(_ configuration: VoiceCommandConfiguration) async {
        self.configuration = configuration
    }

    // MARK: - Simulation Methods

    /// Simulates receiving a voice command.
    ///
    /// - Parameters:
    ///   - command: The command to simulate.
    ///   - confidence: The confidence level. Defaults to 0.9.
    ///   - transcription: The transcription text. Defaults to the command's default phrase.
    public func simulateCommand(
        _ command: VoiceCommand,
        confidence: Float = 0.9,
        transcription: String? = nil
    ) {
        let result = VoiceCommandResult(
            command: command,
            confidence: confidence,
            transcription: transcription ?? command.defaultPhrase
        )

        stateSubject.send(.processing)
        commandSubject.send(result)
        stateSubject.send(.listening)
    }

    /// Simulates an error during recognition.
    ///
    /// - Parameter error: The error to simulate.
    public func simulateError(_ error: VoiceCommandError) {
        stateSubject.send(.error(error))
        errorSubject.send(error)
    }

    /// Simulates a state change.
    ///
    /// - Parameter state: The state to transition to.
    public func simulateStateChange(_ state: VoiceCommandServiceState) {
        stateSubject.send(state)
    }

    /// Resets all mock state and call counts.
    public func reset() {
        isListening = false
        startListeningCallCount = 0
        stopListeningCallCount = 0
        requestAuthorizationCallCount = 0
        startListeningError = nil
        requestAuthorizationError = nil
        mockAuthorizationStatus = .authorized
        stateSubject.send(.idle)
    }
}
