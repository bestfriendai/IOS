//
//  DiscoverView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var streamManager: StreamManager
    @State private var searchText = ""
    @State private var selectedCategory: StreamCategory = .all
    @State private var featuredStreams: [FeaturedStream] = []
    @State private var trendingStreams: [TrendingStream] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    // Category Filter
                    CategoryFilterView(selectedCategory: $selectedCategory)
                    
                    // Featured Section
                    if !featuredStreams.isEmpty {
                        FeaturedStreamsSection(streams: featuredStreams)
                    }
                    
                    // Trending Section
                    TrendingStreamsSection(streams: filteredTrendingStreams)
                    
                    // Popular Categories
                    PopularCategoriesSection()
                    
                    // Quick Add Section
                    QuickAddSection()
                }
                .padding(.bottom, 100) // Extra padding for tab bar
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadDiscoverContent()
            }
        }
        .onAppear {
            Task {
                await loadDiscoverContent()
            }
        }
    }
    
    private var filteredTrendingStreams: [TrendingStream] {
        if selectedCategory == .all {
            return trendingStreams
        }
        return trendingStreams.filter { $0.category == selectedCategory }
    }
    
    private func loadDiscoverContent() async {
        isLoading = true
        
        // Simulate API calls
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        featuredStreams = [
            FeaturedStream(
                id: "1",
                title: "shroud",
                game: "VALORANT",
                viewers: 45000,
                thumbnailURL: "https://example.com/thumb1.jpg",
                platform: .twitch,
                url: "https://twitch.tv/shroud"
            ),
            FeaturedStream(
                id: "2",
                title: "pokimane",
                game: "Just Chatting",
                viewers: 32000,
                thumbnailURL: "https://example.com/thumb2.jpg",
                platform: .twitch,
                url: "https://twitch.tv/pokimane"
            )
        ]
        
        trendingStreams = [
            TrendingStream(
                id: "1",
                title: "xQc",
                game: "Grand Theft Auto V",
                viewers: 78000,
                category: .gaming,
                platform: .twitch,
                url: "https://twitch.tv/xqc"
            ),
            TrendingStream(
                id: "2",
                title: "MKBHD",
                game: "Tech Review",
                viewers: 15000,
                category: .tech,
                platform: .youtube,
                url: "https://youtube.com/@mkbhd"
            ),
            TrendingStream(
                id: "3",
                title: "Ninja",
                game: "Fortnite",
                viewers: 25000,
                category: .gaming,
                platform: .twitch,
                url: "https://twitch.tv/ninja"
            )
        ]
        
        isLoading = false
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search streams, games, or creators", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Category Filter
struct CategoryFilterView: View {
    @Binding var selectedCategory: StreamCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StreamCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryChip: View {
    let category: StreamCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Featured Streams Section
struct FeaturedStreamsSection: View {
    let streams: [FeaturedStream]
    @EnvironmentObject var streamManager: StreamManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Featured")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(streams, id: \.id) { stream in
                        FeaturedStreamCard(stream: stream) {
                            streamManager.addStream(url: stream.url)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FeaturedStreamCard: View {
    let stream: FeaturedStream
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 200, height: 112)
                    
                    // Placeholder thumbnail
                    VStack {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    // Live indicator
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            
                            Spacer()
                        }
                        Spacer()
                        
                        HStack {
                            Spacer()
                            Text("\(stream.viewers) viewers")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(8)
                }
                
                // Stream info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(stream.game)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        Circle()
                            .fill(stream.platform.color)
                            .frame(width: 12, height: 12)
                        Text(stream.platform.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 200)
    }
}

// MARK: - Trending Streams Section
struct TrendingStreamsSection: View {
    let streams: [TrendingStream]
    @EnvironmentObject var streamManager: StreamManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trending")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(streams.enumerated()), id: \.element.id) { index, stream in
                    TrendingStreamRow(stream: stream, rank: index + 1) {
                        streamManager.addStream(url: stream.url)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TrendingStreamRow: View {
    let stream: TrendingStream
    let rank: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Rank
                Text("#\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                    .frame(width: 30)
                
                // Stream info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(stream.game)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Viewers and platform
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(stream.viewers) viewers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stream.platform.color)
                            .frame(width: 8, height: 8)
                        Text(stream.platform.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "plus.circle")
                    .foregroundColor(.purple)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Popular Categories Section
struct PopularCategoriesSection: View {
    private let categories = [
        ("Gaming", "gamecontroller", Color.blue),
        ("Just Chatting", "bubble.left.and.bubble.right", Color.green),
        ("Music", "music.note", Color.orange),
        ("Art", "paintbrush", Color.purple),
        ("Tech", "laptopcomputer", Color.gray),
        ("Sports", "sportscourt", Color.red)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Popular Categories")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(categories, id: \.0) { category in
                    CategoryCard(name: category.0, icon: category.1, color: category.2)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryCard: View {
    let name: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quick Add Section
struct QuickAddSection: View {
    @EnvironmentObject var streamManager: StreamManager
    @State private var showingAddStream = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button(action: { showingAddStream = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("Add Custom Stream")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingAddStream) {
            AddStreamView()
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
    let platform: StreamType
    let url: String
}

struct TrendingStream {
    let id: String
    let title: String
    let game: String
    let viewers: Int
    let category: StreamCategory
    let platform: StreamType
    let url: String
}

#Preview {
    DiscoverView()
        .environmentObject(StreamManager())
}