//
//  StreamPickerSheet.swift
//  StreamyyyApp
//
//  Stream picker sheet for selecting streams to add to multistream
//

import SwiftUI

struct StreamPickerSheet: View {
    let onStreamSelected: (StreamModel) -> Void
    @EnvironmentObject var streamManager: StreamManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    
    private let categories = ["All", "Gaming", "Just Chatting", "Music", "Art", "Technology"]
    
    var filteredStreams: [StreamModel] {
        var streams = streamManager.streams
        
        // Filter by search text
        if !searchText.isEmpty {
            streams = streams.filter { stream in
                stream.title.localizedCaseInsensitiveContains(searchText) ||
                stream.channelName?.localizedCaseInsensitiveContains(searchText) == true ||
                stream.gameName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Filter by category
        if selectedCategory != "All" {
            streams = streams.filter { stream in
                stream.gameName?.contains(selectedCategory) == true
            }
        }
        
        return streams
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filters
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search streams, channels, games...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Stream List
                if filteredStreams.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "tv.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Streams Found")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Try adjusting your search or category filter")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredStreams) { stream in
                                StreamPickerRow(stream: stream) {
                                    onStreamSelected(stream)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Quick Actions
                HStack(spacing: 16) {
                    Button(action: {
                        navigationCoordinator.showAddStreamSheet()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Custom URL")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        navigationCoordinator.navigateToMultiStream(animated: true)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.3.group")
                            Text("Go to Multi-Stream")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding()
                        .background(.blue)
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Choose Streams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StreamPickerRow: View {
    let stream: StreamModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(stream.type.color.opacity(0.3))
                    .frame(width: 80, height: 45)
                    .overlay(
                        VStack {
                            Image(systemName: "play.tv")
                                .foregroundColor(stream.type.color)
                            
                            if stream.isLive {
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                        }
                    )
                
                // Stream info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(stream.channelName ?? "Unknown")
                            .font(.subheadline)
                            .foregroundColor(stream.type.color)
                        
                        Spacer()
                        
                        Text(stream.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(stream.type.color.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    HStack {
                        if let gameName = stream.gameName {
                            Text(gameName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if stream.isLive {
                            Text("\(stream.viewerCount) viewers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Add button
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? .blue : .blue.opacity(0.1))
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    StreamPickerSheet { stream in
        print("Selected: \(stream.title)")
    }
    .environmentObject(StreamManager())
    .environmentObject(NavigationCoordinator())
}