//
//  SearchResultsView.swift
//  StreamyyyApp
//
//  Search results view for navigation
//

import SwiftUI

struct SearchResultsView: View {
    let query: String
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var streamManager: StreamManager
    @State private var searchResults: [StreamModel] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search info header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Results")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("for \"\(query)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(searchResults.count) results")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary)
                    .cornerRadius(8)
            }
            .padding()
            .background(.regularMaterial)
            
            // Results
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Searching...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                }
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Results Found")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Try adjusting your search terms or check your spelling")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(searchResults) { stream in
                            SearchResultCard(stream: stream) {
                                // Add to multistream and navigate
                                streamManager.addStream(url: stream.url)
                                navigationCoordinator.navigateToMultiStream(animated: true)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            performSearch()
        }
    }
    
    private func performSearch() {
        isLoading = true
        
        // Simulate search delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Filter existing streams based on query
            searchResults = streamManager.streams.filter { stream in
                stream.title.localizedCaseInsensitiveContains(query) ||
                stream.channelName?.localizedCaseInsensitiveContains(query) == true ||
                stream.gameName?.localizedCaseInsensitiveContains(query) == true
            }
            
            isLoading = false
        }
    }
}

struct SearchResultCard: View {
    let stream: StreamModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 80, height: 45)
                    .overlay(
                        Image(systemName: "play.tv")
                            .foregroundColor(.white.opacity(0.7))
                    )
                
                // Stream info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(stream.channelName ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                    
                    HStack {
                        if let gameName = stream.gameName {
                            Text(gameName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if stream.isLive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Add button
                Image(systemName: "plus.circle")
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

#Preview {
    NavigationView {
        SearchResultsView(query: "gaming")
            .environmentObject(NavigationCoordinator())
            .environmentObject(StreamManager())
    }
}