//
//  DiscoverView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Enhanced with modern design system components and improved UX
//

import SwiftUI

struct DiscoverView: View {
    @StateObject private var appState = AppStateManager.shared
    @StateObject private var discoveryService = StreamDiscoveryService()
    @State private var searchText = ""
    @State private var selectedCategory: StreamCategory = .all
    @State private var showingStreamAddedPopup = false
    @State private var addedStreamTitle = ""
    @State private var viewMode: ViewMode = .grid
    @State private var searchFilters = SearchFilters()
    @State private var showingFilters = false
    @State private var lastSearchQuery = ""
    @State private var searchTask: Task<Void, Never>?
    
    private let columns = [
        GridItem(.flexible(), spacing: StreamyyySpacing.streamGridSpacing),
        GridItem(.flexible(), spacing: StreamyyySpacing.streamGridSpacing)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                StreamyyyColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: StreamyyySpacing.sectionSpacing) {
                        // Search Section
                        modernSearchSection
                        
                        // Category Filter
                        modernCategoryFilter
                        
                        // Featured Section
                        if !discoveryService.featuredStreams.isEmpty {
                            modernFeaturedSection
                        }
                        
                        // View Mode Toggle and Trending Section
                        VStack(spacing: StreamyyySpacing.md) {
                            trendingSectionHeader
                            modernTrendingSection
                        }
                        
                        // Popular Categories
                        modernCategoriesSection
                        
                        // Quick Add Section
                        modernQuickAddSection
                    }
                    .screenPadding()
                    .padding(.bottom, StreamyyySpacing.xxl) // Extra padding for tab bar
                }
                .refreshable {
                    await loadDiscoverContent()
                }
                
                // Loading overlay
                if discoveryService.isLoading {
                    loadingOverlay
                }
                
                // Error handling
                if let error = discoveryService.error {
                    errorOverlay(error)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingStreamAddedPopup) {
                StreamAddedPopup(
                    streamTitle: addedStreamTitle,
                    isPresented: $showingStreamAddedPopup
                )
            }
        }
        .onAppear {
            Task {
                await loadDiscoverContent()
            }
        }
    }
    
    // MARK: - Modern UI Sections
    
    private var modernSearchSection: some View {
        VStack(spacing: StreamyyySpacing.md) {
            StreamyyyCard(style: .default, shadowStyle: .default) {
                HStack(spacing: StreamyyySpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                        .foregroundColor(StreamyyyColors.textSecondary)
                    
                    TextField("Search streams, games, or creators", text: $searchText)
                        .font(StreamyyyTypography.bodyLarge)
                        .foregroundColor(StreamyyyColors.textPrimary)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { newValue in
                            // Debounced search
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                if !Task.isCancelled && !newValue.isEmpty {
                                    await performSearch()
                                }
                            }
                        }
                    
                    HStack(spacing: StreamyyySpacing.xs) {
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                discoveryService.searchResults = []
                                StreamyyyDesignSystem.hapticFeedback(.light)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                                    .foregroundColor(StreamyyyColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            showingFilters = true
                            StreamyyyDesignSystem.hapticFeedback(.light)
                        }) {
                            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                                .foregroundColor(hasActiveFilters ? StreamyyyColors.primary : StreamyyyColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Search Results Section
            if !discoveryService.searchResults.isEmpty {
                searchResultsSection
            }
        }
        .accessibilityLabel("Search streams and content")
        .accessibilityHint("Enter text to search for streams, games, or creators")
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(filters: $searchFilters) {
                if !searchText.isEmpty {
                    Task {
                        await performSearch()
                    }
                }
            }
        }
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: StreamyyySpacing.md) {
            HStack {
                Text("Search Results")
                    .titleMedium()
                    .foregroundColor(StreamyyyColors.textPrimary)
                
                Spacer()
                
                Text("\(discoveryService.searchResults.count) results")
                    .font(StreamyyyTypography.captionMedium)
                    .foregroundColor(StreamyyyColors.textSecondary)
            }
            
            LazyVStack(spacing: StreamyyySpacing.sm) {
                ForEach(Array(discoveryService.searchResults.enumerated()), id: \.element.id) { index, stream in
                    SearchResultCard(stream: stream, rank: index + 1) {
                        addDiscoveredStream(stream)
                    }
                }
            }
        }
    }
    
    private var modernCategoryFilter: some View {
        VStack(alignment: .leading, spacing: StreamyyySpacing.md) {
            HStack {
                Text("Categories")
                    .titleMedium()
                    .foregroundColor(StreamyyyColors.textPrimary)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StreamyyySpacing.sm) {
                    ForEach(StreamCategory.allCases, id: \.self) { category in
                        ModernCategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            StreamyyyDesignSystem.hapticSelection()
                        }
                    }
                }
                .padding(.horizontal, StreamyyySpacing.screenPadding)
            }
            .padding(.horizontal, -StreamyyySpacing.screenPadding)
        }
    }
    
    private var modernFeaturedSection: some View {
        VStack(alignment: .leading, spacing: StreamyyySpacing.md) {
            HStack {
                Text("Featured Streams")
                    .titleMedium()
                    .foregroundColor(StreamyyyColors.textPrimary)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await discoveryService.loadFeaturedContent()
                    }
                    StreamyyyDesignSystem.hapticFeedback(.light)
                }
                .font(StreamyyyTypography.labelMedium)
                .foregroundColor(StreamyyyColors.primary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StreamyyySpacing.md) {
                    ForEach(discoveryService.featuredStreams, id: \.id) { stream in
                        ModernDiscoveredStreamCard(stream: stream, style: .featured) {
                            addDiscoveredStream(stream)
                        }
                    }
                }
                .padding(.horizontal, StreamyyySpacing.screenPadding)
            }
            .padding(.horizontal, -StreamyyySpacing.screenPadding)
        }
    }
    
    private var trendingSectionHeader: some View {
        HStack {
            Text("Trending")
                .titleMedium()
                .foregroundColor(StreamyyyColors.textPrimary)
            
            Spacer()
            
            // View mode toggle
            HStack(spacing: StreamyyySpacing.xs) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button(action: {
                        viewMode = mode
                        StreamyyyDesignSystem.hapticSelection()
                    }) {
                        Image(systemName: mode.icon)
                            .font(.system(size: StreamyyySpacing.iconSizeSM, weight: .medium))
                            .foregroundColor(viewMode == mode ? StreamyyyColors.primary : StreamyyyColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, StreamyyySpacing.sm)
            .padding(.vertical, StreamyyySpacing.xs)
            .background(StreamyyyColors.surface)
            .cornerRadius(StreamyyySpacing.cornerRadiusSM)
        }
    }
    
    private var modernTrendingSection: some View {
        Group {
            if viewMode == .grid {
                LazyVGrid(columns: columns, spacing: StreamyyySpacing.md) {
                    ForEach(Array(filteredTrendingStreams.enumerated()), id: \.element.id) { index, stream in
                        ModernDiscoveredStreamCard(
                            stream: stream,
                            style: .trending(rank: index + 1),
                            viewMode: .grid
                        ) {
                            addDiscoveredStream(stream)
                        }
                    }
                }
            } else {
                LazyVStack(spacing: StreamyyySpacing.sm) {
                    ForEach(Array(filteredTrendingStreams.enumerated()), id: \.element.id) { index, stream in
                        ModernDiscoveredStreamCard(
                            stream: stream,
                            style: .trending(rank: index + 1),
                            viewMode: .list
                        ) {
                            addDiscoveredStream(stream)
                        }
                    }
                }
            }
        }
    }
    
    private var modernCategoriesSection: some View {
        VStack(alignment: .leading, spacing: StreamyyySpacing.md) {
            HStack {
                Text("Popular Categories")
                    .titleMedium()
                    .foregroundColor(StreamyyyColors.textPrimary)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await discoveryService.loadPopularCategories()
                    }
                    StreamyyyDesignSystem.hapticFeedback(.light)
                }
                .font(StreamyyyTypography.labelMedium)
                .foregroundColor(StreamyyyColors.primary)
            }
            
            LazyVGrid(columns: columns, spacing: StreamyyySpacing.md) {
                ForEach(discoveryService.popularCategories, id: \.name) { category in
                    ModernCategoryCard(
                        category: category
                    ) {
                        // Filter by category
                        selectedCategory = mapDiscoveryCategoryToStreamCategory(category)
                        StreamyyyDesignSystem.hapticFeedback(.light)
                    }
                }
            }
        }
    }
    
    private var modernQuickAddSection: some View {
        VStack(spacing: StreamyyySpacing.md) {
            HStack {
                Text("Quick Actions")
                    .titleMedium()
                    .foregroundColor(StreamyyyColors.textPrimary)
                
                Spacer()
            }
            
            StreamyyyCard(
                style: .default,
                shadowStyle: .default,
                isInteractive: true,
                onTap: {
                    // Handle add custom stream
                    StreamyyyDesignSystem.hapticFeedback(.medium)
                }
            ) {
                HStack(spacing: StreamyyySpacing.md) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: StreamyyySpacing.iconSizeLG, weight: .medium))
                        .foregroundColor(StreamyyyColors.primary)
                    
                    VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
                        Text("Add Custom Stream")
                            .font(StreamyyyTypography.titleSmall)
                            .foregroundColor(StreamyyyColors.textPrimary)
                        
                        Text("Enter any stream URL manually")
                            .font(StreamyyyTypography.bodySmall)
                            .foregroundColor(StreamyyyColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: StreamyyySpacing.iconSizeSM, weight: .medium))
                        .foregroundColor(StreamyyyColors.textTertiary)
                }
            }
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            StreamyyyColors.overlay
                .opacity(0.3)
                .ignoresSafeArea()
            
            StreamyyyCard(style: .glass, shadowStyle: .floating) {
                VStack(spacing: StreamyyySpacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: StreamyyyColors.primary))
                        .scaleEffect(1.2)
                    
                    Text("Loading streams...")
                        .font(StreamyyyTypography.bodyMedium)
                        .foregroundColor(StreamyyyColors.textPrimary)
                }
                .padding(StreamyyySpacing.lg)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTrendingStreams: [DiscoveredStream] {
        if selectedCategory == .all {
            return discoveryService.trendingStreams
        }
        return discoveryService.trendingStreams.filter { stream in
            guard let category = stream.category else { return false }
            return mapGameToCategory(category) == selectedCategory
        }
    }
    
    private var hasActiveFilters: Bool {
        return searchFilters.platforms != nil ||
               searchFilters.categories != nil ||
               searchFilters.languages != nil ||
               searchFilters.liveOnly ||
               searchFilters.minViewers != nil ||
               searchFilters.maxViewers != nil ||
               !searchFilters.includeNSFW
    }
    
    // MARK: - Actions
    
    private func addDiscoveredStream(_ discoveredStream: DiscoveredStream) {
        // Convert DiscoveredStream to the app's Stream model
        let stream = Stream(
            id: discoveredStream.id,
            url: discoveredStream.streamURL,
            platform: discoveredStream.platform,
            title: discoveredStream.title
        )
        
        // Set additional properties
        stream.streamerName = discoveredStream.channelName
        stream.viewerCount = discoveredStream.viewerCount
        stream.isLive = discoveredStream.isLive
        stream.thumbnailURL = discoveredStream.thumbnailURL
        stream.category = discoveredStream.category
        stream.language = discoveredStream.language
        stream.startedAt = discoveredStream.startedAt
        stream.tags = discoveredStream.tags
        stream.description = discoveredStream.description
        
        appState.addStreamFromDiscover(stream)
        addedStreamTitle = discoveredStream.title
        showingStreamAddedPopup = true
        StreamyyyDesignSystem.hapticNotification(.success)
    }
    
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            discoveryService.searchResults = []
            return
        }
        
        lastSearchQuery = searchText
        await discoveryService.search(query: searchText, filters: searchFilters)
    }
    
    private func loadDiscoverContent() async {
        async let featuredTask: Void = discoveryService.loadFeaturedContent()
        async let trendingTask: Void = discoveryService.loadTrendingContent()
        async let categoriesTask: Void = discoveryService.loadPopularCategories()
        
        // Wait for all tasks to complete
        _ = await (featuredTask, trendingTask, categoriesTask)
    }
    
    private func mapGameToCategory(_ gameName: String) -> StreamCategory {
        let lowerGame = gameName.lowercased()
        
        if lowerGame.contains("chatting") || lowerGame.contains("talk") {
            return .chatting
        } else if lowerGame.contains("music") || lowerGame.contains("sing") {
            return .music
        } else if lowerGame.contains("art") || lowerGame.contains("draw") || lowerGame.contains("creative") {
            return .art
        } else if lowerGame.contains("sport") || lowerGame.contains("football") || lowerGame.contains("basketball") {
            return .sports
        } else if lowerGame.contains("tech") || lowerGame.contains("programming") || lowerGame.contains("coding") {
            return .tech
        } else {
            return .gaming // Default to gaming for most content
        }
    }
    
    private func mapDiscoveryCategoryToStreamCategory(_ discoveryCategory: StreamCategory) -> StreamCategory {
        let name = discoveryCategory.displayName.lowercased()
        
        if name.contains("gaming") || name.contains("game") {
            return .gaming
        } else if name.contains("music") {
            return .music
        } else if name.contains("tech") || name.contains("science") {
            return .tech
        } else if name.contains("sport") {
            return .sports
        } else if name.contains("art") || name.contains("creative") {
            return .art
        } else if name.contains("chat") || name.contains("talk") {
            return .chatting
        } else {
            return .all
        }
    }
    
    private func errorOverlay(_ error: StreamDiscoveryError) -> some View {
        ZStack {
            StreamyyyColors.overlay
                .opacity(0.3)
                .ignoresSafeArea()
            
            StreamyyyCard(style: .default, shadowStyle: .floating) {
                VStack(spacing: StreamyyySpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: StreamyyySpacing.iconSizeLG, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Text("Error Loading Content")
                        .font(StreamyyyTypography.titleMedium)
                        .foregroundColor(StreamyyyColors.textPrimary)
                    
                    Text(error.localizedDescription)
                        .font(StreamyyyTypography.bodyMedium)
                        .foregroundColor(StreamyyyColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        Task {
                            await loadDiscoverContent()
                        }
                    }
                    .buttonStyle(StreamyyyButton.Style.primary.small)
                }
                .padding(StreamyyySpacing.lg)
            }
        }
    }
}

// MARK: - Modern Components

// MARK: - View Mode
enum ViewMode: String, CaseIterable {
    case grid = "grid"
    case list = "list"
    
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Modern Discovered Stream Card
struct ModernDiscoveredStreamCard: View {
    let stream: DiscoveredStream
    let style: CardStyle
    var viewMode: ViewMode = .grid
    let action: () -> Void
    @State private var isPressed = false
    
    enum CardStyle {
        case featured
        case trending(rank: Int)
        case search
    }
    
    var body: some View {
        StreamyyyCard(
            style: .default,
            shadowStyle: .default,
            isInteractive: true,
            onTap: {
                StreamyyyDesignSystem.hapticFeedback(.medium)
                action()
            }
        ) {
            if viewMode == .grid {
                gridLayout
            } else {
                listLayout
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: StreamyyySpacing.sm) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: StreamyyySpacing.streamThumbnailCornerRadius)
                    .fill(StreamyyyColors.surfaceSecondary)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        LinearGradient(
                            colors: [Color.clear, StreamyyyColors.overlay.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(StreamyyySpacing.streamThumbnailCornerRadius)
                    )
                
                VStack(spacing: StreamyyySpacing.sm) {
                    if case .trending(let rank) = style {
                        Text("#\(rank)")
                            .font(StreamyyyTypography.labelLarge)
                            .fontWeight(.bold)
                            .foregroundColor(StreamyyyColors.textInverse)
                            .padding(.horizontal, StreamyyySpacing.sm)
                            .padding(.vertical, StreamyyySpacing.xs)
                            .background(StreamyyyColors.primary)
                            .cornerRadius(StreamyyySpacing.cornerRadiusXS)
                    }
                    
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: StreamyyySpacing.iconSizeLG, weight: .medium))
                        .foregroundColor(StreamyyyColors.textInverse.opacity(0.8))
                    
                    if stream.isLive {
                        HStack(spacing: StreamyyySpacing.xs) {
                            Circle()
                                .fill(StreamyyyColors.liveIndicator)
                                .frame(width: 6, height: 6)
                            
                            Text("LIVE")
                                .font(StreamyyyTypography.liveIndicator)
                                .foregroundColor(StreamyyyColors.textInverse)
                        }
                        .padding(.horizontal, StreamyyySpacing.sm)
                        .padding(.vertical, StreamyyySpacing.xs)
                        .background(StreamyyyColors.overlay.opacity(0.8))
                        .cornerRadius(StreamyyySpacing.cornerRadiusXS)
                    }
                }
                
                // Viewer count overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatViewerCount(stream.viewerCount))
                            .font(StreamyyyTypography.viewerCount)
                            .foregroundColor(StreamyyyColors.textInverse)
                            .padding(.horizontal, StreamyyySpacing.sm)
                            .padding(.vertical, StreamyyySpacing.xs)
                            .background(StreamyyyColors.overlay.opacity(0.8))
                            .cornerRadius(StreamyyySpacing.cornerRadiusXS)
                    }
                }
                .padding(StreamyyySpacing.sm)
            }
            
            // Stream info
            VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
                Text(stream.title)
                    .font(StreamyyyTypography.streamTitle)
                    .foregroundColor(StreamyyyColors.textPrimary)
                    .lineLimit(1)
                
                Text(stream.channelName)
                    .font(StreamyyyTypography.gameTitle)
                    .foregroundColor(StreamyyyColors.textSecondary)
                    .lineLimit(1)
                
                if let category = stream.category {
                    Text(category)
                        .font(StreamyyyTypography.captionMedium)
                        .foregroundColor(StreamyyyColors.textTertiary)
                        .lineLimit(1)
                }
                
                HStack(spacing: StreamyyySpacing.xs) {
                    Circle()
                        .fill(stream.platform.color)
                        .frame(width: 8, height: 8)
                    
                    Text(stream.platform.displayName)
                        .font(StreamyyyTypography.platformBadge)
                        .foregroundColor(StreamyyyColors.textTertiary)
                    
                    Spacer()
                    
                    StreamyyyIconButton(
                        icon: "plus.circle.fill",
                        style: .ghost,
                        size: .small
                    ) {
                        action()
                    }
                }
            }
        }
    }
    
    private var listLayout: some View {
        HStack(spacing: StreamyyySpacing.md) {
            // Rank or platform icon
            Group {
                if case .trending(let rank) = style {
                    Text("#\(rank)")
                        .font(StreamyyyTypography.titleSmall)
                        .fontWeight(.bold)
                        .foregroundColor(StreamyyyColors.primary)
                        .frame(width: 32)
                } else {
                    Image(systemName: stream.platform.icon)
                        .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                        .foregroundColor(stream.platform.color)
                        .frame(width: 32)
                }
            }
            
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: StreamyyySpacing.streamThumbnailCornerRadius)
                    .fill(StreamyyyColors.surfaceSecondary)
                    .frame(width: 80, height: 45) // 16:9 aspect ratio
                
                Image(systemName: "play.tv.fill")
                    .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                    .foregroundColor(StreamyyyColors.textInverse.opacity(0.8))
                
                if stream.isLive {
                    VStack {
                        HStack {
                            Circle()
                                .fill(StreamyyyColors.liveIndicator)
                                .frame(width: 4, height: 4)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
            
            // Stream info
            VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
                Text(stream.title)
                    .font(StreamyyyTypography.streamTitle)
                    .foregroundColor(StreamyyyColors.textPrimary)
                    .lineLimit(1)
                
                Text(stream.channelName)
                    .font(StreamyyyTypography.gameTitle)
                    .foregroundColor(StreamyyyColors.textSecondary)
                    .lineLimit(1)
                
                if let category = stream.category {
                    Text(category)
                        .font(StreamyyyTypography.captionMedium)
                        .foregroundColor(StreamyyyColors.textTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Viewers and add button
            VStack(alignment: .trailing, spacing: StreamyyySpacing.xs) {
                Text(formatViewerCount(stream.viewerCount))
                    .font(StreamyyyTypography.viewerCount)
                    .foregroundColor(StreamyyyColors.textSecondary)
                
                StreamyyyIconButton(
                    icon: "plus.circle.fill",
                    style: .ghost,
                    size: .small
                ) {
                    action()
                }
            }
        }
    }
    
    private func formatViewerCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let stream: DiscoveredStream
    let rank: Int
    let action: () -> Void
    
    var body: some View {
        ModernDiscoveredStreamCard(
            stream: stream,
            style: .search,
            viewMode: .list,
            action: action
        )
    }
}

// MARK: - Modern Category Card
struct ModernCategoryCard: View {
    let category: StreamCategory
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            StreamyyyDesignSystem.hapticFeedback(.medium)
            action()
        }) {
            StreamyyyCard(style: .default, shadowStyle: .default) {
                VStack(spacing: StreamyyySpacing.md) {
                    // Icon with background
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: StreamyyySpacing.iconSizeLG, weight: .medium))
                            .foregroundColor(category.color)
                    }
                    
                    VStack(spacing: StreamyyySpacing.xs) {
                        Text(category.displayName)
                            .font(StreamyyyTypography.titleSmall)
                            .foregroundColor(StreamyyyColors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel("\(category.displayName) category")
        .accessibilityHint("Tap to browse this category.")
    }
}

// MARK: - Search Filters View
struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Platforms") {
                    ForEach(Platform.popularPlatforms, id: \.self) { platform in
                        HStack {
                            Image(systemName: platform.icon)
                                .foregroundColor(platform.color)
                                .frame(width: 24)
                            
                            Text(platform.displayName)
                            
                            Spacer()
                            
                            if filters.platforms?.contains(platform) == true {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            togglePlatform(platform)
                        }
                    }
                }
                
                Section("Content") {
                    Toggle("Live streams only", isOn: $filters.liveOnly)
                    Toggle("Include mature content", isOn: $filters.includeNSFW)
                }
                
                Section("Viewer Count") {
                    HStack {
                        Text("Minimum:")
                        Spacer()
                        TextField("0", value: $filters.minViewers, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Maximum:")
                        Spacer()
                        TextField("No limit", value: $filters.maxViewers, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
                
                Section("Sort By") {
                    Picker("Sort Option", selection: $filters.sortBy) {
                        ForEach(SearchFilters.SortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func togglePlatform(_ platform: Platform) {
        if filters.platforms == nil {
            filters.platforms = Set([platform])
        } else if filters.platforms!.contains(platform) {
            filters.platforms!.remove(platform)
            if filters.platforms!.isEmpty {
                filters.platforms = nil
            }
        } else {
            filters.platforms!.insert(platform)
        }
    }
}

// MARK: - Modern Category Chip
struct ModernCategoryChip: View {
    let category: StreamCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: StreamyyySpacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: StreamyyySpacing.iconSizeXS, weight: .medium))
                
                Text(category.displayName)
                    .font(StreamyyyTypography.labelMedium)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, StreamyyySpacing.md)
            .padding(.vertical, StreamyyySpacing.sm)
            .background(isSelected ? StreamyyyColors.primary : StreamyyyColors.surface)
            .foregroundColor(isSelected ? StreamyyyColors.textInverse : StreamyyyColors.textPrimary)
            .cornerRadius(StreamyyySpacing.cornerRadiusLG)
            .overlay(
                RoundedRectangle(cornerRadius: StreamyyySpacing.cornerRadiusLG)
                    .stroke(isSelected ? Color.clear : StreamyyyColors.border, lineWidth: StreamyyySpacing.borderWidthThin)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityLabel("\(category.displayName) category")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to filter by this category")
    }
}

// MARK: - Legacy Models (for compatibility)
enum StreamCategory: String, CaseIterable {
    case all = "All"
    case gaming = "Gaming"
    case music = "Music"
    case tech = "Tech"
    case art = "Art"
    case sports = "Sports"
    case chatting = "Chatting"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .gaming: return "gamecontroller"
        case .music: return "music.note"
        case .tech: return "laptopcomputer"
        case .art: return "paintbrush"
        case .sports: return "sportscourt"
        case .chatting: return "bubble.left.and.bubble.right"
        }
    }
}

#Preview {
    DiscoverView()
        .environmentObject(StreamManager())
}