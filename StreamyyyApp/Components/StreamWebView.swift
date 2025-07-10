//
//  StreamWebView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI
import WebKit
import AVKit
import Network
import Combine
import CoreHaptics

struct StreamWebView: UIViewRepresentable {
    let url: String
    let isMuted: Bool
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var currentQuality: StreamQuality
    @Binding var isLive: Bool
    @Binding var viewerCount: Int
    
    // Advanced configuration
    let gesturesEnabled: Bool
    let pictureInPictureEnabled: Bool
    let performanceMonitoringEnabled: Bool
    
    // Performance monitoring
    @StateObject private var performanceMonitor = StreamPerformanceMonitor()
    @StateObject private var networkMonitor = NetworkQualityMonitor()
    @StateObject private var gestureController = StreamGestureController()
    
    init(
        url: String,
        isMuted: Bool,
        isLoading: Binding<Bool>,
        hasError: Binding<Bool>,
        currentQuality: Binding<StreamQuality> = .constant(.auto),
        isLive: Binding<Bool> = .constant(false),
        viewerCount: Binding<Int> = .constant(0),
        gesturesEnabled: Bool = true,
        pictureInPictureEnabled: Bool = true,
        performanceMonitoringEnabled: Bool = true
    ) {
        self.url = url
        self.isMuted = isMuted
        self._isLoading = isLoading
        self._hasError = hasError
        self._currentQuality = currentQuality
        self._isLive = isLive
        self._viewerCount = viewerCount
        self.gesturesEnabled = gesturesEnabled
        self.pictureInPictureEnabled = pictureInPictureEnabled
        self.performanceMonitoringEnabled = performanceMonitoringEnabled
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = createEnhancedWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Configure WebView
        setupEnhancedWebView(webView, context: context)
        
        // Start monitoring if enabled
        if performanceMonitoringEnabled {
            performanceMonitor.startMonitoring(for: webView)
            networkMonitor.startMonitoring()
        }
        
        // Setup gesture controller
        if gesturesEnabled {
            gestureController.setupGestures(for: webView, coordinator: context.coordinator)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let embedURL = getEmbedURL(from: url)
        
        if let currentURL = webView.url?.absoluteString,
           currentURL != embedURL {
            loadStream(in: webView, url: embedURL)
        }
        
        // Handle mute state
        if isMuted {
            muteWebView(webView)
        } else {
            unmuteWebView(webView)
        }
        
        // Update performance monitoring
        if performanceMonitoringEnabled {
            performanceMonitor.updateMetrics()
        }
        
        // Update gesture controller
        if gesturesEnabled {
            gestureController.updateConfiguration(webView: webView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Enhanced Configuration Methods
    
    private func createEnhancedWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Media playback configuration
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Picture-in-picture support
        if #available(iOS 14.0, *) && pictureInPictureEnabled {
            configuration.allowsPictureInPictureMediaPlayback = true
        }
        
        // Enable AirPlay
        configuration.allowsAirPlayForMediaPlayback = true
        
        // Performance optimizations
        configuration.processPool = SharedWebViewProcessPool.shared
        
        // User script for enhanced functionality
        let userScript = WKUserScript(
            source: getEnhancedStreamScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(userScript)
        
        // Message handlers
        configuration.userContentController.add(
            WeakScriptMessageHandler(target: self),
            name: "streamHandler"
        )
        
        return configuration
    }
    
    private func setupEnhancedWebView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Appearance
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Performance optimizations
        webView.configuration.preferences.javaScriptEnabled = true
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // iPhone 16 Pro specific optimizations
        if #available(iOS 16.0, *) {
            setupiPhone16ProOptimizations(webView)
        }
        
        // Disable user selection and context menu
        webView.evaluateJavaScript("""
            document.addEventListener('selectstart', function(e) {
                e.preventDefault();
            });
            document.addEventListener('contextmenu', function(e) {
                e.preventDefault();
            });
            
            // Prevent zoom
            document.addEventListener('gesturestart', function(e) {
                e.preventDefault();
            });
            
            document.addEventListener('gesturechange', function(e) {
                e.preventDefault();
            });
            
            document.addEventListener('gestureend', function(e) {
                e.preventDefault();
            });
        """)
    }
    
    private func setupiPhone16ProOptimizations(_ webView: WKWebView) {
        // ProMotion display optimization
        if let displayLink = webView.layer.displayLink {
            displayLink.preferredFramesPerSecond = 120
        }
        
        // HDR support
        if #available(iOS 17.0, *) {
            webView.configuration.preferences.isElementFullscreenEnabled = true
        }
        
        // Metal performance optimization
        webView.layer.drawsAsynchronously = true
        webView.layer.shouldRasterize = false
    }
    
    private func getEnhancedStreamScript() -> String {
        return """
            // Enhanced stream integration script
            (function() {
                // Performance monitoring
                let performanceData = {
                    loadTime: 0,
                    bufferHealth: 0,
                    droppedFrames: 0,
                    bitrate: 0
                };
                
                // Monitor video element
                function monitorVideo() {
                    const video = document.querySelector('video');
                    if (video) {
                        // Track buffer health
                        video.addEventListener('progress', function() {
                            if (video.buffered.length > 0) {
                                const buffered = video.buffered.end(0);
                                const current = video.currentTime;
                                performanceData.bufferHealth = buffered - current;
                            }
                        });
                        
                        // Track quality changes
                        video.addEventListener('loadedmetadata', function() {
                            performanceData.bitrate = video.videoWidth * video.videoHeight;
                            
                            window.webkit.messageHandlers.streamHandler.postMessage({
                                type: 'qualityUpdate',
                                width: video.videoWidth,
                                height: video.videoHeight,
                                bitrate: performanceData.bitrate
                            });
                        });
                        
                        // Track playback events
                        video.addEventListener('play', function() {
                            window.webkit.messageHandlers.streamHandler.postMessage({
                                type: 'playbackStart'
                            });
                        });
                        
                        video.addEventListener('pause', function() {
                            window.webkit.messageHandlers.streamHandler.postMessage({
                                type: 'playbackPause'
                            });
                        });
                        
                        video.addEventListener('waiting', function() {
                            window.webkit.messageHandlers.streamHandler.postMessage({
                                type: 'buffering'
                            });
                        });
                        
                        video.addEventListener('canplay', function() {
                            window.webkit.messageHandlers.streamHandler.postMessage({
                                type: 'ready'
                            });
                        });
                    }
                }
                
                // Enhanced CSS for better mobile experience
                const style = document.createElement('style');
                style.innerHTML = `
                    body {
                        margin: 0;
                        padding: 0;
                        overflow: hidden;
                        background: black;
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    }
                    
                    video {
                        width: 100% !important;
                        height: 100% !important;
                        object-fit: cover;
                        background: black;
                    }
                    
                    iframe {
                        width: 100% !important;
                        height: 100% !important;
                        border: none;
                        background: black;
                    }
                    
                    /* Hide platform-specific UI elements */
                    .player-controls,
                    .player-overlay,
                    .top-nav,
                    .channel-info-bar,
                    .ytp-chrome-top,
                    .ytp-chrome-bottom,
                    .ytp-watermark,
                    .kick-player-controls {
                        display: none !important;
                    }
                    
                    /* Prevent user interaction */
                    * {
                        -webkit-user-select: none;
                        -webkit-touch-callout: none;
                        -webkit-tap-highlight-color: transparent;
                        user-select: none;
                    }
                    
                    /* Loading indicator */
                    .loading-overlay {
                        position: absolute;
                        top: 50%;
                        left: 50%;
                        transform: translate(-50%, -50%);
                        color: white;
                        font-size: 16px;
                        z-index: 9999;
                    }
                    
                    /* Quality indicator */
                    .quality-indicator {
                        position: absolute;
                        top: 10px;
                        right: 10px;
                        background: rgba(0, 0, 0, 0.7);
                        color: white;
                        padding: 4px 8px;
                        border-radius: 4px;
                        font-size: 12px;
                        z-index: 1000;
                    }
                `;
                document.head.appendChild(style);
                
                // Start monitoring
                monitorVideo();
                
                // Retry monitoring if video not found initially
                setTimeout(function() {
                    if (!document.querySelector('video')) {
                        monitorVideo();
                    }
                }, 1000);
                
                // Report initialization
                window.webkit.messageHandlers.streamHandler.postMessage({
                    type: 'initialized',
                    timestamp: Date.now()
                });
            })();
        """
    }
    
    private func loadStream(in webView: WKWebView, url: String) {
        guard let streamURL = URL(string: url) else {
            hasError = true
            return
        }
        
        isLoading = true
        hasError = false
        
        let request = URLRequest(url: streamURL)
        webView.load(request)
    }
    
    private func getEmbedURL(from originalURL: String) -> String {
        // Convert regular URLs to embed URLs
        if originalURL.contains("twitch.tv") {
            return getTwitchEmbedURL(from: originalURL)
        } else if originalURL.contains("youtube.com") || originalURL.contains("youtu.be") {
            return getYouTubeEmbedURL(from: originalURL)
        } else if originalURL.contains("kick.com") {
            return getKickEmbedURL(from: originalURL)
        } else {
            return originalURL
        }
    }
    
    private func getTwitchEmbedURL(from url: String) -> String {
        // Extract channel name from Twitch URL
        let components = url.components(separatedBy: "/")
        guard let channelName = components.last else { return url }
        
        return "https://player.twitch.tv/?channel=\(channelName)&parent=localhost&autoplay=true&muted=false"
    }
    
    private func getYouTubeEmbedURL(from url: String) -> String {
        var videoId = ""
        
        if url.contains("youtu.be/") {
            // Short URL format
            let components = url.components(separatedBy: "/")
            videoId = components.last?.components(separatedBy: "?").first ?? ""
        } else if url.contains("youtube.com/watch") {
            // Regular URL format
            if let urlComponents = URLComponents(string: url),
               let queryItems = urlComponents.queryItems,
               let vParam = queryItems.first(where: { $0.name == "v" }) {
                videoId = vParam.value ?? ""
            }
        } else if url.contains("youtube.com/live/") {
            // Live stream format
            let components = url.components(separatedBy: "/")
            videoId = components.last ?? ""
        }
        
        guard !videoId.isEmpty else { return url }
        
        return "https://www.youtube.com/embed/\(videoId)?autoplay=1&mute=0&controls=1&rel=0&modestbranding=1"
    }
    
    private func getKickEmbedURL(from url: String) -> String {
        // Extract channel name from Kick URL
        let components = url.components(separatedBy: "/")
        guard let channelName = components.last else { return url }
        
        return "https://player.kick.com/\(channelName)"
    }
    
    private func muteWebView(_ webView: WKWebView) {
        // Mute Twitch
        webView.evaluateJavaScript("""
            if (window.location.hostname.includes('twitch.tv')) {
                const video = document.querySelector('video');
                if (video) {
                    video.muted = true;
                    video.volume = 0;
                }
            }
        """)
        
        // Mute YouTube
        webView.evaluateJavaScript("""
            if (window.location.hostname.includes('youtube.com')) {
                const iframe = document.querySelector('iframe');
                if (iframe && iframe.contentWindow) {
                    iframe.contentWindow.postMessage('{"event":"command","func":"mute","args":""}', '*');
                }
            }
        """)
    }
    
    private func unmuteWebView(_ webView: WKWebView) {
        // Unmute Twitch
        webView.evaluateJavaScript("""
            if (window.location.hostname.includes('twitch.tv')) {
                const video = document.querySelector('video');
                if (video) {
                    video.muted = false;
                    video.volume = 1;
                }
            }
        """)
        
        // Unmute YouTube
        webView.evaluateJavaScript("""
            if (window.location.hostname.includes('youtube.com')) {
                const iframe = document.querySelector('iframe');
                if (iframe && iframe.contentWindow) {
                    iframe.contentWindow.postMessage('{"event":"command","func":"unMute","args":""}', '*');
                }
            }
        """)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: StreamWebView
        
        init(_ parent: StreamWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.hasError = false
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            
            // Inject custom CSS for better mobile experience
            let css = """
                body {
                    margin: 0;
                    padding: 0;
                    overflow: hidden;
                    background: black;
                }
                
                video {
                    width: 100% !important;
                    height: 100% !important;
                    object-fit: cover;
                }
                
                iframe {
                    width: 100% !important;
                    height: 100% !important;
                    border: none;
                }
                
                /* Hide Twitch UI elements */
                .player-controls,
                .player-overlay,
                .top-nav,
                .channel-info-bar {
                    display: none !important;
                }
                
                /* Hide YouTube UI elements */
                .ytp-chrome-top,
                .ytp-chrome-bottom,
                .ytp-watermark {
                    display: none !important;
                }
            """
            
            let script = """
                var style = document.createElement('style');
                style.innerHTML = `\(css)`;
                document.head.appendChild(style);
                
                // Remove scroll bars
                document.body.style.overflow = 'hidden';
                
                // Prevent zoom
                document.addEventListener('gesturestart', function(e) {
                    e.preventDefault();
                });
                
                document.addEventListener('gesturechange', function(e) {
                    e.preventDefault();
                });
                
                document.addEventListener('gestureend', function(e) {
                    e.preventDefault();
                });
            """
            
            webView.evaluateJavaScript(script)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow navigation to embed URLs
            if let url = navigationAction.request.url {
                let urlString = url.absoluteString
                
                if urlString.contains("player.twitch.tv") ||
                   urlString.contains("youtube.com/embed") ||
                   urlString.contains("player.kick.com") {
                    decisionHandler(.allow)
                    return
                }
                
                // Block external navigation
                if navigationAction.navigationType == .linkActivated {
                    decisionHandler(.cancel)
                    return
                }
            }
            
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            hapticFeedback.impactOccurred()
            
            // Toggle fullscreen or picture-in-picture
            if let webView = gesture.view as? WKWebView {
                let script = """
                    const video = document.querySelector('video');
                    if (video) {
                        if (document.fullscreenElement) {
                            document.exitFullscreen();
                        } else {
                            video.requestFullscreen();
                        }
                    }
                """
                webView.evaluateJavaScript(script)
            }
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            // Prevent zoom for video streams
            gesture.view?.transform = CGAffineTransform.identity
        }
        
        @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
            hapticFeedback.impactOccurred()
            
            guard let webView = gesture.view as? WKWebView else { return }
            
            switch gesture.direction {
            case .left:
                // Seek forward
                let script = """
                    const video = document.querySelector('video');
                    if (video && !video.seeking) {
                        video.currentTime = Math.min(video.currentTime + 10, video.duration);
                    }
                """
                webView.evaluateJavaScript(script)
                
            case .right:
                // Seek backward
                let script = """
                    const video = document.querySelector('video');
                    if (video && !video.seeking) {
                        video.currentTime = Math.max(video.currentTime - 10, 0);
                    }
                """
                webView.evaluateJavaScript(script)
                
            case .up:
                // Increase volume
                let script = """
                    const video = document.querySelector('video');
                    if (video) {
                        video.volume = Math.min(video.volume + 0.1, 1.0);
                    }
                """
                webView.evaluateJavaScript(script)
                
            case .down:
                // Decrease volume
                let script = """
                    const video = document.querySelector('video');
                    if (video) {
                        video.volume = Math.max(video.volume - 0.1, 0.0);
                    }
                """
                webView.evaluateJavaScript(script)
                
            default:
                break
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                hapticFeedback.impactOccurred()
                
                // Show stream info or controls
                if let webView = gesture.view as? WKWebView {
                    let script = """
                        const video = document.querySelector('video');
                        if (video) {
                            window.webkit.messageHandlers.streamHandler.postMessage({
                                type: 'streamInfo',
                                currentTime: video.currentTime,
                                duration: video.duration,
                                volume: video.volume,
                                muted: video.muted,
                                paused: video.paused,
                                width: video.videoWidth,
                                height: video.videoHeight
                            });
                        }
                    """
                    webView.evaluateJavaScript(script)
                }
            }
        }
    }
}

// MARK: - Stream Gesture Controller

class StreamGestureController: ObservableObject {
    private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    func setupGestures(for webView: WKWebView, coordinator: StreamWebView.Coordinator) {
        // Double tap for fullscreen
        let doubleTapGesture = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(StreamWebView.Coordinator.handleDoubleTap(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        webView.addGestureRecognizer(doubleTapGesture)
        
        // Pinch gesture (disabled for streams)
        let pinchGesture = UIPinchGestureRecognizer(
            target: coordinator,
            action: #selector(StreamWebView.Coordinator.handlePinch(_:))
        )
        webView.addGestureRecognizer(pinchGesture)
        
        // Swipe gestures for stream control
        let swipeLeft = UISwipeGestureRecognizer(
            target: coordinator,
            action: #selector(StreamWebView.Coordinator.handleSwipe(_:))
        )
        swipeLeft.direction = .left
        webView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(
            target: coordinator,
            action: #selector(StreamWebView.Coordinator.handleSwipe(_:))
        )
        swipeRight.direction = .right
        webView.addGestureRecognizer(swipeRight)
        
        let swipeUp = UISwipeGestureRecognizer(
            target: coordinator,
            action: #selector(StreamWebView.Coordinator.handleSwipe(_:))
        )
        swipeUp.direction = .up
        webView.addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(
            target: coordinator,
            action: #selector(StreamWebView.Coordinator.handleSwipe(_:))
        )
        swipeDown.direction = .down
        webView.addGestureRecognizer(swipeDown)
        
        // Long press for stream info
        let longPressGesture = UILongPressGestureRecognizer(
            target: coordinator,
            action: #selector(StreamWebView.Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        webView.addGestureRecognizer(longPressGesture)
    }
    
    func updateConfiguration(webView: WKWebView) {
        // Update gesture configuration if needed
        hapticFeedback.prepare()
    }
}

// MARK: - Stream Error View
struct StreamErrorView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Failed to Load Stream")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("There was an error loading this stream. Please check your connection and try again.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

// MARK: - Stream Loading View
struct StreamLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
            Text("Loading Stream...")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text("Please wait while we connect to the stream")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Enhanced Stream Container View
struct EnhancedStreamContainerView: View {
    let stream: StreamModel
    @State private var isLoading = false
    @State private var hasError = false
    @State private var isMuted = false
    @State private var currentQuality = StreamQuality.auto
    @State private var isLive = false
    @State private var viewerCount = 0
    @State private var showControls = false
    
    var body: some View {
        ZStack {
            Color.black
            
            if hasError {
                StreamErrorView {
                    hasError = false
                    isLoading = true
                }
            } else if isLoading {
                StreamLoadingView()
            } else {
                StreamWebView(
                    url: stream.url,
                    isMuted: isMuted,
                    isLoading: $isLoading,
                    hasError: $hasError,
                    currentQuality: $currentQuality,
                    isLive: $isLive,
                    viewerCount: $viewerCount
                )
            }
            
            // Enhanced Controls Overlay
            if showControls {
                VStack {
                    HStack {
                        // Live indicator
                        if isLive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Quality indicator
                        Text(currentQuality.displayName)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        
                        // Mute button
                        Button(action: { isMuted.toggle() }) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Viewer count
                    if viewerCount > 0 {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("\(viewerCount)")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(.bottom)
                    }
                }
                .transition(.opacity)
            }
        }
        .cornerRadius(12)
        .clipped()
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls.toggle()
            }
            
            // Auto-hide controls after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = false
                }
            }
        }
    }
}

// MARK: - Stream Container View (Legacy)
struct StreamContainerView: View {
    let stream: StreamModel
    @State private var isLoading = false
    @State private var hasError = false
    @State private var isMuted = false
    @State private var currentQuality = StreamQuality.auto
    @State private var isLive = false
    @State private var viewerCount = 0
    
    var body: some View {
        ZStack {
            Color.black
            
            if hasError {
                StreamErrorView {
                    hasError = false
                    isLoading = true
                }
            } else if isLoading {
                StreamLoadingView()
            } else {
                StreamWebView(
                    url: stream.url,
                    isMuted: isMuted,
                    isLoading: $isLoading,
                    hasError: $hasError,
                    currentQuality: $currentQuality,
                    isLive: $isLive,
                    viewerCount: $viewerCount
                )
            }
            
            // Mute Button Overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isMuted.toggle() }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .cornerRadius(12)
        .clipped()
    }
}

#Preview {
    EnhancedStreamContainerView(
        stream: StreamModel(
            id: "1",
            url: "https://twitch.tv/shroud",
            type: .twitch
        )
    )
    .frame(height: 200)
    .padding()
}