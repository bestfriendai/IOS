//
//  MultiStreamManager.swift
//  StreamyyyApp
//
//  Core multi-stream viewing manager with working video players
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

// MARK: - Multi Stream Manager
class MultiStreamManager: ObservableObject {
    @Published var activeStreams: [StreamSlot] = []
    @Published var currentLayout: MultiStreamLayout = .single
    @Published var focusedStream: StreamSlot?
    @Published var isLoading = false
    
    private var players: [String: AVPlayer] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupInitialLayout()
    }
    
    func setupInitialLayout() {
        // Start with empty slots based on layout
        updateLayout(currentLayout)
    }
    
    func updateLayout(_ layout: MultiStreamLayout) {
        currentLayout = layout
        let slotCount = layout.maxStreams
        
        // Preserve existing streams, add empty slots as needed
        while activeStreams.count < slotCount {
            activeStreams.append(StreamSlot(position: activeStreams.count))
        }
        
        // Remove extra slots if downsizing
        if activeStreams.count > slotCount {
            let removedSlots = Array(activeStreams[slotCount...])
            activeStreams = Array(activeStreams[0..<slotCount])
            
            // Clean up removed players
            for slot in removedSlots {
                if let streamId = slot.stream?.id {
                    players[streamId]?.pause()
                    players.removeValue(forKey: streamId)
                }
            }
        }
    }
    
    func addStream(_ stream: TwitchStream, to slotIndex: Int) {
        guard slotIndex < activeStreams.count else { return }
        
        // Remove previous stream from this slot
        if let previousStream = activeStreams[slotIndex].stream {
            players[previousStream.id]?.pause()
            players.removeValue(forKey: previousStream.id)
        }
        
        // Add new stream
        activeStreams[slotIndex].stream = stream
        activeStreams[slotIndex].isLoading = true
        
        // Create player for new stream
        createPlayer(for: stream, slotIndex: slotIndex)
    }
    
    func removeStream(from slotIndex: Int) {
        guard slotIndex < activeStreams.count else { return }
        
        if let stream = activeStreams[slotIndex].stream {
            players[stream.id]?.pause()
            players.removeValue(forKey: stream.id)
        }
        
        activeStreams[slotIndex].stream = nil
        activeStreams[slotIndex].isLoading = false
        activeStreams[slotIndex].hasError = false
    }
    
    func focusOnStream(at slotIndex: Int) {
        guard slotIndex < activeStreams.count,
              activeStreams[slotIndex].stream != nil else { return }
        
        focusedStream = activeStreams[slotIndex]
    }
    
    func clearFocus() {
        focusedStream = nil
    }
    
    private func createPlayer(for stream: TwitchStream, slotIndex: Int) {
        // Try to get HLS stream URL
        getStreamURL(for: stream) { [weak self] url in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let url = url {
                    let player = AVPlayer(url: url)
                    self.players[stream.id] = player
                    
                    // Configure player for optimal streaming
                    player.automaticallyWaitsToMinimizeStalling = false
                    player.preventsDisplaySleepDuringVideoPlayback = true
                    
                    // Start playback
                    player.play()
                    
                    self.activeStreams[slotIndex].isLoading = false
                    self.activeStreams[slotIndex].hasError = false
                } else {
                    // Fallback to WebView-based player
                    self.activeStreams[slotIndex].isLoading = false
                    self.activeStreams[slotIndex].useWebPlayer = true
                }
            }
        }
    }
    
    private func getStreamURL(for stream: TwitchStream, completion: @escaping (URL?) -> Void) {
        // Try to extract HLS URL from Twitch
        // This is a simplified version - in production you'd use Twitch's API
        
        // For now, we'll use a working approach with direct channel URLs
        let channelURL = "https://www.twitch.tv/\(stream.userLogin)"
        
        // Use a background task to try to extract the real stream URL
        Task {
            do {
                // This would be replaced with actual HLS URL extraction
                // For now, return nil to fall back to WebView
                completion(nil)
            } catch {
                completion(nil)
            }
        }
    }
    
    func getPlayer(for streamId: String) -> AVPlayer? {
        return players[streamId]
    }
    
    func pauseAll() {
        players.values.forEach { $0.pause() }
    }
    
    func resumeAll() {
        players.values.forEach { $0.play() }
    }
}

// MARK: - Stream Slot
struct StreamSlot: Identifiable {
    let id = UUID()
    let position: Int
    var stream: TwitchStream?
    var isLoading = false
    var hasError = false
    var useWebPlayer = false
    
    var isEmpty: Bool {
        return stream == nil
    }
}

// MARK: - Multi Stream Layout
enum MultiStreamLayout: String, CaseIterable, Identifiable {
    case single = "1x1"
    case twoByTwo = "2x2"
    case threeByThree = "3x3"
    case fourByFour = "4x4"
    case oneByThree = "1x3"
    case threeByOne = "3x1"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .single: return "Single"
        case .twoByTwo: return "2×2 Grid"
        case .threeByThree: return "3×3 Grid"
        case .fourByFour: return "4×4 Grid"
        case .oneByThree: return "1×3 Vertical"
        case .threeByOne: return "3×1 Horizontal"
        }
    }
    
    var maxStreams: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 4
        case .threeByThree: return 9
        case .fourByFour: return 16
        case .oneByThree: return 3
        case .threeByOne: return 3
        }
    }
    
    var columns: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 2
        case .threeByThree: return 3
        case .fourByFour: return 4
        case .oneByThree: return 1
        case .threeByOne: return 3
        }
    }
    
    var rows: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 2
        case .threeByThree: return 3
        case .fourByFour: return 4
        case .oneByThree: return 3
        case .threeByOne: return 1
        }
    }
    
    var icon: String {
        switch self {
        case .single: return "square"
        case .twoByTwo: return "grid"
        case .threeByThree: return "square.grid.3x3"
        case .fourByFour: return "square.grid.4x4"
        case .oneByThree: return "rectangle.grid.1x2"
        case .threeByOne: return "rectangle.grid.2x1"
        }
    }
}

// MARK: - Working Stream Player View
struct WorkingStreamPlayer: View {
    let stream: TwitchStream
    let streamManager: MultiStreamManager
    let isCompact: Bool
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var useWebView = false
    @State private var showControls = false
    
    var body: some View {
        ZStack {
            Color.black
            
            if isLoading {
                LoadingPlayerView(isCompact: isCompact)
            } else if useWebView {
                WorkingStreamWebView(
                    channelName: stream.userLogin,
                    isCompact: isCompact
                )
            } else if let player = player {
                VideoPlayerView(player: player)
            } else {
                ErrorPlayerView(
                    stream: stream,
                    isCompact: isCompact,
                    onRetry: {
                        loadStream()
                    }
                )
            }
            
            // Stream info overlay
            if !isCompact || showControls {
                VStack {
                    Spacer()
                    
                    StreamInfoOverlay(
                        stream: stream,
                        isCompact: isCompact
                    )
                }
            }
        }
        .onAppear {
            loadStream()
        }
        .onTapGesture {
            if isCompact {
                withAnimation {
                    showControls.toggle()
                }
            }
        }
    }
    
    private func loadStream() {
        isLoading = true
        
        // Try to get the actual player from the manager
        if let existingPlayer = streamManager.getPlayer(for: stream.id) {
            self.player = existingPlayer
            self.isLoading = false
        } else {
            // Fall back to WebView player
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.useWebView = true
                self.isLoading = false
            }
        }
    }
}

// MARK: - Working Stream WebView
struct WorkingStreamWebView: UIViewRepresentable {
    let channelName: String
    let isCompact: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false // Disable PiP in multi-view
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        // Load optimized player URL
        let playerURL = createOptimizedPlayerURL()
        if let url = URL(string: playerURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createOptimizedPlayerURL() -> String {
        // Use Twitch player embed with optimizations for multi-stream
        var components = URLComponents()
        components.scheme = "https"
        components.host = "player.twitch.tv"
        components.path = "/"
        
        components.queryItems = [
            URLQueryItem(name: "channel", value: channelName),
            URLQueryItem(name: "parent", value: "localhost"),
            URLQueryItem(name: "autoplay", value: "true"),
            URLQueryItem(name: "muted", value: isCompact ? "true" : "false"), // Mute in multi-view
            URLQueryItem(name: "controls", value: "false"), // Hide controls in compact view
            URLQueryItem(name: "playsinline", value: "true"),
            URLQueryItem(name: "allowfullscreen", value: "false"), // Disable fullscreen in multi-view
            URLQueryItem(name: "time", value: "0s")
        ]
        
        return components.url?.absoluteString ?? "https://player.twitch.tv/?channel=\(channelName)&parent=localhost&autoplay=true&muted=\(isCompact)&playsinline=true"
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WorkingStreamWebView
        
        init(_ parent: WorkingStreamWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Optimize for multi-stream viewing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                webView.evaluateJavaScript("""
                    // Remove all unnecessary UI elements for multi-stream
                    const selectors = [
                        '[data-a-target="consent-banner"]',
                        '.consent-banner',
                        '[class*="chat"]',
                        '[class*="sidebar"]',
                        '[class*="recommendations"]',
                        '.tw-full-height'
                    ];
                    
                    selectors.forEach(selector => {
                        document.querySelectorAll(selector).forEach(el => el.remove());
                    });
                    
                    // Force video to fill container
                    const videos = document.getElementsByTagName('video');
                    for (let video of videos) {
                        video.style.width = '100%';
                        video.style.height = '100%';
                        video.style.objectFit = 'cover';
                        video.muted = \(parent.isCompact);
                        video.play().catch(e => console.log('Multi-stream autoplay prevented'));
                    }
                    
                    // Hide player UI in compact mode
                    if (\(parent.isCompact)) {
                        document.querySelectorAll('[class*="player-controls"]').forEach(el => {
                            el.style.display = 'none';
                        });
                    }
                """)
            }
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        
        let view = UIView()
        view.layer.addSublayer(playerLayer)
        
        // Store layer reference for layout updates
        context.coordinator.playerLayer = playerLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Supporting Views
struct LoadingPlayerView: View {
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 8 : 16) {
            ProgressView()
                .scaleEffect(isCompact ? 1.0 : 1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            if !isCompact {
                Text("Loading Stream...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
    }
}

struct ErrorPlayerView: View {
    let stream: TwitchStream
    let isCompact: Bool
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: isCompact ? 4 : 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: isCompact ? 20 : 30))
                .foregroundColor(.red)
            
            if !isCompact {
                Text("Stream Error")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

struct StreamInfoOverlay: View {
    let stream: TwitchStream
    let isCompact: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if !isCompact {
                    Text(stream.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Text(stream.userName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                
                if !isCompact && !stream.gameName.isEmpty {
                    Text(stream.gameName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: isCompact ? 4 : 6, height: isCompact ? 4 : 6)
                
                Text(stream.formattedViewerCount)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Import fix
import WebKit