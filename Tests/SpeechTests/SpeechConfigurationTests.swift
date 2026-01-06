//
//  SpeechConfigurationTests.swift
//  JogPodTests
//
//  Tests for SpeechConfiguration and related types.
//

import Testing
import AVFoundation
@testable import JogPod

@Suite("SpeechConfiguration Tests")
struct SpeechConfigurationTests {

    @Test("Default configuration has expected values")
    func testDefaultConfiguration() {
        let config = SpeechConfiguration.default

        #expect(config.isEnabled == true)
        #expect(config.voiceIdentifier == nil)
        #expect(config.rate == AVSpeechUtteranceDefaultSpeechRate)
        #expect(config.pitchMultiplier == 1.0)
        #expect(config.volume == 1.0)
        #expect(config.enableAudioDucking == true)
        #expect(config.languageCode == "en-US")
    }

    @Test("Rate is clamped to valid range")
    func testRateClamping() {
        // Below minimum
        let lowRate = SpeechConfiguration(rate: -1.0)
        #expect(lowRate.rate >= AVSpeechUtteranceMinimumSpeechRate)

        // Above maximum
        let highRate = SpeechConfiguration(rate: 10.0)
        #expect(highRate.rate <= AVSpeechUtteranceMaximumSpeechRate)

        // Within range
        let normalRate = SpeechConfiguration(rate: 0.5)
        #expect(normalRate.rate == 0.5)
    }

    @Test("Volume is clamped to valid range")
    func testVolumeClamping() {
        let lowVolume = SpeechConfiguration(volume: -0.5)
        #expect(lowVolume.volume == 0.0)

        let highVolume = SpeechConfiguration(volume: 1.5)
        #expect(highVolume.volume == 1.0)

        let normalVolume = SpeechConfiguration(volume: 0.7)
        #expect(normalVolume.volume == 0.7)
    }

    @Test("Pitch is clamped to valid range")
    func testPitchClamping() {
        let lowPitch = SpeechConfiguration(pitchMultiplier: 0.1)
        #expect(lowPitch.pitchMultiplier >= 0.5)

        let highPitch = SpeechConfiguration(pitchMultiplier: 3.0)
        #expect(highPitch.pitchMultiplier <= 2.0)
    }

    @Test("Configuration is equatable")
    func testEquatable() {
        let config1 = SpeechConfiguration(rate: 0.5, volume: 0.8)
        let config2 = SpeechConfiguration(rate: 0.5, volume: 0.8)
        let config3 = SpeechConfiguration(rate: 0.6, volume: 0.8)

        #expect(config1 == config2)
        #expect(config1 != config3)
    }
}

@Suite("VoiceInfo Tests")
struct VoiceInfoTests {

    @Test("VoiceInfo is identifiable")
    func testIdentifiable() {
        let voice = VoiceInfo(
            id: "com.apple.voice.test",
            name: "Test Voice",
            languageCode: "en-US",
            quality: .enhanced
        )

        #expect(voice.id == "com.apple.voice.test")
    }

    @Test("VoiceQuality ordering")
    func testVoiceQualityOrdering() {
        #expect(VoiceQuality.standard < VoiceQuality.enhanced)
        #expect(VoiceQuality.enhanced < VoiceQuality.premium)
        #expect(VoiceQuality.standard < VoiceQuality.premium)
    }
}

@Suite("AnnouncementType Tests")
struct AnnouncementTypeTests {

    @Test("All announcement types have preference keys")
    func testPreferenceKeys() {
        for type in AnnouncementType.allCases {
            #expect(!type.rawValue.isEmpty)
            #expect(type.rawValue.starts(with: "announce"))
        }
    }

    @Test("All announcement types have display names")
    func testDisplayNames() {
        for type in AnnouncementType.allCases {
            #expect(!type.displayName.isEmpty)
            #expect(type.displayName.count >= 4)
        }
    }

    @Test("Default enabled types match legacy behavior")
    func testDefaultEnabledTypes() {
        // These should be enabled by default (matching legacy)
        #expect(AnnouncementType.currentSpeed.isEnabledByDefault)
        #expect(AnnouncementType.averageSpeed.isEnabledByDefault)
        #expect(AnnouncementType.caloriesBurned.isEnabledByDefault)
        #expect(AnnouncementType.duration.isEnabledByDefault)
        #expect(AnnouncementType.distance.isEnabledByDefault)
        #expect(AnnouncementType.temperature.isEnabledByDefault)

        // These should be disabled by default (matching legacy)
        #expect(!AnnouncementType.currentHeartRate.isEnabledByDefault)
        #expect(!AnnouncementType.averageHeartRate.isEnabledByDefault)
        #expect(!AnnouncementType.totalAscent.isEnabledByDefault)
        #expect(!AnnouncementType.totalDescent.isEnabledByDefault)
    }

    @Test("Legacy preference key equivalence")
    func testLegacyPreferenceKeys() {
        // Verify the raw values match legacy Objective-C constants
        #expect(AnnouncementType.currentSpeed.rawValue == "announceCurrentSpeed")
        #expect(AnnouncementType.averageSpeed.rawValue == "announceAvgSpeed")
        #expect(AnnouncementType.currentHeartRate.rawValue == "announceCurrentHeartRate")
        #expect(AnnouncementType.averageHeartRate.rawValue == "announceAvgHeartRate")
        #expect(AnnouncementType.totalAscent.rawValue == "announceTotalAscent")
        #expect(AnnouncementType.totalDescent.rawValue == "announceTotalDescent")
        #expect(AnnouncementType.caloriesBurned.rawValue == "announceCaloriesBurned")
        #expect(AnnouncementType.duration.rawValue == "announceDuration")
        #expect(AnnouncementType.distance.rawValue == "announceDistance")
        #expect(AnnouncementType.temperature.rawValue == "announceTemperature")
        #expect(AnnouncementType.humidity.rawValue == "announceHumidity")
        #expect(AnnouncementType.windSpeed.rawValue == "announceWindSpeed")
    }
}
