# JogPod iOS App - Medium Priority Documentation

This document provides comprehensive documentation for utility classes, pedometer system, Fitbit support, view controllers, notifications, and operations classes.

---

## Table of Contents

1. [Utility Classes](#1-utility-classes)
2. [Pedometer System](#2-pedometer-system)
3. [Fitbit Support Classes](#3-fitbit-support-classes)
4. [View Controllers Inventory](#4-view-controllers-inventory)
5. [NSNotification Names](#5-nsnotification-names)
6. [Operations Classes](#6-operations-classes)

---

## 1. Utility Classes

### 1.1 LogUtil

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/LogUtil.h`
- `/Users/andraslferenczi/jogpod/JogCast/LogUtil.m`

**Purpose:**
Debug-only logging utility that persists log events to NSUserDefaults for later retrieval.

**Public Interface:**
```objc
@interface LogUtil : NSObject
+(void)logEvent: (NSString*)format,...;
+(NSDictionary*)eventHistory;
+(void)clearEventHistory;
@end
```

**Key Behaviors:**
- Logging is only active in DEBUG builds (wrapped in `#ifdef DEBUG`)
- Uses variadic arguments for printf-style formatting
- Timestamps events with format `hh.mm.ss.SSS`
- Stores logs in NSUserDefaults under key `runtimeLogs`
- Calls `[userDefaults synchronize]` after each log entry

**Dependencies:**
- Foundation framework

**Migration Notes:**
- NSUserDefaults `synchronize` is deprecated; consider removing as iOS handles this automatically
- Consider using Apple's unified logging system (os_log) for modern iOS versions
- The DEBUG-only compilation may hide issues in production

---

### 1.2 DeviceDetector

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/DeviceDetector.h`
- `/Users/andraslferenczi/jogpod/JogCast/DeviceDetector.m`

**Purpose:**
Detects specific iPhone models based on screen height.

**Public Interface:**
```objc
@interface DeviceDetector : NSObject
+(BOOL)isIPhone5;  // Screen height == 568
+(BOOL)isIPhone4;  // Screen height == 480
@end
```

**Key Behaviors:**
- Uses `[[UIScreen mainScreen] bounds].size.height` for detection
- iPhone 5 detection: height == 568 points
- iPhone 4 detection: height == 480 points

**Dependencies:**
- UIKit framework

**Migration Notes:**
- This approach is OBSOLETE for modern iOS development
- Does not detect iPhone 6 and later devices
- Replace with Auto Layout / Size Classes for responsive design
- If device capability detection is needed, use `UIDevice` or `UIScreen.nativeScale`

---

### 1.3 InputValidator

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/InputValidator.h`
- `/Users/andraslferenczi/jogpod/JogCast/InputValidator.m`

**Purpose:**
Validates numeric text field input, ensuring only digits and maximum value constraints.

**Public Interface:**
```objc
@interface InputValidator : NSObject
+(BOOL)textField:(UITextField *)textField
    shouldChangeNumericCharsInRange:(NSRange)range
    replacementString:(NSString *)string
    :(int)maxValue;
@end
```

**Key Behaviors:**
- Rejects any non-numeric characters (0-9 only)
- Enforces maximum value constraint (returns NO if value >= maxValue)
- Designed to be called from `textField:shouldChangeCharactersInRange:replacementString:` delegate method

**Dependencies:**
- UIKit framework

**Migration Notes:**
- Method signature uses unlabeled parameter (`:maxValue`) - consider adding label for clarity
- Max value check uses `<` not `<=` - values equal to maxValue are rejected
- Consider using modern approaches like UITextFieldDelegate with custom formatters

---

### 1.4 Reachability

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/Reachability.h`
- `/Users/andraslferenczi/jogpod/JogCast/Reachability.m`

**Purpose:**
Third-party library (Tony Million's Reachability) for monitoring network connectivity status.

**Public Interface:**
```objc
extern NSString *const kReachabilityChangedNotification;

typedef NS_ENUM(NSInteger, NetworkStatus) {
    NotReachable = 0,
    ReachableViaWiFi = 2,
    ReachableViaWWAN = 1
};

@interface Reachability : NSObject
@property (nonatomic, copy) NetworkReachable reachableBlock;
@property (nonatomic, copy) NetworkUnreachable unreachableBlock;
@property (nonatomic, assign) BOOL reachableOnWWAN;

+(Reachability*)reachabilityWithHostname:(NSString*)hostname;
+(Reachability*)reachabilityForInternetConnection;
+(Reachability*)reachabilityWithAddress:(const struct sockaddr_in*)hostAddress;
+(Reachability*)reachabilityForLocalWiFi;

-(BOOL)startNotifier;
-(void)stopNotifier;
-(BOOL)isReachable;
-(BOOL)isReachableViaWWAN;
-(BOOL)isReachableViaWiFi;
-(BOOL)isConnectionRequired;
-(NetworkStatus)currentReachabilityStatus;
@end
```

**Key Behaviors:**
- Uses SystemConfiguration framework's SCNetworkReachability APIs
- Posts `kReachabilityChangedNotification` on network status changes (on main queue)
- Uses GCD dispatch queues for async monitoring
- Block-based callbacks (`reachableBlock`, `unreachableBlock`)

**Dependencies:**
- SystemConfiguration framework
- Foundation framework

**Migration Notes:**
- Consider replacing with Apple's NWPathMonitor (Network framework, iOS 12+)
- The library handles both ARC and non-ARC environments
- Thread-safety: Callbacks are NOT on main thread by default (must dispatch UI updates)

---

### 1.5 NetworkPresenceTester

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/NetworkPresenceTester.h`
- `/Users/andraslferenczi/jogpod/JogCast/NetworkPresenceTester.m`

**Purpose:**
Simplified wrapper around Reachability for checking WiFi and network connectivity.

**Public Interface:**
```objc
@interface NetworkPresenceTester : NSObject
-(BOOL)wifiActive;
-(BOOL)connectedToNetwork;
@end
```

**Key Behaviors:**
- `wifiActive`: Returns YES only when connected via WiFi (NOT WWAN)
- `connectedToNetwork`: Returns YES for either WiFi OR WWAN connection

**Dependencies:**
- Reachability class

**Migration Notes:**
- Simple synchronous checks, creates new Reachability instance each time
- Consider caching Reachability instance for performance
- Replace with NWPathMonitor for modern iOS

---

### 1.6 XMLDictionary

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/XMLDictionary.h`
- `/Users/andraslferenczi/jogpod/JogCast/XMLDictionary.m`

**Purpose:**
Third-party library (Nick Lockwood's XMLDictionary v1.4) for parsing XML into NSDictionary structures.

**Public Interface:**
```objc
typedef NS_ENUM(NSInteger, XMLDictionaryAttributesMode) {
    XMLDictionaryAttributesModePrefixed = 0,
    XMLDictionaryAttributesModeDictionary,
    XMLDictionaryAttributesModeUnprefixed,
    XMLDictionaryAttributesModeDiscard
};

typedef NS_ENUM(NSInteger, XMLDictionaryNodeNameMode) {
    XMLDictionaryNodeNameModeRootOnly = 0,
    XMLDictionaryNodeNameModeAlways,
    XMLDictionaryNodeNameModeNever
};

@interface XMLDictionaryParser : NSObject <NSCopying>
+ (XMLDictionaryParser *)sharedInstance;

@property BOOL collapseTextNodes;  // defaults to YES
@property BOOL stripEmptyNodes;    // defaults to YES
@property BOOL trimWhiteSpace;     // defaults to YES
@property BOOL alwaysUseArrays;    // defaults to NO
@property BOOL preserveComments;   // defaults to NO
@property BOOL wrapRootNode;       // defaults to NO

- (NSDictionary *)dictionaryWithParser:(NSXMLParser *)parser;
- (NSDictionary *)dictionaryWithData:(NSData *)data;
- (NSDictionary *)dictionaryWithString:(NSString *)string;
- (NSDictionary *)dictionaryWithFile:(NSString *)path;
@end

// NSDictionary category for convenience
@interface NSDictionary (XMLDictionary)
+ (NSDictionary *)dictionaryWithXMLParser:(NSXMLParser *)parser;
+ (NSDictionary *)dictionaryWithXMLData:(NSData *)data;
+ (NSDictionary *)dictionaryWithXMLString:(NSString *)string;
+ (NSDictionary *)dictionaryWithXMLFile:(NSString *)path;

- (NSDictionary *)attributes;
- (NSDictionary *)childNodes;
- (NSString *)innerText;
- (NSString *)XMLString;
@end
```

**Key Behaviors:**
- Uses NSXMLParser internally with delegate pattern
- Shared instance pattern with thread-safe initialization
- Supports multiple modes for handling XML attributes
- Can reverse dictionary back to XML string

**Special Dictionary Keys:**
- `__attributes` - Contains element attributes
- `__comments` - Contains XML comments
- `__text` - Contains text content
- `__name` - Contains element name

**Dependencies:**
- Foundation framework

**Migration Notes:**
- Well-maintained third-party library
- Consider updating to latest version from GitHub
- For simple JSON-like structures, consider modern alternatives

---

### 1.7 TimedOperation

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/TimedOperation.h`
- `/Users/andraslferenczi/jogpod/JogCast/TimedOperation.m`

**Purpose:**
Base class for NSOperation subclasses that need to track when the operation was requested.

**Public Interface:**
```objc
@interface TimedOperation : NSOperation
-(id)init;
-(NSDate*)requestDate;
@end
```

**Key Behaviors:**
- Captures creation timestamp in `init`
- `requestDate` returns the timestamp when operation was created
- Used as base class for many workout and data operations

**Dependencies:**
- Foundation framework

**Migration Notes:**
- Simple utility base class, minimal changes needed
- Consider adding additional timing metrics (start time, end time, duration)

---

## 2. Pedometer System

### 2.1 Architecture Overview

The pedometer system uses a Factory pattern to provide the appropriate step counting implementation based on device capabilities:

```
PedometerFactory
    |
    +-- [Simulator] -> MockPedometer
    |
    +-- [M7/M8+ Chip] -> M7Pedometer -> JAGPedometer -> CMPedometer
    |
    +-- [Older Devices] -> nil (LegacyPedometer disabled)
```

### 2.2 StepCounter Protocol

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/StepCounter.h`

**Purpose:**
Protocol defining the contract for all pedometer implementations.

**Public Interface:**
```objc
typedef void (^StepCounterCompletion)(BOOL success, NSInteger steps, NSError *error);

@protocol StepCounter <NSObject>
-(void)startCount;
-(void)stopCount;
-(NSInteger)steps;
-(BOOL)isCounting;
@end
```

**Key Behaviors:**
- Defines four required methods for step counting
- Completion block typedef (commented out in actual use)

---

### 2.3 PedometerFactory

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/PedometerFactory.h`
- `/Users/andraslferenczi/jogpod/JogCast/PedometerFactory.m`

**Purpose:**
Factory class that creates the appropriate StepCounter implementation.

**Public Interface:**
```objc
@interface PedometerFactory : NSObject
+(id<StepCounter>)create;
@end
```

**Implementation Logic:**
```objc
+(id<StepCounter>)create {
#if TARGET_IPHONE_SIMULATOR
    return [MockPedometer new];
#else
    if ([M7Pedometer stepCountingAvailable]) {
        return [M7Pedometer new];
    }
    else {
        return Nil;  // LegacyPedometer disabled
    }
#endif
}
```

**Key Behaviors:**
- Returns MockPedometer for simulator builds
- Returns M7Pedometer for devices with M7/M8+ motion coprocessor
- Returns nil for older devices (LegacyPedometer is commented out)

**Migration Notes:**
- LegacyPedometer is disabled; older devices won't have step counting
- Consider adding CMPedometer availability check for iOS 8+ devices without M7

---

### 2.4 M7Pedometer

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/M7Pedometer.h`
- `/Users/andraslferenczi/jogpod/JogCast/M7Pedometer.m`

**Purpose:**
Pedometer implementation using Apple's CMPedometer (via JAGPedometer wrapper).

**Public Interface:**
```objc
@interface M7Pedometer : NSObject<StepCounter>
-(id)init;
+(BOOL)stepCountingAvailable;
@end
```

**Key Behaviors:**
- Wraps JAGPedometer for CoreMotion pedometer access
- `stepCountingAvailable` checks `[CMPedometer isStepCountingAvailable]`
- Tracks step count via CMPedometerData.numberOfSteps

**Dependencies:**
- CoreMotion framework
- JAGPedometer class

---

### 2.5 JAGPedometer

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/JAGPedometer.h`
- `/Users/andraslferenczi/jogpod/JogCast/JAGPedometer.m`

**Purpose:**
Wrapper class for CMPedometer providing block-based callbacks on main thread.

**Public Interface:**
```objc
typedef void (^JAGPedometerCompletion)(BOOL success, CMPedometerData *pedometerData, NSError *error);

@interface JAGPedometer : NSObject
- (BOOL)isStepCountingAvailable;
- (void)startPedometerUpdatesFromDate:(NSDate *)date completion:(JAGPedometerCompletion)completion;
- (void)getPedometerData:(NSDate *)startDate endDate:(NSDate *)enDate completion:(JAGPedometerCompletion)completion;
- (void)stopPedometerUpdates;
@end
```

**Key Behaviors:**
- Creates CMPedometer instance lazily when checking availability
- Dispatches completion callbacks to main queue
- Supports both live updates and historical queries

**Dependencies:**
- CoreMotion framework

---

### 2.6 LegacyPedometer

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/LegacyPedometer.h`
- `/Users/andraslferenczi/jogpod/JogCast/LegacyPedometer.m`

**Purpose:**
Accelerometer-based step detection for devices without motion coprocessor.

**Status:** DISABLED in PedometerFactory (returns nil instead)

**Public Interface:**
```objc
@interface LegacyPedometer : NSObject<StepCounter>
@end
```

**Implementation Details:**
- Uses CMMotionManager for accelerometer updates (0.01s interval)
- Implements step detection via:
  - Dot product of consecutive acceleration samples
  - Weighted moving average (WMA) of 10 samples
  - Threshold crossing detection
- Uses background dispatch queue for processing
- Configurable threshold via `kPedometerParameter` preference

**Internal Helper Class:**
```objc
@interface TriDimData : NSObject
@property float x, y, z;
+(TriDimData*)fromStruct:(CMAcceleration)acceleration;
-(float)squareRootOfSumOfSquaredCoords;
-(float)dotProduct:(TriDimData*)other3DData;
@end
```

**Dependencies:**
- CoreMotion framework
- PersistenceManager
- AppQueueManager
- NSMutableArray+FixedSize category

**Migration Notes:**
- Currently disabled; consider removing entirely
- Algorithm is custom implementation, may have accuracy issues
- High battery consumption due to continuous accelerometer polling

---

### 2.7 MockPedometer

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/MockPedometer.h`
- `/Users/andraslferenczi/jogpod/JogCast/MockPedometer.m`

**Purpose:**
Simulator-only implementation that generates random step counts.

**Public Interface:**
```objc
@interface MockPedometer : NSObject<StepCounter>
@end
```

**Key Behaviors:**
- `steps` property adds random 0-5 steps each time it's accessed
- Used only in simulator builds

---

## 3. Fitbit Support Classes

### 3.1 Activities

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/Activities.h`
- `/Users/andraslferenczi/jogpod/JogCast/Activities.m`

**Purpose:**
Model class representing Fitbit activity data.

**Public Interface:**
```objc
@interface Activities : NSObject
@property(strong, nonatomic) NSDate *date;
@property int activeMinutes;
@property int calories;
@property float distance;
@property int steps;
@property(strong, readonly) NSDate *time;

-(id)init;
-(float)distanceInMetric:(BOOL)isMetric;
@end
```

**Key Behaviors:**
- `time` property set to current date on init
- `distanceInMetric:` converts km to miles using factor 0.621371

---

### 3.2 Profile

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/Profile.h`
- `/Users/andraslferenczi/jogpod/JogCast/Profile.m`

**Purpose:**
Model class representing Fitbit user profile.

**Public Interface:**
```objc
@interface Profile : NSObject
@property(strong, nonatomic) NSString *displayName;
@property(strong, nonatomic) NSDate *dateOfBirth;
@property int weight;
@property BOOL isMetric;

-(float)weightInProperUnits:(BOOL)isMetric;
-(void)saveDateOfBirth:(NSString *)dateOfBirth;
-(void)saveWeight:(NSString*)weight;
@end
```

**Key Behaviors:**
- Weight stored in kg internally
- `weightInProperUnits:` converts kg to lb using factor 2.20462
- Date of birth parsed from string format "yyyy-MM-dd"

---

### 3.3 OAuth1Controller

**File Location:**
- `/Users/andraslferenczi/jogpod/JogCast/OAuth1Controller.h`
- `/Users/andraslferenczi/jogpod/JogCast/OAuth1Controller.m`

**Purpose:**
OAuth 1.0a authentication controller for Fitbit API.

**Public Interface:**
```objc
@interface OAuth1Controller : NSObject <UIWebViewDelegate>

- (void)loginWithWebView:(UIWebView *)webWiew
              completion:(void (^)(NSDictionary *oauthTokens, NSError *error))completion;

- (void)requestAccessToken:(NSString *)oauth_token_secret
                oauthToken:(NSString *)oauth_token
             oauthVerifier:(NSString *)oauth_verifier
                completion:(void (^)(NSError *error, NSDictionary *responseParams))completion;

+ (NSURLRequest *)preparedRequestForPath:(NSString *)path
                              parameters:(NSDictionary *)parameters
                              HTTPmethod:(NSString *)method
                              oauthToken:(NSString *)oauth_token
                             oauthSecret:(NSString *)oauth_token_secret;
@end
```

**Hardcoded Configuration:**
```objc
#define OAUTH_CALLBACK       @"https://pofajegyzetek.appspot.com/jogpod"
#define CONSUMER_KEY         @"12006c213d984133a3eeada7432b82bd"
#define CONSUMER_SECRET      @"183d0c5f184446cbb1ded82fc9706c4a"
#define AUTH_URL             @"https://api.fitbit.com/"
#define API_URL              @"https://api.fitbit.com/"
```

**OAuth Flow:**
1. `obtainRequestTokenWithCompletion:` - Step 1: Get request token
2. `authenticateToken:withCompletion:` - Step 2: User authorization via WebView
3. `requestAccessToken:...` - Step 3: Exchange verifier for access token

**Key Behaviors:**
- Uses HMAC-SHA1 signature method
- Handles OAuth header construction
- Uses NSURLConnection (deprecated) for network requests
- UIWebViewDelegate for handling OAuth callbacks

**Dependencies:**
- NSString+URLEncoding category
- hmac.h / Base64Transcoder.h for cryptographic operations

**Migration Notes:**
- CRITICAL: Contains hardcoded API credentials - should be moved to secure storage
- Uses deprecated UIWebView - must migrate to WKWebView or ASWebAuthenticationSession
- Uses deprecated NSURLConnection - migrate to NSURLSession
- Fitbit now recommends OAuth 2.0 - consider full migration

---

## 4. View Controllers Inventory

### 4.1 Main Dashboard

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| DashboardViewController | DashboardViewController.h/.m | Main workout dashboard with metrics, media controls, GPS/HR indicators | UIViewController |
| JogmuzDashViewController | JogmuzDashViewController.swift | Swift-based alternative dashboard (watchOS integration) | UIViewController |

**DashboardViewController Key Features:**
- IBOutlets: mediaCenterView, gpsLevelImage, heartMonitoringImage, metricsView, startStopWorkoutButton
- IBActions: startStopWorkoutButtonClicked, toggleSpeechRecognition, metricsLeftScrollClicked, metricsRightScrollClicked
- Protocols: WorkoutStatusDelegate, SpeechCommandDelegate, GPSSignalAndHeartMonitorDelegate, DisclaimerDelegate

### 4.2 Metrics Display

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| MetricsViewController | MetricsViewController.h/.m | Single metric display with value, unit, description | EmbeddedViewController |
| CombinedMetricsViewController | CombinedMetricsViewController.h/.m | Combined metrics display | UIViewController |
| SlidingMetricsViewController | SlidingMetricsViewController.h/.m | Scrollable metrics pages | SlidingBaseViewController |

### 4.3 Media/Podcast Controllers

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

### 4.4 Statistics & Reporting

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| StatsViewController | StatsViewController.h/.m | Statistics container with map, graph, grid views | UIViewController |
| StatsMapViewController | StatsMapViewController.h/.m | Workout route map display | EmbeddedViewController |
| StatsTabViewController | StatsTabViewController.h | Tab controller for stats views | (Protocol) |
| ChartViewController | ChartViewController.h/.m | CorePlot-based graphing | UIViewController |
| GridViewController | GridViewController.h/.m | Grid-based data display | UIViewController |
| ReportViewController | ReportViewController.h/.m | Workout summary report with metrics | EmbeddedViewController |
| ListeningLogViewController | ListeningLogViewController.h/.m | Media listening history | UIViewController |
| WorkoutPickerViewController | WorkoutPickerViewController.h/.m | Historical workout selection picker | PopUpViewController |

### 4.5 Settings Controllers

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| GoalsSettingsViewController | GoalsSettingsViewController.h/.m | Workout goals (duration, steps, distance, calories) | SettingsBaseController |
| AnnouncementsViewController | AnnouncementsViewController.h/.m | Voice announcement toggles (13 different announcements) | SettingsBaseController |
| SoundSettingsViewController | SoundSettingsViewController.h/.m | Alert sounds (heart rate, speed warnings) | SettingsBaseController |
| SensorsSettingsViewController | SensorsSettingsViewController.h/.m | External sensors (Wahoo heart rate) | SettingsBaseController |
| PlayerSettingsViewController | PlayerSettingsViewController.h/.m | Audio player settings (skip, playback speed) | SettingsBaseController |
| VoiceCommandsViewController | VoiceCommandsViewController.h/.m | Customizable voice command phrases | SettingsBaseController |
| DataSettingsViewController | DataSettingsViewController.h/.m | Data export (JSON) | SettingsBaseController |
| StorageSettingViewController | StorageSettingViewController.h/.m | Storage management | SettingsBaseController |
| ThirdPartySettingsViewController | ThirdPartySettingsViewController.h/.m | Third-party integrations | SettingsBaseController |
| CreditsSettingsViewController | CreditsSettingsViewController.h/.m | App credits and attribution | SettingsBaseController |
| WorkoutSettingsTableViewController | WorkoutSettingsTableViewController.h/.m | Workout-specific settings | UITableViewController |

### 4.6 Utility/Base Controllers

| Controller | File | Purpose | Parent Class |
|------------|------|---------|--------------|
| EmbeddedViewController | EmbeddedViewController.h/.m | Base class for embedded child controllers | UIViewController |
| SlidingBaseViewController | SlidingBaseViewController.h/.m | Base class for horizontal scrolling pages | EmbeddedViewController |
| BasePopupViewController | BasePopupViewController.h/.m | Base class for popup dialogs | UIViewController |
| PopUpViewController | PopUpViewController.h/.m | Generic popup | UIViewController |
| MJPopupViewController | MJPopupViewController.h/.m | Third-party popup library | UIViewController |
| UIViewController+MJPopupViewController | .h/.m | Category for popup presentation | (Category) |
| StaticDataTableViewController | StaticDataTableViewController.h/.m | Static table view base | UITableViewController |

### 4.7 Special Purpose Controllers

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

---

## 5. NSNotification Names

### 5.1 Workout Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `workoutStatusChanged` | WorkoutController | `@{@"status": NSNumber(BOOL)}` | DashboardViewController, WatchKitRequestHandler, JogmuzDashViewController |
| `workoutUpdatesAvailable` | (Various) | `@{@"stats": WorkoutStats}` | DashboardViewController, WorkoutMetricsPublisher, JogmuzDashViewController |
| `locationUpdate` | WorkoutMetricsManager, SimpleLocationMonitor | `@{@"currentLocation": CLLocation}` | WatchKitRequestHandler |

### 5.2 Player/Media Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `playerStatusChanged` | PlayerController | `@{@"playing": NSNumber(BOOL)}` | MediaCenterViewController, WatchKitRequestHandler |
| `podcastItemChanged` | MediaCenterViewController | `@{@"currentTitle": NSString}` | WatchKitRequestHandler |
| `rssRefreshCompleteNotification` | (RSS refresh system) | (Unknown) | SlidingPodcastViewController, MediaCenterViewController, PodcastTableViewController |
| `foregroundFetchCompletedForPodcast` | (Background fetch) | (Unknown) | MediaCenterViewController |
| `backgroundFetchCompletedForPodcast` | (Background fetch) | (Unknown) | JogmuzAppDelegate, JogPodAppDelegate |

### 5.3 Sensor/Hardware Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `WF_NOTIFICATION_SENSOR_CONNECTED` | WahooSensorController | (userInfo dict) | (Sensor handlers) |
| `WF_NOTIFICATION_SENSOR_DISCONNECTED` | WahooSensorController | nil | (Sensor handlers) |
| `WF_NOTIFICATION_DISCOVERED_SENSOR` | WahooSensorController | (userInfo dict) | DeviceDiscoveryVC |
| `WF_NOTIFICATION_SENSOR_HAS_DATA` | WahooSensorController, MockSensorController | (heartRateStats dict) | WorkoutController |
| `WF_NOTIFICATION_HW_CONNECTED` | WahooSensorController | nil | DeviceDiscoveryVC |
| `WF_NOTIFICATION_HW_DISCONNECTED` | WahooSensorController | nil | (Hardware handlers) |

### 5.4 Network/Reachability Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `kReachabilityChangedNotification` | Reachability | self (Reachability object) | (Network observers) |

### 5.5 Data Sync Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `USMStoreWillChangeNotification` | UbiquityStoreManager | nil | JogmuzAppDelegate, JogPodAppDelegate |
| `USMStoreDidChangeNotification` | UbiquityStoreManager | nil | (Store observers) |
| `USMStoreDidImportChangesNotification` | UbiquityStoreManager | (changes dict) | MediaCenterViewController, PodcastTableViewController |
| `UbiquityManagedStoreDidDetectCorruptionNotification` | NSError+UbiquityStoreManager | (error dict) | UbiquityStoreManager |
| `kMKiCloudSyncNotification` | MKiCloudSync | nil | (iCloud observers) |

### 5.6 Settings/Preferences Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `PreferenceChanges` | SettingsBaseController | self | SpeechCommandController, WorkoutMetricsPublisher |

### 5.7 UI/Gesture Notifications

| Notification Name | Posted By | Payload | Observers |
|-------------------|-----------|---------|-----------|
| `shakeGestureEnded` | UIViewController+Shakeable | self | DashboardViewController |
| `kMarqueeLabelControllerRestartNotification` | MarqueeLabel | (varies) | MarqueeLabel instances |
| `kMarqueeLabelShouldLabelizeNotification` | MarqueeLabel | (varies) | MarqueeLabel instances |
| `kMarqueeLabelShouldAnimateNotification` | MarqueeLabel | (varies) | MarqueeLabel instances |

### 5.8 System Notifications Observed

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

## 6. Operations Classes

All custom operations inherit from `TimedOperation` (which inherits from `NSOperation`) to track request timing.

### 6.1 Weather Operations

#### WeatherInfoUpdateOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/WeatherInfoUpdateOperation.h/.m`

**Purpose:** Updates workout history record with weather information.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid
      temperature:(float)currentTemperature
         humidity:(float)currentHumidity
             wind:(float)currentWind
          windDir:(NSString*)currentWindDir
            image:(NSString*)iconUrl;
```

**Key Behaviors:**
- Updates WorkoutHistory entity with: temperature, humidity, wind speed, weather icon URL
- Uses low priority queue (`NSOperationQueuePriorityVeryLow`)

---

#### WeatherAlertUpdateOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/WeatherAlertUpdateOperation.h/.m`

**Purpose:** Updates workout history with weather alerts.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid
         withType:(NSString*)alertType
      description:(NSString*)alertDescription
        effective:(NSString*)date
           expiry:(NSString*)expires;
```

**Key Behaviors:**
- Stores alert type, description, effective date, and expiry
- Uses low priority queue

---

### 6.2 Workout Data Operations

#### WorkoutHistoriesOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/WorkoutHistoriesOperation.h/.m`

**Purpose:** Fetches all workout history records.

**Public Interface:**
```objc
-(id)init;
-(NSArray*)workoutHistories;
```

**Key Behaviors:**
- Retrieves all workout histories in descending order (newest first)
- Results accessible via `workoutHistories` property after execution

---

#### WorkoutReadingOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/WorkoutReadingOperation.h/.m`

**Purpose:** Processes raw location data into workout readings with computed metrics.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid;
```

**Computed Metrics:**
- Instant speed, moving average speed, min/max speed
- Distance, duration, total distance, total duration
- Elevation changes, heart rate
- Step size (from distance/steps ratio over 10 measurements)

**Key Behaviors:**
- Filters out inaccurate readings (< 0.5s duration, unreasonable acceleration > 5 m/s^2)
- Uses MotionMetricsHelper for calculations
- Uses DouglasPeuckerDataReductionAlgorithm indirectly

---

#### WorkoutReadingsForGraphOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/WorkoutReadingsForGraphOperation.h/.m`

**Purpose:** Prepares workout data for graph visualization with data reduction.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid :(NSString*)field;
```

**Supported Fields:**
- `movingAverageSpeed` - Converted to proper units
- `elevation` - Converted to proper units
- `instantHeartRate` - Zero values filtered
- `currentStepSize` - Zero values filtered, converted to sub-units

**Key Behaviors:**
- Uses Douglas-Peucker algorithm for data point reduction
- Returns XYCoords with x (duration in minutes) and y (metric value)
- Different tolerance values for step size (0.15) vs other metrics (0.75)

---

#### WorkoutStatsOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/WorkoutStatsOperation.h/.m`

**Purpose:** Computes comprehensive workout statistics from location data.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid
          startAt:(NSDate*)startTime
            units:(BOOL)isMetric
           weight:(float)weight
            speed:(float)currentSpeed
       temerature:(TemperatureMeasurement*)currentTemperature
         humidity:(float)currentHumidity
             wind:(float)currentWind
    windDirection:(NSString*)currentWindDir
           alerts:(NSString*)currentAlerts
    postalAddress:(NSString*)address;

-(WorkoutStats*)stats;
```

**Computed Statistics:**
- Distance, duration, average/min/max speed, pace
- Elevation gain/loss, min/max/current elevation
- Steps, average step size
- Calories burned (using running calorie formula)
- Heart rate stats (current, min, max, average)
- Weather data integration

**Calorie Calculation Formula:**
```
CB = (((0.05 x G) + 0.95) x WKG + TF) x DRK x CFF
```
Where G = grade, WKG = weight in kg, TF = terrain factor, DRK = distance in km

---

#### WorkoutUpdateMetricsOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/WorkoutUpdateMetricsOperation.h/.m`

**Purpose:** Persists new location reading during active workout.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid
      toLocation:(CLLocation*)newLocation
     fromLocation:(CLLocation*)oldLocation
       totalSteps:(int)steps
       speedStats:(SpeedStats*)speedStats
        heartRate:(HeartRateMeasurement*)currentHeartRateMeasurement
          counter:(int)counterToSkipFirstMeasurement;
```

**Key Behaviors:**
- Skips first measurement (counter check)
- At 10th measurement, triggers geocode lookup for location
- Detects and removes speed outliers
- Associates heart rate if measurement is < 10 seconds old

---

#### WorkoutListeningLogsOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/WorkoutListeningLogsOperation.h/.m`

**Purpose:** Retrieves listening logs associated with a workout.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid;
-(NSArray*)listeningLogs;
```

---

#### UpdateHeartRateOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/UpdateHeartRateOperation.h/.m`

**Purpose:** Creates workout location record with heart rate data.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid
       speedStats:(SpeedStats*)speedStats
         location:(LocationMeasurement*)currentLocationMeasurement
        heartRate:(NSNumber*)heartRate
            steps:(int)steps;
```

---

### 6.3 Map/Visualization Operations

#### PolylineFromCoordinateOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/PolylineFromCoordinateOperation.h/.m`

**Purpose:** Generates MKPolyline and speed-based route overlays from workout data.

**Initialization:**
```objc
-(id)initForUuid:(NSString*)uuid;
-(PolylineHolder*)polylineHolder;
```

**PolylineHolder Properties:**
```objc
@property MKPolyline *routeLine;
@property CrumbPath* walkingRouteLine;   // < 4 mph
@property CrumbPath* joggingRouteLine;   // 4-6 mph
@property CrumbPath* runningRouteLine;   // 6-10 mph
@property CrumbPath* racingRouteLine;    // > 10 mph
@property CLLocation *startLocation;
@property CLLocation *endLocation;
@property NSArray *mileStones;           // Distance markers
```

**Speed Classification (mph):**
- Walking: < 4 mph
- Jogging: 4-6 mph
- Running: 6-10 mph
- Racing: > 10 mph

---

### 6.4 RSS/Podcast Operations

#### RSSEnclosureExtractorOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/RSSEnclosureExtractorOperation.h/.m`

**Purpose:** Parses RSS feed to extract podcast enclosure (media) URLs.

**Initialization:**
```objc
-(id)initWithIndex:(int)theIndex
    backgroundFetch:(BOOL)background
           delegate:(id<RSSEnclosureSearchDelegate>)theDelegate;
```

**Key Behaviors:**
- Uses MWFeedParser for RSS parsing
- Timeout: 25s for background, 60s for foreground
- Extracts first feed item only
- Creates/updates RSSEntity and RSSEntry Core Data objects
- Notifies delegate on main queue with serialized entity/entry dictionaries

**Protocol:**
```objc
@protocol RSSEnclosureSearchDelegate <NSObject>
- (void)searchCompletedForIndex:(int)index
                        message:(NSString*)message
                         entity:(NSDictionary*)entity
                          entry:(NSDictionary*)entry
                 backgroundFetch:(BOOL)background;
@end
```

---

#### PublicPodcastDownloadOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/PublicPodcastDownloadOperation.h/.m`

**Purpose:** Downloads podcast data from URL with delegate callbacks.

**Initialization:**
```objc
-(id)initWithURLRequest:(NSURLRequest*)request
            andDelegate:(id<PublicPodcastDownloadDelegate>)delegate;
```

**Protocol:**
```objc
@protocol PublicPodcastDownloadDelegate <NSObject>
- (void)operation:(PublicPodcastDownloadOperation*)operation didCompleteWithData:(NSData*)data;
- (void)operation:(PublicPodcastDownloadOperation*)operation didFailWithError:(NSError*)error;
@end
```

**Key Behaviors:**
- Uses NSURLConnection (deprecated)
- Runs CFRunLoop to make synchronous operation
- Exposes HTTP status code

---

### 6.5 Maintenance Operations

#### PurgeOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/PurgeOperation.h/.m`

**Purpose:** Automatic cleanup of old workout data when storage exceeds threshold.

**Key Behaviors:**
- Threshold: 500,000 location records
- Deletes oldest workout with locations (preserves empty workouts)
- Preserves at least 2 workouts
- Deletes all locations for the workout, then the workout history record

---

#### AnnouncementListAssemblyOperation

**File Location:** `/Users/andraslferenczi/jogpod/JogCast/AnnouncementListAssemblyOperation.h/.m`

**Purpose:** Builds list of enabled voice announcements based on user preferences.

**Initialization:**
```objc
-(id)initWithAnnouncementList:(NSMutableArray *)announcementList;
```

**Key Behaviors:**
- Reads announcement preferences from PersistenceDefaults
- Populates provided mutable array with enabled announcement keys

---

## Summary

This documentation covers the medium-priority components of the JogPod iOS application:

1. **Utility Classes**: Core infrastructure for logging, device detection, input validation, network monitoring, XML parsing, and operation timing.

2. **Pedometer System**: Factory-pattern implementation supporting M7/M8+ hardware pedometers, with legacy accelerometer-based detection (currently disabled) and simulator mocks.

3. **Fitbit Integration**: OAuth 1.0a authentication and data models for Fitbit activity sync (contains hardcoded credentials that need securing).

4. **View Controllers**: 50+ view controllers organized by function (dashboard, media, statistics, settings, utilities).

5. **Notification System**: 25+ custom notification names for inter-component communication, plus observation of system notifications.

6. **Operations Classes**: 14 NSOperation subclasses for background data processing, including workout stats computation, map visualization, RSS parsing, and data maintenance.

### Key Migration Concerns

1. **Deprecated APIs**: UIWebView, NSURLConnection need replacement
2. **Hardcoded Credentials**: OAuth secrets should be moved to secure storage
3. **Device Detection**: Screen-based detection is obsolete
4. **Legacy Pedometer**: Disabled but still present in codebase
5. **Thread Safety**: Some notifications not guaranteed to be on main thread
6. **Memory Management**: Manual retain/release code still present in some third-party libraries
