//
//  StreamErrorRecoveryManager.swift
//  StreamyyyApp
//
//  Comprehensive error recovery and fallback management system
//  Handles network issues, CORS problems, and platform-specific failures
//  Created by Claude Code on 2025-07-11
//

import Foundation
import Combine
import Network

/// Comprehensive error recovery manager for stream playback
/// Provides intelligent fallback mechanisms and automatic recovery strategies
@MainActor
public final class StreamErrorRecoveryManager: ObservableObject {
    
    // MARK: - Properties
    @Published public private(set) var recoveryAttempts: [String: Int] = [:]
    @Published public private(set) var lastRecoveryAttempt: [String: Date] = [:]
    @Published public private(set) var recoveryStrategies: [String: RecoveryStrategy] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    private let exponentialBackoffBase: Double = 2.0
    
    // MARK: - Initialization
    public init() {
        setupDefaultStrategies()
    }
    
    // MARK: - Public Methods
    
    /// Attempts to recover from a stream error
    public func attemptRecovery(for stream: Stream, webView: WKWebView, error: StreamError) -> Bool {
        let streamId = stream.id
        let currentAttempts = recoveryAttempts[streamId] ?? 0
        
        guard currentAttempts < maxRetries else {
            print("❌ Max recovery attempts reached for stream: \(streamId)")
            return false
        }
        
        recoveryAttempts[streamId] = currentAttempts + 1
        lastRecoveryAttempt[streamId] = Date()
        
        print("🔄 Attempting recovery \(currentAttempts + 1)/\(maxRetries) for stream: \(streamId)")
        
        // Calculate delay with exponential backoff
        let delay = retryDelay * pow(exponentialBackoffBase, Double(currentAttempts))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.executeRecoveryStrategy(for: stream, webView: webView, error: error)
        }
        
        return true
    }
    
    /// Resets recovery attempts for a stream
    public func resetRecoveryAttempts(for streamId: String) {
        recoveryAttempts.removeValue(forKey: streamId)
        lastRecoveryAttempt.removeValue(forKey: streamId)
        recoveryStrategies.removeValue(forKey: streamId)
        print("🔄 Reset recovery attempts for stream: \(streamId)")
    }
    
    /// Checks if a stream is in recovery
    public func isInRecovery(streamId: String) -> Bool {
        return recoveryAttempts[streamId] != nil
    }
    
    /// Gets the current recovery attempt count
    public func getRecoveryAttempts(for streamId: String) -> Int {
        return recoveryAttempts[streamId] ?? 0
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultStrategies() {
        // Default recovery strategies for different error types
        recoveryStrategies["connection_failed"] = .reloadWithNewURL
        recoveryStrategies["timeout"] = .reloadWithDelay
        recoveryStrategies["invalid_url"] = .regenerateEmbedURL
        recoveryStrategies["platform_error"] = .switchToFallbackURL
    }
    
    private func executeRecoveryStrategy(for stream: Stream, webView: WKWebView, error: StreamError) {
        let strategy = getRecoveryStrategy(for: error)
        
        switch strategy {
        case .reloadWithNewURL:
            reloadWithNewURL(stream: stream, webView: webView)
        case .reloadWithDelay:
            reloadWithDelay(stream: stream, webView: webView)
        case .regenerateEmbedURL:
            regenerateEmbedURL(stream: stream, webView: webView)
        case .switchToFallbackURL:
            switchToFallbackURL(stream: stream, webView: webView)
        case .clearCacheAndReload:
            clearCacheAndReload(stream: stream, webView: webView)
        case .restartWebView:
            restartWebView(stream: stream, webView: webView)
        }
    }
    
    private func getRecoveryStrategy(for error: StreamError) -> RecoveryStrategy {
        switch error {
        case .connectionFailed:
            return .reloadWithNewURL
        case .invalidURL:
            return .regenerateEmbedURL
        case .loadFailed:
            return .clearCacheAndReload
        case .playbackFailed:
            return .switchToFallbackURL
        default:
            return .reloadWithDelay
        }
    }
    
    // MARK: - Recovery Strategies
    
    private func reloadWithNewURL(stream: Stream, webView: WKWebView) {
        print("🔄 Executing reloadWithNewURL strategy")
        
        // Generate a fresh embed URL
        guard let identifier = stream.platform.extractStreamIdentifier(from: stream.url) else {
            print("❌ Failed to extract stream identifier for recovery")
            return
        }
        
        let embedOptions = EmbedOptions(
            autoplay: true,
            muted: false,
            showControls: true,
            chatEnabled: false,
            quality: stream.quality,
            parentDomain: Config.Platforms.Twitch.parentDomain
        )
        
        guard let embedURL = stream.platform.generateEmbedURL(for: identifier, options: embedOptions) else {
            print("❌ Failed to generate embed URL for recovery")
            return
        }
        
        guard let url = URL(string: embedURL) else {
            print("❌ Invalid embed URL generated for recovery")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("StreamyyyApp/1.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue("streamyyy.com", forHTTPHeaderField: "Referer")
        
        webView.load(request)
    }
    
    private func reloadWithDelay(stream: Stream, webView: WKWebView) {
        print("🔄 Executing reloadWithDelay strategy")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            webView.reload()
        }
    }
    
    private func regenerateEmbedURL(stream: Stream, webView: WKWebView) {
        print("🔄 Executing regenerateEmbedURL strategy")
        
        // Try different embed options
        let embedOptions = EmbedOptions(
            autoplay: true,
            muted: false,
            showControls: false,
            chatEnabled: false,
            quality: .auto,
            parentDomain: Config.Platforms.Twitch.parentDomain
        )
        
        guard let identifier = stream.platform.extractStreamIdentifier(from: stream.url),
              let embedURL = stream.platform.generateEmbedURL(for: identifier, options: embedOptions),
              let url = URL(string: embedURL) else {
            print("❌ Failed to regenerate embed URL")
            return
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    private func switchToFallbackURL(stream: Stream, webView: WKWebView) {
        print("🔄 Executing switchToFallbackURL strategy")
        
        // Try loading the original stream URL directly
        guard let url = URL(string: stream.url) else {
            print("❌ Invalid original stream URL")
            return
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    private func clearCacheAndReload(stream: Stream, webView: WKWebView) {
        print("🔄 Executing clearCacheAndReload strategy")
        
        // Clear WebView cache
        let dataStore = webView.configuration.websiteDataStore
        dataStore.removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date.distantPast) { [weak self] in
            DispatchQueue.main.async {
                self?.reloadWithNewURL(stream: stream, webView: webView)
            }
        }
    }
    
    private func restartWebView(stream: Stream, webView: WKWebView) {
        print("🔄 Executing restartWebView strategy")
        
        // Stop all navigation
        webView.stopLoading()
        
        // Clear all content
        webView.loadHTMLString("", baseURL: nil)
        
        // Reload after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.reloadWithNewURL(stream: stream, webView: webView)
        }
    }
    
    // MARK: - Health Monitoring
    
    /// Monitors stream health and triggers recovery if needed
    public func monitorStreamHealth(for stream: Stream, webView: WKWebView) {
        let streamId = stream.id
        
        // Set up periodic health checks
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.performHealthCheck(for: stream, webView: webView) { isHealthy in
                if !isHealthy {
                    print("⚠️ Stream health check failed, attempting recovery")
                    _ = self.attemptRecovery(for: stream, webView: webView, error: .playbackFailed)
                }
            }
        }
    }
    
    private func performHealthCheck(for stream: Stream, webView: WKWebView, completion: @escaping (Bool) -> Void) {
        webView.evaluateJavaScript("""
            (function() {
                const videos = document.querySelectorAll('video');
                const iframes = document.querySelectorAll('iframe');
                
                let hasActiveVideo = false;
                videos.forEach(video => {
                    if (!video.paused && !video.ended && video.readyState > 2) {
                        hasActiveVideo = true;
                    }
                });
                
                return {
                    hasVideo: videos.length > 0,
                    hasIframe: iframes.length > 0,
                    hasActiveVideo: hasActiveVideo,
                    videoCount: videos.length,
                    iframeCount: iframes.length
                };
            })();
        """) { result, error in
            if let error = error {
                print("❌ Health check JavaScript error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let result = result as? [String: Any] {
                let hasVideo = result["hasVideo"] as? Bool ?? false
                let hasIframe = result["hasIframe"] as? Bool ?? false
                let hasActiveVideo = result["hasActiveVideo"] as? Bool ?? false
                
                let isHealthy = (hasVideo || hasIframe) && (hasActiveVideo || hasIframe)
                completion(isHealthy)
            } else {
                completion(false)
            }
        }
    }
}

// MARK: - Recovery Strategy Enum

/// Available recovery strategies for stream errors
public enum RecoveryStrategy {
    case reloadWithNewURL
    case reloadWithDelay
    case regenerateEmbedURL
    case switchToFallbackURL
    case clearCacheAndReload
    case restartWebView
}

// MARK: - Recovery Statistics

/// Statistics about recovery attempts
public struct RecoveryStatistics {
    public let streamId: String
    public let totalAttempts: Int
    public let successfulRecoveries: Int
    public let failedRecoveries: Int
    public let averageRecoveryTime: TimeInterval
    public let lastRecoveryAttempt: Date?
    
    public var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(successfulRecoveries) / Double(totalAttempts)
    }
}