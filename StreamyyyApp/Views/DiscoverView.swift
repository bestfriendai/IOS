//
//  DiscoverView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Enhanced with modern design system components and improved UX
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var streamManager: StreamManager
    @State private var searchText = ""
    @State private var selectedCategory: StreamCategory = .all
    @State private var featuredStreams: [FeaturedStream] = []
    @State private var trendingStreams: [TrendingStream] = []
    @State private var isLoading = false
    @State private var showingStreamAddedPopup = false
    @State private var addedStreamTitle = ""
    @State private var viewMode: ViewMode = .grid
    
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
                        if !featuredStreams.isEmpty {
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
                if isLoading {
                    loadingOverlay
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
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = "" 
                        StreamyyyDesignSystem.hapticFeedback(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                            .foregroundColor(StreamyyyColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityLabel("Search streams and content")
        .accessibilityHint("Enter text to search for streams, games, or creators")
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
                Text("Featured")
                    .titleMedium()
                    .foregroundColor(StreamyyyColors.textPrimary)
                
                Spacer()
                
                Button("See All") {
                    // Handle see all action
                    StreamyyyDesignSystem.hapticFeedback(.light)
                }
                .font(StreamyyyTypography.labelMedium)
                .foregroundColor(StreamyyyColors.primary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StreamyyySpacing.md) {
                    ForEach(featuredStreams, id: \.id) { stream in
                        ModernFeaturedStreamCard(stream: stream) {
                            addStream(stream.url, title: stream.title)
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
                        ModernTrendingStreamCard(
                            stream: stream,
                            rank: index + 1,
                            viewMode: .grid
                        ) {
                            addStream(stream.url, title: stream.title)
                        }
                    }
                }
            } else {
                LazyVStack(spacing: StreamyyySpacing.sm) {
                    ForEach(Array(filteredTrendingStreams.enumerated()), id: \.element.id) { index, stream in
                        ModernTrendingStreamCard(
                            stream: stream,
                            rank: index + 1,
                            viewMode: .list
                        ) {
                            addStream(stream.url, title: stream.title)
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
            }
            
            LazyVGrid(columns: columns, spacing: StreamyyySpacing.md) {
                ForEach(popularCategories, id: \.name) { category in
                    ModernCategoryCard(
                        name: category.name,
                        icon: category.icon,
                        color: category.color,
                        streamCount: category.streamCount
                    ) {
                        // Handle category selection
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
    
    private var filteredTrendingStreams: [TrendingStream] {
        if selectedCategory == .all {
            return trendingStreams
        }
        return trendingStreams.filter { $0.category == selectedCategory }
    }
    
    private var popularCategories: [PopularCategory] {
        return [
            PopularCategory(name: "Gaming", icon: "gamecontroller.fill", color: StreamyyyColors.primary, streamCount: 1234),
            PopularCategory(name: "Just Chatting", icon: "bubble.left.and.bubble.right.fill", color: StreamyyyColors.secondary, streamCount: 856),
            PopularCategory(name: "Music", icon: "music.note", color: .orange, streamCount: 492),
            PopularCategory(name: "Art", icon: "paintbrush.fill", color: .purple, streamCount: 234),
            PopularCategory(name: "Tech", icon: "laptopcomputer", color: .blue, streamCount: 156),
            PopularCategory(name: "Sports", icon: "sportscourt.fill", color: .green, streamCount: 89)
        ]
    }
    
    // MARK: - Actions
    
    private func addStream(_ url: String, title: String) {
        streamManager.addStream(url: url)
        addedStreamTitle = title
        showingStreamAddedPopup = true
        StreamyyyDesignSystem.hapticNotification(.success)
    }
    
    private func loadDiscoverContent() async {
        isLoading = true
        
        // Simulate API calls
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        featuredStreams = [
            FeaturedStream(
                id: "1",
                title: "shroud",
                game: "VALORANT",
                viewers: 45000,
                thumbnailURL: "https://example.com/thumb1.jpg",
                platform: Platform.twitch,
                url: "https://twitch.tv/shroud"
            ),
            FeaturedStream(
                id: "2",
                title: "pokimane",
                game: "Just Chatting",
                viewers: 32000,
                thumbnailURL: "https://example.com/thumb2.jpg",
                platform: Platform.twitch,
                url: "https://twitch.tv/pokimane"
            ),
            FeaturedStream(
                id: "3",
                title: "TheGrefg",
                game: "Fortnite",
                viewers: 28000,
                thumbnailURL: "https://example.com/thumb3.jpg",
                platform: Platform.twitch,
                url: "https://twitch.tv/thegrefg"
            )
        ]
        
        trendingStreams = [
            TrendingStream(
                id: "1",
                title: "xQc",
                game: "Grand Theft Auto V",
                viewers: 78000,
                category: .gaming,
                platform: Platform.twitch,
                url: "https://twitch.tv/xqc"
            ),
            TrendingStream(
                id: "2",
                title: "MKBHD",
                game: "Tech Review",
                viewers: 15000,
                category: .tech,
                platform: Platform.youtube,
                url: "https://youtube.com/@mkbhd"
            ),
            TrendingStream(
                id: "3",
                title: "Ninja",
                game: "Fortnite",
                viewers: 25000,
                category: .gaming,
                platform: Platform.twitch,
                url: "https://twitch.tv/ninja"
            ),
            TrendingStream(
                id: "4",
                title: "Gaules",
                game: "Counter-Strike 2",
                viewers: 42000,
                category: .gaming,
                platform: Platform.twitch,
                url: "https://twitch.tv/gaules"
            ),
            TrendingStream(
                id: "5",
                title: "HasanAbi",
                game: "Just Chatting",
                viewers: 31000,
                category: .chatting,
                platform: Platform.twitch,
                url: "https://twitch.tv/hasanabi"
            ),
            TrendingStream(
                id: "6",
                title: "ibai",
                game: "Music",
                viewers: 19000,
                category: .music,
                platform: Platform.twitch,
                url: "https://twitch.tv/ibai"
            )
        ]
        
        isLoading = false
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

// MARK: - Popular Category Model
struct PopularCategory {
    let name: String
    let icon: String
    let color: Color
    let streamCount: Int
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

// MARK: - Modern Featured Stream Card
struct ModernFeaturedStreamCard: View {
    let stream: FeaturedStream
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            StreamyyyDesignSystem.hapticFeedback(.medium)
            action()
        }) {
            VStack(alignment: .leading, spacing: StreamyyySpacing.sm) {
                // Thumbnail with overlay
                ZStack {
                    RoundedRectangle(cornerRadius: StreamyyySpacing.streamThumbnailCornerRadius)
                        .fill(StreamyyyColors.surfaceSecondary)
                        .frame(width: 280, height: 157) // 16:9 aspect ratio
                        .overlay(
                            // Gradient overlay for better text readability
                            LinearGradient(
                                colors: [Color.clear, StreamyyyColors.overlay.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .cornerRadius(StreamyyySpacing.streamThumbnailCornerRadius)
                        )
                    
                    // Placeholder content
                    VStack(spacing: StreamyyySpacing.sm) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: StreamyyySpacing.iconSizeXL, weight: .medium))
                            .foregroundColor(StreamyyyColors.textInverse.opacity(0.8))
                        
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
                    
                    // Viewer count overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Text(formatViewerCount(stream.viewers))
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
                    
                    Text(stream.game)
                        .font(StreamyyyTypography.gameTitle)
                        .foregroundColor(StreamyyyColors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: StreamyyySpacing.xs) {
                        Circle()
                            .fill(stream.platform.color)
                            .frame(width: 10, height: 10)
                        
                        Text(stream.platform.displayName)
                            .font(StreamyyyTypography.platformBadge)
                            .foregroundColor(StreamyyyColors.textTertiary)
                    }
                }
                .frame(width: 280, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel("Featured stream: \(stream.title)")
        .accessibilityHint("Streaming \(stream.game) with \(formatViewerCount(stream.viewers)) viewers. Tap to add to your multistream.")
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

// MARK: - Modern Trending Stream Card
struct ModernTrendingStreamCard: View {
    let stream: TrendingStream
    let rank: Int
    let viewMode: ViewMode
    let action: () -> Void
    @State private var isPressed = false
    
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
        .accessibilityLabel("Trending stream #\(rank): \(stream.title)")
        .accessibilityHint("Streaming \(stream.game) with \(formatViewerCount(stream.viewers)) viewers. Tap to add to your multistream.")
    }
    
    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: StreamyyySpacing.sm) {
            // Thumbnail placeholder
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
                    // Rank badge
                    Text("#\(rank)")
                        .font(StreamyyyTypography.labelLarge)
                        .fontWeight(.bold)
                        .foregroundColor(StreamyyyColors.textInverse)
                        .padding(.horizontal, StreamyyySpacing.sm)
                        .padding(.vertical, StreamyyySpacing.xs)
                        .background(StreamyyyColors.primary)
                        .cornerRadius(StreamyyySpacing.cornerRadiusXS)
                    
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: StreamyyySpacing.iconSizeLG, weight: .medium))
                        .foregroundColor(StreamyyyColors.textInverse.opacity(0.8))
                }
                
                // Viewer count overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatViewerCount(stream.viewers))
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
                
                Text(stream.game)
                    .font(StreamyyyTypography.gameTitle)
                    .foregroundColor(StreamyyyColors.textSecondary)
                    .lineLimit(1)
                
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
            // Rank
            Text("#\(rank)")
                .font(StreamyyyTypography.titleSmall)
                .fontWeight(.bold)
                .foregroundColor(StreamyyyColors.primary)
                .frame(width: 32)
            
            // Thumbnail placeholder
            ZStack {
                RoundedRectangle(cornerRadius: StreamyyySpacing.streamThumbnailCornerRadius)
                    .fill(StreamyyyColors.surfaceSecondary)
                    .frame(width: 80, height: 45) // 16:9 aspect ratio
                
                Image(systemName: "play.tv.fill")
                    .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                    .foregroundColor(StreamyyyColors.textInverse.opacity(0.8))
            }
            
            // Stream info
            VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
                Text(stream.title)
                    .font(StreamyyyTypography.streamTitle)
                    .foregroundColor(StreamyyyColors.textPrimary)
                    .lineLimit(1)
                
                Text(stream.game)
                    .font(StreamyyyTypography.gameTitle)
                    .foregroundColor(StreamyyyColors.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: StreamyyySpacing.xs) {
                    Circle()
                        .fill(stream.platform.color)
                        .frame(width: 8, height: 8)
                    
                    Text(stream.platform.displayName)
                        .font(StreamyyyTypography.platformBadge)
                        .foregroundColor(StreamyyyColors.textTertiary)
                }
            }
            
            Spacer()
            
            // Viewers and add button
            VStack(alignment: .trailing, spacing: StreamyyySpacing.xs) {
                Text(formatViewerCount(stream.viewers))
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

// MARK: - Modern Category Card
struct ModernCategoryCard: View {
    let name: String
    let icon: String
    let color: Color
    let streamCount: Int
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
                            .fill(color.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: icon)
                            .font(.system(size: StreamyyySpacing.iconSizeLG, weight: .medium))
                            .foregroundColor(color)
                    }
                    
                    VStack(spacing: StreamyyySpacing.xs) {
                        Text(name)
                            .font(StreamyyyTypography.titleSmall)
                            .foregroundColor(StreamyyyColors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("\(formatCount(streamCount)) streams")
                            .font(StreamyyyTypography.captionMedium)
                            .foregroundColor(StreamyyyColors.textSecondary)
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
        .accessibilityLabel("\(name) category")
        .accessibilityHint("\(streamCount) streams available. Tap to browse this category.")
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Models
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

struct FeaturedStream {
    let id: String
    let title: String
    let game: String
    let viewers: Int
    let thumbnailURL: String
    let platform: Platform
    let url: String
}

struct TrendingStream {
    let id: String
    let title: String
    let game: String
    let viewers: Int
    let category: StreamCategory
    let platform: Platform
    let url: String
}

#Preview {
    DiscoverView()
        .environmentObject(StreamManager())
}