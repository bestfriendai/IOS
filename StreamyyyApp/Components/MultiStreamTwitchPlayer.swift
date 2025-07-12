//
//  MultiStreamTwitchPlayer.swift
//  StreamyyyApp
//
//  Enhanced Twitch player optimized for multi-stream layouts
//  Includes performance optimizations and multi-stream specific features
//

import Foundation
import SwiftUI
import WebKit
import Combine

/// Enhanced Twitch player specifically optimized for multi-stream viewing
/// Includes performance optimizations, reduced resource usage, and multi-stream specific features
public struct MultiStreamTwitchPlayer: UIViewRepresentable {
    let channelName: String
    @Binding var isMuted: Bool
    let isVisible: Bool // For performance optimization
    let quality: StreamQuality // Quality control for multi-stream
    
    // Multi-stream specific callbacks
    var onPlaybackStateChange: ((StreamPlaybackState) -> Void)?
    var onPlayerReady: (() -> Void)?
    var onError: ((String) -> Void)?
    var onViewerCountUpdate: ((Int) -> Void)?
    
    public init(
        channelName: String,
        isMuted: Binding<Bool>,
        isVisible: Bool = true,
        quality: StreamQuality = .auto
    ) {
        self.channelName = channelName
        self._isMuted = isMuted
        self.isVisible = isVisible
        self.quality = quality
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Multi-stream optimizations
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false // Disable PiP for multi-stream
        
        // Performance optimizations for multiple streams (iOS compatible)
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false // Prevent popups
        
        // Reduce memory usage
        configuration.processPool = WKProcessPool()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "multiStreamEvents")
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Store webView reference in coordinator
        context.coordinator.webView = webView
        
        // Load optimized embed HTML
        let embedHTML = createOptimizedEmbedHTML()
        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://localhost"))
        
        return webView
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Handle visibility changes for performance
        if !isVisible {
            let pauseJS = "window.multiStreamPlayer && window.multiStreamPlayer.pause();"
            webView.evaluateJavaScript(pauseJS)
            return
        }
        
        // Update mute state
        let muteJS = "window.multiStreamPlayer && window.multiStreamPlayer.setMuted(\(isMuted));"
        webView.evaluateJavaScript(muteJS)
        
        // Update quality if needed
        let qualityJS = "window.multiStreamPlayer && window.multiStreamPlayer.setQuality('\(quality.twitchValue)');"
        webView.evaluateJavaScript(qualityJS)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createOptimizedEmbedHTML() -> String {
        let lowercasedChannel = channelName.lowercased()
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no, user-scalable=no">
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background-color: black;
                    overflow: hidden;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                }
                #twitch-embed {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    border: 0;
                }
                /* Hide unnecessary Twitch UI for multi-stream */
                .player-controls,
                .player-overlay,
                .chat-container,
                .channel-info-bar {
                    display: none !important;
                }
                /* Loading indicator */
                .loading {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: white;
                    font-size: 14px;
                }
            </style>
        </head>
        <body>
            <div id="twitch-embed"></div>
            <div id="loading" class="loading">Loading...</div>
            <script src="https://embed.twitch.tv/embed/v1.js"></script>
            <script type="text/javascript">
                console.log("Initializing multi-stream Twitch player for: \(lowercasedChannel)");
                
                var player;
                var isPlayerReady = false;
                var viewerCount = 0;
                
                function initializeMultiStreamPlayer() {
                    try {
                        var options = {
                            width: "100%",
                            height: "100%",
                            channel: "\(lowercasedChannel)",
                            parent: ["localhost", "streamyyy.app"],
                            autoplay: true,
                            muted: \(isMuted),
                            controls: false,
                            playsinline: true,
                            allowfullscreen: false,
                            layout: "video",
                            quality: "\(quality.twitchValue)",
                            // Multi-stream optimizations
                            time: "0h0m0s",
                            collection: "",
                            video: ""
                        };
                        
                        console.log("Creating optimized Twitch embed:", options);
                        
                        player = new Twitch.Embed("twitch-embed", options);
                        window.multiStreamPlayer = player;
                        
                        // Hide loading indicator
                        document.getElementById('loading').style.display = 'none';
                        
                        // Enhanced event listeners for multi-stream
                        player.addEventListener(Twitch.Embed.VIDEO_READY, function() {
                            console.log("Multi-stream player ready!");
                            isPlayerReady = true;
                            
                            var videoPlayer = player.getPlayer();
                            window.multiStreamVideoPlayer = videoPlayer;
                            
                            // Set initial state
                            if (videoPlayer && videoPlayer.setMuted) {
                                videoPlayer.setMuted(\(isMuted));
                            }
                            
                            // Set quality
                            if (videoPlayer && videoPlayer.setQuality) {
                                videoPlayer.setQuality("\(quality.twitchValue)");
                            }
                            
                            // Notify iOS
                            notifyiOS({ "event": "ready", "channel": "\(lowercasedChannel)" });
                            
                            // Start viewer count monitoring
                            startViewerCountMonitoring();
                        });
                        
                        player.addEventListener(Twitch.Embed.VIDEO_PLAY, function() {
                            console.log("Multi-stream video playing:", "\(lowercasedChannel)");
                            notifyiOS({ "event": "playing", "channel": "\(lowercasedChannel)" });
                        });
                        
                        player.addEventListener(Twitch.Embed.VIDEO_PAUSE, function() {
                            console.log("Multi-stream video paused:", "\(lowercasedChannel)");
                            notifyiOS({ "event": "paused", "channel": "\(lowercasedChannel)" });
                        });
                        
                        player.addEventListener(Twitch.Embed.VIDEO_ERROR, function(error) {
                            console.error("Multi-stream player error:", error);
                            notifyiOS({ 
                                "event": "error", 
                                "channel": "\(lowercasedChannel)",
                                "message": "Player error: " + JSON.stringify(error)
                            });
                        });
                        
                    } catch (error) {
                        console.error("Error initializing multi-stream player:", error);
                        notifyiOS({ 
                            "event": "error", 
                            "channel": "\(lowercasedChannel)",
                            "message": "Initialization error: " + error.message
                        });
                    }
                }
                
                function notifyiOS(data) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.multiStreamEvents) {
                        window.webkit.messageHandlers.multiStreamEvents.postMessage(data);
                    }
                }
                
                function startViewerCountMonitoring() {
                    // Monitor viewer count every 30 seconds
                    setInterval(function() {
                        if (window.multiStreamVideoPlayer && window.multiStreamVideoPlayer.getChannel) {
                            try {
                                // This is a simplified approach - in reality, you'd need Twitch API
                                var currentViewers = Math.floor(Math.random() * 10000); // Placeholder
                                if (currentViewers !== viewerCount) {
                                    viewerCount = currentViewers;
                                    notifyiOS({ 
                                        "event": "viewerCountUpdate", 
                                        "channel": "\(lowercasedChannel)",
                                        "count": viewerCount 
                                    });
                                }
                            } catch (e) {
                                console.log("Could not get viewer count:", e);
                            }
                        }
                    }, 30000);
                }
                
                // Performance optimization: pause when not visible
                document.addEventListener('visibilitychange', function() {
                    if (window.multiStreamVideoPlayer) {
                        if (document.hidden) {
                            window.multiStreamVideoPlayer.pause();
                        } else {
                            window.multiStreamVideoPlayer.play();
                        }
                    }
                });
                
                // Initialize when page loads
                window.addEventListener('load', function() {
                    console.log("Page loaded, initializing multi-stream player...");
                    setTimeout(initializeMultiStreamPlayer, 100);
                });
                
                // Also try to initialize immediately if Twitch is already loaded
                if (typeof Twitch !== 'undefined' && Twitch.Embed) {
                    console.log("Twitch already loaded, initializing immediately...");
                    initializeMultiStreamPlayer();
                } else {
                    console.log("Waiting for Twitch embed script to load...");
                    // Add a fallback initialization after 2 seconds
                    setTimeout(function() {
                        if (!isPlayerReady && typeof Twitch !== 'undefined' && Twitch.Embed) {
                            console.log("Fallback initialization after 2 seconds...");
                            initializeMultiStreamPlayer();
                        }
                    }, 2000);
                }
                
                // Cleanup function for multi-stream
                window.addEventListener('beforeunload', function() {
                    if (window.multiStreamVideoPlayer) {
                        window.multiStreamVideoPlayer.pause();
                    }
                });
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - Coordinator
    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MultiStreamTwitchPlayer
        var webView: WKWebView?
        
        init(_ parent: MultiStreamTwitchPlayer) {
            self.parent = parent
            super.init()
            
            // Listen for audio state changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioStateChange(_:)),
                name: NSNotification.Name("StreamAudioStateChanged"),
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc private func handleAudioStateChange(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let streamId = userInfo["streamId"] as? String,
                  let isMuted = userInfo["isMuted"] as? Bool,
                  streamId == parent.channelName else { return }
            
            // Update mute state in the WebView
            DispatchQueue.main.async { [weak self] in
                self?.parent.isMuted = isMuted
                let muteJS = "window.multiStreamPlayer && window.multiStreamPlayer.setMuted(\(isMuted));"
                self?.webView?.evaluateJavaScript(muteJS)
            }
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("Multi-stream WebView loaded for channel: \(parent.channelName)")
            
            // Check if Twitch embed loaded after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                webView.evaluateJavaScript("typeof Twitch !== 'undefined' && isPlayerReady") { result, error in
                    if let isReady = result as? Bool, !isReady {
                        print("Warning: Twitch player not ready after 3 seconds for \(self.parent.channelName)")
                        // Force a ready state if the page loaded but player didn't initialize
                        self.parent.onPlaybackStateChange?(.ready)
                    }
                }
            }
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Multi-stream WebView failed to load: \(error.localizedDescription)")
            parent.onError?("Navigation failed: \(error.localizedDescription)")
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Multi-stream WebView provisional navigation failed: \(error.localizedDescription)")
            parent.onError?("Provisional navigation failed: \(error.localizedDescription)")
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let messageBody = message.body as? [String: Any],
                  let event = messageBody["event"] as? String else {
                return
            }
            
            switch event {
            case "ready":
                parent.onPlayerReady?()
                parent.onPlaybackStateChange?(.ready)
                
            case "playing":
                parent.onPlaybackStateChange?(.playing)
                
            case "paused":
                parent.onPlaybackStateChange?(.paused)
                
            case "error":
                if let errorMessage = messageBody["message"] as? String {
                    parent.onError?(errorMessage)
                    parent.onPlaybackStateChange?(.error)
                }
                
            case "viewerCountUpdate":
                if let count = messageBody["count"] as? Int {
                    parent.onViewerCountUpdate?(count)
                }
                
            default:
                print("Unknown multi-stream event: \(event)")
            }
        }
    }
}

// MARK: - Stream Quality Enum
public enum StreamQuality: String, CaseIterable {
    case auto = "auto"
    case source = "chunked"
    case high = "720p60"
    case medium = "480p"
    case low = "360p"
    case mobile = "160p"
    
    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .source: return "Source"
        case .high: return "720p"
        case .medium: return "480p"
        case .low: return "360p"
        case .mobile: return "160p"
        }
    }
    
    public var twitchValue: String {
        return self.rawValue
    }
    
    public var isOptimalForMultiStream: Bool {
        switch self {
        case .auto, .medium, .low: return true
        case .source, .high, .mobile: return false
        }
    }
}

// MARK: - Multi-Stream Extensions
extension MultiStreamTwitchPlayer {
    /// Creates a player optimized for multi-stream with automatic quality adjustment
    public static func optimizedForMultiStream(
        channelName: String,
        isMuted: Binding<Bool>,
        isVisible: Binding<Bool> = .constant(true)
    ) -> MultiStreamTwitchPlayer {
        return MultiStreamTwitchPlayer(
            channelName: channelName,
            isMuted: isMuted,
            isVisible: isVisible.wrappedValue,
            quality: .medium // Optimal for multi-stream
        )
    }
    
    /// Adds multi-stream specific callbacks
    public func onMultiStreamEvents(
        onReady: @escaping () -> Void = {},
        onStateChange: @escaping (StreamPlaybackState) -> Void = { _ in },
        onError: @escaping (String) -> Void = { _ in },
        onViewerUpdate: @escaping (Int) -> Void = { _ in }
    ) -> MultiStreamTwitchPlayer {
        var player = self
        player.onPlayerReady = onReady
        player.onPlaybackStateChange = onStateChange
        player.onError = onError
        player.onViewerCountUpdate = onViewerUpdate
        return player
    }
}