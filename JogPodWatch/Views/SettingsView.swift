//
//  SettingsView.swift
//  JogPodWatch
//
//  Settings view for unit preferences and app configuration.
//

import SwiftUI

// MARK: - SettingsView

/// Settings view for the watchOS app.
///
/// Features:
/// - Unit system selection (metric/imperial)
/// - Connection status display
/// - App version information
struct SettingsView: View {

    // MARK: - Environment & State

    @Environment(WatchState.self) private var watchState
    @AppStorage("unitSystem") private var unitSystemRaw: String = UnitSystem.metric.rawValue

    private var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        set { unitSystemRaw = newValue.rawValue }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Unit System Section
            Section {
                Picker("Units", selection: Binding(
                    get: { unitSystem },
                    set: { newValue in
                        unitSystemRaw = newValue.rawValue
                        watchState.unitSystem = newValue
                    }
                )) {
                    ForEach(UnitSystem.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            } header: {
                Text("Preferences")
            }

            // Connection Status Section
            Section {
                connectionStatusRow
                if watchState.pendingSyncCount > 0 {
                    pendingSyncRow
                }
            } header: {
                Text("Connection")
            }

            // About Section
            Section {
                aboutRow(label: "Version", value: appVersion)
                aboutRow(label: "Build", value: buildNumber)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var connectionStatusRow: some View {
        HStack {
            Text("iPhone")
                .font(.system(size: 14))

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(watchState.isReachable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(watchState.isReachable ? "Connected" : "Not Connected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pendingSyncRow: some View {
        Button {
            Task {
                await WorkoutDataSync.shared.forceSyncAll()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(watchState.pendingSyncCount) pending")
                        .font(.system(size: 12))
                    Text("Tap to sync now")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .disabled(!watchState.isReachable)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))

            Spacer()

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(WatchState())
}
