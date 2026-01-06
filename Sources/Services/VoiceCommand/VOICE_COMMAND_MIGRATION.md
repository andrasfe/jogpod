# Voice Command Migration: OpenEars to Apple Speech Framework

This document describes the migration of JogPod's voice command functionality from the legacy OpenEars/Pocketsphinx implementation to Apple's modern Speech framework.

## Overview

The legacy JogPod application used OpenEars with Pocketsphinx for voice command recognition. This provided fully offline speech recognition with a custom vocabulary optimized for workout commands. The modern implementation uses Apple's `SFSpeechRecognizer` from the Speech framework.

## Feature Comparison

| Feature | Legacy (OpenEars) | Modern (Speech) |
|---------|-------------------|-----------------|
| Offline Recognition | Always available | iOS 13+ with Neural Engine |
| Recognition Accuracy | Good | Excellent |
| Custom Vocabulary | Required language model generation | Contextual strings hint |
| Language Support | English, Spanish | 50+ languages |
| Privacy | Fully on-device | Configurable |
| Framework Maintenance | Abandoned | Apple-maintained |
| iOS Compatibility | iOS 8+ | iOS 13+ |

## Offline Recognition Limitations

### Legacy Behavior
The OpenEars implementation with Pocketsphinx worked **entirely offline**. The app bundled acoustic models (`AcousticModelEnglish.bundle`) and generated language models at runtime from the configured command phrases. Recognition never required network connectivity.

### Modern Behavior
Apple's Speech framework has two modes:

1. **On-Device Recognition** (iOS 13+)
   - Available on devices with Neural Engine (A12 Bionic or later)
   - Requires iOS 13.0+
   - May not be available for all locales
   - When available, provides offline operation similar to legacy

2. **Server-Based Recognition**
   - Fallback when on-device is unavailable
   - Requires network connectivity
   - Better accuracy but privacy trade-off

### Devices Affected
On-device recognition is NOT available on:
- iPhone X and earlier (A11 or earlier chips)
- iPad Pro (1st generation) and earlier
- All iPod touch models

Users with these devices will need network connectivity for voice commands.

## Configuration Options

The `VoiceCommandConfiguration` struct provides options to manage this behavior:

```swift
// Require offline-only operation (will fail on unsupported devices)
var config = VoiceCommandConfiguration.offlineOnly

// Allow fallback to server-based recognition
var config = VoiceCommandConfiguration.default // requireOnDeviceRecognition = false
```

## Authorization Requirements

### Legacy Behavior
OpenEars only required microphone permission (`NSMicrophoneUsageDescription`).

### Modern Behavior
The Speech framework requires TWO permissions:
1. **Microphone Access** (`NSMicrophoneUsageDescription`)
2. **Speech Recognition** (`NSSpeechRecognitionUsageDescription`)

Both must be added to Info.plist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>JogPod needs microphone access for voice commands during workouts.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>JogPod uses speech recognition for hands-free workout control.</string>
```

## Command Phrase Compatibility

The modern implementation preserves the same default command phrases as the legacy version:

| Legacy Constant | Default Phrase | Command |
|----------------|----------------|---------|
| `kStartWorkoutText` | "START WORKOUT" | `.startWorkout` |
| `kStopWorkoutText` | "STOP WORKOUT" | `.stopWorkout` |
| `kPlayPodcastText` | "PLAY" | `.play` |
| `kPausePodcastText` | "PAUSE" | `.pause` |
| `kSkipToNextText` | "NEXT" | `.next` |
| `kSkipToPreviousText` | "PREVIOUS" | `.previous` |
| `kFastForwardText` | "FAST FORWARD" | `.fastForward` |
| `kRewindPodcastText` | "REWIND" | `.rewind` |
| `kShutdownVoiceText` | "STOP LISTENING" | `.stopListening` |
| "METRICS" | "METRICS" | `.announceMetrics` |

### New Commands (iOS 26+)
The modern implementation adds volume control commands not present in the legacy version:
- "LOUDER" (`.volumeUp`)
- "SOFTER" (`.volumeDown`)

## Testing Strategy

### Challenge
- SFSpeechRecognizer requires authorization that cannot be granted in CI
- Speech recognition results are non-deterministic
- Microphone access requires user interaction

### Solution
The implementation separates concerns to enable testing:

1. **VoiceCommandParser**: Pure logic for matching transcriptions to commands
   - Fully unit-testable without audio/microphone
   - Tests in `VoiceCommandParserTests.swift`

2. **MockVoiceCommandService**: Mock implementation of the service protocol
   - Enables testing of command handling
   - Simulates commands, errors, and state changes

3. **VoiceCommandService**: Real implementation
   - Integration-tested on device
   - Manual testing required for full coverage

## Migration Guide

### For View Controllers

**Legacy:**
```objc
// DashboardViewController.m
[SpeechCommandController sharedInstance].delegate = self;
[[SpeechCommandController sharedInstance] startListening];

// SpeechCommandDelegate
-(void)speechCommandReceived:(NSString*)command {
    if([command isEqualToString:kStartWorkoutText]) {
        [self startStopWorkoutButtonClicked:nil];
    }
}
```

**Modern:**
```swift
// DashboardView.swift
@Observable
class DashboardViewModel {
    private let voiceCommandService: any VoiceCommandServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(voiceCommandService: any VoiceCommandServiceProtocol = VoiceCommandService()) {
        self.voiceCommandService = voiceCommandService

        voiceCommandService.commandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleCommand(result.command)
            }
            .store(in: &cancellables)
    }

    func toggleListening() async {
        if await voiceCommandService.isListening {
            await voiceCommandService.stopListening()
        } else {
            try? await voiceCommandService.startListening()
        }
    }

    private func handleCommand(_ command: VoiceCommand) {
        switch command {
        case .startWorkout:
            startWorkout()
        case .stopWorkout:
            stopWorkout()
        // ... handle other commands
        }
    }
}
```

## Known Limitations

1. **Offline Requirement Change**: Older devices require network for voice commands
2. **One-Minute Limit**: SFSpeechRecognizer has a built-in one-minute limit per recognition task
3. **Rate Limiting**: Apple may rate-limit speech recognition requests
4. **Background Audio**: Recognition may be affected when audio is playing

## Alternative Control Methods

To ensure accessibility for users when voice commands are unavailable:

1. **Apple Watch Integration**: WatchConnectivityService provides remote control
2. **Headphone Controls**: Now Playing integration supports media buttons
3. **Lock Screen Controls**: NowPlayingManager enables lock screen control

## References

- [Apple Speech Documentation](https://developer.apple.com/documentation/speech)
- [SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer)
- [On-Device Speech Recognition](https://developer.apple.com/documentation/speech/recognizing_speech_in_live_audio)
- [Legacy OpenEars Documentation](https://www.politepix.com/openears/)
