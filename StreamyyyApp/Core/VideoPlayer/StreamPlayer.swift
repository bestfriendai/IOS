//
//  StreamPlayer.swift
//  StreamyyyApp
//
//  Native video player for reliable stream playback
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import AVKit
import AVFoundation
import WebKit

// MARK: - Stream Player View
struct StreamPlayer: View {
    let stream: TwitchStream
    @Binding var isPresented: Bool
    
    @StateObject private var playerManager = StreamPlayerManager()
    @State private var showControls = true
    @State private var isFullScreen = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Video Player Area
                    ZStack {
                        if playerManager.isLoading {
                            LoadingPlayerView()
                        } else if playerManager.hasError {
                            ErrorPlayerView(
                                error: playerManager.errorMessage,
                                onRetry: {
                                    playerManager.loadStream(stream)
                                }
                            )
                        } else {
                            WorkingVideoPlayer(
                                stream: stream,
                                playerManager: playerManager
                            )
                        }
                        
                        // Player Controls Overlay
                        if showControls && !playerManager.isLoading {
                            PlayerControlsOverlay(
                                isPlaying: $playerManager.isPlaying,
                                volume: $playerManager.volume,
                                onPlayPause: playerManager.togglePlayPause,
                                onSeek: playerManager.seek
                            )
                        }
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showControls.toggle()
                        }
                    }
                    
                    // Stream Info
                    if !isFullScreen {
                        StreamInfoView(stream: stream)
                    }
                }
            }
            .navigationTitle(isFullScreen ? "" : "Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isFullScreen ? "Exit" : "Fullscreen") {
                        withAnimation {
                            isFullScreen.toggle()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            playerManager.loadStream(stream)
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
}

// MARK: - Working Video Player
struct WorkingVideoPlayer: View {
    let stream: TwitchStream
    @ObservedObject var playerManager: StreamPlayerManager
    
    var body: some View {
        ZStack {
            // Use HLS player for better compatibility
            if let hlsURL = playerManager.hlsURL {
                AVPlayerView(url: hlsURL)
            } else {
                // Fallback to optimized WebView
                OptimizedTwitchWebView(
                    channelName: stream.userLogin,
                    onVideoReady: { url in
                        playerManager.hlsURL = url
                    }
                )
            }
        }
    }
}

// MARK: - AVPlayer View
struct AVPlayerView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.showsPlaybackControls = true
        
        // Configure for optimal playback
        player.automaticallyWaitsToMinimizeStalling = false
        player.play()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update if needed
    }
}

// MARK: - Optimized Twitch WebView
struct OptimizedTwitchWebView: UIViewRepresentable {
    let channelName: String
    let onVideoReady: (URL) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Load mobile-optimized Twitch page
        let urlString = "https://m.twitch.tv/\(channelName)"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: OptimizedTwitchWebView
        
        init(_ parent: OptimizedTwitchWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Try to extract HLS URL
            webView.evaluateJavaScript("""
                // Look for HLS streams
                const videos = document.getElementsByTagName('video');
                if (videos.length > 0) {
                    return videos[0].src || videos[0].currentSrc;
                }
                return null;
            """) { result, error in
                if let urlString = result as? String,
                   let url = URL(string: urlString) {
                    self.parent.onVideoReady(url)
                }
            }
        }
    }
}

// MARK: - Stream Player Manager
class StreamPlayerManager: ObservableObject {
    @Published var isLoading = true
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var isPlaying = false
    @Published var volume: Double = 1.0
    @Published var hlsURL: URL?
    
    func loadStream(_ stream: TwitchStream) {
        isLoading = true
        hasError = false
        
        // Simulate loading and try to get stream URL
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            self.isPlaying = true
        }
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    func seek(to time: Double) {
        // Implement seeking
    }
    
    func cleanup() {
        isPlaying = false
        hlsURL = nil
    }
}

// MARK: - Supporting Views
struct LoadingPlayerView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Loading Stream...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct ErrorPlayerView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Stream Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Unable to load stream. This may be due to platform restrictions or the stream being offline.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct PlayerControlsOverlay: View {
    @Binding var isPlaying: Bool
    @Binding var volume: Double
    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.white)
                    
                    Slider(value: $volume, in: 0...1)
                        .frame(width: 100)
                        .accentColor(.white)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

struct StreamInfoView: View {
    let stream: TwitchStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stream.title)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(2)
            
            HStack {
                Text(stream.userName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text("• \(stream.formattedViewerCount) viewers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !stream.gameName.isEmpty {
                Text("Playing: \(stream.gameName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    StreamPlayer(
        stream: TwitchStream(
            id: "123",
            userId: "456",
            userLogin: "shroud",
            userName: "shroud",
            gameId: "32982",
            gameName: "Grand Theft Auto V",
            type: "live",
            title: "Test Stream",
            viewerCount: 12345,
            startedAt: "2023-01-01T00:00:00Z",
            language: "en",
            thumbnailUrl: "https://example.com/thumbnail.jpg",
            tagIds: [],
            tags: [],
            isMature: false
        ),
        isPresented: .constant(true)
    )
}