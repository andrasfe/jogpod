# JogPod iOS Application Migration Documentation

## Executive Summary

JogPod is a fitness tracking application for runners who listen to podcasts during workouts. This document provides comprehensive migration specifications for transitioning from the legacy Objective-C/Swift 2.x codebase to modern iOS (Swift, SwiftUI, Swift Concurrency, SwiftData, modern WatchOS).

**Current Tech Stack:**
- Objective-C (primary), Swift 2.x (newer components)
- Core Data with UbiquityStoreManager for iCloud sync
- CoreLocation, CoreMotion for tracking
- AVFoundation/MediaPlayer for audio
- OpenEars framework for speech recognition and TTS
- WFConnector.framework for Wahoo heart rate sensors
- PebbleKit for Pebble watch integration (deprecated)
- MWFeedParser for RSS feed parsing
- WatchConnectivity (migrating from MMWormhole)
- CorePlot for charting
- MACircleProgressIndicator (CocoaPods)

**Dual Target Configuration:**
- **JogPod**: Original target with full feature set
- **Jogmuz/podmuz**: Alternative target with different UI (uses MACircleProgressIndicator via CocoaPods)

---

# Part 1: Dependency Graph

## High-Level Module Dependencies

```
                            +------------------+
                            | JogPodAppDelegate|  (or JogmuzAppDelegate)
                            +--------+---------+
                                     |
          +-----------+--------------+-------------+-----------+
          |           |              |             |           |
          v           v              v             v           v
+----------------+ +----------------+ +-----------+ +--------+ +---------------+
|WorkoutController| |PlayerController| |Speech    | |Watch   | |External       |
|                 | |(parent class)  | |System    | |Comms   | |Integrations   |
+--------+--------+ +-------+--------+ +----+-----+ +---+----+ +-------+-------+
         |                  |               |           |              |
    +----+----+        +----+----+     +----+----+   +--+--+    +------+------+
    |         |        |         |     |         |   |     |    |      |      |
    v         v        v         v     v         v   v     v    v      v      v
+-------+ +------+ +------+ +------+ +----+ +------+ +---+ +---+ +----+ +----+ +-----+
|Metrics| |GPS   | |Media | |RSS   | |TTS | |Voice | |iOS| |WK | |HK  | |Peb | |Wahoo|
|Manager| |Signal| |Cache | |Parser| |    | |Recog | |App| |Ext| |    | |ble | |     |
+---+---+ +--+---+ +--+---+ +--+---+ +--+-+ +--+---+ +-+-+ +-+-+ +--+-+ +-+--+ +--+--+
    |        |        |        |       |       |      |     |      |     |       |
    +--------+--------+--------+-------+-------+------+-----+------+-----+-------+
                                       |
                            +----------+----------+
                            |                     |
                            v                     v
                    +---------------+     +---------------+
                    |PersistenceManager|   |NSUserDefaults |
                    |(Core Data)    |     |(Preferences)  |
                    +-------+-------+     +---------------+
                            |
              +-------------+-------------+
              |             |             |
              v             v             v
        +----------+  +----------+  +----------+
        |Workout   |  |RSS       |  |Preference|
        |History   |  |Entity/   |  |          |
        |Location  |  |Entry     |  |          |
        +----------+  +----------+  +----------+
```

## Feature-Level Dependency Map

### 1. Workout Tracking Feature
```
WorkoutController (Singleton)
    |
    +-- WorkoutMetricsManager (per-workout instance)
    |       |-- WorkoutStats (computed metrics)
    |       |-- SpeedStats (speed calculations)
    |       |-- HeartRateMeasurement, LocationMeasurement, SpeedMeasurement
    |       |-- NSOperationQueue (serial update queue)
    |       +-- Operations: WorkoutUpdateMetricsOperation, WorkoutStatsOperation,
    |                       UpdateHeartRateOperation, PolylineFromCoordinateOperation
    |
    +-- GPSSignalAndHeartMonitorController
    |       |-- CLLocationManager
    |       |-- SensorController (protocol)
    |       |       +-- WahooSensorController (WFConnector)
    |       |       +-- MockSensorController
    |       +-- WeatherInfo (Wunderground API)
    |
    +-- PersistenceManager
    |       +-- WorkoutHistory (Core Data)
    |       +-- WorkoutLocation (Core Data)
    |       +-- WorkoutListeningLog (Core Data)
    |
    +-- External Publishers
            +-- PebbleWorkoutSession
            +-- WorkoutMetricsPublisher (Watch, Pebble)
            +-- HKStoreHelper (HealthKit)
```

### 2. Podcast/Audio Feature
```
UniversalPlayerController (Singleton) extends PlayerController
    |
    +-- PlayerController (parent class - playlist/queue management)
    |       +-- Playlist management methods
    |       +-- RSSEnclosureSearchDelegate implementation
    |       +-- PlayerTimerDelegate implementation
    |
    +-- UniversalQueuePlayer
    |       +-- AVQueuePlayer
    |       +-- UniversalPlayerItem[]
    |
    +-- MediaCache (Singleton)
    |       +-- NetworkResourceLoader
    |       +-- CachesIO (file operations)
    |       +-- NSURLSession (background downloads)
    |
    +-- MWFeedParser
    |       +-- RSS/Atom parsing
    |       +-- MWFeedInfo, MWFeedItem
    |
    +-- RSSEnclosureExtractorOperation
    |       +-- Background feed refresh
    |
    +-- PersistenceManager
            +-- RSSEntity (podcast)
            +-- RSSEntry (episode)
```

### 3. Voice/Speech Feature
```
JogTraceSpeech (Singleton)
    |
    +-- FliteController (OpenEars TTS)
    |       +-- Slt voice
    |       +-- Audio session management
    |
    +-- SpeechCommandController
            +-- PocketsphinxController (OpenEars recognition)
            +-- OpenEarsEventsObserver
            +-- LanguageModelGenerator
```

### 4. WatchOS Extension Feature
```
iOS App Side:
    WatchKitRequestHandler (Singleton)
        +-- WatchSessionManager (Swift, WCSession)
        +-- WorkoutMetricsPublisher[]
        +-- SimpleLocationMonitor
        +-- RouteImageGenerator
        +-- NSNotificationCenter observers

WatchOS Extension Side:
    ExtensionDelegate
        +-- WatchSessionManager (Swift, WCSession)

    Interface Controllers:
        +-- InterfaceController (main metrics display)
        +-- DashBoardInterfaceController
        +-- MetricsInterfaceController
        +-- PodcastInterfaceController
        +-- MapInterfaceController
        +-- StatsInterfaceController
        +-- AlertInterfaceController
        +-- GlanceController
        +-- NotificationController

    Shared Utilities:
        +-- SharedGlobals (MMWormhole configuration)
```

### 5. External Integrations Feature
```
PebbleController
    +-- PBPebbleCentral
    +-- PBWatch
    +-- App messaging

WahooSensorController
    +-- WFHardwareConnector
    +-- WFHeartrateConnection
    +-- Bluetooth LE

HKStoreHelper
    +-- HKHealthStore
    +-- HKWorkout

FitbitEventSubscriber
    +-- OAuth1Controller (OAuth 1.0a authentication)
    |       +-- HMAC-SHA1 signing
    |       +-- Base64Transcoder
    |       +-- UIWebView (deprecated)
    +-- REST API calls

SocialIntegration
    +-- ACAccountStore
    +-- SLRequest (Twitter, Facebook)
```

### 6. AppQueueManager (Central Queue Manager)
```
AppQueueManager (Singleton)
    |
    +-- operationQueue (NSOperationQueue)
    |       +-- maxConcurrentOperationCount: 5 (iPhone 5+) or 3 (older)
    |       +-- Used for: workout operations, data processing
    |
    +-- parseQueue (NSOperationQueue)
            +-- maxConcurrentOperationCount: 5 (iPhone 5+) or 3 (older)
            +-- Used for: RSS parsing operations

Consumers:
    - LegacyPedometer
    - RSSEnclosureExtractorOperation
    - Various workout operations
```

### 7. Pedometer System
```
PedometerFactory
    |
    +-- [Simulator] -> MockPedometer
    |
    +-- [M7/M8+ Chip] -> M7Pedometer -> JAGPedometer -> CMPedometer
    |
    +-- [Older Devices] -> nil (LegacyPedometer disabled)

StepCounter Protocol:
    -(void)startCount
    -(void)stopCount
    -(NSInteger)steps
    -(BOOL)isCounting
```

---

# Part 2: File-by-File Summaries Organized by Feature

## Feature: Application Core

### `/Users/andraslferenczi/jogpod/JogCast/JogPodAppDelegate.h` / `.m`
- **Purpose**: Main application delegate for JogPod target
- **Inputs**: UIApplicationDelegate lifecycle events, background fetch triggers
- **Outputs**: Configured app state, background fetch results
- **Side Effects**: Initializes persistence, registers for background fetch, configures watch session
- **Feature Role**: Entry point and lifecycle manager for JogPod target
- **Conforms To**: UIApplicationDelegate, PlaylistRefreshDelegate

### `/Users/andraslferenczi/jogpod/JogCast/JogmuzAppDelegate.h` / `.m`
- **Purpose**: Main application delegate for Jogmuz/podmuz target (alternative UI)
- **Inputs**: UIApplicationDelegate lifecycle events, background fetch triggers
- **Outputs**: Configured app state, background fetch results
- **Side Effects**: Initializes persistence, registers for background fetch
- **Feature Role**: Entry point and lifecycle manager for Jogmuz target
- **MIGRATION NOTE**: Determine if dual-target architecture should be preserved or unified

### `/Users/andraslferenczi/jogpod/AppQueueManager.h` / `.m`
- **Purpose**: Singleton providing centralized NSOperationQueue management
- **Inputs**: None (configuration only)
- **Outputs**: Shared operation queues for background work
- **Side Effects**: None
- **Feature Role**: Central queue management for all background operations
- **Key Invariant**: Queue concurrency adjusted based on DeviceDetector.isIPhone5 (5 vs 3)
- **MIGRATION NOTE**: DeviceDetector check is obsolete; modern devices should use higher concurrency

---

## Feature: Workout Tracking

### `/Users/andraslferenczi/jogpod/JogCast/WorkoutController.h` / `.m`
- **Purpose**: Singleton orchestrator for workout sessions including GPS tracking, heart rate monitoring, weather, and speech announcements
- **Inputs**: User start/stop commands, location updates, heart rate data, weather data
- **Outputs**: Workout metrics via notifications, persisted workout history
- **Side Effects**: Starts/stops CLLocationManager, manages audio session for announcements, posts notifications (workoutStatusChanged, podcastItemChanged)
- **Feature Role**: Central coordinator that initializes and manages all workout subsystems

### `/Users/andraslferenczi/jogpod/JogCast/WorkoutMetricsManager.h` / `.m`
- **Purpose**: Manages real-time and historical workout metrics for a single workout session
- **Inputs**: CLLocation updates, heart rate readings, step counts, weather data
- **Outputs**: WorkoutStats objects, polyline coordinates, announcement strings
- **Side Effects**: Creates WorkoutHistory in Core Data, posts locationUpdate notifications, queues update operations
- **Feature Role**: Computes and persists all workout measurements with serial operation queue for thread safety

### `/Users/andraslferenczi/jogpod/JogCast/WorkoutStats.h` / `.m`
- **Purpose**: Value object containing computed workout statistics with announcement generation
- **Inputs**: Raw metrics from WorkoutMetricsManager
- **Outputs**: Formatted strings for announcements, dictionary for wearable displays
- **Side Effects**: None (pure data container)
- **Feature Role**: Provides formatted workout data for UI and announcements

### `/Users/andraslferenczi/jogpod/JogCast/GPSSignalAndHeartMonitorController.h` / `.m`
- **Purpose**: Manages CoreLocation and heart rate sensor connections
- **Inputs**: Delegate callbacks from CLLocationManager and sensor controller
- **Outputs**: Location updates via LocationUpdateDelegate, heart rate notifications
- **Side Effects**: Requests location authorization, manages CLLocationManager lifecycle
- **Feature Role**: Hardware abstraction layer for location and heart rate sensors

### `/Users/andraslferenczi/jogpod/JogCast/SpeedStats.h` / `.m`
- **Purpose**: Tracks speed measurements with rolling average and peak detection
- **Inputs**: Raw speed values from location updates
- **Outputs**: Current speed, average speed, peak speed indicators
- **Side Effects**: None
- **Feature Role**: Speed smoothing and peak detection algorithm

### `/Users/andraslferenczi/jogpod/JogCast/WeatherInfo.h` / `.m`
- **Purpose**: Fetches weather data from Wunderground API
- **Inputs**: CLLocation coordinates
- **Outputs**: Temperature, humidity, wind speed/direction via LocalWeatherDelegate
- **Side Effects**: Network requests to Wunderground API
- **Feature Role**: Provides environmental context for workout announcements
- **MIGRATION NOTE**: Wunderground API key hardcoded (`bb6559c821a428c6`); API may be deprecated

---

## Feature: Podcast/Audio Playback

### `/Users/andraslferenczi/jogpod/JogCast/PlayerController.h` / `.m`
- **Purpose**: Base class managing playlist operations, RSS feed refresh, and queue management
- **Inputs**: RSSEntry items, playback commands (play, pause, skip, seek)
- **Outputs**: Player state via delegates, playlist data
- **Side Effects**: Manages UniversalQueuePlayer, persists playback position
- **Feature Role**: Parent class providing playlist infrastructure for UniversalPlayerController
- **Conforms To**: RSSEnclosureSearchDelegate, PlayerTimerDelegate
- **Key Methods**: refreshPlayList, asyncRefreshMediaContent, goToItem, saveCurrentItemPosition

### `/Users/andraslferenczi/jogpod/JogCast/UniversalPlayerController.h` / `.m`
- **Purpose**: Singleton extending PlayerController for unified audio playback management
- **Inputs**: Inherits from PlayerController
- **Outputs**: Player state via notifications (playerStatusChanged, podcastItemChanged)
- **Side Effects**: Manages AVAudioSession, updates MPNowPlayingInfoCenter, inherits all PlayerController behavior
- **Feature Role**: Single access point for all audio playback in the app
- **Inheritance**: Extends PlayerController (NOT a separate implementation)
- **MIGRATION NOTE**: Consider flattening hierarchy or using composition instead of inheritance

### `/Users/andraslferenczi/jogpod/JogCast/MediaCache.h` / `.m`
- **Purpose**: Manages offline podcast episode caching
- **Inputs**: RSS entry URLs, podcast URLs
- **Outputs**: Local file URLs for cached content
- **Side Effects**: Downloads files to Caches directory, maintains entry-to-RSS mapping in NSUserDefaults
- **Feature Role**: Enables offline playback by downloading and caching podcast episodes

### `/Users/andraslferenczi/jogpod/JogCast/MWFeedParser.h` / `.m`
- **Purpose**: Third-party RSS/Atom feed parser (Michael Waterfall, MIT License with restrictions)
- **Inputs**: Feed URL
- **Outputs**: MWFeedInfo (podcast metadata), MWFeedItem (episode metadata) via delegate
- **Side Effects**: Network requests to fetch feeds
- **Feature Role**: Parses podcast RSS feeds into structured data
- **License**: MIT with diary/journal restriction clause
- **MIGRATION NOTE**: Replace with FeedKit or custom Swift RSS parser

### `/Users/andraslferenczi/jogpod/JogCast/RSSEnclosureExtractorOperation.h` / `.m`
- **Purpose**: NSOperation that refreshes podcast feeds and extracts audio enclosures
- **Inputs**: Podcast index, background fetch flag
- **Outputs**: Updated RSSEntry objects via delegate
- **Side Effects**: Network requests, Core Data updates
- **Feature Role**: Background feed refresh mechanism

---

## Feature: Voice Commands and TTS

### `/Users/andraslferenczi/jogpod/JogCast/JogTraceSpeech.h` / `.m`
- **Purpose**: Singleton managing text-to-speech output using OpenEars FliteController
- **Inputs**: Text strings to speak, audio ducking preference
- **Outputs**: Audio output via speakers
- **Side Effects**: Ducks/restores podcast audio volume during speech, manages audio session category
- **Feature Role**: Provides voice feedback for workout metrics and notifications

### `/Users/andraslferenczi/jogpod/JogCast/SpeechCommandController.h` / `.m`
- **Purpose**: Manages voice command recognition using OpenEars Pocketsphinx
- **Inputs**: Audio input from microphone
- **Outputs**: Recognized commands via SpeechCommandDelegate
- **Side Effects**: Manages microphone audio session, generates language model
- **Feature Role**: Enables hands-free control via voice commands
- **MIGRATION NOTE**: OpenEars is deprecated; modern replacement needed (SFSpeechRecognizer)

---

## Feature: WatchOS Extension

### `/Users/andraslferenczi/jogpod/JogCast/WatchSessionManager.swift`
- **Purpose**: Swift wrapper for WCSession providing Watch Connectivity communication
- **Inputs**: Messages from watch, application context
- **Outputs**: Reply handlers for watch messages
- **Side Effects**: Activates WCSession
- **Feature Role**: Bidirectional communication layer between iOS app and WatchOS extension

### `/Users/andraslferenczi/jogpod/JogCast/WatchKitRequestHandler.h` / `.m`
- **Purpose**: Singleton handling all requests from WatchOS extension
- **Inputs**: Watch messages (openDashBoard, openMetrics, openPodcast, openMap, openStats)
- **Outputs**: Dictionary responses with workout state, podcast state
- **Side Effects**: Registers notification observers, sends push messages to watch
- **Feature Role**: iOS-side handler for watch interface controller requests

### `/Users/andraslferenczi/jogpod/JogPod WatchKit Extension/ExtensionDelegate.swift`
- **Purpose**: WatchOS extension delegate initializing watch session
- **Inputs**: Lifecycle events
- **Outputs**: None
- **Side Effects**: Starts WatchSessionManager
- **Feature Role**: Extension entry point

### `/Users/andraslferenczi/jogpod/JogPod WatchKit Extension/InterfaceController.swift`
- **Purpose**: Main watch interface for workout metrics display and control
- **Inputs**: Messages from iOS app via WCSession and MMWormhole
- **Outputs**: UI updates, workout control commands
- **Side Effects**: Activates WCSession, listens for wormhole messages
- **Feature Role**: Primary watch metrics display with workout on/off control
- **UI States**: firstTimeRendering, workoutStoppedRendered, workoutJustStartedRendered, workoutInProgressRendered
- **IBOutlets**: workoutOn (switch), upButton, downButton, metricsDescription, metricsUnits, metricsValueLabel, updatingImage, metricsOffMessageLabel
- **MIGRATION NOTE**: Still uses MMWormhole alongside WCSession; should migrate fully to WCSession

### `/Users/andraslferenczi/jogpod/JogPod WatchKit Extension/SharedGlobals.swift`
- **Purpose**: Provides shared MMWormhole instance for watch-app communication
- **Inputs**: None
- **Outputs**: Static MMWormhole instance
- **Side Effects**: None
- **Feature Role**: Central wormhole configuration for watch extension
- **Configuration**: App group "group.com.motionscapes.jogpod", directory "wormhole", transit type SessionContext
- **MIGRATION NOTE**: MMWormhole should be replaced with native WatchConnectivity

### `/Users/andraslferenczi/jogpod/JogPod WatchKit Extension/DashBoardInterfaceController.swift`
- **Purpose**: Main watch interface showing workout and podcast status
- **Inputs**: Messages from iOS app
- **Outputs**: UI updates
- **Side Effects**: Sends openDashBoard request to iOS app
- **Feature Role**: Primary watch interface

---

## Feature: External Device Integrations

### `/Users/andraslferenczi/jogpod/JogCast/PebbleController.h` / `.m`
- **Purpose**: Manages Pebble smartwatch communication
- **Inputs**: Messages from Pebble app
- **Outputs**: Workout metrics pushed to Pebble
- **Side Effects**: Launches/terminates Pebble companion app
- **Feature Role**: Pebble watch integration
- **MIGRATION NOTE**: Pebble is discontinued; this feature can be removed

### `/Users/andraslferenczi/jogpod/JogCast/WahooSensorController.h` / `.m`
- **Purpose**: Manages Wahoo heart rate sensor connections via WFConnector framework
- **Inputs**: Bluetooth LE heart rate data
- **Outputs**: Heart rate readings via notifications (WF_NOTIFICATION_SENSOR_HAS_DATA)
- **Side Effects**: Manages Bluetooth connections, copies sensor data plist
- **Feature Role**: Heart rate hardware integration
- **MIGRATION NOTE**: WFConnector may need replacement with Core Bluetooth

### `/Users/andraslferenczi/jogpod/JogCast/HKStoreHelper.swift`
- **Purpose**: HealthKit integration for reading/writing workout data
- **Inputs**: Workout completion data
- **Outputs**: HKWorkout records
- **Side Effects**: Requests HealthKit authorization, saves workouts
- **Feature Role**: Syncs workout data with Apple Health

### `/Users/andraslferenczi/jogpod/JogCast/FitbitEventSubscriber.h` / `.m`
- **Purpose**: Manages Fitbit API integration for activity tracking
- **Inputs**: OAuth tokens
- **Outputs**: Activity deltas (minutes, distance, calories)
- **Side Effects**: REST API calls to Fitbit
- **Feature Role**: Pulls activity data from Fitbit for sedentary alerts

### `/Users/andraslferenczi/jogpod/JogCast/OAuth1Controller.h` / `.m`
- **Purpose**: OAuth 1.0a authentication controller for Fitbit API
- **Inputs**: UIWebView for user authorization
- **Outputs**: OAuth tokens via completion blocks
- **Side Effects**: Network requests for token exchange, UIWebView navigation
- **Feature Role**: Handles Fitbit OAuth authentication flow
- **CRITICAL SECURITY**: Contains hardcoded credentials:
  - Consumer Key: `12006c213d984133a3eeada7432b82bd`
  - Consumer Secret: `183d0c5f184446cbb1ded82fc9706c4a`
  - OAuth Callback: `https://pofajegyzetek.appspot.com/jogpod`
- **Dependencies**: NSString+URLEncoding, hmac.h, Base64Transcoder.h
- **MIGRATION NOTE**:
  - CRITICAL: Move credentials to secure storage (Keychain or server-side)
  - Replace UIWebView with ASWebAuthenticationSession
  - Replace NSURLConnection with URLSession
  - Consider migrating to OAuth 2.0 (Fitbit's current recommendation)

### `/Users/andraslferenczi/jogpod/JogCast/SocialIntegration.h` / `.m`
- **Purpose**: Manages Twitter and Facebook sharing
- **Inputs**: Workout summary text
- **Outputs**: Social media posts
- **Side Effects**: ACAccountStore access, SLRequest API calls
- **Feature Role**: Social sharing of workout achievements
- **MIGRATION NOTE**: Deprecated Social framework; needs modern replacement

---

## Feature: Data Persistence

### `/Users/andraslferenczi/jogpod/JogCast/PersistenceManager.h` / `.m`
- **Purpose**: Singleton managing Core Data stack and all data operations
- **Inputs**: Entity create/read/update/delete requests
- **Outputs**: Managed objects, query results
- **Side Effects**: Core Data saves, iCloud sync via UbiquityStoreManager
- **Feature Role**: Central data access layer

### `/Users/andraslferenczi/jogpod/JogCast/PersistenceDefaults.h` / `.m`
- **Purpose**: Defines preference keys and default values
- **Inputs**: None (static definitions)
- **Outputs**: Default preference values
- **Side Effects**: None
- **Feature Role**: Configuration constants

### `/Users/andraslferenczi/jogpod/JogCast/UbiquityStoreManager/UbiquityStoreManager.h` / `.m`
- **Purpose**: Third-party iCloud Core Data sync manager (Maarten Billemont, Apache 2.0)
- **Inputs**: Delegate callbacks, store configuration
- **Outputs**: NSPersistentStoreCoordinator with iCloud-enabled store
- **Side Effects**: Manages iCloud container, handles store migrations, posts notifications
- **Feature Role**: Provides reliable iCloud sync for Core Data
- **Key Features**: Migration strategies, corruption handling, cloud/local switching
- **Notifications**: USMStoreWillChangeNotification, USMStoreDidChangeNotification, USMStoreDidImportChangesNotification
- **MIGRATION NOTE**: Replace with modern NSPersistentCloudKitContainer

### Core Data Entities:

#### `/Users/andraslferenczi/jogpod/JogCast/WorkoutHistory.h`
- **Attributes**: workoutID, startTime, address, temperature, humidity, wind, alert info, weather icon
- **Purpose**: Stores workout session metadata

#### `/Users/andraslferenczi/jogpod/JogCast/WorkoutLocation.h`
- **Attributes**: workoutID, time, location, heartRate, steps
- **Purpose**: Stores individual location samples during workout

#### `/Users/andraslferenczi/jogpod/JogCast/RSSEntity.h`
- **Attributes**: link, title, summary, imageUrl, contains (relationship to RSSEntry)
- **Purpose**: Stores podcast feed metadata

#### `/Users/andraslferenczi/jogpod/JogCast/RSSEntry.h`
- **Attributes**:
  - identifier (NSString) - unique episode ID
  - title (NSString) - episode title
  - name (NSString) - display name
  - summary (NSString) - episode description
  - url (NSString) - episode page URL
  - link (NSString) - alternate link
  - enclosureMediaLink (NSString) - audio file URL
  - date (NSDate) - entry creation date
  - releaseDate (NSDate) - episode publication date
  - lastUpdated (NSDate) - last sync timestamp
  - index (NSNumber) - playlist position
  - currentInPlayer (NSNumber/BOOL) - is currently playing
  - type (NSNumber) - entry type identifier
  - preferredPlayDurationInMinutes (NSNumber) - target play duration
  - belongsTo (RSSEntity) - parent podcast relationship
- **Purpose**: Stores podcast episode metadata with playback state

#### `/Users/andraslferenczi/jogpod/JogCast/Preference.h`
- **Attributes**: name, boolValue, intValue, floatValue, stringValue, dateValue, latCoord, longCoord
- **Purpose**: Generic key-value preference storage

#### `/Users/andraslferenczi/jogpod/JogCast/WorkoutListeningLog.h`
- **Attributes**: workoutID, time, entityTitle, entryTitle, entrySummary
- **Purpose**: Links podcasts listened to specific workouts

---

## Feature: Utilities

### `/Users/andraslferenczi/jogpod/JogCast/MotionDetector.swift`
- **Purpose**: Detects device motion using CMMotionManager
- **Inputs**: Accelerometer data
- **Outputs**: Motion event callbacks
- **Feature Role**: Triggers UI updates based on device movement

### `/Users/andraslferenczi/jogpod/JogCast/UnitConverter.h` / `.m`
- **Purpose**: Converts between metric and imperial units
- **Inputs**: Raw measurement values
- **Outputs**: Converted values
- **Feature Role**: Localization support for measurements

---

# Part 3: Utility Infrastructure

## Utility Classes

### LogUtil
**Files**: `/Users/andraslferenczi/jogpod/JogCast/LogUtil.h` / `.m`
- **Purpose**: Debug-only logging utility persisting to NSUserDefaults
- **Methods**: `+logEvent:`, `+eventHistory`, `+clearEventHistory`
- **Key Behavior**: Only active in DEBUG builds, timestamps with `hh.mm.ss.SSS`
- **Storage**: NSUserDefaults key `runtimeLogs`
- **MIGRATION NOTE**: Replace with os_log (unified logging)

### DeviceDetector
**Files**: `/Users/andraslferenczi/jogpod/JogCast/DeviceDetector.h` / `.m`
- **Purpose**: Detects iPhone model based on screen height
- **Methods**: `+isIPhone5` (height == 568), `+isIPhone4` (height == 480)
- **MIGRATION NOTE**: OBSOLETE - Replace with Auto Layout/Size Classes

### InputValidator
**Files**: `/Users/andraslferenczi/jogpod/JogCast/InputValidator.h` / `.m`
- **Purpose**: Validates numeric text field input
- **Methods**: `+textField:shouldChangeNumericCharsInRange:replacementString::maxValue:`
- **Key Behavior**: Rejects non-numeric, enforces max value (exclusive)
- **MIGRATION NOTE**: Consider using UITextFieldDelegate with Formatters

### Reachability
**Files**: `/Users/andraslferenczi/jogpod/JogCast/Reachability.h` / `.m`
- **Purpose**: Network connectivity monitoring (Tony Million's library)
- **Methods**: `+reachabilityWithHostname:`, `+reachabilityForInternetConnection:`, `-isReachable`, `-isReachableViaWiFi`, `-isReachableViaWWAN`
- **Notifications**: `kReachabilityChangedNotification`
- **Dependencies**: SystemConfiguration framework
- **MIGRATION NOTE**: Replace with NWPathMonitor (Network framework, iOS 12+)

### NetworkPresenceTester
**Files**: `/Users/andraslferenczi/jogpod/JogCast/NetworkPresenceTester.h` / `.m`
- **Purpose**: Simplified wrapper around Reachability
- **Methods**: `-wifiActive`, `-connectedToNetwork`
- **MIGRATION NOTE**: Replace with NWPathMonitor

### XMLDictionary
**Files**: `/Users/andraslferenczi/jogpod/JogCast/XMLDictionary.h` / `.m`
- **Purpose**: XML to NSDictionary parser (Nick Lockwood v1.4)
- **License**: Zlib
- **Key Features**: Configurable attribute handling, bidirectional conversion
- **MIGRATION NOTE**: Consider updating to latest version or using native parsing

### TimedOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/TimedOperation.h` / `.m`
- **Purpose**: Base class for NSOperation with request timestamp
- **Methods**: `-init`, `-requestDate`
- **Feature Role**: Base class for all timed operations

---

# Part 4: Pedometer System

## Architecture

```
PedometerFactory.create()
    |
    +-- [TARGET_IPHONE_SIMULATOR] -> MockPedometer
    |
    +-- [M7Pedometer.stepCountingAvailable == YES] -> M7Pedometer
    |
    +-- [else] -> nil (LegacyPedometer disabled)
```

## StepCounter Protocol
**File**: `/Users/andraslferenczi/jogpod/JogCast/StepCounter.h`
```objc
@protocol StepCounter <NSObject>
-(void)startCount;
-(void)stopCount;
-(NSInteger)steps;
-(BOOL)isCounting;
@end
```

## Implementations

### PedometerFactory
**Files**: `/Users/andraslferenczi/jogpod/JogCast/PedometerFactory.h` / `.m`
- **Purpose**: Factory creating appropriate StepCounter implementation
- **Method**: `+create` returns id<StepCounter>

### M7Pedometer
**Files**: `/Users/andraslferenczi/jogpod/JogCast/M7Pedometer.h` / `.m`
- **Purpose**: CMPedometer wrapper for M7/M8+ devices
- **Methods**: `-init`, `+stepCountingAvailable`
- **Dependencies**: JAGPedometer, CoreMotion

### JAGPedometer
**Files**: `/Users/andraslferenczi/jogpod/JogCast/JAGPedometer.h` / `.m`
- **Purpose**: CMPedometer wrapper with main-thread callbacks
- **Methods**: `-startPedometerUpdatesFromDate:completion:`, `-stopPedometerUpdates`

### LegacyPedometer (DISABLED)
**Files**: `/Users/andraslferenczi/jogpod/JogCast/LegacyPedometer.h` / `.m`
- **Purpose**: Accelerometer-based step detection
- **Status**: Disabled in PedometerFactory
- **Algorithm**: Dot product + weighted moving average + threshold crossing
- **MIGRATION NOTE**: Consider removing entirely

### MockPedometer
**Files**: `/Users/andraslferenczi/jogpod/JogCast/MockPedometer.h` / `.m`
- **Purpose**: Simulator-only random step generator
- **Feature Role**: Development/testing only

---

# Part 5: Data Model Support Classes

### WorkoutReading
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WorkoutReading.h` / `.m`
- **Purpose**: Value object for processed location data with computed metrics
- **Properties**:
  - time (NSDate)
  - distance, totalDistance (CLLocationDistance)
  - duration, totalDuration (NSTimeInterval)
  - instantSpeed, movingAverageSpeed (NSNumber)
  - instantHeartRate (NSNumber)
  - elevation (NSNumber)
  - elevationChange (double)
  - minSpeed, maxSpeed (float)
  - totalSteps (NSNumber)
  - currentStepSize (NSNumber)
  - location (CLLocation)
- **Feature Role**: Intermediate data structure for workout analysis

### DataPoint
**Files**: `/Users/andraslferenczi/jogpod/JogCast/DataPoint.h` / `.m`
- **Purpose**: Simple 2D coordinate for graph data
- **Properties**: x (double), y (double)
- **Methods**: `-initWithX:andY:`, `-equalsTo:`
- **Feature Role**: Used by Douglas-Peucker algorithm

### XYCoords
**Files**: `/Users/andraslferenczi/jogpod/JogCast/XYCoords.h` / `.m`
- **Purpose**: Parallel arrays of X and Y coordinates for graphing
- **Properties**: xCoords (NSArray), yCoords (NSArray)
- **Methods**: `-initWithDataPointArray:`, `+dataPointArrayFromXArray:andYArray:`
- **Feature Role**: Output format for graph operations

---

# Part 6: Correctness Invariants

## Data Invariants

### Workout Data
1. **WorkoutHistory.workoutID** MUST be unique (UUID string format)
2. **WorkoutLocation.workoutID** MUST reference existing WorkoutHistory
3. **WorkoutLocation.time** MUST be chronologically ordered within a workout
4. **WorkoutLocation.location** stores CLLocation object via transformable
5. Heart rate values MUST be in range 0-255 BPM (unsigned char from sensor)
6. Step count MUST be non-negative and monotonically increasing within workout

### Podcast Data
1. **RSSEntry.index** determines playlist order; MUST be unique per playlist
2. **RSSEntry.currentInPlayer** can be YES for at most one entry at a time
3. **RSSEntry.belongsTo** relationship MUST reference valid RSSEntity or be nil
4. **RSSEntity.link** serves as unique identifier for podcasts
5. **RSSEntry.lastUpdated** tracks sync timestamp for freshness
6. **RSSEntry.preferredPlayDurationInMinutes** is optional user preference

### Preference Data
1. **Preference.name** MUST be unique (acts as primary key)
2. Boolean preferences default to values defined in PersistenceDefaults when not set
3. Coordinate preferences store latitude/longitude as separate NSNumber fields

## Behavioral Invariants

### Workout Tracking
1. WorkoutController MUST post `workoutStatusChanged` notification when workout starts/stops
2. Location updates MUST be persisted to Core Data every 20 readings (batch commit)
3. Heart rate updates MUST be persisted to Core Data every 20 readings
4. Weather data MUST be fetched once per workout start (not continuously)
5. SpeedStats MUST ignore first reading to avoid GPS cold-start spikes
6. WorkoutMetricsManager uses serial NSOperationQueue (maxConcurrentOperationCount = 1)

### Audio Playback
1. UniversalPlayerController MUST post `playerStatusChanged` notification on state changes
2. UniversalPlayerController MUST post `podcastItemChanged` notification when track changes
3. Audio session category MUST support background playback
4. TTS speech MUST duck (lower volume) podcast audio during announcements
5. Playback position MUST be persisted when pausing or switching tracks

### Watch Communication
1. WCSession MUST be activated before sending messages
2. Message handlers MUST return response synchronously via replyHandler
3. currentView state MUST be tracked to filter incoming notifications
4. Background task MUST be started for long-running watch operations
5. MMWormhole and WCSession are currently BOTH used; migration incomplete

### Data Persistence
1. Core Data saves MUST occur on main thread OR merge to main context
2. Background contexts MUST have primaryContext as parent
3. iCloud sync state MUST be persisted in NSUserDefaults (ICLOUD_ENABLED)
4. Playlist changes MUST post kPlaylistChangeNotification

## Ordering Invariants

### Startup Sequence
1. PersistenceManager singleton MUST be initialized before any data access
2. UbiquityStoreManager MUST complete loading before MOC is available (waitTillAvailable)
3. Disclaimer acceptance MUST be checked before workout features are accessible
4. Watch session MUST be started in AppDelegate applicationDidFinishLaunching
5. AppQueueManager queues MUST be available before any operations are queued

### Workout Lifecycle
1. WorkoutMetricsManager MUST create WorkoutHistory before storing locations
2. Weather fetch MUST complete before first announcement includes weather
3. HealthKit workout MUST be saved after workout completion, not during
4. Core Data commit MUST occur after all location/HR updates in batch

### Audio Playback Lifecycle
1. AVAudioSession MUST be configured before creating AVPlayer
2. MPNowPlayingInfoCenter MUST be updated when track changes
3. Remote control events MUST be registered after audio session active

## Consistency Invariants

### Cross-Entity Consistency
1. WorkoutListeningLog entries MUST have workoutID matching active WorkoutHistory
2. RSSEntry.belongsTo MUST be consistent with cached file mapping in NSUserDefaults
3. Media cache file existence MUST match entryToRSSMapping in NSUserDefaults

### State Synchronization
1. Watch interface MUST reflect iOS app workout/podcast state
2. Pebble display MUST receive updates when workout metrics change
3. HealthKit workout MUST match WorkoutHistory data

## Error Handling Invariants

### Network Failures
1. Weather fetch failure MUST NOT prevent workout from starting
2. Feed parse failure MUST NOT delete existing podcast entries
3. Media cache download failure MUST invoke completion block with success=NO

### Hardware Failures
1. GPS authorization denial MUST disable workout functionality
2. Sensor disconnection MUST reset lastReading to 0
3. Watch unreachable MUST NOT block iOS app operations

### Data Corruption
1. Core Data save failure MUST be logged but MUST NOT crash (uses NSMergeByPropertyObjectTrumpMergePolicy)
2. Missing preference MUST return default value from PersistenceDefaults
3. Invalid managed object ID MUST return nil, not crash

---

# Part 7: View Controllers Inventory

## 7.1 Main Dashboard (2 controllers)

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| DashboardViewController | DashboardViewController.h/.m | Main workout dashboard with metrics, media controls, GPS/HR indicators | UIViewController |
| JogmuzDashViewController | JogmuzDashViewController.swift | Swift-based alternative dashboard (Jogmuz target) | UIViewController |

**DashboardViewController Details:**
- IBOutlets: mediaCenterView, gpsLevelImage, heartMonitoringImage, metricsView, startStopWorkoutButton
- IBActions: startStopWorkoutButtonClicked, toggleSpeechRecognition, metricsLeftScrollClicked, metricsRightScrollClicked
- Protocols: WorkoutStatusDelegate, SpeechCommandDelegate, GPSSignalAndHeartMonitorDelegate, DisclaimerDelegate

## 7.2 Metrics Display (3 controllers)

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| MetricsViewController | MetricsViewController.h/.m | Single metric display with value, unit, description | EmbeddedViewController |
| CombinedMetricsViewController | CombinedMetricsViewController.h/.m | Combined metrics display | UIViewController |
| SlidingMetricsViewController | SlidingMetricsViewController.h/.m | Scrollable metrics pages | SlidingBaseViewController |

## 7.3 Media/Podcast Controllers (9 controllers)

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| MediaCenterViewController | MediaCenterViewController.h/.m | Audio player controls (play/pause, seek, position) | EmbeddedViewController |
| PodcastTableViewController | PodcastTableViewController.h/.m | Podcast list management | UITableViewController |
| PodcastDetailViewController | PodcastDetailViewController.h/.m | Podcast episode details | UIViewController |
| PublicPodcastViewController | PublicPodcastViewController.h/.m | Public podcast browser with add-to-playlist | UIViewController |
| PublicPodcastSearchTableViewController | PublicPodcastSearchTableViewController.h/.m | Podcast search interface | UITableViewController |
| PlayItemViewController | PlayItemViewController.h/.m | Individual play item display | UIViewController |
| SlidingPodcastViewController | SlidingPodcastViewController.h/.m | Scrollable podcast items | SlidingBaseViewController |
| PodcastUpdatesViewController | PodcastUpdatesViewController.h/.m | Podcast update notifications | UIViewController |
| PodcastFilterViewController | PodcastFilterViewController.h/.m | Podcast filtering options | UIViewController |

## 7.4 Statistics & Reporting (8 controllers)

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| StatsViewController | StatsViewController.h/.m | Statistics container with map, graph, grid views | UIViewController |
| StatsMapViewController | StatsMapViewController.h/.m | Workout route map display | EmbeddedViewController |
| StatsTabViewController | StatsTabViewController.h | Tab controller protocol for stats views | (Protocol) |
| ChartViewController | ChartViewController.h/.m | CorePlot-based graphing | UIViewController |
| GridViewController | GridViewController.h/.m | Grid-based data display using PFGridView | UIViewController |
| ReportViewController | ReportViewController.h/.m | Workout summary report with metrics | EmbeddedViewController |
| ListeningLogViewController | ListeningLogViewController.h/.m | Media listening history | UIViewController |
| WorkoutPickerViewController | WorkoutPickerViewController.h/.m | Historical workout selection picker | PopUpViewController |

## 7.5 Settings Controllers (11 controllers)

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| GoalsSettingsViewController | GoalsSettingsViewController.h/.m | Workout goals (duration, steps, distance, calories) | SettingsBaseController |
| AnnouncementsViewController | AnnouncementsViewController.h/.m | Voice announcement toggles (13 announcements) | SettingsBaseController |
| SoundSettingsViewController | SoundSettingsViewController.h/.m | Alert sounds (heart rate, speed warnings) | SettingsBaseController |
| SensorsSettingsViewController | SensorsSettingsViewController.h/.m | External sensors (Wahoo heart rate) | SettingsBaseController |
| PlayerSettingsViewController | PlayerSettingsViewController.h/.m | Audio player settings (skip, playback speed) | SettingsBaseController |
| VoiceCommandsViewController | VoiceCommandsViewController.h/.m | Customizable voice command phrases | SettingsBaseController |
| DataSettingsViewController | DataSettingsViewController.h/.m | Data export (JSON) | SettingsBaseController |
| StorageSettingViewController | StorageSettingViewController.h/.m | Storage management | SettingsBaseController |
| ThirdPartySettingsViewController | ThirdPartySettingsViewController.h/.m | Third-party integrations | SettingsBaseController |
| CreditsSettingsViewController | CreditsSettingsViewController.h/.m | App credits and attribution | SettingsBaseController |
| WorkoutSettingsTableViewController | WorkoutSettingsTableViewController.h/.m | Workout-specific settings | UITableViewController |

## 7.6 Utility/Base Controllers (7 controllers)

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| EmbeddedViewController | EmbeddedViewController.h/.m | Base class for embedded child controllers | UIViewController |
| SlidingBaseViewController | SlidingBaseViewController.h/.m | Base class for horizontal scrolling pages | EmbeddedViewController |
| BasePopupViewController | BasePopupViewController.h/.m | Base class for popup dialogs | UIViewController |
| PopUpViewController | PopUpViewController.h/.m | Generic popup | UIViewController |
| MJPopupViewController | MJPopupViewController.h/.m | Third-party popup library | UIViewController |
| UIViewController+MJPopupViewController | .h/.m | Category for popup presentation | (Category) |
| StaticDataTableViewController | StaticDataTableViewController.h/.m | Static table view base | UITableViewController |

## 7.7 Special Purpose Controllers (11 controllers)

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| OAuthViewController | OAuthViewController.h/.m | OAuth web view for Fitbit authentication | UIViewController |
| DisclaimerViewController | DisclaimerViewController.h/.m | App disclaimer/terms display | UIViewController |
| LocationServicesViewController | LocationServicesViewController.h/.m | Location permission prompts | UIViewController |
| RefreshProgressViewController | RefreshProgressViewController.h/.m | RSS refresh progress indicator | UIViewController |
| ReaderViewController | ReaderViewController.h/.m | Content reader | UIViewController |
| ArticleSelectionViewController | ArticleSelectionViewController.h/.m | Article selection | UIViewController |
| TextSelectionViewController | TextSelectionViewController.h/.m | Text selection | UIViewController |
| SocialFeedsViewController | SocialFeedsViewController.h/.m | Social media feeds | UIViewController |
| InlineMenuViewController | InlineMenuViewController.h/.m | Inline contextual menu | UIViewController |
| MediaPopupViewController | MediaPopupViewController.h/.m | Media item popup | UIViewController |
| SpeachFileGeneratorViewController | SpeachFileGeneratorViewController.h/.m | Text-to-speech file generation | UIViewController |
| LogViewController | LogViewController.h/.m | Debug log viewer | UIViewController |

**Total: 51 View Controllers**

---

# Part 8: Notification System

## 8.1 Workout Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `workoutStatusChanged` | WorkoutController | `@{@"status": NSNumber(BOOL)}` | DashboardViewController, WatchKitRequestHandler, JogmuzDashViewController |
| `workoutUpdatesAvailable` | WorkoutController | `@{@"stats": WorkoutStats}` | DashboardViewController, WorkoutMetricsPublisher, JogmuzDashViewController |
| `locationUpdate` | WorkoutMetricsManager, SimpleLocationMonitor | `@{@"currentLocation": CLLocation}` | WatchKitRequestHandler |

## 8.2 Player/Media Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `playerStatusChanged` | PlayerController | `@{@"playing": NSNumber(BOOL)}` | MediaCenterViewController, WatchKitRequestHandler |
| `podcastItemChanged` | MediaCenterViewController | `@{@"currentTitle": NSString}` | WatchKitRequestHandler |
| `rssRefreshCompleteNotification` | RSSEnclosureExtractorOperation | nil | SlidingPodcastViewController, MediaCenterViewController, PodcastTableViewController |
| `foregroundFetchCompletedForPodcast` | AppDelegate | nil | MediaCenterViewController |
| `backgroundFetchCompletedForPodcast` | AppDelegate | nil | JogmuzAppDelegate, JogPodAppDelegate |
| `kPlaylistChangeNotification` | PersistenceManager | nil | PlayerController |

## 8.3 Sensor/Hardware Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `WF_NOTIFICATION_SENSOR_CONNECTED` | WahooSensorController | userInfo dict | Sensor handlers |
| `WF_NOTIFICATION_SENSOR_DISCONNECTED` | WahooSensorController | nil | Sensor handlers |
| `WF_NOTIFICATION_DISCOVERED_SENSOR` | WahooSensorController | userInfo dict | DeviceDiscoveryVC |
| `WF_NOTIFICATION_SENSOR_HAS_DATA` | WahooSensorController, MockSensorController | heartRateStats dict | WorkoutController |
| `WF_NOTIFICATION_HW_CONNECTED` | WahooSensorController | nil | DeviceDiscoveryVC |
| `WF_NOTIFICATION_HW_DISCONNECTED` | WahooSensorController | nil | Hardware handlers |

## 8.4 Network/Reachability Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `kReachabilityChangedNotification` | Reachability | self (Reachability object) | Network observers |

## 8.5 Data Sync Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `USMStoreWillChangeNotification` | UbiquityStoreManager | nil | JogmuzAppDelegate, JogPodAppDelegate |
| `USMStoreDidChangeNotification` | UbiquityStoreManager | nil | Store observers |
| `USMStoreDidImportChangesNotification` | UbiquityStoreManager | changes dict | MediaCenterViewController, PodcastTableViewController |
| `UbiquityManagedStoreDidDetectCorruptionNotification` | NSError+UbiquityStoreManager | error dict | UbiquityStoreManager |
| `kMKiCloudSyncNotification` | MKiCloudSync | nil | iCloud observers |

## 8.6 Settings/Preferences Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `PreferenceChanges` | SettingsBaseController | self | SpeechCommandController, WorkoutMetricsPublisher |

## 8.7 UI/Gesture Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `shakeGestureEnded` | UIViewController+Shakeable | self | DashboardViewController |
| `kMarqueeLabelControllerRestartNotification` | MarqueeLabel | varies | MarqueeLabel instances |
| `kMarqueeLabelShouldLabelizeNotification` | MarqueeLabel | varies | MarqueeLabel instances |
| `kMarqueeLabelShouldAnimateNotification` | MarqueeLabel | varies | MarqueeLabel instances |
| `motionDetected` | MotionDetector | nil | Various controllers |

## 8.8 System Notifications Observed

| Notification Name | Observer |
|-------------------|----------|
| `AVPlayerItemDidPlayToEndTimeNotification` | PlayerController |
| `AVAudioSessionInterruptionNotification` | PlayerController |
| `UIApplicationDidEnterBackgroundNotification` | StatsMapViewController, MarqueeLabel |
| `UIApplicationDidBecomeActiveNotification` | StatsMapViewController, MarqueeLabel, UbiquityStoreManager |
| `UIKeyboardWillChangeFrameNotification` | NumberPadDoneBtn |
| `NSMetadataQueryDidUpdateNotification` | UbiquityStoreManager |
| `NSUbiquityIdentityDidChangeNotification` | UbiquityStoreManager |
| `NSUserDefaultsDidChangeNotification` | UbiquityStoreManager |
| `NSPersistentStoreCoordinatorStoresWillChangeNotification` | UbiquityStoreManager |
| `NSPersistentStoreCoordinatorStoresDidChangeNotification` | UbiquityStoreManager |

---

# Part 9: Operations System

All custom operations inherit from `TimedOperation` (extends `NSOperation`) to track request timing.

## 9.1 Weather Operations (2)

### WeatherInfoUpdateOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WeatherInfoUpdateOperation.h` / `.m`
- **Purpose**: Updates WorkoutHistory with weather data
- **Init**: `-initForUuid:temperature:humidity:wind:windDir:image:`
- **Priority**: NSOperationQueuePriorityVeryLow

### WeatherAlertUpdateOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WeatherAlertUpdateOperation.h` / `.m`
- **Purpose**: Updates WorkoutHistory with weather alerts
- **Init**: `-initForUuid:withType:description:effective:expiry:`
- **Priority**: NSOperationQueuePriorityVeryLow

## 9.2 Workout Data Operations (6)

### WorkoutHistoriesOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WorkoutHistoriesOperation.h` / `.m`
- **Purpose**: Fetches all workout history records
- **Output**: `-workoutHistories` (descending order by date)

### WorkoutReadingOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WorkoutReadingOperation.h` / `.m`
- **Purpose**: Processes raw location data into WorkoutReading objects
- **Init**: `-initForUuid:`
- **Filters**: Removes readings < 0.5s duration or acceleration > 5 m/s^2

### WorkoutReadingsForGraphOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WorkoutReadingsForGraphOperation.h` / `.m`
- **Purpose**: Prepares workout data for graphing with Douglas-Peucker reduction
- **Init**: `-initForUuid::field:`
- **Fields**: movingAverageSpeed, elevation, instantHeartRate, currentStepSize
- **Tolerance**: 0.15 (step size), 0.75 (other metrics)

### WorkoutStatsOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WorkoutStatsOperation.h` / `.m`
- **Purpose**: Computes comprehensive workout statistics
- **Init**: `-initForUuid:startAt:units:weight:speed:temerature:humidity:wind:windDirection:alerts:postalAddress:`
- **Output**: `-stats` returns WorkoutStats
- **Calorie Formula**: `CB = (((0.05 x G) + 0.95) x WKG + TF) x DRK x CFF`

### WorkoutUpdateMetricsOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WorkoutUpdateMetricsOperation.h` / `.m`
- **Purpose**: Persists new location reading during active workout
- **Init**: `-initForUuid:toLocation:fromLocation:totalSteps:speedStats:heartRate:counter:`
- **Special**: At 10th measurement triggers geocode lookup

### UpdateHeartRateOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/UpdateHeartRateOperation.h` / `.m`
- **Purpose**: Creates WorkoutLocation with heart rate data
- **Init**: `-initForUuid:speedStats:location:heartRate:steps:`

### WorkoutListeningLogsOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/WorkoutListeningLogsOperation.h` / `.m`
- **Purpose**: Retrieves listening logs for a workout
- **Init**: `-initForUuid:`
- **Output**: `-listeningLogs`

## 9.3 Map/Visualization Operations (1)

### PolylineFromCoordinateOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/PolylineFromCoordinateOperation.h` / `.m`
- **Purpose**: Generates MKPolyline and speed-based route overlays
- **Init**: `-initForUuid:`
- **Output**: `-polylineHolder` with routeLine, walking/jogging/running/racing routes, milestones
- **Speed Classification**: Walking < 4mph, Jogging 4-6mph, Running 6-10mph, Racing > 10mph

## 9.4 RSS/Podcast Operations (2)

### RSSEnclosureExtractorOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/RSSEnclosureExtractorOperation.h` / `.m`
- **Purpose**: Parses RSS feed to extract enclosure URLs
- **Init**: `-initWithIndex:backgroundFetch:delegate:`
- **Timeout**: 25s (background), 60s (foreground)
- **Delegate**: `RSSEnclosureSearchDelegate`

### PublicPodcastDownloadOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/PublicPodcastDownloadOperation.h` / `.m`
- **Purpose**: Downloads podcast data from URL
- **Init**: `-initWithURLRequest:andDelegate:`
- **Delegate**: `PublicPodcastDownloadDelegate`
- **MIGRATION NOTE**: Uses deprecated NSURLConnection

## 9.5 Maintenance Operations (2)

### PurgeOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/PurgeOperation.h` / `.m`
- **Purpose**: Auto-cleanup when storage exceeds threshold
- **Threshold**: 500,000 location records
- **Behavior**: Deletes oldest workout, preserves minimum 2 workouts

### AnnouncementListAssemblyOperation
**Files**: `/Users/andraslferenczi/jogpod/JogCast/AnnouncementListAssemblyOperation.h` / `.m`
- **Purpose**: Builds list of enabled voice announcements
- **Init**: `-initWithAnnouncementList:`

**Total: 14 Operations**

---

# Part 10: Category Extensions

## Application Categories (20+)

### Foundation Categories

| Category | File | Methods | Purpose |
|----------|------|---------|---------|
| NSData+Base64 | NSData+Base64.h/.m | `+dataWithBase64EncodedString:`, `-base64EncodedString` | Base64 encoding/decoding |
| NSDate+InternetDateTime | NSDate+InternetDateTime.h/.m | `+dateFromInternetDateTimeString:`, RFC822/RFC3339 parsing | Date parsing for RSS |
| NSDictionary+DictionaryWithObject | NSDictionary+DictionaryWithObject.h/.m | `+dictionaryWithObject:forKey:ifNotNil:` | Nil-safe dictionary creation |
| NSMutableArray+FixedSize | NSMutableArray+FixedSize.h/.m | `-addObjectPurgeOld:`, `-addObject:purgeAllExcept:` | Fixed-size array management |
| NSString+Base64StringFromData | NSString+Base64StringFromData.h/.m | `+base64StringFromData:` | Base64 string conversion |
| NSString+HTML | NSString+HTML.h/.m | `-stringByConvertingHTMLToPlainText`, `-stringByDecodingHTMLEntities` | HTML stripping |
| NSString+IsEmpty | NSString+IsEmpty.h/.m | `-isEmpty`, `-isEmptyIgnoringWhitespace` | Empty string checks |
| NSString+URLEncoding | NSString+URLEncoding.h/.m | `-utf8AndURLEncode`, `+getNonce` | URL encoding for OAuth |
| NSString+XMLEntities | NSString+XMLEntities.h/.m | `-stringByStrippingTags`, `-stringByDecodingXMLEntities` | XML entity handling |
| GTMNSString+HTML | GTMNSString+HTML.h/.m | `-gtm_stringByEscapingForHTML`, `-gtm_stringByUnescapingFromHTML` | Google Toolbox HTML utils |

### UIKit Categories

| Category | File | Methods | Purpose |
|----------|------|---------|---------|
| UIAlertView+AFEnhancement | UIAlertView+AFEnhancement.h/.m | Custom alert utilities | Enhanced alert views |
| UIButton+RoundedFlat | UIButton+RoundedFlat.h/.m | Rounded button styling | UI consistency |
| UIColor+RGB | UIColor+RGB.h/.m | `+colorWithR:G:B:A:`, `+tealColor`, `+navigationControllerColor`, `+podcastTableColor`, `+preferencesHeaderColor` | App color palette |
| UIImageView+AFExtension | UIImageView+AFExtension.h/.m | Image view utilities | Image handling |
| UIView+DisableAllControls | UIView+DisableAllControls.h/.m | `-enableAllControls:` | Batch control enable/disable |
| UIView+ImageSnapshot | UIView+ImageSnapshot.h/.m | View snapshot utilities | Image capture |
| UIViewController+MJPopupViewController | UIViewController+MJPopupViewController.h/.m | `-presentPopupViewController:`, `-dismissPopupViewController` | Popup presentation |
| UIViewController+Shakeable | UIViewController+Shakeable.h/.m | Shake gesture handling | Shake detection |

### AVFoundation Categories

| Category | File | Methods | Purpose |
|----------|------|---------|---------|
| AVQueuePlayer+AFAdditions | AVQueuePlayer+AFAdditions.h/.m | `-currentURL`, `-setVolume:`, `-goToPrevItem:`, `-reInitWithItems:`, `-playAtIndex::`, `-currentIndex:`, `-indexOf:playList:` | Queue player extensions |
| AVPlayerItem+AFAdditions | AVPlayerItem+AFAdditions.h/.m | Player item utilities | Item metadata access |

### UbiquityStoreManager Categories

| Category | File | Methods | Purpose |
|----------|------|---------|---------|
| NSError+UbiquityStoreManager | NSError+UbiquityStoreManager.h/.m | Error handling for iCloud | USM error utilities |
| NSURL+UbiquityStoreManager | NSURL+UbiquityStoreManager.h/.m | URL handling for iCloud | USM URL utilities |

---

# Part 11: Third-Party Libraries

## 11.1 Vendored Code (In-Repository)

### MWFeedParser
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/MWFeedParser.h` / `.m`, MWFeedInfo, MWFeedItem
- **Author**: Michael Waterfall
- **License**: MIT with diary/journal restriction
- **Purpose**: RSS/Atom feed parsing
- **Migration Path**: Replace with FeedKit (Swift) or custom RSS parser

### MJPopupViewController
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/MJPopupViewController.h` / `.m`, MJPopupBackgroundView
- **Purpose**: Modal popup presentation
- **License**: MIT
- **Migration Path**: Use native UIKit presentation styles or custom SwiftUI sheets

### MarqueeLabel
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/MarqueeLabel.h` / `.m`
- **Purpose**: Auto-scrolling text labels for long content
- **License**: MIT
- **Migration Path**: MarqueeLabel has Swift version, or use custom SwiftUI implementation

### PFGridView
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/PFGridView.h` / `.m`, PFGridViewCell, PFGridViewSection, PFGridIndexPath
- **Author**: YJ Park (PettyFun.com)
- **Purpose**: Grid-based data display
- **License**: Unknown (check source)
- **Migration Path**: Replace with UICollectionView or SwiftUI LazyVGrid

### DouglasPeukerDataReductionAlgorithm
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/DouglasPeukerDataReductionAlgorithm.h` / `.m`
- **Purpose**: Line simplification for graph data reduction
- **License**: Custom (in-house implementation)
- **Migration Path**: Port to Swift or use existing Swift implementations

### Base64Transcoder
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/Base64Transcoder.h` / `.m`
- **Purpose**: Base64 encoding/decoding for OAuth
- **License**: Unknown
- **Migration Path**: Use native Data base64 methods

### HMAC/SHA1
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/hmac.h` / `.m`
- **Author**: Jonathan Wight (OAuthConsumer)
- **License**: MIT
- **Purpose**: HMAC-SHA1 for OAuth 1.0a signing
- **Migration Path**: Use CommonCrypto or CryptoKit

### UbiquityStoreManager
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/UbiquityStoreManager/`
- **Author**: Maarten Billemont (Lyndir)
- **License**: Apache 2.0
- **Purpose**: iCloud Core Data sync management
- **Migration Path**: Replace with NSPersistentCloudKitContainer

### XMLDictionary
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/XMLDictionary.h` / `.m`
- **Author**: Nick Lockwood
- **Version**: 1.4
- **License**: Zlib
- **Purpose**: XML to NSDictionary conversion
- **Migration Path**: Update to latest version or use native XMLParser

### Reachability
- **Files**: `/Users/andraslferenczi/jogpod/JogCast/Reachability.h` / `.m`
- **Author**: Tony Million
- **License**: BSD
- **Purpose**: Network connectivity monitoring
- **Migration Path**: Replace with NWPathMonitor

## 11.2 Frameworks (External)

### CorePlot
- **Location**: `/Users/andraslferenczi/jogpod/JogCast/CorePlotHeaders/`
- **Purpose**: Scientific plotting and charting
- **License**: BSD
- **Migration Path**: Replace with Swift Charts (iOS 16+) or DGCharts

### OpenEars
- **Location**: `/Users/andraslferenczi/jogpod/Framework/OpenEars.framework/`
- **Purpose**: Speech recognition and TTS
- **License**: Commercial with restrictions
- **Migration Path**: Replace with SFSpeechRecognizer and AVSpeechSynthesizer
- **DEPRECATED**: OpenEars is no longer maintained

### WFConnector
- **Location**: `/Users/andraslferenczi/jogpod/WFConnector.framework/`
- **Purpose**: Wahoo Fitness sensor connectivity
- **License**: Wahoo proprietary
- **Migration Path**: Replace with Core Bluetooth for BLE heart rate sensors

### PebbleKit
- **Location**: `/Users/andraslferenczi/jogpod/PebbleKit.framework/`
- **Purpose**: Pebble smartwatch connectivity
- **License**: Pebble proprietary
- **Migration Path**: REMOVE (Pebble discontinued)

### MMWormhole (via SharedUtilities)
- **Location**: SharedUtilities framework
- **Purpose**: iOS-to-Watch communication
- **License**: MIT
- **Migration Path**: Replace with native WatchConnectivity (already partially migrated)

## 11.3 CocoaPods

### MACircleProgressIndicator
- **Podfile**: `/Users/andraslferenczi/jogpod/Podfile`
- **Target**: podmuz only
- **Version**: ~> 1.0.0
- **Purpose**: Circular progress indicator UI
- **Migration Path**: Replace with native ProgressView or custom SwiftUI implementation

---

# Part 12: Storyboards and XIBs

## Storyboards (3)

| File | Target | Purpose |
|------|--------|---------|
| `/Users/andraslferenczi/jogpod/JogCast/en.lproj/MainStoryboard.storyboard` | JogPod | Main app flow |
| `/Users/andraslferenczi/jogpod/JogCast/en.lproj/MainStoryboard-jogmuz.storyboard` | Jogmuz | Alternative UI flow |
| `/Users/andraslferenczi/jogpod/JogPod WatchKit App/Base.lproj/Interface.storyboard` | WatchKit | Watch interface |

## XIB Files (26)

| File | Associated Controller |
|------|----------------------|
| ArticleSelectionViewController.xib | ArticleSelectionViewController |
| ChartViewController.xib | ChartViewController |
| CombinedMetricsViewController.xib | CombinedMetricsViewController |
| DeviceDiscoveryVC.xib | DeviceDiscoveryVC |
| DisclaimerViewController.xib | DisclaimerViewController |
| GridViewController.xib | GridViewController |
| InlineMenuViewController.xib | InlineMenuViewController |
| Launch Screen.xib | Launch screen |
| ListeningLogViewController.xib | ListeningLogViewController |
| MediaCenterViewController.xib | MediaCenterViewController |
| MediaPopupViewController.xib | MediaPopupViewController |
| MetricsViewController.xib | MetricsViewController |
| OAuthViewController.xib | OAuthViewController |
| PlayItemViewController.xib | PlayItemViewController |
| PodcastDetailViewController.xib | PodcastDetailViewController |
| PodcastFilterViewController.xib | PodcastFilterViewController |
| PublicPodcastViewController.xib | PublicPodcastViewController |
| ReaderViewController.xib | ReaderViewController |
| RefreshProgressViewController.xib | RefreshProgressViewController |
| ReportViewController.xib | ReportViewController |
| SettingsViewController.xib | SettingsViewController |
| SlidingMetricsViewController.xib | SlidingMetricsViewController |
| SlidingPodcastViewController.xib | SlidingPodcastViewController |
| StatsMapViewController.xib | StatsMapViewController |
| TextSelectionViewController.xib | TextSelectionViewController |

**Migration Note**: All XIBs should be converted to SwiftUI views or programmatic UIKit.

---

# Part 13: Migration Strategy

## Phase 1: Foundation (Weeks 1-4)

### 1.1 Data Layer Migration
**Priority: CRITICAL**

Tasks:
1. Convert Core Data model to SwiftData
   - WorkoutHistory -> @Model class
   - WorkoutLocation -> @Model class
   - RSSEntity -> @Model class
   - RSSEntry -> @Model class (include all 14 attributes)
   - Preference -> @Model class (or migrate to @AppStorage)
   - WorkoutListeningLog -> @Model class

2. Write migration code for existing data
   - Export tool for existing Core Data stores
   - Import validation tests

3. Replace UbiquityStoreManager with CloudKit sync
   - Modern NSPersistentCloudKitContainer equivalent

**Invariants to Preserve:**
- WorkoutLocation ordering by time
- RSSEntry playlist ordering by index
- Preference key uniqueness

### 1.2 Persistence Manager Modernization
**Priority: CRITICAL**

Tasks:
1. Create Swift PersistenceManager using SwiftData
2. Implement same public interface for gradual migration
3. Add async/await support for all fetch operations

**Files to Replace:**
- `/Users/andraslferenczi/jogpod/JogCast/PersistenceManager.h` / `.m`
- `/Users/andraslferenczi/jogpod/JogCast/PersistenceDefaults.h` / `.m`
- `/Users/andraslferenczi/jogpod/JogCast/UbiquityStoreManager/`

## Phase 2: Core Features (Weeks 5-10)

### 2.1 Workout Tracking Migration
**Priority: HIGH**

Tasks:
1. Create WorkoutService actor (thread-safe singleton)
2. Migrate WorkoutMetricsManager to async/await
3. Replace NSOperationQueue with Swift Concurrency
4. Modernize CLLocationManager usage with async streams
5. Replace notification-based communication with Combine/async streams

**Files to Migrate:**
- WorkoutController -> WorkoutService (actor)
- WorkoutMetricsManager -> WorkoutMetricsManager (class with MainActor)
- GPSSignalAndHeartMonitorController -> LocationService

**Risk Areas:**
- Serial queue behavior MUST be preserved
- Location update batching timing
- Background location permissions

### 2.2 Audio Playback Migration
**Priority: HIGH**

Tasks:
1. Create AudioPlayerService using modern AVFoundation APIs
2. Implement queue management with AVQueuePlayer
3. Add background audio handling
4. Migrate MediaCache to async/await with URLSession
5. Flatten PlayerController/UniversalPlayerController hierarchy

**Files to Migrate:**
- UniversalPlayerController + PlayerController -> AudioPlayerService
- MediaCache -> MediaCacheService

**Risk Areas:**
- Background audio continuation
- Now Playing info synchronization
- Audio session category management

### 2.3 RSS Feed Migration
**Priority: MEDIUM**

Tasks:
1. Replace MWFeedParser with FeedKit or custom Swift parser
2. Implement async feed fetching
3. Add podcast artwork caching

**Files to Replace:**
- MWFeedParser.h/.m -> FeedParser (Swift)
- RSSEnclosureExtractorOperation -> FeedRefreshService

## Phase 3: Speech System (Weeks 11-13)

### 3.1 Text-to-Speech Migration
**Priority: MEDIUM**

Tasks:
1. Replace OpenEars FliteController with AVSpeechSynthesizer
2. Implement audio ducking with AVAudioSession
3. Preserve announcement timing and formatting

**Files to Replace:**
- JogTraceSpeech -> SpeechService

**Risk Areas:**
- Voice quality differences (FliteController Slt voice vs AVSpeechSynthesizer)
- Audio ducking timing

### 3.2 Voice Command Migration
**Priority: LOW**

Tasks:
1. Replace OpenEars Pocketsphinx with SFSpeechRecognizer
2. Implement command vocabulary
3. Handle authorization flows

**Files to Replace:**
- SpeechCommandController -> VoiceCommandService

**Risk Areas:**
- Always-on recognition not possible with SFSpeechRecognizer
- Network requirement for speech recognition

## Phase 4: WatchOS Migration (Weeks 14-18)

### 4.1 Watch Communication Migration
**Priority: HIGH**

Tasks:
1. Modernize WatchSessionManager with async/await
2. Remove MMWormhole legacy code completely
3. Implement WatchConnectivity 2.0+ patterns
4. Add complication support

**Files to Migrate:**
- WatchSessionManager.swift -> WatchConnectivityManager (modern Swift)
- WatchKitRequestHandler -> WatchMessageHandler
- SharedGlobals.swift -> REMOVE (MMWormhole)
- InterfaceController.swift -> Remove MMWormhole usage

### 4.2 WatchOS UI Migration
**Priority: MEDIUM**

Tasks:
1. Convert WKInterfaceController to SwiftUI Views
2. Implement SwiftUI navigation
3. Add workout session on watch (independent workout tracking)

**Files to Migrate:**
- InterfaceController -> MetricsView (SwiftUI)
- DashBoardInterfaceController -> DashboardView
- All interface controllers -> SwiftUI views

## Phase 5: External Integrations (Weeks 19-22)

### 5.1 HealthKit Migration
**Priority: HIGH**

Tasks:
1. Modernize HKStoreHelper with async/await
2. Add HKWorkoutBuilder support
3. Implement workout route tracking

**Files to Migrate:**
- HKStoreHelper.swift -> HealthKitService

### 5.2 Sensor Migration
**Priority: MEDIUM**

Tasks:
1. Replace WFConnector with Core Bluetooth
2. Implement BTLE heart rate profile
3. Add sensor discovery UI

**Files to Replace:**
- WahooSensorController -> BluetoothSensorService

### 5.3 Fitbit Migration
**Priority: MEDIUM**

Tasks:
1. Move hardcoded credentials to Keychain
2. Replace UIWebView with ASWebAuthenticationSession
3. Replace NSURLConnection with URLSession
4. Consider OAuth 2.0 migration

**Files to Migrate:**
- OAuth1Controller -> OAuth2Service or secure OAuth1Service

### 5.4 Deprecated Integrations
**Priority: LOW (Consider Removal)**

- PebbleController: Pebble is discontinued - REMOVE
- SocialIntegration: Social framework deprecated - replace with ShareLink

## Phase 6: UI Migration (Weeks 23-30)

### 6.1 SwiftUI Migration
**Priority: MEDIUM**

Tasks:
1. Create SwiftUI app structure
2. Migrate 51 view controllers to SwiftUI views
3. Implement navigation with NavigationStack
4. Add accessibility support
5. Decide on JogPod vs Jogmuz target unification

---

# Part 14: Risk Assessment

## High Risk Areas

1. **Core Data to SwiftData Migration**
   - Existing user data MUST be preserved
   - Migration MUST be tested with production-size datasets
   - Rollback strategy needed

2. **Audio Session Management**
   - Background playback MUST continue working
   - TTS ducking behavior MUST be preserved
   - Remote control events MUST work

3. **Watch Communication Timing**
   - Message reply handlers have timing constraints
   - Background task management is complex
   - MMWormhole to WCSession transition incomplete

4. **Speech Recognition Change**
   - OpenEars works offline; SFSpeechRecognizer needs network
   - May require feature limitation or removal

5. **Hardcoded Credentials**
   - Fitbit OAuth credentials in OAuth1Controller
   - Wunderground API key in WeatherInfo
   - Must be moved to secure storage before release

## Medium Risk Areas

1. **Location Accuracy**
   - Modern CLLocationManager APIs differ
   - Battery vs accuracy tradeoffs

2. **Notification Observers**
   - 25+ notification names in use
   - Need systematic replacement with Combine

3. **Thread Safety**
   - Current code uses manual synchronization
   - Swift concurrency model differs

4. **Dual Target Architecture**
   - JogPod vs Jogmuz decision needed
   - Different storyboards, different app delegates

## Low Risk Areas

1. **Unit Conversion**: Pure functions, easy to port
2. **Data Formatting**: String manipulation, straightforward
3. **UI Layout**: SwiftUI provides better layout system
4. **Category Extensions**: Direct Swift extension equivalents

---

# Part 15: Modern Replacements Reference

| Legacy Component | Modern Replacement |
|-----------------|-------------------|
| Core Data | SwiftData |
| UbiquityStoreManager | NSPersistentCloudKitContainer |
| NSOperationQueue | Swift Concurrency (async/await, actors) |
| NSNotificationCenter | Combine publishers or async streams |
| OpenEars FliteController | AVSpeechSynthesizer |
| OpenEars Pocketsphinx | SFSpeechRecognizer |
| MWFeedParser | FeedKit or custom Swift RSS parser |
| WFConnector | Core Bluetooth |
| PebbleKit | REMOVE (discontinued) |
| Social.framework | ShareLink (SwiftUI) |
| UIKit ViewControllers | SwiftUI Views |
| Storyboards/XIBs | SwiftUI declarative UI |
| Objective-C categories | Swift extensions |
| MMWormhole | WatchConnectivity (native) |
| CorePlot | Swift Charts (iOS 16+) or DGCharts |
| PFGridView | UICollectionView or LazyVGrid |
| MACircleProgressIndicator | ProgressView (SwiftUI) |
| UIWebView | WKWebView or ASWebAuthenticationSession |
| NSURLConnection | URLSession |
| DeviceDetector | Auto Layout / Size Classes |
| Reachability | NWPathMonitor |
| LogUtil | os_log (unified logging) |

---

# Appendix A: File Inventory by Category

## Core App Files (4)
- JogPodAppDelegate.h/.m
- JogmuzAppDelegate.h/.m
- AppQueueManager.h/.m

## Workout Feature (26+ files)
- WorkoutController, WorkoutMetricsManager, WorkoutStats, SpeedStats
- GPSSignalAndHeartMonitorController, WeatherInfo
- Measurement classes (HeartRateMeasurement, LocationMeasurement, SpeedMeasurement, TemperatureMeasurement)
- Operations (WorkoutUpdateMetricsOperation, WorkoutStatsOperation, etc.)
- WorkoutReading, DataPoint, XYCoords

## Audio Feature (15+ files)
- UniversalPlayerController, PlayerController
- UniversalQueuePlayer, UniversalPlayerItem
- PlayerPositionManager
- MediaCache, NetworkResourceLoader
- MWFeedParser, MWFeedInfo, MWFeedItem
- RSSEnclosureExtractorOperation

## Speech Feature (4 files)
- JogTraceSpeech
- SpeechCommandController

## Watch Feature (12+ files)
- iOS: WatchSessionManager, WatchKitRequestHandler
- WatchOS: ExtensionDelegate, InterfaceController, SharedGlobals
- DashBoardInterfaceController, PodcastInterfaceController, MetricsInterfaceController, MapInterfaceController, StatsInterfaceController, etc.

## Integrations Feature (10+ files)
- PebbleController, PebbleWorkoutSession
- WahooSensorController
- HKStoreHelper
- FitbitEventSubscriber, OAuth1Controller, Activities, Profile
- SocialIntegration

## Persistence Feature (14+ files)
- PersistenceManager, PersistenceDefaults
- Entity classes: WorkoutHistory, WorkoutLocation, WorkoutListeningLog, RSSEntity, RSSEntry, Preference
- UbiquityStoreManager (and categories)

## Pedometer System (7 files)
- StepCounter.h (protocol)
- PedometerFactory
- M7Pedometer, JAGPedometer
- LegacyPedometer
- MockPedometer

## UI Feature (51 ViewControllers + 26 XIBs + 3 Storyboards)
- See Part 7 for complete inventory

## Utilities (20+ files)
- UnitConverter, LogUtil, DeviceDetector, InputValidator
- Reachability, NetworkPresenceTester
- XMLDictionary, TimedOperation
- MotionDetector

## Category Extensions (20+ files)
- See Part 10 for complete inventory

## Third-Party Libraries (10+ packages)
- See Part 11 for complete inventory

---

# Appendix B: External API Dependencies

| API | Usage | Migration Notes |
|-----|-------|-----------------|
| Wunderground API | Weather data | API key hardcoded; consider OpenWeatherMap |
| Fitbit API | Activity tracking | OAuth 1.0a flow; credentials hardcoded |
| iTunes Search API | Podcast discovery | Still supported |

---

# Appendix C: Security Concerns

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|
| Hardcoded Fitbit Consumer Key | OAuth1Controller.m | HIGH | Move to Keychain |
| Hardcoded Fitbit Consumer Secret | OAuth1Controller.m | CRITICAL | Move to Keychain or server-side |
| Hardcoded Wunderground API Key | WeatherInfo.m | MEDIUM | Move to configuration |
| Deprecated UIWebView | OAuth1Controller.m | MEDIUM | Replace with ASWebAuthenticationSession |
| Deprecated NSURLConnection | OAuth1Controller.m, PublicPodcastDownloadOperation.m | LOW | Replace with URLSession |

---

*Document generated: January 2026*
*Based on analysis of JogPod codebase at commit 16c376d*
*Updated to include medium and low priority gap findings*
