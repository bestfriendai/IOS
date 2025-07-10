//
//  StreamDetailView.swift
//  StreamyyyApp
//
//  Stream detail view for navigation
//

import SwiftUI

struct StreamDetailView: View {
    let streamId: String
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var streamManager: StreamManager
    @State private var stream: StreamModel?
    
    var body: some View {
        Group {
            if let stream = stream {
                VStack(spacing: 20) {
                    // Stream preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text(stream.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(stream.channelName ?? "Unknown Channel")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if stream.isLive {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                    Text("LIVE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        if let viewerCount = stream.viewerCount {
                            Text("\(viewerCount) viewers")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            // Add to multistream and navigate
                            streamManager.addStream(url: stream.url)
                            navigationCoordinator.navigateToMultiStream(animated: true)
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to Multi-Stream")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Toggle favorite
                        }) {
                            HStack {
                                Image(systemName: stream.isFavorite ? "heart.fill" : "heart")
                                Text(stream.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            } else {
                VStack {
                    ProgressView()
                    Text("Loading stream details...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Stream Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadStreamDetails()
        }
    }
    
    private func loadStreamDetails() {
        // Find stream by ID
        stream = streamManager.streams.first { $0.id == streamId }
    }
}

#Preview {
    NavigationView {
        StreamDetailView(streamId: "test")
            .environmentObject(NavigationCoordinator())
            .environmentObject(StreamManager())
    }
}