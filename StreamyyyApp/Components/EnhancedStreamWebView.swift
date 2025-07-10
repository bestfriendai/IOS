//
//  EnhancedStreamWebView.swift
//  StreamyyyApp
//
//  Quality-optimized StreamWebView with advanced performance monitoring
//

import SwiftUI
import WebKit
import AVKit
import Network
import Combine
import CoreHaptics

struct EnhancedStreamWebView: UIViewRepresentable {
    let url: String
    let platform: Platform
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
    let qualityControlEnabled: Bool
    
    // Quality service integration
    @StateObject private var qualityService = QualityService.shared
    @StateObject private var gestureController = StreamGestureController()
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(
        url: String,
        platform: Platform,
        isMuted: Bool,
        isLoading: Binding<Bool>,
        hasError: Binding<Bool>,
        currentQuality: Binding<StreamQuality> = .constant(.auto),
        isLive: Binding<Bool> = .constant(false),
        viewerCount: Binding<Int> = .constant(0),
        gesturesEnabled: Bool = true,
        pictureInPictureEnabled: Bool = true,
        performanceMonitoringEnabled: Bool = true,
        qualityControlEnabled: Bool = true
    ) {
        self.url = url
        self.platform = platform
        self.isMuted = isMuted
        self._isLoading = isLoading
        self._hasError = hasError
        self._currentQuality = currentQuality
        self._isLive = isLive
        self._viewerCount = viewerCount
        self.gesturesEnabled = gesturesEnabled
        self.pictureInPictureEnabled = pictureInPictureEnabled
        self.performanceMonitoringEnabled = performanceMonitoringEnabled
        self.qualityControlEnabled = qualityControlEnabled
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = createEnhancedWebViewConfiguration(context: context)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Configure WebView
        setupEnhancedWebView(webView, context: context)
        
        // Configure quality service for this stream
        if qualityControlEnabled {
            qualityService.configureForStream(url: url, platform: platform)
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
        
        // Update quality based on service recommendations
        if qualityControlEnabled {
            updateQualityFromService()
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
    
    private func createEnhancedWebViewConfiguration(context: Context) -> WKWebViewConfiguration {
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
        
        // Message handlers for quality control
        configuration.userContentController.add(
            WeakScriptMessageHandler(target: context.coordinator),
            name: "streamHandler"
        )
        
        configuration.userContentController.add(
            WeakScriptMessageHandler(target: context.coordinator),
            name: "qualityHandler"
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
        
        // Setup quality service WebView reference
        if qualityControlEnabled {
            qualityService.healthDiagnostics.setWebView(webView)
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
            // Enhanced stream integration script with quality control
            (function() {
                let performanceData = {
                    loadTime: 0,
                    bufferHealth: 0,
                    droppedFrames: 0,
                    bitrate: 0,
                    currentQuality: 'auto',
                    availableQualities: []
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
                                
                                window.webkit.messageHandlers.streamHandler.postMessage({
                                    type: 'bufferHealth',
                                    value: performanceData.bufferHealth
                                });
                            }
                        });
                        
                        // Track quality changes
                        video.addEventListener('loadedmetadata', function() {
                            performanceData.bitrate = video.videoWidth * video.videoHeight;
                            
                            window.webkit.messageHandlers.qualityHandler.postMessage({
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
                        
                        // Track stalls and errors
                        video.addEventListener('stalled', function() {
                            window.webkit.messageHandlers.streamHandler.postMessage({
                                type: 'stalled'
                            });
                        });
                        
                        video.addEventListener('error', function() {
                            window.webkit.messageHandlers.streamHandler.postMessage({
                                type: 'error',
                                error: video.error ? video.error.code : 'unknown'
                            });
                        });
                        
                        // Performance monitoring
                        if (video.getVideoPlaybackQuality) {
                            setInterval(function() {
                                const quality = video.getVideoPlaybackQuality();
                                performanceData.droppedFrames = quality.droppedVideoFrames;
                                
                                window.webkit.messageHandlers.streamHandler.postMessage({
                                    type: 'performanceUpdate',
                                    droppedFrames: performanceData.droppedFrames,
                                    totalFrames: quality.totalVideoFrames,
                                    bufferHealth: performanceData.bufferHealth
                                });
                            }, 1000);
                        }
                    }
                }
                
                // Quality control functions
                function setQuality(quality) {
                    const video = document.querySelector('video');
                    if (video) {
                        // Platform-specific quality setting
                        if (window.location.hostname.includes('twitch.tv')) {
                            setTwitchQuality(quality);
                        } else if (window.location.hostname.includes('youtube.com')) {
                            setYouTubeQuality(quality);
                        }
                    }
                }
                
                function setTwitchQuality(quality) {
                    // Twitch quality setting logic
                    const qualityButton = document.querySelector('[data-a-target="player-settings-button"]');
                    if (qualityButton) {
                        qualityButton.click();
                        setTimeout(() => {
                            const qualityOption = document.querySelector(`[data-a-target="player-quality-option-${quality}"]`);
                            if (qualityOption) {
                                qualityOption.click();
                            }
                        }, 100);
                    }
                }
                
                function setYouTubeQuality(quality) {
                    // YouTube quality setting logic
                    const video = document.querySelector('video');
                    if (video && video.requestVideoFrameCallback) {
                        // Modern YouTube quality API
                        video.requestVideoFrameCallback(function() {
                            const player = document.querySelector('.html5-video-player');
                            if (player && player.setPlaybackQuality) {
                                player.setPlaybackQuality(quality);
                            }
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
                        transition: opacity 0.3s ease;
                    }
                    
                    /* Performance indicator */
                    .performance-indicator {
                        position: absolute;
                        top: 10px;
                        left: 10px;
                        background: rgba(0, 0, 0, 0.7);
                        color: white;
                        padding: 4px 8px;
                        border-radius: 4px;
                        font-size: 10px;
                        z-index: 1000;
                        opacity: 0;
                        transition: opacity 0.3s ease;
                    }
                    
                    .performance-indicator.visible {
                        opacity: 1;
                    }
                `;
                document.head.appendChild(style);
                
                // Add quality indicator
                const qualityIndicator = document.createElement('div');
                qualityIndicator.className = 'quality-indicator';
                qualityIndicator.textContent = 'AUTO';
                document.body.appendChild(qualityIndicator);
                
                // Add performance indicator
                const performanceIndicator = document.createElement('div');
                performanceIndicator.className = 'performance-indicator';
                performanceIndicator.textContent = 'Performance: Good';
                document.body.appendChild(performanceIndicator);
                
                // Global quality control
                window.setStreamQuality = setQuality;
                window.showPerformanceIndicator = function(show) {
                    if (show) {
                        performanceIndicator.classList.add('visible');
                    } else {
                        performanceIndicator.classList.remove('visible');
                    }
                };
                
                window.updateQualityIndicator = function(quality) {
                    qualityIndicator.textContent = quality.toUpperCase();
                };
                
                window.updatePerformanceIndicator = function(performance) {
                    performanceIndicator.textContent = `Performance: ${performance}`;
                };
                
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
    
    // MARK: - Quality Control Integration
    
    private func updateQualityFromService() {
        let serviceQuality = qualityService.currentQuality
        
        if serviceQuality != currentQuality {
            currentQuality = serviceQuality
            
            // Update quality in WebView
            updateWebViewQuality(serviceQuality)
        }
    }
    
    private func updateWebViewQuality(_ quality: StreamQuality) {
        // This will be implemented by the Coordinator
        NotificationCenter.default.post(
            name: .updateWebViewQuality,
            object: self,
            userInfo: ["quality": quality]
        )
    }
    
    // MARK: - URL Generation and Stream Loading
    
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
        // Use platform-specific embed URL generation
        if let embedURL = platform.generateEmbedURL(from: originalURL) {
            return embedURL
        }
        return originalURL
    }
    
    private func muteWebView(_ webView: WKWebView) {
        webView.evaluateJavaScript("""
            const video = document.querySelector('video');
            if (video) {
                video.muted = true;
                video.volume = 0;
            }
        """)
    }
    
    private func unmuteWebView(_ webView: WKWebView) {
        webView.evaluateJavaScript("""
            const video = document.querySelector('video');
            if (video) {
                video.muted = false;
                video.volume = 1;
            }
        """)
    }
    
    // MARK: - Coordinator Class
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: EnhancedStreamWebView
        
        init(_ parent: EnhancedStreamWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.hasError = false
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            
            // Initialize quality control
            let qualityScript = """
                if (window.updateQualityIndicator) {
                    window.updateQualityIndicator('\(parent.currentQuality.displayName)');
                }
                
                if (window.showPerformanceIndicator) {
                    window.showPerformanceIndicator(\(parent.performanceMonitoringEnabled));
                }
            """
            
            webView.evaluateJavaScript(qualityScript)
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
                
                if parent.platform.isValidEmbedURL(urlString) {
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
        
        // MARK: - Script Message Handler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            switch message.name {
            case "streamHandler":
                handleStreamMessage(body)
            case "qualityHandler":
                handleQualityMessage(body)
            default:
                break
            }
        }
        
        private func handleStreamMessage(_ message: [String: Any]) {
            guard let type = message["type"] as? String else { return }
            
            switch type {
            case "bufferHealth":
                if let bufferHealth = message["value"] as? Double {
                    parent.qualityService.performanceMonitor.updateBufferHealth(bufferHealth)
                }
                
            case "performanceUpdate":
                if let droppedFrames = message["droppedFrames"] as? Int,
                   let totalFrames = message["totalFrames"] as? Int {
                    let frameDropRate = Double(droppedFrames) / Double(totalFrames)
                    // Update performance metrics
                }
                
            case "error":
                parent.hasError = true
                
            case "ready":
                parent.isLoading = false
                
            case "stalled":
                // Handle stalled stream
                break
                
            default:
                break
            }
        }
        
        private func handleQualityMessage(_ message: [String: Any]) {
            guard let type = message["type"] as? String else { return }
            
            switch type {
            case "qualityUpdate":
                if let width = message["width"] as? Int,
                   let height = message["height"] as? Int {
                    // Update quality based on resolution
                    let detectedQuality = StreamQuality.fromResolution(width: width, height: height)
                    parent.currentQuality = detectedQuality
                }
                
            default:
                break
            }
        }
    }
}

// MARK: - Supporting Classes

class SharedWebViewProcessPool {
    static let shared = WKProcessPool()
}

class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    
    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - Platform Extensions

extension Platform {
    func generateEmbedURL(from originalURL: String) -> String? {
        guard let identifier = extractStreamIdentifier(from: originalURL) else { return nil }
        
        switch self {
        case .twitch:
            return "\(embedURL)?channel=\(identifier)&parent=streamyyy.com&autoplay=true"
        case .youtube:
            return "\(embedURL)/\(identifier)?autoplay=1&mute=0&controls=0&rel=0"
        case .kick:
            return "\(embedURL)/\(identifier)"
        default:
            return nil
        }
    }
    
    func isValidEmbedURL(_ url: String) -> Bool {
        let embedHosts = ["player.twitch.tv", "youtube.com", "player.kick.com"]
        return embedHosts.contains { url.contains($0) }
    }
}

// MARK: - StreamQuality Extensions

extension StreamQuality {
    static func fromResolution(width: Int, height: Int) -> StreamQuality {
        switch (width, height) {
        case (1920, 1080):
            return .hd1080
        case (1280, 720):
            return .hd720
        case (854, 480):
            return .medium
        case (640, 360):
            return .low
        case (284, 160):
            return .mobile
        default:
            return .auto
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let updateWebViewQuality = Notification.Name("updateWebViewQuality")
}