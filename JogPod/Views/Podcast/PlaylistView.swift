//
//  PlaylistView.swift
//  JogPod
//
//  Podcast playlist management view for browsing and managing episodes.
//

import SwiftUI
import SwiftData

// MARK: - PlaylistView

/// The podcast playlist management view.
///
/// This view corresponds to the legacy `PodcastTableViewController` and provides:
/// - List of subscribed podcasts and their episodes
/// - Episode playback controls
/// - Add/remove podcast functionality
/// - Episode filtering and sorting
/// - Download management for offline playback
///
/// ## Legacy Equivalence
///
/// This view replaces:
/// - `PodcastTableViewController.h/.m`
/// - `SlidingPodcastViewController.h/.m`
/// - `PlayItemViewController.h/.m`
///
/// ## View Hierarchy
///
/// ```
/// PlaylistView
/// +-- NavigationStack
///     +-- List
///     |   +-- Section: Now Playing
///     |   |   +-- CurrentEpisodeRow
///     |   +-- Section: Up Next
///     |   |   +-- EpisodeRow (foreach)
///     |   +-- Section: Podcasts
///     |       +-- PodcastRow (foreach)
///     +-- Toolbar
///         +-- Add Podcast Button
///         +-- Edit Button
/// ```
///
/// ## Navigation Destinations
///
/// - `PodcastDetailView`: Shows podcast feed details and episodes
/// - `EpisodeDetailView`: Shows individual episode information
/// - `AddPodcastView`: Search and add new podcasts
///
/// ## Accessibility
///
/// - List items have clear accessibility labels
/// - Swipe actions have accessibility hints
/// - Supports VoiceOver navigation
/// - Supports Dynamic Type
public struct PlaylistView: View {

    // MARK: - Environment

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    // MARK: - Queries

    @Query(sort: \PodcastFeed.title, order: .forward)
    private var podcasts: [PodcastFeed]

    @Query(
        filter: #Predicate<PodcastEpisode> { $0.isCurrentInPlayer == true }
    )
    private var currentEpisodes: [PodcastEpisode]

    @Query(
        filter: #Predicate<PodcastEpisode> { $0.isInQueue == true },
        sort: \PodcastEpisode.index,
        order: .forward
    )
    private var queuedEpisodes: [PodcastEpisode]

    // MARK: - State

    /// Whether the add podcast sheet is presented.
    @State private var showingAddPodcast: Bool = false

    /// The search text for filtering episodes.
    @State private var searchText: String = ""

    /// Whether to show a refresh indicator.
    @State private var isRefreshing: Bool = false

    /// Error message to display.
    @State private var errorMessage: String?

    /// Whether an error alert is showing.
    @State private var showingError: Bool = false

    // MARK: - Computed Properties

    private var currentEpisode: PodcastEpisode? {
        currentEpisodes.first
    }

    private var upNextEpisodes: [PodcastEpisode] {
        // Filter out the current episode and show only queued episodes
        queuedEpisodes.filter { !$0.isCurrentInPlayer }
    }

    private var filteredEpisodes: [PodcastEpisode] {
        guard !searchText.isEmpty else {
            return upNextEpisodes
        }
        return upNextEpisodes.filter { episode in
            episode.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            (episode.feed?.title?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if podcasts.isEmpty && queuedEpisodes.isEmpty {
                emptyStateView
            } else {
                playlistContent
            }
        }
        .navigationTitle("Playlist")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search episodes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddPodcast = true }) {
                    Label("Add Podcast", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddPodcast) {
            AddPodcastView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .refreshable {
            await refreshPlaylist()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Podcasts", systemImage: "music.note.list")
        } description: {
            Text("Add podcasts to listen to during your workouts.")
        } actions: {
            Button(action: { showingAddPodcast = true }) {
                Text("Add Podcast")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Playlist Content

    private var playlistContent: some View {
        List {
            // Now Playing Section
            if let episode = currentEpisode {
                Section("Now Playing") {
                    CurrentEpisodeRow(episode: episode)
                }
            }

            // Up Next Section
            if !filteredEpisodes.isEmpty {
                Section {
                    ForEach(filteredEpisodes) { episode in
                        NavigationLink(value: episode) {
                            EpisodeRowView(episode: episode)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                removeFromUpNext(episode)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                playEpisodeFromUpNext(episode)
                            } label: {
                                Label("Play", systemImage: "play.fill")
                            }
                            .tint(.green)
                        }
                    }
                    .onMove(perform: moveEpisodes)
                } header: {
                    HStack {
                        Text("Up Next")
                        Spacer()
                        Text("\(filteredEpisodes.count) episodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Podcasts Section
            if !podcasts.isEmpty {
                Section {
                    ForEach(podcasts) { podcast in
                        NavigationLink(value: podcast) {
                            PodcastRowView(podcast: podcast)
                        }
                    }
                    .onDelete(perform: deletePodcasts)
                } header: {
                    HStack {
                        Text("Podcasts")
                        Spacer()
                        Text("\(podcasts.count) subscribed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: PodcastFeed.self) { podcast in
            PodcastDetailView(podcast: podcast)
        }
        .navigationDestination(for: PodcastEpisode.self) { episode in
            EpisodeDetailView(episode: episode)
        }
    }

    // MARK: - Actions

    private func refreshPlaylist() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await dependencies.audioPlayerService?.loadPlaylist()
        } catch {
            errorMessage = "Failed to refresh playlist: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func moveEpisodes(from source: IndexSet, to destination: Int) {
        // Create a mutable copy for reordering
        var episodes = filteredEpisodes

        // Perform the move
        episodes.move(fromOffsets: source, toOffset: destination)

        // Update indices in persistence
        Task {
            for (newIndex, episode) in episodes.enumerated() {
                do {
                    try await dependencies.persistenceManager.updateEpisodeIndex(
                        episode.persistentModelID,
                        newIndex: Int32(newIndex)
                    )
                } catch {
                    errorMessage = "Failed to reorder episodes: \(error.localizedDescription)"
                    showingError = true
                    break
                }
            }

            // Notify player that playlist needs refresh
            try? await dependencies.audioPlayerService?.loadPlaylist()
        }
    }

    private func deleteEpisodes(at offsets: IndexSet) {
        let episodesToDelete = offsets.map { filteredEpisodes[$0] }

        Task {
            for episode in episodesToDelete {
                do {
                    try await dependencies.persistenceManager.deletePodcastEpisode(
                        episode.persistentModelID
                    )
                } catch {
                    errorMessage = "Failed to delete episode: \(error.localizedDescription)"
                    showingError = true
                }
            }

            // Refresh playlist after deletion
            try? await dependencies.audioPlayerService?.loadPlaylist()
        }
    }

    private func removeFromUpNext(_ episode: PodcastEpisode) {
        Task {
            do {
                // Remove from queue (sets isInQueue = false) without deleting the episode
                try await dependencies.persistenceManager.removeEpisodeFromQueue(
                    episode.persistentModelID
                )
                try await dependencies.audioPlayerService?.loadPlaylist()
            } catch {
                errorMessage = "Failed to remove episode: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func playEpisodeFromUpNext(_ episode: PodcastEpisode) {
        Task {
            do {
                try await dependencies.audioPlayerService?.goToEpisode(episode.persistentModelID)
                try dependencies.audioPlayerService?.play()
            } catch {
                errorMessage = "Failed to play episode: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func deletePodcasts(at offsets: IndexSet) {
        let podcastsToDelete = offsets.map { podcasts[$0] }

        Task {
            for podcast in podcastsToDelete {
                do {
                    try await dependencies.persistenceManager.deletePodcastFeed(
                        podcast.persistentModelID
                    )
                } catch {
                    errorMessage = "Failed to delete podcast: \(error.localizedDescription)"
                    showingError = true
                }
            }

            // Refresh playlist after deletion
            try? await dependencies.audioPlayerService?.loadPlaylist()
        }
    }
}

// MARK: - CurrentEpisodeRow

/// Row displaying the currently playing episode with playback controls.
struct CurrentEpisodeRow: View {
    let episode: PodcastEpisode

    @Environment(AppDependencies.self) private var dependencies

    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncArtworkView(urlString: episode.feed?.imageUrl, size: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let feedTitle = episode.feed?.title {
                    Text(feedTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                ProgressView(value: progress)
                    .tint(.accentColor)
            }

            Spacer()

            // Play/Pause button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(episode.displayTitle)")
        .accessibilityHint("Double tap to \(isPlaying ? "pause" : "play")")
        .onAppear {
            updatePlaybackState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerStatusChanged)) { _ in
            updatePlaybackState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playbackPositionUpdated)) { notification in
            if let currentTime = notification.userInfo?["currentTime"] as? TimeInterval,
               let duration = notification.userInfo?["duration"] as? TimeInterval,
               duration > 0 {
                progress = currentTime / duration
            }
        }
    }

    private func togglePlayback() {
        Task {
            try? dependencies.audioPlayerService?.togglePlayPause()
            updatePlaybackState()
        }
    }

    private func updatePlaybackState() {
        isPlaying = dependencies.audioPlayerService?.isPlaying ?? false
        if let audioProgress = dependencies.audioPlayerService?.progress {
            progress = audioProgress.progress
        }
    }
}

// MARK: - EpisodeRowView

/// Row displaying an episode in the playlist with play button, duration, and download status.
public struct EpisodeRowView: View {
    let episode: PodcastEpisode

    @Environment(AppDependencies.self) private var dependencies
    @State private var isCached: Bool = false
    @State private var isDownloading: Bool = false

    public var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: playEpisode) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: 32)

            // Artwork
            AsyncArtworkView(urlString: episode.feed?.imageUrl, size: 44)

            // Episode info
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.displayTitle)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let feedTitle = episode.feed?.title {
                        Text(feedTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let date = episode.releaseDate {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Status indicators
            VStack(alignment: .trailing, spacing: 4) {
                // In Queue indicator
                if episode.isInQueue {
                    Label("In Queue", systemImage: "text.badge.checkmark")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .labelStyle(.titleAndIcon)
                }

                // Download status
                HStack(spacing: 4) {
                    if isDownloading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if isCached {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "cloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(episode.displayTitle)
        .accessibilityHint("Double tap to view episode details")
        .task {
            await checkCacheStatus()
        }
    }

    private var formattedDuration: String? {
        // Check if we have a stored duration from parsing
        // For now return placeholder - will be populated from audio metadata
        return nil
    }

    private func playEpisode() {
        Task {
            do {
                try await dependencies.audioPlayerService?.goToEpisode(episode.persistentModelID)
                try dependencies.audioPlayerService?.play()
            } catch {
                // Handle error
            }
        }
    }

    private func checkCacheStatus() async {
        if let mediaLink = episode.enclosureMediaLink {
            isCached = await MediaCacheService.shared.isCached(mediaLink)
        }
    }
}

// MARK: - EpisodeRowWithActions

/// Episode row with swipe actions and context menu for playlist management.
struct EpisodeRowWithActions: View {
    let episode: PodcastEpisode
    let onPlayNow: () -> Void
    let onAddToUpNext: () -> Void
    let onPlayNext: () -> Void

    var body: some View {
        NavigationLink(value: episode) {
            EpisodeRowView(episode: episode)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onAddToUpNext) {
                Label("Up Next", systemImage: "text.badge.plus")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onPlayNow) {
                Label("Play", systemImage: "play.fill")
            }
            .tint(.green)
        }
        .contextMenu {
            Button(action: onPlayNow) {
                Label("Play Now", systemImage: "play.fill")
            }

            Button(action: onAddToUpNext) {
                Label("Add to Up Next", systemImage: "text.badge.plus")
            }

            Button(action: onPlayNext) {
                Label("Play Next", systemImage: "text.insert")
            }
        }
    }
}

// MARK: - PodcastRowView

/// Row displaying a podcast feed with artwork and episode count.
struct PodcastRowView: View {
    let podcast: PodcastFeed

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncArtworkView(urlString: podcast.imageUrl, size: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(podcast.title ?? "Unknown Podcast")
                    .font(.headline)
                    .lineLimit(1)

                if let summary = podcast.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text("\(podcast.episodeCount) episodes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(podcast.title ?? "Unknown Podcast")
        .accessibilityHint("\(podcast.episodeCount) episodes. Double tap to view episodes.")
    }
}

// MARK: - AsyncArtworkView

/// Async loading artwork view with placeholder.
struct AsyncArtworkView: View {
    let urlString: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        artworkPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        artworkPlaceholder
                    @unknown default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size > 50 ? 8 : 6))
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: size > 50 ? 8 : 6)
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
                    .font(.system(size: size * 0.3))
            }
    }
}

// MARK: - AddPodcastView

/// Sheet view for searching and adding new podcasts.
///
/// This view corresponds to the legacy `PodcastFilterViewController` and
/// `PublicPodcastSearchTableViewController`, providing:
/// - Search by keyword using iTunes API
/// - Direct RSS URL entry
/// - Podcast preview and subscription
struct AddPodcastView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext

    @State private var searchText: String = ""
    @State private var feedURL: String = ""
    @State private var searchResults: [iTunesPodcast] = []
    @State private var isSearching: Bool = false
    @State private var isAddingFeed: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false
    @State private var selectedTab: AddPodcastTab = .search

    enum AddPodcastTab: String, CaseIterable {
        case search = "Search"
        case url = "RSS URL"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Add Method", selection: $selectedTab) {
                    ForEach(AddPodcastTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case .search:
                    searchView
                case .url:
                    urlEntryView
                }
            }
            .navigationTitle("Add Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Search View

    private var searchView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search podcasts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await searchPodcasts() }
                    }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

            if isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                Spacer()
            } else if searchResults.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("Search for podcasts")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Enter keywords to find podcasts from the iTunes directory.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                searchResultsList
            }
        }
    }

    private var searchResultsList: some View {
        List {
            ForEach(searchResults) { podcast in
                Button(action: { Task { await subscribeToPodcast(podcast) } }) {
                    HStack(spacing: 12) {
                        AsyncArtworkView(urlString: podcast.artworkUrl100, size: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(podcast.collectionName)
                                .font(.headline)
                                .lineLimit(2)
                                .foregroundStyle(.primary)

                            Text(podcast.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let genres = podcast.genres?.joined(separator: ", ") {
                                Text(genres)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isAddingFeed)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - URL Entry View

    private var urlEntryView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "link")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("Enter RSS Feed URL")
                .font(.headline)

            Text("Paste the URL of a podcast RSS feed to subscribe directly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("https://example.com/feed.xml", text: $feedURL)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal)

            Button(action: { Task { await addFeedByURL() } }) {
                if isAddingFeed {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Add Podcast")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(feedURL.isEmpty || isAddingFeed)
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Actions

    private func searchPodcasts() async {
        guard !searchText.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await searchiTunes(query: searchText)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func subscribeToPodcast(_ podcast: iTunesPodcast) async {
        guard let feedURLString = podcast.feedUrl else {
            errorMessage = "This podcast doesn't have an RSS feed URL."
            showingError = true
            return
        }

        isAddingFeed = true
        defer { isAddingFeed = false }

        do {
            try await addPodcastFeed(urlString: feedURLString)
            dismiss()
        } catch {
            errorMessage = "Failed to add podcast: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func addFeedByURL() async {
        guard !feedURL.isEmpty else { return }

        isAddingFeed = true
        defer { isAddingFeed = false }

        do {
            try await addPodcastFeed(urlString: feedURL)
            dismiss()
        } catch {
            errorMessage = "Failed to add podcast: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func addPodcastFeed(urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw AddPodcastError.invalidURL
        }

        // Check if already subscribed
        let existingFeed = try await dependencies.persistenceManager.fetchPodcastFeed(byLink: urlString)
        if existingFeed != nil {
            throw AddPodcastError.alreadySubscribed
        }

        // Fetch and parse the feed
        let feedService = FeedService()
        let parsedFeed = try await feedService.fetchFeed(from: url)

        // Debug: Log parsed feed info
        print("[AddPodcast] Feed title: \(parsedFeed.info.title ?? "nil")")
        print("[AddPodcast] Total items parsed: \(parsedFeed.items.count)")

        // Create podcast feed in persistence
        let feedID = try await dependencies.persistenceManager.createPodcastFeed(
            title: parsedFeed.info.title,
            link: urlString,
            summary: parsedFeed.info.summary,
            imageUrl: parsedFeed.info.imageUrl
        )

        print("[AddPodcast] Created feed with ID: \(feedID)")

        // Create episodes from the parsed feed (limit to most recent)
        let maxEpisodes = 10
        var createdCount = 0
        for (index, item) in parsedFeed.items.prefix(maxEpisodes).enumerated() {
            let mediaUrl = item.enclosures.first?.url
            print("[AddPodcast] Episode \(index): '\(item.title ?? "nil")' - enclosure: \(mediaUrl ?? "nil")")

            _ = try await dependencies.persistenceManager.createPodcastEpisode(
                title: item.title,
                identifier: item.identifier,
                enclosureMediaLink: mediaUrl,
                releaseDate: item.date,
                feedIdentifier: feedID
            )
            createdCount += 1
        }

        print("[AddPodcast] Created \(createdCount) episodes for feed")

        // Refresh the audio player's playlist
        try await dependencies.audioPlayerService?.loadPlaylist()
        print("[AddPodcast] Playlist refreshed")
    }

    // MARK: - iTunes Search

    private func searchiTunes(query: String) async throws -> [iTunesPodcast] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&media=podcast&limit=25"

        guard let url = URL(string: urlString) else {
            throw AddPodcastError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AddPodcastError.searchFailed
        }

        let searchResponse = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        return searchResponse.results
    }
}

// MARK: - iTunes Models

struct iTunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [iTunesPodcast]
}

struct iTunesPodcast: Decodable, Identifiable {
    var id: Int { collectionId }

    let collectionId: Int
    let collectionName: String
    let artistName: String
    let artworkUrl100: String?
    let artworkUrl600: String?
    let feedUrl: String?
    let genres: [String]?
    let trackCount: Int?
}

// MARK: - AddPodcastError

enum AddPodcastError: LocalizedError {
    case invalidURL
    case alreadySubscribed
    case searchFailed
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .alreadySubscribed:
            return "You are already subscribed to this podcast."
        case .searchFailed:
            return "Search failed. Please try again."
        case .parseFailed:
            return "Could not parse the podcast feed."
        }
    }
}

// MARK: - PodcastDetailView

/// Detail view showing a podcast feed's episodes.
///
/// This view corresponds to the legacy `PodcastDetailViewController` and provides:
/// - Podcast artwork and metadata
/// - Episode list sorted by release date
/// - Subscribe/unsubscribe functionality
/// - Refresh feed capability
struct PodcastDetailView: View {
    let podcast: PodcastFeed

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @State private var isRefreshing: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false
    @State private var showingUnsubscribeConfirmation: Bool = false

    var body: some View {
        List {
            // Header section
            Section {
                podcastHeader
            }

            // Episodes section
            Section {
                if podcast.sortedEpisodes.isEmpty {
                    ContentUnavailableView(
                        "No Episodes",
                        systemImage: "waveform",
                        description: Text("Pull to refresh and check for new episodes.")
                    )
                } else {
                    ForEach(podcast.sortedEpisodes) { episode in
                        EpisodeRowWithActions(
                            episode: episode,
                            onPlayNow: { playEpisodeNow(episode) },
                            onAddToUpNext: { addToUpNext(episode) },
                            onPlayNext: { playEpisodeNext(episode) }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Episodes")
                    Spacer()
                    Text("\(podcast.episodeCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(podcast.title ?? "Podcast")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PodcastEpisode.self) { episode in
            EpisodeDetailView(episode: episode)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { Task { await refreshFeed() } }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive, action: { showingUnsubscribeConfirmation = true }) {
                        Label("Unsubscribe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            await refreshFeed()
        }
        .confirmationDialog(
            "Unsubscribe from \(podcast.title ?? "this podcast")?",
            isPresented: $showingUnsubscribeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unsubscribe", role: .destructive) {
                Task { await unsubscribe() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the podcast and all its episodes from your library.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var podcastHeader: some View {
        VStack(alignment: .center, spacing: 16) {
            // Artwork
            AsyncArtworkView(urlString: podcast.imageUrl, size: 150)
                .shadow(radius: 8)

            // Title
            Text(podcast.title ?? "Unknown Podcast")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            // Summary
            if let summary = podcast.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }

            // Website link
            if let link = podcast.link, let url = URL(string: link) {
                Link(destination: url) {
                    Label("Visit Website", systemImage: "safari")
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    private func refreshFeed() async {
        guard let feedURLString = podcast.link, let feedURL = URL(string: feedURLString) else {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let feedService = FeedService()
            let parsedFeed = try await feedService.fetchFeed(from: feedURL)

            // Find existing episode identifiers
            let existingIdentifiers = Set(podcast.episodes.compactMap { $0.identifier })

            // Add new episodes
            for item in parsedFeed.items {
                guard let identifier = item.identifier,
                      !existingIdentifiers.contains(identifier) else {
                    continue
                }

                _ = try await dependencies.persistenceManager.createPodcastEpisode(
                    title: item.title,
                    identifier: identifier,
                    enclosureMediaLink: item.enclosures.first?.url,
                    releaseDate: item.date,
                    feedIdentifier: podcast.persistentModelID
                )
            }

            // Refresh the audio player's playlist
            try await dependencies.audioPlayerService?.loadPlaylist()

        } catch {
            errorMessage = "Failed to refresh feed: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func unsubscribe() async {
        do {
            try await dependencies.persistenceManager.deletePodcastFeed(podcast.persistentModelID)
            try await dependencies.audioPlayerService?.loadPlaylist()
        } catch {
            errorMessage = "Failed to unsubscribe: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Playlist Actions

    private func playEpisodeNow(_ episode: PodcastEpisode) {
        print("[PodcastDetailView] playEpisodeNow called for: \(episode.displayTitle)")
        Task {
            do {
                try await dependencies.audioPlayerService?.goToEpisode(episode.persistentModelID)
                try dependencies.audioPlayerService?.play()
                print("[PodcastDetailView] playEpisodeNow succeeded")
            } catch {
                print("[PodcastDetailView] playEpisodeNow failed: \(error)")
                errorMessage = "Failed to play episode: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func addToUpNext(_ episode: PodcastEpisode) {
        print("[PodcastDetailView] addToUpNext called for: \(episode.displayTitle)")
        Task {
            do {
                try await dependencies.audioPlayerService?.addToEndOfQueue(episode.persistentModelID)
                print("[PodcastDetailView] addToUpNext succeeded")
            } catch {
                print("[PodcastDetailView] addToUpNext failed: \(error)")
                errorMessage = "Failed to add to queue: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func playEpisodeNext(_ episode: PodcastEpisode) {
        print("[PodcastDetailView] playEpisodeNext called for: \(episode.displayTitle)")
        Task {
            do {
                try await dependencies.audioPlayerService?.addToPlayNext(episode.persistentModelID)
                print("[PodcastDetailView] playEpisodeNext succeeded")
            } catch {
                print("[PodcastDetailView] playEpisodeNext failed: \(error)")
                errorMessage = "Failed to add to queue: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

// MARK: - EpisodeDetailView

/// Detail view for a podcast episode with show notes and playback controls.
///
/// This view provides:
/// - Episode artwork and metadata
/// - Play/pause controls
/// - Download for offline playback
/// - Show notes/description
/// - Share functionality
struct EpisodeDetailView: View {
    let episode: PodcastEpisode

    @Environment(AppDependencies.self) private var dependencies
    @State private var isPlaying: Bool = false
    @State private var isCached: Bool = false
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showingError: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                episodeHeader

                Divider()

                // Action buttons
                actionButtons

                Divider()

                // Show notes
                showNotesSection
            }
            .padding()
        }
        .navigationTitle("Episode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .task {
            await checkCacheStatus()
            updatePlaybackState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerStatusChanged)) { _ in
            updatePlaybackState()
        }
    }

    private var episodeHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // Artwork
            AsyncArtworkView(urlString: episode.feed?.imageUrl, size: 100)
                .shadow(radius: 4)

            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(episode.displayTitle)
                    .font(.headline)

                // Podcast name
                if let feedTitle = episode.feed?.title {
                    Text(feedTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Release date
                if let date = episode.releaseDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Duration and cache status
                HStack(spacing: 12) {
                    if isCached {
                        Label("Downloaded", systemImage: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if isDownloading {
                        Label("Downloading", systemImage: "arrow.down.circle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Play button
            Button(action: playEpisode) {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Download button
            if isCached {
                Button(role: .destructive, action: deleteFromCache) {
                    Label("Remove", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else if isDownloading {
                Button(action: cancelDownload) {
                    VStack(spacing: 4) {
                        ProgressView(value: downloadProgress)
                        Text("Cancel")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                Button(action: downloadEpisode) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var showNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Show Notes")
                .font(.headline)

            if let summary = episode.summary {
                // Render HTML content as attributed string if possible
                Text(summary.strippingHTML())
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("No show notes available.")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
    }

    private var shareText: String {
        var text = episode.displayTitle
        if let feedTitle = episode.feed?.title {
            text += " - \(feedTitle)"
        }
        if let link = episode.link {
            text += "\n\(link)"
        }
        return text
    }

    // MARK: - Actions

    private func playEpisode() {
        Task {
            do {
                if isPlaying {
                    dependencies.audioPlayerService?.pause()
                } else {
                    try await dependencies.audioPlayerService?.goToEpisode(episode.persistentModelID)
                    try dependencies.audioPlayerService?.play()
                }
                updatePlaybackState()
            } catch {
                errorMessage = "Failed to play episode: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func downloadEpisode() {
        guard let mediaLink = episode.enclosureMediaLink,
              let feedLink = episode.feed?.link else {
            errorMessage = "Episode has no media URL."
            showingError = true
            return
        }

        isDownloading = true

        Task {
            do {
                try await MediaCacheService.shared.cacheEpisode(
                    from: mediaLink,
                    feedURL: feedLink
                )
                isCached = true
                isDownloading = false
            } catch {
                isDownloading = false
                errorMessage = "Download failed: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func cancelDownload() {
        guard let mediaLink = episode.enclosureMediaLink,
              let url = URL(string: mediaLink) else { return }

        Task {
            await MediaCacheService.shared.cancelDownload(for: url)
            isDownloading = false
        }
    }

    private func deleteFromCache() {
        guard let mediaLink = episode.enclosureMediaLink else { return }

        Task {
            do {
                try await MediaCacheService.shared.deleteFromCache(mediaLink)
                isCached = false
            } catch {
                errorMessage = "Failed to remove download: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func checkCacheStatus() async {
        if let mediaLink = episode.enclosureMediaLink {
            isCached = await MediaCacheService.shared.isCached(mediaLink)
        }
    }

    private func updatePlaybackState() {
        let currentItem = dependencies.audioPlayerService?.currentItem
        let isThisEpisode = currentItem?.episodeID == episode.persistentModelID
        isPlaying = isThisEpisode && (dependencies.audioPlayerService?.isPlaying ?? false)
    }
}

// MARK: - String Extension

extension String {
    /// Strips HTML tags from a string.
    func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }

        // Fallback: simple regex-based stripping
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlaylistView()
    }
    .appDependencies(AppDependencies.makeForPreview())
    .modelContainer(for: JogPodSchema.models, inMemory: true)
}
