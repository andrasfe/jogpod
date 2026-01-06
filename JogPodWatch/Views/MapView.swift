//
//  MapView.swift
//  JogPodWatch
//
//  Map view showing the user's current location during workout.
//  Uses watchOS MapKit for native map display.
//

import SwiftUI
import MapKit

// MARK: - MapView

/// Map view displaying the user's current location.
///
/// Features:
/// - Real-time location updates from iPhone
/// - Centered map with user annotation
/// - Automatic region updates as location changes
///
/// ## Legacy Equivalence
///
/// Replaces `MapInterfaceController` from the legacy WatchKit implementation.
/// Uses the modern SwiftUI Map view instead of WKInterfaceMap.
///
/// ## watchOS 10+ Features
///
/// Uses the new MapKit for SwiftUI APIs available in watchOS 10+.
struct MapView: View {

    // MARK: - Environment & State

    @Environment(WatchState.self) private var watchState
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition = .automatic
    @State private var hasReceivedLocation = false

    // MARK: - Constants

    private let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)

    // MARK: - Body

    var body: some View {
        ZStack {
            mapContent

            if !hasReceivedLocation {
                noLocationOverlay
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await WatchConnectivityManager.shared.notifyMapOpened()
        }
        .onDisappear {
            WatchConnectivityManager.shared.notifyMapClosed()
        }
        .onChange(of: watchState.currentLocation) { _, newLocation in
            if let location = newLocation {
                updateMapPosition(for: location)
                hasReceivedLocation = true
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mapContent: some View {
        if let location = watchState.currentLocation {
            Map(position: $position) {
                // User Location Annotation
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                )) {
                    userLocationMarker
                }
            }
            .mapStyle(.standard)
            .mapControlVisibility(.hidden)
        } else {
            Map(position: $position)
                .mapStyle(.standard)
                .mapControlVisibility(.hidden)
        }
    }

    private var userLocationMarker: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 30, height: 30)

            // Main dot
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)

            // Inner highlight
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
    }

    private var noLocationOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Waiting for location...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if !watchState.workoutInProgress {
                Text("Start a workout to track location")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Helpers

    private func updateMapPosition(for location: WatchLocation) {
        let coordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )

        let region = MKCoordinateRegion(
            center: coordinate,
            span: defaultSpan
        )

        withAnimation(.easeInOut(duration: 0.3)) {
            position = .region(region)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MapView()
    }
    .environment(WatchState())
}
