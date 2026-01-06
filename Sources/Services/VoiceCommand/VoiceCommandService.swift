//
//  VoiceCommandService.swift
//  JogPod
//
//  Voice command recognition service using Apple's Speech framework.
//  Replaces the legacy OpenEars/Pocketsphinx implementation.
//

import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - VoiceCommandService

/// Voice command recognition service using Apple's Speech framework.
///
/// This service provides hands-free voice control during workouts, replacing
/// the legacy OpenEars/Pocketsphinx implementation with Apple's modern
/// Speech framework.
///
/// ## Feature Comparison with Legacy Implementation
///
/// | Feature                    | Legacy (OpenEars)  | Modern (Speech)        |
/// |----------------------------|--------------------|------------------------|
/// | Offline recognition        | Always             | iOS 13+ with Neural Engine |
/// | Recognition accuracy       | Good               | Excellent              |
/// | Custom vocabulary          | Required setup     | Contextual strings     |
/// | Language support           | English, Spanish   | 50+ languages          |
/// | Privacy                    | Fully on-device    | Configurable           |
///
/// ## Offline Recognition (iOS 13+)
///
/// Apple's on-device speech recognition provides offline capability similar
/// to the legacy OpenEars implementation. However, on-device recognition:
///
/// - Requires iOS 13.0 or later
/// - Requires a device with Neural Engine (A12 Bionic or later)
/// - May not be available for all locales
///
/// When on-device recognition is unavailable, the service falls back to
/// server-based recognition (requires network). Use `requireOnDeviceRecognition`
/// in configuration to enforce offline-only operation.
///
/// ## Usage
///
/// ```swift
/// let service = VoiceCommandService()
///
/// // Request authorization
/// try await service.requestAuthorization()
///
/// // Subscribe to commands
/// service.commandPublisher
///     .sink { result in
///         handleCommand(result.command)
///     }
///     .store(in: &cancellables)
///
/// // Start listening
/// try await service.startListening()
///
/// // Stop when done
/// await service.stopListening()
/// ```
///
/// ## Thread Safety
///
/// This class is an actor, ensuring all operations are serialized and thread-safe.
///
public actor VoiceCommandService: VoiceCommandServiceProtocol {

    // MARK: - Properties

    /// The current configuration.
    public private(set) var configuration: VoiceCommandConfiguration

    /// Whether the service is currently listening.
    public private(set) var isListening: Bool = false

    /// The speech recognizer.
    private var speechRecognizer: SFSpeechRecognizer?

    /// The current recognition request.
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// The current recognition task.
    private var recognitionTask: SFSpeechRecognitionTask?

    /// The audio engine for capturing microphone input.
    private let audioEngine: AVAudioEngine

    /// The audio session.
    private let audioSession: AVAudioSession

    /// The command parser.
    private var parser: VoiceCommandParser

    /// Subject for publishing recognized commands.
    private let commandSubject = PassthroughSubject<VoiceCommandResult, Never>()

    /// Subject for publishing state changes.
    private let stateSubject = CurrentValueSubject<VoiceCommandServiceState, Never>(.idle)

    /// Subject for publishing errors.
    private let errorSubject = PassthroughSubject<VoiceCommandError, Never>()

    /// The delegate for event callbacks.
    public weak var delegate: VoiceCommandDelegate?

    /// Timestamp of last recognized command (for debouncing).
    private var lastCommandTimestamp: Date?

    /// Minimum interval between command recognitions (debounce).
    private let commandDebounceInterval: TimeInterval = 1.0

    // MARK: - Publishers

    public nonisolated var commandPublisher: AnyPublisher<VoiceCommandResult, Never> {
        commandSubject.eraseToAnyPublisher()
    }

    public nonisolated var statePublisher: AnyPublisher<VoiceCommandServiceState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public nonisolated var errorPublisher: AnyPublisher<VoiceCommandError, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    /// Creates a new voice command service with the specified configuration.
    ///
    /// - Parameters:
    ///   - configuration: The service configuration. Defaults to `.default`.
    ///   - audioSession: The audio session to use. Defaults to shared instance.
    public init(
        configuration: VoiceCommandConfiguration = .default,
        audioSession: AVAudioSession = .sharedInstance()
    ) {
        self.configuration = configuration
        self.audioSession = audioSession
        self.audioEngine = AVAudioEngine()
        self.parser = VoiceCommandParser(configuration: configuration)

        // Initialize speech recognizer for configured locale
        self.speechRecognizer = SFSpeechRecognizer(locale: configuration.locale)
    }

    // MARK: - Authorization

    public var authorizationStatus: VoiceCommandAuthorizationStatus {
        get async {
            let speechStatus = SFSpeechRecognizer.authorizationStatus()
            let microphoneStatus = AVAudioApplication.shared.recordPermission

            switch (speechStatus, microphoneStatus) {
            case (.authorized, .granted):
                return .authorized
            case (.notDetermined, _), (_, .undetermined):
                return .notDetermined
            case (.denied, .denied):
                return .denied(reason: .both)
            case (.denied, _):
                return .denied(reason: .speechRecognition)
            case (_, .denied):
                return .denied(reason: .microphone)
            case (.restricted, _):
                return .restricted
            default:
                return .notDetermined
            }
        }
    }

    @discardableResult
    public func requestAuthorization() async throws -> VoiceCommandAuthorizationStatus {
        // Request speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            switch speechStatus {
            case .denied:
                throw VoiceCommandError.speechRecognitionDenied
            case .restricted:
                throw VoiceCommandError.speechRecognitionRestricted
            case .notDetermined:
                throw VoiceCommandError.speechRecognitionNotDetermined
            default:
                throw VoiceCommandError.speechRecognitionDenied
            }
        }

        // Request microphone authorization
        let microphoneGranted = await AVAudioApplication.requestRecordPermission()

        guard microphoneGranted else {
            throw VoiceCommandError.microphoneAccessDenied
        }

        return .authorized
    }

    // MARK: - Lifecycle

    public func startListening() async throws {
        // Check if already listening
        guard !isListening else {
            throw VoiceCommandError.alreadyListening
        }

        // Update state
        updateState(.starting)

        // Check authorization
        let status = await authorizationStatus
        guard status.isAuthorized else {
            updateState(.error(.speechRecognitionDenied))
            throw VoiceCommandError.speechRecognitionDenied
        }

        // Check speech recognizer availability
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            let error = VoiceCommandError.speechRecognitionUnavailable
            updateState(.error(error))
            throw error
        }

        // Check on-device availability if required
        if configuration.requireOnDeviceRecognition {
            if !recognizer.supportsOnDeviceRecognition {
                let error = VoiceCommandError.onDeviceRecognitionUnavailable
                updateState(.error(error))
                throw error
            }
        }

        // Configure audio session
        do {
            try configureAudioSession()
        } catch {
            let commandError = VoiceCommandError.audioSessionConfigurationFailed(
                reason: error.localizedDescription
            )
            updateState(.error(commandError))
            throw commandError
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = configuration.usePartialResults

        // Configure on-device recognition if available
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = configuration.requireOnDeviceRecognition
        }

        // Add contextual strings to improve accuracy
        if configuration.useContextualStrings {
            request.contextualStrings = configuration.allPhrases().map { $0.phrase }
        }

        // Configure task hint
        switch configuration.taskHint {
        case .unspecified:
            request.taskHint = .unspecified
        case .dictation:
            request.taskHint = .dictation
        case .search:
            request.taskHint = .search
        case .userInitiated, .background:
            request.taskHint = .unspecified
        }

        self.recognitionRequest = request

        // Start recognition task
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { [weak self] in
                await self?.handleRecognitionResult(result: result, error: error)
            }
        }

        self.recognitionTask = task

        // Start audio engine
        do {
            try startAudioEngine()
        } catch {
            // Clean up on failure
            task.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil

            let commandError = VoiceCommandError.audioEngineStartFailed(
                reason: error.localizedDescription
            )
            updateState(.error(commandError))
            throw commandError
        }

        isListening = true
        updateState(.listening)
    }

    public func stopListening() async {
        guard isListening else {
            return
        }

        updateState(.stopping)

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Cancel recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Clean up
        recognitionRequest = nil
        recognitionTask = nil

        // Deactivate audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        isListening = false
        updateState(.idle)
    }

    // MARK: - Configuration

    public func updateConfiguration(_ newConfiguration: VoiceCommandConfiguration) async {
        let wasListening = isListening

        // Stop if listening
        if wasListening {
            await stopListening()
        }

        // Update configuration
        configuration = newConfiguration
        parser = VoiceCommandParser(configuration: newConfiguration)

        // Reinitialize speech recognizer if locale changed
        speechRecognizer = SFSpeechRecognizer(locale: newConfiguration.locale)

        // Restart if was listening
        if wasListening {
            try? await startListening()
        }
    }

    // MARK: - Capability Queries

    public var isOnDeviceRecognitionAvailable: Bool {
        get async {
            speechRecognizer?.supportsOnDeviceRecognition ?? false
        }
    }

    public var isRecognitionAvailableForLocale: Bool {
        get async {
            speechRecognizer?.isAvailable ?? false
        }
    }

    // MARK: - Private Methods

    private func configureAudioSession() throws {
        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: [.duckOthers, .allowBluetooth]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // Handle errors
        if let error = error {
            let nsError = error as NSError

            // Check for cancellation
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                // Recognition was cancelled - this is expected when stopping
                return
            }

            let commandError = VoiceCommandError.recognitionFailed(reason: error.localizedDescription)
            publishError(commandError)

            // Restart listening on recoverable errors
            if !isListening {
                return
            }

            Task {
                await stopListening()
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                try? await startListening()
            }
            return
        }

        // Process result
        guard let result = result else {
            return
        }

        // Update state to processing
        if isListening && stateSubject.value == .listening {
            updateState(.processing)
        }

        // Get transcription
        let transcription = result.bestTranscription.formattedString
        let confidence = result.bestTranscription.segments.last?.confidence ?? 0.5

        // Parse command
        if let commandResult = parser.parse(transcription: transcription, confidence: confidence) {
            // Check confidence threshold
            if commandResult.confidence >= configuration.confidenceThreshold {
                // Debounce: prevent same command from firing multiple times
                if shouldAcceptCommand(commandResult) {
                    lastCommandTimestamp = Date()
                    publishCommand(commandResult)
                }
            }
        }

        // If final result, return to listening state
        if result.isFinal && isListening {
            updateState(.listening)
        }
    }

    private func shouldAcceptCommand(_ result: VoiceCommandResult) -> Bool {
        guard let lastTimestamp = lastCommandTimestamp else {
            return true
        }

        return result.timestamp.timeIntervalSince(lastTimestamp) >= commandDebounceInterval
    }

    private func publishCommand(_ result: VoiceCommandResult) {
        commandSubject.send(result)

        // Notify delegate
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.voiceCommandService(self, didRecognizeCommand: result)
        }

        // Provide feedback if enabled
        if configuration.enableAudioFeedback || configuration.enableHapticFeedback {
            Task { @MainActor in
                self.provideFeedback()
            }
        }

        #if DEBUG
        print("VoiceCommandService: Recognized '\(result.command.rawValue)' (confidence: \(result.confidence))")
        #endif
    }

    private func publishError(_ error: VoiceCommandError) {
        errorSubject.send(error)

        // Notify delegate
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.voiceCommandService(self, didEncounterError: error)
        }
    }

    private func updateState(_ state: VoiceCommandServiceState) {
        stateSubject.send(state)

        // Notify delegate
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.voiceCommandService(self, didChangeState: state)
        }
    }

    @MainActor
    private func provideFeedback() {
        if configuration.enableHapticFeedback {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }

        // Audio feedback would be handled by a separate audio service
        // to avoid interfering with speech recognition
    }
}

// MARK: - Convenience Factory Methods

public extension VoiceCommandService {

    /// Creates a voice command service configured for outdoor workout use.
    static func forOutdoorWorkout() -> VoiceCommandService {
        VoiceCommandService(configuration: .outdoor)
    }

    /// Creates a voice command service configured for offline-only operation.
    ///
    /// - Warning: This will fail on devices that don't support on-device recognition.
    static func offlineOnly() -> VoiceCommandService {
        VoiceCommandService(configuration: .offlineOnly)
    }
}

// MARK: - UIKit Dependency

#if canImport(UIKit)
import UIKit
#endif
