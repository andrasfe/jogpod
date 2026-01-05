# JogPod Equivalence Testing Strategy

## Executive Summary

This document defines a comprehensive testing strategy to validate that the rebuilt JogPod iOS application is functionally equivalent to the legacy system. Since the legacy system cannot be deployed alongside the new system for direct comparison, this strategy relies on:

1. **Specification-Based Oracles**: The archaeologist's behavioral documentation and migration specifications
2. **Golden Dataset Oracles**: Historical data patterns extracted from Core Data models
3. **Invariant Oracles**: Documented behavioral invariants that must hold in both systems
4. **Metamorphic Oracles**: Input/output relationships that must be preserved

The testing strategy covers all major feature areas: workout tracking, podcast playback, voice commands, TTS announcements, Watch communication, data persistence, and external integrations.

---

## Part 1: Definition of Equivalence

### 1.1 What "Equivalent" Means for JogPod

Functional equivalence is defined as:

1. **Behavioral Equivalence**: Given identical inputs, the new system produces outputs that are semantically equivalent to what the legacy system would have produced
2. **Data Equivalence**: Data structures, relationships, and persistence patterns match documented schemas
3. **Integration Equivalence**: External system interactions (HealthKit, Watch, Bluetooth) follow identical protocols
4. **User Experience Equivalence**: User-facing behaviors (announcements, notifications, UI updates) occur with equivalent timing and content

### 1.2 Equivalence Tolerances

| Metric | Tolerance | Rationale |
|--------|-----------|-----------|
| GPS Distance | +/- 1% | GPS accuracy variations |
| Speed Calculations | +/- 0.1 mph/kmh | Float precision differences |
| Calorie Calculations | +/- 5% | Algorithm approximation |
| TTS Announcement Timing | +/- 500ms | Audio session setup variance |
| Watch Message Delivery | +/- 2 seconds | Network latency |
| Playback Position Sync | +/- 1 second | Buffering differences |

---

## Part 2: Test Oracle Catalog

### 2.1 Golden Dataset Oracles

| Oracle ID | Source | Description | Test Data Requirements |
|-----------|--------|-------------|------------------------|
| GD-001 | Core Data Schema | `WorkoutHistory` entity structure | Export existing workout records |
| GD-002 | Core Data Schema | `WorkoutLocation` entity structure | Export location samples with HR, steps |
| GD-003 | Core Data Schema | `RSSEntity`/`RSSEntry` relationships | Export podcast/episode mappings |
| GD-004 | Core Data Schema | `Preference` key-value pairs | Export all preference records |
| GD-005 | NSUserDefaults | Media cache URL mappings | Export `entryToRSSMapping` dictionary |

### 2.2 Specification Oracles

| Oracle ID | Source File | Specification |
|-----------|-------------|---------------|
| SO-001 | `WorkoutStats.m` | Announcement string formats (e.g., "Current speed %0.1f %@") |
| SO-002 | `PersistenceDefaults.m` | Default preference values for all keys |
| SO-003 | `WatchKitRequestHandler.m` | Watch message response dictionary structures |
| SO-004 | `SpeechCommandController.m` | Voice command vocabulary (10 commands) |
| SO-005 | `WorkoutMetricsManager.m` | Batch commit frequency (every 20 readings) |

### 2.3 Invariant Oracles

| Oracle ID | Invariant | Verification Method |
|-----------|-----------|---------------------|
| INV-001 | `WorkoutHistory.workoutID` is UUID format | Regex validation |
| INV-002 | `WorkoutLocation.time` chronologically ordered | Sort verification |
| INV-003 | Heart rate values in range 0-255 BPM | Bounds checking |
| INV-004 | At most one `RSSEntry.currentInPlayer == YES` | Unique constraint test |
| INV-005 | `Preference.name` is unique | Primary key test |
| INV-006 | Steps monotonically increasing within workout | Sequence validation |
| INV-007 | Serial queue behavior in WorkoutMetricsManager | Concurrency tests |

### 2.4 Metamorphic Oracles

| Oracle ID | Relationship | Test Approach |
|-----------|--------------|---------------|
| MO-001 | Distance = sum of segment distances | Cumulative validation |
| MO-002 | Unit conversion consistency (metric/imperial) | Round-trip tests |
| MO-003 | Announcement rotation cycles through all enabled | Sequence testing |
| MO-004 | Watch state mirrors iOS app state | Bidirectional sync tests |

---

## Part 3: Test Categories by Feature Area

### 3.1 Workout Tracking Tests

#### 3.1.1 GPS and Location Processing

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WT-GPS-001 | Location update creates WorkoutLocation | CLLocation object | Persisted WorkoutLocation record | CRITICAL | GD-002 |
| WT-GPS-002 | First GPS reading ignored (cold-start filter) | Initial location | counterToSkipFirstMeasurement > 0 | HIGH | SO-005 |
| WT-GPS-003 | Location batch commit every 20 readings | 25 location updates | Commit called at readings 10, 30 | HIGH | SO-005 |
| WT-GPS-004 | Polyline generation from coordinates | WorkoutLocation array | MKPolyline with correct points | MEDIUM | GD-002 |
| WT-GPS-005 | Milestone markers at distance intervals | Long workout trace | Annotations at km/mile marks | MEDIUM | SO-001 |

**Test Data Requirements:**
- Sample GPS traces (GPX format) representing:
  - Short walk (< 1km, 10 minutes)
  - Medium run (5km, 30 minutes)
  - Long run (10km+, 60+ minutes)
  - GPS dropout scenarios (tunnel, buildings)
  - GPS cold start (first 30 seconds unreliable)

#### 3.1.2 Speed and Pace Calculations

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WT-SPD-001 | Current speed calculation | Sequential CLLocations | Speed in m/s converted to user units | CRITICAL | SO-001 |
| WT-SPD-002 | Average speed over workout | All workout locations | Cumulative average | CRITICAL | SO-001 |
| WT-SPD-003 | Peak speed detection | Speed sequence with peak | `isAtPeakSpeed` returns true | HIGH | INV-006 |
| WT-SPD-004 | Speed smoothing (rolling average) | Noisy speed data | Smoothed output | MEDIUM | SO-001 |
| WT-SPD-005 | Unit conversion (mph <-> kmh) | Speed in one unit | Correct conversion | HIGH | MO-002 |

**Acceptance Criteria:**
- Speed accuracy: +/- 0.1 mph (0.16 kmh)
- Rolling average window: 5 samples (verify from SpeedStats.m)
- Peak detection: sustained > average for 3+ readings

#### 3.1.3 Distance Calculations

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WT-DST-001 | Cumulative distance calculation | Sequential locations | Sum of segment distances | CRITICAL | MO-001 |
| WT-DST-002 | Distance unit display (km vs mi) | Distance + isMetric flag | Formatted string | HIGH | SO-001 |
| WT-DST-003 | Distance persistence in WorkoutStats | Completed workout | Stored distance value | CRITICAL | GD-001 |

**Acceptance Criteria:**
- Distance accuracy: +/- 1% of actual GPS distance
- Unit strings: "km" / "mi" (short), "kilometers" / "miles" (long)

#### 3.1.4 Heart Rate Processing

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WT-HR-001 | Heart rate storage with location | HR value + location | WorkoutLocation.heartRate set | HIGH | GD-002 |
| WT-HR-002 | HR value bounds validation | HR 0-255 | Stored value in range | HIGH | INV-003 |
| WT-HR-003 | HR batch commit every 20 readings | 25 HR updates | Commit called appropriately | MEDIUM | SO-005 |
| WT-HR-004 | Average heart rate calculation | Workout HR readings | Correct average | HIGH | SO-001 |
| WT-HR-005 | HR announcement format | HR value | "Heart rate %d" string | MEDIUM | SO-001 |

**Test Data Requirements:**
- Heart rate sequences simulating:
  - Resting HR (60-80 BPM)
  - Exercise HR (120-180 BPM)
  - HR spikes and drops
  - Sensor disconnection (0 values)

#### 3.1.5 Calories and Steps

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WT-CAL-001 | Calorie calculation | Duration + distance + weight | Estimated calories | HIGH | SO-001 |
| WT-STP-001 | Step count tracking | Pedometer steps | Monotonic increase | HIGH | INV-006 |
| WT-STP-002 | Average step size calculation | Steps + distance | stepSize = distance/steps | MEDIUM | SO-001 |
| WT-STP-003 | Run vs walk detection | Average step size | isARun true if stepSize < 300cm | MEDIUM | SO-001 |

**Acceptance Criteria:**
- Calorie accuracy: +/- 5% (based on MET formula)
- Step count: monotonically increasing, never negative

#### 3.1.6 Weather Integration

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WT-WTH-001 | Weather fetch on workout start | CLLocation coordinates | Temperature, humidity, wind | MEDIUM | GD-001 |
| WT-WTH-002 | Weather stored in WorkoutHistory | Weather API response | Persisted values | MEDIUM | GD-001 |
| WT-WTH-003 | Weather announcement format | Temperature + unit | "Temperature %.0f %@" | MEDIUM | SO-001 |
| WT-WTH-004 | Weather fetch failure handling | Network error | Workout continues, no crash | HIGH | INV-006 |

**Note:** Weather API (Wunderground) may be deprecated. Test should verify graceful degradation.

#### 3.1.7 Elevation Tracking

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WT-ELV-001 | Total elevation gain calculation | Locations with altitude | Cumulative gain | MEDIUM | SO-001 |
| WT-ELV-002 | Total elevation loss calculation | Locations with altitude | Cumulative loss | MEDIUM | SO-001 |
| WT-ELV-003 | Elevation unit conversion | Meters <-> feet | Correct conversion | MEDIUM | MO-002 |

---

### 3.2 Podcast Playback Tests

#### 3.2.1 RSS Feed Parsing

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| PP-RSS-001 | Parse standard RSS 2.0 feed | RSS feed URL | RSSEntity + RSSEntry records | CRITICAL | GD-003 |
| PP-RSS-002 | Extract audio enclosure URL | RSS item | enclosureMediaLink populated | CRITICAL | GD-003 |
| PP-RSS-003 | Parse Atom feed | Atom feed URL | Correctly parsed entities | HIGH | GD-003 |
| PP-RSS-004 | Handle malformed feed | Invalid XML | Graceful failure, no crash | HIGH | INV-006 |
| PP-RSS-005 | Feed refresh preserves existing entries | Re-fetch feed | Entries not duplicated | HIGH | INV-006 |

**Test Data Requirements:**
- Sample RSS feeds:
  - Standard RSS 2.0 with audio enclosures
  - Atom format feed
  - Feed with special characters in titles
  - Feed with missing enclosure URLs
  - Malformed XML feed

#### 3.2.2 Media Caching

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| PP-MCH-001 | Cache podcast episode | Episode URL + RSS URL | File in Caches directory | CRITICAL | GD-005 |
| PP-MCH-002 | Cached URL retrieval | Original URL | Local file URL | CRITICAL | GD-005 |
| PP-MCH-003 | Cache mapping persistence | Cache operation | entryToRSSMapping updated | HIGH | GD-005 |
| PP-MCH-004 | Clear cache operation | clearAllCache call | All cached files removed | HIGH | GD-005 |
| PP-MCH-005 | Cache download failure | Network error | completion(success=NO) | HIGH | INV-006 |
| PP-MCH-006 | Non-existent URL lookup | Invalid URL | Returns nil, no crash | HIGH | INV-006 |

**Test Data Requirements:**
- Sample audio files (MP3, M4A) for caching tests
- Mock network responses for download tests

#### 3.2.3 Playback Control

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| PP-PBC-001 | Play podcast episode | play() command | AVPlayer playing, notification posted | CRITICAL | SO-002 |
| PP-PBC-002 | Pause playback | pause() command | AVPlayer paused, notification posted | CRITICAL | SO-002 |
| PP-PBC-003 | Advance to next item | advanceToNextItem() | Next RSSEntry playing | HIGH | GD-003 |
| PP-PBC-004 | Go to previous item | goToPrevItem() | Previous RSSEntry playing | HIGH | GD-003 |
| PP-PBC-005 | Fast forward | fastForward() | Position advances by kForwardRewindTime | HIGH | SO-002 |
| PP-PBC-006 | Rewind | rewind() | Position decreases by kForwardRewindTime | HIGH | SO-002 |
| PP-PBC-007 | Seek to position | seekTo(seconds) | Playback at specified position | HIGH | SO-002 |
| PP-PBC-008 | Playback rate change | setRate(1.5) | Audio plays at 1.5x speed | MEDIUM | SO-002 |

**Acceptance Criteria:**
- Playback position accuracy: +/- 1 second
- Notification timing: within 100ms of state change
- Default fast forward/rewind: 3 seconds (kForwardRewindTime default)

#### 3.2.4 Playlist Management

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| PP-PLM-001 | Playlist ordering by index | Multiple RSSEntries | Sorted by index | HIGH | INV-004 |
| PP-PLM-002 | Current item tracking | Item change | Only one currentInPlayer=YES | HIGH | INV-004 |
| PP-PLM-003 | Position persistence on pause | Pause playback | Position saved to RSSEntry | HIGH | GD-003 |
| PP-PLM-004 | Resume from saved position | Play after pause | Resumes at saved position | HIGH | GD-003 |
| PP-PLM-005 | Playlist change notification | Playlist modified | kPlaylistChangeNotification posted | MEDIUM | SO-002 |

#### 3.2.5 Audio Session Management

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| PP-AUD-001 | Background playback continues | App backgrounded | Audio continues | CRITICAL | INV-006 |
| PP-AUD-002 | Now Playing info update | Track change | MPNowPlayingInfoCenter updated | HIGH | SO-002 |
| PP-AUD-003 | Remote control events | Lock screen controls | Play/pause/skip work | HIGH | SO-002 |
| PP-AUD-004 | Audio interruption handling | Phone call | Playback pauses, resumes after | HIGH | INV-006 |

---

### 3.3 Voice Command Tests

#### 3.3.1 Command Recognition

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| VC-REC-001 | "START WORKOUT" command | Audio "Start Workout" | Workout begins | HIGH | SO-004 |
| VC-REC-002 | "STOP WORKOUT" command | Audio "Stop Workout" | Workout ends | HIGH | SO-004 |
| VC-REC-003 | "PLAY PODCAST" command | Audio "Play Podcast" | Playback starts | HIGH | SO-004 |
| VC-REC-004 | "PAUSE PODCAST" command | Audio "Pause Podcast" | Playback pauses | HIGH | SO-004 |
| VC-REC-005 | "NEXT PODCAST" command | Audio "Next Podcast" | Advances to next | HIGH | SO-004 |
| VC-REC-006 | "PREVIOUS PODCAST" command | Audio "Previous Podcast" | Goes to previous | HIGH | SO-004 |
| VC-REC-007 | "FAST FORWARD" command | Audio "Fast Forward" | Skips forward | HIGH | SO-004 |
| VC-REC-008 | "REWIND PODCAST" command | Audio "Rewind Podcast" | Skips backward | HIGH | SO-004 |
| VC-REC-009 | "SHUTDOWN SPEECH" command | Audio "Shutdown Speech" | TTS disabled | HIGH | SO-004 |
| VC-REC-010 | "METRICS" command | Audio "Metrics" | Announces current stats | HIGH | SO-004 |

**Test Data Requirements:**
- Audio recordings of each command phrase
- Recordings with background noise
- Recordings with different accents/speeds

**Migration Note:** Legacy uses OpenEars/Pocketsphinx (offline). Modern replacement (SFSpeechRecognizer) requires network. Tests must account for this behavioral difference.

#### 3.3.2 Custom Command Configuration

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| VC-CFG-001 | Custom phrase for START WORKOUT | User-configured phrase | New phrase recognized | MEDIUM | SO-002 |
| VC-CFG-002 | Preference change triggers reload | Preference update | Language model regenerated | MEDIUM | SO-004 |

---

### 3.4 TTS Announcement Tests

#### 3.4.1 Announcement Content

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| TTS-CNT-001 | Current speed announcement | WorkoutStats | "Current speed X.X miles per hour" | HIGH | SO-001 |
| TTS-CNT-002 | Average speed announcement | WorkoutStats | "Average speed X.X kilometers per hour" | HIGH | SO-001 |
| TTS-CNT-003 | Heart rate announcement | WorkoutStats (HR > 0) | "Heart rate XXX" | HIGH | SO-001 |
| TTS-CNT-004 | Heart rate nil when zero | WorkoutStats (HR = 0) | Returns nil (no announcement) | HIGH | SO-001 |
| TTS-CNT-005 | Calories announcement | WorkoutStats | "Calories burned XXX" | HIGH | SO-001 |
| TTS-CNT-006 | Distance announcement | WorkoutStats | "Distance X.X miles" | HIGH | SO-001 |
| TTS-CNT-007 | Uphill announcement | WorkoutStats | "Uphill XXX feet" | MEDIUM | SO-001 |
| TTS-CNT-008 | Downhill announcement | WorkoutStats | "Downhill XXX meters" | MEDIUM | SO-001 |
| TTS-CNT-009 | Duration announcement | WorkoutStats | "Duration XX minutes" | HIGH | SO-001 |
| TTS-CNT-010 | Temperature announcement | WorkoutStats | "Temperature XX FAHRENHEIT" | MEDIUM | SO-001 |
| TTS-CNT-011 | Temperature nil when no data | No weather data | Returns nil | MEDIUM | SO-001 |

**Acceptance Criteria:**
- Announcement format must match legacy exactly (verified against WorkoutStats.m)
- Unit strings must match (km/mi, kmh/mph, m/ft, C/F)

#### 3.4.2 Announcement Behavior

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| TTS-BHV-001 | Audio ducking during speech | TTS starts | Podcast volume reduced | HIGH | INV-006 |
| TTS-BHV-002 | Audio restore after speech | TTS ends | Podcast volume restored | HIGH | INV-006 |
| TTS-BHV-003 | Speech queue serialization | Multiple announcements | Spoken in order, not overlapping | HIGH | INV-007 |
| TTS-BHV-004 | Announcement rotation | Multiple announcements | Cycles through enabled metrics | HIGH | MO-003 |
| TTS-BHV-005 | Disabled announcement skip | kAnnounceVoice = NO | No speech output | HIGH | SO-002 |
| TTS-BHV-006 | Null text handling | say(nil) | No crash, no output | HIGH | INV-006 |

**Migration Note:** Legacy uses OpenEars FliteController (Slt voice). Modern replacement (AVSpeechSynthesizer) will have different voice characteristics. Voice quality difference is acceptable; announcement content and timing must match.

---

### 3.5 Watch Communication Tests

#### 3.5.1 Message Handling

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WC-MSG-001 | openDashBoard request | Message from Watch | Dict with workout/podcast status | CRITICAL | SO-003 |
| WC-MSG-002 | openMetrics request | Message from Watch | Dict with workout status, publisher count | HIGH | SO-003 |
| WC-MSG-003 | openPodcast request | Message from Watch | Dict with current title, isPlaying | HIGH | SO-003 |
| WC-MSG-004 | openMap request | Message from Watch | Location monitoring started | HIGH | SO-003 |
| WC-MSG-005 | openStats request | Message from Watch | Route image generation triggered | MEDIUM | SO-003 |

**Response Dictionary Structures (from WatchKitRequestHandler.m):**

```
openDashBoard:
{
  "workoutInProgress": 0|1,
  "podcastPlaying": 0|1,
  "podcastTitle": String,
  "initialized": Bool,
  "noOfWorkouts": Int
}

openMetrics:
{
  "workoutInProgress": 0|1,
  "publisherCount": Int
}

openPodcast:
{
  "currentTitle": String,
  "isPlaying": 0|1
}
```

#### 3.5.2 Push Notifications to Watch

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WC-PSH-001 | Workout status push | Workout start/stop | "workoutStatus" message sent | HIGH | SO-003 |
| WC-PSH-002 | Podcast item change push | Track change | "podcastUpdate" message sent | HIGH | SO-003 |
| WC-PSH-003 | Player status push | Play/pause | "playerUpdate" message sent | HIGH | SO-003 |
| WC-PSH-004 | Workout metrics push | Location update | "workoutUpdate" message sent | HIGH | SO-003 |
| WC-PSH-005 | Location update push | GPS reading | "locationUpdate" message sent | HIGH | SO-003 |
| WC-PSH-006 | currentView filtering | Message while in wrong view | Message not sent | MEDIUM | SO-003 |

#### 3.5.3 Session Management

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| WC-SES-001 | Session activation | App launch | WCSession.activateSession called | CRITICAL | INV-006 |
| WC-SES-002 | Reachability handling | Session unreachable | Operations continue on iOS | HIGH | INV-006 |
| WC-SES-003 | Reply handler completion | Valid request | Response within timeout | HIGH | INV-006 |

---

### 3.6 Data Persistence Tests

#### 3.6.1 Core Data Entity Tests

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| DP-ENT-001 | WorkoutHistory creation | New workout | UUID assigned, startTime set | CRITICAL | GD-001 |
| DP-ENT-002 | WorkoutLocation creation | Location sample | Linked to WorkoutHistory by workoutID | CRITICAL | GD-002 |
| DP-ENT-003 | WorkoutListeningLog creation | Podcast during workout | Linked to workout by workoutID | HIGH | GD-001 |
| DP-ENT-004 | RSSEntity creation | New podcast | Unique link, title populated | CRITICAL | GD-003 |
| DP-ENT-005 | RSSEntry creation | New episode | Linked to RSSEntity, index set | CRITICAL | GD-003 |
| DP-ENT-006 | Preference creation | New preference | Unique name, value stored | HIGH | INV-005 |

#### 3.6.2 Relationship Integrity

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| DP-REL-001 | RSSEntry.belongsTo relationship | Entry with parent | Valid RSSEntity reference | HIGH | GD-003 |
| DP-REL-002 | RSSEntity.contains inverse | Entity with entries | All related entries accessible | HIGH | GD-003 |
| DP-REL-003 | Orphan entry handling | Entry with nil belongsTo | No crash on access | MEDIUM | INV-006 |

#### 3.6.3 Migration Tests

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| DP-MIG-001 | Core Data to SwiftData migration | Existing database | All records migrated | CRITICAL | GD-001 |
| DP-MIG-002 | Workout history preservation | Production data | No data loss | CRITICAL | GD-001 |
| DP-MIG-003 | Podcast/episode preservation | Production data | No data loss | CRITICAL | GD-003 |
| DP-MIG-004 | Preference preservation | Production data | All preferences migrated | HIGH | SO-002 |
| DP-MIG-005 | Location data preservation | Production data | All GPS samples migrated | CRITICAL | GD-002 |

#### 3.6.4 Preference Default Tests

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| DP-PRF-001 | Missing bool preference | Non-existent key | Default from PersistenceDefaults | HIGH | SO-002 |
| DP-PRF-002 | Missing int preference | Non-existent key | Default from PersistenceDefaults | HIGH | SO-002 |
| DP-PRF-003 | Missing string preference | Non-existent key | Default from PersistenceDefaults | HIGH | SO-002 |

**Default Values to Test (from PersistenceDefaults.m):**

| Key | Type | Default Value |
|-----|------|---------------|
| kWeight | int | 167 |
| kForwardRewindTime | int | 3 |
| kAge | int | 100 |
| kMinHeartRate | int | 40 |
| kMaxHeartRate | int | 90 |
| kPedometerParameter | int | 995 |
| kBackgroundFetchInterval | int | 30 |
| kPlayerRate | int | 100 |
| kDistanceGoal | int | 3 |
| kCaloriesGoal | int | 400 |
| kStepsGoal | int | 10000 |
| kDurationGoal | int | 30 |
| kAnnounceVoice | bool | YES |
| kAnnounceCurrentSpeed | bool | YES |
| kAnnounceAvgSpeed | bool | YES |
| kAnnounceCaloriesBurned | bool | YES |
| kAnnounceDuration | bool | YES |
| kAnnounceDistance | bool | YES |
| kMetric | bool | NO |
| kStartWorkoutText | string | "START WORKOUT" |
| kStopWorkoutText | string | "STOP WORKOUT" |
| kPlayPodcastText | string | "PLAY PODCAST" |
| kPausePodcastText | string | "PAUSE PODCAST" |
| kSkipToNextText | string | "NEXT PODCAST" |
| kSkipToPreviousText | string | "PREVIOUS PODCAST" |
| kFastForwardText | string | "FAST FORWARD" |
| kRewindPodcastText | string | "REWIND PODCAST" |
| kShutdownVoiceText | string | "SHUTDOWN SPEECH" |

---

### 3.7 Background Mode Tests

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| BG-001 | Location updates in background | App backgrounded during workout | GPS continues | CRITICAL | INV-006 |
| BG-002 | Audio playback in background | App backgrounded during playback | Audio continues | CRITICAL | INV-006 |
| BG-003 | Background fetch execution | System trigger | Feed refresh occurs | HIGH | SO-002 |
| BG-004 | Watch background task | Long-running watch op | UIBackgroundTask started | HIGH | SO-003 |

---

### 3.8 Integration Tests

#### 3.8.1 HealthKit Integration

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| HK-001 | HealthKit authorization request | First launch | Permission dialog shown | CRITICAL | INV-006 |
| HK-002 | Workout save to HealthKit | Completed workout | HKWorkout created | HIGH | SO-003 |
| HK-003 | Workout data accuracy | WorkoutStats | Matching calories, distance, duration | HIGH | MO-004 |
| HK-004 | HealthKit unavailable handling | iPad/unsupported device | Graceful degradation | MEDIUM | INV-006 |

#### 3.8.2 Bluetooth Sensor Integration

| Test ID | Description | Input | Expected Output | Priority | Oracle |
|---------|-------------|-------|-----------------|----------|--------|
| BT-001 | Heart rate sensor discovery | Bluetooth LE scan | Wahoo sensors found | HIGH | INV-006 |
| BT-002 | Sensor connection | Connect command | WF_NOTIFICATION_SENSOR_CONNECTED | HIGH | SO-002 |
| BT-003 | Heart rate data reception | Sensor broadcast | WF_NOTIFICATION_SENSOR_HAS_DATA | HIGH | SO-002 |
| BT-004 | Sensor disconnection handling | Bluetooth disconnect | lastReading reset to 0 | HIGH | INV-006 |

**Migration Note:** Legacy uses WFConnector framework. Modern replacement will use Core Bluetooth. Protocol-level behavior must match.

---

## Part 4: Test Data Requirements

### 4.1 GPS Trace Data

| Dataset ID | Description | Format | Source |
|------------|-------------|--------|--------|
| GPS-001 | Urban run with GPS dropouts | GPX | Generated/recorded |
| GPS-002 | Trail run with elevation changes | GPX | Generated/recorded |
| GPS-003 | Short walk baseline | GPX | Generated/recorded |
| GPS-004 | Long marathon-length run | GPX | Generated/recorded |
| GPS-005 | GPS cold-start sequence | GPX | Generated/recorded |

### 4.2 Core Data Sample Databases

| Dataset ID | Description | Contents |
|------------|-------------|----------|
| CD-001 | Empty database | Fresh install state |
| CD-002 | Single workout | 1 WorkoutHistory, ~100 WorkoutLocations |
| CD-003 | Production-scale | 50+ workouts, 10+ podcasts, 100+ episodes |
| CD-004 | Corrupted/edge cases | Missing relationships, orphan entries |

### 4.3 RSS Feed Samples

| Dataset ID | Description | Format |
|------------|-------------|--------|
| RSS-001 | Standard RSS 2.0 podcast | XML |
| RSS-002 | Atom format podcast | XML |
| RSS-003 | Malformed XML | XML |
| RSS-004 | Feed with special characters | XML |
| RSS-005 | Feed without enclosures | XML |

### 4.4 Audio Samples

| Dataset ID | Description | Format |
|------------|-------------|--------|
| AUD-001 | Short podcast episode | MP3 (30 seconds) |
| AUD-002 | Full-length episode | MP3 (30 minutes) |
| AUD-003 | M4A format episode | M4A |
| AUD-004 | Voice command recordings | WAV/M4A |

### 4.5 Heart Rate Data

| Dataset ID | Description | Format |
|------------|-------------|--------|
| HR-001 | Resting HR sequence | JSON array |
| HR-002 | Exercise HR sequence | JSON array |
| HR-003 | HR with dropouts | JSON array |

---

## Part 5: Validation Workflow

### 5.1 Phase 1: Unit Test Validation (Weeks 1-2)

Execute all unit-level equivalence tests for:
- [ ] WorkoutStats calculations and formatting
- [ ] SpeedStats rolling average and peak detection
- [ ] UnitConverter conversions
- [ ] PersistenceDefaults default values
- [ ] Announcement string generation

**Gate Criteria:** 100% of unit tests passing

### 5.2 Phase 2: Component Test Validation (Weeks 3-4)

Execute component-level tests for:
- [ ] WorkoutMetricsManager location processing
- [ ] PlayerController playback control
- [ ] MediaCache caching operations
- [ ] WatchSessionManager message handling

**Gate Criteria:** 95% of component tests passing, all CRITICAL tests passing

### 5.3 Phase 3: Integration Test Validation (Weeks 5-6)

Execute integration tests for:
- [ ] Workout tracking end-to-end flow
- [ ] Podcast playback end-to-end flow
- [ ] Watch communication round-trip
- [ ] HealthKit workout save

**Gate Criteria:** 90% of integration tests passing, all CRITICAL tests passing

### 5.4 Phase 4: System Test Validation (Weeks 7-8)

Execute full system tests:
- [ ] Complete workout scenario
- [ ] Complete podcast listening scenario
- [ ] Background mode scenarios
- [ ] Data migration validation

**Gate Criteria:** All CRITICAL and HIGH priority tests passing

### 5.5 Phase 5: User Acceptance Validation (Week 9)

Manual validation with domain experts:
- [ ] Voice command recognition accuracy
- [ ] TTS announcement quality (acceptable voice difference)
- [ ] Watch app usability
- [ ] Overall user experience parity

---

## Part 6: Risk Assessment and Prioritization

### 6.1 Risk Matrix

| Feature Area | Complexity | User Impact | Data Risk | Priority |
|--------------|------------|-------------|-----------|----------|
| Workout Tracking | HIGH | CRITICAL | HIGH | P0 |
| Data Persistence/Migration | HIGH | CRITICAL | CRITICAL | P0 |
| Podcast Playback | MEDIUM | HIGH | MEDIUM | P1 |
| Watch Communication | HIGH | MEDIUM | LOW | P1 |
| TTS Announcements | MEDIUM | MEDIUM | LOW | P2 |
| Voice Commands | HIGH | MEDIUM | LOW | P2 |
| HealthKit Integration | MEDIUM | MEDIUM | MEDIUM | P2 |
| Bluetooth Sensors | HIGH | LOW | LOW | P3 |

### 6.2 Critical Path Tests

These tests MUST pass before declaring equivalence:

1. **DP-MIG-001**: Core Data to SwiftData migration (data preservation)
2. **WT-GPS-001**: Location update creates WorkoutLocation
3. **WT-DST-001**: Cumulative distance calculation
4. **PP-PBC-001**: Play podcast episode
5. **PP-AUD-001**: Background playback continues
6. **WC-MSG-001**: openDashBoard request handling
7. **BG-001**: Location updates in background

### 6.3 High-Risk Areas Requiring Extra Attention

1. **Thread Safety Migration**: Legacy uses NSOperationQueue with maxConcurrentOperationCount=1. Swift concurrency (actors) must preserve serial behavior.

2. **Audio Session Management**: Complex interaction between TTS, podcast playback, and system audio. Audio ducking timing is critical.

3. **Watch Communication Timing**: Message reply handlers have timing constraints. Background task management must be correct.

4. **Speech Recognition Behavioral Change**: OpenEars works offline; SFSpeechRecognizer requires network. This is a known behavioral difference that may require feature limitation documentation.

---

## Part 7: Automated vs Manual Testing

### 7.1 Automated Test Opportunities

| Category | Automation Level | Framework |
|----------|-----------------|-----------|
| Unit calculations (speed, distance, calories) | 100% | XCTest |
| String formatting (announcements) | 100% | XCTest |
| Data persistence CRUD | 100% | XCTest |
| Preference defaults | 100% | XCTest |
| Watch message structure validation | 90% | XCTest |
| Playback state transitions | 80% | XCTest |
| Core Data migration | 80% | XCTest |

### 7.2 Manual Testing Required

| Category | Reason | Approach |
|----------|--------|----------|
| GPS accuracy in field | Real-world conditions | Field testing with known routes |
| Voice command recognition | Human speech variance | Multiple testers, varied environments |
| TTS quality assessment | Subjective evaluation | A/B comparison with legacy recordings |
| Watch physical interaction | Hardware dependency | Device testing |
| Bluetooth sensor pairing | Hardware dependency | Real sensor testing |
| Background mode edge cases | System-level behavior | Extended runtime testing |

### 7.3 UI Test Opportunities

| Screen | Automation Feasibility | Notes |
|--------|------------------------|-------|
| Workout dashboard | HIGH | State verification via accessibility |
| Podcast list | HIGH | Navigation and selection |
| Settings screens | HIGH | Preference toggle verification |
| Map view | MEDIUM | Annotation presence verification |
| Watch app | LOW | Requires Watch simulator limitations |

---

## Part 8: Gap Register

### 8.1 Untestable Behaviors

| Gap ID | Description | Reason | Mitigation |
|--------|-------------|--------|------------|
| GAP-001 | Original Flite voice quality | Cannot reproduce OpenEars voice | Accept voice difference, verify content |
| GAP-002 | Exact Pocketsphinx recognition accuracy | Deprecated framework | Test SFSpeechRecognizer with same phrases |
| GAP-003 | Legacy GPS filter algorithm | Undocumented implementation details | Test against documented behavior only |
| GAP-004 | Wunderground API response format | API may be deprecated | Mock responses based on WorkoutHistory data |

### 8.2 Documentation Gaps Requiring Clarification

| Gap ID | Area | Question | Recommended Action |
|--------|------|----------|-------------------|
| DOCGAP-001 | SpeedStats | Exact rolling window size | Inspect SpeedStats.m implementation |
| DOCGAP-002 | AppQueueManager | Purpose and behavior | Auditor flagged as gap - investigate |
| DOCGAP-003 | Pedometer factory | Selection criteria | Auditor flagged as gap - investigate |
| DOCGAP-004 | LegacyPedometer | Legacy behavior specifications | Document before migration |

---

## Part 9: Sign-Off Criteria

### 9.1 Quantitative Criteria

- [ ] 100% of CRITICAL priority tests passing
- [ ] 95% of HIGH priority tests passing
- [ ] 90% of MEDIUM priority tests passing
- [ ] 0 data loss in migration testing
- [ ] All invariants verified (INV-001 through INV-007)

### 9.2 Qualitative Criteria

- [ ] Domain expert approval of user experience parity
- [ ] Voice command recognition "acceptable" by testers
- [ ] TTS announcement content verified as identical
- [ ] Watch app functionality validated on physical device
- [ ] Background mode stability confirmed over 24-hour test

### 9.3 Documentation Criteria

- [ ] All test results documented with pass/fail status
- [ ] All GAPs documented with mitigations
- [ ] All known behavioral differences documented
- [ ] Regression test suite committed to repository
- [ ] Test data artifacts archived

---

## Appendix A: Notification Name Reference for Testing

| Notification | Posted By | Verified In Tests |
|--------------|-----------|-------------------|
| workoutStatusChanged | WorkoutController | WT-*, WC-PSH-001 |
| podcastItemChanged | UniversalPlayerController | PP-PBC-003, WC-PSH-002 |
| playerStatusChanged | UniversalPlayerController | PP-PBC-001/002, WC-PSH-003 |
| locationUpdate | WorkoutMetricsManager | WT-GPS-001, WC-PSH-005 |
| kPlaylistChangeNotification | PersistenceManager | PP-PLM-005 |
| WF_NOTIFICATION_SENSOR_HAS_DATA | WahooSensorController | BT-003 |
| WF_NOTIFICATION_SENSOR_CONNECTED | WahooSensorController | BT-002 |
| PreferenceChanges | PersistenceManager | VC-CFG-002 |

---

## Appendix B: Test Environment Requirements

### B.1 Simulators/Devices

- iOS Simulator (latest iOS)
- Physical iPhone (for GPS, Bluetooth testing)
- Physical Apple Watch (for Watch app testing)
- Wahoo heart rate sensor (optional, for Bluetooth testing)

### B.2 Test Data Setup

1. Export existing Core Data from legacy app (if available)
2. Generate synthetic GPS traces using GPX tools
3. Create RSS feed mock server
4. Prepare audio sample files

### B.3 Mock Services

- Weather API mock (returns deterministic weather data)
- RSS feed server mock (serves sample feeds)
- Network condition simulation (for offline testing)

---

*Document generated: January 2026*
*Based on analysis of JogPod codebase and migration documentation*
*Test Strategy Version: 1.0*
