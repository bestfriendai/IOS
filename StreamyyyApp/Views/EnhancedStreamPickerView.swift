//
//  EnhancedStreamPickerView.swift
//  StreamyyyApp
//
//  Modern stream picker with advanced search and filtering
//

import SwiftUI

struct EnhancedStreamPickerView: View {
    let selectedSlotIndex: Int
    let onStreamSelected: (TwitchStream) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: StreamCategory = .all
    @State private var sortOption: SortOption = .viewers
    @State private var isLoading = false
    @State private var streams: [TwitchStream] = []
    
    enum StreamCategory: String, CaseIterable {
        case all = "All"
        case gaming = "Gaming"
        case justChatting = "Just Chatting"
        case music = "Music"
        case sports = "Sports"
        
        var icon: String {
            switch self {
            case .all: return "globe"
            case .gaming: return "gamecontroller"
            case .justChatting: return "bubble.left.and.bubble.right"
            case .music: return "music.note"
            case .sports: return "sportscourt"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case viewers = "Viewers"
        case recent = "Recent"
        case alphabetical = "A-Z"
        
        var icon: String {
            switch self {
            case .viewers: return "eye"
            case .recent: return "clock"
            case .alphabetical: return "textformat.abc"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search header
                    searchHeader
                    
                    // Filter controls
                    filterControls
                    
                    // Stream list
                    streamsList
                }
            }
            .navigationTitle("Add Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshStreams) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            loadMockStreams()
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search streams...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Quick actions
            HStack(spacing: 12) {
                quickActionButton(
                    title: "Popular",
                    icon: "flame",
                    action: { loadPopularStreams() }
                )
                
                quickActionButton(
                    title: "Live Now",
                    icon: "dot.radiowaves.left.and.right",
                    action: { loadLiveStreams() }
                )
                
                quickActionButton(
                    title: "Favorites",
                    icon: "heart",
                    action: { loadFavoriteStreams() }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
    
    // MARK: - Filter Controls
    private var filterControls: some View {
        VStack(spacing: 12) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StreamCategory.allCases, id: \.self) { category in
                        categoryFilterButton(category: category)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Sort options
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            Label(option.rawValue, systemImage: option.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sortOption.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
    
    private func categoryFilterButton(category: StreamCategory) -> some View {
        Button(action: { selectedCategory = category }) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedCategory == category ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(selectedCategory == category ? Color.white : .ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(selectedCategory == category ? 0 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
    
    // MARK: - Streams List
    private var streamsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredStreams, id: \.id) { stream in
                    EnhancedStreamRow(stream: stream) {
                        onStreamSelected(stream)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private var filteredStreams: [TwitchStream] {
        var filtered = streams
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { stream in
                stream.userName.localizedCaseInsensitiveContains(searchText) ||
                stream.title.localizedCaseInsensitiveContains(searchText) ||
                stream.gameName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        if selectedCategory != .all {
            filtered = filtered.filter { stream in
                switch selectedCategory {
                case .gaming:
                    return !["Just Chatting", "Music", "Sports"].contains(stream.gameName)
                case .justChatting:
                    return stream.gameName == "Just Chatting"
                case .music:
                    return stream.gameName.contains("Music") || stream.gameName == "Music"
                case .sports:
                    return stream.gameName.contains("Sports") || stream.gameName == "Sports"
                case .all:
                    return true
                }
            }
        }
        
        // Apply sort
        switch sortOption {
        case .viewers:
            filtered = filtered.sorted { $0.viewerCount > $1.viewerCount }
        case .recent:
            filtered = filtered.sorted { $0.startedAt > $1.startedAt }
        case .alphabetical:
            filtered = filtered.sorted { $0.userName < $1.userName }
        }
        
        return filtered
    }
    
    // MARK: - Helper Methods
    private func loadMockStreams() {
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            streams = [
                TwitchStream(id: "1", userId: "1", userLogin: "shroud", userName: "Shroud", gameId: "1", gameName: "VALORANT", type: "live", title: "Pro Gameplay - Road to Radiant", viewerCount: 25000, startedAt: "2025-07-10T10:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_shroud-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "2", userId: "2", userLogin: "pokimane", userName: "Pokimane", gameId: "2", gameName: "Just Chatting", type: "live", title: "Morning Stream - Coffee & Chat", viewerCount: 18000, startedAt: "2025-07-10T09:30:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_pokimane-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "3", userId: "3", userLogin: "xqc", userName: "xQc", gameId: "3", gameName: "GTA V", type: "live", title: "NoPixel RP - Bank Heist Planning", viewerCount: 45000, startedAt: "2025-07-10T08:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_xqc-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "4", userId: "4", userLogin: "ninja", userName: "Ninja", gameId: "4", gameName: "Fortnite", type: "live", title: "Arena Practice - New Season Grind", viewerCount: 32000, startedAt: "2025-07-10T11:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_ninja-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "5", userId: "5", userLogin: "asmongold", userName: "Asmongold", gameId: "5", gameName: "World of Warcraft", type: "live", title: "Classic WoW Raid Night - MC Clear", viewerCount: 28000, startedAt: "2025-07-10T12:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_asmongold-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "6", userId: "6", userLogin: "hasanabi", userName: "HasanAbi", gameId: "6", gameName: "Just Chatting", type: "live", title: "React Content & Political Discussion", viewerCount: 22000, startedAt: "2025-07-10T13:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_hasanabi-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "7", userId: "7", userLogin: "lirik", userName: "LIRIK", gameId: "7", gameName: "Variety", type: "live", title: "Variety Gaming - New Releases", viewerCount: 15000, startedAt: "2025-07-10T14:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_lirik-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "8", userId: "8", userLogin: "summit1g", userName: "summit1g", gameId: "8", gameName: "CS2", type: "live", title: "Counter-Strike 2 Competitive", viewerCount: 19000, startedAt: "2025-07-10T15:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_summit1g-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false)
            ]
            isLoading = false
        }
    }
    
    private func refreshStreams() {
        loadMockStreams()
    }
    
    private func loadPopularStreams() {
        // Filter to show most popular streams
        selectedCategory = .all
        sortOption = .viewers
    }
    
    private func loadLiveStreams() {
        // Show all live streams
        selectedCategory = .all
        sortOption = .recent
    }
    
    private func loadFavoriteStreams() {
        // Show favorited streams (mock implementation)
        streams = streams.filter { ["shroud", "pokimane", "ninja"].contains($0.userLogin) }
    }
}

// MARK: - Enhanced Stream Row
struct EnhancedStreamRow: View {
    let stream: TwitchStream
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: stream.thumbnailUrlMedium)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Image(systemName: "tv")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                .frame(width: 80, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    // Live indicator
                    HStack {
                        Spacer()
                        VStack {
                            Text("LIVE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.red)
                                )
                            Spacer()
                        }
                    }
                    .padding(4)
                )
                
                // Stream info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(stream.userName)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Text(stream.gameName)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        
                        HStack(spacing: 2) {
                            Image(systemName: "eye")
                                .font(.system(size: 8))
                            Text(stream.formattedViewerCount)
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Add button
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
}

#Preview {
    EnhancedStreamPickerView(selectedSlotIndex: 0) { _ in }
}