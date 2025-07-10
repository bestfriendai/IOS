//
//  FavoritesView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var streamManager: StreamManager
    @State private var favoriteStreams: [FavoriteStream] = []
    @State private var searchText = ""
    @State private var selectedFilter: FavoriteFilter = .all
    @State private var showingAddFavorite = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if favoriteStreams.isEmpty && !isLoading {
                    EmptyFavoritesView(showingAddFavorite: $showingAddFavorite)
                } else {
                    VStack(spacing: 0) {
                        // Search and Filter
                        VStack(spacing: 16) {
                            SearchBar(text: $searchText)
                            FilterSegmentedControl(selectedFilter: $selectedFilter)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        
                        // Favorites List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredFavorites) { favorite in
                                    FavoriteStreamCard(favorite: favorite) {
                                        addToActiveStreams(favorite)
                                    } onRemove: {
                                        removeFavorite(favorite)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Favorite", action: { showingAddFavorite = true })
                        Button("Refresh Status", action: { Task { await refreshFavorites() } })
                        
                        if !favoriteStreams.isEmpty {
                            Divider()
                            Button("Add All to Streams", action: addAllToStreams)
                            Button("Clear All", role: .destructive, action: clearAllFavorites)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await refreshFavorites()
            }
            .sheet(isPresented: $showingAddFavorite) {
                AddFavoriteView { favorite in
                    favoriteStreams.append(favorite)
                }
            }
        }
        .onAppear {
            loadFavorites()
        }
    }
    
    private var filteredFavorites: [FavoriteStream] {
        var filtered = favoriteStreams
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.game.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .live:
            filtered = filtered.filter { $0.isLive }
        case .offline:
            filtered = filtered.filter { !$0.isLive }
        }
        
        return filtered
    }
    
    private func loadFavorites() {
        // Load from UserDefaults or Core Data
        favoriteStreams = [
            FavoriteStream(
                id: "1",
                title: "shroud",
                game: "VALORANT",
                platform: .twitch,
                url: "https://twitch.tv/shroud",
                isLive: true,
                viewers: 45000,
                lastSeen: Date().addingTimeInterval(-3600),
                thumbnailURL: "https://example.com/thumb1.jpg"
            ),
            FavoriteStream(
                id: "2",
                title: "pokimane",
                game: "Just Chatting",
                platform: .twitch,
                url: "https://twitch.tv/pokimane",
                isLive: false,
                viewers: 0,
                lastSeen: Date().addingTimeInterval(-7200),
                thumbnailURL: "https://example.com/thumb2.jpg"
            ),
            FavoriteStream(
                id: "3",
                title: "MKBHD",
                game: "Tech Review",
                platform: .youtube,
                url: "https://youtube.com/@mkbhd",
                isLive: true,
                viewers: 15000,
                lastSeen: Date(),
                thumbnailURL: "https://example.com/thumb3.jpg"
            )
        ]
    }
    
    private func refreshFavorites() async {
        isLoading = true
        
        // Simulate API calls to check live status
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Update live status for each favorite
        for i in favoriteStreams.indices {
            // Simulate random live status
            favoriteStreams[i].isLive = Bool.random()
            if favoriteStreams[i].isLive {
                favoriteStreams[i].viewers = Int.random(in: 100...50000)
            } else {
                favoriteStreams[i].viewers = 0
            }
        }
        
        isLoading = false
    }
    
    private func addToActiveStreams(_ favorite: FavoriteStream) {
        streamManager.addStream(url: favorite.url)
    }
    
    private func removeFavorite(_ favorite: FavoriteStream) {
        favoriteStreams.removeAll { $0.id == favorite.id }
    }
    
    private func addAllToStreams() {
        for favorite in favoriteStreams {
            streamManager.addStream(url: favorite.url)
        }
    }
    
    private func clearAllFavorites() {
        favoriteStreams.removeAll()
    }
}

// MARK: - Empty Favorites View
struct EmptyFavoritesView: View {
    @Binding var showingAddFavorite: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your favorite streamers to keep track of when they go live")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add Favorite") {
                showingAddFavorite = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

// MARK: - Filter Segmented Control
struct FilterSegmentedControl: View {
    @Binding var selectedFilter: FavoriteFilter
    
    var body: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(FavoriteFilter.allCases, id: \.self) { filter in
                Text(filter.displayName)
                    .tag(filter)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

// MARK: - Favorite Stream Card
struct FavoriteStreamCard: View {
    let favorite: FavoriteStream
    let onAdd: () -> Void
    let onRemove: () -> Void
    
    @State private var showingActionSheet = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 45)
                
                // Live indicator or offline overlay
                if favorite.isLive {
                    VStack {
                        HStack {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 4, height: 4)
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(4)
                } else {
                    Color.black.opacity(0.6)
                        .cornerRadius(8)
                    
                    Text("OFFLINE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            // Stream Info
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(favorite.game)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Platform badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(favorite.platform.color)
                            .frame(width: 8, height: 8)
                        Text(favorite.platform.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    if favorite.isLive {
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                        
                        Text("\(favorite.viewers) viewers")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                        
                        Text("Last seen \(timeAgoString(from: favorite.lastSeen))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 8) {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(favorite.isLive ? .purple : .gray)
                }
                .disabled(!favorite.isLive)
                
                Button(action: { showingActionSheet = true }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
        .confirmationDialog("Options", isPresented: $showingActionSheet) {
            Button("Add to Streams", action: onAdd)
            Button("Share", action: {})
            Button("Remove from Favorites", role: .destructive, action: onRemove)
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Add Favorite View
struct AddFavoriteView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (FavoriteStream) -> Void
    
    @State private var streamURL = ""
    @State private var customTitle = ""
    @State private var selectedPlatform: StreamType = .twitch
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)
                    
                    Text("Add to Favorites")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Keep track of your favorite streamers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Form
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stream URL")
                            .font(.headline)
                        
                        TextField("https://twitch.tv/username", text: $streamURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Title (Optional)")
                            .font(.headline)
                        
                        TextField("Custom display name", text: $customTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Platform")
                            .font(.headline)
                        
                        Picker("Platform", selection: $selectedPlatform) {
                            ForEach(StreamType.allCases, id: \.self) { platform in
                                HStack {
                                    Circle()
                                        .fill(platform.color)
                                        .frame(width: 12, height: 12)
                                    Text(platform.displayName)
                                }
                                .tag(platform)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Add Button
                Button(action: addFavorite) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Add to Favorites")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(streamURL.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(streamURL.isEmpty)
                .padding(.horizontal)
            }
            .navigationTitle("Add Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addFavorite() {
        guard !streamURL.isEmpty else { return }
        
        if isValidURL(streamURL) {
            let title = customTitle.isEmpty ? extractTitleFromURL(streamURL) : customTitle
            
            let favorite = FavoriteStream(
                id: UUID().uuidString,
                title: title,
                game: "Unknown",
                platform: selectedPlatform,
                url: streamURL,
                isLive: false,
                viewers: 0,
                lastSeen: Date(),
                thumbnailURL: ""
            )
            
            onAdd(favorite)
            dismiss()
        } else {
            errorMessage = "Please enter a valid stream URL"
            showingError = true
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    private func extractTitleFromURL(_ url: String) -> String {
        if url.contains("twitch.tv") {
            return url.components(separatedBy: "/").last ?? "Twitch Stream"
        } else if url.contains("youtube.com") {
            return "YouTube Stream"
        } else {
            return "Live Stream"
        }
    }
}

// MARK: - Models
enum FavoriteFilter: String, CaseIterable {
    case all = "All"
    case live = "Live"
    case offline = "Offline"
    
    var displayName: String {
        return rawValue
    }
}

struct FavoriteStream: Identifiable {
    let id: String
    let title: String
    let game: String
    let platform: StreamType
    let url: String
    var isLive: Bool
    var viewers: Int
    var lastSeen: Date
    let thumbnailURL: String
}

#Preview {
    FavoritesView()
        .environmentObject(StreamManager())
}