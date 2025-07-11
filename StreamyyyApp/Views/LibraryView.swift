//
//  LibraryView.swift
//  StreamyyyApp
//
//  Comprehensive Library view with real functionality for favorites, history, collections, and layouts
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @StateObject private var appState = AppStateManager.shared
    
    @State private var selectedTab: LibraryTab = .favorites
    @State private var searchText = ""
    @State private var showingFilterMenu = false
    @State private var showingNewCollectionSheet = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingClearHistoryAlert = false
    
    private enum LibraryTab: String, CaseIterable {
        case favorites = "Favorites"
        case history = "History"
        case collections = "Collections"
        case layouts = "Layouts"
        case recents = "Recent"
        
        var icon: String {
            switch self {
            case .favorites: return "heart.fill"
            case .history: return "clock.fill"
            case .collections: return "folder.fill"
            case .layouts: return "rectangle.3.offgrid.fill"
            case .recents: return "timer"
            }
        }
        
        var color: Color {
            switch self {
            case .favorites: return .red
            case .history: return .blue
            case .collections: return .orange
            case .layouts: return .purple
            case .recents: return .green
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Tab selector
                    tabSelectorView
                    
                    // Search bar
                    searchBarView
                    
                    // Content
                    contentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewCollectionSheet) {
                NewCollectionSheet()
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportLibrarySheet()
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportLibrarySheet()
            }
            .alert("Clear Viewing History", isPresented: $showingClearHistoryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    Task {
                        await viewingHistoryService.clearAllHistory()
                    }
                }
            } message: {
                Text("This will permanently delete all viewing history. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Filter button
                Button(action: {
                    showingFilterMenu = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .sheet(isPresented: $showingFilterMenu) {
                    FilterMenuSheet(selectedTab: selectedTab)
                }
                
                // More actions menu
                Menu {
                    Button(action: {
                        showingNewCollectionSheet = true
                    }) {
                        Label("New Collection", systemImage: "folder.badge.plus")
                    }
                    
                    Button(action: {
                        showingExportSheet = true
                    }) {
                        Label("Export Library", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        showingImportSheet = true
                    }) {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                    
                    Divider()
                    
                    if selectedTab == .history {
                        Button(action: {
                            showingClearHistoryAlert = true
                        }) {
                            Label("Clear History", systemImage: "trash")
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await appState.refreshAllData()
                        }
                    }) {
                        Label("Sync Data", systemImage: "arrow.clockwise")
                    }
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var headerSubtitle: String {
        switch selectedTab {
        case .favorites:
            return "\(appState.favoritesService.favoritesCount) favorites"
        case .history:
            return "\(appState.historyService.viewingHistory.count) entries"
        case .collections:
            return "\(appState.collectionsService.totalCollections) collections"
        case .layouts:
            return "\(appState.streamManager.getSavedLayouts().count) layouts"
        case .recents:
            return "Recently added streams"
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = tab
                                searchText = "" // Clear search when switching tabs
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
                .onSubmit {
                    performSearch()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private var searchPlaceholder: String {
        switch selectedTab {
        case .favorites: return "Search favorites..."
        case .history: return "Search history..."
        case .collections: return "Search collections..."
        case .layouts: return "Search layouts..."
        case .recents: return "Search recent streams..."
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch selectedTab {
                case .favorites:
                    FavoritesContentView(searchText: searchText)
                        .environmentObject(appState.favoritesService)
                
                case .history:
                    HistoryContentView(searchText: searchText)
                        .environmentObject(appState.historyService)
                
                case .collections:
                    CollectionsContentView(searchText: searchText)
                        .environmentObject(appState.collectionsService)
                
                case .layouts:
                    LayoutsContentView(searchText: searchText, streamManager: appState.streamManager)
                
                case .recents:
                    RecentsContentView(searchText: searchText)
                        .environmentObject(appState.favoritesService)
                        .environmentObject(appState.historyService)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Extra space for tab bar
        }
    }
    
    // MARK: - Helper Methods
    private func performSearch() {
        // Search functionality is handled by individual content views
        // This could trigger additional search analytics or logging
    }
    
    private func syncAllData() async {
        await appState.refreshAllData()
    }
}

// MARK: - Tab Button
private struct TabButton: View {
    let tab: LibraryView.LibraryTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.subheadline)
                
                Text(tab.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? tab.color : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Favorites Content View
private struct FavoritesContentView: View {
    let searchText: String
    @EnvironmentObject var favoritesService: UserFavoritesService
    
    @State private var selectedPlatform: String = "All"
    @State private var sortOption: FavoriteSortOption = .dateAdded
    
    private let platforms = ["All", "Twitch", "YouTube", "Other"]
    
    var filteredFavorites: [FavoriteStream] {
        let favorites = favoritesService.favorites
        
        var filtered = favorites
        
        // Platform filter
        if selectedPlatform != "All" {
            filtered = filtered.filter { $0.platform.lowercased() == selectedPlatform.lowercased() }
        }
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { favorite in
                favorite.title.localizedCaseInsensitiveContains(searchText) ||
                favorite.streamerName.localizedCaseInsensitiveContains(searchText) ||
                favorite.gameName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        filtered.sort { lhs, rhs in
            switch sortOption {
            case .dateAdded:
                return lhs.addedAt > rhs.addedAt
            case .lastViewed:
                return (lhs.lastUpdated) > (rhs.lastUpdated)
            case .viewCount:
                return false // Not implemented in FavoriteStream
            case .rating:
                return false // Not implemented in FavoriteStream
            case .title:
                return lhs.title < rhs.title
            case .platform:
                return lhs.platform < rhs.platform
            case .custom:
                return false // Not implemented
            }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Filter bar
            HStack {
                Text("Platform:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(platforms, id: \.self) { platform in
                        Text(platform).tag(platform)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
            }
            
            // Favorites list
            if filteredFavorites.isEmpty {
                EmptyStateView(
                    icon: "heart",
                    title: searchText.isEmpty ? "No Favorites" : "No Results",
                    message: searchText.isEmpty ? "Add streams to your favorites to see them here" : "No favorites match your search"
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(filteredFavorites, id: \.id) { favorite in
                        FavoriteCard(favorite: favorite)
                    }
                }
            }
        }
    }
}

// MARK: - History Content View
private struct HistoryContentView: View {
    let searchText: String
    @EnvironmentObject var historyService: ViewingHistoryService
    
    @State private var filterOption: ViewingHistoryFilter = .all
    @State private var sortOption: ViewingHistorySortOption = .recentFirst
    
    var filteredHistory: [ViewingHistory] {
        var history = historyService.viewingHistory
        
        // Apply filter
        switch filterOption {
        case .all:
            break
        case .today:
            let startOfDay = Calendar.current.startOfDay(for: Date())
            history = history.filter { $0.viewedAt >= startOfDay }
        case .thisWeek:
            let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            history = history.filter { $0.viewedAt >= startOfWeek }
        case .thisMonth:
            let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
            history = history.filter { $0.viewedAt >= startOfMonth }
        case .completed:
            history = history.filter { $0.isCompleted }
        case .rated:
            history = history.filter { $0.rating != nil }
        case .longSessions:
            history = history.filter { $0.wasLongSession }
        case .live:
            history = history.filter { $0.wasLive }
        case .byPlatform:
            break // Would group by platform
        }
        
        // Search filter
        if !searchText.isEmpty {
            history = history.filter { entry in
                entry.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                entry.displayStreamer.localizedCaseInsensitiveContains(searchText) ||
                entry.category?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Sort
        history.sort { lhs, rhs in
            switch sortOption {
            case .recentFirst:
                return lhs.viewedAt > rhs.viewedAt
            case .oldestFirst:
                return lhs.viewedAt < rhs.viewedAt
            case .longestDuration:
                return lhs.viewDuration > rhs.viewDuration
            case .shortestDuration:
                return lhs.viewDuration < rhs.viewDuration
            case .highestRated:
                return (lhs.rating ?? 0) > (rhs.rating ?? 0)
            case .mostCompleted:
                return lhs.watchPercentage > rhs.watchPercentage
            case .byPlatform:
                return lhs.platform.displayName < rhs.platform.displayName
            case .byStreamer:
                return lhs.displayStreamer < rhs.displayStreamer
            }
        }
        
        return history
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ViewingHistoryFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            title: filter.displayName,
                            icon: filter.icon,
                            isSelected: filterOption == filter,
                            action: {
                                filterOption = filter
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Statistics
            if !filteredHistory.isEmpty {
                HistoryStatsView()
                    .environmentObject(historyService)
            }
            
            // History list
            if filteredHistory.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: searchText.isEmpty ? "No History" : "No Results",
                    message: searchText.isEmpty ? "Your viewing history will appear here" : "No history entries match your search"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredHistory, id: \.id) { history in
                        HistoryCard(history: history)
                    }
                }
            }
        }
    }
}

// MARK: - Collections Content View
private struct CollectionsContentView: View {
    let searchText: String
    @EnvironmentObject var collectionsService: StreamCollectionsService
    
    @State private var sortOption: CollectionSortOption = .dateUpdated
    @State private var showPrivateOnly = false
    
    var filteredCollections: [StreamCollection] {
        var collections = collectionsService.collections
        
        // Privacy filter
        if showPrivateOnly {
            collections = collections.filter { $0.isPrivate }
        }
        
        // Search filter
        if !searchText.isEmpty {
            collections = collections.filter { collection in
                collection.name.localizedCaseInsensitiveContains(searchText) ||
                collection.description?.localizedCaseInsensitiveContains(searchText) == true ||
                collection.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        collections.sort { lhs, rhs in
            switch sortOption {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .dateCreated:
                return lhs.createdAt > rhs.createdAt
            case .dateUpdated:
                return lhs.updatedAt > rhs.updatedAt
            case .lastAccessed:
                return (lhs.lastAccessedAt ?? Date.distantPast) > (rhs.lastAccessedAt ?? Date.distantPast)
            case .streamCount:
                return lhs.totalStreams > rhs.totalStreams
            case .duration:
                return lhs.totalDuration > rhs.totalDuration
            case .rating:
                return lhs.rating > rhs.rating
            case .accessCount:
                return lhs.accessCount > rhs.accessCount
            }
        }
        
        return collections
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Controls
            HStack {
                Toggle("Private Only", isOn: $showPrivateOnly)
                    .foregroundColor(.white)
                
                Spacer()
                
                Menu {
                    ForEach(CollectionSortOption.allCases, id: \.self) { option in
                        Button(option.displayName) {
                            sortOption = option
                        }
                    }
                } label: {
                    HStack {
                        Text("Sort")
                        Image(systemName: "chevron.down")
                    }
                    .foregroundColor(.cyan)
                    .font(.subheadline)
                }
            }
            
            // Collections list
            if filteredCollections.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: searchText.isEmpty ? "No Collections" : "No Results",
                    message: searchText.isEmpty ? "Create collections to organize your streams" : "No collections match your search"
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(filteredCollections, id: \.id) { collection in
                        CollectionCard(collection: collection)
                    }
                }
            }
        }
    }
}

// MARK: - Layouts Content View
private struct LayoutsContentView: View {
    let searchText: String
    let streamManager: MultiStreamManager
    
    @State private var showFavoritesOnly = false
    @State private var selectedType: LayoutType?
    
    var filteredLayouts: [SavedLayout] {
        var layouts = streamManager.getSavedLayouts()
        
        // Search filter
        if !searchText.isEmpty {
            layouts = layouts.filter { layout in
                layout.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return layouts
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Controls
            HStack {
                Toggle("Favorites Only", isOn: $showFavoritesOnly)
                    .foregroundColor(.white)
                
                Spacer()
                
                Menu {
                    Button("All Layouts") {
                        selectedType = nil
                    }
                } label: {
                    HStack {
                        Text("All Layouts")
                        Image(systemName: "chevron.down")
                    }
                    .foregroundColor(.cyan)
                    .font(.subheadline)
                }
            }
            
            // Recent layouts - simplified
            if !filteredLayouts.isEmpty && searchText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Layouts")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(filteredLayouts.prefix(5), id: \.id) { layout in
                                CompactSavedLayoutCard(layout: layout)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            
            // All layouts
            if filteredLayouts.isEmpty {
                EmptyStateView(
                    icon: "rectangle.3.offgrid",
                    title: searchText.isEmpty ? "No Layouts" : "No Results",
                    message: searchText.isEmpty ? "Your saved layouts will appear here" : "No layouts match your search"
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(filteredLayouts, id: \.id) { layout in
                        SavedLayoutCard(layout: layout)
                    }
                }
            }
        }
    }
}

// MARK: - Recents Content View
private struct RecentsContentView: View {
    let searchText: String
    @EnvironmentObject var favoritesService: UserFavoritesService
    @EnvironmentObject var historyService: ViewingHistoryService
    
    var recentItems: [(id: String, type: String, title: String, subtitle: String, date: Date, icon: String, color: Color)] {
        var items: [(id: String, type: String, title: String, subtitle: String, date: Date, icon: String, color: Color)] = []
        
        // Recent favorites
        for favorite in favoritesService.favorites.prefix(5) {
            items.append((
                favorite.id,
                "Favorite",
                favorite.title,
                favorite.streamerName,
                favorite.addedAt,
                "heart.fill",
                .red
            ))
        }
        
        // Recent history
        for history in historyService.viewingHistory.prefix(10) {
            items.append((
                history.id,
                "Viewed",
                history.displayTitle,
                history.displayStreamer,
                history.viewedAt,
                "clock.fill",
                .blue
            ))
        }
        
        // Sort by date
        items.sort { $0.date > $1.date }
        
        // Filter by search
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.subtitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return Array(items.prefix(20))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if recentItems.isEmpty {
                EmptyStateView(
                    icon: "timer",
                    title: searchText.isEmpty ? "No Recent Activity" : "No Results",
                    message: searchText.isEmpty ? "Your recent activity will appear here" : "No recent items match your search"
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentItems, id: \.id) { item in
                        RecentItemCard(
                            type: item.type,
                            title: item.title,
                            subtitle: item.subtitle,
                            date: item.date,
                            icon: item.icon,
                            color: item.color
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.cyan : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Card Views (Placeholder implementations)
private struct FavoriteCard: View {
    let favorite: FavoriteStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .padding(8),
                    alignment: .topTrailing
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(favorite.streamerName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(favorite.platform)
                    .font(.caption2)
                    .foregroundColor(.cyan)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct HistoryCard: View {
    let history: ViewingHistory
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: history.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fit)
            }
            .frame(width: 80, height: 45)
            .clipped()
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(history.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(history.displayStreamer)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack {
                    Text(history.relativeTime)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    Text(history.displayDuration)
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct CollectionCard: View {
    let collection: StreamCollection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: collection.icon)
                    .font(.title2)
                    .foregroundColor(collection.colorValue)
                
                Spacer()
                
                if collection.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text("\(collection.totalStreams) streams")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(collection.timeSinceUpdated)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct LayoutCard: View {
    let layout: Layout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: layout.typeIcon)
                    .font(.title2)
                    .foregroundColor(layout.typeColor)
                
                Spacer()
                
                if layout.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(layout.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(layout.type.displayName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                if layout.useCount > 0 {
                    Text("Used \(layout.useCount) times")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct CompactSavedLayoutCard: View {
    let layout: SavedLayout
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: layout.layout.icon)
                .font(.title2)
                .foregroundColor(.purple)
            
            Text(layout.name)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 80, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct SavedLayoutCard: View {
    let layout: SavedLayout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: layout.layout.icon)
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Text("\(layout.streams.count) streams")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(layout.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(layout.layout.displayName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Created \(layout.createdAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct RecentItemCard: View {
    let type: String
    let title: String
    let subtitle: String
    let date: Date
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(type)
                        .font(.caption2)
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct HistoryStatsView: View {
    @EnvironmentObject var historyService: ViewingHistoryService
    
    var body: some View {
        HStack(spacing: 16) {
            StatItem(
                title: "Total Watch Time",
                value: formatDuration(historyService.totalWatchTime),
                icon: "clock"
            )
            
            StatItem(
                title: "This Week",
                value: formatDuration(historyService.weeklyWatchTime),
                icon: "calendar"
            )
            
            StatItem(
                title: "Completion Rate",
                value: String(format: "%.1f%%", historyService.completionRate),
                icon: "checkmark.circle"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

private struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.cyan)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sheet Views (Placeholder implementations)
private struct NewCollectionSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("New Collection")
                .navigationTitle("Create Collection")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct FilterMenuSheet: View {
    let selectedTab: LibraryView.LibraryTab
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Filter \(selectedTab.rawValue)")
                .navigationTitle("Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct ExportLibrarySheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Export Library")
                .navigationTitle("Export")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct ImportLibrarySheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Import Library")
                .navigationTitle("Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}