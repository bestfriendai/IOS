//
//  MultiPlatformStreamView.swift
//  StreamyyyApp
//
//  Multi-platform streaming support (Twitch, YouTube, Kick)
//  Created by Streamyyy Team
//

import SwiftUI
import WebKit
import AVKit
import Network
import Combine

// MARK: - Multi-Platform Stream View
struct MultiPlatformStreamView: UIViewRepresentable {
    let url: String
    let platform: Platform
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var currentQuality: StreamQuality
    @Binding var isLive: Bool
    @Binding var viewerCount: Int
    @Binding var isMuted: Bool
    
    // Advanced configuration
    let chatEnabled: Bool
    let gesturesEnabled: Bool
    let performanceMonitoringEnabled: Bool
    
    // Platform-specific managers
    @StateObject private var twitchManager = TwitchStreamManager()
    @StateObject private var youtubeManager = YouTubeStreamManager()
    @StateObject private var kickManager = KickStreamManager()
    
    init(
        url: String,
        platform: Platform = .other,
        isLoading: Binding<Bool>,
        hasError: Binding<Bool>,
        currentQuality: Binding<StreamQuality> = .constant(.auto),
        isLive: Binding<Bool> = .constant(false),
        viewerCount: Binding<Int> = .constant(0),
        isMuted: Binding<Bool> = .constant(false),
        chatEnabled: Bool = true,
        gesturesEnabled: Bool = true,
        performanceMonitoringEnabled: Bool = true
    ) {
        self.url = url
        self.platform = platform == .other ? Platform.detect(from: url) : platform
        self._isLoading = isLoading
        self._hasError = hasError
        self._currentQuality = currentQuality
        self._isLive = isLive
        self._viewerCount = viewerCount
        self._isMuted = isMuted
        self.chatEnabled = chatEnabled
        self.gesturesEnabled = gesturesEnabled
        self.performanceMonitoringEnabled = performanceMonitoringEnabled
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = createPlatformConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Setup WebView
        setupWebView(webView, context: context)
        
        // Configure platform-specific settings
        configurePlatformSettings(webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let embedURL = buildEmbedURL()
        
        if let currentURL = webView.url?.absoluteString,
           currentURL != embedURL {
            loadStream(in: webView, url: embedURL)
        }
        
        // Update platform-specific settings
        updatePlatformSettings(webView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Private Methods
    
    private func createPlatformConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Media playback configuration
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        
        // Performance optimizations
        configuration.processPool = SharedWebViewProcessPool.shared
        
        // Platform-specific user script
        let userScript = WKUserScript(
            source: getPlatformScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(userScript)
        
        // Message handlers
        configuration.userContentController.add(
            WeakScriptMessageHandler(target: self),
            name: "platformHandler"
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
        
        // Performance optimizations
        webView.configuration.preferences.javaScriptEnabled = true
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Setup gestures if enabled
        if gesturesEnabled {
            setupGestures(webView, coordinator: context.coordinator)
        }
        
        // iPhone 16 Pro optimizations
        if #available(iOS 16.0, *) {
            optimizeForDevice(webView)
        }
    }
    
    private func configurePlatformSettings(_ webView: WKWebView) {
        switch platform {
        case .twitch:
            twitchManager.configure(webView: webView, chatEnabled: chatEnabled)
        case .youtube:
            youtubeManager.configure(webView: webView, chatEnabled: chatEnabled)
        case .kick:
            kickManager.configure(webView: webView, chatEnabled: chatEnabled)
        default:
            break
        }
    }
    
    private func buildEmbedURL() -> String {
        switch platform {
        case .twitch:
            return twitchManager.buildEmbedURL(from: url, quality: currentQuality, muted: isMuted)
        case .youtube:
            return youtubeManager.buildEmbedURL(from: url, quality: currentQuality, muted: isMuted)
        case .kick:
            return kickManager.buildEmbedURL(from: url, quality: currentQuality, muted: isMuted)
        default:
            return url
        }
    }
    
    private func loadStream(in webView: WKWebView, url: String) {
        guard let streamURL = URL(string: url) else {
            hasError = true
            return
        }
        
        isLoading = true
        hasError = false
        
        var request = URLRequest(url: streamURL)
        request.setValue(getUserAgent(), forHTTPHeaderField: "User-Agent")
        
        webView.load(request)
    }
    
    private func updatePlatformSettings(_ webView: WKWebView) {
        switch platform {
        case .twitch:
            twitchManager.updateSettings(webView: webView, quality: currentQuality, muted: isMuted)
        case .youtube:
            youtubeManager.updateSettings(webView: webView, quality: currentQuality, muted: isMuted)
        case .kick:
            kickManager.updateSettings(webView: webView, quality: currentQuality, muted: isMuted)
        default:
            break
        }
    }
    
    private func getPlatformScript() -> String {
        return \"\"\"\n            // Multi-platform stream integration script\n            (function() {\n                // Platform detection\n                let platform = 'unknown';\n                if (window.location.hostname.includes('twitch.tv')) {\n                    platform = 'twitch';\n                } else if (window.location.hostname.includes('youtube.com')) {\n                    platform = 'youtube';\n                } else if (window.location.hostname.includes('kick.com')) {\n                    platform = 'kick';\n                }\n                \n                // Universal video monitoring\n                function monitorVideo() {\n                    const video = document.querySelector('video');\n                    if (video) {\n                        // Track playback events\n                        video.addEventListener('play', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'playbackStart',\n                                platform: platform\n                            });\n                        });\n                        \n                        video.addEventListener('pause', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'playbackPause',\n                                platform: platform\n                            });\n                        });\n                        \n                        video.addEventListener('loadedmetadata', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'streamLoaded',\n                                platform: platform,\n                                width: video.videoWidth,\n                                height: video.videoHeight,\n                                duration: video.duration\n                            });\n                        });\n                        \n                        video.addEventListener('waiting', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'buffering',\n                                platform: platform\n                            });\n                        });\n                        \n                        video.addEventListener('canplay', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'ready',\n                                platform: platform\n                            });\n                        });\n                        \n                        video.addEventListener('volumechange', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'volumeChanged',\n                                platform: platform,\n                                volume: video.volume,\n                                muted: video.muted\n                            });\n                        });\n                    }\n                }\n                \n                // Platform-specific monitoring\n                if (platform === 'twitch') {\n                    // Twitch-specific monitoring\n                    if (window.Twitch && window.Twitch.player) {\n                        window.Twitch.player.addEventListener('ready', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'twitchReady',\n                                quality: window.Twitch.player.getQuality(),\n                                volume: window.Twitch.player.getVolume()\n                            });\n                        });\n                        \n                        window.Twitch.player.addEventListener('online', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'liveStatus',\n                                isLive: true,\n                                platform: 'twitch'\n                            });\n                        });\n                        \n                        window.Twitch.player.addEventListener('offline', function() {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'liveStatus',\n                                isLive: false,\n                                platform: 'twitch'\n                            });\n                        });\n                    }\n                } else if (platform === 'youtube') {\n                    // YouTube-specific monitoring\n                    window.addEventListener('message', function(event) {\n                        if (event.data && event.data.info) {\n                            const info = event.data.info;\n                            if (info.playerState !== undefined) {\n                                window.webkit.messageHandlers.platformHandler.postMessage({\n                                    type: 'youtubeStateChange',\n                                    state: info.playerState,\n                                    platform: 'youtube'\n                                });\n                            }\n                        }\n                    });\n                } else if (platform === 'kick') {\n                    // Kick-specific monitoring\n                    setTimeout(function() {\n                        const liveIndicator = document.querySelector('.live-indicator, [data-live=\"true\"]');\n                        if (liveIndicator) {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'liveStatus',\n                                isLive: true,\n                                platform: 'kick'\n                            });\n                        }\n                    }, 1000);\n                }\n                \n                // Universal CSS styling\n                const style = document.createElement('style');\n                style.innerHTML = `\n                    body {\n                        margin: 0;\n                        padding: 0;\n                        overflow: hidden;\n                        background: black;\n                    }\n                    \n                    video {\n                        width: 100% !important;\n                        height: 100% !important;\n                        object-fit: cover;\n                        background: black;\n                    }\n                    \n                    iframe {\n                        width: 100% !important;\n                        height: 100% !important;\n                        border: none;\n                    }\n                    \n                    /* Hide platform-specific UI elements */\n                    .player-controls,\n                    .player-overlay,\n                    .top-nav,\n                    .channel-info-bar,\n                    .ytp-chrome-top,\n                    .ytp-chrome-bottom,\n                    .ytp-watermark,\n                    .kick-player-controls,\n                    .player-button,\n                    .player-seek-bar {\n                        display: none !important;\n                    }\n                    \n                    /* Disable user interaction */\n                    * {\n                        -webkit-user-select: none;\n                        -webkit-touch-callout: none;\n                        -webkit-tap-highlight-color: transparent;\n                    }\n                    \n                    /* Chat styling */\n                    .chat-container {\n                        position: absolute;\n                        bottom: 20px;\n                        right: 20px;\n                        width: 300px;\n                        max-height: 400px;\n                        background: rgba(0, 0, 0, 0.9);\n                        border-radius: 8px;\n                        padding: 12px;\n                        color: white;\n                        font-size: 14px;\n                        overflow-y: auto;\n                        z-index: 1000;\n                        backdrop-filter: blur(10px);\n                    }\n                    \n                    .chat-message {\n                        margin-bottom: 8px;\n                        padding: 4px;\n                        border-radius: 4px;\n                        background: rgba(255, 255, 255, 0.1);\n                    }\n                    \n                    .chat-username {\n                        font-weight: bold;\n                        color: #9146ff;\n                    }\n                `;\n                document.head.appendChild(style);\n                \n                // Disable zoom and context menu\n                document.addEventListener('gesturestart', function(e) {\n                    e.preventDefault();\n                });\n                \n                document.addEventListener('gesturechange', function(e) {\n                    e.preventDefault();\n                });\n                \n                document.addEventListener('gestureend', function(e) {\n                    e.preventDefault();\n                });\n                \n                document.addEventListener('contextmenu', function(e) {\n                    e.preventDefault();\n                });\n                \n                document.addEventListener('selectstart', function(e) {\n                    e.preventDefault();\n                });\n                \n                // Start monitoring\n                monitorVideo();\n                \n                // Retry if video not found\n                setTimeout(function() {\n                    if (!document.querySelector('video')) {\n                        monitorVideo();\n                    }\n                }, 1000);\n                \n                // Report initialization\n                window.webkit.messageHandlers.platformHandler.postMessage({\n                    type: 'initialized',\n                    platform: platform,\n                    timestamp: Date.now()\n                });\n            })();\n        \"\"\"\n    }
    
    private func setupGestures(_ webView: WKWebView, coordinator: Coordinator) {
        // Double tap for fullscreen
        let doubleTapGesture = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        webView.addGestureRecognizer(doubleTapGesture)
        
        // Pinch gesture (disabled for streams)
        let pinchGesture = UIPinchGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        webView.addGestureRecognizer(pinchGesture)
        
        // Swipe gestures
        let directions: [UISwipeGestureRecognizer.Direction] = [.left, .right, .up, .down]
        for direction in directions {
            let swipeGesture = UISwipeGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.handleSwipe(_:))
            )
            swipeGesture.direction = direction
            webView.addGestureRecognizer(swipeGesture)
        }
        
        // Long press for info
        let longPressGesture = UILongPressGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        webView.addGestureRecognizer(longPressGesture)
    }
    
    private func optimizeForDevice(_ webView: WKWebView) {
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
    
    private func getUserAgent() -> String {
        return "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: MultiPlatformStreamView
        private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
        
        init(_ parent: MultiPlatformStreamView) {
            self.parent = parent
            super.init()
            hapticFeedback.prepare()
        }
        
        // MARK: - Navigation Delegate
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.hasError = false
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            
            // Platform-specific post-load setup
            switch parent.platform {
            case .twitch:
                parent.twitchManager.onLoadComplete(webView: webView)
            case .youtube:
                parent.youtubeManager.onLoadComplete(webView: webView)
            case .kick:
                parent.kickManager.onLoadComplete(webView: webView)
            default:
                break
            }
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
            if let url = navigationAction.request.url {
                let urlString = url.absoluteString
                
                // Allow streaming platform URLs
                if urlString.contains("player.twitch.tv") ||
                   urlString.contains("youtube.com/embed") ||
                   urlString.contains("player.kick.com") ||
                   urlString.contains("twitchcdn.net") ||
                   urlString.contains("googlevideo.com") ||
                   urlString.contains("kick.com") ||
                   urlString.contains("ytimg.com") {
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
            
            let platform = body["platform"] as? String ?? "unknown"
            
            switch body["type"] as? String {
            case "initialized":
                // Platform initialized
                break
                
            case "streamLoaded":
                if let width = body["width"] as? Int,
                   let height = body["height\"] as? Int {
                    let quality = determineQuality(width: width, height: height)
                    parent.currentQuality = quality
                }
                
            case "playbackStart":
                parent.isLive = true
                
            case "playbackPause":
                parent.isLive = false
                
            case "liveStatus":
                if let isLive = body["isLive"] as? Bool {
                    parent.isLive = isLive
                }
                
            case "twitchReady":
                if let quality = body["quality"] as? String {
                    parent.currentQuality = StreamQuality.from(twitchValue: quality)
                }
                
            case "youtubeStateChange":
                if let state = body["state"] as? Int {
                    // YouTube player states: -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued
                    parent.isLive = state == 1
                }
                
            case "volumeChanged":
                if let muted = body["muted"] as? Bool {
                    parent.isMuted = muted
                }
                
            case "buffering":
                // Handle buffering state
                break
                
            case "ready":
                parent.isLoading = false
                parent.hasError = false
                
            default:
                break
            }
        }
        
        private func determineQuality(width: Int, height: Int) -> StreamQuality {
            switch height {
            case 1080...2160:
                return .source
            case 720...1079:
                return .high
            case 480...719:
                return .medium
            case 360...479:
                return .low
            default:
                return .mobile
            }
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            hapticFeedback.impactOccurred()
            
            if let webView = gesture.view as? WKWebView {
                let script = \"\"\"\n                    const video = document.querySelector('video');\n                    if (video) {\n                        if (document.fullscreenElement) {\n                            document.exitFullscreen();\n                        } else {\n                            video.requestFullscreen();\n                        }\n                    }\n                \"\"\"\n                webView.evaluateJavaScript(script)
            }
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            gesture.view?.transform = CGAffineTransform.identity
        }
        
        @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
            hapticFeedback.impactOccurred()
            
            guard let webView = gesture.view as? WKWebView else { return }
            
            switch gesture.direction {
            case .left:
                // Next quality or seek forward
                let script = \"\"\"\n                    const video = document.querySelector('video');\n                    if (video && !video.seeking && video.duration > 0) {\n                        video.currentTime = Math.min(video.currentTime + 10, video.duration);\n                    }\n                \"\"\"\n                webView.evaluateJavaScript(script)
                
            case .right:
                // Previous quality or seek backward
                let script = \"\"\"\n                    const video = document.querySelector('video');\n                    if (video && !video.seeking && video.duration > 0) {\n                        video.currentTime = Math.max(video.currentTime - 10, 0);\n                    }\n                \"\"\"\n                webView.evaluateJavaScript(script)
                
            case .up:
                // Volume up
                let script = \"\"\"\n                    const video = document.querySelector('video');\n                    if (video) {\n                        video.volume = Math.min(video.volume + 0.1, 1.0);\n                    }\n                \"\"\"\n                webView.evaluateJavaScript(script)
                
            case .down:
                // Volume down
                let script = \"\"\"\n                    const video = document.querySelector('video');\n                    if (video) {\n                        video.volume = Math.max(video.volume - 0.1, 0.0);\n                    }\n                \"\"\"\n                webView.evaluateJavaScript(script)
                
            default:
                break
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                hapticFeedback.impactOccurred()
                
                if let webView = gesture.view as? WKWebView {
                    let script = \"\"\"\n                        const video = document.querySelector('video');\n                        if (video) {\n                            window.webkit.messageHandlers.platformHandler.postMessage({\n                                type: 'streamInfo',\n                                platform: '\(parent.platform.rawValue)',\n                                currentTime: video.currentTime,\n                                duration: video.duration,\n                                volume: video.volume,\n                                muted: video.muted,\n                                paused: video.paused,\n                                width: video.videoWidth,\n                                height: video.videoHeight\n                            });\n                        }\n                    \"\"\"\n                    webView.evaluateJavaScript(script)
                }
            }
        }
    }
}

// MARK: - Stream Platform Enum (Using Platform from Models)
// StreamPlatform enum has been replaced with Platform from Models/Platform.swift

// MARK: - Platform Managers

class TwitchStreamManager: ObservableObject {
    func configure(webView: WKWebView, chatEnabled: Bool) {
        // Twitch-specific configuration
    }
    
    func buildEmbedURL(from url: String, quality: StreamQuality, muted: Bool) -> String {
        // Extract channel name from Twitch URL
        let components = url.components(separatedBy: "/")
        guard let channelName = components.last else { return url }
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "player.twitch.tv"
        
        urlComponents.queryItems = [
            URLQueryItem(name: "channel", value: channelName),
            URLQueryItem(name: "parent", value: "streamyyy.com"),
            URLQueryItem(name: "autoplay", value: "true"),
            URLQueryItem(name: "muted", value: muted ? "true" : "false"),
            URLQueryItem(name: "quality", value: quality.twitchValue),
            URLQueryItem(name: "allowfullscreen", value: "true"),
            URLQueryItem(name: "low_latency", value: "true")
        ]
        
        return urlComponents.url?.absoluteString ?? url
    }
    
    func updateSettings(webView: WKWebView, quality: StreamQuality, muted: Bool) {
        let script = \"\"\"\n            if (window.Twitch && window.Twitch.player) {\n                window.Twitch.player.setQuality('\(quality.twitchValue)');\n                window.Twitch.player.setMuted(\(muted));\n            }\n        \"\"\"\n        webView.evaluateJavaScript(script)
    }
    
    func onLoadComplete(webView: WKWebView) {
        // Twitch-specific post-load setup
        let script = \"\"\"\n            setTimeout(function() {\n                if (window.Twitch && window.Twitch.player) {\n                    window.webkit.messageHandlers.platformHandler.postMessage({\n                        type: 'twitchPlayerReady',\n                        quality: window.Twitch.player.getQuality(),\n                        volume: window.Twitch.player.getVolume()\n                    });\n                }\n            }, 2000);\n        \"\"\"\n        webView.evaluateJavaScript(script)
    }
}

class YouTubeStreamManager: ObservableObject {
    func configure(webView: WKWebView, chatEnabled: Bool) {
        // YouTube-specific configuration
    }
    
    func buildEmbedURL(from url: String, quality: StreamQuality, muted: Bool) -> String {
        var videoId = ""
        
        if url.contains("youtu.be/") {
            let components = url.components(separatedBy: "/")
            videoId = components.last?.components(separatedBy: "?").first ?? ""
        } else if url.contains("youtube.com/watch") {
            if let urlComponents = URLComponents(string: url),
               let queryItems = urlComponents.queryItems,
               let vParam = queryItems.first(where: { $0.name == "v" }) {
                videoId = vParam.value ?? ""
            }
        } else if url.contains("youtube.com/live/") {
            let components = url.components(separatedBy: "/")
            videoId = components.last ?? ""
        }
        
        guard !videoId.isEmpty else { return url }
        
        var params = [
            "autoplay=1",
            "controls=1",
            "rel=0",
            "modestbranding=1",
            "enablejsapi=1",
            "origin=https://streamyyy.com"
        ]
        
        if muted {
            params.append("mute=1")
        }
        
        return "https://www.youtube.com/embed/\(videoId)?\(params.joined(separator: "&"))"
    }
    
    func updateSettings(webView: WKWebView, quality: StreamQuality, muted: Bool) {
        let script = \"\"\"\n            if (window.YT && window.YT.Player) {\n                const iframe = document.querySelector('iframe');\n                if (iframe && iframe.contentWindow) {\n                    iframe.contentWindow.postMessage('\(muted ? "{\"event\":\"command\",\"func\":\"mute\",\"args\":\"\"}" : "{\"event\":\"command\",\"func\":\"unMute\",\"args\":\"\"}")' , '*');\n                }\n            }\n        \"\"\"\n        webView.evaluateJavaScript(script)
    }
    
    func onLoadComplete(webView: WKWebView) {
        // YouTube-specific post-load setup
        let script = \"\"\"\n            setTimeout(function() {\n                window.webkit.messageHandlers.platformHandler.postMessage({\n                    type: 'youtubePlayerReady'\n                });\n            }, 2000);\n        \"\"\"\n        webView.evaluateJavaScript(script)
    }
}

class KickStreamManager: ObservableObject {
    func configure(webView: WKWebView, chatEnabled: Bool) {
        // Kick-specific configuration
    }
    
    func buildEmbedURL(from url: String, quality: StreamQuality, muted: Bool) -> String {
        // Extract channel name from Kick URL
        let components = url.components(separatedBy: "/")
        guard let channelName = components.last else { return url }
        
        var params = [
            "autoplay=true",
            "muted=\(muted)"
        ]
        
        return "https://player.kick.com/\(channelName)?\(params.joined(separator: "&"))"
    }
    
    func updateSettings(webView: WKWebView, quality: StreamQuality, muted: Bool) {
        let script = \"\"\"\n            const video = document.querySelector('video');\n            if (video) {\n                video.muted = \(muted);\n            }\n        \"\"\"\n        webView.evaluateJavaScript(script)
    }
    
    func onLoadComplete(webView: WKWebView) {
        // Kick-specific post-load setup
        let script = \"\"\"\n            setTimeout(function() {\n                window.webkit.messageHandlers.platformHandler.postMessage({\n                    type: 'kickPlayerReady'\n                });\n            }, 2000);\n        \"\"\"\n        webView.evaluateJavaScript(script)
    }
}

// MARK: - Preview

#Preview {
    struct MultiPlatformPreview: View {
        @State private var isLoading = false
        @State private var hasError = false
        @State private var currentQuality = StreamQuality.auto
        @State private var isLive = false
        @State private var viewerCount = 0
        @State private var isMuted = false
        
        var body: some View {
            VStack(spacing: 16) {
                // Twitch stream
                MultiPlatformStreamView(
                    url: "https://twitch.tv/shroud",
                    platform: .twitch,
                    isLoading: $isLoading,
                    hasError: $hasError,
                    currentQuality: $currentQuality,
                    isLive: $isLive,
                    viewerCount: $viewerCount,
                    isMuted: $isMuted
                )
                .frame(height: 200)
                .cornerRadius(12)
                
                // YouTube stream
                MultiPlatformStreamView(
                    url: "https://youtube.com/watch?v=dQw4w9WgXcQ",
                    platform: .youtube,
                    isLoading: $isLoading,
                    hasError: $hasError,
                    currentQuality: $currentQuality,
                    isLive: $isLive,
                    viewerCount: $viewerCount,
                    isMuted: $isMuted
                )
                .frame(height: 200)
                .cornerRadius(12)
                
                // Kick stream
                MultiPlatformStreamView(
                    url: "https://kick.com/trainwreckstv",
                    platform: .kick,
                    isLoading: $isLoading,
                    hasError: $hasError,
                    currentQuality: $currentQuality,
                    isLive: $isLive,
                    viewerCount: $viewerCount,
                    isMuted: $isMuted
                )
                .frame(height: 200)
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    return MultiPlatformPreview()
}