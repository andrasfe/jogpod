//
//  SpeechService.swift
//  JogPod
//
//  Modern speech synthesis service using AVSpeechSynthesizer.
//  Replaces the legacy OpenEars FliteController implementation.
//

import Foundation
import AVFoundation

// MARK: - SpeechServiceDelegate

/// Delegate protocol for receiving speech service events.
public protocol SpeechServiceDelegate: AnyObject, Sendable {

    /// Called when speech synthesis starts.
    func speechServiceDidStartSpeaking(_ service: SpeechService)

    /// Called when speech synthesis finishes.
    func speechServiceDidFinishSpeaking(_ service: SpeechService)

    /// Called when speech synthesis is cancelled.
    func speechServiceDidCancelSpeaking(_ service: SpeechService)

    /// Called when an error occurs during speech synthesis.
    func speechService(_ service: SpeechService, didEncounterError error: SpeechError)
}

// MARK: - Default Delegate Implementation

public extension SpeechServiceDelegate {
    func speechServiceDidStartSpeaking(_ service: SpeechService) {}
    func speechServiceDidFinishSpeaking(_ service: SpeechService) {}
    func speechServiceDidCancelSpeaking(_ service: SpeechService) {}
    func speechService(_ service: SpeechService, didEncounterError error: SpeechError) {}
}

// MARK: - SpeechService

/// A modern speech synthesis service using AVSpeechSynthesizer.
///
/// This service provides text-to-speech functionality for workout announcements,
/// replacing the legacy OpenEars FliteController. It handles:
///
/// - Speech synthesis with configurable voice, rate, and volume
/// - Audio ducking to lower music/podcast volume during speech
/// - Speech queue serialization (no overlapping announcements)
/// - Background audio compatibility
///
/// ## Legacy Equivalence
///
/// This replaces the `JogTraceSpeech` singleton and `SpeechOperation` classes
/// from the legacy codebase. Key differences:
///
/// - Uses AVSpeechSynthesizer instead of FliteController
/// - Voice quality is improved (Siri voices vs Flite Slt)
/// - Audio ducking uses AVAudioSession instead of pausing media player
///
/// ## Usage
///
/// ```swift
/// let speechService = SpeechService()
///
/// // Configure
/// speechService.updateConfiguration { config in
///     config.rate = 0.5
///     config.enableAudioDucking = true
/// }
///
/// // Speak
/// await speechService.speak("Current speed 5.2 miles per hour")
/// ```
///
/// ## Thread Safety
///
/// This class is an actor, ensuring all operations are serialized and thread-safe.
public actor SpeechService: NSObject {

    // MARK: - Properties

    /// The current configuration.
    private var configuration: SpeechConfiguration

    /// The speech synthesizer.
    private let synthesizer: AVSpeechSynthesizer

    /// The audio session for ducking.
    private let audioSession: AVAudioSession

    /// Queue of pending utterances.
    private var utteranceQueue: [AVSpeechUtterance] = []

    /// Whether speech is currently in progress.
    private var isSpeaking: Bool = false

    /// Whether audio is currently ducked.
    private var isAudioDucked: Bool = false

    /// Continuation for async speak operations.
    private var speakContinuation: CheckedContinuation<Void, Error>?

    /// Delegate for speech events.
    public weak var delegate: SpeechServiceDelegate?

    /// The synthesizer delegate wrapper (required because AVSpeechSynthesizerDelegate is not Sendable).
    private var synthesizerDelegate: SynthesizerDelegate?

    // MARK: - Initialization

    /// Creates a new SpeechService with the specified configuration.
    ///
    /// - Parameters:
    ///   - configuration: The speech configuration. Defaults to `.default`.
    ///   - audioSession: The audio session to use. Defaults to shared instance.
    public init(
        configuration: SpeechConfiguration = .default,
        audioSession: AVAudioSession = .sharedInstance()
    ) {
        self.configuration = configuration
        self.synthesizer = AVSpeechSynthesizer()
        self.audioSession = audioSession

        super.init()

        // Set up delegate on MainActor to avoid Sendable issues
        Task { @MainActor in
            let delegate = SynthesizerDelegate(service: self)
            self.synthesizerDelegate = delegate
            self.synthesizer.delegate = delegate
        }
    }

    // MARK: - Configuration

    /// Updates the speech configuration.
    ///
    /// - Parameter update: A closure that modifies the configuration.
    public func updateConfiguration(_ update: (inout SpeechConfiguration) -> Void) {
        update(&configuration)
    }

    /// Returns the current configuration.
    public func getConfiguration() -> SpeechConfiguration {
        configuration
    }

    /// Sets whether speech is enabled.
    ///
    /// - Parameter enabled: Whether speech should be enabled.
    public func setEnabled(_ enabled: Bool) {
        configuration.isEnabled = enabled
    }

    /// Returns whether speech is enabled.
    public func isEnabled() -> Bool {
        configuration.isEnabled
    }

    // MARK: - Voice Management

    /// Returns all available voices for the configured language.
    ///
    /// - Returns: An array of VoiceInfo objects for available voices.
    public func availableVoices() -> [VoiceInfo] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: configuration.languageCode.prefix(2)) }
            .map { VoiceInfo(voice: $0) }
            .sorted { $0.quality > $1.quality }
    }

    /// Returns the currently selected voice, or the default voice if none is selected.
    ///
    /// - Returns: The current voice info, or nil if no voice is available.
    public func currentVoice() -> VoiceInfo? {
        if let identifier = configuration.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return VoiceInfo(voice: voice)
        }

        // Fall back to default voice for language
        if let voice = AVSpeechSynthesisVoice(language: configuration.languageCode) {
            return VoiceInfo(voice: voice)
        }

        return nil
    }

    /// Sets the voice to use for speech.
    ///
    /// - Parameter voiceIdentifier: The identifier of the voice to use.
    /// - Throws: `SpeechError.voiceNotFound` if the voice is not available.
    public func setVoice(_ voiceIdentifier: String) throws {
        guard AVSpeechSynthesisVoice(identifier: voiceIdentifier) != nil else {
            throw SpeechError.voiceNotFound(identifier: voiceIdentifier)
        }
        configuration.voiceIdentifier = voiceIdentifier
    }

    // MARK: - Speaking

    /// Speaks the given text.
    ///
    /// This method queues the text for speaking. If speech is disabled or the text
    /// is empty, the method returns immediately without speaking.
    ///
    /// The method waits for audio ducking to take effect before speaking, and
    /// restores audio levels after speech completes.
    ///
    /// - Parameter text: The text to speak.
    /// - Throws: `SpeechError` if speech fails.
    public func speak(_ text: String) async throws {
        // Check if enabled
        guard configuration.isEnabled else {
            throw SpeechError.speechDisabled
        }

        // Validate text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw SpeechError.emptyAnnouncement
        }

        // Create utterance
        let utterance = createUtterance(for: trimmedText)

        // Duck audio if enabled
        if configuration.enableAudioDucking {
            try await duckAudio()
        }

        // Speak and wait for completion
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.speakContinuation = continuation
            self.synthesizer.speak(utterance)
        }
    }

    /// Speaks the given text without throwing on errors.
    ///
    /// This is a convenience method that logs errors instead of throwing.
    /// Useful for fire-and-forget announcements.
    ///
    /// - Parameter text: The text to speak.
    public func speakSafely(_ text: String) async {
        do {
            try await speak(text)
        } catch {
            // Errors are handled via delegate
            #if DEBUG
            print("SpeechService: Failed to speak '\(text)': \(error)")
            #endif
        }
    }

    /// Stops any ongoing speech immediately.
    ///
    /// - Parameter boundary: Where to stop. Defaults to `.immediate`.
    public func stop(at boundary: AVSpeechBoundary = .immediate) {
        synthesizer.stopSpeaking(at: boundary)
        utteranceQueue.removeAll()

        // Restore audio if ducked
        if isAudioDucked {
            Task {
                await restoreAudio()
            }
        }

        // Cancel any pending continuation
        speakContinuation?.resume(throwing: CancellationError())
        speakContinuation = nil
    }

    /// Returns whether speech is currently in progress.
    public func isSpeechInProgress() -> Bool {
        isSpeaking
    }

    // MARK: - Convenience Speaking Methods

    /// Announces that workout monitoring was turned on or off.
    ///
    /// - Parameter on: Whether monitoring is on.
    public func sayWorkoutMonitoringTurned(_ on: Bool) async {
        let text = "Workout monitoring is \(on ? "on" : "off")"
        await speakSafely(text)
    }

    /// Announces that region monitoring was turned on or off.
    ///
    /// - Parameter on: Whether monitoring is on.
    public func sayRegionMonitoringTurned(_ on: Bool) async {
        let text = "Region monitoring is turned \(on ? "on" : "off")"
        await speakSafely(text)
    }

    /// Announces that speech recognition was turned on or off.
    ///
    /// - Parameter on: Whether recognition is on.
    public func saySpeechRecognitionTurned(_ on: Bool) async {
        let text = "Voice recognition is turned \(on ? "on" : "off")"
        await speakSafely(text)
    }

    // MARK: - Private Methods

    /// Creates an AVSpeechUtterance configured with current settings.
    private func createUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)

        // Set voice
        if let voiceId = configuration.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: configuration.languageCode)
        }

        // Set parameters
        utterance.rate = configuration.rate
        utterance.pitchMultiplier = configuration.pitchMultiplier
        utterance.volume = configuration.volume

        // Add slight pre/post delays for natural pacing
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        return utterance
    }

    /// Ducks other audio to make speech more audible.
    private func duckAudio() async throws {
        guard !isAudioDucked else { return }

        do {
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try audioSession.setActive(true)
            isAudioDucked = true

            // Wait for ducking to take effect
            if configuration.duckingDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(configuration.duckingDelay * 1_000_000_000))
            }
        } catch {
            throw SpeechError.audioDuckingFailed(reason: error.localizedDescription)
        }
    }

    /// Restores normal audio levels after speech.
    private func restoreAudio() async {
        guard isAudioDucked else { return }

        do {
            // Deactivate with notification to restore other audio
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isAudioDucked = false
        } catch {
            // Log but don't fail - audio restoration is best effort
            #if DEBUG
            print("SpeechService: Failed to restore audio: \(error)")
            #endif
            isAudioDucked = false
        }
    }

    // MARK: - Delegate Callbacks (called from SynthesizerDelegate)

    fileprivate func handleDidStart() {
        isSpeaking = true
        delegate?.speechServiceDidStartSpeaking(self)
    }

    fileprivate func handleDidFinish() {
        isSpeaking = false

        // Restore audio
        Task {
            await restoreAudio()
        }

        // Resume continuation
        speakContinuation?.resume()
        speakContinuation = nil

        delegate?.speechServiceDidFinishSpeaking(self)
    }

    fileprivate func handleDidCancel() {
        isSpeaking = false

        // Restore audio
        Task {
            await restoreAudio()
        }

        // Cancel continuation
        speakContinuation?.resume(throwing: CancellationError())
        speakContinuation = nil

        delegate?.speechServiceDidCancelSpeaking(self)
    }
}

// MARK: - SynthesizerDelegate

/// Internal delegate wrapper for AVSpeechSynthesizerDelegate.
///
/// This class bridges AVSpeechSynthesizerDelegate callbacks to the SpeechService actor.
@MainActor
private final class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {

    private weak var service: SpeechService?

    init(service: SpeechService) {
        self.service = service
        super.init()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task {
            await service?.handleDidStart()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task {
            await service?.handleDidFinish()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task {
            await service?.handleDidCancel()
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {

    /// Posted when speech synthesis starts.
    static let speechDidStart = Notification.Name("speechDidStart")

    /// Posted when speech synthesis finishes.
    static let speechDidFinish = Notification.Name("speechDidFinish")
}
