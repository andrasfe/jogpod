//
//  StatsView.swift
//  JogPodWatch
//
//  Displays workout statistics and route map.
//

import SwiftUI

#if os(watchOS)
import WatchKit
#endif

// MARK: - StatsView

/// View displaying workout statistics.
///
/// Features:
/// - Route map image (if available)
/// - Key workout metrics: distance, speed, calories, duration
///
/// ## Legacy Equivalence
///
/// Replaces `StatsInterfaceController` from the legacy WatchKit implementation.
struct StatsView: View {

    // MARK: - Environment & State

    @Environment(WatchState.self) private var watchState

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Route Map Image
                mapImageView

                // Stats Grid
                statsGrid
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await WatchConnectivityManager.shared.requestStatsData()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mapImageView: some View {
        if let stats = watchState.workoutStats,
           let imageData = stats.mapImageData {
            // On watchOS, use Data directly with SwiftUI Image
            if let cgImage = createCGImage(from: imageData) {
                Image(decorative: cgImage, scale: 2.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholderMapView
            }
        } else {
            placeholderMapView
        }
    }

    private var placeholderMapView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 100)

            VStack(spacing: 4) {
                Image(systemName: "map")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)

                Text("No route available")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 8) {
            statRow(label: "Distance", value: watchState.workoutStats?.distance ?? "N/A")
            statRow(label: "Avg. Speed", value: watchState.workoutStats?.avgSpeed ?? "N/A")
            statRow(label: "Calories", value: watchState.workoutStats?.calories ?? "N/A")
            statRow(label: "Duration", value: watchState.workoutStats?.duration ?? "N/A")
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
        )
    }

    // MARK: - Image Helpers

    private func createCGImage(from data: Data) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                  pngDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            // Try JPEG if PNG fails
            guard let jpegProvider = CGDataProvider(data: data as CFData),
                  let jpegImage = CGImage(
                      jpegDataProviderSource: jpegProvider,
                      decode: nil,
                      shouldInterpolate: true,
                      intent: .defaultIntent
                  ) else {
                return nil
            }
            return jpegImage
        }
        return cgImage
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StatsView()
    }
    .environment(WatchState())
}
