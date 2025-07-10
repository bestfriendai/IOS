//
//  TwitchEmbedWebView.swift
//  StreamyyyApp
//
//  Fixed Twitch WebView with 2025 embed API compatibility
//  Updated to resolve iOS parent parameter and streaming issues
//

import SwiftUI
import WebKit
import Combine

/// A reliable and controllable Twitch stream player using the official JavaScript embed API.
/// Fixed for 2025 iOS compatibility and parent parameter issues.
public struct TwitchEmbedWebView: UIViewRepresentable {
    let channelName: String
    @Binding var isMuted: Bool
    
    // Callbacks for state changes
    var onPlaybackStateChange: ((StreamPlaybackState) -> Void)?
    var onPlayerReady: (() -> Void)?
    var onError: ((String) -> Void)?
    
    public init(
        channelName: String,
        isMuted: Binding<Bool>
    ) {
        self.channelName = channelName
        self._isMuted = isMuted
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable modern web features
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "twitchPlayerEvents")
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        // Load the embed HTML directly
        let embedHTML = createEmbedHTML(channel: channelName, muted: isMuted)
        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://localhost"))
        
        return webView
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        let currentMutedStateJS = "window.twitchPlayer && window.twitchPlayer.getMuted()"
        
        webView.evaluateJavaScript(currentMutedStateJS) { (result, error) in
            guard let currentlyMuted = result as? Bool, currentlyMuted != isMuted else {
                // No change needed, or player not ready yet.
                // The coordinator will set the initial mute state once the player is ready.
                return
            }
            
            // Mute state has changed from outside, update the player.
            let js = "window.twitchPlayer.setMuted(\(isMuted));"
            webView.evaluateJavaScript(js)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createEmbedHTML(channel: String, muted: Bool) -> String {
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
                }
                #twitch-embed {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    border: 0;
                }
                /* Hide Twitch UI elements that don't work well in mobile */
                .player-controls {
                    display: none !important;
                }
            </style>
        </head>
        <body>
            <div id="twitch-embed"></div>
            <script src="https://embed.twitch.tv/embed/v1.js"></script>
            <script type="text/javascript">
                console.log("Initializing Twitch player for channel: \(channel)");
                
                var player;
                var isPlayerReady = false;
                
                function initializeTwitchPlayer() {
                    try {
                        var options = {
                            width: "100%",
                            height: "100%",
                            channel: "\(channel)",
                            parent: ["localhost"], // Use localhost for iOS WKWebView compatibility
                            autoplay: true,
                            muted: \(muted),
                            controls: false,
                            playsinline: true,
                            allowfullscreen: false,
                            layout: "video"
                        };
                        
                        console.log("Creating Twitch embed with options:", options);
                        
                        player = new Twitch.Embed("twitch-embed", options);
                        window.twitchPlayer = player;
                        
                        // Add event listeners
                        player.addEventListener(Twitch.Embed.VIDEO_READY, function() {
                            console.log("Twitch player is ready!");
                            isPlayerReady = true;
                            
                            // Get the video player instance
                            var videoPlayer = player.getPlayer();
                            window.twitchVideoPlayer = videoPlayer;
                            
                            // Set initial mute state
                            if (videoPlayer && videoPlayer.setMuted) {
                                videoPlayer.setMuted(\(muted));
                            }
                            
                            // Notify iOS
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchPlayerEvents) {
                                window.webkit.messageHandlers.twitchPlayerEvents.postMessage({ "event": "ready" });
                            }
                        });
                        
                        player.addEventListener(Twitch.Embed.VIDEO_PLAY, function() {
                            console.log("Video started playing");
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchPlayerEvents) {
                                window.webkit.messageHandlers.twitchPlayerEvents.postMessage({ "event": "playing" });
                            }
                        });
                        
                        player.addEventListener(Twitch.Embed.VIDEO_PAUSE, function() {
                            console.log("Video paused");
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchPlayerEvents) {
                                window.webkit.messageHandlers.twitchPlayerEvents.postMessage({ "event": "paused" });
                            }
                        });
                        
                        // Handle errors
                        player.addEventListener(Twitch.Embed.VIDEO_ERROR, function(error) {
                            console.error("Twitch player error:", error);
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchPlayerEvents) {
                                window.webkit.messageHandlers.twitchPlayerEvents.postMessage({ 
                                    "event": "error", 
                                    "message": "Player error: " + JSON.stringify(error)
                                });
                            }
                        });
                        
                    } catch (error) {
                        console.error("Error initializing Twitch player:", error);
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchPlayerEvents) {
                            window.webkit.messageHandlers.twitchPlayerEvents.postMessage({ 
                                "event": "error", 
                                "message": "Initialization error: " + error.message
                            });
                        }
                    }
                }
                
                // Initialize when page loads
                window.addEventListener('load', function() {
                    console.log("Page loaded, initializing Twitch player...");
                    setTimeout(initializeTwitchPlayer, 100); // Small delay to ensure DOM is ready
                });
                
                // Fallback initialization
                if (document.readyState === 'complete') {
                    initializeTwitchPlayer();
                } else {
                    document.addEventListener('DOMContentLoaded', initializeTwitchPlayer);
                }
                
                // Expose functions for iOS control
                window.setMuted = function(muted) {
                    console.log("Setting muted state to:", muted);
                    if (window.twitchVideoPlayer && window.twitchVideoPlayer.setMuted) {
                        window.twitchVideoPlayer.setMuted(muted);
                    } else if (window.twitchPlayer && window.twitchPlayer.getPlayer) {
                        var videoPlayer = window.twitchPlayer.getPlayer();
                        if (videoPlayer && videoPlayer.setMuted) {
                            videoPlayer.setMuted(muted);
                        }
                    }
                };
                
                window.getMuted = function() {
                    if (window.twitchVideoPlayer && window.twitchVideoPlayer.getMuted) {
                        return window.twitchVideoPlayer.getMuted();
                    } else if (window.twitchPlayer && window.twitchPlayer.getPlayer) {
                        var videoPlayer = window.twitchPlayer.getPlayer();
                        if (videoPlayer && videoPlayer.getMuted) {
                            return videoPlayer.getMuted();
                        }
                    }
                    return false;
                };
                
                // Debug function
                window.getTwitchPlayerState = function() {
                    return {
                        playerExists: !!window.twitchPlayer,
                        videoPlayerExists: !!window.twitchVideoPlayer,
                        isPlayerReady: isPlayerReady,
                        channel: "\(channel)"
                    };
                };
                
            </script>
        </body>
        </html>
        """
    }
    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: TwitchEmbedWebView

        init(_ parent: TwitchEmbedWebView) {
            self.parent = parent
            super.init()
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // HTML is already loaded in makeUIView, no need to reload
            print("WebView finished loading navigation")
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error)")
            DispatchQueue.main.async {
                self.parent.onError?("Navigation failed: \(error.localizedDescription)")
            }
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error)")
            DispatchQueue.main.async {
                self.parent.onError?("Provisional navigation failed: \(error.localizedDescription)")
            }
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let event = body["event"] as? String else { 
                print("Invalid message received: \(message.body)")
                return 
            }

            DispatchQueue.main.async {
                switch event {
                case "ready":
                    print("Twitch player is ready!")
                    self.parent.onPlayerReady?()
                    // Set initial mute state once player is ready using new function
                    message.webView?.evaluateJavaScript("window.setMuted(\(self.parent.isMuted));")
                    
                case "playing":
                    print("Twitch player started playing")
                    self.parent.onPlaybackStateChange?(.playing)
                    
                case "paused":
                    print("Twitch player paused")
                    self.parent.onPlaybackStateChange?(.paused)
                    
                case "error":
                    let errorMessage = body["message"] as? String ?? "Unknown error"
                    print("Twitch player error: \(errorMessage)")
                    self.parent.onError?(errorMessage)
                    self.parent.onPlaybackStateChange?(.error)
                    
                default:
                    print("Unknown event received: \(event)")
                    break
                }
            }
        }
    }
}

// MARK: - Stream Playback State
public enum StreamPlaybackState: String, CaseIterable {
    case idle, loading, ready, playing, paused, buffering, ended, error
    
    public var displayName: String {
        return self.rawValue.capitalized
    }
    
    public var isPlaying: Bool {
        return self == .playing
    }
    
    public var isPaused: Bool {
        return self == .paused
    }
    
    public var isError: Bool {
        return self == .error
    }
}