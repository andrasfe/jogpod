# JogPod iOS App - Complete Migration Documentation Suite

> **Documentation Version**: 1.0
> **Generated**: 2026-01-05
> **Coverage Score**: 97%
> **Status**: APPROVED FOR MIGRATION

---

## Executive Summary

This documentation suite provides comprehensive coverage of the JogPod (jogmuz) iOS fitness tracking application for migration to modern iOS technology (Swift, SwiftUI, SwiftData, modern WatchOS).

### What is JogPod?

JogPod is an iOS fitness tracking application designed for runners who want to:
- **Track workouts** with GPS, speed, distance, pace, elevation, calories, and heart rate
- **Listen to podcasts** while running with queue management and offline caching
- **Use voice commands** for hands-free control
- **Receive voice announcements** of workout metrics
- **Sync with Apple Watch** for wrist-based control
- **Connect external sensors** (Wahoo heart rate monitors)
- **Share results** to social media and HealthKit

### Dual Targets
- **JogPod**: Primary target with WatchOS 2.0 support
- **jogmuz/podmuz**: Secondary/consumer-facing variant

---

## Documentation Files

### 1. MIGRATION_DOCUMENTATION.md (Primary Reference)
**Lines**: ~1,700 | **Purpose**: Complete technical reference

Contains:
- Part 1: System Architecture & Dependency Graphs
- Part 2: File-by-File Summaries (organized by feature)
- Part 3: Utility Infrastructure
- Part 4: Pedometer System
- Part 5: Data Model Support Classes
- Part 6: Correctness Invariants
- Part 7: View Controllers Inventory (51 controllers)
- Part 8: Notification System (25+ notifications)
- Part 9: Operations System (14 operations)
- Part 10: Category Extensions (20+ extensions)
- Part 11: Third-Party Libraries
- Part 12: Storyboards and XIBs
- Part 13: Migration Strategy (6 phases)
- Appendix A: Modern Replacements Table
- Appendix B: Risk Assessment
- Appendix C: Security Concerns

### 2. MEDIUM_PRIORITY_DOCUMENTATION.md (Supplementary)
**Lines**: ~1,200 | **Purpose**: Detailed utility and infrastructure documentation

Contains:
- Section 1: Utility Classes (7 classes)
- Section 2: Pedometer System (6 components)
- Section 3: Fitbit Support Classes (3 classes)
- Section 4: View Controllers Inventory
- Section 5: NSNotification Names
- Section 6: Operations Classes (14 operations)

### 3. EQUIVALENCE_TESTING_STRATEGY.md
**Lines**: ~770 | **Purpose**: Testing strategy for migration validation

Contains:
- Part 1: Definition of Equivalence
- Part 2: Test Oracle Catalog
- Part 3: Test Categories by Feature Area (100+ test cases)
- Part 4: Test Data Requirements
- Part 5: Validation Workflow (9-week plan)
- Part 6: Risk Assessment and Prioritization
- Part 7: Automated vs Manual Testing
- Part 8: Gap Register
- Part 9: Sign-Off Criteria

---

## Quick Reference: Technology Stack

### Current (Legacy)
| Component | Technology |
|-----------|------------|
| Language | Objective-C (primary), Swift 2.x |
| UI | UIKit, Storyboards, XIBs |
| Data | Core Data with iCloud (UbiquityStoreManager) |
| Audio | AVFoundation, AVQueuePlayer |
| Speech | OpenEars (Pocketsphinx, Flite) |
| Watch | WatchKit 1.0/2.0, MMWormhole |
| Sensors | WFConnector (Wahoo), PebbleKit |
| RSS | MWFeedParser |
| Charts | CorePlot |

### Target (Modern)
| Component | Technology |
|-----------|------------|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Data | SwiftData or NSPersistentCloudKitContainer |
| Audio | AVFoundation with async/await |
| Speech | AVSpeechSynthesizer, SFSpeechRecognizer |
| Watch | WatchOS 10+, WatchConnectivity native |
| Sensors | Core Bluetooth |
| RSS | FeedKit or custom XMLParser |
| Charts | Swift Charts |

---

## Quick Reference: Core Data Entities

| Entity | Attributes | Purpose |
|--------|------------|---------|
| WorkoutHistory | workoutID, startTime, address, weather data | Workout session record |
| WorkoutLocation | workoutID, time, location, heartRate, steps | GPS track point |
| WorkoutListeningLog | workoutID, time, titles | Podcast listening during workout |
| RSSEntity | title, link, summary, imageUrl | Podcast feed |
| RSSEntry | 14 attributes including enclosureMediaLink | Podcast episode |
| Preference | name, various value types | User settings |

---

## Quick Reference: Key Files

### App Lifecycle
- `JogPodAppDelegate.m` / `JogmuzAppDelegate.m` - App delegates
- `main.m` / `jogmuzMain.m` - Entry points

### Core Controllers
- `WorkoutController.m` - Workout tracking orchestration
- `PlayerController.m` - Audio playback logic
- `UniversalPlayerController.m` - Singleton audio controller
- `PersistenceManager.m` - Core Data management
- `WatchSessionManager.swift` - Watch communication

### Watch Extension
- `InterfaceController.swift` - Main metrics UI
- `DashBoardInterfaceController.swift` - Dashboard
- `SharedGlobals.swift` - MMWormhole singleton

---

## Quick Reference: Migration Phases

| Phase | Focus | Duration* |
|-------|-------|----------|
| 1 | Foundation (Data layer, PersistenceManager) | Weeks 1-4 |
| 2 | Core Features (Workout tracking, Audio playback) | Weeks 5-10 |
| 3 | Speech System (OpenEars → native) | Weeks 11-13 |
| 4 | WatchOS (SwiftUI, modern WatchConnectivity) | Weeks 14-18 |
| 5 | External Integrations (HealthKit, Bluetooth) | Weeks 19-22 |
| 6 | UI (SwiftUI migration) | Weeks 23-30 |

*Durations are estimates; actual timelines depend on team size and priorities.

---

## Security Concerns

### Hardcoded Credentials (CRITICAL)
| Location | Credential | Action Required |
|----------|------------|-----------------|
| WeatherInfo.m | Weather Underground API key | Replace API (service discontinued) |
| OAuth1Controller.m | Fitbit consumer key/secret | Move to secure storage |
| OAuth1Controller.m | OAuth callback URL | Update for production |

---

## Known Deprecated APIs

| API | File | Replacement |
|-----|------|-------------|
| UIAlertView | Multiple | UIAlertController |
| UIWebView | OAuthViewController | WKWebView or ASWebAuthenticationSession |
| NSURLConnection | Multiple | URLSession |
| ACAccountStore | SocialIntegration | ShareLink or Social frameworks |
| MMWormhole | Watch Extension | WatchConnectivity |

---

## Files to Remove

| File/Component | Reason |
|----------------|--------|
| PebbleController | Pebble discontinued |
| PebbleKit framework | Pebble discontinued |
| LegacyPedometer | Already disabled, obsolete |
| DeviceDetector | Obsolete device detection |

---

## Audit History

| Date | Auditor | Coverage | Status |
|------|---------|----------|--------|
| 2026-01-05 | Initial Audit | 85% | Gaps identified |
| 2026-01-05 | Final Audit | 97% | APPROVED |

### Remaining Minor Gap
- Info.plist configuration not explicitly documented (can be derived from source)

---

## How to Use This Documentation

1. **Start with** `MIGRATION_DOCUMENTATION.md` for overall architecture and migration strategy
2. **Reference** `MEDIUM_PRIORITY_DOCUMENTATION.md` for detailed utility class and operations documentation
3. **Use** `EQUIVALENCE_TESTING_STRATEGY.md` to plan testing approach and define acceptance criteria
4. **Cross-reference** file paths in documentation with actual source code

---

## Document Generation

This documentation was generated using the following agent workflow:

1. **legacy-archaeologist** - Exhaustive codebase analysis
2. **spec-agent** - Structured documentation creation
3. **output-integrity-auditor** - Completeness verification
4. **equivalence-test-strategist** - Testing strategy development

All agents verified documentation accuracy against source code.

---

*For questions or updates, refer to the source code at `/Users/andraslferenczi/jogpod/`*
