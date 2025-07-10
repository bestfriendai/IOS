//
//  ModernMainView.swift
//  StreamyyyApp
//
//  Modern, intuitive main interface with working features
//  Created by Claude Code on 2025-07-10
//

import SwiftUI

// MARK: - Modern Main View
struct ModernMainView: View {
    @StateObject private var streamStore = StreamStore()
    @State private var selectedTab = 0
    @State private var selectedStream: TwitchStream?
    @State private var showingStreamPlayer = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Discover Tab
            DiscoverTabView(
                streamStore: streamStore,
                onStreamSelected: { stream in
                    selectedStream = stream
                    showingStreamPlayer = true
                }
            )
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Discover")
            }
            .tag(0)
            
            // Browse Tab
            BrowseTabView(
                streamStore: streamStore,
                onStreamSelected: { stream in
                    selectedStream = stream
                    showingStreamPlayer = true
                }
            )
            .tabItem {
                Image(systemName: "rectangle.grid.2x2")
                Text("Browse")
            }
            .tag(1)
            
            // Following Tab (placeholder for now)
            FollowingTabView()
            .tabItem {
                Image(systemName: "heart")
                Text("Following")
            }
            .tag(2)
            
            // Profile Tab
            ProfileTabView()
            .tabItem {
                Image(systemName: "person")
                Text("Profile")
            }
            .tag(3)
        }
        .accentColor(.purple)
        .sheet(isPresented: $showingStreamPlayer) {
            if let stream = selectedStream {
                AlternativeStreamPlayer(stream: stream, isPresented: $showingStreamPlayer)
            }
        }
        .onAppear {
            streamStore.loadStreams()
        }
    }
}

// MARK: - Discover Tab
struct DiscoverTabView: View {
    @ObservedObject var streamStore: StreamStore
    let onStreamSelected: (TwitchStream) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory: StreamCategory?
    
    var filteredStreams: [TwitchStream] {
        if searchText.isEmpty {
            return streamStore.featuredStreams
        } else {
            return streamStore.streams.filter { stream in
                stream.title.localizedCaseInsensitiveContains(searchText) ||
                stream.userName.localizedCaseInsensitiveContains(searchText) ||
                stream.gameName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Search Bar
                    ModernSearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Categories
                    if searchText.isEmpty {
                        CategoriesSection(
                            categories: streamStore.categories,
                            selectedCategory: $selectedCategory
                        )
                        .padding(.top)
                    }
                    
                    // Featured Streams
                    if !filteredStreams.isEmpty {
                        StreamsGridSection(
                            title: searchText.isEmpty ? "Featured Streams" : "Search Results",
                            streams: filteredStreams,
                            onStreamSelected: onStreamSelected
                        )
                        .padding(.top)
                    } else if streamStore.isLoading {
                        LoadingStreamsView()
                            .padding(.top, 50)
                    } else {
                        EmptyStateView(
                            title: "No Streams Found",
                            subtitle: searchText.isEmpty ? "Check your connection and try again" : "Try searching for something else",
                            icon: "tv.slash"
                        )
                        .padding(.top, 50)
                    }
                }
            }
            .navigationTitle("Discover")
            .refreshable {
                await streamStore.refreshStreams()
            }
        }
    }
}

// MARK: - Browse Tab
struct BrowseTabView: View {
    @ObservedObject var streamStore: StreamStore
    let onStreamSelected: (TwitchStream) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if !streamStore.topStreams.isEmpty {
                        StreamsGridSection(
                            title: "Top Streams",
                            streams: streamStore.topStreams,
                            onStreamSelected: onStreamSelected
                        )
                    }
                    
                    if !streamStore.gamingStreams.isEmpty {
                        StreamsGridSection(
                            title: "Gaming",
                            streams: streamStore.gamingStreams,
                            onStreamSelected: onStreamSelected
                        )
                    }
                    
                    if !streamStore.justChattingStreams.isEmpty {
                        StreamsGridSection(
                            title: "Just Chatting",
                            streams: streamStore.justChattingStreams,
                            onStreamSelected: onStreamSelected
                        )
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Browse")
            .refreshable {
                await streamStore.refreshStreams()
            }
        }
    }
}

// MARK: - Following Tab
struct FollowingTabView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "heart.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)
                
                VStack(spacing: 12) {
                    Text("Following")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Follow your favorite streamers to see them here")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button("Connect Account") {
                    // TODO: Implement account connection
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .navigationTitle("Following")
        }
    }
}

// MARK: - Profile Tab
struct ProfileTabView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Profile Image
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
                
                VStack(spacing: 8) {
                    Text("Guest User")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Sign in to save preferences and follow streamers")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    Button("Sign In") {
                        // TODO: Implement sign in
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Settings") {
                        // TODO: Open settings
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Supporting Views

struct ModernSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search streams, games, or streamers", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CategoriesSection: View {
    let categories: [StreamCategory]
    @Binding var selectedCategory: StreamCategory?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Categories")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories) { category in
                        CategoryCard(
                            category: category,
                            isSelected: selectedCategory?.id == category.id,
                            onTap: {
                                selectedCategory = selectedCategory?.id == category.id ? nil : category
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct CategoryCard: View {
    let category: StreamCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: category.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "gamecontroller")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 80, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 80)
            }
        }
        .foregroundColor(isSelected ? .purple : .primary)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct StreamsGridSection: View {
    let title: String
    let streams: [TwitchStream]
    let onStreamSelected: (TwitchStream) -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(streams.prefix(6)) { stream in
                    ModernStreamCard(
                        stream: stream,
                        onTap: { onStreamSelected(stream) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ModernStreamCard: View {
    let stream: TwitchStream
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                AsyncImage(url: URL(string: stream.thumbnailUrlMedium)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            ProgressView()
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Text(stream.formattedViewerCount)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                    }
                    .padding(8)
                )
                
                // Stream Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(stream.userName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    if !stream.gameName.isEmpty {
                        Text(stream.gameName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .foregroundColor(.primary)
        .buttonStyle(PlainButtonStyle())
    }
}

struct LoadingStreamsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading streams...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Stream Store
class StreamStore: ObservableObject {
    @Published var streams: [TwitchStream] = []
    @Published var categories: [StreamCategory] = []
    @Published var isLoading = false
    
    var featuredStreams: [TwitchStream] {
        Array(streams.prefix(10))
    }
    
    var topStreams: [TwitchStream] {
        streams.sorted { $0.viewerCount > $1.viewerCount }.prefix(6).map { $0 }
    }
    
    var gamingStreams: [TwitchStream] {
        streams.filter { !$0.gameName.isEmpty && $0.gameName.lowercased() != "just chatting" }.prefix(6).map { $0 }
    }
    
    var justChattingStreams: [TwitchStream] {
        streams.filter { $0.gameName.lowercased().contains("just chatting") }.prefix(6).map { $0 }
    }
    
    func loadStreams() {
        isLoading = true
        
        // Use existing Twitch service
        Task {
            do {
                let twitchService = RealTwitchAPIService.shared
                await twitchService.validateAndRefreshTokens()
                
                let (fetchedStreams, _) = await twitchService.getTopStreams(first: 50)
                let fetchedCategories = await twitchService.getTopGames(first: 20)
                
                DispatchQueue.main.async {
                    self.streams = fetchedStreams
                    self.categories = fetchedCategories.map { game in
                        StreamCategory(
                            id: game.id,
                            name: game.name,
                            platform: .twitch,
                            viewerCount: 0,
                            streamCount: 0,
                            thumbnailURL: game.boxArtUrlLarge
                        )
                    }
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshStreams() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate delay for pull-to-refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        loadStreams()
    }
}

#Preview {
    ModernMainView()
}