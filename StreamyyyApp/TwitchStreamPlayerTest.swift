//
//  TwitchStreamPlayerTest.swift
//  StreamyyyApp
//
//  Test component to validate Twitch stream playback functionality
//  Created by Claude Code on 2025-07-10
//

import SwiftUI

struct TwitchStreamPlayerTest: View {
    @State private var isLoading = true
    @State private var hasError = false
    @State private var isLive = false
    @State private var viewerCount = 0
    @State private var currentQuality: StreamQuality = .auto
    @State private var showTestPlayer = false
    
    // Test channels (popular streamers that are likely to be live)
    private let testChannels = [
        "shroud",
        "ninja",
        "pokimane",
        "summit1g",
        "xqcow",
        "sodapoppin",
        "lirik",
        "timthetatman"
    ]
    
    @State private var selectedChannel = "shroud"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Twitch Stream Player Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select a channel to test stream playback:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Channel selection
                Picker("Test Channel", selection: $selectedChannel) {
                    ForEach(testChannels, id: \.self) { channel in
                        Text(channel)
                            .tag(channel)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Test player button
                Button(action: {
                    showTestPlayer = true
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                        Text("Test Stream Player")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .cornerRadius(10)
                }
                
                // Status indicators
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(isLive ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text("Stream Status: \(isLive ? "Live" : "Offline")")
                            .font(.caption)
                    }
                    
                    HStack {
                        Circle()
                            .fill(isLoading ? .orange : .blue)
                            .frame(width: 8, height: 8)
                        Text("Loading: \(isLoading ? "Yes" : "No")")
                            .font(.caption)
                    }
                    
                    HStack {
                        Circle()
                            .fill(hasError ? .red : .green)
                            .frame(width: 8, height: 8)
                        Text("Error: \(hasError ? "Yes" : "No")")
                            .font(.caption)
                    }
                    
                    if viewerCount > 0 {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.secondary)
                            Text("\(viewerCount) viewers")
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                        Text("Quality: \(currentQuality.displayName)")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Instructions:")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Text("• Select a channel from the dropdown")
                    Text("• Tap 'Test Stream Player' to open")
                    Text("• Verify video content loads and plays")
                    Text("• Test volume and quality controls")
                    Text("• Try fullscreen mode (double-tap)")
                    Text("• Check error handling for offline streams")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("Stream Test")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTestPlayer) {
                TestStreamPlayerSheet(
                    channelName: selectedChannel,
                    isLoading: $isLoading,
                    hasError: $hasError,
                    isLive: $isLive,
                    viewerCount: $viewerCount,
                    currentQuality: $currentQuality
                )
            }
        }
    }
}

struct TestStreamPlayerSheet: View {
    let channelName: String
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var isLive: Bool
    @Binding var viewerCount: Int
    @Binding var currentQuality: StreamQuality
    
    @Environment(\.presentationMode) var presentationMode
    @State private var volume: Double = 1.0
    @State private var isMuted = false
    @State private var isFullscreen = false
    @State private var showControls = true
    @State private var showQualitySelection = false
    
    private let availableQualities: [StreamQuality] = [
        .auto, .source, .hd720p60, .hd720p, .medium, .low, .mobile
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Test Stream Player
                    ZStack {
                        TwitchEmbedWebView(
                            channelName: channelName,
                            chatEnabled: false,
                            quality: currentQuality,
                            isLoading: $isLoading,
                            hasError: $hasError,
                            isLive: $isLive,
                            viewerCount: $viewerCount,
                            currentQuality: $currentQuality,
                            lowLatency: true,
                            autoplay: true,
                            muted: isMuted,
                            volume: volume,
                            fullscreen: isFullscreen
                        )
                        .aspectRatio(16/9, contentMode: .fit)
                        .background(Color.black)
                        .clipped()
                        
                        // Loading overlay
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text("Testing \(channelName) stream...")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.8))
                        }
                        
                        // Error overlay
                        if hasError {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.red)
                                
                                Text("Test Failed")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("The stream \(channelName) may be offline or experiencing issues.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                
                                Button("Retry Test") {
                                    hasError = false
                                    isLoading = true
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.purple)
                                .cornerRadius(8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.8))
                        }
                        
                        // Player controls overlay
                        if showControls && !isLoading && !hasError {
                            VStack {
                                Spacer()
                                
                                PlayerControlsView(
                                    volume: $volume,
                                    isMuted: $isMuted,
                                    currentQuality: $currentQuality,
                                    availableQualities: availableQualities,
                                    isLive: isLive,
                                    showQualitySelection: $showQualitySelection,
                                    onFullscreenToggle: {
                                        isFullscreen.toggle()
                                    }
                                )
                            }
                            .padding()
                        }
                        
                        // Test status overlay
                        VStack {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TEST MODE")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    
                                    Text(channelName)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                if isLive {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text("WORKING")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            
                            Spacer()
                        }
                        .padding()
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showControls.toggle()
                        }
                    }
                    
                    // Test details
                    if !isFullscreen {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Testing Channel: \(channelName)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("Status Indicators:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                TestStatusIndicator(
                                    title: "Loading",
                                    status: isLoading ? "Active" : "Complete",
                                    color: isLoading ? .orange : .green
                                )
                                
                                TestStatusIndicator(
                                    title: "Error",
                                    status: hasError ? "Yes" : "No",
                                    color: hasError ? .red : .green
                                )
                                
                                TestStatusIndicator(
                                    title: "Live",
                                    status: isLive ? "Yes" : "No",
                                    color: isLive ? .green : .red
                                )
                                
                                TestStatusIndicator(
                                    title: "Quality",
                                    status: currentQuality.shortDisplayName,
                                    color: .blue
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    
                    if !isFullscreen {
                        Spacer()
                    }
                }
            }
            .navigationTitle(isFullscreen ? "" : "Stream Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFullscreen {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct TestStatusIndicator: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(status)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

#Preview {
    TwitchStreamPlayerTest()
}