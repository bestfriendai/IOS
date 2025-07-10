//
//  EnhancedDiscoverView.swift
//  StreamyyyApp
//
//  Enhanced multi-platform stream discovery and search
//  Created by Claude Code on 2025-07-10
//

import SwiftUI

// MARK: - Enhanced Discover View

struct EnhancedDiscoverView: View {
    @StateObject private var discoveryService = EnhancedDiscoveryService(
        twitchService: TwitchAPIService(),
        youtubeService: YouTubeService(),
        rumbleService: RumbleService()
    )
    
    @State private var searchText = ""
    @State private var selectedPlatforms: Set<Platform> = [.twitch, .youtube, .rumble]
    @State private var showFilters = false
    @State private var searchFilters = SearchFilters()
    @State private var selectedTab: DiscoveryTab = .featured
    
    enum DiscoveryTab: String, CaseIterable {
        case featured = "Featured"
        case trending = "Trending"
        case categories = "Categories"
        case search = "Search"
        
        var systemImage: String {
            switch self {
            case .featured: return "star.fill"
            case .trending: return "flame.fill"
            case .categories: return "grid.circle.fill"
            case .search: return "magnifyingglass"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchSection
                
                // Tab selector
                tabSelector
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedTab {
                        case .featured:
                            featuredContent
                        case .trending:
                            trendingContent
                        case .categories:
                            categoriesContent
                        case .search:
                            searchContent
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Tab bar spacing
                }
                .refreshable {
                    await refreshContent()
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilters = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FiltersView(
                    selectedPlatforms: $selectedPlatforms,
                    searchFilters: $searchFilters
                )
            }
            .task {
                await loadInitialContent()
            }
        }
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search streams, channels, categories...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        selectedTab = .search
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // Platform filters
            platformFilters
        }
        .padding(.horizontal)
    }
    
    private var platformFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Platform.popularPlatforms, id: \.self) { platform in
                    PlatformFilterChip(
                        platform: platform,
                        isSelected: selectedPlatforms.contains(platform)
                    ) {
                        togglePlatform(platform)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DiscoveryTab.allCases, id: \.self) { tab in
                Button(action: { 
                    selectedTab = tab
                    if tab == .search && !searchText.isEmpty {
                        performSearch()
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.title3)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(.regularMaterial)
    }
    
    // MARK: - Content Sections
    
    private var featuredContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Featured Streams", systemImage: "star.fill", color: .orange)
            
            if discoveryService.isLoading && discoveryService.featuredStreams.isEmpty {
                LoadingView()
            } else if discoveryService.featuredStreams.isEmpty {
                EmptyStateView(
                    title: "No Featured Streams",
                    subtitle: "Check your internet connection and try again",
                    systemImage: "star"
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(discoveryService.featuredStreams) { stream in
                        StreamDiscoveryCard(stream: stream)
                    }
                }
            }
        }
    }
    
    private var trendingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Trending Now", systemImage: "flame.fill", color: .red)
            
            if discoveryService.isLoading && discoveryService.trendingStreams.isEmpty {
                LoadingView()
            } else if discoveryService.trendingStreams.isEmpty {
                EmptyStateView(
                    title: "No Trending Streams",
                    subtitle: "Check back later for trending content",
                    systemImage: "flame"
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(discoveryService.trendingStreams) { stream in
                        StreamDiscoveryCard(stream: stream)
                    }
                }
            }
        }
    }
    
    private var categoriesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Popular Categories", systemImage: "grid.circle.fill", color: .blue)
            
            if discoveryService.popularCategories.isEmpty {
                LoadingView()
            } else {
                LazyVGrid(columns: categoryGridColumns, spacing: 16) {
                    ForEach(discoveryService.popularCategories) { category in
                        CategoryCard(category: category) {
                            searchForCategory(category.name)
                        }
                    }
                }
            }
        }
    }
    
    private var searchContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !searchText.isEmpty {
                sectionHeader("Search Results for \"\(searchText)\"", systemImage: "magnifyingglass", color: .purple)
            }
            
            if discoveryService.isLoading && discoveryService.searchResults.isEmpty {
                LoadingView()
            } else if searchText.isEmpty {
                searchSuggestions
            } else if discoveryService.searchResults.isEmpty {
                EmptyStateView(
                    title: "No Results Found",
                    subtitle: "Try adjusting your search terms or filters",
                    systemImage: "magnifyingglass"
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(discoveryService.searchResults) { stream in
                        StreamDiscoveryCard(stream: stream)
                    }
                }
            }
        }
    }
    
    private var searchSuggestions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Popular Searches")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: 12)
            ], spacing: 12) {
                ForEach(popularSearchTerms, id: \.self) { term in
                    Button(action: {
                        searchText = term
                        performSearch()
                    }) {
                        Text(term)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(color)
                .font(.title2)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
        }
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 160), spacing: 16)
        ]
    }
    
    private var categoryGridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 140), spacing: 16)
        ]
    }
    
    private var popularSearchTerms: [String] {
        ["Gaming", "Music", "Talk Shows", "Art", "Cooking", "Sports", "News", "Education"]
    }
    
    // MARK: - Actions
    
    private func togglePlatform(_ platform: Platform) {
        if selectedPlatforms.contains(platform) {
            selectedPlatforms.remove(platform)
        } else {
            selectedPlatforms.insert(platform)
        }
        
        // Update filters and refresh if needed
        searchFilters = SearchFilters(
            platforms: selectedPlatforms,
            categories: searchFilters.categories,
            languages: searchFilters.languages,
            liveOnly: searchFilters.liveOnly,
            minViewers: searchFilters.minViewers,
            maxViewers: searchFilters.maxViewers
        )
        
        if selectedTab == .search && !searchText.isEmpty {
            performSearch()
        }
    }
    
    private func performSearch() {
        Task {
            await discoveryService.search(query: searchText, filters: searchFilters)
        }
    }
    
    private func searchForCategory(_ categoryName: String) {
        searchText = categoryName
        selectedTab = .search
        performSearch()
    }
    
    private func loadInitialContent() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await discoveryService.loadFeaturedContent()
            }
            
            group.addTask {
                await discoveryService.loadTrendingContent()
            }
            
            group.addTask {
                await discoveryService.loadPopularCategories()
            }
        }
    }
    
    private func refreshContent() async {
        await loadInitialContent()
    }
}

// MARK: - Platform Filter Chip

struct PlatformFilterChip: View {
    let platform: Platform
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: platform.icon)
                    .font(.caption)
                
                Text(platform.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : platform.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? platform.color : platform.color.opacity(0.1),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(platform.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stream Discovery Card

struct StreamDiscoveryCard: View {
    let stream: DiscoveredStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: stream.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(stream.platform.color.opacity(0.3))
                    .overlay(
                        Image(systemName: stream.platform.systemImage)
                            .font(.title)
                            .foregroundColor(stream.platform.color.opacity(0.6))
                    )
            }
            .frame(height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                platformBadge
            }
            .overlay(alignment: .bottomTrailing) {
                if stream.isLive {
                    liveBadge
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(stream.channelName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    if let category = stream.category {
                        Text(category)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    if stream.viewerCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                            Text("\(stream.viewerCount.formatted())")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var platformBadge: some View {
        Image(systemName: stream.platform.icon)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(4)
            .background(stream.platform.color, in: Circle())
            .padding(6)
    }
    
    private var liveBadge: some View {
        Text("LIVE")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.red, in: Capsule())
            .padding(6)
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: StreamCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Thumbnail or icon
                AsyncImage(url: URL(string: category.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(category.platform.color.opacity(0.3))
                        .overlay(
                            Image(systemName: "grid.circle.fill")
                                .font(.title)
                                .foregroundColor(category.platform.color.opacity(0.6))
                        )
                }
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Info
                VStack(spacing: 4) {
                    Text(category.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("\(category.viewerCount.formatted()) viewers")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let platforms = category.platforms, platforms.count > 1 {
                            HStack(spacing: -4) {
                                ForEach(Array(platforms.prefix(3)), id: \.self) { platform in
                                    Image(systemName: platform.icon)
                                        .font(.caption2)
                                        .foregroundColor(platform.color)
                                        .padding(2)
                                        .background(.regularMaterial, in: Circle())
                                }
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Filters View

struct FiltersView: View {
    @Binding var selectedPlatforms: Set<Platform>
    @Binding var searchFilters: SearchFilters
    @Environment(\.dismiss) private var dismiss
    
    @State private var liveOnly = false
    @State private var minViewers = ""
    @State private var maxViewers = ""
    @State private var selectedLanguages: Set<String> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Platforms") {
                    ForEach(Platform.popularPlatforms, id: \.self) { platform in
                        HStack {
                            Image(systemName: platform.systemImage)
                                .foregroundColor(platform.color)
                            
                            Text(platform.displayName)
                            
                            Spacer()
                            
                            if selectedPlatforms.contains(platform) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedPlatforms.contains(platform) {
                                selectedPlatforms.remove(platform)
                            } else {
                                selectedPlatforms.insert(platform)
                            }
                        }
                    }
                }
                
                Section("Content") {
                    Toggle("Live streams only", isOn: $liveOnly)
                }
                
                Section("Viewer Count") {
                    HStack {
                        Text("Min")
                        TextField("Any", text: $minViewers)
                            .keyboardType(.numberPad)
                        
                        Text("Max")
                        TextField("Any", text: $maxViewers)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        applyFilters()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentFilters()
        }
    }
    
    private func loadCurrentFilters() {
        liveOnly = searchFilters.liveOnly
        minViewers = searchFilters.minViewers?.description ?? ""
        maxViewers = searchFilters.maxViewers?.description ?? ""
    }
    
    private func applyFilters() {
        searchFilters = SearchFilters(
            platforms: selectedPlatforms,
            categories: searchFilters.categories,
            languages: selectedLanguages.isEmpty ? nil : selectedLanguages,
            liveOnly: liveOnly,
            minViewers: Int(minViewers),
            maxViewers: Int(maxViewers)
        )
    }
    
    private func resetFilters() {
        selectedPlatforms = Set(Platform.popularPlatforms)
        liveOnly = false
        minViewers = ""
        maxViewers = ""
        selectedLanguages = []
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview

#Preview {
    EnhancedDiscoverView()
}