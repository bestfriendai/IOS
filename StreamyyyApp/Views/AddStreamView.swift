//
//  AddStreamView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI

struct AddStreamView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var streamManager: StreamManager
    
    @State private var streamURL = ""
    @State private var selectedPlatform: StreamType = .twitch
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let popularStreams = [
        PopularStream(title: "shroud", platform: .twitch, url: "https://twitch.tv/shroud"),
        PopularStream(title: "pokimane", platform: .twitch, url: "https://twitch.tv/pokimane"),
        PopularStream(title: "xQc", platform: .twitch, url: "https://twitch.tv/xqc"),
        PopularStream(title: "Ninja", platform: .twitch, url: "https://twitch.tv/ninja"),
        PopularStream(title: "MKBHD", platform: .youtube, url: "https://youtube.com/@mkbhd"),
        PopularStream(title: "MrBeast Gaming", platform: .youtube, url: "https://youtube.com/@mrbeastgaming")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                        
                        Text("Add New Stream")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Enter a stream URL or select from popular streams")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // URL Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stream URL")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            TextField("https://twitch.tv/username or https://youtube.com/...", text: $streamURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            
                            // Platform Selector
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
                        
                        // Add Button
                        Button(action: addStream) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Stream")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(streamURL.isEmpty ? Color.gray : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(streamURL.isEmpty)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Popular Streams Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Popular Streams")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(popularStreams, id: \.title) { stream in
                                PopularStreamCard(stream: stream) {
                                    streamManager.addStream(url: stream.url)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Quick Add Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Quick Add")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            QuickAddButton(
                                title: "Add Twitch Stream",
                                subtitle: "Enter username",
                                icon: "tv",
                                color: .purple
                            ) {
                                showQuickAddAlert(for: .twitch)
                            }
                            
                            QuickAddButton(
                                title: "Add YouTube Stream",
                                subtitle: "Enter channel or video URL",
                                icon: "play.rectangle",
                                color: .red
                            ) {
                                showQuickAddAlert(for: .youtube)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Add Stream")
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
    
    private func addStream() {
        guard !streamURL.isEmpty else { return }
        
        if isValidURL(streamURL) {
            streamManager.addStream(url: streamURL)
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
    
    private func showQuickAddAlert(for platform: StreamType) {
        // This would show an alert for quick username entry
        // For now, we'll just set the platform
        selectedPlatform = platform
    }
}

// MARK: - Supporting Views
struct PopularStreamCard: View {
    let stream: PopularStream
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(stream.platform.color.opacity(0.1))
                        .frame(height: 80)
                    
                    VStack {
                        Image(systemName: stream.platform == .twitch ? "tv" : "play.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(stream.platform.color)
                        
                        Text(stream.platform.displayName)
                            .font(.caption)
                            .foregroundColor(stream.platform.color)
                    }
                }
                
                VStack(spacing: 2) {
                    Text(stream.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("Tap to add")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickAddButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Models
struct PopularStream {
    let title: String
    let platform: StreamType
    let url: String
}

#Preview {
    AddStreamView()
        .environmentObject(StreamManager())
}