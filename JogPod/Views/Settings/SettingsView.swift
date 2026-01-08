//
//  SettingsView.swift
//  JogPod
//
//  App settings and preferences view.
//

import SwiftUI
import SwiftData
import HealthKit
import CoreLocation

// MARK: - Preference Keys

/// Preference keys matching the legacy Objective-C constants from PersistenceDefaults.h
enum PreferenceKey {
    // MARK: Voice Commands
    static let startWorkoutText = "startWorkoutText"
    static let stopWorkoutText = "stopWorkoutText"
    static let playPodcastText = "playPodcastText"
    static let skipToNextText = "skipToNextText"
    static let skipToPreviousText = "skipToPreviousText"
    static let pausePodcastText = "pausePodcastText"
    static let fastForwardText = "fastForwardText"
    static let rewindPodcastText = "rewindPodcastText"
    static let shutdownVoiceText = "shutdownVoiceText"
    static let shakeVoiceCommands = "kShakeVoiceCommands"

    // MARK: Announcements
    static let announceVoice = "announceVoice"
    static let announceTemperature = "announceTemperature"
    static let announceHumidity = "announceHumidity"
    static let announceWindSpeed = "announceWindSpeed"
    static let announceWindDir = "announceWindDir"
    static let announceCurrentSpeed = "announceCurrentSpeed"
    static let announceAvgSpeed = "announceAvgSpeed"
    static let announceCurrentHeartRate = "announceCurrentHeartRate"
    static let announceAvgHeartRate = "announceAvgHeartRate"
    static let announceTotalAscent = "announceTotalAscent"
    static let announceTotalDescent = "announceTotalDescent"
    static let announceCaloriesBurned = "announceCaloriesBurned"
    static let announceDuration = "announceDuration"
    static let announceDistance = "announceDistance"

    // MARK: Workout Settings
    static let metric = "metric"
    static let weight = "weight"
    static let age = "age"
    static let birthDate = "birthDate"
    static let minHeartRate = "minHeartRate"
    static let maxHeartRate = "maxHeartRate"
    static let bestLocationAccuracy = "bestLocationAccuracy"

    // MARK: Goals
    static let durationGoal = "durationGoal"
    static let distanceGoal = "distanceGoal"
    static let caloriesGoal = "caloriesGoal"
    static let stepsGoal = "stepsGoal"

    // MARK: Notifications
    static let notifyMaxHeartRate = "notifyMaxHeartRate"
    static let notifyMinHeartRate = "notifyMinHeartRate"
    static let notifyMaxSpeed = "notifyMaxSpeed"

    // MARK: Player Settings
    static let forwardRewindTime = "forwardRewindTime"
    static let playerRate = "playerRate"

    // MARK: Integrations
    static let healthKitIntegration = "healthKitIntegration"
    static let fitbitIntegration = "fitbitIntegration"
    static let fitbitAuthCode = "fitbitAuthCode"
    static let fitbitSecret = "fitbitSecret"
    static let fitbitScreenName = "fitbitScreenName"
    static let fitbitSedentaryAlert = "fitbitSedentaryAlert"

    // MARK: Sensors
    static let wahooSensor = "wahooSensor"

    // MARK: App State
    static let firstTimeUse = "firstTimeUse"
    static let disclaimerAccepted = "disclaimerAccepted"

    // MARK: Background Fetch
    static let backgroundFetchOn = "backgroundFetchOn"
    static let backgroundFetchInterval = "backgroundFetchInterval"
    static let updateWhenNoWiFi = "updateWhenNoWiFi"
}

// MARK: - SettingsView

/// The app settings and preferences view.
///
/// This view provides access to all app configuration options, organized
/// into logical sections matching the legacy settings structure.
///
/// ## Legacy Equivalence
///
/// This view replaces 11 settings view controllers:
/// - `GoalsSettingsViewController.h/.m` - Workout goals
/// - `AnnouncementsViewController.h/.m` - Voice announcements
/// - `SoundSettingsViewController.h/.m` - Alert sounds
/// - `SensorsSettingsViewController.h/.m` - External sensors
/// - `PlayerSettingsViewController.h/.m` - Audio player settings
/// - `VoiceCommandsViewController.h/.m` - Voice commands
/// - `DataSettingsViewController.h/.m` - Data export
/// - `StorageSettingViewController.h/.m` - Storage management
/// - `ThirdPartySettingsViewController.h/.m` - Integrations
/// - `CreditsSettingsViewController.h/.m` - App credits
/// - `WorkoutSettingsTableViewController.h/.m` - Workout settings
///
/// ## Accessibility
///
/// - All controls have accessibility labels
/// - Toggle values are announced
/// - Supports Dynamic Type
/// - Supports VoiceOver navigation
public struct SettingsView: View {

    // MARK: - Environment

    @Environment(AppDependencies.self) private var dependencies

    // MARK: - Body

    public var body: some View {
        List {
            workoutSection
            audioSection
            sensorsSection
            integrationsSection
            dataSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Workout Section

    private var workoutSection: some View {
        Section("Workout") {
            NavigationLink {
                GoalsSettingsView()
            } label: {
                Label("Goals", systemImage: "target")
            }

            NavigationLink {
                WorkoutSettingsView()
            } label: {
                Label("Workout Settings", systemImage: "figure.run")
            }

            NavigationLink {
                AnnouncementsSettingsView()
            } label: {
                Label("Announcements", systemImage: "speaker.wave.2")
            }

            NavigationLink {
                VoiceCommandsSettingsView()
            } label: {
                Label("Voice Commands", systemImage: "mic")
            }
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        Section("Audio") {
            NavigationLink {
                PlayerSettingsView()
            } label: {
                Label("Player Settings", systemImage: "play.circle")
            }

            NavigationLink {
                SoundSettingsView()
            } label: {
                Label("Sound Alerts", systemImage: "bell")
            }
        }
    }

    // MARK: - Sensors Section

    private var sensorsSection: some View {
        Section("Sensors") {
            NavigationLink {
                SensorsSettingsView()
            } label: {
                Label("Heart Rate Monitor", systemImage: "heart")
            }

            NavigationLink {
                LocationSettingsView()
            } label: {
                Label("Location", systemImage: "location")
            }
        }
    }

    // MARK: - Integrations Section

    private var integrationsSection: some View {
        Section("Integrations") {
            NavigationLink {
                HealthKitSettingsView()
            } label: {
                Label("Apple Health", systemImage: "heart.text.square")
            }

            NavigationLink {
                ThirdPartySettingsView()
            } label: {
                Label("Third Party Services", systemImage: "link")
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section("Data") {
            NavigationLink {
                ExportDataView()
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }

            NavigationLink {
                StorageSettingsView()
            } label: {
                Label("Storage", systemImage: "internaldrive")
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                CreditsView()
            } label: {
                Label("Credits", systemImage: "info.circle")
            }

            NavigationLink {
                SupportView()
            } label: {
                Label("Support", systemImage: "questionmark.circle")
            }

            HStack {
                Label("Version", systemImage: "number")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - SettingsViewModel

/// Observable view model for settings that manages preference persistence.
@Observable
@MainActor
final class SettingsViewModel {
    private let persistenceManager: PersistenceManager

    init(persistenceManager: PersistenceManager) {
        self.persistenceManager = persistenceManager
    }

    // MARK: - Preference Loading

    func loadBool(key: String) async -> Bool {
        do {
            return try await persistenceManager.fetchPreference(name: key, as: Bool.self) ?? false
        } catch {
            print("[SettingsViewModel] Failed to load bool preference '\(key)': \(error)")
            return false
        }
    }

    func loadInt(key: String, default defaultValue: Int = 0) async -> Int {
        do {
            return try await persistenceManager.fetchPreference(name: key, as: Int.self) ?? defaultValue
        } catch {
            print("[SettingsViewModel] Failed to load int preference '\(key)': \(error)")
            return defaultValue
        }
    }

    func loadString(key: String, default defaultValue: String = "") async -> String {
        do {
            return try await persistenceManager.fetchPreference(name: key, as: String.self) ?? defaultValue
        } catch {
            print("[SettingsViewModel] Failed to load string preference '\(key)': \(error)")
            return defaultValue
        }
    }

    func loadDate(key: String) async -> Date? {
        do {
            return try await persistenceManager.fetchPreference(name: key, as: Date.self)
        } catch {
            print("[SettingsViewModel] Failed to load date preference '\(key)': \(error)")
            return nil
        }
    }

    // MARK: - Preference Saving

    func saveBool(key: String, value: Bool) async {
        do {
            try await persistenceManager.savePreference(name: key, value: value)
        } catch {
            print("[SettingsViewModel] Failed to save bool preference '\(key)': \(error)")
        }
    }

    func saveInt(key: String, value: Int) async {
        do {
            try await persistenceManager.savePreference(name: key, value: value)
        } catch {
            print("[SettingsViewModel] Failed to save int preference '\(key)': \(error)")
        }
    }

    func saveString(key: String, value: String) async {
        do {
            try await persistenceManager.savePreference(name: key, value: value)
        } catch {
            print("[SettingsViewModel] Failed to save string preference '\(key)': \(error)")
        }
    }

    func saveDate(key: String, value: Date) async {
        do {
            try await persistenceManager.savePreference(name: key, value: value)
        } catch {
            print("[SettingsViewModel] Failed to save date preference '\(key)': \(error)")
        }
    }

    // MARK: - Heart Rate Calculation

    /// Calculates max heart rate based on birth date using the formula: 0.8 * (206.9 - (0.67 * age))
    func calculateMaxHeartRate(from birthDate: Date) -> Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        guard let age = ageComponents.year, age > 0 else { return 160 }

        let maxHR = 0.8 * (206.9 - (0.67 * Double(age)))
        return Int(maxHR)
    }
}

// MARK: - Goals Settings View

/// Workout goals configuration.
///
/// Replaces `GoalsSettingsViewController` from the legacy app.
struct GoalsSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var durationGoal: Int = 30
    @State private var distanceGoal: Int = 5
    @State private var caloriesGoal: Int = 300
    @State private var stepsGoal: Int = 10000
    @State private var isMetric: Bool = true

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Duration")
                    Spacer()
                    TextField("minutes", value: $durationGoal, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("min")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Duration goal")
                .accessibilityValue("\(durationGoal) minutes")
            } header: {
                Text("Duration Goal")
            } footer: {
                Text("Set a target workout duration in minutes (max 600)")
            }

            Section {
                HStack {
                    Text("Distance")
                    Spacer()
                    TextField("distance", value: $distanceGoal, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text(isMetric ? "km" : "mi")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Distance goal")
                .accessibilityValue("\(distanceGoal) \(isMetric ? "kilometers" : "miles")")
            } header: {
                Text("Distance Goal")
            } footer: {
                Text("Set a target distance (max 100)")
            }

            Section {
                HStack {
                    Text("Calories")
                    Spacer()
                    TextField("calories", value: $caloriesGoal, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kcal")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Calories goal")
                .accessibilityValue("\(caloriesGoal) calories")
            } header: {
                Text("Calories Goal")
            } footer: {
                Text("Set a target calorie burn (max 10,000)")
            }

            Section {
                HStack {
                    Text("Steps")
                    Spacer()
                    TextField("steps", value: $stepsGoal, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text("steps")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Steps goal")
                .accessibilityValue("\(stepsGoal) steps")
            } header: {
                Text("Steps Goal")
            } footer: {
                Text("Set a target step count (max 25,000)")
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onChange(of: durationGoal) { _, newValue in
            Task { await viewModel?.saveInt(key: PreferenceKey.durationGoal, value: min(newValue, 600)) }
        }
        .onChange(of: distanceGoal) { _, newValue in
            Task { await viewModel?.saveInt(key: PreferenceKey.distanceGoal, value: min(newValue, 100)) }
        }
        .onChange(of: caloriesGoal) { _, newValue in
            Task { await viewModel?.saveInt(key: PreferenceKey.caloriesGoal, value: min(newValue, 10000)) }
        }
        .onChange(of: stepsGoal) { _, newValue in
            Task { await viewModel?.saveInt(key: PreferenceKey.stepsGoal, value: min(newValue, 25000)) }
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        durationGoal = await viewModel.loadInt(key: PreferenceKey.durationGoal, default: 30)
        distanceGoal = await viewModel.loadInt(key: PreferenceKey.distanceGoal, default: 5)
        caloriesGoal = await viewModel.loadInt(key: PreferenceKey.caloriesGoal, default: 300)
        stepsGoal = await viewModel.loadInt(key: PreferenceKey.stepsGoal, default: 10000)
        isMetric = await viewModel.loadBool(key: PreferenceKey.metric)
    }
}

// MARK: - Workout Settings View

/// Workout configuration including units, weight, and heart rate zones.
///
/// Replaces `WorkoutSettingsTableViewController` from the legacy app.
struct WorkoutSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var isMetric: Bool = true
    @State private var weight: Int = 70
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var maxHeartRate: Int = 160
    @State private var minHeartRate: Int = 100

    var body: some View {
        Form {
            Section {
                Picker("Units", selection: $isMetric) {
                    Text("Imperial (lb, mi)").tag(false)
                    Text("Metric (kg, km)").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Distance units")
            } header: {
                Text("Units of Measure")
            }

            Section {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("weight", value: $weight, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text(isMetric ? "kg" : "lb")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Body weight")
                .accessibilityValue("\(weight) \(isMetric ? "kilograms" : "pounds")")
            } header: {
                Text("Body Weight")
            } footer: {
                Text("Used for calorie calculations")
            }

            Section {
                DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .accessibilityLabel("Birth date for heart rate calculation")
            } header: {
                Text("Birth Date")
            } footer: {
                Text("Used to calculate your maximum heart rate zone")
            }

            Section {
                HStack {
                    Text("Max Heart Rate")
                    Spacer()
                    Text("\(maxHeartRate) BPM")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Maximum heart rate")
                .accessibilityValue("\(maxHeartRate) beats per minute")

                HStack {
                    Text("Min Target HR")
                    Spacer()
                    TextField("min HR", value: $minHeartRate, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("BPM")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Minimum target heart rate")
                .accessibilityValue("\(minHeartRate) beats per minute")
            } header: {
                Text("Heart Rate Zones")
            } footer: {
                Text("Max heart rate is calculated based on your birth date. Set your minimum target heart rate for zone alerts.")
            }
        }
        .navigationTitle("Workout Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onChange(of: isMetric) { oldValue, newValue in
            // Convert weight when switching units
            if oldValue != newValue {
                if newValue {
                    // Converting to metric (lb to kg)
                    weight = Int(floor(Double(weight) * 0.453592))
                } else {
                    // Converting to imperial (kg to lb)
                    weight = Int(ceil(Double(weight) * 2.20462))
                }
            }
            Task { await viewModel?.saveBool(key: PreferenceKey.metric, value: newValue) }
        }
        .onChange(of: weight) { _, newValue in
            Task { await viewModel?.saveInt(key: PreferenceKey.weight, value: newValue) }
        }
        .onChange(of: birthDate) { _, newValue in
            Task {
                await viewModel?.saveDate(key: PreferenceKey.birthDate, value: newValue)
                if let vm = viewModel {
                    let newMaxHR = vm.calculateMaxHeartRate(from: newValue)
                    maxHeartRate = newMaxHR
                    await vm.saveInt(key: PreferenceKey.maxHeartRate, value: newMaxHR)
                }
            }
        }
        .onChange(of: minHeartRate) { _, newValue in
            Task { await viewModel?.saveInt(key: PreferenceKey.minHeartRate, value: newValue) }
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        isMetric = await viewModel.loadBool(key: PreferenceKey.metric)
        weight = await viewModel.loadInt(key: PreferenceKey.weight, default: isMetric ? 70 : 154)
        birthDate = await viewModel.loadDate(key: PreferenceKey.birthDate) ?? Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        maxHeartRate = await viewModel.loadInt(key: PreferenceKey.maxHeartRate, default: viewModel.calculateMaxHeartRate(from: birthDate))
        minHeartRate = await viewModel.loadInt(key: PreferenceKey.minHeartRate, default: 100)
    }
}

// MARK: - Announcements Settings View

/// Voice announcement configuration during workouts.
///
/// Replaces `AnnouncementsViewController` from the legacy app.
struct AnnouncementsSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var announceVoice: Bool = true
    @State private var announceDistance: Bool = true
    @State private var announceDuration: Bool = true
    @State private var announceCurrentSpeed: Bool = false
    @State private var announceAvgSpeed: Bool = false
    @State private var announceCurrentHeartRate: Bool = true
    @State private var announceAvgHeartRate: Bool = false
    @State private var announceCaloriesBurned: Bool = false
    @State private var announceTotalAscent: Bool = false
    @State private var announceTotalDescent: Bool = false
    @State private var announceTemperature: Bool = false
    @State private var announceHumidity: Bool = false
    @State private var announceWindSpeed: Bool = false

    var body: some View {
        announcementForm
            .navigationTitle("Announcements")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadPreferences() }
            .modifier(AnnouncementChangeHandlers(
                announceVoice: $announceVoice,
                announceDistance: $announceDistance,
                announceDuration: $announceDuration,
                announceCurrentSpeed: $announceCurrentSpeed,
                announceAvgSpeed: $announceAvgSpeed,
                announceCurrentHeartRate: $announceCurrentHeartRate,
                announceAvgHeartRate: $announceAvgHeartRate,
                announceCaloriesBurned: $announceCaloriesBurned,
                announceTotalAscent: $announceTotalAscent,
                announceTotalDescent: $announceTotalDescent,
                announceTemperature: $announceTemperature,
                announceHumidity: $announceHumidity,
                announceWindSpeed: $announceWindSpeed,
                viewModel: viewModel
            ))
    }

    private var announcementForm: some View {
        Form {
            Section {
                Toggle("Enable Voice Announcements", isOn: $announceVoice)
                    .accessibilityHint("Master toggle for all voice announcements during workouts")
            } footer: {
                Text("When enabled, the app will speak workout metrics at regular intervals")
            }

            Section("Workout Metrics") {
                Toggle("Distance", isOn: $announceDistance)
                    .disabled(!announceVoice)
                Toggle("Duration", isOn: $announceDuration)
                    .disabled(!announceVoice)
                Toggle("Calories Burned", isOn: $announceCaloriesBurned)
                    .disabled(!announceVoice)
            }

            Section("Speed") {
                Toggle("Current Speed", isOn: $announceCurrentSpeed)
                    .disabled(!announceVoice)
                Toggle("Average Speed", isOn: $announceAvgSpeed)
                    .disabled(!announceVoice)
            }

            Section("Heart Rate") {
                Toggle("Current Heart Rate", isOn: $announceCurrentHeartRate)
                    .disabled(!announceVoice)
                Toggle("Average Heart Rate", isOn: $announceAvgHeartRate)
                    .disabled(!announceVoice)
            }

            Section("Elevation") {
                Toggle("Total Ascent", isOn: $announceTotalAscent)
                    .disabled(!announceVoice)
                Toggle("Total Descent", isOn: $announceTotalDescent)
                    .disabled(!announceVoice)
            }

            Section("Weather") {
                Toggle("Temperature", isOn: $announceTemperature)
                    .disabled(!announceVoice)
                Toggle("Humidity", isOn: $announceHumidity)
                    .disabled(!announceVoice)
                Toggle("Wind Speed", isOn: $announceWindSpeed)
                    .disabled(!announceVoice)
            }
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        announceVoice = await viewModel.loadBool(key: PreferenceKey.announceVoice)
        announceDistance = await viewModel.loadBool(key: PreferenceKey.announceDistance)
        announceDuration = await viewModel.loadBool(key: PreferenceKey.announceDuration)
        announceCurrentSpeed = await viewModel.loadBool(key: PreferenceKey.announceCurrentSpeed)
        announceAvgSpeed = await viewModel.loadBool(key: PreferenceKey.announceAvgSpeed)
        announceCurrentHeartRate = await viewModel.loadBool(key: PreferenceKey.announceCurrentHeartRate)
        announceAvgHeartRate = await viewModel.loadBool(key: PreferenceKey.announceAvgHeartRate)
        announceCaloriesBurned = await viewModel.loadBool(key: PreferenceKey.announceCaloriesBurned)
        announceTotalAscent = await viewModel.loadBool(key: PreferenceKey.announceTotalAscent)
        announceTotalDescent = await viewModel.loadBool(key: PreferenceKey.announceTotalDescent)
        announceTemperature = await viewModel.loadBool(key: PreferenceKey.announceTemperature)
        announceHumidity = await viewModel.loadBool(key: PreferenceKey.announceHumidity)
        announceWindSpeed = await viewModel.loadBool(key: PreferenceKey.announceWindSpeed)
    }
}

// MARK: - Voice Commands Settings View

/// Voice command phrase customization.
///
/// Replaces `VoiceCommandsViewController` from the legacy app.
struct VoiceCommandsSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var shakeToActivate: Bool = true
    @State private var startWorkoutPhrase: String = "start workout"
    @State private var stopWorkoutPhrase: String = "stop workout"
    @State private var playPodcastPhrase: String = "play podcast"
    @State private var pausePodcastPhrase: String = "pause podcast"
    @State private var skipNextPhrase: String = "skip next"
    @State private var skipPreviousPhrase: String = "skip previous"
    @State private var fastForwardPhrase: String = "fast forward"
    @State private var rewindPhrase: String = "rewind"

    var body: some View {
        Form {
            Section {
                Toggle("Shake to Activate", isOn: $shakeToActivate)
                    .accessibilityHint("Shake your device to start listening for voice commands")
            } footer: {
                Text("Shake your device to activate voice command listening")
            }

            Section("Workout Commands") {
                VoiceCommandRow(label: "Start Workout", phrase: $startWorkoutPhrase)
                VoiceCommandRow(label: "Stop Workout", phrase: $stopWorkoutPhrase)
            }

            Section("Playback Commands") {
                VoiceCommandRow(label: "Play Podcast", phrase: $playPodcastPhrase)
                VoiceCommandRow(label: "Pause Podcast", phrase: $pausePodcastPhrase)
                VoiceCommandRow(label: "Skip to Next", phrase: $skipNextPhrase)
                VoiceCommandRow(label: "Skip to Previous", phrase: $skipPreviousPhrase)
                VoiceCommandRow(label: "Fast Forward", phrase: $fastForwardPhrase)
                VoiceCommandRow(label: "Rewind", phrase: $rewindPhrase)
            }
        }
        .navigationTitle("Voice Commands")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onChange(of: shakeToActivate) { _, newValue in
            Task { await viewModel?.saveBool(key: PreferenceKey.shakeVoiceCommands, value: newValue) }
        }
        .onChange(of: startWorkoutPhrase) { _, newValue in
            Task { await viewModel?.saveString(key: PreferenceKey.startWorkoutText, value: newValue) }
        }
        .onChange(of: stopWorkoutPhrase) { _, newValue in
            Task { await viewModel?.saveString(key: PreferenceKey.stopWorkoutText, value: newValue) }
        }
        .onChange(of: playPodcastPhrase) { _, newValue in
            Task { await viewModel?.saveString(key: PreferenceKey.playPodcastText, value: newValue) }
        }
        .onChange(of: pausePodcastPhrase) { _, newValue in
            Task { await viewModel?.saveString(key: PreferenceKey.pausePodcastText, value: newValue) }
        }
        .onChange(of: skipNextPhrase) { _, newValue in
            Task { await viewModel?.saveString(key: PreferenceKey.skipToNextText, value: newValue) }
        }
        .onChange(of: skipPreviousPhrase) { _, newValue in
            Task { await viewModel?.saveString(key: PreferenceKey.skipToPreviousText, value: newValue) }
        }
        .onChange(of: fastForwardPhrase) { _, newValue in
            Task { await viewModel?.saveString(key: PreferenceKey.fastForwardText, value: newValue) }
        }
        .onChange(of: rewindPhrase) { _, newValue in
            Task { await viewModel?.saveString(key: PreferenceKey.rewindPodcastText, value: newValue) }
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        shakeToActivate = await viewModel.loadBool(key: PreferenceKey.shakeVoiceCommands)
        startWorkoutPhrase = await viewModel.loadString(key: PreferenceKey.startWorkoutText, default: "start workout")
        stopWorkoutPhrase = await viewModel.loadString(key: PreferenceKey.stopWorkoutText, default: "stop workout")
        playPodcastPhrase = await viewModel.loadString(key: PreferenceKey.playPodcastText, default: "play podcast")
        pausePodcastPhrase = await viewModel.loadString(key: PreferenceKey.pausePodcastText, default: "pause podcast")
        skipNextPhrase = await viewModel.loadString(key: PreferenceKey.skipToNextText, default: "skip next")
        skipPreviousPhrase = await viewModel.loadString(key: PreferenceKey.skipToPreviousText, default: "skip previous")
        fastForwardPhrase = await viewModel.loadString(key: PreferenceKey.fastForwardText, default: "fast forward")
        rewindPhrase = await viewModel.loadString(key: PreferenceKey.rewindPodcastText, default: "rewind")
    }
}

/// A row for editing a voice command phrase.
private struct VoiceCommandRow: View {
    let label: String
    @Binding var phrase: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("phrase", text: $phrase)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) voice command")
        .accessibilityValue(phrase)
    }
}

// MARK: - Player Settings View

/// Audio player configuration.
///
/// Replaces `PlayerSettingsViewController` from the legacy app.
struct PlayerSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var skipInterval: Int = 30
    @State private var playbackSpeed: Double = 1.0

    private let speedOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        Form {
            Section {
                Stepper("Skip Interval: \(skipInterval) sec", value: $skipInterval, in: 5...120, step: 5)
                    .accessibilityLabel("Skip interval")
                    .accessibilityValue("\(skipInterval) seconds")
                    .accessibilityHint("Adjusts how many seconds to skip forward or backward")
            } header: {
                Text("Skip Controls")
            } footer: {
                Text("Set the number of seconds to skip when using forward/rewind controls")
            }

            Section {
                Picker("Playback Speed", selection: $playbackSpeed) {
                    ForEach(speedOptions, id: \.self) { speed in
                        Text(formatSpeed(speed)).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Playback Speed")
            } footer: {
                Text("Adjust podcast playback speed. 1.0x is normal speed.")
            }

            Section {
                HStack {
                    Text("Current Speed")
                    Spacer()
                    Text(formatSpeed(playbackSpeed))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Player Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onChange(of: skipInterval) { _, newValue in
            Task { await viewModel?.saveInt(key: PreferenceKey.forwardRewindTime, value: newValue) }
        }
        .onChange(of: playbackSpeed) { _, newValue in
            // Store as int percentage (100 = 1.0x)
            let intValue = Int(newValue * 100)
            Task { await viewModel?.saveInt(key: PreferenceKey.playerRate, value: intValue) }

            // Apply to audio player immediately
            if let audioPlayer = dependencies.audioPlayerService {
                do {
                    try audioPlayer.setRate(Float(newValue))
                } catch {
                    print("[PlayerSettingsView] Failed to set playback rate: \(error)")
                }
            }
        }
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == 1.0 {
            return "1x"
        }
        return String(format: "%.2gx", speed)
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        skipInterval = await viewModel.loadInt(key: PreferenceKey.forwardRewindTime, default: 30)
        let rateInt = await viewModel.loadInt(key: PreferenceKey.playerRate, default: 100)
        playbackSpeed = Double(rateInt) / 100.0
    }
}

// MARK: - Sound Settings View

/// Sound alert configuration for workout notifications.
///
/// Replaces `SoundSettingsViewController` from the legacy app.
struct SoundSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var notifyMaxHeartRate: Bool = true
    @State private var notifyMinHeartRate: Bool = true
    @State private var notifyMaxSpeed: Bool = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Toggle("High Heart Rate Alert", isOn: $notifyMaxHeartRate)
                    Button {
                        playTestSound(type: .highHeartRate)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Test high heart rate alert sound")
                }

                HStack {
                    Toggle("Low Heart Rate Alert", isOn: $notifyMinHeartRate)
                    Button {
                        playTestSound(type: .lowHeartRate)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Test low heart rate alert sound")
                }
            } header: {
                Text("Heart Rate Alerts")
            } footer: {
                Text("Play a sound when your heart rate goes above or below your target zone")
            }

            Section {
                HStack {
                    Toggle("High Speed Alert", isOn: $notifyMaxSpeed)
                    Button {
                        playTestSound(type: .highSpeed)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Test high speed alert sound")
                }
            } header: {
                Text("Speed Alerts")
            } footer: {
                Text("Play a sound when you exceed your target speed")
            }
        }
        .navigationTitle("Sound Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onChange(of: notifyMaxHeartRate) { _, newValue in
            Task { await viewModel?.saveBool(key: PreferenceKey.notifyMaxHeartRate, value: newValue) }
        }
        .onChange(of: notifyMinHeartRate) { _, newValue in
            Task { await viewModel?.saveBool(key: PreferenceKey.notifyMinHeartRate, value: newValue) }
        }
        .onChange(of: notifyMaxSpeed) { _, newValue in
            Task { await viewModel?.saveBool(key: PreferenceKey.notifyMaxSpeed, value: newValue) }
        }
    }

    private enum AlertSoundType {
        case highHeartRate, lowHeartRate, highSpeed
    }

    private func playTestSound(type: AlertSoundType) {
        // TODO: Integrate with SystemSoundController equivalent
        // For now, use system haptic feedback as placeholder
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .highHeartRate:
            generator.notificationOccurred(.warning)
        case .lowHeartRate:
            generator.notificationOccurred(.success)
        case .highSpeed:
            generator.notificationOccurred(.error)
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        notifyMaxHeartRate = await viewModel.loadBool(key: PreferenceKey.notifyMaxHeartRate)
        notifyMinHeartRate = await viewModel.loadBool(key: PreferenceKey.notifyMinHeartRate)
        notifyMaxSpeed = await viewModel.loadBool(key: PreferenceKey.notifyMaxSpeed)
    }
}

// MARK: - Sensors Settings View

/// External sensor configuration including heart rate monitors.
///
/// Replaces `SensorsSettingsViewController` from the legacy app.
struct SensorsSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var wahooSensorEnabled: Bool = false
    @State private var isScanning: Bool = false
    @State private var connectedDeviceName: String?

    var body: some View {
        Form {
            Section {
                Toggle("Wahoo Heart Rate Sensor", isOn: $wahooSensorEnabled)
                    .accessibilityHint("Enable to connect to Wahoo Bluetooth heart rate monitors")
            } header: {
                Text("Bluetooth Heart Rate Monitor")
            } footer: {
                Text("Enable to use an external Bluetooth heart rate monitor during workouts")
            }

            if wahooSensorEnabled {
                Section {
                    if let deviceName = connectedDeviceName {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(deviceName)
                            Spacer()
                            Text("Connected")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Connected to \(deviceName)")
                    } else if isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Scanning for devices...")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Scanning for heart rate monitors")
                    } else {
                        Button {
                            startScanning()
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Scan for Devices")
                            }
                        }
                        .accessibilityHint("Double tap to start scanning for nearby heart rate monitors")
                    }
                } header: {
                    Text("Connected Device")
                }
            }

            Section {
                NavigationLink {
                    SensorTroubleshootingView()
                } label: {
                    Label("Troubleshooting", systemImage: "wrench")
                }
            }
        }
        .navigationTitle("Heart Rate Monitor")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onChange(of: wahooSensorEnabled) { _, newValue in
            Task { await viewModel?.saveBool(key: PreferenceKey.wahooSensor, value: newValue) }
        }
    }

    private func startScanning() {
        isScanning = true
        // TODO: Integrate with HeartRateService for actual Bluetooth scanning
        // Simulating scan completion for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isScanning = false
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        wahooSensorEnabled = await viewModel.loadBool(key: PreferenceKey.wahooSensor)
    }
}

/// Sensor troubleshooting help view.
private struct SensorTroubleshootingView: View {
    var body: some View {
        List {
            Section("Common Issues") {
                TroubleshootingRow(
                    title: "Sensor not found",
                    solution: "Make sure Bluetooth is enabled and the sensor is in pairing mode. Try putting on the chest strap to activate the sensor."
                )
                TroubleshootingRow(
                    title: "Connection drops frequently",
                    solution: "Keep your phone within 3 meters of the sensor. Avoid interference from other Bluetooth devices."
                )
                TroubleshootingRow(
                    title: "Inaccurate readings",
                    solution: "Moisten the sensor contact points or use electrode gel. Make sure the strap fits snugly."
                )
            }

            Section("Battery") {
                TroubleshootingRow(
                    title: "Sensor battery low",
                    solution: "Most heart rate sensors use a CR2032 coin cell battery. Replace if readings become erratic."
                )
            }
        }
        .navigationTitle("Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TroubleshootingRow: View {
    let title: String
    let solution: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(solution)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Location Settings View

/// GPS and location accuracy configuration.
struct LocationSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var bestAccuracy: Bool = true
    @State private var autoPauseEnabled: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle("Best Accuracy", isOn: $bestAccuracy)
                    .accessibilityHint("Uses more battery but provides more accurate location tracking")
            } header: {
                Text("GPS Accuracy")
            } footer: {
                Text("Best accuracy uses GPS more frequently for precise tracking. Disable to conserve battery during longer workouts.")
            }

            Section {
                Toggle("Auto-Pause", isOn: $autoPauseEnabled)
                    .accessibilityHint("Automatically pauses workout tracking when you stop moving")
            } header: {
                Text("Auto-Pause")
            } footer: {
                Text("Automatically pause the workout when you stop moving, such as at traffic lights")
            }

            Section {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                    Text("Location Permission")
                    Spacer()
                    Text(locationAuthorizationStatus)
                        .foregroundStyle(.secondary)
                }

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } header: {
                Text("Permissions")
            }
        }
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onChange(of: bestAccuracy) { _, newValue in
            Task { await viewModel?.saveBool(key: PreferenceKey.bestLocationAccuracy, value: newValue) }
        }
    }

    private var locationAuthorizationStatus: String {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "While Using"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        bestAccuracy = await viewModel.loadBool(key: PreferenceKey.bestLocationAccuracy)
    }
}

// MARK: - HealthKit Settings View

/// Apple Health integration configuration.
struct HealthKitSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var healthKitEnabled: Bool = false
    @State private var isHealthKitAvailable: Bool = false
    @State private var authorizationStatus: String = "Not Determined"

    var body: some View {
        Form {
            Section {
                if isHealthKitAvailable {
                    Toggle("Sync with Apple Health", isOn: $healthKitEnabled)
                        .accessibilityHint("When enabled, workouts will be saved to Apple Health")
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("HealthKit not available on this device")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Apple Health Integration")
            } footer: {
                if isHealthKitAvailable {
                    Text("When enabled, your workouts and heart rate data will be synced with Apple Health")
                }
            }

            if healthKitEnabled && isHealthKitAvailable {
                Section("Data Synced") {
                    DataSyncRow(icon: "figure.run", title: "Workouts", enabled: true)
                    DataSyncRow(icon: "heart.fill", title: "Heart Rate", enabled: true)
                    DataSyncRow(icon: "flame.fill", title: "Active Calories", enabled: true)
                    DataSyncRow(icon: "figure.walk", title: "Steps", enabled: true)
                    DataSyncRow(icon: "location.fill", title: "Workout Routes", enabled: true)
                }

                Section {
                    HStack {
                        Text("Authorization Status")
                        Spacer()
                        Text(authorizationStatus)
                            .foregroundStyle(.secondary)
                    }

                    Button("Open Health Settings") {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
            checkHealthKitAvailability()
        }
        .onChange(of: healthKitEnabled) { _, newValue in
            if newValue {
                requestHealthKitAuthorization()
            } else {
                Task { await viewModel?.saveBool(key: PreferenceKey.healthKitIntegration, value: false) }
            }
        }
    }

    private func checkHealthKitAvailability() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }

    private func requestHealthKitAuthorization() {
        guard isHealthKitAvailable else { return }

        let healthStore = HKHealthStore()

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    Task { await viewModel?.saveBool(key: PreferenceKey.healthKitIntegration, value: true) }
                    authorizationStatus = "Authorized"
                } else {
                    healthKitEnabled = false
                    Task { await viewModel?.saveBool(key: PreferenceKey.healthKitIntegration, value: false) }
                    authorizationStatus = "Denied"
                }
            }
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        healthKitEnabled = await viewModel.loadBool(key: PreferenceKey.healthKitIntegration)
    }
}

private struct DataSyncRow: View {
    let icon: String
    let title: String
    let enabled: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.red)
                .frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) sync \(enabled ? "enabled" : "disabled")")
    }
}

// MARK: - Third Party Settings View

/// Third-party service integrations (Fitbit, etc.)
///
/// Replaces `ThirdPartySettingsViewController` from the legacy app.
struct ThirdPartySettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SettingsViewModel?

    @State private var fitbitEnabled: Bool = false
    @State private var fitbitScreenName: String = ""
    @State private var isConnecting: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Fitbit Integration", isOn: $fitbitEnabled)
                    .accessibilityHint("Connect to Fitbit to sync your fitness data")

                if fitbitEnabled {
                    if isConnecting {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Connecting to Fitbit...")
                                .foregroundStyle(.secondary)
                        }
                    } else if !fitbitScreenName.isEmpty {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.blue)
                            Text(fitbitScreenName)
                            Spacer()
                            Text("Connected")
                                .foregroundStyle(.green)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Connected as \(fitbitScreenName)")

                        Button("Disconnect", role: .destructive) {
                            disconnectFitbit()
                        }
                    }
                }
            } header: {
                Text("Fitbit")
            } footer: {
                Text("Connect your Fitbit account to sync weight and fitness data")
            }

            Section {
                Text("More integrations coming soon")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Other Services")
            }
        }
        .navigationTitle("Third Party Services")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .onChange(of: fitbitEnabled) { _, newValue in
            if newValue && fitbitScreenName.isEmpty {
                connectToFitbit()
            } else if !newValue {
                disconnectFitbit()
            }
        }
    }

    private func connectToFitbit() {
        isConnecting = true
        // TODO: Integrate with OAuth service for Fitbit authentication
        // Simulating connection for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
            // In real implementation, this would be set after successful OAuth
        }
    }

    private func disconnectFitbit() {
        fitbitScreenName = ""
        fitbitEnabled = false
        Task {
            await viewModel?.saveBool(key: PreferenceKey.fitbitIntegration, value: false)
            await viewModel?.saveString(key: PreferenceKey.fitbitScreenName, value: "")
            await viewModel?.saveString(key: PreferenceKey.fitbitAuthCode, value: "")
            await viewModel?.saveString(key: PreferenceKey.fitbitSecret, value: "")
        }
    }

    private func loadPreferences() async {
        viewModel = SettingsViewModel(persistenceManager: dependencies.persistenceManager)
        guard let viewModel else { return }

        fitbitEnabled = await viewModel.loadBool(key: PreferenceKey.fitbitIntegration)
        fitbitScreenName = await viewModel.loadString(key: PreferenceKey.fitbitScreenName, default: "")
    }
}

// MARK: - Export Data View

/// Data export functionality.
///
/// Replaces `DataSettingsViewController` from the legacy app.
struct ExportDataView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var isExporting: Bool = false
    @State private var exportURL: URL?
    @State private var showShareSheet: Bool = false
    @State private var exportError: String?

    var body: some View {
        Form {
            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export All Workout Data")
                        Spacer()
                        if isExporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isExporting)
                .accessibilityHint("Export all your workout data as a JSON file")
            } header: {
                Text("Export")
            } footer: {
                Text("Export your workout history as a JSON file for backup or analysis")
            }

            if let error = exportError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Export Includes") {
                ExportItemRow(icon: "figure.run", title: "Workout Sessions")
                ExportItemRow(icon: "map", title: "GPS Track Points")
                ExportItemRow(icon: "heart.fill", title: "Heart Rate Data")
                ExportItemRow(icon: "headphones", title: "Listening History")
                ExportItemRow(icon: "gearshape", title: "Preferences")
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func exportData() {
        isExporting = true
        exportError = nil

        Task {
            do {
                // Create temporary file URL
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent("jogpod_export.json")

                // TODO: Implement full data dump from PersistenceManager
                // For now, create a placeholder export
                let exportData: [String: Any] = [
                    "exportDate": ISO8601DateFormatter().string(from: Date()),
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    "data": [
                        "workouts": [],
                        "preferences": []
                    ]
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                try jsonData.write(to: fileURL)

                await MainActor.run {
                    exportURL = fileURL
                    isExporting = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    exportError = "Failed to export data: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
}

private struct ExportItemRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(title)
        }
    }
}

/// UIKit share sheet wrapper for SwiftUI.
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Storage Settings View

/// Storage management including iCloud sync.
///
/// Replaces `StorageSettingViewController` from the legacy app.
struct StorageSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var iCloudEnabled: Bool = false
    @State private var cacheSize: String = "Calculating..."
    @State private var showClearCacheAlert: Bool = false
    @State private var showClearDataAlert: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("iCloud Sync", isOn: $iCloudEnabled)
                    .accessibilityHint("Sync your data across all your devices using iCloud")
            } header: {
                Text("iCloud")
            } footer: {
                Text("Keep your workout data and podcasts synced across all your devices")
            }

            Section {
                HStack {
                    Text("Cached Episodes")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(.secondary)
                }

                Button("Clear Cache") {
                    showClearCacheAlert = true
                }
                .foregroundStyle(.blue)
            } header: {
                Text("Podcast Cache")
            } footer: {
                Text("Cached episodes allow offline playback but use storage space")
            }

            Section {
                Button("Clear All Data", role: .destructive) {
                    showClearDataAlert = true
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("This will permanently delete all workout data, podcasts, and settings")
            }
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await calculateCacheSize()
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will delete all cached podcast episodes. They can be re-downloaded later.")
        }
        .alert("Clear All Data", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your workout history, podcasts, and settings. This action cannot be undone.")
        }
    }

    private func calculateCacheSize() async {
        // TODO: Calculate actual cache size from MediaCacheService
        // Placeholder for now
        cacheSize = "0 MB"
    }

    private func clearCache() {
        // TODO: Implement cache clearing via MediaCacheService
        cacheSize = "0 MB"
    }

    private func clearAllData() {
        // TODO: Implement full data reset
    }
}

// MARK: - Credits View

/// App credits and acknowledgments.
///
/// Replaces `CreditsSettingsViewController` from the legacy app.
struct CreditsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityHidden(true)

                Text("JogPod")
                    .font(.title.weight(.bold))

                Text("Podcast-Enhanced Workouts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.vertical)

                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.headline)

                    Text("""
                        JogPod combines fitness tracking with podcast listening, \
                        making your workouts more enjoyable and productive. \
                        Track your runs, monitor your heart rate, and listen to \
                        your favorite podcasts all in one app.
                        """)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("Developed By")
                        .font(.headline)
                        .padding(.top)

                    Text("Andras L Ferenczi")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("Open Source Libraries")
                        .font(.headline)
                        .padding(.top)

                    VStack(alignment: .leading, spacing: 8) {
                        CreditRow(name: "Swift", description: "Programming language")
                        CreditRow(name: "SwiftUI", description: "User interface framework")
                        CreditRow(name: "SwiftData", description: "Data persistence")
                        CreditRow(name: "CoreLocation", description: "Location services")
                        CreditRow(name: "HealthKit", description: "Health data integration")
                        CreditRow(name: "CoreBluetooth", description: "Heart rate sensor support")
                    }

                    Text("Special Thanks")
                        .font(.headline)
                        .padding(.top)

                    Text("To all the beta testers and users who have provided valuable feedback to make JogPod better.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Spacer()

                Text("Copyright 2014-2025 Andras L Ferenczi")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CreditRow: View {
    let name: String
    let description: String

    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline.weight(.medium))
            Text("-")
                .foregroundStyle(.secondary)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Support View

/// Support and help information.
struct SupportView: View {
    var body: some View {
        Form {
            Section("Get Help") {
                Link(destination: URL(string: "mailto:support@jogpod.app")!) {
                    Label("Email Support", systemImage: "envelope")
                }

                Link(destination: URL(string: "https://jogpod.app/faq")!) {
                    Label("FAQ", systemImage: "questionmark.circle")
                }

                Link(destination: URL(string: "https://jogpod.app/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                Link(destination: URL(string: "https://jogpod.app/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            }

            Section("Rate & Review") {
                Link(destination: URL(string: "https://apps.apple.com/app/jogpod")!) {
                    Label("Rate on App Store", systemImage: "star")
                }
            }

            Section("Debug") {
                HStack {
                    Text("Device")
                    Spacer()
                    Text(UIDevice.current.model)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("iOS Version")
                    Spacer()
                    Text(UIDevice.current.systemVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Announcement Change Handlers

/// ViewModifier to handle onChange events for announcement settings.
/// This breaks up the complex expression into manageable pieces.
private struct AnnouncementChangeHandlers: ViewModifier {
    @Binding var announceVoice: Bool
    @Binding var announceDistance: Bool
    @Binding var announceDuration: Bool
    @Binding var announceCurrentSpeed: Bool
    @Binding var announceAvgSpeed: Bool
    @Binding var announceCurrentHeartRate: Bool
    @Binding var announceAvgHeartRate: Bool
    @Binding var announceCaloriesBurned: Bool
    @Binding var announceTotalAscent: Bool
    @Binding var announceTotalDescent: Bool
    @Binding var announceTemperature: Bool
    @Binding var announceHumidity: Bool
    @Binding var announceWindSpeed: Bool
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .modifier(WorkoutMetricsHandlers(
                announceVoice: $announceVoice,
                announceDistance: $announceDistance,
                announceDuration: $announceDuration,
                announceCaloriesBurned: $announceCaloriesBurned,
                viewModel: viewModel
            ))
            .modifier(SpeedHandlers(
                announceCurrentSpeed: $announceCurrentSpeed,
                announceAvgSpeed: $announceAvgSpeed,
                viewModel: viewModel
            ))
            .modifier(HeartRateHandlers(
                announceCurrentHeartRate: $announceCurrentHeartRate,
                announceAvgHeartRate: $announceAvgHeartRate,
                viewModel: viewModel
            ))
            .modifier(ElevationHandlers(
                announceTotalAscent: $announceTotalAscent,
                announceTotalDescent: $announceTotalDescent,
                viewModel: viewModel
            ))
            .modifier(WeatherHandlers(
                announceTemperature: $announceTemperature,
                announceHumidity: $announceHumidity,
                announceWindSpeed: $announceWindSpeed,
                viewModel: viewModel
            ))
    }
}

private struct WorkoutMetricsHandlers: ViewModifier {
    @Binding var announceVoice: Bool
    @Binding var announceDistance: Bool
    @Binding var announceDuration: Bool
    @Binding var announceCaloriesBurned: Bool
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: announceVoice) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceVoice, value: newValue) }
            }
            .onChange(of: announceDistance) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceDistance, value: newValue) }
            }
            .onChange(of: announceDuration) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceDuration, value: newValue) }
            }
            .onChange(of: announceCaloriesBurned) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceCaloriesBurned, value: newValue) }
            }
    }
}

private struct SpeedHandlers: ViewModifier {
    @Binding var announceCurrentSpeed: Bool
    @Binding var announceAvgSpeed: Bool
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: announceCurrentSpeed) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceCurrentSpeed, value: newValue) }
            }
            .onChange(of: announceAvgSpeed) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceAvgSpeed, value: newValue) }
            }
    }
}

private struct HeartRateHandlers: ViewModifier {
    @Binding var announceCurrentHeartRate: Bool
    @Binding var announceAvgHeartRate: Bool
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: announceCurrentHeartRate) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceCurrentHeartRate, value: newValue) }
            }
            .onChange(of: announceAvgHeartRate) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceAvgHeartRate, value: newValue) }
            }
    }
}

private struct ElevationHandlers: ViewModifier {
    @Binding var announceTotalAscent: Bool
    @Binding var announceTotalDescent: Bool
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: announceTotalAscent) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceTotalAscent, value: newValue) }
            }
            .onChange(of: announceTotalDescent) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceTotalDescent, value: newValue) }
            }
    }
}

private struct WeatherHandlers: ViewModifier {
    @Binding var announceTemperature: Bool
    @Binding var announceHumidity: Bool
    @Binding var announceWindSpeed: Bool
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: announceTemperature) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceTemperature, value: newValue) }
            }
            .onChange(of: announceHumidity) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceHumidity, value: newValue) }
            }
            .onChange(of: announceWindSpeed) { _, newValue in
                Task { await viewModel?.saveBool(key: PreferenceKey.announceWindSpeed, value: newValue) }
            }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .appDependencies(AppDependencies.makeForPreview())
    .modelContainer(for: JogPodSchema.models, inMemory: true)
}
