//
//  PodcastPlayerView.swift
//  JogPodWatch
//
//  Podcast playback controls for the watchOS app.
//  Mirrors the iOS app's playback control functionality.
//

import SwiftUI

// MARK: - PodcastPlayerView

/// Podcast player control view.
///
/// Features:
/// - Play/pause button
/// - Skip forward/backward buttons
/// - Next track button
/// - Current podcast title display
///
/// ## Legacy Equivalence
///
/// Replaces `PodcastInterfaceController` from the legacy WatchKit implementation.
struct PodcastPlayerView: View {

    // MARK: - Environment & State

    @Environment(WatchState.self) private var watchState
    @State private var isPlaying: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Rewind / Fast Forward
            HStack(spacing: 20) {
                // Rewind Button
                controlButton(
                    systemName: "gobackward.15",
                    action: rewind
                )

                // Fast Forward Button
                controlButton(
                    systemName: "goforward.30",
                    action: fastForward
                )
            }

            // Podcast Title
            Text(watchState.podcastTitle)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(height: 50)
                .padding(.horizontal, 8)

            // Bottom Row: Play / Next Track
            HStack(spacing: 20) {
                // Play/Pause Button
                playPauseButton

                // Next Track Button
                controlButton(
                    systemName: "forward.end.fill",
                    action: nextTrack
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .navigationTitle("Podcasts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPodcastData()
        }
        .onChange(of: watchState.podcastPlaying) { _, newValue in
            isPlaying = newValue
        }
    }

    // MARK: - Subviews

    private var playPauseButton: some View {
        Button(action: togglePlayPause) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    // Offset play icon slightly for visual centering
                    .offset(x: isPlaying ? 0 : 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)

                Image(systemName: systemName)
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func togglePlayPause() {
        isPlaying.toggle()
        WatchConnectivityManager.shared.sendAction(.playPause)
    }

    private func fastForward() {
        WatchConnectivityManager.shared.sendAction(.fastForward)

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)
    }

    private func rewind() {
        WatchConnectivityManager.shared.sendAction(.rewind)

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)
    }

    private func nextTrack() {
        WatchConnectivityManager.shared.sendAction(.nextTrack)

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
    }

    private func loadPodcastData() async {
        await WatchConnectivityManager.shared.requestPodcastData()
        isPlaying = watchState.podcastPlaying
    }
}

// MARK: - WKInterfaceDevice Import

import WatchKit

// MARK: - Preview

#Preview {
    NavigationStack {
        PodcastPlayerView()
    }
    .environment(WatchState())
}
