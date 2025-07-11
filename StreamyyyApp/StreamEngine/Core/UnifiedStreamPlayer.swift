//
//  UnifiedStreamPlayer.swift
//  StreamyyyApp
//
//  SwiftUI component that wraps the UnifiedStreamPlayerEngine
//  This is the main interface for embedding stream players in the app
//  Created by Claude Code on 2025-07-11
//

import SwiftUI
import WebKit

/// Main SwiftUI component for displaying stream players
/// Replaces all existing player components with a single, reliable solution
public struct UnifiedStreamPlayer: View {
    
    // MARK: - Properties
    let stream: Stream
    @Binding var isPresented: Bool
    
    // Configuration
    let enableControls: Bool
    let enablePictureInPicture: Bool
    let enableChat: Bool
    let autoplay: Bool
    
    // State
    @StateObject private var engine = UnifiedStreamPlayerEngine()
    @State private var showControls = true
    @State private var isFullscreen = false
    @State private var showSettings = false
    @State private var controlsTimer: Timer?
    @State private var showAdaptiveQualityIndicator = false
    @State private var adaptiveQualityMessage = ""
    @State private var networkQuality: String = "Unknown"
    
    // MARK: - Initialization
    public init(
        stream: Stream,
        isPresented: Binding<Bool>,
        enableControls: Bool = true,
        enablePictureInPicture: Bool = true,
        enableChat: Bool = false,
        autoplay: Bool = true
    ) {
        self.stream = stream
        self._isPresented = isPresented
        self.enableControls = enableControls
        self.enablePictureInPicture = enablePictureInPicture
        self.enableChat = enableChat
        self.autoplay = autoplay
    }
    
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
                
                // Player content
                playerContent
                
                // Footer
                if !isFullscreen && enableControls {
                    playerControls
                        .opacity(showControls ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showControls)
                }
            }
            
            // Loading overlay
            if engine.isLoading {
                loadingOverlay
            }
            
            // Error overlay
            if engine.hasError {
                errorOverlay
            }
            
            // Settings sheet
            if showSettings {
                settingsOverlay
            }
            
            // Adaptive quality indicator
            if showAdaptiveQualityIndicator {
                adaptiveQualityIndicator
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(isFullscreen)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
        .onTapGesture {
            if enableControls {
                toggleControls()
            }
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
            // Back button
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            // Stream info
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.displayTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let streamerName = stream.streamerName {
                    HStack(spacing: 8) {
                        Text(streamerName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Live indicator
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
            }
            
            Spacer()
            
            // Platform badge
            HStack(spacing: 4) {
                Image(systemName: stream.platform.icon)
                    .font(.caption)
                Text(stream.platform.displayName)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stream.platform.color.opacity(0.8))
            .cornerRadius(8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var playerContent: some View {
        ZStack {
            // WebView container
            if let webView = engine.getWebView() {
                WebViewRepresentable(webView: webView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .cornerRadius(isFullscreen ? 0 : 8)
            } else {
                // Placeholder while initializing
                Rectangle()
                    .fill(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(isFullscreen ? 0 : 8)
            }
            
            // Buffering indicator
            if engine.isBuffering {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Buffering...")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
            }
            
            // Stream health indicator
            VStack {
                HStack {
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: engine.streamHealth.icon)
                            .font(.caption)
                            .foregroundColor(engine.streamHealth.color)
                        
                        if engine.viewerCount > 0 {
                            Text(stream.formattedViewerCount)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                    .opacity(showControls ? 1 : 0.3)
                }
                .padding()
                
                Spacer()
            }
        }
        .aspectRatio(isFullscreen ? nil : 16/9, contentMode: .fit)
    }
    
    private var playerControls: some View {
        VStack(spacing: 16) {
            // Playback controls
            HStack(spacing: 24) {
                // Play/Pause
                Button(action: {
                    if engine.playbackState == .playing {
                        engine.pause()
                    } else {
                        engine.resume()
                    }
                }) {
                    Image(systemName: engine.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .disabled(engine.playbackState == .loading || engine.playbackState == .error)
                
                Spacer()
                
                // Mute toggle
                Button(action: {
                    engine.setMuted(!engine.isMuted)
                }) {
                    Image(systemName: engine.isMuted ? "speaker.slash.fill" : "speaker.2.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Volume slider
                Slider(value: Binding(
                    get: { engine.volume },
                    set: { engine.setVolume($0) }
                ), in: 0...1)
                .frame(width: 80)
                .accentColor(.white)
                
                // Quality selector
                Button(action: {
                    showSettings.toggle()
                }) {
                    Text(engine.currentQuality.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                
                // Fullscreen toggle
                Button(action: {
                    toggleFullscreen()
                }) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Picture in Picture (if supported)
                if enablePictureInPicture && stream.canPlayPictureInPicture {
                    Button(action: {
                        // Implement PiP
                    }) {
                        Image(systemName: "pip")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
            
            // Additional stream info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let category = stream.category, !category.isEmpty {
                        Text("Category: \(category)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if stream.viewerCount > 0 {
                        Text("\(stream.formattedViewerCount) viewers")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    // Favorite
                    Button(action: {
                        // Toggle favorite
                    }) {
                        Image(systemName: stream.isFavorited ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundColor(stream.isFavorited ? .red : .white)
                    }
                    
                    // Share
                    Button(action: {
                        shareStream()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    // Open in browser
                    Button(action: {
                        openInBrowser()
                    }) {
                        Image(systemName: "safari")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
                
                // Retry button after a delay
                if engine.isLoading {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top)
                }
            }
        }
        .transition(.opacity)
    }
    
    private var errorOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Stream Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(engine.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button(action: {
                        engine.retry()
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
                    
                    HStack(spacing: 16) {
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
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Close")
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
        }
        .transition(.opacity)
    }
    
    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .onTapGesture {
                    showSettings = false
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Stream Settings")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Done") {
                            showSettings = false
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Network Information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Network Status")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal)
                        
                        HStack {
                            Text("Quality:")
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(networkQuality)
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("Stream Health:")
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(engine.streamHealth.color)
                                    .frame(width: 8, height: 8)
                                Text(engine.streamHealth.description)
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Quality selection
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Quality")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            if engine.currentQuality == .auto {
                                Text("Auto Adaptive")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal)
                        
                        ForEach(stream.availableQualities, id: \.self) { quality in
                            Button(action: {
                                engine.setQuality(quality, isAdaptive: false)
                                showSettings = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(quality.displayName)
                                            .foregroundColor(.white)
                                        
                                        if quality != .auto {
                                            Text("~\(String(format: "%.1f", quality.bitrateRequirement)) Mbps")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.6))
                                        } else {
                                            Text("Adapts to network conditions")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if quality == engine.currentQuality {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.bottom)
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
            }
        }
    }
    
    // MARK: - Methods
    
    private func setupPlayer() {
        // Configure engine callbacks
        engine.onStreamReady = {
            print("✅ Stream ready callback")
        }
        
        engine.onStreamError = { error in
            print("❌ Stream error callback: \(error)")
        }
        
        engine.onQualityChanged = { quality in
            print("🎥 Quality changed to: \(quality)")
        }
        
        engine.onViewerCountUpdate = { count in
            print("👀 Viewer count: \(count)")
        }
        
        engine.onAdaptiveQualityChange = { [weak self] fromQuality, toQuality in
            Task { @MainActor in
                self?.handleAdaptiveQualityChange(from: fromQuality, to: toQuality)
            }
        }
        
        engine.onNetworkQualityChanged = { [weak self] quality in
            Task { @MainActor in
                self?.handleNetworkQualityChange(quality)
            }
        }
        
        // Load the stream
        engine.loadStream(stream)
        
        // Start controls timer
        if enableControls {
            startControlsTimer()
        }
    }
    
    private func cleanup() {
        controlsTimer?.invalidate()
        engine.cleanup()
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
    
    private func toggleFullscreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen.toggle()
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
    
    // MARK: - Adaptive Quality Handlers
    
    private func handleAdaptiveQualityChange(from fromQuality: StreamQuality, to toQuality: StreamQuality) {
        let isUpgrade = toQuality.bitrateRequirement > fromQuality.bitrateRequirement
        let arrow = isUpgrade ? "↑" : "↓"
        let action = isUpgrade ? "Upgraded" : "Downgraded"
        
        adaptiveQualityMessage = "\(arrow) \(action) to \(toQuality.displayName)"
        showAdaptiveQualityIndicator = true
        
        // Hide indicator after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                self.showAdaptiveQualityIndicator = false
            }
        }
        
        print("🔄 Adaptive quality change: \(fromQuality.displayName) → \(toQuality.displayName)")
    }
    
    private func handleNetworkQualityChange(_ quality: NetworkQuality) {
        switch quality {
        case .excellent:
            networkQuality = "Excellent"
        case .good:
            networkQuality = "Good"
        case .fair:
            networkQuality = "Fair"
        case .poor:
            networkQuality = "Poor"
        case .degraded(let dropRate):
            networkQuality = "Degraded (\(Int(dropRate * 100))% drops)"
        case .unknown:
            networkQuality = "Unknown"
        }
        
        print("📶 Network quality changed to: \(networkQuality)")
    }
    
    private var adaptiveQualityIndicator: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Text(adaptiveQualityMessage)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .shadow(radius: 4)
                
                Spacer()
            }
            
            Spacer()
                .frame(height: 100) // Position above controls
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showAdaptiveQualityIndicator)
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
    UnifiedStreamPlayer(
        stream: Stream(
            url: "https://www.twitch.tv/shroud",
            platform: .twitch,
            title: "Shroud Gaming"
        ),
        isPresented: .constant(true)
    )
}