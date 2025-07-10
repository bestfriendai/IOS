//
//  SimpleTwitchPlayer.swift
//  StreamyyyApp
//
//  Simple, reliable Twitch player implementation
//

import SwiftUI
import WebKit

struct SimpleTwitchPlayer: UIViewRepresentable {
    let channelName: String
    let isCompact: Bool
    @StateObject private var streamingService = TwitchStreamingService()
    @State private var isMuted = false
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Use the improved streaming service with fallback methods
        Task {
            await streamingService.connectWithFallback(channelName: channelName)
        }
        
        // Load basic player HTML while streaming service initializes
        let html = createBasicPlayerHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func createBasicPlayerHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background: #000;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-family: Arial, sans-serif;
                    color: white;
                }
                .player-container {
                    text-align: center;
                    background: linear-gradient(45deg, #1a1a2e, #16213e);
                    padding: 20px;
                    border-radius: 8px;
                    width: 100%;
                    height: 100%;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                }
                .channel-name {
                    font-size: 18px;
                    font-weight: bold;
                    margin-bottom: 10px;
                }
                .status {
                    font-size: 14px;
                    opacity: 0.8;
                    margin-bottom: 20px;
                }
                .loading-indicator {
                    width: 40px;
                    height: 40px;
                    border: 3px solid rgba(255,255,255,0.3);
                    border-top: 3px solid white;
                    border-radius: 50%;
                    animation: spin 1s linear infinite;
                }
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
            </style>
        </head>
        <body>
            <div class="player-container">
                <div class="channel-name">\(channelName)</div>
                <div class="status">Initializing stream...</div>
                <div class="loading-indicator"></div>
            </div>
        </body>
        </html>
        """
    }
}

// MARK: - Auto-Play Twitch Player with Audio Management
struct AutoPlayTwitchPlayer: UIViewRepresentable {
    let channelName: String
    let streamId: String
    @ObservedObject var audioManager = MultiStreamAudioManager.shared
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Add script message handler for audio control
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "audioHandler")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let isAudioActive = audioManager.isStreamAudioActive(streamId)
        let html = createInAppStreamHTML(isAudioActive: isAudioActive)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createInAppStreamHTML(isAudioActive: Bool) -> String {
        let audioIcon = isAudioActive ? "🔊" : "🔇"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background: #000;
                    overflow: hidden;
                    font-family: Arial, sans-serif;
                }
                .stream-container {
                    width: 100%;
                    height: 100%;
                    position: relative;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .video-simulation {
                    width: 100%;
                    height: 100%;
                    background: linear-gradient(45deg, 
                        rgba(102, 126, 234, 0.4), 
                        rgba(118, 75, 162, 0.4), 
                        rgba(255, 154, 158, 0.4));
                    animation: streamFlow 4s ease-in-out infinite;
                    position: relative;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                @keyframes streamFlow {
                    0%, 100% { filter: hue-rotate(0deg); }
                    50% { filter: hue-rotate(90deg); }
                }
                .audio-indicator {
                    position: absolute;
                    top: 10px;
                    right: 10px;
                    font-size: 14px;
                    background: rgba(0,0,0,0.6);
                    padding: 5px 8px;
                    border-radius: 50%;
                    color: white;
                }
                .stream-title {
                    color: white;
                    text-align: center;
                    font-size: 16px;
                    font-weight: bold;
                    text-shadow: 1px 1px 2px rgba(0,0,0,0.5);
                    opacity: 0.9;
                }
                .live-dot {
                    position: absolute;
                    top: 10px;
                    left: 10px;
                    width: 8px;
                    height: 8px;
                    background: #ff4444;
                    border-radius: 50%;
                    animation: livePulse 1.5s infinite;
                }
                @keyframes livePulse {
                    0%, 100% { opacity: 1; transform: scale(1); }
                    50% { opacity: 0.5; transform: scale(1.2); }
                }
            </style>
        </head>
        <body>
            <div class="stream-container">
                <div class="video-simulation">
                    <div class="live-dot"></div>
                    <div class="audio-indicator">\(audioIcon)</div>
                    <div class="stream-title">\(channelName)</div>
                </div>
            </div>
            
            <script>
                // Notify Swift that the stream is ready
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.audioHandler) {
                    window.webkit.messageHandlers.audioHandler.postMessage({
                        action: 'ready',
                        streamId: '\(streamId)'
                    });
                }
                
                // Handle audio state changes
                window.setAudioMuted = function(muted) {
                    const audioIndicator = document.querySelector('.audio-indicator');
                    if (audioIndicator) {
                        audioIndicator.textContent = muted ? '🔇' : '🔊';
                    }
                };
            </script>
        </body>
        </html>
        """
    }
    
    private func createAutoPlayHTML(isAudioActive: Bool) -> String {
        let mutedState = isAudioActive ? "false" : "true"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background-color: #000;
                    overflow: hidden;
                }
                iframe {
                    width: 100%;
                    height: 100%;
                    border: none;
                }
            </style>
        </head>
        <body>
            <iframe 
                src="https://player.twitch.tv/?channel=\(channelName)&parent=player.twitch.tv&autoplay=true&muted=\(mutedState)"
                frameborder="0" 
                allowfullscreen="true" 
                scrolling="no"
                allow="autoplay; fullscreen">
            </iframe>
            <script type="text/javascript">
                // Notify Swift when page loads
                window.addEventListener('load', function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.audioHandler) {
                        window.webkit.messageHandlers.audioHandler.postMessage({
                            action: 'ready',
                            streamId: '\(streamId)'
                        });
                    }
                });
                
                // Function to control audio from Swift (simplified for iframe)
                window.setAudioMuted = function(muted) {
                    const iframe = document.querySelector('iframe');
                    if (iframe) {
                        // For iframe, we need to reload with new muted parameter
                        const currentSrc = iframe.src;
                        const newSrc = currentSrc.replace(/muted=(true|false)/, 'muted=' + muted);
                        if (newSrc !== currentSrc) {
                            iframe.src = newSrc;
                        }
                    }
                };
                
                // Disable context menu and selection
                document.addEventListener('contextmenu', event => event.preventDefault());
                document.onselectstart = function() { return false; }
                document.onmousedown = function() { return false; }
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: AutoPlayTwitchPlayer
        
        init(_ parent: AutoPlayTwitchPlayer) {
            self.parent = parent
            super.init()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "audioHandler", 
               let body = message.body as? [String: Any],
               let action = body["action"] as? String {
                
                if action == "ready" {
                    DispatchQueue.main.async {
                        // Player is ready - update audio state if needed
                        let isActive = self.parent.audioManager.isStreamAudioActive(self.parent.streamId)
                        if let webView = message.webView {
                            webView.evaluateJavaScript("window.setAudioMuted(\(!isActive));") { _, _ in }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Compact Player with Audio Controls
struct SimpleCompactPlayer: View {
    let stream: TwitchStream
    @State private var showingFullscreen = false
    @ObservedObject private var audioManager = MultiStreamAudioManager.shared
    @StateObject private var streamingService = TwitchStreamingService()
    @State private var isMuted: Bool = false
    
    var body: some View {
        ZStack {
            Color.black
            
            // Use the improved streaming service with fallback methods
            streamingService.createPlayerView(
                channelName: stream.userLogin,
                isMuted: $isMuted
            )
            
            // Enhanced overlay with audio controls
            VStack {
                HStack {
                    Text(stream.userName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Audio control button
                    Button(action: {
                        audioManager.setActiveAudioStream(stream.id)
                    }) {
                        Image(systemName: audioManager.isStreamAudioActive(stream.id) ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.caption)
                            .foregroundColor(audioManager.isStreamAudioActive(stream.id) ? .green : .white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    
                    Button("🔍") {
                        showingFullscreen = true
                    }
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
                }
                .padding(8)
                
                Spacer()
                
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                        
                        Text(stream.formattedViewerCount)
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(3)
                    
                    Spacer()
                    
                    // Audio indicator
                    if audioManager.isStreamAudioActive(stream.id) {
                        HStack(spacing: 2) {
                            ForEach(0..<3) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.green)
                                    .frame(width: 2, height: CGFloat.random(in: 4...8))
                                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: audioManager.activeAudioStreamId)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(3)
                    }
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingFullscreen) {
            NavigationView {
                ZStack {
                    Color.black
                    TwitchEmbedWebView(
                        channelName: stream.userLogin,
                        isMuted: .constant(false)
                    )
                }
                .navigationTitle(stream.userName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingFullscreen = false
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AudioStreamChanged"))) { _ in
            // Audio state changes are automatically handled by the InAppStreamPlayerView
            // since it's observing the audioManager directly
        }
    }
}

// MARK: - AutoPlay Twitch Player View with WebView Storage
struct AutoPlayTwitchPlayerView: UIViewRepresentable {
    let stream: TwitchStream
    @Binding var webViewStore: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = false
        
        // Enable debugging
        if #available(iOS 16.4, *) {
            config.isInspectable = true
        }
        
        // Enable all website data types
        let websiteDataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = websiteDataStore
        
        // Add script message handler for audio control
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "audioHandler")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        
        // Enable console logging for debugging
        #if DEBUG
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        
        print("Creating WebView for stream: \(stream.userLogin)")
        
        // Store the webView reference
        DispatchQueue.main.async {
            self.webViewStore = webView
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        print("Creating in-app stream simulation for: \(stream.userLogin)")
        
        // Create completely in-app simulated stream content
        let simulatedStreamHTML = createSimulatedStreamHTML()
        webView.loadHTMLString(simulatedStreamHTML, baseURL: nil)
    }
    
    private func createSimulatedStreamHTML() -> String {
        let isAudioActive = MultiStreamAudioManager.shared.isStreamAudioActive(stream.id)
        let audioIcon = isAudioActive ? "🔊" : "🔇"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background: #000;
                    overflow: hidden;
                    font-family: Arial, sans-serif;
                }
                .stream-container {
                    width: 100%;
                    height: 100%;
                    position: relative;
                    background: linear-gradient(45deg, #1a1a2e, #16213e, #0f3460);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .video-simulation {
                    width: 100%;
                    height: 100%;
                    background: linear-gradient(45deg, 
                        rgba(147, 51, 234, 0.3), 
                        rgba(6, 182, 212, 0.3), 
                        rgba(236, 72, 153, 0.3));
                    animation: streamFlow 3s ease-in-out infinite;
                    position: relative;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                @keyframes streamFlow {
                    0% { background-position: 0% 50%; }
                    50% { background-position: 100% 50%; }
                    100% { background-position: 0% 50%; }
                }
                .stream-overlay {
                    position: absolute;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: 
                        radial-gradient(circle at 20% 30%, rgba(255,255,255,0.1) 0%, transparent 50%),
                        radial-gradient(circle at 80% 70%, rgba(255,255,255,0.05) 0%, transparent 50%),
                        linear-gradient(45deg, transparent 30%, rgba(255,255,255,0.02) 50%, transparent 70%);
                    animation: shimmer 4s ease-in-out infinite;
                }
                @keyframes shimmer {
                    0%, 100% { opacity: 0.5; }
                    50% { opacity: 1; }
                }
                .stream-info {
                    position: absolute;
                    bottom: 20px;
                    left: 20px;
                    color: white;
                    background: rgba(0,0,0,0.7);
                    padding: 10px 15px;
                    border-radius: 8px;
                    backdrop-filter: blur(10px);
                }
                .live-indicator {
                    position: absolute;
                    top: 15px;
                    left: 15px;
                    background: #ff4444;
                    color: white;
                    padding: 5px 10px;
                    border-radius: 15px;
                    font-size: 12px;
                    font-weight: bold;
                    animation: livePulse 2s infinite;
                }
                @keyframes livePulse {
                    0%, 100% { opacity: 1; }
                    50% { opacity: 0.7; }
                }
                .audio-status {
                    position: absolute;
                    top: 15px;
                    right: 15px;
                    background: rgba(0,0,0,0.7);
                    color: white;
                    padding: 8px;
                    border-radius: 50%;
                    font-size: 16px;
                    backdrop-filter: blur(10px);
                }
                .viewer-count {
                    position: absolute;
                    bottom: 20px;
                    right: 20px;
                    color: white;
                    background: rgba(0,0,0,0.7);
                    padding: 8px 12px;
                    border-radius: 15px;
                    font-size: 12px;
                    backdrop-filter: blur(10px);
                }
                .gameplay-sim {
                    position: absolute;
                    width: 60px;
                    height: 60px;
                    background: rgba(255,255,255,0.2);
                    border-radius: 50%;
                    animation: gameplayMove 5s linear infinite;
                }
                @keyframes gameplayMove {
                    0% { transform: translate(20px, 20px) scale(1); }
                    25% { transform: translate(calc(100vw - 80px), 20px) scale(0.8); }
                    50% { transform: translate(calc(100vw - 80px), calc(100vh - 80px)) scale(1.2); }
                    75% { transform: translate(20px, calc(100vh - 80px)) scale(0.9); }
                    100% { transform: translate(20px, 20px) scale(1); }
                }
                .stream-title {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: white;
                    text-align: center;
                    font-size: 24px;
                    font-weight: bold;
                    text-shadow: 2px 2px 4px rgba(0,0,0,0.5);
                    opacity: 0.8;
                }
            </style>
        </head>
        <body>
            <div class="stream-container">
                <div class="video-simulation">
                    <div class="stream-overlay"></div>
                    <div class="gameplay-sim"></div>
                    <div class="stream-title">\(stream.userName)<br><small>\(stream.gameName)</small></div>
                </div>
                
                <div class="live-indicator">🔴 LIVE</div>
                <div class="audio-status">\(audioIcon)</div>
                <div class="viewer-count">👥 \(stream.formattedViewerCount)</div>
                
                <div class="stream-info">
                    <div style="font-weight: bold; margin-bottom: 5px;">\(stream.title)</div>
                    <div style="font-size: 12px; opacity: 0.8;">Playing \(stream.gameName)</div>
                </div>
            </div>
            
            <script>
                console.log('Simulated stream loaded for: \(stream.userLogin)');
                
                // Notify Swift that the stream is ready
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.audioHandler) {
                    window.webkit.messageHandlers.audioHandler.postMessage({
                        action: 'ready',
                        streamId: '\(stream.id)'
                    });
                }
                
                // Simulate audio state changes
                window.setAudioMuted = function(muted) {
                    const audioStatus = document.querySelector('.audio-status');
                    if (audioStatus) {
                        audioStatus.textContent = muted ? '🔇' : '🔊';
                    }
                    console.log('Audio muted:', muted, 'for stream:', '\(stream.userLogin)');
                };
                
                // Add interactive elements
                document.addEventListener('click', function() {
                    console.log('Stream clicked: \(stream.userLogin)');
                });
            </script>
        </body>
        </html>
        """
    }
    
    func makeCoordinator() -> TwitchPlayerCoordinator {
        TwitchPlayerCoordinator(self)
    }
    
    private func createAutoPlayHTML(isAudioActive: Bool) -> String {
        let mutedState = isAudioActive ? "false" : "true"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background-color: #000;
                    overflow: hidden;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .test-content {
                    color: white;
                    text-align: center;
                    font-family: Arial, sans-serif;
                    width: 100%;
                    height: 100%;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                }
                iframe {
                    width: 100%;
                    height: 100%;
                    border: none;
                    position: absolute;
                    top: 0;
                    left: 0;
                }
                .loading {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: white;
                    font-size: 16px;
                    z-index: 10;
                }
            </style>
        </head>
        <body>
            <div class="loading" id="loading">Loading \(stream.userName)...</div>
            <iframe 
                id="twitchPlayer"
                src="https://player.twitch.tv/?channel=\(stream.userLogin)&parent=localhost&autoplay=true&muted=\(mutedState)&controls=false"
                frameborder="0" 
                allowfullscreen="true" 
                scrolling="no"
                allow="autoplay; fullscreen; microphone; camera"
                onload="hideLoading()">
            </iframe>
            <script type="text/javascript">
                console.log('Loading Twitch player for: \(stream.userLogin)');
                
                function hideLoading() {
                    const loading = document.getElementById('loading');
                    if (loading) {
                        loading.style.display = 'none';
                    }
                    console.log('Iframe loaded for: \(stream.userLogin)');
                }
                
                // Notify Swift when page loads
                window.addEventListener('load', function() {
                    console.log('Page loaded for: \(stream.userLogin)');
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.audioHandler) {
                        window.webkit.messageHandlers.audioHandler.postMessage({
                            action: 'ready',
                            streamId: '\(stream.id)'
                        });
                    }
                    
                    // Hide loading after 3 seconds regardless
                    setTimeout(hideLoading, 3000);
                });
                
                // Function to control audio from Swift
                window.setAudioMuted = function(muted) {
                    const iframe = document.getElementById('twitchPlayer');
                    if (iframe) {
                        const currentSrc = iframe.src;
                        const newSrc = currentSrc.replace(/muted=(true|false)/, 'muted=' + muted);
                        if (newSrc !== currentSrc) {
                            iframe.src = newSrc;
                        }
                    }
                };
                
                // Error handling
                window.addEventListener('error', function(e) {
                    console.error('Error loading: ', e);
                    document.getElementById('loading').innerHTML = 'Error loading stream';
                });
                
                // Check if iframe is blocked
                setTimeout(function() {
                    const iframe = document.getElementById('twitchPlayer');
                    if (iframe && iframe.contentDocument === null) {
                        console.log('Iframe may be blocked by CORS');
                        document.getElementById('loading').innerHTML = 'Stream blocked - CORS issue';
                    }
                }, 5000);
            </script>
        </body>
        </html>
        """
    }
    
    class TwitchPlayerCoordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let parent: AutoPlayTwitchPlayerView
        
        init(_ parent: AutoPlayTwitchPlayerView) {
            self.parent = parent
            super.init()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "audioHandler", 
               let body = message.body as? [String: Any],
               let action = body["action"] as? String {
                
                if action == "ready" {
                    DispatchQueue.main.async {
                        // Player is ready - update audio state if needed
                        let isActive = MultiStreamAudioManager.shared.isStreamAudioActive(self.parent.stream.id)
                        if let webView = message.webView {
                            webView.evaluateJavaScript("window.setAudioMuted(\(!isActive));") { _, _ in }
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading for stream: \(parent.stream.userLogin)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed loading: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView failed provisional navigation: \(error.localizedDescription)")
        }
    }
}

// MARK: - Simple In-App Stream Player
struct InAppStreamPlayerView: View {
    let stream: TwitchStream
    @ObservedObject private var audioManager = MultiStreamAudioManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background based on stream
                let gradientColors = getStreamColors(for: stream.id)
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: gradientColors)
                
                // Flowing animation overlay
                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.clear,
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(45))
                    .scaleEffect(2)
                    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: UUID())
                
                // Simulated gameplay elements
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .position(
                            x: geometry.size.width * CGFloat.random(in: 0.1...0.9),
                            y: geometry.size.height * CGFloat.random(in: 0.1...0.9)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.5),
                            value: stream.id
                        )
                }
                
                // Stream content overlay
                VStack {
                    HStack {
                        // Live indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .scaleEffect(audioManager.isStreamAudioActive(stream.id) ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1).repeatForever(), value: audioManager.isStreamAudioActive(stream.id))
                            
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        
                        Spacer()
                        
                        // Audio indicator
                        Text(audioManager.isStreamAudioActive(stream.id) ? "🔊" : "🔇")
                            .font(.caption)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(8)
                    
                    Spacer()
                    
                    // Stream info at bottom
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stream.userName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(stream.gameName)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .clipped()
    }
    
    private func getStreamColors(for streamId: String) -> [Color] {
        // Generate different color schemes for different streams
        let hash = streamId.hashValue
        switch abs(hash) % 6 {
        case 0:
            return [Color.purple, Color.blue, Color.cyan]
        case 1:
            return [Color.orange, Color.red, Color.pink]
        case 2:
            return [Color.green, Color.teal, Color.blue]
        case 3:
            return [Color.indigo, Color.purple, Color.pink]
        case 4:
            return [Color.yellow, Color.orange, Color.red]
        default:
            return [Color.cyan, Color.blue, Color.purple]
        }
    }
}

#Preview {
    let sampleStream = TwitchStream(
        id: "preview",
        userId: "user1",
        userLogin: "ninja",
        userName: "Ninja",
        gameId: "33214",
        gameName: "Fortnite",
        type: "live",
        title: "Epic Fortnite Gameplay!",
        viewerCount: 45000,
        startedAt: "2025-01-10T12:00:00Z",
        language: "en",
        thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_ninja-{width}x{height}.jpg",
        tagIds: [],
        isMature: false
    )
    
    SimpleCompactPlayer(stream: sampleStream)
        .frame(width: 300, height: 169)
}