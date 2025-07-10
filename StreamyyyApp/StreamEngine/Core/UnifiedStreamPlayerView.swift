//
//  UnifiedStreamPlayerView.swift
//  StreamyyyApp
//
//  Unified stream player view that resolves all conflicts and provides robust streaming
//  Created by Claude Code on 2025-07-09
//

import SwiftUI
import WebKit
import AVKit

/// Unified stream player view with robust error handling and state management
public struct UnifiedStreamPlayerView: View {
    
    // MARK: - Properties
    let stream: Stream
    @Binding var isPresented: Bool
    
    // State management
    @State private var isLoading = true
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var isBuffering = false
    @State private var playbackState: StreamPlaybackState = .idle
    @State private var showControls = true
    @State private var isMuted = false
    @State private var volume: Double = 1.0
    @State private var isFullscreen = false
    @State private var videoInfo: VideoInfo?
    
    // Timers and animation
    @State private var controlsTimer: Timer?
    @State private var loadingTimer: Timer?
    
    // State manager
    @StateObject private var stateManager = StreamStateManager.shared
    
    // MARK: - Body
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                if !isFullscreen {
                    streamHeader
                        .opacity(showControls ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showControls)
                }
                
                // Main content
                mainContent
                
                // Footer controls
                if !isFullscreen {
                    streamFooter
                        .opacity(showControls ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showControls)
                }
            }
            
            // Overlay controls
            if showControls {
                overlayControls
            }
            
            // Loading overlay
            if isLoading {
                loadingOverlay
            }
            
            // Error overlay
            if hasError {
                errorOverlay
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(isFullscreen)
        .onAppear {
            setupStream()
        }
        .onDisappear {
            cleanupStream()
        }
        .onTapGesture {
            toggleControls()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    handleSwipeGesture(value)
                }
        )
    }
    
    // MARK: - View Components
    
    private var streamHeader: some View {
        HStack {
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.displayTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let streamerName = stream.streamerName {
                    Text(streamerName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            streamStatusInfo
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var streamStatusInfo: some View {
        HStack(spacing: 16) {
            // Live indicator
            if stream.isLive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.3))
                .cornerRadius(12)
            }
            
            // Viewer count
            if stream.viewerCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.caption)
                    Text(stream.formattedViewerCount)
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.8))
            }
            
            // Stream health
            HStack(spacing: 4) {
                Image(systemName: stream.healthStatus.icon)
                    .font(.caption)
                    .foregroundColor(stream.healthStatus.color)
                Text(stream.healthStatus.displayName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            if hasError {
                errorView
            } else {
                streamWebView
            }
            
            // Buffering indicator
            if isBuffering {
                bufferingOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .cornerRadius(isFullscreen ? 0 : 8)
    }
    
    private var streamWebView: some View {
        UnifiedStreamWebView(
            stream: stream,
            isLoading: $isLoading,
            hasError: $hasError,
            errorMessage: $errorMessage,
            isBuffering: $isBuffering,
            playbackState: $playbackState,
            isMuted: isMuted,
            volume: volume,
            quality: stream.quality,
            enableChat: false,
            enableControls: false,
            onPlaybackStateChanged: { newState in
                playbackState = newState
                stateManager.updatePlaybackState(stream.id, state: newState)
            },
            onVideoInfoChanged: { info in
                videoInfo = info
            },
            onError: { error in
                hasError = true
                errorMessage = error.localizedDescription
            }
        )
    }
    
    private var streamFooter: some View {
        HStack {
            // Platform indicator
            HStack(spacing: 4) {
                Image(systemName: stream.platform.icon)
                    .font(.caption)
                Text(stream.platform.displayName)
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stream.platform.color.opacity(0.3))
            .cornerRadius(8)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                // Favorite button
                Button(action: {
                    // Handle favorite toggle
                }) {
                    Image(systemName: stream.isFavorited ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(stream.isFavorited ? .red : .white)
                }
                
                // Share button
                Button(action: {
                    shareStream()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // External link button
                Button(action: {
                    openInBrowser()
                }) {
                    Image(systemName: "safari")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var overlayControls: some View {
        VStack {
            // Top controls
            HStack {
                Button(action: {
                    if isFullscreen {
                        toggleFullscreen()
                    } else {
                        isPresented = false
                    }
                }) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Button(action: {
                    toggleFullscreen()
                }) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
            
            // Center controls
            HStack(spacing: 40) {
                Button(action: {
                    // Rewind 10 seconds
                    rewindStream()
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    togglePlayback()
                }) {
                    Image(systemName: playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .padding(20)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .disabled(playbackState == .loading || playbackState == .error)
                
                Button(action: {
                    // Fast forward 10 seconds
                    fastForwardStream()
                }) {
                    Image(systemName: "goforward.10")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            // Bottom controls
            HStack {
                Button(action: {
                    toggleMute()
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.2.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                
                // Volume slider
                Slider(value: $volume, in: 0...1)
                    .accentColor(.white)
                    .frame(width: 100)
                    .onChange(of: volume) { newValue in
                        stateManager.setStreamVolume(stream.id, volume: newValue)
                    }
                
                Spacer()
                
                // Quality indicator
                Text(stream.quality.displayName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .transition(.opacity)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Loading Stream...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Connecting to \(stream.platform.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .transition(.opacity)
    }
    
    private var errorOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Stream Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button(action: {
                        retryStream()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        openInBrowser()
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open in Browser")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .transition(.opacity)
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Unable to Load Stream")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Please check your internet connection and try again.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                retryStream()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var bufferingOverlay: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Buffering...")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
    }
    
    // MARK: - Methods
    
    private func setupStream() {
        // Register stream with state manager
        // Note: WebView will be registered when UnifiedStreamWebView is created
        
        // Start loading timer
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            if isLoading {
                hasError = true
                errorMessage = "Stream took too long to load"
                isLoading = false
            }
        }
        
        // Start controls timer
        startControlsTimer()
    }
    
    private func cleanupStream() {
        // Stop timers
        controlsTimer?.invalidate()
        loadingTimer?.invalidate()
        
        // Unregister from state manager
        stateManager.unregisterStream(stream.id)
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        
        if showControls {
            startControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
    
    private func togglePlayback() {
        if playbackState == .playing {
            stateManager.pauseStream(stream.id)
        } else {
            stateManager.resumeStream(stream.id)
        }
    }
    
    private func toggleMute() {
        isMuted.toggle()
        stateManager.muteStream(stream.id, muted: isMuted)
    }
    
    private func toggleFullscreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen.toggle()
        }
    }
    
    private func rewindStream() {
        // Implement rewind functionality
    }
    
    private func fastForwardStream() {
        // Implement fast forward functionality
    }
    
    private func retryStream() {
        hasError = false
        errorMessage = ""
        isLoading = true
        
        // Reset loading timer
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            if isLoading {
                hasError = true
                errorMessage = "Stream took too long to load"
                isLoading = false
            }
        }
    }
    
    private func shareStream() {
        let activityVC = UIActivityViewController(
            activityItems: [stream.url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func openInBrowser() {
        if let url = URL(string: stream.url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        let threshold: CGFloat = 50
        
        if value.translation.y > threshold {
            // Swipe down - exit fullscreen or dismiss
            if isFullscreen {
                toggleFullscreen()
            } else {
                isPresented = false
            }
        } else if value.translation.y < -threshold {
            // Swipe up - enter fullscreen
            if !isFullscreen {
                toggleFullscreen()
            }
        } else if value.translation.x > threshold {
            // Swipe right - go back
            if !isFullscreen {
                isPresented = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UnifiedStreamPlayerView(
        stream: Stream(
            url: "https://www.twitch.tv/shroud",
            platform: .twitch,
            title: "Shroud Gaming"
        ),
        isPresented: .constant(true)
    )
}