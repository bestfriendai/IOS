//
//  UnifiedStreamPlayerEngine.swift
//  StreamyyyApp
//
//  Unified, production-ready stream player engine that consolidates all streaming functionality
//  Resolves CORS issues, provides robust error handling, and supports both Twitch and YouTube
//  Created by Claude Code on 2025-07-11
//

import SwiftUI
import WebKit
import AVKit
import Combine

/// Main stream player engine that consolidates all streaming functionality
/// This replaces WorkingTwitchPlayer, MultiStreamTwitchPlayer, SimpleTwitchPlayer, etc.
@MainActor
public final class UnifiedStreamPlayerEngine: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var playbackState: StreamPlaybackState = .idle
    @Published public var isLoading = false
    @Published public var hasError = false
    @Published public var errorMessage = ""
    @Published public var isBuffering = false
    @Published public var currentQuality: StreamQuality = .auto
    @Published public var volume: Double = 1.0
    @Published public var isMuted = false
    @Published public var viewerCount = 0
    @Published public var streamHealth: StreamHealthStatus = .unknown
    
    // MARK: - Private Properties
    private var webView: WKWebView?
    private var currentStream: Stream?
    private var retryCount = 0
    private let maxRetries = 3
    private var healthCheckTimer: Timer?
    private var qualityCheckTimer: Timer?
    private var adaptiveQualityTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Quality Management
    private var availableQualities: [StreamQuality] = []
    private var lastQualityChange = Date()
    private var qualityChangeCooldown: TimeInterval = 30.0
    private var bufferingCount = 0
    private var lastBufferTime = Date()
    private var networkQuality: NetworkQuality = .unknown
    private var bandwidthEstimate: Double = 0.0 // Mbps
    
    // Callbacks
    public var onStreamReady: (() -> Void)?
    public var onStreamError: ((StreamError) -> Void)?
    public var onQualityChanged: ((StreamQuality) -> Void)?
    public var onViewerCountUpdate: ((Int) -> Void)?
    public var onNetworkQualityChanged: ((NetworkQuality) -> Void)?
    public var onAdaptiveQualityChange: ((StreamQuality, StreamQuality) -> Void)? // from, to
    
    // MARK: - Initialization
    public override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Interface
    
    /// Load and play a stream with automatic platform detection and optimization
    public func loadStream(_ stream: Stream) {
        currentStream = stream
        isLoading = true
        hasError = false
        errorMessage = ""
        retryCount = 0
        
        print("🚀 Loading stream: \(stream.displayTitle) from \(stream.platform.displayName)")
        
        // Reset state
        playbackState = .loading
        streamHealth = .unknown
        
        // Create optimized web view for the platform
        createOptimizedWebView(for: stream)
        
        // Start health monitoring
        startHealthMonitoring()
        
        // Start adaptive quality monitoring
        startAdaptiveQualityMonitoring()
        
        // Load content based on platform
        switch stream.platform {
        case .twitch:
            loadTwitchStream(stream)
        case .youtube:
            loadYouTubeStream(stream)
        default:
            loadGenericStream(stream)
        }
    }
    
    /// Pause the current stream
    public func pause() {
        guard let webView = webView else { return }
        
        let pauseScript = """
            if (window.streamPlayer) {
                if (window.streamPlayer.pause) {
                    window.streamPlayer.pause();
                } else if (window.streamPlayer.getPlayer && window.streamPlayer.getPlayer().pause) {
                    window.streamPlayer.getPlayer().pause();
                }
            }
            if (window.twitchPlayer && window.twitchPlayer.pause) {
                window.twitchPlayer.pause();
            }
            if (window.youtubePlayer && window.youtubePlayer.pauseVideo) {
                window.youtubePlayer.pauseVideo();
            }
        """
        
        webView.evaluateJavaScript(pauseScript) { _, error in
            if let error = error {
                print("❌ Pause error: \(error)")
            } else {
                self.playbackState = .paused
            }
        }
    }
    
    /// Resume the current stream
    public func resume() {
        guard let webView = webView else { return }
        
        let playScript = """
            if (window.streamPlayer) {
                if (window.streamPlayer.play) {
                    window.streamPlayer.play();
                } else if (window.streamPlayer.getPlayer && window.streamPlayer.getPlayer().play) {
                    window.streamPlayer.getPlayer().play();
                }
            }
            if (window.twitchPlayer && window.twitchPlayer.play) {
                window.twitchPlayer.play();
            }
            if (window.youtubePlayer && window.youtubePlayer.playVideo) {
                window.youtubePlayer.playVideo();
            }
        """
        
        webView.evaluateJavaScript(playScript) { _, error in
            if let error = error {
                print("❌ Play error: \(error)")
            } else {
                self.playbackState = .playing
            }
        }
    }
    
    /// Set volume (0.0 to 1.0)
    public func setVolume(_ newVolume: Double) {
        let clampedVolume = max(0.0, min(1.0, newVolume))
        volume = clampedVolume
        
        guard let webView = webView else { return }
        
        let volumeScript = """
            const volume = \(clampedVolume);
            if (window.streamPlayer && window.streamPlayer.setVolume) {
                window.streamPlayer.setVolume(volume);
            }
            if (window.twitchPlayer && window.twitchPlayer.setVolume) {
                window.twitchPlayer.setVolume(volume);
            }
            if (window.youtubePlayer && window.youtubePlayer.setVolume) {
                window.youtubePlayer.setVolume(volume * 100);
            }
        """
        
        webView.evaluateJavaScript(volumeScript)
    }
    
    /// Mute or unmute the stream
    public func setMuted(_ muted: Bool) {
        isMuted = muted
        
        guard let webView = webView else { return }
        
        let muteScript = """
            const muted = \(muted);
            if (window.streamPlayer && window.streamPlayer.setMuted) {
                window.streamPlayer.setMuted(muted);
            }
            if (window.twitchPlayer && window.twitchPlayer.setMuted) {
                window.twitchPlayer.setMuted(muted);
            }
            if (window.youtubePlayer) {
                if (muted && window.youtubePlayer.mute) {
                    window.youtubePlayer.mute();
                } else if (!muted && window.youtubePlayer.unMute) {
                    window.youtubePlayer.unMute();
                }
            }
        """
        
        webView.evaluateJavaScript(muteScript)
    }
    
    /// Change stream quality manually or automatically
    public func setQuality(_ quality: StreamQuality, isAdaptive: Bool = false) {
        // Prevent rapid quality changes unless it's an adaptive adjustment
        let timeSinceLastChange = Date().timeIntervalSince(lastQualityChange)
        if !isAdaptive && timeSinceLastChange < qualityChangeCooldown {
            print("⏳ Quality change blocked - cooldown active (\(Int(qualityChangeCooldown - timeSinceLastChange))s remaining)")
            return
        }
        
        currentQuality = quality
        lastQualityChange = Date()
        
        guard let webView = webView else { return }
        
        let qualityScript = """
            const quality = '\(quality.rawValue)';
            const isAdaptive = \(isAdaptive);
            
            console.log(`🎥 Changing quality to: ${quality} (adaptive: ${isAdaptive})`);
            
            if (window.streamPlayer && window.streamPlayer.setQuality) {
                window.streamPlayer.setQuality(quality);
            }
            if (window.twitchPlayer && window.twitchPlayer.setQuality) {
                window.twitchPlayer.setQuality(quality);
            }
            if (window.youtubePlayer && window.youtubePlayer.setPlaybackQuality) {
                const ytQuality = quality === 'auto' ? 'default' : quality;
                window.youtubePlayer.setPlaybackQuality(ytQuality);
            }
            
            // Notify about quality change
            if (window.webkit?.messageHandlers?.streamEvents) {
                window.webkit.messageHandlers.streamEvents.postMessage({
                    event: 'qualityChanged',
                    quality: quality,
                    isAdaptive: isAdaptive,
                    timestamp: Date.now()
                });
            }
        """
        
        webView.evaluateJavaScript(qualityScript)
        onQualityChanged?(quality)
        
        let changeType = isAdaptive ? "adaptive" : "manual"
        print("✅ Quality changed to \(quality.displayName) (\(changeType))")
    }
    
    /// Retry loading the current stream
    public func retry() {
        guard let stream = currentStream else { return }
        
        retryCount += 1
        if retryCount <= maxRetries {
            print("🔄 Retrying stream load (attempt \(retryCount)/\(maxRetries))")
            loadStream(stream)
        } else {
            hasError = true
            errorMessage = "Failed to load stream after \(maxRetries) attempts"
            playbackState = .error
            onStreamError?(.connectionFailed)
        }
    }
    
    /// Get the web view for embedding in UI
    public func getWebView() -> WKWebView? {
        return webView
    }
    
    /// Clean up resources
    public func cleanup() {
        healthCheckTimer?.invalidate()
        qualityCheckTimer?.invalidate()
        adaptiveQualityTimer?.invalidate()
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
        currentStream = nil
        cancellables.removeAll()
        playbackState = .idle
        
        // Reset quality management state
        availableQualities.removeAll()
        bufferingCount = 0
        networkQuality = .unknown
        bandwidthEstimate = 0.0
    }
}

// MARK: - Private Implementation
extension UnifiedStreamPlayerEngine {
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.pause()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                if self?.playbackState == .paused {
                    self?.resume()
                }
            }
            .store(in: &cancellables)
    }
    
    private func createOptimizedWebView(for stream: Stream) {
        let configuration = WKWebViewConfiguration()
        
        // Essential media settings
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = stream.canPlayPictureInPicture
        
        // Performance optimizations
        configuration.processPool = SharedWebViewProcessPool.shared.processPool
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        
        // Security settings
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Message handlers for communication
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "streamEvents")
        userContentController.add(self, name: "streamError")
        userContentController.add(self, name: "streamMetrics")
        configuration.userContentController = userContentController
        
        // User agent for better compatibility
        configuration.applicationNameForUserAgent = "StreamyyyApp/1.0 Mobile Safari"
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
        webView?.isOpaque = false
        webView?.backgroundColor = UIColor.black
        webView?.scrollView.isScrollEnabled = false
        webView?.scrollView.bounces = false
        webView?.scrollView.showsVerticalScrollIndicator = false
        webView?.scrollView.showsHorizontalScrollIndicator = false
    }
    
    private func loadTwitchStream(_ stream: Stream) {
        guard let channelName = stream.getChannelName() else {
            handleError(.invalidURL)
            return
        }
        
        let html = createTwitchEmbedHTML(
            channelName: channelName,
            quality: currentQuality,
            muted: isMuted,
            volume: volume
        )
        
        webView?.loadHTMLString(html, baseURL: URL(string: "https://streamyyy.com"))
    }
    
    private func loadYouTubeStream(_ stream: Stream) {
        guard let videoId = extractYouTubeVideoId(from: stream.url) else {
            handleError(.invalidURL)
            return
        }
        
        let html = createYouTubeEmbedHTML(
            videoId: videoId,
            quality: currentQuality,
            muted: isMuted,
            volume: volume
        )
        
        webView?.loadHTMLString(html, baseURL: URL(string: "https://streamyyy.com"))
    }
    
    private func loadGenericStream(_ stream: Stream) {
        // For other platforms, try direct loading
        if let url = URL(string: stream.url) {
            webView?.load(URLRequest(url: url))
        } else {
            handleError(.invalidURL)
        }
    }
    
    private func createTwitchEmbedHTML(channelName: String, quality: StreamQuality, muted: Bool, volume: Double) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body {
                    width: 100%; height: 100%;
                    background: #000; overflow: hidden;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                }
                #twitch-embed {
                    position: absolute; top: 0; left: 0;
                    width: 100%; height: 100%; border: none;
                }
                .loading {
                    position: absolute; top: 50%; left: 50%;
                    transform: translate(-50%, -50%);
                    color: white; font-size: 14px; text-align: center;
                }
                .error {
                    position: absolute; top: 50%; left: 50%;
                    transform: translate(-50%, -50%);
                    color: #ff4444; font-size: 12px; text-align: center;
                    max-width: 80%; word-wrap: break-word;
                }
            </style>
        </head>
        <body>
            <div id="twitch-embed"></div>
            <div id="loading" class="loading">Loading \(channelName)...</div>
            
            <script src="https://embed.twitch.tv/embed/v1.js"></script>
            <script>
                console.log('🎮 Initializing Twitch player for:', '\(channelName)');
                
                let player = null;
                let isReady = false;
                let retryCount = 0;
                const maxRetries = 3;
                
                function notifyNative(event, data = {}) {
                    try {
                        const message = { event, ...data };
                        if (window.webkit?.messageHandlers?.streamEvents) {
                            window.webkit.messageHandlers.streamEvents.postMessage(message);
                        }
                    } catch (e) {
                        console.error('Failed to notify native:', e);
                    }
                }
                
                function notifyError(message, details = {}) {
                    console.error('❌ Twitch Player Error:', message, details);
                    if (window.webkit?.messageHandlers?.streamError) {
                        window.webkit.messageHandlers.streamError.postMessage({
                            message, details, channel: '\(channelName)'
                        });
                    }
                }
                
                function initializePlayer() {
                    try {
                        // Multiple parent domains for CORS compatibility
                        const parentDomains = [
                            'streamyyy.com',
                            'localhost',
                            'twitch.tv',
                            'player.twitch.tv',
                            '127.0.0.1'
                        ];
                        
                        const embedOptions = {
                            width: '100%',
                            height: '100%',
                            channel: '\(channelName)',
                            parent: parentDomains,
                            autoplay: true,
                            muted: \(muted),
                            controls: false,
                            allowfullscreen: false,
                            playsinline: true,
                            layout: 'video',
                            quality: '\(quality.twitchValue)',
                            time: '0h0m0s'
                        };
                        
                        console.log('🔧 Creating Twitch embed with options:', embedOptions);
                        
                        player = new Twitch.Embed('twitch-embed', embedOptions);
                        window.streamPlayer = player;
                        window.twitchPlayer = player;
                        
                        // Event listeners
                        player.addEventListener(Twitch.Embed.VIDEO_READY, handleVideoReady);
                        player.addEventListener(Twitch.Embed.VIDEO_PLAY, handleVideoPlay);
                        player.addEventListener(Twitch.Embed.VIDEO_PAUSE, handleVideoPause);
                        player.addEventListener(Twitch.Embed.VIDEO_ERROR, handleVideoError);
                        
                        // Hide loading indicator
                        const loading = document.getElementById('loading');
                        if (loading) loading.style.display = 'none';
                        
                    } catch (error) {
                        console.error('💥 Failed to initialize Twitch player:', error);
                        retryInitialization(error.message);
                    }
                }
                
                function handleVideoReady() {
                    console.log('✅ Twitch player ready');
                    isReady = true;
                    
                    try {
                        const videoPlayer = player.getPlayer();
                        window.twitchVideoPlayer = videoPlayer;
                        
                        // Set initial state
                        if (videoPlayer) {
                            videoPlayer.setMuted(\(muted));
                            videoPlayer.setVolume(\(volume));
                            videoPlayer.setQuality('\(quality.twitchValue)');
                        }
                        
                        notifyNative('ready', {
                            channel: '\(channelName)',
                            platform: 'twitch'
                        });
                        
                        // Start monitoring
                        startHealthMonitoring();
                        
                    } catch (error) {
                        console.error('❌ Error in video ready handler:', error);
                        notifyError('Video ready handler error', { error: error.message });
                    }
                }
                
                function handleVideoPlay() {
                    console.log('▶️ Twitch video playing');
                    notifyNative('playing', { channel: '\(channelName)' });
                }
                
                function handleVideoPause() {
                    console.log('⏸️ Twitch video paused');
                    notifyNative('paused', { channel: '\(channelName)' });
                }
                
                function handleVideoError(error) {
                    console.error('❌ Twitch video error:', error);
                    notifyError('Twitch video error', { error: JSON.stringify(error) });
                }
                
                function retryInitialization(error) {
                    retryCount++;
                    if (retryCount <= maxRetries) {
                        console.log(`🔄 Retrying initialization (${retryCount}/${maxRetries})`);
                        setTimeout(() => {
                            initializePlayer();
                        }, 2000 * retryCount);
                    } else {
                        showError(`Failed to load after ${maxRetries} attempts: ${error}`);
                        notifyError('Max retries exceeded', { originalError: error });
                    }
                }
                
                function showError(message) {
                    const loading = document.getElementById('loading');
                    if (loading) {
                        loading.className = 'error';
                        loading.innerHTML = message + '<br><small>Check internet connection</small>';
                    }
                }
                
                function startHealthMonitoring() {
                    setInterval(() => {
                        if (window.twitchVideoPlayer) {
                            try {
                                // Monitor stream health
                                const isPaused = window.twitchVideoPlayer.isPaused();
                                const currentTime = window.twitchVideoPlayer.getCurrentTime();
                                
                                if (window.webkit?.messageHandlers?.streamMetrics) {
                                    window.webkit.messageHandlers.streamMetrics.postMessage({
                                        channel: '\(channelName)',
                                        isPaused,
                                        currentTime,
                                        timestamp: Date.now()
                                    });
                                }
                            } catch (e) {
                                console.warn('Health monitoring error:', e);
                            }
                        }
                    }, 5000);
                }
                
                // Enhanced player API for external control
                window.streamPlayer = {
                    play: () => window.twitchVideoPlayer?.play(),
                    pause: () => window.twitchVideoPlayer?.pause(),
                    setMuted: (muted) => window.twitchVideoPlayer?.setMuted(muted),
                    setVolume: (volume) => window.twitchVideoPlayer?.setVolume(volume),
                    setQuality: (quality) => window.twitchVideoPlayer?.setQuality(quality),
                    getChannel: () => '\(channelName)',
                    getPlatform: () => 'twitch',
                    isReady: () => isReady,
                    getPlayer: () => window.twitchVideoPlayer
                };
                
                // Initialize when page loads
                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', initializePlayer);
                } else {
                    setTimeout(initializePlayer, 100);
                }
                
                // Cleanup on page unload
                window.addEventListener('beforeunload', () => {
                    if (window.twitchVideoPlayer) {
                        window.twitchVideoPlayer.pause();
                    }
                });
                
                // Prevent context menu and selection
                document.addEventListener('contextmenu', e => e.preventDefault());
                document.addEventListener('selectstart', e => e.preventDefault());
            </script>
        </body>
        </html>
        """
    }
    
    private func createYouTubeEmbedHTML(videoId: String, quality: StreamQuality, muted: Bool, volume: Double) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body {
                    width: 100%; height: 100%;
                    background: #000; overflow: hidden;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                }
                #youtube-player {
                    position: absolute; top: 0; left: 0;
                    width: 100%; height: 100%;
                }
                .loading {
                    position: absolute; top: 50%; left: 50%;
                    transform: translate(-50%, -50%);
                    color: white; font-size: 14px; text-align: center;
                }
                .error {
                    position: absolute; top: 50%; left: 50%;
                    transform: translate(-50%, -50%);
                    color: #ff4444; font-size: 12px; text-align: center;
                    max-width: 80%; word-wrap: break-word;
                }
            </style>
        </head>
        <body>
            <div id="youtube-player"></div>
            <div id="loading" class="loading">Loading YouTube stream...</div>
            
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
                console.log('📺 Initializing YouTube player for:', '\(videoId)');
                
                let player = null;
                let isReady = false;
                let retryCount = 0;
                const maxRetries = 3;
                
                function notifyNative(event, data = {}) {
                    try {
                        const message = { event, ...data };
                        if (window.webkit?.messageHandlers?.streamEvents) {
                            window.webkit.messageHandlers.streamEvents.postMessage(message);
                        }
                    } catch (e) {
                        console.error('Failed to notify native:', e);
                    }
                }
                
                function notifyError(message, details = {}) {
                    console.error('❌ YouTube Player Error:', message, details);
                    if (window.webkit?.messageHandlers?.streamError) {
                        window.webkit.messageHandlers.streamError.postMessage({
                            message, details, videoId: '\(videoId)'
                        });
                    }
                }
                
                function onYouTubeIframeAPIReady() {
                    initializePlayer();
                }
                
                function initializePlayer() {
                    try {
                        const playerVars = {
                            autoplay: 1,
                            mute: \(muted ? 1 : 0),
                            controls: 0,
                            disablekb: 1,
                            fs: 0,
                            modestbranding: 1,
                            playsinline: 1,
                            rel: 0,
                            showinfo: 0,
                            iv_load_policy: 3,
                            cc_load_policy: 0,
                            origin: 'https://streamyyy.com',
                            enablejsapi: 1
                        };
                        
                        console.log('🔧 Creating YouTube player with vars:', playerVars);
                        
                        player = new YT.Player('youtube-player', {
                            videoId: '\(videoId)',
                            width: '100%',
                            height: '100%',
                            playerVars: playerVars,
                            events: {
                                onReady: handlePlayerReady,
                                onStateChange: handleStateChange,
                                onError: handlePlayerError,
                                onPlaybackQualityChange: handleQualityChange
                            }
                        });
                        
                        window.streamPlayer = player;
                        window.youtubePlayer = player;
                        
                        // Hide loading indicator
                        const loading = document.getElementById('loading');
                        if (loading) loading.style.display = 'none';
                        
                    } catch (error) {
                        console.error('💥 Failed to initialize YouTube player:', error);
                        retryInitialization(error.message);
                    }
                }
                
                function handlePlayerReady(event) {
                    console.log('✅ YouTube player ready');
                    isReady = true;
                    
                    try {
                        // Set initial volume
                        event.target.setVolume(\(volume * 100));
                        
                        notifyNative('ready', {
                            videoId: '\(videoId)',
                            platform: 'youtube'
                        });
                        
                        // Start monitoring
                        startHealthMonitoring();
                        
                    } catch (error) {
                        console.error('❌ Error in player ready handler:', error);
                        notifyError('Player ready handler error', { error: error.message });
                    }
                }
                
                function handleStateChange(event) {
                    const state = event.data;
                    switch (state) {
                        case YT.PlayerState.PLAYING:
                            console.log('▶️ YouTube video playing');
                            notifyNative('playing', { videoId: '\(videoId)' });
                            break;
                        case YT.PlayerState.PAUSED:
                            console.log('⏸️ YouTube video paused');
                            notifyNative('paused', { videoId: '\(videoId)' });
                            break;
                        case YT.PlayerState.BUFFERING:
                            console.log('⏳ YouTube video buffering');
                            notifyNative('buffering', { videoId: '\(videoId)' });
                            break;
                        case YT.PlayerState.ENDED:
                            console.log('🏁 YouTube video ended');
                            notifyNative('ended', { videoId: '\(videoId)' });
                            break;
                    }
                }
                
                function handlePlayerError(event) {
                    const errorCode = event.data;
                    const errorMessages = {
                        2: 'Invalid video ID',
                        5: 'HTML5 player error',
                        100: 'Video not found or private',
                        101: 'Embedding not allowed',
                        150: 'Embedding not allowed'
                    };
                    
                    const message = errorMessages[errorCode] || `Unknown error (${errorCode})`;
                    console.error('❌ YouTube player error:', message);
                    notifyError('YouTube player error', { code: errorCode, message });
                }
                
                function handleQualityChange(event) {
                    const quality = event.data;
                    console.log('🎥 Quality changed to:', quality);
                    notifyNative('qualityChanged', { videoId: '\(videoId)', quality });
                }
                
                function retryInitialization(error) {
                    retryCount++;
                    if (retryCount <= maxRetries) {
                        console.log(`🔄 Retrying initialization (${retryCount}/${maxRetries})`);
                        setTimeout(() => {
                            initializePlayer();
                        }, 2000 * retryCount);
                    } else {
                        showError(`Failed to load after ${maxRetries} attempts: ${error}`);
                        notifyError('Max retries exceeded', { originalError: error });
                    }
                }
                
                function showError(message) {
                    const loading = document.getElementById('loading');
                    if (loading) {
                        loading.className = 'error';
                        loading.innerHTML = message + '<br><small>Check video availability</small>';
                    }
                }
                
                function startHealthMonitoring() {
                    setInterval(() => {
                        if (window.youtubePlayer && window.youtubePlayer.getPlayerState) {
                            try {
                                const state = window.youtubePlayer.getPlayerState();
                                const currentTime = window.youtubePlayer.getCurrentTime();
                                const duration = window.youtubePlayer.getDuration();
                                
                                if (window.webkit?.messageHandlers?.streamMetrics) {
                                    window.webkit.messageHandlers.streamMetrics.postMessage({
                                        videoId: '\(videoId)',
                                        state,
                                        currentTime,
                                        duration,
                                        timestamp: Date.now()
                                    });
                                }
                            } catch (e) {
                                console.warn('Health monitoring error:', e);
                            }
                        }
                    }, 5000);
                }
                
                // Enhanced player API for external control
                window.streamPlayer = {
                    playVideo: () => window.youtubePlayer?.playVideo(),
                    pauseVideo: () => window.youtubePlayer?.pauseVideo(),
                    mute: () => window.youtubePlayer?.mute(),
                    unMute: () => window.youtubePlayer?.unMute(),
                    setVolume: (volume) => window.youtubePlayer?.setVolume(volume),
                    setPlaybackQuality: (quality) => window.youtubePlayer?.setPlaybackQuality(quality),
                    getVideoId: () => '\(videoId)',
                    getPlatform: () => 'youtube',
                    isReady: () => isReady,
                    getPlayer: () => window.youtubePlayer
                };
                
                // Legacy compatibility
                window.streamPlayer.play = window.streamPlayer.playVideo;
                window.streamPlayer.pause = window.streamPlayer.pauseVideo;
                window.streamPlayer.setMuted = (muted) => {
                    if (muted) window.streamPlayer.mute();
                    else window.streamPlayer.unMute();
                };
                
                // Initialize if API is already loaded
                if (window.YT && window.YT.Player) {
                    setTimeout(initializePlayer, 100);
                }
                
                // Cleanup on page unload
                window.addEventListener('beforeunload', () => {
                    if (window.youtubePlayer) {
                        window.youtubePlayer.pauseVideo();
                    }
                });
                
                // Prevent context menu and selection
                document.addEventListener('contextmenu', e => e.preventDefault());
                document.addEventListener('selectstart', e => e.preventDefault());
            </script>
        </body>
        </html>
        """
    }
    
    private func extractYouTubeVideoId(from url: String) -> String? {
        // Extract video ID from various YouTube URL formats
        let patterns = [
            "(?:youtube\\.com/watch\\?v=|youtu\\.be/|youtube\\.com/embed/)([a-zA-Z0-9_-]{11})",
            "youtube\\.com/live/([a-zA-Z0-9_-]{11})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        
        return nil
    }
    
    private func startHealthMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkStreamHealth()
        }
    }
    
    private func startAdaptiveQualityMonitoring() {
        adaptiveQualityTimer?.invalidate()
        adaptiveQualityTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.checkAdaptiveQuality()
        }
        
        // Initial quality assessment after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.assessInitialQuality()
        }
    }
    
    private func assessInitialQuality() {
        guard currentQuality == .auto else { return }
        
        // Get available qualities from the player
        getAvailableQualities { [weak self] qualities in
            self?.availableQualities = qualities
            self?.determineOptimalQuality()
        }
    }
    
    private func checkAdaptiveQuality() {
        guard currentQuality == .auto || shouldForceQualityChange() else { return }
        
        // Get current network conditions
        updateNetworkConditions { [weak self] in
            self?.evaluateQualityAdjustment()
        }
    }
    
    private func shouldForceQualityChange() -> Bool {
        // Force quality change if experiencing frequent buffering
        let bufferingThreshold = 3
        let bufferingTimeWindow: TimeInterval = 60.0 // 1 minute
        
        let recentBufferingTime = Date().timeIntervalSince(lastBufferTime)
        if recentBufferingTime <= bufferingTimeWindow && bufferingCount >= bufferingThreshold {
            return true
        }
        
        return false
    }
    
    private func updateNetworkConditions(completion: @escaping () -> Void) {
        guard let webView = webView else {
            completion()
            return
        }
        
        let networkScript = """
            const networkInfo = {
                timestamp: Date.now(),
                connectionType: navigator.connection?.effectiveType || 'unknown',
                downlink: navigator.connection?.downlink || 0,
                rtt: navigator.connection?.rtt || 0,
                saveData: navigator.connection?.saveData || false
            };
            
            // Estimate bandwidth based on video element if available
            const video = document.querySelector('video');
            if (video && video.getVideoPlaybackQuality) {
                const quality = video.getVideoPlaybackQuality();
                networkInfo.droppedFrames = quality.droppedVideoFrames;
                networkInfo.totalFrames = quality.totalVideoFrames;
                networkInfo.creationTime = quality.creationTime;
            }
            
            networkInfo;
        """
        
        webView.evaluateJavaScript(networkScript) { [weak self] result, error in
            if let networkData = result as? [String: Any] {
                self?.processNetworkData(networkData)
            }
            completion()
        }
    }
    
    private func processNetworkData(_ data: [String: Any]) {
        let previousNetworkQuality = networkQuality
        
        // Process connection type
        if let connectionType = data["connectionType"] as? String {
            networkQuality = NetworkQuality.from(connectionType: connectionType)
        }
        
        // Process bandwidth estimate
        if let downlink = data["downlink"] as? Double {
            bandwidthEstimate = downlink
        }
        
        // Check for dropped frames (video quality issues)
        if let droppedFrames = data["droppedFrames"] as? Int,
           let totalFrames = data["totalFrames"] as? Int,
           totalFrames > 0 {
            let dropRate = Double(droppedFrames) / Double(totalFrames)
            if dropRate > 0.05 { // More than 5% dropped frames
                networkQuality = .degraded(dropRate)
            }
        }
        
        // Notify about network quality changes
        if case .unknown = previousNetworkQuality {
            // Don't trigger callback for initial unknown state
        } else if !networkQuality.isEquivalent(to: previousNetworkQuality) {
            onNetworkQualityChanged?(networkQuality)
        }
        
        print("📶 Network conditions - Quality: \(networkQuality), Bandwidth: \(bandwidthEstimate) Mbps")
    }
    
    private func evaluateQualityAdjustment() {
        let recommendedQuality = determineOptimalQuality()
        
        if recommendedQuality != currentQuality {
            let shouldDowngrade = recommendedQuality.bitrateRequirement < currentQuality.bitrateRequirement
            let shouldUpgrade = recommendedQuality.bitrateRequirement > currentQuality.bitrateRequirement
            
            if shouldDowngrade {
                print("📉 Downgrading quality due to network conditions: \(currentQuality.displayName) → \(recommendedQuality.displayName)")
                let previousQuality = currentQuality
                setQuality(recommendedQuality, isAdaptive: true)
                onAdaptiveQualityChange?(previousQuality, recommendedQuality)
            } else if shouldUpgrade && bufferingCount < 2 {
                print("📈 Upgrading quality due to improved conditions: \(currentQuality.displayName) → \(recommendedQuality.displayName)")
                let previousQuality = currentQuality
                setQuality(recommendedQuality, isAdaptive: true)
                onAdaptiveQualityChange?(previousQuality, recommendedQuality)
            }
        }
    }
    
    @discardableResult
    private func determineOptimalQuality() -> StreamQuality {
        // If manual quality is set (not auto), respect user choice unless forcing
        if currentQuality != .auto && !shouldForceQualityChange() {
            return currentQuality
        }
        
        // Determine quality based on network conditions
        let baseQuality = networkQuality.recommendedQuality
        let bandwidthQuality = StreamQuality.fromBandwidth(bandwidthEstimate)
        
        // Use the more conservative of the two recommendations
        let recommendedQuality = min(baseQuality, bandwidthQuality)
        
        // Ensure the quality is available
        if !availableQualities.isEmpty {
            let availableQuality = availableQualities.first { $0.bitrateRequirement <= recommendedQuality.bitrateRequirement }
            return availableQuality ?? .low
        }
        
        return recommendedQuality
    }
    
    private func getAvailableQualities(completion: @escaping ([StreamQuality]) -> Void) {
        guard let webView = webView else {
            completion([])
            return
        }
        
        let qualityScript = """
            let qualities = [];
            
            if (window.twitchVideoPlayer && window.twitchVideoPlayer.getQualities) {
                const twitchQualities = window.twitchVideoPlayer.getQualities();
                qualities = twitchQualities.map(q => q.name || q);
            } else if (window.youtubePlayer && window.youtubePlayer.getAvailableQualityLevels) {
                qualities = window.youtubePlayer.getAvailableQualityLevels();
            }
            
            qualities;
        """
        
        webView.evaluateJavaScript(qualityScript) { result, error in
            var streamQualities: [StreamQuality] = []
            
            if let qualityStrings = result as? [String] {
                streamQualities = qualityStrings.compactMap { StreamQuality.fromString($0) }
            }
            
            // Fallback to default qualities if none found
            if streamQualities.isEmpty {
                streamQualities = [.source, .high, .medium, .low]
            }
            
            completion(streamQualities.sorted { $0.bitrateRequirement > $1.bitrateRequirement })
        }
    }
    
    private func checkStreamHealth() {
        guard let webView = webView else { return }
        
        let healthScript = """
            const health = {
                timestamp: Date.now(),
                platform: window.streamPlayer?.getPlatform() || 'unknown',
                isReady: window.streamPlayer?.isReady() || false,
                hasVideo: !!document.querySelector('video'),
                hasPlayer: !!window.streamPlayer
            };
            
            // Add platform-specific health checks
            if (window.twitchVideoPlayer) {
                health.twitchSpecific = {
                    isPaused: window.twitchVideoPlayer.isPaused(),
                    quality: window.twitchVideoPlayer.getQuality(),
                    currentTime: window.twitchVideoPlayer.getCurrentTime()
                };
            }
            
            if (window.youtubePlayer) {
                health.youtubeSpecific = {
                    state: window.youtubePlayer.getPlayerState(),
                    quality: window.youtubePlayer.getPlaybackQuality(),
                    currentTime: window.youtubePlayer.getCurrentTime()
                };
            }
            
            health;
        """
        
        webView.evaluateJavaScript(healthScript) { [weak self] result, error in
            if let error = error {
                print("❌ Health check error: \(error)")
                self?.streamHealth = .error
            } else if let healthData = result as? [String: Any] {
                self?.processHealthData(healthData)
            }
        }
    }
    
    private func processHealthData(_ data: [String: Any]) {
        let isReady = data["isReady"] as? Bool ?? false
        let hasVideo = data["hasVideo"] as? Bool ?? false
        let hasPlayer = data["hasPlayer"] as? Bool ?? false
        
        if isReady && hasVideo && hasPlayer {
            streamHealth = .healthy
            if isLoading {
                isLoading = false
                playbackState = .playing
                onStreamReady?()
            }
        } else if hasPlayer {
            streamHealth = .warning
        } else {
            streamHealth = .error
        }
    }
    
    private func handleError(_ error: StreamError) {
        hasError = true
        errorMessage = error.localizedDescription
        playbackState = .error
        streamHealth = .error
        onStreamError?(error)
        
        print("❌ Stream error: \(error)")
    }
}

// MARK: - WKNavigationDelegate
extension UnifiedStreamPlayerEngine: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ WebView navigation finished")
        
        // Start a timeout to ensure loading completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isLoading {
                self.checkStreamHealth()
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView navigation failed: \(error)")
        handleError(.networkError(error))
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView provisional navigation failed: \(error)")
        handleError(.networkError(error))
    }
}

// MARK: - WKScriptMessageHandler
extension UnifiedStreamPlayerEngine: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: Any] else { return }
        
        switch message.name {
        case "streamEvents":
            handleStreamEvent(messageBody)
        case "streamError":
            handleStreamError(messageBody)
        case "streamMetrics":
            handleStreamMetrics(messageBody)
        default:
            print("Unknown message: \(message.name)")
        }
    }
    
    private func handleStreamEvent(_ data: [String: Any]) {
        guard let event = data["event"] as? String else { return }
        
        switch event {
        case "ready":
            isLoading = false
            hasError = false
            playbackState = .ready
            streamHealth = .healthy
            onStreamReady?()
            
        case "playing":
            playbackState = .playing
            
        case "paused":
            playbackState = .paused
            
        case "buffering":
            isBuffering = true
            handleBufferingEvent()
            
        case "ended":
            playbackState = .ended
            
        case "qualityChanged":
            if let quality = data["quality"] as? String,
               let streamQuality = StreamQuality(rawValue: quality) {
                currentQuality = streamQuality
                onQualityChanged?(streamQuality)
            }
            
        default:
            print("Unknown stream event: \(event)")
        }
    }
    
    private func handleStreamError(_ data: [String: Any]) {
        let message = data["message"] as? String ?? "Unknown error"
        handleError(.unknown(NSError(domain: "StreamError", code: -1, userInfo: [NSLocalizedDescriptionKey: message])))
    }
    
    private func handleStreamMetrics(_ data: [String: Any]) {
        // Process performance metrics for monitoring
        if let timestamp = data["timestamp"] as? Double {
            let now = Date().timeIntervalSince1970 * 1000
            let latency = now - timestamp
            
            if latency > 5000 { // 5 seconds
                streamHealth = .warning
            }
        }
        
        // Track buffering and performance for adaptive quality
        if let isPaused = data["isPaused"] as? Bool, !isPaused {
            isBuffering = false
        }
    }
    
    private func handleBufferingEvent() {
        bufferingCount += 1
        lastBufferTime = Date()
        
        print("⏳ Buffering detected (count: \(bufferingCount))")
        
        // If we're buffering frequently, consider downgrading quality
        if bufferingCount >= 2 && currentQuality != .low {
            let lowerQuality = currentQuality.lowerQuality
            print("📉 Frequent buffering detected, downgrading to \(lowerQuality.displayName)")
            setQuality(lowerQuality, isAdaptive: true)
        }
    }
}

// MARK: - Supporting Types
extension UnifiedStreamPlayerEngine {
    
    public enum StreamError: Error, LocalizedError {
        case invalidURL
        case unsupportedPlatform
        case networkError(Error)
        case loadTimeout
        case unknown(Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid stream URL. Please check the URL and try again."
            case .unsupportedPlatform:
                return "This platform is not currently supported."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .loadTimeout:
                return "Stream took too long to load. Please check your connection."
            case .unknown(let error):
                return "An error occurred: \(error.localizedDescription)"
            }
        }
        
        public var isRecoverable: Bool {
            switch self {
            case .invalidURL, .unsupportedPlatform:
                return false
            case .networkError, .loadTimeout, .unknown:
                return true
            }
        }
    }
    
    public enum ConnectionFailedReason {
        case corsBlocked
        case networkTimeout
        case serverError
        case invalidStream
        case platformRestriction
        
        var localizedDescription: String {
            switch self {
            case .corsBlocked:
                return "Cross-origin request blocked"
            case .networkTimeout:
                return "Network request timed out"
            case .serverError:
                return "Server error occurred"
            case .invalidStream:
                return "Stream is no longer available"
            case .platformRestriction:
                return "Platform access restricted"
            }
        }
    }
}

// MARK: - Network Quality Assessment
enum NetworkQuality {
    case excellent
    case good
    case fair
    case poor
    case degraded(Double) // Drop rate
    case unknown
    
    static func from(connectionType: String) -> NetworkQuality {
        switch connectionType.lowercased() {
        case "4g": return .excellent
        case "3g": return .good
        case "2g": return .poor
        case "slow-2g": return .poor
        default: return .unknown
        }
    }
    
    var recommendedQuality: StreamQuality {
        switch self {
        case .excellent:
            return .source
        case .good:
            return .high
        case .fair:
            return .medium
        case .poor:
            return .low
        case .degraded(let dropRate):
            if dropRate > 0.15 { return .low }
            else if dropRate > 0.08 { return .medium }
            else { return .high }
        case .unknown:
            return .medium
        }
    }
    
    func isEquivalent(to other: NetworkQuality) -> Bool {
        switch (self, other) {
        case (.excellent, .excellent),
             (.good, .good),
             (.fair, .fair),
             (.poor, .poor),
             (.unknown, .unknown):
            return true
        case (.degraded(let rate1), .degraded(let rate2)):
            return abs(rate1 - rate2) < 0.02 // Within 2% difference
        default:
            return false
        }
    }
}

// MARK: - StreamQuality Extensions
extension StreamQuality {
    var twitchValue: String {
        switch self {
        case .auto: return "auto"
        case .source: return "chunked"
        case .high: return "720p60"
        case .medium: return "480p"
        case .low: return "360p"
        case .mobile: return "160p"
        }
    }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .source: return "Source"
        case .high: return "High (720p)"
        case .medium: return "Medium (480p)"
        case .low: return "Low (360p)"
        case .mobile: return "Mobile (160p)"
        }
    }
    
    /// Estimated bitrate requirement in Mbps
    var bitrateRequirement: Double {
        switch self {
        case .auto: return 2.0 // Adaptive baseline
        case .source: return 8.0
        case .high: return 4.0
        case .medium: return 2.0
        case .low: return 1.0
        case .mobile: return 0.5
        }
    }
    
    /// Get a lower quality option
    var lowerQuality: StreamQuality {
        switch self {
        case .source: return .high
        case .high: return .medium
        case .medium: return .low
        case .low: return .mobile
        case .mobile: return .mobile
        case .auto: return .medium
        }
    }
    
    /// Get a higher quality option
    var higherQuality: StreamQuality {
        switch self {
        case .mobile: return .low
        case .low: return .medium
        case .medium: return .high
        case .high: return .source
        case .source: return .source
        case .auto: return .auto
        }
    }
    
    /// Create quality from bandwidth estimate
    static func fromBandwidth(_ bandwidth: Double) -> StreamQuality {
        if bandwidth >= 8.0 { return .source }
        else if bandwidth >= 4.0 { return .high }
        else if bandwidth >= 2.0 { return .medium }
        else if bandwidth >= 1.0 { return .low }
        else { return .mobile }
    }
    
    /// Create quality from string (for parsing available qualities)
    static func fromString(_ string: String) -> StreamQuality? {
        let normalized = string.lowercased()
        
        if normalized.contains("source") || normalized.contains("chunked") || normalized.contains("1080") {
            return .source
        } else if normalized.contains("720") || normalized.contains("high") {
            return .high
        } else if normalized.contains("480") || normalized.contains("medium") {
            return .medium
        } else if normalized.contains("360") || normalized.contains("low") {
            return .low
        } else if normalized.contains("160") || normalized.contains("mobile") {
            return .mobile
        } else if normalized.contains("auto") {
            return .auto
        }
        
        return nil
    }
}