//
//  ModernViews.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Modern view implementations using the new design system
//

import SwiftUI

// MARK: - ModernStreamsView
struct ModernStreamsView: View {
    @EnvironmentObject var streamDataManager: StreamDataManager
    @State private var showingAddStream = false
    @State private var userStreams: [AppStream] = []
    @State private var selectedLayout: GridLayout = .grid2x2
    @State private var showingLayoutPicker = false
    
    var body: some View {
        StreamyyyNavigationView {
            StreamyyyScreenContainer {
                VStack {
                    if userStreams.isEmpty {
                        StreamyyyEmptyState(
                            title: "No Streams Yet",
                            subtitle: "Add your first stream to get started with multi-stream viewing",
                            icon: "play.tv.fill",
                            buttonTitle: "Add Stream",
                            buttonAction: {
                                showingAddStream = true
                            }
                        )
                    } else {
                        StreamyyyScrollView {
                            VStack(spacing: StreamyyySpacing.lg) {
                                // Layout Controls
                                HStack {
                                    StreamyyyButton(
                                        title: selectedLayout.displayName,
                                        style: .tertiary,
                                        size: .small,
                                        action: {
                                            showingLayoutPicker = true
                                        }
                                    )
                                    
                                    Spacer()
                                    
                                    Text("\\(userStreams.count) streams")
                                        .captionLarge()
                                        .foregroundColor(StreamyyyColors.textSecondary)
                                }
                                .padding(.horizontal, StreamyyySpacing.md)
                                
                                // Stream Grid
                                StreamyyyGrid(columns: selectedLayout.columns.count) {
                                    ForEach(userStreams) { stream in
                                        StreamCard(stream: stream) {
                                            // Handle stream tap
                                        }
                                        .microInteraction(.standard)
                                    }
                                }
                                .padding(.horizontal, StreamyyySpacing.md)
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Streams")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Stream") {
                        showingAddStream = true
                    }
                }
            }
            .sheet(isPresented: $showingAddStream) {
                ModernAddStreamView(userStreams: $userStreams)
            }
            .actionSheet(isPresented: $showingLayoutPicker) {
                ActionSheet(
                    title: Text("Select Layout"),
                    buttons: GridLayout.allCases.map { layout in
                        .default(Text(layout.displayName)) {
                            selectedLayout = layout
                        }
                    } + [.cancel()]
                )
            }
        }
        .onAppear {
            loadUserStreams()
        }
    }
    
    private func loadUserStreams() {
        if let data = UserDefaults.standard.data(forKey: "user_streams"),
           let streams = try? JSONDecoder().decode([AppStream].self, from: data) {
            userStreams = streams
        }
    }
}

// MARK: - ModernDiscoverView
struct ModernDiscoverView: View {
    @EnvironmentObject var streamDataManager: StreamDataManager
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    
    private let categories = ["All", "Twitch", "YouTube", "Gaming", "Just Chatting", "Music"]
    
    var body: some View {
        StreamyyyNavigationView {
            StreamyyyScreenContainer {
                StreamyyyScrollView {
                    VStack(spacing: StreamyyySpacing.lg) {
                        // Search Section
                        StreamyyySearchField(
                            placeholder: "Search streams...",
                            text: $searchText,
                            onSearchTap: {
                                performSearch()
                            }
                        )
                        .padding(.horizontal, StreamyyySpacing.md)
                        
                        // Category Filter
                        StreamyyyScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: StreamyyySpacing.sm) {
                                ForEach(categories, id: \\.self) { category in
                                    StreamyyyToggleButton(
                                        title: category,
                                        isOn: .constant(selectedCategory == category),
                                        style: .tertiary,
                                        size: .small
                                    )
                                    .onTapGesture {
                                        selectedCategory = category
                                        filterStreams()
                                    }
                                }
                            }
                            .padding(.horizontal, StreamyyySpacing.md)
                        }
                        
                        // Loading state
                        if streamDataManager.isLoading {
                            StreamyyyLoadingView(
                                title: "Loading streams...",
                                style: .default
                            )
                        }
                        
                        // Error state
                        if let error = streamDataManager.error {
                            StreamyyyCard(style: .error) {
                                VStack(spacing: StreamyyySpacing.md) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(StreamyyyColors.error)
                                    
                                    Text("Error Loading Streams")
                                        .titleMedium()
                                        .foregroundColor(StreamyyyColors.textPrimary)
                                    
                                    Text(error.localizedDescription)
                                        .captionLarge()
                                        .foregroundColor(StreamyyyColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                    
                                    StreamyyyButton(
                                        title: "Retry",
                                        style: .primary,
                                        size: .medium,
                                        action: {
                                            Task {
                                                await streamDataManager.loadFeaturedStreams()
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, StreamyyySpacing.md)
                        }
                        
                        // Featured Streams
                        if !streamDataManager.featuredStreams.isEmpty {
                            StreamyyySection(title: "Featured Streams") {
                                StreamyyyScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: StreamyyySpacing.md) {
                                        ForEach(filteredStreams) { stream in
                                            StreamCard(stream: stream) {
                                                // Handle stream tap
                                            }
                                            .frame(width: 200)
                                        }
                                    }
                                    .padding(.horizontal, StreamyyySpacing.md)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await streamDataManager.loadFeaturedStreams()
            }
        }
    }
    
    private var filteredStreams: [AppStream] {
        let streams = streamDataManager.featuredStreams
        
        if selectedCategory == "All" {
            return streams
        } else {
            return streams.filter { $0.platform.lowercased() == selectedCategory.lowercased() }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        Task {
            await streamDataManager.searchStreams(query: searchText)
        }
    }
    
    private func filterStreams() {
        // Filtering is handled by the computed property
    }
}

// MARK: - ModernFavoritesView
struct ModernFavoritesView: View {
    @EnvironmentObject var streamDataManager: StreamDataManager
    @State private var favorites: [AppStream] = []
    @State private var showingStreamPlayer = false
    @State private var selectedStream: AppStream?
    
    var body: some View {
        StreamyyyNavigationView {
            StreamyyyScreenContainer {
                VStack {
                    if favorites.isEmpty {
                        StreamyyyEmptyState(
                            title: "No Favorites Yet",
                            subtitle: "Add streams to your favorites to see them here",
                            icon: "heart.fill",
                            buttonTitle: "Discover Streams",
                            buttonAction: {
                                // Navigate to discover tab
                            }
                        )
                    } else {
                        StreamyyyScrollView {
                            StreamyyyList(favorites) { stream in
                                FavoriteStreamRow(stream: stream) {
                                    selectedStream = stream
                                    showingStreamPlayer = true
                                }
                            }
                            .padding(.horizontal, StreamyyySpacing.md)
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                EditButton()
            }
            .fullScreenCover(isPresented: $showingStreamPlayer) {
                if let selectedStream = selectedStream {
                    StreamyyyStreamPlayer(stream: selectedStream, isFullScreen: .constant(true))
                }
            }
        }
        .onAppear {
            loadFavorites()
        }
        .refreshable {
            await refreshFavoriteStreams()
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favorite_streams"),
           let streams = try? JSONDecoder().decode([AppStream].self, from: data) {
            favorites = streams
        }
    }
    
    private func refreshFavoriteStreams() async {
        // Refresh favorite streams
    }
}

// MARK: - ModernProfileView
struct ModernProfileView: View {
    @EnvironmentObject var clerkManager: ClerkManager
    @State private var showingSettings = false
    @State private var showingAbout = false
    @State private var streamingStats = StreamingStats()
    
    var body: some View {
        StreamyyyNavigationView {
            StreamyyyScreenContainer {
                StreamyyyScrollView {
                    VStack(spacing: StreamyyySpacing.xl) {
                        // Profile Header
                        VStack(spacing: StreamyyySpacing.lg) {
                            Circle()
                                .fill(StreamyyyColors.primary.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(StreamyyyColors.primary)
                                )
                            
                            VStack(spacing: StreamyyySpacing.xs) {
                                Text(clerkManager.user?.firstName ?? "Stream Viewer")
                                    .titleLarge()
                                    .foregroundColor(StreamyyyColors.textPrimary)
                                
                                Text(clerkManager.user?.primaryEmailAddress?.emailAddress ?? "user@example.com")
                                    .bodyMedium()
                                    .foregroundColor(StreamyyyColors.textSecondary)
                            }
                        }
                        .padding(.top, StreamyyySpacing.lg)
                        
                        // Stats Section
                        StreamyyySection(title: "Your Statistics") {
                            HStack(spacing: StreamyyySpacing.md) {
                                StreamyyyStatsCard(
                                    title: "Streams Watched",
                                    value: "\\(streamingStats.streamsWatched)",
                                    icon: "tv.fill",
                                    color: StreamyyyColors.primary
                                )
                                
                                StreamyyyStatsCard(
                                    title: "Hours Watched",
                                    value: "\\(streamingStats.hoursWatched)",
                                    icon: "clock.fill",
                                    color: StreamyyyColors.accent
                                )
                                
                                StreamyyyStatsCard(
                                    title: "Favorite Platform",
                                    value: streamingStats.favoritePlatform,
                                    icon: "heart.fill",
                                    color: StreamyyyColors.success
                                )
                            }
                        }
                        
                        // Profile Options
                        VStack(spacing: StreamyyySpacing.md) {
                            StreamyyyInfoCard(
                                title: "Settings",
                                subtitle: "Configure your preferences",
                                icon: "gear.circle.fill",
                                onTap: {
                                    showingSettings = true
                                }
                            )
                            
                            StreamyyyInfoCard(
                                title: "About",
                                subtitle: "Learn more about Streamyyy",
                                icon: "info.circle.fill",
                                onTap: {
                                    showingAbout = true
                                }
                            )
                            
                            StreamyyyButton(
                                title: "Sign Out",
                                style: .destructive,
                                size: .medium,
                                action: {
                                    Task {
                                        try await clerkManager.signOut()
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSettings) {
                ModernSettingsView()
            }
            .sheet(isPresented: $showingAbout) {
                ModernAboutView()
            }
        }
        .onAppear {
            loadStreamingStats()
        }
    }
    
    private func loadStreamingStats() {
        streamingStats = StreamingStats(
            streamsWatched: 42,
            hoursWatched: 128,
            favoritePlatform: "Twitch"
        )
    }
}

// MARK: - FavoriteStreamRow
struct FavoriteStreamRow: View {
    let stream: AppStream
    let action: () -> Void
    
    var body: some View {
        StreamyyyCard(isInteractive: true, onTap: action) {
            HStack(spacing: StreamyyySpacing.md) {
                Circle()
                    .fill(stream.platformColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
                    Text(stream.streamerName)
                        .titleMedium()
                        .foregroundColor(StreamyyyColors.textPrimary)
                    
                    Text(stream.title)
                        .bodyMedium()
                        .foregroundColor(StreamyyyColors.textSecondary)
                        .lineLimit(1)
                    
                    if !stream.gameName.isEmpty {
                        Text(stream.gameName)
                            .captionLarge()
                            .foregroundColor(StreamyyyColors.textTertiary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: StreamyyySpacing.xs) {
                    if stream.isLive {
                        HStack(spacing: StreamyyySpacing.xs) {
                            Circle()
                                .fill(StreamyyyColors.liveIndicator)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .captionSmall()
                                .fontWeight(.bold)
                                .foregroundColor(StreamyyyColors.liveIndicator)
                        }
                        
                        if stream.viewerCount > 0 {
                            Text(stream.formattedViewerCount)
                                .captionMedium()
                                .foregroundColor(StreamyyyColors.textSecondary)
                        }
                    } else {
                        Text("OFFLINE")
                            .captionMedium()
                            .foregroundColor(StreamyyyColors.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - ModernAddStreamView
struct ModernAddStreamView: View {
    @Binding var userStreams: [AppStream]
    @Environment(\\.dismiss) private var dismiss
    
    var body: some View {
        StreamyyyNavigationView {
            StreamyyyScreenContainer {
                Text("Add Stream View")
                    .titleLarge()
                    .foregroundColor(StreamyyyColors.textPrimary)
            }
            .navigationTitle("Add Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        // Add stream logic
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ModernSettingsView
struct ModernSettingsView: View {
    @Environment(\\.dismiss) private var dismiss
    
    var body: some View {
        StreamyyyNavigationView {
            StreamyyyScreenContainer {
                Text("Settings View")
                    .titleLarge()
                    .foregroundColor(StreamyyyColors.textPrimary)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ModernAboutView
struct ModernAboutView: View {
    @Environment(\\.dismiss) private var dismiss
    
    var body: some View {
        StreamyyyNavigationView {
            StreamyyyScreenContainer {
                Text("About View")
                    .titleLarge()
                    .foregroundColor(StreamyyyColors.textPrimary)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}