//
//  UnifiedStreamWebView.swift
//  StreamyyyApp
//
//  Unified WebView component for all streaming platforms
//  Created by Claude Code on 2025-07-09
//

import SwiftUI
import WebKit
import Combine

/// Unified WebView for all streaming platforms with proper lifecycle management
public struct UnifiedStreamWebView: UIViewRepresentable {
    
    // MARK: - Properties
    let stream: Stream
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var errorMessage: String
    @Binding var isBuffering: Bool
    @Binding var playbackState: StreamPlaybackState
    
    // Configuration
    let isMuted: Bool
    let volume: Double
    let quality: StreamQuality
    let enableChat: Bool
    let enableControls: Bool
    
    // Callbacks
    let onPlaybackStateChanged: ((StreamPlaybackState) -> Void)?
    let onVideoInfoChanged: ((VideoInfo) -> Void)?
    let onError: ((StreamError) -> Void)?
    
    // MARK: - Initialization
    public init(
        stream: Stream,
        isLoading: Binding<Bool>,
        hasError: Binding<Bool>,
        errorMessage: Binding<String>,
        isBuffering: Binding<Bool>,
        playbackState: Binding<StreamPlaybackState>,
        isMuted: Bool = false,
        volume: Double = 1.0,
        quality: StreamQuality = .auto,
        enableChat: Bool = false,
        enableControls: Bool = false,
        onPlaybackStateChanged: ((StreamPlaybackState) -> Void)? = nil,
        onVideoInfoChanged: ((VideoInfo) -> Void)? = nil,
        onError: ((StreamError) -> Void)? = nil
    ) {
        self.stream = stream
        self._isLoading = isLoading
        self._hasError = hasError
        self._errorMessage = errorMessage
        self._isBuffering = isBuffering
        self._playbackState = playbackState
        self.isMuted = isMuted
        self.volume = volume
        self.quality = quality
        self.enableChat = enableChat
        self.enableControls = enableControls
        self.onPlaybackStateChanged = onPlaybackStateChanged
        self.onVideoInfoChanged = onVideoInfoChanged
        self.onError = onError
    }
    
    // MARK: - UIViewRepresentable
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = SharedWebViewProcessPool.shared.createWebViewConfiguration(for: stream.platform)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Configure WebView
        setupWebView(webView, context: context)
        
        // Register with process pool
        SharedWebViewProcessPool.shared.registerWebView(webView, for: stream.id)
        
        // Setup observers
        setupObservers(for: webView, context: context)
        
        return webView
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Generate embed URL
        guard let embedURL = generateEmbedURL() else {
            hasError = true
            errorMessage = "Failed to generate embed URL"
            return
        }
        
        // Check if we need to reload
        if let currentURL = webView.url?.absoluteString,
           currentURL != embedURL {
            loadStream(webView, url: embedURL)
        }
        
        // Update playback settings
        updatePlaybackSettings(webView)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Setup Methods
    private func setupWebView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Appearance
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Gestures
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        
        // Performance
        webView.configuration.suppressesIncrementalRendering = false
        
        // Security
        webView.configuration.preferences.fraudulentWebsiteWarningEnabled = true
    }
    
    private func setupObservers(for webView: WKWebView, context: Context) {
        // Observe stream events
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleStreamEvent(_:)),
            name: .streamEventMessage,
            object: nil
        )
        
        // Observe control messages
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleControlMessage(_:)),
            name: .streamControlMessage,
            object: nil
        )
        
        // Observe analytics
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleAnalyticsMessage(_:)),
            name: .streamAnalyticsMessage,
            object: nil
        )
    }
    
    private func generateEmbedURL() -> String? {
        guard let identifier = stream.platform.extractStreamIdentifier(from: stream.url) else {
            print("❌ Failed to extract stream identifier from URL: \(stream.url)")
            return nil
        }
        
        let embedOptions = EmbedOptions(
            autoplay: true,
            muted: isMuted,
            showControls: enableControls,
            chatEnabled: enableChat,
            quality: quality,
            parentDomain: Config.Platforms.Twitch.parentDomain
        )
        
        guard let embedURL = stream.platform.generateEmbedURL(for: identifier, options: embedOptions) else {
            print("❌ Failed to generate embed URL for platform: \(stream.platform.displayName)")
            return nil
        }
        
        print("✅ Generated embed URL: \(embedURL)")
        return embedURL
    }
    
    private func loadStream(_ webView: WKWebView, url: String) {
        guard let streamURL = URL(string: url) else {
            print("❌ Invalid stream URL: \(url)")
            hasError = true
            errorMessage = "Invalid stream URL"
            playbackState = .error
            return
        }
        
        print("🔄 Loading stream URL: \(streamURL)")
        isLoading = true
        hasError = false
        errorMessage = ""
        playbackState = .loading
        
        var request = URLRequest(url: streamURL)
        request.setValue("StreamyyyApp/1.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue("streamyyy.com", forHTTPHeaderField: "Referer")
        
        // Add platform-specific headers
        switch stream.platform {
        case .twitch:
            request.setValue("streamyyy.com", forHTTPHeaderField: "Origin")
        case .youtube:
            request.setValue("https://youtube.com", forHTTPHeaderField: "Origin")
        default:
            break
        }
        
        webView.load(request)
        
        // Set a timeout for loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            if self.isLoading {
                print("⏰ Stream loading timeout")
                self.hasError = true
                self.errorMessage = "Stream loading timed out"
                self.playbackState = .error
                self.isLoading = false
            }
        }
    }
    
    private func updatePlaybackSettings(_ webView: WKWebView) {
        // Update mute state
        webView.evaluateJavaScript("""
            if (window.StreamyyyControl) {
                if (\(isMuted)) {
                    window.StreamyyyControl.mute();
                } else {
                    window.StreamyyyControl.unmute();
                }
                window.StreamyyyControl.setVolume(\(volume));
            }
        """)
    }
    
    // MARK: - Coordinator
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: UnifiedStreamWebView
        
        init(_ parent: UnifiedStreamWebView) {
            self.parent = parent
        }
        
        // MARK: - WKNavigationDelegate
        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.hasError = false
            parent.playbackState = .loading
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
            parent.isLoading = false
            parent.hasError = false
            parent.playbackState = .ready
            
            // Inject additional scripts if needed
            injectPlatformSpecificScripts(webView)
            
            // Verify the stream is actually working
            verifyStreamHealth(webView)
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView navigation failed: \(error.localizedDescription)")
            parent.isLoading = false
            parent.hasError = true
            parent.errorMessage = "Failed to load stream: \(error.localizedDescription)"
            parent.playbackState = .error
            
            parent.onError?(StreamError.connectionFailed)
            
            // Attempt retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.attemptRetry(webView)
            }
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
            parent.isLoading = false
            parent.hasError = true
            parent.errorMessage = "Failed to connect to stream: \(error.localizedDescription)"
            parent.playbackState = .error
            
            parent.onError?(StreamError.connectionFailed)
            
            // Attempt retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.attemptRetry(webView)
            }
        }
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            let urlString = url.absoluteString
            
            // Allow navigation to embed URLs
            if isAllowedURL(urlString) {
                decisionHandler(.allow)
            } else if navigationAction.navigationType == .linkActivated {
                // Handle external links
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
        
        // MARK: - WKUIDelegate
        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Don't allow creating new windows
            return nil
        }
        
        public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Handle JavaScript alerts
            completionHandler()
        }
        
        // MARK: - Event Handlers
        @objc func handleStreamEvent(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let type = userInfo["type"] as? String else { return }
            
            switch type {
            case "playback_started":
                parent.playbackState = .playing
                parent.onPlaybackStateChanged?(.playing)
                
            case "playback_paused":
                parent.playbackState = .paused
                parent.onPlaybackStateChanged?(.paused)
                
            case "playback_ended":
                parent.playbackState = .ended
                parent.onPlaybackStateChanged?(.ended)
                
            case "buffering":
                parent.isBuffering = true
                parent.playbackState = .buffering
                parent.onPlaybackStateChanged?(.buffering)
                
            case "ready":
                parent.isBuffering = false
                parent.playbackState = .ready
                parent.onPlaybackStateChanged?(.ready)
                
            case "error":
                parent.hasError = true
                parent.errorMessage = userInfo["message"] as? String ?? "Unknown error"
                parent.playbackState = .error
                parent.onError?(StreamError.unknown(NSError(domain: "StreamError", code: -1)))
                
            default:
                break
            }
        }
        
        @objc func handleControlMessage(_ notification: Notification) {
            guard let userInfo = notification.userInfo else { return }
            
            if let videoInfo = parseVideoInfo(userInfo) {
                parent.onVideoInfoChanged?(videoInfo)
            }
        }
        
        @objc func handleAnalyticsMessage(_ notification: Notification) {
            // Handle analytics events
            // This can be extended to track user interactions
        }
        
        // MARK: - Helper Methods
        private func isAllowedURL(_ url: String) -> Bool {
            let allowedDomains = [
                "player.twitch.tv",
                "youtube.com",
                "youtu.be",
                "player.kick.com",
                "kick.com",
                "dlive.tv",
                "trovo.live",
                "nimo.tv",
                "bigo.tv"
            ]
            
            return allowedDomains.contains { url.contains($0) }
        }
        
        private func verifyStreamHealth(_ webView: WKWebView) {
            // Check if video elements are present and healthy
            webView.evaluateJavaScript("""
                (function() {
                    const videos = document.querySelectorAll('video');
                    const iframes = document.querySelectorAll('iframe');
                    
                    return {
                        hasVideo: videos.length > 0,
                        hasIframe: iframes.length > 0,
                        videoCount: videos.length,
                        iframeCount: iframes.length,
                        pageTitle: document.title,
                        url: window.location.href
                    };
                })();
            """) { result, error in
                if let error = error {
                    print("❌ Stream health check failed: \(error.localizedDescription)")
                    return
                }
                
                if let result = result as? [String: Any] {
                    print("🔍 Stream health check result: \(result)")
                    
                    let hasVideo = result["hasVideo"] as? Bool ?? false
                    let hasIframe = result["hasIframe"] as? Bool ?? false
                    
                    if !hasVideo && !hasIframe {
                        print("⚠️ No video or iframe elements found")
                        // Stream may not be working properly
                        DispatchQueue.main.async {
                            self.parent.playbackState = .error
                            self.parent.hasError = true
                            self.parent.errorMessage = "Stream player not found"
                        }
                    } else {
                        print("✅ Stream appears healthy")
                        DispatchQueue.main.async {
                            self.parent.playbackState = .ready
                        }
                    }
                }
            }
        }
        
        private func attemptRetry(_ webView: WKWebView) {
            // Only retry if we haven't exceeded max attempts
            let maxRetries = 3
            let currentRetries = parent.stream.connectionAttempts
            
            if currentRetries < maxRetries {
                print("🔄 Attempting retry \(currentRetries + 1)/\(maxRetries)")
                
                // Generate a new embed URL
                if let embedURL = parent.generateEmbedURL() {
                    parent.loadStream(webView, url: embedURL)
                } else {
                    print("❌ Failed to generate embed URL for retry")
                }
            } else {
                print("❌ Max retries exceeded")
                parent.hasError = true
                parent.errorMessage = "Stream failed to load after \(maxRetries) attempts"
                parent.playbackState = .error
            }
        }
        
        private func injectPlatformSpecificScripts(_ webView: WKWebView) {
            // Platform-specific enhancements
            let script = """
                // Monitor video element for quality changes
                const videos = document.querySelectorAll('video');
                videos.forEach(video => {
                    if (!video.hasAttribute('data-streamyyy-monitored')) {
                        video.setAttribute('data-streamyyy-monitored', 'true');
                        
                        video.addEventListener('loadedmetadata', function() {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                                window.webkit.messageHandlers.streamEvents.postMessage({
                                    type: 'video_loaded',
                                    width: video.videoWidth,
                                    height: video.videoHeight,
                                    duration: video.duration
                                });
                            }
                        });
                        
                        video.addEventListener('timeupdate', function() {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamControl) {
                                window.webkit.messageHandlers.streamControl.postMessage({
                                    type: 'time_update',
                                    currentTime: video.currentTime,
                                    duration: video.duration,
                                    buffered: video.buffered.length > 0 ? video.buffered.end(0) : 0
                                });
                            }
                        });
                    }
                });
            """
            
            webView.evaluateJavaScript(script)
        }
        
        private func parseVideoInfo(_ userInfo: [String: Any]) -> VideoInfo? {
            guard let type = userInfo["type"] as? String,
                  type == "time_update" else { return nil }
            
            return VideoInfo(
                currentTime: userInfo["currentTime"] as? Double ?? 0,
                duration: userInfo["duration"] as? Double ?? 0,
                buffered: userInfo["buffered"] as? Double ?? 0
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Supporting Types

/// Stream playback state
public enum StreamPlaybackState: String, CaseIterable {
    case idle = "idle"
    case loading = "loading"
    case ready = "ready"
    case playing = "playing"
    case paused = "paused"
    case buffering = "buffering"
    case ended = "ended"
    case error = "error"
    
    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .loading: return "Loading"
        case .ready: return "Ready"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .buffering: return "Buffering"
        case .ended: return "Ended"
        case .error: return "Error"
        }
    }
    
    public var color: Color {
        switch self {
        case .idle: return .gray
        case .loading: return .orange
        case .ready: return .blue
        case .playing: return .green
        case .paused: return .yellow
        case .buffering: return .orange
        case .ended: return .gray
        case .error: return .red
        }
    }
}

/// Video information
public struct VideoInfo {
    public let currentTime: Double
    public let duration: Double
    public let buffered: Double
    
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    public var bufferHealth: Double {
        return buffered - currentTime
    }
}

/// Stream error types
public enum StreamError: Error {
    case invalidURL
    case connectionFailed
    case loadFailed
    case playbackFailed
    case unknown(Error)
}

// MARK: - Extension for SwiftUI Preview
extension UnifiedStreamWebView {
    static func preview() -> UnifiedStreamWebView {
        let stream = Stream(
            url: "https://www.twitch.tv/shroud",
            platform: .twitch,
            title: "Preview Stream"
        )
        
        return UnifiedStreamWebView(
            stream: stream,
            isLoading: .constant(false),
            hasError: .constant(false),
            errorMessage: .constant(""),
            isBuffering: .constant(false),
            playbackState: .constant(.ready)
        )
    }
}