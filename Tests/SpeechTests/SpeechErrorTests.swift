//
//  SpeechErrorTests.swift
//  JogPodTests
//
//  Tests for SpeechError types.
//

import Testing
@testable import JogPod

@Suite("SpeechError Tests")
struct SpeechErrorTests {

    @Test("Error descriptions are meaningful")
    func testErrorDescriptions() {
        let errors: [SpeechError] = [
            .synthesizerUnavailable,
            .synthesisFailed(reason: "test reason"),
            .audioSessionConfigurationFailed(reason: "config error"),
            .voiceNotFound(identifier: "com.apple.voice.test"),
            .speechDisabled,
            .emptyAnnouncement,
            .audioDuckingFailed(reason: "ducking error")
        ]

        for error in errors {
            let description = error.localizedDescription
            #expect(!description.isEmpty, "Error \(error) should have a description")
            #expect(description.count > 10, "Error description should be meaningful")
        }
    }

    @Test("Errors are equatable")
    func testEquatable() {
        #expect(SpeechError.synthesizerUnavailable == SpeechError.synthesizerUnavailable)
        #expect(SpeechError.speechDisabled == SpeechError.speechDisabled)
        #expect(SpeechError.synthesisFailed(reason: "a") == SpeechError.synthesisFailed(reason: "a"))
        #expect(SpeechError.synthesisFailed(reason: "a") != SpeechError.synthesisFailed(reason: "b"))
        #expect(SpeechError.speechDisabled != SpeechError.synthesizerUnavailable)
    }

    @Test("Voice not found includes identifier")
    func testVoiceNotFoundIncludesIdentifier() {
        let identifier = "com.apple.voice.premium.en-US.Samantha"
        let error = SpeechError.voiceNotFound(identifier: identifier)

        #expect(error.localizedDescription.contains(identifier))
    }
}
