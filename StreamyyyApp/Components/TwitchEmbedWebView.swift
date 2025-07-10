//
//  TwitchEmbedWebView.swift
//  StreamyyyApp
//
//  Advanced Twitch WebView with enhanced streaming features
//  Created by Streamyyy Team
//

import SwiftUI
import WebKit
import AVKit
import Network
import Combine

// MARK: - Twitch Embed WebView
public struct TwitchEmbedWebView: UIViewRepresentable {
    let channelName: String
    let chatEnabled: Bool
    let quality: String
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var isLive: Bool
    @Binding var viewerCount: Int
    @Binding var currentQuality: String
    
    // Advanced configuration
    let lowLatency: Bool
    let autoplay: Bool
    let muted: Bool
    let volume: Double
    let fullscreen: Bool
    
    // Performance monitoring
    @StateObject private var performanceMonitor = StreamPerformanceMonitor()
    @StateObject private var networkMonitor = NetworkQualityMonitor()
    
    public init(
        channelName: String,
        chatEnabled: Bool = true,
        quality: String = "auto",
        isLoading: Binding<Bool>,
        hasError: Binding<Bool>,
        isLive: Binding<Bool>,
        viewerCount: Binding<Int>,
        currentQuality: Binding<String>,
        lowLatency: Bool = true,
        autoplay: Bool = true,
        muted: Bool = false,
        volume: Double = 1.0,
        fullscreen: Bool = false
    ) {
        self.channelName = channelName
        self.chatEnabled = chatEnabled
        self.quality = quality
        self._isLoading = isLoading
        self._hasError = hasError
        self._isLive = isLive
        self._viewerCount = viewerCount
        self._currentQuality = currentQuality
        self.lowLatency = lowLatency
        self.autoplay = autoplay
        self.muted = muted
        self.volume = volume
        self.fullscreen = fullscreen
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = createWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Configure WebView
        setupWebView(webView, context: context)
        
        // Start performance monitoring
        performanceMonitor.startMonitoring(for: webView)
        networkMonitor.startMonitoring()
        
        return webView
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Load stream if needed
        if webView.url == nil || shouldReloadStream(webView) {
            loadTwitchStream(in: webView)
        }
        
        // Update stream settings
        updateStreamSettings(webView)
        
        // Monitor performance
        performanceMonitor.updateMetrics()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Private Methods
    
    private func createWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Media playback configuration
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Picture-in-picture support
        if #available(iOS 14.0, *) {
            configuration.allowsPictureInPictureMediaPlayback = true
        }
        
        // Enable airplay
        configuration.allowsAirPlayForMediaPlayback = true
        
        // Performance optimizations
        configuration.processPool = SharedWebViewProcessPool.shared
        
        // User script for enhanced functionality
        let userScript = WKUserScript(
            source: getTwitchEnhancementScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(userScript)
        
        // Message handlers
        configuration.userContentController.add(
            WeakScriptMessageHandler(target: self),
            name: "twitchHandler"
        )
        
        return configuration
    }
    
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
        
        // Gesture recognizers
        setupGestureRecognizers(webView, context: context)
        
        // Performance optimizations
        webView.configuration.preferences.javaScriptEnabled = true
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // iPhone 16 Pro specific optimizations
        if #available(iOS 16.0, *) {
            setupiPhone16ProOptimizations(webView)
        }
    }
    
    private func setupGestureRecognizers(_ webView: WKWebView, context: Context) {
        // Double tap for fullscreen
        let doubleTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        webView.addGestureRecognizer(doubleTapGesture)
        
        // Pinch to zoom (disabled for streams)
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        webView.addGestureRecognizer(pinchGesture)
        
        // Swipe gestures for stream control
        let swipeLeft = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSwipe(_:))
        )
        swipeLeft.direction = .left
        webView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSwipe(_:))
        )
        swipeRight.direction = .right
        webView.addGestureRecognizer(swipeRight)
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
    }
    
    private func loadTwitchStream(in webView: WKWebView) {
        let embedHTMLString = createLocalTwitchEmbedHTML()
        
        isLoading = true
        hasError = false
        
        // Load the HTML string directly instead of using a URL
        // This bypasses the parent domain restrictions
        webView.loadHTMLString(embedHTMLString, baseURL: URL(string: "https://streamyyy.com"))
    }
    
    private func buildTwitchEmbedURL() -> String {
        // For iOS WKWebView, we use HTML embedding approach
        // This method now returns a simple identifier for comparison
        return "twitch-embed-\(channelName)-\(quality.twitchValue)-\(autoplay)-\(muted)-\(volume)"
    }
    
    private func createLocalTwitchEmbedHTML() -> String {
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    overflow: hidden;
                    background: black;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                }
                
                #twitch-embed {
                    width: 100vw;
                    height: 100vh;
                }
                
                /* Alternative iframe approach for enhanced compatibility */
                #twitch-iframe {
                    width: 100vw;
                    height: 100vh;
                    border: none;
                    background: black;
                }
                
                .loading {
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: white;
                    font-size: 16px;
                    text-align: center;
                }
                
                .error {
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: #ff4444;
                    font-size: 16px;
                    text-align: center;
                    padding: 20px;
                    background: rgba(0, 0, 0, 0.8);
                    border-radius: 8px;
                }
                
                /* Prevent zoom and selection */
                * {
                    -webkit-user-select: none;
                    -webkit-touch-callout: none;
                    -webkit-tap-highlight-color: transparent;
                }
                
                /* Disable context menu */
                body {
                    -webkit-touch-callout: none;
                    -webkit-user-select: none;
                }
            </style>
        </head>
        <body>
            <!-- Primary embed approach using Twitch Embed API -->
            <div id="twitch-embed"></div>
            
            <!-- Fallback iframe approach -->
            <iframe id="twitch-iframe" 
                    src="https://player.twitch.tv/?channel=\(channelName)&parent=streamyyy.com&autoplay=\(autoplay ? "true" : "false")&muted=\(muted ? "true" : "false")" 
                    allowfullscreen="true"
                    style="display: none;">
            </iframe>
            
            <div id="loading" class="loading">Loading Twitch Stream...</div>
            <div id="error" class="error" style="display: none;">
                <div>Stream Unavailable</div>
                <div style="font-size: 12px; margin-top: 10px; opacity: 0.7;">
                    The stream may be offline or experiencing technical difficulties.
                </div>
            </div>
            
            <script src="https://embed.twitch.tv/embed/v1.js"></script>
            <script>
                let player = null;
                let loadingElement = document.getElementById('loading');
                let errorElement = document.getElementById('error');
                let embedDiv = document.getElementById('twitch-embed');
                let fallbackIframe = document.getElementById('twitch-iframe');
                let embedLoadTimeout;
                let fallbackUsed = false;
                
                // Fallback to iframe if embed fails to load
                function fallbackToIframe() {
                    console.log('Falling back to iframe approach');
                    fallbackUsed = true;
                    embedDiv.style.display = 'none';
                    fallbackIframe.style.display = 'block';
                    loadingElement.style.display = 'none';
                    
                    // Update iframe src with current settings
                    const iframeSrc = `https://player.twitch.tv/?channel=\(channelName)&parent=streamyyy.com&autoplay=\(autoplay ? "true" : "false")&muted=\(muted ? "true" : "false")&time=0h0m0s`;
                    fallbackIframe.src = iframeSrc;
                    
                    // Notify native code that fallback is being used
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchHandler) {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'fallback_used',
                            channel: '\(channelName)'
                        });
                    }
                }
                
                // Primary embed approach
                try {
                    // Set timeout for embed loading
                    embedLoadTimeout = setTimeout(function() {
                        if (loadingElement.style.display !== 'none') {
                            fallbackToIframe();
                        }
                    }, 8000); // 8 second timeout for primary embed
                    
                    // Twitch Embed configuration
                    const embed = new Twitch.Embed("twitch-embed", {
                        width: "100%",
                        height: "100%",
                        channel: "\(channelName)",
                        layout: "video",
                        autoplay: \(autoplay ? "true" : "false"),
                        muted: \(muted ? "true" : "false"),
                        theme: "dark",
                        parent: ["streamyyy.com"],
                        
                        // Additional options
                        allowfullscreen: \(fullscreen ? "true" : "false"),
                        
                        // Player options
                        time: "0h0m0s"
                    });
                    
                    // Handle embed ready
                    embed.addEventListener(Twitch.Embed.VIDEO_READY, function() {
                        clearTimeout(embedLoadTimeout);
                        player = embed.getPlayer();
                        loadingElement.style.display = 'none';
                        
                        // Set initial volume
                        if (player) {
                            player.setVolume(\(volume));
                            player.setMuted(\(muted));
                            
                            // Set quality if specified
                            if ("\(quality.twitchValue)" !== "auto") {
                                player.setQuality("\(quality.twitchValue)");
                            }
                        }
                        
                        // Notify native code that player is ready
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchHandler) {
                            window.webkit.messageHandlers.twitchHandler.postMessage({
                                type: 'ready',
                                channel: '\(channelName)',
                                quality: player ? player.getQuality() : 'auto',
                                fallback_used: false
                            });
                        }
                    });
                } catch (error) {
                    console.error('Embed failed to initialize:', error);
                    fallbackToIframe();
                }
                
                // Handle player events (only if not using fallback)
                function setupEmbedEventListeners(embed) {
                    embed.addEventListener(Twitch.Embed.VIDEO_PLAY, function() {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchHandler) {
                            window.webkit.messageHandlers.twitchHandler.postMessage({
                                type: 'playing'
                            });
                        }
                    });
                    
                    embed.addEventListener(Twitch.Embed.VIDEO_PAUSE, function() {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchHandler) {
                            window.webkit.messageHandlers.twitchHandler.postMessage({
                                type: 'pause'
                            });
                        }
                    });
                    
                    // Handle stream offline
                    embed.addEventListener(Twitch.Embed.OFFLINE, function() {
                        loadingElement.style.display = 'none';
                        errorElement.style.display = 'block';
                        
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchHandler) {
                            window.webkit.messageHandlers.twitchHandler.postMessage({
                                type: 'offline'
                            });
                        }
                    });
                    
                    // Handle stream online
                    embed.addEventListener(Twitch.Embed.ONLINE, function() {
                        errorElement.style.display = 'none';
                        
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchHandler) {
                            window.webkit.messageHandlers.twitchHandler.postMessage({
                                type: 'online'
                            });
                        }
                    });
                }
                
                // Setup event listeners if embed is created successfully
                if (typeof embed !== 'undefined') {
                    setupEmbedEventListeners(embed);
                }
                
                // Disable zoom and context menu
                document.addEventListener('gesturestart', function(e) {
                    e.preventDefault();
                });
                
                document.addEventListener('gesturechange', function(e) {
                    e.preventDefault();
                });
                
                document.addEventListener('gestureend', function(e) {
                    e.preventDefault();
                });
                
                document.addEventListener('contextmenu', function(e) {
                    e.preventDefault();
                });
                
                document.addEventListener('selectstart', function(e) {
                    e.preventDefault();
                });
                
                // Expose player controls to native code
                window.updateVolume = function(volume) {
                    if (player) {
                        player.setVolume(volume);
                    }
                };
                
                window.updateMute = function(muted) {
                    if (player) {
                        player.setMuted(muted);
                    }
                };
                
                window.updateQuality = function(quality) {
                    if (player) {
                        player.setQuality(quality);
                    }
                };
                
                window.getPlayerState = function() {
                    if (player) {
                        return {
                            quality: player.getQuality(),
                            volume: player.getVolume(),
                            muted: player.getMuted(),
                            isPaused: player.isPaused()
                        };
                    }
                    return null;
                };
            </script>
        </body>
        </html>
        """
        
        return embedHTML
    }
    
    private func shouldReloadStream(_ webView: WKWebView) -> Bool {
        // For HTML-based loading, we check if we need to reload based on configuration changes
        // If the URL is nil or if it's the first load, we should reload
        guard let currentURL = webView.url?.absoluteString else { return true }
        
        // If we're not on our base URL, we should reload
        if !currentURL.contains("streamyyy.com") {
            return true
        }
        
        // For now, we'll reload if any core parameters have changed
        // In a more sophisticated implementation, we could track the current state
        return false
    }
    
    private func updateStreamSettings(_ webView: WKWebView) {
        // Update volume using our exposed functions
        let volumeScript = """
            if (window.updateVolume) {
                window.updateVolume(\(volume));
            }
        """
        webView.evaluateJavaScript(volumeScript)
        
        // Update mute using our exposed functions
        let muteScript = """
            if (window.updateMute) {
                window.updateMute(\(muted));
            }
        """
        webView.evaluateJavaScript(muteScript)
        
        // Update quality using our exposed functions
        let qualityScript = """
            if (window.updateQuality) {
                window.updateQuality('\(quality.twitchValue)');
            }
        """
        webView.evaluateJavaScript(qualityScript)
    }
    
    private func getTwitchEnhancementScript() -> String {
        return """
            // Enhanced Twitch integration script
            (function() {
                // Wait for Twitch player to load
                function waitForTwitchPlayer() {
                    if (window.Twitch && window.Twitch.player) {
                        setupTwitchEvents();
                    } else {
                        setTimeout(waitForTwitchPlayer, 100);
                    }
                }
                
                function setupTwitchEvents() {
                    const player = window.Twitch.player;
                    
                    // Stream status events
                    player.addEventListener('ready', function() {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'ready',
                            quality: player.getQuality(),
                            volume: player.getVolume(),
                            muted: player.getMuted()
                        });
                    });
                    
                    player.addEventListener('playing', function() {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'playing',
                            quality: player.getQuality()
                        });
                    });
                    
                    player.addEventListener('pause', function() {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'pause'
                        });
                    });
                    
                    player.addEventListener('offline', function() {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'offline'
                        });
                    });
                    
                    player.addEventListener('online', function() {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'online'
                        });
                    });
                    
                    // Quality change events
                    player.addEventListener('qualityChanged', function(quality) {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'qualityChanged',
                            quality: quality
                        });
                    });
                    
                    // Volume change events
                    player.addEventListener('volumeChanged', function(volume) {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'volumeChanged',
                            volume: volume
                        });
                    });
                    
                    // Chat integration
                    if (window.Twitch.chat) {
                        window.Twitch.chat.onMessage = function(message) {
                            window.webkit.messageHandlers.twitchHandler.postMessage({
                                type: 'chatMessage',
                                message: message
                            });
                        };
                    }
                }
                
                // Custom CSS for better mobile experience
                const style = document.createElement('style');
                style.innerHTML = `
                    body {
                        margin: 0;
                        padding: 0;
                        overflow: hidden;
                        background: black;
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    }
                    
                    /* Hide unwanted UI elements */
                    .player-controls,
                    .player-overlay-background,
                    .top-nav,
                    .channel-info-bar,
                    .player-button,
                    .player-seek-bar,
                    .player-volume {
                        display: none !important;
                    }
                    
                    /* Optimize video container */
                    .player-root,
                    .player-video {
                        width: 100% !important;
                        height: 100% !important;
                        object-fit: cover;
                    }
                    
                    /* Chat styling */
                    .chat-container {
                        position: absolute;
                        bottom: 0;
                        right: 0;
                        width: 300px;
                        height: 400px;
                        background: rgba(0, 0, 0, 0.8);
                        border-radius: 8px;
                        padding: 8px;
                        color: white;
                        font-size: 14px;
                        overflow-y: auto;
                        z-index: 1000;
                    }
                    
                    /* Prevent zoom and selection */
                    * {
                        -webkit-user-select: none;
                        -webkit-touch-callout: none;
                        -webkit-tap-highlight-color: transparent;
                    }
                    
                    /* Disable context menu */
                    body {
                        -webkit-touch-callout: none;
                        -webkit-user-select: none;
                    }
                `;
                document.head.appendChild(style);
                
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
                
                // Disable context menu
                document.addEventListener('contextmenu', function(e) {
                    e.preventDefault();
                });
                
                // Disable text selection
                document.addEventListener('selectstart', function(e) {
                    e.preventDefault();
                });
                
                // Start setup
                waitForTwitchPlayer();
            })();
        """
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: TwitchEmbedWebView
        private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
        
        init(_ parent: TwitchEmbedWebView) {
            self.parent = parent
        }
        
        // MARK: - Navigation Delegate
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.hasError = false
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            
            // Inject additional optimizations
            let script = """
                // Performance optimizations
                if (window.performance && window.performance.mark) {
                    window.performance.mark('twitch-stream-loaded');
                }
                
                // Report initial status
                setTimeout(function() {
                    if (window.Twitch && window.Twitch.player) {
                        window.webkit.messageHandlers.twitchHandler.postMessage({
                            type: 'initialized',
                            quality: window.Twitch.player.getQuality(),
                            volume: window.Twitch.player.getVolume(),
                            muted: window.Twitch.player.getMuted()
                        });
                    }
                }, 1000);
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
            // Only allow Twitch player URLs
            if let url = navigationAction.request.url {
                let urlString = url.absoluteString
                
                if urlString.contains("player.twitch.tv") ||
                   urlString.contains("twitch.tv") ||
                   urlString.contains("twitchcdn.net") {
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
            
            switch body["type"] as? String {
            case "ready":
                parent.isLive = true
                if let quality = body["quality"] as? String {
                    parent.currentQuality = quality
                }
                
            case "playing":
                parent.isLive = true
                
            case "pause":
                parent.isLive = false
                
            case "offline":
                parent.isLive = false
                
            case "online":
                parent.isLive = true
                
            case "qualityChanged":
                if let quality = body["quality"] as? String {
                    parent.currentQuality = quality
                }
                
            case "fallback_used":
                // Fallback iframe is being used
                print("Twitch embed fallback to iframe for channel: \(body["channel"] ?? "unknown")")
                parent.isLive = true // Assume live when fallback is used
                
            case "error":
                parent.hasError = true
                if let message = body["message"] as? String {
                    print("Twitch embed error: \(message)")
                }
                
            case "chatMessage":
                // Handle chat messages
                if let message = body["message"] as? [String: Any] {
                    // Process chat message
                    print("Chat message received: \(message)")
                }
                
            default:
                break
            }
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            hapticFeedback.impactOccurred()
            
            // Toggle fullscreen
            if let webView = gesture.view as? WKWebView {
                let script = """
                    if (window.Twitch && window.Twitch.player) {
                        if (document.fullscreenElement) {
                            document.exitFullscreen();
                        } else {
                            document.documentElement.requestFullscreen();
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
                // Next quality level
                let script = """
                    if (window.Twitch && window.Twitch.player) {
                        const qualities = window.Twitch.player.getQualities();
                        const current = window.Twitch.player.getQuality();
                        const currentIndex = qualities.indexOf(current);
                        const nextIndex = (currentIndex + 1) % qualities.length;
                        window.Twitch.player.setQuality(qualities[nextIndex]);
                    }
                """
                webView.evaluateJavaScript(script)
                
            case .right:
                // Previous quality level
                let script = """
                    if (window.Twitch && window.Twitch.player) {
                        const qualities = window.Twitch.player.getQualities();
                        const current = window.Twitch.player.getQuality();
                        const currentIndex = qualities.indexOf(current);
                        const prevIndex = currentIndex > 0 ? currentIndex - 1 : qualities.length - 1;
                        window.Twitch.player.setQuality(qualities[prevIndex]);
                    }
                """
                webView.evaluateJavaScript(script)
                
            default:
                break
            }
        }
    }
}

// MARK: - Stream Quality Enum (now imported from Platform.swift)

// MARK: - Performance Monitor

class StreamPerformanceMonitor: ObservableObject {
    @Published var memoryUsage: Double = 0
    @Published var cpuUsage: Double = 0
    @Published var networkBandwidth: Double = 0
    @Published var frameRate: Double = 0
    @Published var bufferHealth: Double = 0
    
    private var timer: Timer?
    private weak var webView: WKWebView?
    
    func startMonitoring(for webView: WKWebView) {
        self.webView = webView
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateMetrics()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateMetrics() {
        // Update memory usage
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            memoryUsage = Double(memoryInfo.resident_size) / 1024 / 1024 // MB
        }
        
        // Update CPU usage
        updateCPUUsage()
        
        // Update network bandwidth
        updateNetworkBandwidth()
    }
    
    private func updateCPUUsage() {
        // CPU usage calculation
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // CPU usage approximation
            cpuUsage = Double(info.resident_size) / 1000000 // Simplified calculation
        }
    }
    
    private func updateNetworkBandwidth() {
        // Network bandwidth monitoring
        webView?.evaluateJavaScript("""
            (function() {
                if (navigator.connection) {
                    return navigator.connection.downlink || 0;
                }
                return 0;
            })();
        """) { [weak self] result, _ in
            if let bandwidth = result as? Double {
                DispatchQueue.main.async {
                    self?.networkBandwidth = bandwidth
                }
            }
        }
    }
}

// MARK: - Network Quality Monitor

class NetworkQualityMonitor: ObservableObject {
    @Published var connectionType: NWInterface.InterfaceType = .other
    @Published var bandwidth: Double = 0
    @Published var latency: Double = 0
    @Published var isConnected: Bool = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                if let interface = path.availableInterfaces.first {
                    self?.connectionType = interface.type
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

// MARK: - Shared WebView Process Pool

class SharedWebViewProcessPool {
    static let shared = WKProcessPool()
}

// MARK: - Weak Script Message Handler

class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: TwitchEmbedWebView?
    
    init(target: TwitchEmbedWebView) {
        self.target = target
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Forward to target if it still exists
        if let coordinator = target?.makeCoordinator() {
            coordinator.userContentController(userContentController, didReceive: message)
        }
    }
}

// MARK: - Preview

#Preview {
    struct TwitchEmbedPreview: View {
        @State private var isLoading = false
        @State private var hasError = false
        @State private var isLive = false
        @State private var viewerCount = 0
        @State private var currentQuality = "auto"
        
        var body: some View {
            TwitchEmbedWebView(
                channelName: "shroud",
                chatEnabled: true,
                quality: .auto,
                isLoading: $isLoading,
                hasError: $hasError,
                isLive: $isLive,
                viewerCount: $viewerCount,
                currentQuality: $currentQuality
            )
            .frame(height: 300)
            .overlay(
                VStack {
                    if isLoading {
                        ProgressView("Loading...")
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    if hasError {
                        Text("Stream Error")
                            .foregroundColor(.red)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    HStack {
                        if isLive {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Text(currentQuality.displayName)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                    }
                    .padding(8)
                }
            )
        }
    }
    
    return TwitchEmbedPreview()
}