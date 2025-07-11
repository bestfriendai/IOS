//
//  EnhancedStreamPickerSheet.swift
//  StreamyyyApp
//
//  Advanced stream picker with search, filtering, and real Twitch API integration
//

import SwiftUI

struct EnhancedStreamPickerSheet: View {
    let availableStreams: [TwitchStreamData]
    let onStreamSelected: (TwitchStreamData) -> Void
    @Binding var isLoading: Bool
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var twitchAPI = TwitchAPIService.shared
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var searchResults: [TwitchStreamData] = []
    @State private var isSearching = false
    @State private var featuredStreams: [TwitchStreamData] = []
    
    private let categories = ["All", "Just Chatting", "Gaming", "Music", "Art", "Sports", "IRL"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Search and filters
                    searchAndFiltersView
                    
                    // Content
                    contentView
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadFeaturedStreams()
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Stream")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Choose from live streams")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.cyan)
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Search and Filters
    private var searchAndFiltersView: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search streams or channels...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        if newValue.isEmpty {
                            searchResults = []
                            isSearching = false
                        } else if newValue.count > 2 {
                            Task {
                                await performLiveSearch(query: newValue)
                            }
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        isSearching = false
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
            
            // Category filter
            if !isSearching {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryFilterChip(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: {
                                    selectedCategory = category
                                    Task {
                                        await loadCategoryStreams(category)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Content
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    loadingView
                } else if isSearching && !searchResults.isEmpty {
                    searchResultsSection
                } else if !isSearching {
                    featuredStreamsSection
                } else if isSearching && searchResults.isEmpty {
                    noResultsView
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.5)
            
            Text("Loading streams...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Search Results Section
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search Results")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(searchResults.count) found")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(searchResults, id: \.id) { stream in
                    StreamPickerCard(stream: stream) {
                        onStreamSelected(stream)
                    }
                }
            }
        }
    }
    
    // MARK: - Featured Streams Section
    private var featuredStreamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedCategory == "All" ? "Featured Streams" : selectedCategory)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !featuredStreams.isEmpty {
                    Text("\(featuredStreams.count) streams")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            if featuredStreams.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(featuredStreams, id: \.id) { stream in
                        StreamPickerCard(stream: stream) {
                            onStreamSelected(stream)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No streams found")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No streams available")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Check your internet connection or try again later")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Helper Methods
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            isSearching = true
            do {
                let results = try await twitchAPI.searchStreams(query: searchText, limit: 50)
                await MainActor.run {
                    searchResults = results
                }
            } catch {
                print("Search failed: \(error)")
            }
        }
    }
    
    private func performLiveSearch(query: String) async {
        do {
            let results = try await twitchAPI.searchStreams(query: query, limit: 20)
            await MainActor.run {
                searchResults = results
                isSearching = !query.isEmpty
            }
        } catch {
            print("Live search failed: \(error)")
        }
    }
    
    private func loadFeaturedStreams() async {
        do {
            let streams = try await twitchAPI.getTopStreams(limit: 50)
            await MainActor.run {
                featuredStreams = streams
            }
        } catch {
            print("Failed to load featured streams: \(error)")
        }
    }
    
    private func loadCategoryStreams(_ category: String) async {
        do {
            let streams = try await twitchAPI.getStreamsForCategory(category, limit: 30)
            await MainActor.run {
                featuredStreams = streams
            }
        } catch {
            print("Failed to load category streams: \(error)")
        }
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.cyan : Color.white.opacity(0.2))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stream Picker Card
struct StreamPickerCard: View {
    let stream: TwitchStreamData
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                AsyncImage(url: URL(string: stream.thumbnailUrl.replacingOccurrences(of: "{width}", with: "320").replacingOccurrences(of: "{height}", with: "180"))) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .clipped()
                .cornerRadius(8)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("LIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text("\(stream.viewerCount.formatted()) viewers")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.7))
                        )
                        .padding(8)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.userName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(stream.title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                    
                    if let gameName = stream.gameName, !gameName.isEmpty {
                        Text(gameName)
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    EnhancedStreamPickerSheet(
        availableStreams: [],
        onStreamSelected: { _ in },
        isLoading: .constant(false)
    )
}