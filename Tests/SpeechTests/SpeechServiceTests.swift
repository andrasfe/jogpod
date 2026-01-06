//
//  SpeechServiceTests.swift
//  JogPodTests
//
//  Tests for SpeechService.
//

import Testing
import AVFoundation
@testable import JogPod

@Suite("SpeechService Tests")
struct SpeechServiceTests {

    @Test("Service initializes with default configuration")
    func testDefaultInitialization() async {
        let service = SpeechService()

        let config = await service.getConfiguration()
        #expect(config.isEnabled)
        #expect(config.languageCode == "en-US")
    }

    @Test("Service initializes with custom configuration")
    func testCustomInitialization() async {
        let config = SpeechConfiguration(
            isEnabled: false,
            rate: 0.6,
            volume: 0.8,
            languageCode: "en-GB"
        )
        let service = SpeechService(configuration: config)

        let resultConfig = await service.getConfiguration()
        #expect(!resultConfig.isEnabled)
        #expect(resultConfig.rate == 0.6)
        #expect(resultConfig.volume == 0.8)
        #expect(resultConfig.languageCode == "en-GB")
    }

    @Test("Configuration can be updated")
    func testUpdateConfiguration() async {
        let service = SpeechService()

        await service.updateConfiguration { config in
            config.rate = 0.7
            config.volume = 0.5
        }

        let config = await service.getConfiguration()
        #expect(config.rate == 0.7)
        #expect(config.volume == 0.5)
    }

    @Test("Enabled state can be toggled")
    func testSetEnabled() async {
        let service = SpeechService()

        #expect(await service.isEnabled())

        await service.setEnabled(false)
        #expect(!await service.isEnabled())

        await service.setEnabled(true)
        #expect(await service.isEnabled())
    }

    @Test("Available voices returns voices for language")
    func testAvailableVoices() async {
        let service = SpeechService()

        let voices = await service.availableVoices()

        // Should have at least one English voice on any iOS device
        #expect(voices.count > 0)

        // All voices should be for English
        for voice in voices {
            #expect(voice.languageCode.starts(with: "en"))
        }
    }

    @Test("Current voice returns default when none set")
    func testCurrentVoiceDefault() async {
        let service = SpeechService()

        let voice = await service.currentVoice()

        // Should return the default system voice for en-US
        #expect(voice != nil)
        #expect(voice?.languageCode.starts(with: "en") == true)
    }

    @Test("Setting invalid voice throws error")
    func testSetInvalidVoice() async {
        let service = SpeechService()

        do {
            try await service.setVoice("com.invalid.nonexistent.voice")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechError {
            if case .voiceNotFound = error {
                // Expected
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Speaking when disabled throws error")
    func testSpeakWhenDisabled() async {
        let service = SpeechService(configuration: SpeechConfiguration(isEnabled: false))

        do {
            try await service.speak("Hello")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechError {
            #expect(error == .speechDisabled)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Speaking empty text throws error")
    func testSpeakEmptyText() async {
        let service = SpeechService()

        do {
            try await service.speak("")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechError {
            #expect(error == .emptyAnnouncement)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Speaking whitespace-only text throws error")
    func testSpeakWhitespaceText() async {
        let service = SpeechService()

        do {
            try await service.speak("   \n\t   ")
            #expect(Bool(false), "Should have thrown")
        } catch let error as SpeechError {
            #expect(error == .emptyAnnouncement)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("SpeakSafely does not throw")
    func testSpeakSafely() async {
        let service = SpeechService(configuration: SpeechConfiguration(isEnabled: false))

        // This should not throw even though speech is disabled
        await service.speakSafely("Hello")
        // If we get here, the test passes
    }

    @Test("Stop clears speech state")
    func testStop() async {
        let service = SpeechService()

        // Stop should work even when not speaking
        await service.stop()

        let isSpeaking = await service.isSpeechInProgress()
        #expect(!isSpeaking)
    }

    @Test("Convenience method - workout monitoring")
    func testSayWorkoutMonitoringTurned() async {
        let service = SpeechService(configuration: SpeechConfiguration(isEnabled: false))

        // Should not throw even when disabled
        await service.sayWorkoutMonitoringTurned(true)
        await service.sayWorkoutMonitoringTurned(false)
    }

    @Test("Convenience method - region monitoring")
    func testSayRegionMonitoringTurned() async {
        let service = SpeechService(configuration: SpeechConfiguration(isEnabled: false))

        await service.sayRegionMonitoringTurned(true)
        await service.sayRegionMonitoringTurned(false)
    }

    @Test("Convenience method - speech recognition")
    func testSaySpeechRecognitionTurned() async {
        let service = SpeechService(configuration: SpeechConfiguration(isEnabled: false))

        await service.saySpeechRecognitionTurned(true)
        await service.saySpeechRecognitionTurned(false)
    }
}

@Suite("SpeechService Integration Tests", .tags(.integration))
struct SpeechServiceIntegrationTests {

    @Test("Speak valid text completes")
    func testSpeakValidText() async throws {
        let config = SpeechConfiguration(
            isEnabled: true,
            rate: AVSpeechUtteranceMaximumSpeechRate, // Fast for testing
            volume: 0.0, // Silent
            enableAudioDucking: false
        )
        let service = SpeechService(configuration: config)

        // This test verifies the speech flow completes without error
        try await service.speak("Test")
    }
}

extension Tag {
    @Tag static var integration: Self
}
