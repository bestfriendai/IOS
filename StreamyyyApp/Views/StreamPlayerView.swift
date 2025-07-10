//
//  StreamPlayerView.swift
//  StreamyyyApp
//
//  Platform-specific stream player view
//

import SwiftUI
import WebKit
import AVKit

struct StreamPlayerView: View {
    let stream: Stream
    @State private var isFullScreen = false
    @State private var showingControls = true
    @State private var isLoading = true
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var controlsTimer: Timer?
    @State private var volume: Double = 1.0
    @State private var isMuted = false
    @State private var selectedQuality: StreamQuality?
    @State private var showingQualitySelector = false
    @State private var isBuffering = false
    @State private var playbackState: PlaybackState = .stopped
    
    @StateObject private var playerManager = StreamPlayerManager()
    @Environment(\.dismiss) private var dismiss
    
    enum PlaybackState {
        case playing, paused, stopped, buffering, error
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Player Content
            VStack(spacing: 0) {
                // Player View
                playerView
                    .aspectRatio(16/9, contentMode: .fit)
                    .onTapGesture {
                        toggleControls()
                    }
                
                // Bottom controls (only in non-fullscreen)
                if !isFullScreen {
                    bottomControlsView
                        .background(Color.black.opacity(0.8))
                }
            }
            
            // Overlay Controls
            if showingControls {
                overlayControlsView
            }
            
            // Loading indicator
            if isLoading {
                loadingView
            }
            
            // Error view
            if hasError {
                errorView
            }
        }
        .navigationBarHidden(isFullScreen)
        .statusBarHidden(isFullScreen)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    handleSwipeGesture(value)
                }
        )
    }
    
    // MARK: - Player View
    private var playerView: some View {
        ZStack {
            // Platform-specific player
            switch stream.platform {
            case .twitch:
                TwitchPlayerView(stream: stream, playerManager: playerManager)
            case .youtube:
                YouTubePlayerView(stream: stream, playerManager: playerManager)
            case .kick:
                KickPlayerView(stream: stream, playerManager: playerManager)
            default:
                GenericWebPlayerView(stream: stream, playerManager: playerManager)
            }
            
            // Buffering indicator
            if isBuffering {
                bufferingView
            }
        }
        .onReceive(playerManager.$isLoading) { loading in
            isLoading = loading
        }
        .onReceive(playerManager.$hasError) { error in
            hasError = error
            if error {
                errorMessage = playerManager.errorMessage
            }
        }
        .onReceive(playerManager.$isBuffering) { buffering in
            isBuffering = buffering
        }
        .onReceive(playerManager.$playbackState) { state in
            playbackState = state
        }
    }
    
    // MARK: - Overlay Controls
    private var overlayControlsView: some View {
        VStack {
            // Top controls
            HStack {
                Button(action: {
                    if isFullScreen {
                        exitFullScreen()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: isFullScreen ? "xmark" : "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(22)
                }
                
                Spacer()
                
                // Stream info
                VStack(alignment: .trailing, spacing: 4) {
                    Text(stream.displayTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let streamerName = stream.streamerName {
                        Text(streamerName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // More options
                Button(action: {
                    // Show more options
                }) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(22)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Center controls
            HStack(spacing: 40) {
                // Previous/Rewind
                Button(action: {
                    playerManager.rewind()
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                // Play/Pause
                Button(action: {
                    togglePlayback()
                }) {
                    Image(systemName: playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .disabled(playbackState == .buffering)
                
                // Next/Fast Forward
                Button(action: {
                    playerManager.fastForward()
                }) {
                    Image(systemName: "goforward.15")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            // Bottom controls
            HStack {
                // Volume
                Button(action: {
                    toggleMute()
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.2.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Slider(value: $volume, in: 0...1)
                    .accentColor(.white)
                    .frame(width: 80)
                    .onChange(of: volume) { newValue in
                        playerManager.setVolume(newValue)
                        if newValue > 0 {
                            isMuted = false
                        }
                    }
                
                Spacer()
                
                // Quality
                Button(action: {
                    showingQualitySelector = true
                }) {
                    HStack(spacing: 4) {
                        Text(selectedQuality?.displayName ?? "Auto")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
                
                // Fullscreen
                Button(action: {
                    toggleFullScreen()
                }) {
                    Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.clear,
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .opacity(showingControls ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: showingControls)
    }
    
    // MARK: - Bottom Controls
    private var bottomControlsView: some View {
        VStack(spacing: 12) {
            // Stream stats
            HStack {
                // Live indicator
                if stream.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Viewer count
                if stream.viewerCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(stream.formattedViewerCount)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Health status
                HStack(spacing: 4) {
                    Image(systemName: stream.healthStatus.icon)
                        .font(.caption)
                        .foregroundColor(stream.healthStatus.color)
                    
                    Text(stream.healthStatus.displayName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Action buttons
            HStack(spacing: 16) {
                // Favorite
                Button(action: {
                    // Toggle favorite
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: stream.isFavorited ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(stream.isFavorited ? .red : .white)
                        
                        Text("Favorite")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Share
                Button(action: {
                    shareStream()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Share")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Chat (if supported)
                if stream.platform.supportsChat {
                    Button(action: {
                        // Show chat
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "message")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Chat")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                }
                
                // Picture in Picture
                if stream.canPlayPictureInPicture {
                    Button(action: {
                        togglePictureInPicture()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "pip")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("PiP")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading stream...")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Error View
    private var errorView: some View {
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
            
            Button(action: {
                retryStream()
            }) {
                Text("Retry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Buffering View
    private var bufferingView: some View {
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
    
    // MARK: - Actions
    private func setupPlayer() {
        selectedQuality = stream.quality
        volume = stream.volume
        isMuted = stream.isMuted
        
        playerManager.setupPlayer(for: stream)
        
        // Start auto-hide timer
        startControlsTimer()
    }
    
    private func cleanup() {
        controlsTimer?.invalidate()
        playerManager.cleanup()
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingControls.toggle()
        }
        
        if showingControls {
            startControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls = false
            }
        }
    }
    
    private func togglePlayback() {
        if playbackState == .playing {
            playerManager.pause()
        } else {
            playerManager.play()
        }
    }
    
    private func toggleMute() {
        isMuted.toggle()
        playerManager.setMuted(isMuted)
    }
    
    private func toggleFullScreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullScreen.toggle()
        }
    }
    
    private func exitFullScreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullScreen = false
        }
    }
    
    private func togglePictureInPicture() {
        playerManager.togglePictureInPicture()
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
    
    private func retryStream() {
        hasError = false
        errorMessage = ""
        playerManager.retry()
    }
    
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        let threshold: CGFloat = 100
        
        if value.translation.x > threshold {
            // Swipe right - go back
            if !isFullScreen {
                dismiss()
            }
        } else if value.translation.x < -threshold {
            // Swipe left - next action
        } else if value.translation.y > threshold {
            // Swipe down - exit fullscreen or dismiss
            if isFullScreen {
                exitFullScreen()
            } else {
                dismiss()
            }
        } else if value.translation.y < -threshold {
            // Swipe up - enter fullscreen
            if !isFullScreen {
                toggleFullScreen()
            }
        }
    }
}

// MARK: - Platform-Specific Player Views
struct TwitchPlayerView: UIViewRepresentable {
    let stream: Stream
    let playerManager: StreamPlayerManager
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let embedURL = stream.embedURL,
              let url = URL(string: embedURL) else { return }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: TwitchPlayerView
        
        init(_ parent: TwitchPlayerView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.playerManager.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.playerManager.hasError = true
            parent.playerManager.errorMessage = error.localizedDescription
        }
    }
}

struct YouTubePlayerView: UIViewRepresentable {
    let stream: Stream
    let playerManager: StreamPlayerManager
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let embedURL = stream.embedURL,
              let url = URL(string: embedURL) else { return }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: YouTubePlayerView
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.playerManager.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.playerManager.hasError = true
            parent.playerManager.errorMessage = error.localizedDescription
        }
    }
}

struct KickPlayerView: UIViewRepresentable {
    let stream: Stream
    let playerManager: StreamPlayerManager
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let embedURL = stream.embedURL,
              let url = URL(string: embedURL) else { return }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: KickPlayerView
        
        init(_ parent: KickPlayerView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.playerManager.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.playerManager.hasError = true
            parent.playerManager.errorMessage = error.localizedDescription
        }
    }
}

struct GenericWebPlayerView: UIViewRepresentable {
    let stream: Stream
    let playerManager: StreamPlayerManager
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: stream.url) else { return }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: GenericWebPlayerView
        
        init(_ parent: GenericWebPlayerView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.playerManager.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.playerManager.hasError = true
            parent.playerManager.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Stream Player Manager
@MainActor
class StreamPlayerManager: ObservableObject {
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var isBuffering = false
    @Published var playbackState: StreamPlayerView.PlaybackState = .stopped
    
    private var currentStream: Stream?
    
    func setupPlayer(for stream: Stream) {
        currentStream = stream
        isLoading = true
        hasError = false
        errorMessage = ""
        
        // Initialize player based on platform
        // This would contain platform-specific setup logic
    }
    
    func play() {
        playbackState = .playing
        // Platform-specific play implementation
    }
    
    func pause() {
        playbackState = .paused
        // Platform-specific pause implementation
    }
    
    func stop() {
        playbackState = .stopped
        // Platform-specific stop implementation
    }
    
    func setVolume(_ volume: Double) {
        // Platform-specific volume control
    }
    
    func setMuted(_ muted: Bool) {
        // Platform-specific mute control
    }
    
    func rewind() {
        // Platform-specific rewind implementation
    }
    
    func fastForward() {
        // Platform-specific fast forward implementation
    }
    
    func togglePictureInPicture() {
        // Platform-specific PiP implementation
    }
    
    func retry() {
        guard let stream = currentStream else { return }
        setupPlayer(for: stream)
    }
    
    func cleanup() {
        currentStream = nil
        playbackState = .stopped
    }
}

#Preview {
    StreamPlayerView(
        stream: Stream(
            url: "https://www.twitch.tv/example",
            title: "Example Stream"
        )
    )
}