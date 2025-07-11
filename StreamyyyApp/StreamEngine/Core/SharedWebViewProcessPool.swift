//
//  SharedWebViewProcessPool.swift
//  StreamyyyApp
//
//  Enhanced shared WebView process pool for optimal performance and memory management
//  Manages multiple stream WebViews efficiently to prevent memory issues
//  Created by Claude Code on 2025-07-11
//

import Foundation
import WebKit
import Combine

/// Enhanced shared WebView process pool manager for optimal multi-stream performance
/// Handles process lifecycle, memory management, and performance monitoring
@MainActor
public final class SharedWebViewProcessPool: NSObject, ObservableObject {
    
    // MARK: - Singleton
    public static let shared = SharedWebViewProcessPool()
    
    // MARK: - Published Properties
    @Published public var activeWebViewCount = 0
    @Published public var memoryUsage: Int64 = 0
    @Published public var isMemoryWarning = false
    @Published public var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Properties
    public let processPool = WKProcessPool()
    private let dataStore = WKWebsiteDataStore.nonPersistent()
    private var activeWebViews: [String: WeakWebViewReference] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let maxWebViews = 8
    private let memoryWarningThreshold: Int64 = 256 * 1024 * 1024 // 256MB
    private let cleanupInterval: TimeInterval = 30 // 30 seconds
    
    // Monitoring
    private var cleanupTimer: Timer?
    private var memoryMonitorTimer: Timer?
    private var performanceTimer: Timer?
    
    // MARK: - Initialization
    private init() {
        self.processPool = WKProcessPool()
        self.userContentController = WKUserContentController()
        self.configuration = WKWebViewConfiguration()
        
        setupConfiguration()
        setupUserContentController()
        setupMemoryManagement()
    }
    
    // MARK: - Configuration
    private func setupConfiguration() {
        configuration.processPool = processPool
        configuration.userContentController = userContentController
        
        // Media playback configuration
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        
        // Picture-in-picture support
        if #available(iOS 14.0, *) {
            configuration.allowsPictureInPictureMediaPlayback = true
        }
        
        // Performance optimizations
        configuration.suppressesIncrementalRendering = false
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Security settings
        configuration.preferences.fraudulentWebsiteWarningEnabled = true
        
        // Data store configuration
        configuration.websiteDataStore = WKWebsiteDataStore.default()
    }
    
    private func setupUserContentController() {
        // Add JavaScript handlers for stream control
        userContentController.add(StreamMessageHandler.shared, name: "streamControl")
        userContentController.add(StreamMessageHandler.shared, name: "streamEvents")
        userContentController.add(StreamMessageHandler.shared, name: "streamAnalytics")
        
        // Add stream control scripts
        let streamControlScript = WKUserScript(
            source: getStreamControlScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(streamControlScript)
        
        // Add platform-specific scripts
        let platformScript = WKUserScript(
            source: getPlatformSpecificScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(platformScript)
    }
    
    private func setupMemoryManagement() {
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Setup periodic cleanup
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.cleanupDeadReferences()
        }
    }
    
    // MARK: - Public Methods
    
    /// Creates a new WebView configuration with shared process pool
    public func createWebViewConfiguration(for platform: Platform) -> WKWebViewConfiguration {
        let config = configuration.copy() as! WKWebViewConfiguration
        
        // Platform-specific configuration
        switch platform {
        case .twitch:
            setupTwitchConfiguration(config)
        case .youtube:
            setupYouTubeConfiguration(config)
        case .kick:
            setupKickConfiguration(config)
        default:
            setupGenericConfiguration(config)
        }
        
        return config
    }
    
    /// Registers a WebView with the process pool
    public func registerWebView(_ webView: WKWebView, for streamId: String) {
        queue.async {
            let reference = WeakWebViewReference(webView: webView, streamId: streamId)
            self.activeWebViews.insert(reference)
        }
    }
    
    /// Unregisters a WebView from the process pool
    public func unregisterWebView(_ webView: WKWebView) {
        queue.async {
            self.activeWebViews = self.activeWebViews.filter { $0.webView !== webView }
        }
    }
    
    /// Suspends all WebViews except the specified one
    public func suspendAllWebViewsExcept(_ activeWebView: WKWebView) {
        queue.async {
            for reference in self.activeWebViews {
                if let webView = reference.webView, webView !== activeWebView {
                    self.suspendWebView(webView)
                }
            }
        }
    }
    
    /// Resumes all suspended WebViews
    public func resumeAllWebViews() {
        queue.async {
            for reference in self.activeWebViews {
                if let webView = reference.webView {
                    self.resumeWebView(webView)
                }
            }
        }
    }
    
    /// Clears all website data
    public func clearAllWebsiteData() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast
        ) { }
    }
    
    /// Gets memory usage statistics
    public func getMemoryUsage() -> ProcessPoolMemoryUsage {
        let totalWebViews = activeWebViews.count
        let aliveWebViews = activeWebViews.compactMap { $0.webView }.count
        
        return ProcessPoolMemoryUsage(
            totalWebViews: totalWebViews,
            aliveWebViews: aliveWebViews,
            deadReferences: totalWebViews - aliveWebViews
        )
    }
    
    // MARK: - Private Methods
    
    private func setupTwitchConfiguration(_ config: WKWebViewConfiguration) {
        // Add Twitch-specific user agent
        config.applicationNameForUserAgent = "StreamyyyApp/1.0.0 TwitchPlayer"
        
        // Add Twitch-specific scripts
        let twitchScript = WKUserScript(
            source: getTwitchEnhancementScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(twitchScript)
    }
    
    private func setupYouTubeConfiguration(_ config: WKWebViewConfiguration) {
        // Add YouTube-specific user agent
        config.applicationNameForUserAgent = "StreamyyyApp/1.0.0 YouTubePlayer"
        
        // Add YouTube-specific scripts
        let youtubeScript = WKUserScript(
            source: getYouTubeEnhancementScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(youtubeScript)
    }
    
    private func setupKickConfiguration(_ config: WKWebViewConfiguration) {
        // Add Kick-specific user agent
        config.applicationNameForUserAgent = "StreamyyyApp/1.0.0 KickPlayer"
        
        // Add Kick-specific scripts
        let kickScript = WKUserScript(
            source: getKickEnhancementScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(kickScript)
    }
    
    private func setupGenericConfiguration(_ config: WKWebViewConfiguration) {
        // Add generic user agent
        config.applicationNameForUserAgent = "StreamyyyApp/1.0.0 GenericPlayer"
    }
    
    private func suspendWebView(_ webView: WKWebView) {
        print("😴 Suspending WebView: \(webView.url?.absoluteString ?? "unknown")")
        
        // Pause video playback and store state
        webView.evaluateJavaScript("""
            // Store current state and pause all videos
            const videos = document.querySelectorAll('video');
            videos.forEach(video => {
                if (!video.paused) {
                    video.pause();
                    video.dataset.wasPaused = 'false';
                    video.dataset.currentTime = video.currentTime.toString();
                } else {
                    video.dataset.wasPaused = 'true';
                }
            });
            
            // Clear any active timers
            if (window.streamyyyInterval) {
                clearInterval(window.streamyyyInterval);
                window.streamyyyInterval = null;
            }
            
            // Reduce animations
            document.body.style.animationPlayState = 'paused';
            
            // Notify about suspension
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                window.webkit.messageHandlers.streamEvents.postMessage({
                    type: 'webview_suspended',
                    timestamp: Date.now()
                });
            }
        """)
        
        // Set webView to be less visible to reduce GPU usage
        webView.alpha = 0.1
        webView.isUserInteractionEnabled = false
    }
    
    private func resumeWebView(_ webView: WKWebView) {
        print("🔄 Resuming WebView: \(webView.url?.absoluteString ?? "unknown")")
        
        // Restore webView visibility
        webView.alpha = 1.0
        webView.isUserInteractionEnabled = true
        
        // Resume video playback if it was playing before
        webView.evaluateJavaScript("""
            // Resume animations
            document.body.style.animationPlayState = 'running';
            
            // Resume video playback
            const videos = document.querySelectorAll('video');
            videos.forEach(video => {
                if (video.dataset.wasPaused === 'false') {
                    // Restore previous time position if available
                    if (video.dataset.currentTime) {
                        video.currentTime = parseFloat(video.dataset.currentTime);
                    }
                    
                    // Resume playback
                    video.play().catch(e => {
                        console.log('Could not resume video playback:', e);
                    });
                }
            });
            
            // Restart monitoring intervals
            if (window.StreamyyyControl && !window.streamyyyInterval) {
                window.streamyyyInterval = setInterval(() => {
                    // Periodic health checks
                    const video = document.querySelector('video');
                    if (video && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                        window.webkit.messageHandlers.streamEvents.postMessage({
                            type: 'periodic_health_check',
                            timestamp: Date.now(),
                            videoState: {
                                paused: video.paused,
                                readyState: video.readyState,
                                currentTime: video.currentTime
                            }
                        });
                    }
                }, 10000);
            }
            
            // Notify about resumption
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                window.webkit.messageHandlers.streamEvents.postMessage({
                    type: 'webview_resumed',
                    timestamp: Date.now()
                });
            }
        """)
    }
    
    private func cleanupDeadReferences() {
        activeWebViews = activeWebViews.filter { $0.webView != nil }
    }
    
    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning received, optimizing WebView usage")
        
        // Clear caches
        URLCache.shared.removeAllCachedResponses()
        
        // Cleanup dead references
        cleanupDeadReferences()
        
        // Clear website data
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(ofTypes: [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeWebSQLDatabases,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases
        ], modifiedSince: Date.distantPast) { }
        
        // Suspend inactive WebViews
        queue.async {
            var suspendedCount = 0
            for reference in self.activeWebViews {
                if let webView = reference.webView {
                    // Suspend WebViews that are not currently visible
                    if webView.superview == nil || webView.isHidden {
                        self.suspendWebView(webView)
                        suspendedCount += 1
                    }
                }
            }
            print("🔄 Suspended \(suspendedCount) WebViews due to memory pressure")
        }
        
        // Force garbage collection on process pool
        processPool.terminateNetworkProcess()
        
        // Clear user content controller scripts temporarily
        userContentController.removeAllUserScripts()
        
        // Re-add essential scripts after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupUserContentController()
        }
    }
    
    // MARK: - JavaScript Scripts
    
    private func getStreamControlScript() -> String {
        return """
        // Stream control utilities
        window.StreamyyyControl = {
            mute: function() {
                const videos = document.querySelectorAll('video');
                videos.forEach(video => {
                    video.muted = true;
                    video.volume = 0;
                });
            },
            
            unmute: function() {
                const videos = document.querySelectorAll('video');
                videos.forEach(video => {
                    video.muted = false;
                    video.volume = 1;
                });
            },
            
            setVolume: function(volume) {
                const videos = document.querySelectorAll('video');
                videos.forEach(video => {
                    video.volume = Math.max(0, Math.min(1, volume));
                });
            },
            
            pause: function() {
                const videos = document.querySelectorAll('video');
                videos.forEach(video => video.pause());
            },
            
            play: function() {
                const videos = document.querySelectorAll('video');
                videos.forEach(video => video.play());
            },
            
            getVideoInfo: function() {
                const video = document.querySelector('video');
                if (video) {
                    return {
                        currentTime: video.currentTime,
                        duration: video.duration,
                        paused: video.paused,
                        muted: video.muted,
                        volume: video.volume,
                        width: video.videoWidth,
                        height: video.videoHeight
                    };
                }
                return null;
            }
        };
        """
    }
    
    private func getPlatformSpecificScript() -> String {
        return """
        // Platform detection and optimization
        (function() {
            const hostname = window.location.hostname;
            
            // Common optimizations
            const style = document.createElement('style');
            style.innerHTML = `
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
                    background: black;
                }
                
                iframe {
                    width: 100% !important;
                    height: 100% !important;
                    border: none;
                    background: black;
                }
                
                * {
                    -webkit-user-select: none;
                    -webkit-touch-callout: none;
                    -webkit-tap-highlight-color: transparent;
                    user-select: none;
                }
            `;
            document.head.appendChild(style);
            
            // Report platform
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                window.webkit.messageHandlers.streamEvents.postMessage({
                    type: 'platform_detected',
                    platform: hostname
                });
            }
        })();
        """
    }
    
    private func getTwitchEnhancementScript() -> String {
        return """
        // Twitch-specific enhancements
        (function() {
            if (!window.location.hostname.includes('twitch.tv')) return;
            
            console.log('🎮 Twitch enhancement script loaded');
            
            // Hide Twitch UI elements for cleaner embedding
            const twitchStyle = document.createElement('style');
            twitchStyle.innerHTML = `
                .player-controls,
                .player-overlay,
                .top-nav,
                .channel-info-bar,
                .player-streaminfo,
                .player-extensions,
                .player-controls__left-control-group,
                .player-controls__right-control-group,
                .player-button,
                .player-seek,
                .player-volume,
                .player-fullscreen-button {
                    display: none !important;
                }
                
                /* Ensure video takes full space */
                video {
                    width: 100% !important;
                    height: 100% !important;
                    object-fit: cover !important;
                }
                
                /* Hide chat overlay */
                .right-column {
                    display: none !important;
                }
            `;
            document.head.appendChild(twitchStyle);
            
            // Enhanced video monitoring
            let videoCheckInterval;
            let lastVideoState = null;
            
            function initializeVideoMonitoring() {
                const video = document.querySelector('video');
                if (video && !video.hasAttribute('data-streamyyy-initialized')) {
                    video.setAttribute('data-streamyyy-initialized', 'true');
                    console.log('🎬 Twitch video element found and initialized');
                    
                    // Add comprehensive event listeners
                    const events = ['play', 'pause', 'ended', 'error', 'canplay', 'waiting', 'playing'];
                    events.forEach(eventType => {
                        video.addEventListener(eventType, function(e) {
                            console.log(`📺 Twitch video event: ${eventType}`);
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                                window.webkit.messageHandlers.streamEvents.postMessage({
                                    type: `playback_${eventType}`,
                                    platform: 'twitch',
                                    timestamp: Date.now(),
                                    videoState: {
                                        paused: video.paused,
                                        ended: video.ended,
                                        readyState: video.readyState,
                                        currentTime: video.currentTime,
                                        duration: video.duration
                                    }
                                });
                            }
                        });
                    });
                    
                    // Monitor video state changes
                    videoCheckInterval = setInterval(() => {
                        const currentState = {
                            paused: video.paused,
                            ended: video.ended,
                            readyState: video.readyState,
                            currentTime: video.currentTime,
                            duration: video.duration,
                            buffered: video.buffered.length > 0 ? video.buffered.end(0) : 0
                        };
                        
                        if (JSON.stringify(currentState) !== JSON.stringify(lastVideoState)) {
                            lastVideoState = currentState;
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                                window.webkit.messageHandlers.streamEvents.postMessage({
                                    type: 'video_state_change',
                                    platform: 'twitch',
                                    state: currentState
                                });
                            }
                        }
                    }, 1000);
                    
                    return true;
                }
                return false;
            }
            
            // Try to initialize immediately
            if (!initializeVideoMonitoring()) {
                // If not found, use MutationObserver to wait for video element
                const observer = new MutationObserver(function(mutations) {
                    if (initializeVideoMonitoring()) {
                        observer.disconnect();
                    }
                });
                
                observer.observe(document.body, { childList: true, subtree: true });
                
                // Fallback timeout
                setTimeout(() => {
                    observer.disconnect();
                    console.warn('⚠️ Twitch video element not found within timeout');
                }, 10000);
            }
            
            // Handle page visibility changes
            document.addEventListener('visibilitychange', function() {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                    window.webkit.messageHandlers.streamEvents.postMessage({
                        type: 'visibility_change',
                        platform: 'twitch',
                        visible: !document.hidden
                    });
                }
            });
            
            // Report successful initialization
            setTimeout(() => {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                    window.webkit.messageHandlers.streamEvents.postMessage({
                        type: 'twitch_ready',
                        platform: 'twitch'
                    });
                }
            }, 2000);
        })();
        """
    }
    
    private func getYouTubeEnhancementScript() -> String {
        return """
        // YouTube-specific enhancements
        (function() {
            if (!window.location.hostname.includes('youtube.com')) return;
            
            console.log('📺 YouTube enhancement script loaded');
            
            // Hide YouTube UI elements for cleaner embedding
            const youtubeStyle = document.createElement('style');
            youtubeStyle.innerHTML = `
                .ytp-chrome-top,
                .ytp-chrome-bottom,
                .ytp-watermark,
                .ytp-endscreen-overlay,
                .ytp-show-cards-title,
                .ytp-pause-overlay,
                .ytp-suggested-action,
                .ytp-videowall-still,
                .ytp-ce-video,
                .ytp-cards-teaser {
                    display: none !important;
                }
                
                /* Ensure video takes full space */
                video {
                    width: 100% !important;
                    height: 100% !important;
                    object-fit: cover !important;
                }
                
                /* Hide annotations */
                .annotation,
                .iv-click-target {
                    display: none !important;
                }
            `;
            document.head.appendChild(youtubeStyle);
            
            // Enhanced video monitoring for YouTube
            let videoCheckInterval;
            let lastVideoState = null;
            
            function initializeYouTubeMonitoring() {
                const video = document.querySelector('video');
                if (video && !video.hasAttribute('data-streamyyy-initialized')) {
                    video.setAttribute('data-streamyyy-initialized', 'true');
                    console.log('🎬 YouTube video element found and initialized');
                    
                    // Add comprehensive event listeners
                    const events = ['play', 'pause', 'ended', 'error', 'canplay', 'waiting', 'playing', 'loadstart', 'loadeddata'];
                    events.forEach(eventType => {
                        video.addEventListener(eventType, function(e) {
                            console.log(`📺 YouTube video event: ${eventType}`);
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                                window.webkit.messageHandlers.streamEvents.postMessage({
                                    type: `playback_${eventType}`,
                                    platform: 'youtube',
                                    timestamp: Date.now(),
                                    videoState: {
                                        paused: video.paused,
                                        ended: video.ended,
                                        readyState: video.readyState,
                                        currentTime: video.currentTime,
                                        duration: video.duration || 0,
                                        videoWidth: video.videoWidth,
                                        videoHeight: video.videoHeight
                                    }
                                });
                            }
                        });
                    });
                    
                    // Monitor video state changes for YouTube
                    videoCheckInterval = setInterval(() => {
                        const currentState = {
                            paused: video.paused,
                            ended: video.ended,
                            readyState: video.readyState,
                            currentTime: video.currentTime,
                            duration: video.duration || 0,
                            buffered: video.buffered.length > 0 ? video.buffered.end(0) : 0,
                            playbackRate: video.playbackRate
                        };
                        
                        if (JSON.stringify(currentState) !== JSON.stringify(lastVideoState)) {
                            lastVideoState = currentState;
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                                window.webkit.messageHandlers.streamEvents.postMessage({
                                    type: 'video_state_change',
                                    platform: 'youtube',
                                    state: currentState
                                });
                            }
                        }
                    }, 1000);
                    
                    return true;
                }
                return false;
            }
            
            // Try to initialize immediately
            if (!initializeYouTubeMonitoring()) {
                // If not found, use MutationObserver to wait for video element
                const observer = new MutationObserver(function(mutations) {
                    if (initializeYouTubeMonitoring()) {
                        observer.disconnect();
                    }
                });
                
                observer.observe(document.body, { childList: true, subtree: true });
                
                // Fallback timeout
                setTimeout(() => {
                    observer.disconnect();
                    console.warn('⚠️ YouTube video element not found within timeout');
                }, 10000);
            }
            
            // YouTube player API integration
            window.addEventListener('message', function(event) {
                if (event.data && event.data.event === 'video-progress') {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                        window.webkit.messageHandlers.streamEvents.postMessage({
                            type: 'playback_progress',
                            platform: 'youtube',
                            data: event.data
                        });
                    }
                }
            });
            
            // Report successful initialization
            setTimeout(() => {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                    window.webkit.messageHandlers.streamEvents.postMessage({
                        type: 'youtube_ready',
                        platform: 'youtube'
                    });
                }
            }, 2000);
        })();
        """
    }
    
    private func getKickEnhancementScript() -> String {
        return """
        // Kick-specific enhancements
        (function() {
            if (!window.location.hostname.includes('kick.com')) return;
            
            // Hide Kick UI elements
            const kickStyle = document.createElement('style');
            kickStyle.innerHTML = `
                .kick-player-controls,
                .kick-player-overlay,
                .kick-chat-overlay {
                    display: none !important;
                }
            `;
            document.head.appendChild(kickStyle);
            
            // Monitor Kick player
            const observer = new MutationObserver(function(mutations) {
                const video = document.querySelector('video');
                if (video && !video.hasAttribute('data-streamyyy-initialized')) {
                    video.setAttribute('data-streamyyy-initialized', 'true');
                    
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamEvents) {
                        window.webkit.messageHandlers.streamEvents.postMessage({
                            type: 'player_ready',
                            platform: 'kick'
                        });
                    }
                }
            });
            
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
    }
}

// MARK: - Supporting Types

/// Weak reference to a WebView
private class WeakWebViewReference: Hashable {
    weak var webView: WKWebView?
    let streamId: String
    
    init(webView: WKWebView, streamId: String) {
        self.webView = webView
        self.streamId = streamId
    }
    
    static func == (lhs: WeakWebViewReference, rhs: WeakWebViewReference) -> Bool {
        return lhs.streamId == rhs.streamId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(streamId)
    }
}

/// Memory usage statistics for the process pool
public struct ProcessPoolMemoryUsage {
    public let totalWebViews: Int
    public let aliveWebViews: Int
    public let deadReferences: Int
    
    public var healthPercentage: Double {
        guard totalWebViews > 0 else { return 100.0 }
        return Double(aliveWebViews) / Double(totalWebViews) * 100.0
    }
}

/// Message handler for stream events
public class StreamMessageHandler: NSObject, WKScriptMessageHandler {
    public static let shared = StreamMessageHandler()
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        
        switch message.name {
        case "streamControl":
            handleStreamControl(body)
        case "streamEvents":
            handleStreamEvents(body)
        case "streamAnalytics":
            handleStreamAnalytics(body)
        default:
            break
        }
    }
    
    private func handleStreamControl(_ body: [String: Any]) {
        // Handle stream control messages
        NotificationCenter.default.post(
            name: .streamControlMessage,
            object: nil,
            userInfo: body
        )
    }
    
    private func handleStreamEvents(_ body: [String: Any]) {
        // Handle stream events
        NotificationCenter.default.post(
            name: .streamEventMessage,
            object: nil,
            userInfo: body
        )
    }
    
    private func handleStreamAnalytics(_ body: [String: Any]) {
        // Handle analytics events
        NotificationCenter.default.post(
            name: .streamAnalyticsMessage,
            object: nil,
            userInfo: body
        )
    }
}

// MARK: - Supporting Types Added for Enhanced Implementation

public struct PerformanceMetrics {
    public let activeWebViews: Int
    public let memoryUsage: Int64
    public let averageLoadTime: TimeInterval
    public let errorRate: Double
    public let timestamp: Date
    
    public init(
        activeWebViews: Int = 0,
        memoryUsage: Int64 = 0,
        averageLoadTime: TimeInterval = 0,
        errorRate: Double = 0,
        timestamp: Date = Date()
    ) {
        self.activeWebViews = activeWebViews
        self.memoryUsage = memoryUsage
        self.averageLoadTime = averageLoadTime
        self.errorRate = errorRate
        self.timestamp = timestamp
    }
}

public enum OptimizationLevel: String, CaseIterable {
    case performance = "performance"
    case balanced = "balanced"
    case stability = "stability"
    case aggressive = "aggressive"
}

// MARK: - Enhanced Public Interface

extension SharedWebViewProcessPool {
    
    /// Create a configuration for a new WebView with optimal settings
    public func createOptimizedConfiguration(for streamId: String) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Use shared process pool for better memory management
        configuration.processPool = processPool
        configuration.websiteDataStore = dataStore
        
        // Essential media settings
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        
        // Performance optimizations
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Message handlers for communication
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "streamEvents")
        userContentController.add(self, name: "streamError")
        userContentController.add(self, name: "performanceMetrics")
        configuration.userContentController = userContentController
        
        // User agent for better compatibility
        configuration.applicationNameForUserAgent = "StreamyyyApp/1.0 Mobile Safari"
        
        print("⚙️ Created optimized WebView configuration for stream: \(streamId)")
        return configuration
    }
    
    /// Handle memory warning with enhanced cleanup
    public func handleMemoryWarning() {
        print("⚠️ Memory warning received - performing aggressive cleanup")
        
        isMemoryWarning = true
        
        // Clear caches and perform cleanup
        clearWebViewCaches()
        cleanupInactiveWebViews()
        
        // Reset warning flag after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.isMemoryWarning = false
        }
    }
    
    private func clearWebViewCaches() {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date.distantPast) {
            print("🧹 Cleared WebView caches")
        }
    }
}

// MARK: - WKScriptMessageHandler Extension for Enhanced Pool

extension SharedWebViewProcessPool: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let data = message.body as? [String: Any] else { return }
        
        switch message.name {
        case "performanceMetrics":
            processWebViewMetrics(data)
        case "streamEvents":
            handleStreamEvents(data)
        case "streamError":
            handleStreamError(data)
        default:
            break
        }
    }
    
    private func processWebViewMetrics(_ data: [String: Any]) {
        guard let streamId = data["streamId"] as? String,
              let memoryUsage = data["memoryUsage"] as? Int64 else { return }
        
        print("📊 Received metrics from \(streamId): Memory: \(memoryUsage) bytes")
    }
    
    private func handleStreamEvents(_ data: [String: Any]) {
        NotificationCenter.default.post(
            name: .streamEventMessage,
            object: nil,
            userInfo: data
        )
    }
    
    private func handleStreamError(_ data: [String: Any]) {
        print("❌ Stream error: \(data)")
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let streamControlMessage = Notification.Name("streamControlMessage")
    static let streamEventMessage = Notification.Name("streamEventMessage")
    static let streamAnalyticsMessage = Notification.Name("streamAnalyticsMessage")
    static let pauseBackgroundStreams = Notification.Name("pauseBackgroundStreams")
    static let optimizationLevelChanged = Notification.Name("optimizationLevelChanged")
}