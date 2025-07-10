//
//  SearchBar.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSearchButtonClicked: (() -> Void)? = nil
    var onCancelButtonClicked: (() -> Void)? = nil
    
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        onSearchButtonClicked?()
                    }
                    .onChange(of: isFocused) { focused in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing = focused
                        }
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isEditing ? Color.purple.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            
            // Cancel Button
            if isEditing {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        text = ""
                        isFocused = false
                        isEditing = false
                        onCancelButtonClicked?()
                    }
                }
                .foregroundColor(.purple)
                .font(.system(size: 16, weight: .medium))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

// MARK: - Advanced Search Bar
struct AdvancedSearchBar: View {
    @Binding var text: String
    @Binding var selectedFilter: SearchFilter
    var placeholder: String = "Search streams, games, or streamers..."
    var onSearch: (() -> Void)? = nil
    
    @State private var isEditing = false
    @State private var showingFilters = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Main Search Bar
            HStack(spacing: 12) {
                // Search Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField(placeholder, text: $text)
                        .focused($isFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            onSearch?()
                        }
                        .onChange(of: isFocused) { focused in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditing = focused
                            }
                        }
                    
                    if !text.isEmpty {
                        Button(action: {
                            text = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isEditing ? Color.purple.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
                
                // Filter Button
                Button(action: {
                    showingFilters.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16, weight: .medium))
                        
                        if selectedFilter != .all {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundColor(showingFilters ? .purple : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                showingFilters ? Color.purple.opacity(0.5) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                
                // Cancel Button
                if isEditing {
                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            text = ""
                            isFocused = false
                            isEditing = false
                            showingFilters = false
                        }
                    }
                    .foregroundColor(.purple)
                    .font(.system(size: 16, weight: .medium))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            
            // Filter Options
            if showingFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                                onSearch?()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .animation(.easeInOut(duration: 0.2), value: showingFilters)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.purple : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Color.clear : Color(.systemGray4),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Suggestions
struct SearchSuggestions: View {
    let suggestions: [String]
    let onSuggestionTapped: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button(action: {
                    onSuggestionTapped(suggestion)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        
                        Text(suggestion)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion != suggestions.last {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Recent Searches
struct RecentSearches: View {
    let searches: [String]
    let onSearchTapped: (String) -> Void
    let onClearAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Clear All") {
                    onClearAll()
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(searches, id: \.self) { search in
                    Button(action: {
                        onSearchTapped(search)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(search)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Search Filter Enum
enum SearchFilter: String, CaseIterable {
    case all = "All"
    case streams = "Streams"
    case games = "Games"
    case streamers = "Streamers"
    case live = "Live"
    case categories = "Categories"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .streams: return "play.circle"
        case .games: return "gamecontroller"
        case .streamers: return "person.circle"
        case .live: return "dot.radiowaves.left.and.right"
        case .categories: return "folder"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""))
        
        AdvancedSearchBar(
            text: .constant(""),
            selectedFilter: .constant(.all)
        )
        
        SearchSuggestions(
            suggestions: ["shroud", "pokimane", "valorant", "just chatting"]
        ) { suggestion in
            print("Tapped: \(suggestion)")
        }
        
        RecentSearches(
            searches: ["ninja", "fortnite", "apex legends", "minecraft"]
        ) { search in
            print("Recent: \(search)")
        } onClearAll: {
            print("Clear all")
        }
    }
    .padding()
}