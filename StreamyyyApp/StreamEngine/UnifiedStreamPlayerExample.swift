//
//  UnifiedStreamPlayerExample.swift
//  StreamyyyApp
//
//  Example implementation showing how to use the unified stream player system
//  Demonstrates best practices for reliable streaming in iOS
//  Created by Claude Code on 2025-07-11
//

import SwiftUI

/// Example view demonstrating how to use the unified stream player
/// This replaces all existing player implementations with a single, reliable solution
struct UnifiedStreamPlayerExample: View {
    
    // MARK: - State
    @StateObject private var streamManager = ExampleStreamManager()
    @StateObject private var audioManager = MultiStreamAudioManager.shared
    @State private var selectedStream: Stream?
    @State private var isPlayerPresented = false
    @State private var showMultiStream = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                
                streamSelectionSection
                
                playerSection
                
                multiStreamSection
                
                audioControlsSection
                
                adaptiveQualityDemoSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Stream Player Demo")
            .task {
                await loadExampleStreams()
            }
        }
        .sheet(isPresented: $isPlayerPresented) {
            if let stream = selectedStream {
                UnifiedStreamPlayer(
                    stream: stream,
                    isPresented: $isPlayerPresented,
                    enableControls: true,
                    enablePictureInPicture: true,
                    enableChat: false,
                    autoplay: true
                )
            }
        }
        .sheet(isPresented: $showMultiStream) {
            MultiStreamViewExample(isPresented: $showMultiStream)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Unified Stream Player")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Single, reliable solution for Twitch, YouTube, and more")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var streamSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example Streams")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(streamManager.exampleStreams) { stream in
                        StreamCard(stream: stream) {
                            selectedStream = stream
                            isPlayerPresented = true
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Single Stream Player")
                .font(.headline)
            
            Button(action: {
                selectedStream = streamManager.exampleStreams.first
                isPlayerPresented = true
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Open Stream Player")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
            }
            
            Text("Features: Error recovery, CORS handling, quality selection, audio management")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var multiStreamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Multi-Stream Player")
                .font(.headline)
            
            Button(action: {
                showMultiStream = true
            }) {
                HStack {
                    Image(systemName: "rectangle.split.3x3.fill")
                    Text("Open Multi-Stream View")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.purple)
                .cornerRadius(8)
            }
            
            Text("Features: Optimized performance, audio mixing, focus management")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var audioControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Management")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Master Volume")
                    Spacer()
                    Slider(value: Binding(
                        get: { Double(audioManager.masterVolume) },
                        set: { audioManager.setMasterVolume(Float($0)) }
                    ), in: 0...1)
                    .frame(width: 120)
                }
                
                HStack {
                    Text("Audio Route")
                    Spacer()
                    Text(audioManager.audioRouteDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("Audio Ducking", isOn: $audioManager.isDuckingEnabled)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var adaptiveQualityDemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adaptive Quality Demo")
                .font(.headline)
            
            VStack(spacing: 8) {
                Text("The unified player automatically adjusts quality based on:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundColor(.blue)
                        Text("Network connection speed")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.green)
                        Text("Buffering frequency and performance")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.purple)
                        Text("Frame drop rate and playback health")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        Text("Device capabilities and battery status")
                            .font(.caption)
                    }
                }
                .padding(.leading, 8)
                
                HStack {
                    Text("Manual Override:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Use player settings to force specific quality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Methods
    
    private func loadExampleStreams() async {
        await streamManager.loadExampleStreams()
    }
}

// MARK: - Stream Card Component

struct StreamCard: View {
    let stream: Stream
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Platform badge
            HStack {
                Image(systemName: stream.platform.icon)
                    .font(.caption)
                Text(stream.platform.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(stream.platform.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stream.platform.color.opacity(0.2))
            .cornerRadius(4)
            
            // Stream info
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if let streamerName = stream.streamerName {
                    Text(streamerName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if stream.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .frame(width: 150, height: 120)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Multi-Stream Example

struct MultiStreamViewExample: View {
    @Binding var isPresented: Bool
    @StateObject private var multiStreamManager = MultiStreamManager()
    @StateObject private var audioManager = MultiStreamAudioManager.shared
    
    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                if multiStreamManager.activeStreams.isEmpty {
                    ContentUnavailableView(
                        "No Active Streams",
                        systemImage: "tv.slash",
                        description: Text("Add streams to start watching multiple streams simultaneously")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(multiStreamManager.activeStreams) { stream in
                                MultiStreamCell(
                                    stream: stream,
                                    isFocused: audioManager.focusedStreamId == stream.id,
                                    onFocus: {
                                        audioManager.setFocusedStream(stream.id)
                                    },
                                    onRemove: {
                                        multiStreamManager.removeStream(stream.id)
                                        audioManager.unregisterStream(stream.id)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Multi-Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Stream") {
                        addExampleStream()
                    }
                }
            }
        }
        .task {
            setupInitialStreams()
        }
    }
    
    private func setupInitialStreams() {
        // Add a few example streams
        let exampleStreams = [
            Stream(url: "https://www.twitch.tv/shroud", platform: .twitch, title: "Shroud Gaming"),
            Stream(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", platform: .youtube, title: "YouTube Live"),
        ]
        
        for stream in exampleStreams {
            multiStreamManager.addStream(stream)
            audioManager.registerStream(stream.id, initialVolume: audioManager.getOptimalVolumeForNewStream())
        }
    }
    
    private func addExampleStream() {
        let newStream = Stream(
            url: "https://www.twitch.tv/ninja",
            platform: .twitch,
            title: "Ninja Fortnite"
        )
        
        multiStreamManager.addStream(newStream)
        audioManager.registerStream(newStream.id, initialVolume: audioManager.getOptimalVolumeForNewStream())
    }
}

// MARK: - Multi-Stream Cell

struct MultiStreamCell: View {
    let stream: Stream
    let isFocused: Bool
    let onFocus: () -> Void
    let onRemove: () -> Void
    
    @StateObject private var engine = UnifiedStreamPlayerEngine()
    
    var body: some View {
        VStack(spacing: 0) {
            // Player area
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                
                if let webView = engine.getWebView() {
                    WebViewRepresentable(webView: webView)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                }
                
                // Focus overlay
                if isFocused {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 3)
                }
                
                // Loading indicator
                if engine.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                // Error state
                if engine.hasError {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.red)
                        Text("Error")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            .onTapGesture {
                onFocus()
            }
            
            // Controls
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stream.displayTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(stream.platform.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        engine.setMuted(!engine.isMuted)
                    }) {
                        Image(systemName: engine.isMuted ? "speaker.slash" : "speaker.2")
                            .font(.caption)
                    }
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            engine.loadStream(stream)
        }
        .onDisappear {
            engine.cleanup()
        }
    }
}

// MARK: - Supporting Types

@MainActor
class ExampleStreamManager: ObservableObject {
    @Published var exampleStreams: [Stream] = []
    
    func loadExampleStreams() async {
        // Create example streams for demonstration
        exampleStreams = [
            Stream(
                url: "https://www.twitch.tv/shroud",
                platform: .twitch,
                title: "Shroud Gaming Session"
            ),
            Stream(
                url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                platform: .youtube,
                title: "YouTube Live Stream"
            ),
            Stream(
                url: "https://www.twitch.tv/ninja",
                platform: .twitch,
                title: "Ninja Fortnite"
            ),
            Stream(
                url: "https://kick.com/xqc",
                platform: .kick,
                title: "xQc on Kick"
            )
        ]
        
        // Update stream metadata
        for i in 0..<exampleStreams.count {
            exampleStreams[i].isLive = true
            exampleStreams[i].viewerCount = Int.random(in: 1000...50000)
            exampleStreams[i].streamerName = extractStreamerName(from: exampleStreams[i].url)
        }
    }
    
    private func extractStreamerName(from url: String) -> String? {
        let components = URLComponents(string: url)
        let pathComponents = components?.path.components(separatedBy: "/").filter { !$0.isEmpty }
        return pathComponents?.last
    }
}

@MainActor
class MultiStreamManager: ObservableObject {
    @Published var activeStreams: [Stream] = []
    
    func addStream(_ stream: Stream) {
        guard !activeStreams.contains(where: { $0.id == stream.id }) else { return }
        activeStreams.append(stream)
    }
    
    func removeStream(_ streamId: String) {
        activeStreams.removeAll { $0.id == streamId }
    }
}

// MARK: - WebView Representable

private struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Updates handled by the engine
    }
}

// MARK: - Preview

#Preview {
    UnifiedStreamPlayerExample()
}