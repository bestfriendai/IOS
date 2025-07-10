//
//  StreamPickerView.swift
//  StreamyyyApp
//
//  Stream selection interface optimized for multi-stream setup
//  Created by Claude Code on 2025-07-10
//

import SwiftUI

// MARK: - Stream Picker View
struct StreamPickerView: View {
    @ObservedObject var streamStore: StreamStoreManager
    let selectedSlotIndex: Int
    let onStreamSelected: (TwitchStream) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: String?
    
    var filteredStreams: [TwitchStream] {
        var streams = streamStore.streams
        
        // Filter by search text
        if !searchText.isEmpty {
            streams = streams.filter { stream in
                stream.title.localizedCaseInsensitiveContains(searchText) ||
                stream.userName.localizedCaseInsensitiveContains(searchText) ||
                stream.gameName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by category
        if let category = selectedCategory, !category.isEmpty {
            streams = streams.filter { stream in
                stream.gameName.localizedCaseInsensitiveContains(category)
            }
        }
        
        return streams
    }
    
    var popularCategories: [String] {
        let categories = Array(Set(streamStore.streams.map { $0.gameName }))
            .filter { !$0.isEmpty }
            .sorted { first, second in
                let firstCount = streamStore.streams.filter { $0.gameName == first }.count
                let secondCount = streamStore.streams.filter { $0.gameName == second }.count
                return firstCount > secondCount
            }
        
        return Array(categories.prefix(10))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                StreamSearchBar(searchText: $searchText)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Categories
                if searchText.isEmpty && !popularCategories.isEmpty {
                    CategoryScrollView(
                        categories: popularCategories,
                        selectedCategory: $selectedCategory
                    )
                    .padding(.top)
                }
                
                // Stream List
                if streamStore.isLoading {
                    Spacer()
                    ProgressView("Loading streams...")
                    Spacer()
                } else if filteredStreams.isEmpty {
                    Spacer()
                    EmptySearchView(searchText: searchText)
                    Spacer()
                } else {
                    StreamListView(
                        streams: filteredStreams,
                        onStreamSelected: onStreamSelected
                    )
                }
            }
            .navigationTitle("Add to Slot \(selectedSlotIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        streamStore.loadStreams()
                    }
                }
            }
        }
        .onAppear {
            if streamStore.streams.isEmpty {
                streamStore.loadStreams()
            }
        }
    }
}

// MARK: - Stream Search Bar
struct StreamSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search streams, games, or streamers", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
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

// MARK: - Category Scroll View
struct CategoryScrollView: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Popular Categories")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // All Categories Button
                    CategoryChip(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        onTap: {
                            selectedCategory = nil
                        }
                    )
                    
                    // Category Chips
                    ForEach(categories, id: \.self) { category in
                        CategoryChip(
                            title: category,
                            isSelected: selectedCategory == category,
                            onTap: {
                                selectedCategory = selectedCategory == category ? nil : category
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Stream List View
struct StreamListView: View {
    let streams: [TwitchStream]
    let onStreamSelected: (TwitchStream) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(streams) { stream in
                    StreamPickerRow(
                        stream: stream,
                        onTap: {
                            onStreamSelected(stream)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Stream Picker Row
struct StreamPickerRow: View {
    let stream: TwitchStream
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: stream.thumbnailUrlSmall)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "tv")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 80, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red)
                                .cornerRadius(3)
                        }
                        Spacer()
                    }
                    .padding(4)
                )
                
                // Stream Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(stream.userName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 4, height: 4)
                            
                            Text(stream.formattedViewerCount)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !stream.gameName.isEmpty {
                        Text(stream.gameName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Add Button
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .foregroundColor(.primary)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty Search View
struct EmptySearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "tv.slash" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Streams Available" : "No Results Found")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(searchText.isEmpty 
                     ? "Check your connection and try again"
                     : "Try a different search term")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Quick Stream Suggestions
struct QuickStreamSuggestions: View {
    let streams: [TwitchStream]
    let onStreamSelected: (TwitchStream) -> Void
    
    var topStreamers: [TwitchStream] {
        streams.sorted { $0.viewerCount > $1.viewerCount }.prefix(5).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular Right Now")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(topStreamers) { stream in
                        QuickStreamCard(
                            stream: stream,
                            onTap: {
                                onStreamSelected(stream)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Quick Stream Card
struct QuickStreamCard: View {
    let stream: TwitchStream
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: stream.thumbnailUrlSmall)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(stream.userName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    Text(stream.formattedViewerCount)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .foregroundColor(.primary)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    StreamPickerView(
        streamStore: StreamStoreManager(),
        selectedSlotIndex: 0,
        onStreamSelected: { _ in }
    )
}