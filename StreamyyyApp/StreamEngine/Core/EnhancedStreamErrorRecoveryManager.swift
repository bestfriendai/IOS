//
//  EnhancedStreamErrorRecoveryManager.swift
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
public final class EnhancedStreamErrorRecoveryManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = EnhancedStreamErrorRecoveryManager()
    
    // MARK: - Published Properties
    @Published public var isNetworkAvailable = true
    @Published public var networkQuality: NetworkQuality = .excellent
    @Published public var activeRecoveryAttempts: [String: RecoveryAttempt] = [:]
    @Published public var errorStatistics = ErrorStatistics()
    
    // MARK: - Properties
    private let networkMonitor = NWPathMonitor()
    private let recoveryQueue = DispatchQueue(label: "com.streamyyy.recovery", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // Recovery configuration
    private let maxRetryAttempts = 5
    private let baseRetryDelay: TimeInterval = 2.0
    private let maxRetryDelay: TimeInterval = 30.0
    private let networkCheckInterval: TimeInterval = 5.0
    
    // Fallback strategies
    private var fallbackStrategies: [StreamPlatform: [FallbackStrategy]] = [:]
    
    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
        setupFallbackStrategies()
        startErrorTracking()
    }
    
    deinit {
        networkMonitor.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// Attempt to recover from a stream error
    public func recoverFromError(
        streamId: String,
        platform: StreamPlatform,
        error: StreamError,
        originalURL: String,
        completion: @escaping (RecoveryResult) -> Void
    ) {
        print("🔧 Starting recovery for stream \(streamId) - Error: \(error)")
        
        // Record the error
        recordError(error, for: platform)
        
        // Check if we're already attempting recovery for this stream
        if activeRecoveryAttempts[streamId] != nil {
            print("⚠️ Recovery already in progress for stream: \(streamId)")
            completion(.alreadyInProgress)
            return
        }
        
        // Create recovery attempt
        let attempt = RecoveryAttempt(
            streamId: streamId,
            platform: platform,
            originalURL: originalURL,
            error: error,
            startTime: Date(),
            attemptCount: 0
        )
        
        activeRecoveryAttempts[streamId] = attempt
        
        // Start recovery process
        performRecovery(attempt: attempt, completion: completion)
    }
    
    /// Cancel ongoing recovery for a stream
    public func cancelRecovery(for streamId: String) {
        if let attempt = activeRecoveryAttempts[streamId] {
            print("❌ Cancelling recovery for stream: \(streamId)")
            activeRecoveryAttempts.removeValue(forKey: streamId)
        }
    }
    
    /// Get suggested fallback URL for a stream
    public func getFallbackURL(for originalURL: String, platform: StreamPlatform) -> String? {
        let strategies = fallbackStrategies[platform] ?? []
        
        for strategy in strategies {
            if let fallbackURL = strategy.generateFallbackURL(from: originalURL) {
                print("🔄 Generated fallback URL for \(platform): \(fallbackURL)")
                return fallbackURL
            }
        }
        
        return nil
    }
    
    /// Check if a stream should be retried based on error history
    public func shouldRetryStream(_ streamId: String) -> Bool {
        guard let attempt = activeRecoveryAttempts[streamId] else { return true }
        
        let timeSinceStart = Date().timeIntervalSince(attempt.startTime)
        let hasExceededMaxAttempts = attempt.attemptCount >= maxRetryAttempts
        let hasExceededMaxTime = timeSinceStart > maxRetryDelay * Double(maxRetryAttempts)
        
        return !hasExceededMaxAttempts && !hasExceededMaxTime
    }
    
    /// Get optimal retry delay for a stream
    public func getRetryDelay(for streamId: String) -> TimeInterval {
        guard let attempt = activeRecoveryAttempts[streamId] else { return baseRetryDelay }
        
        // Exponential backoff with jitter
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt.attemptCount))
        let cappedDelay = min(exponentialDelay, maxRetryDelay)
        let jitter = Double.random(in: 0.8...1.2)
        
        return cappedDelay * jitter
    }
}

// MARK: - Private Implementation
extension EnhancedStreamErrorRecoveryManager {
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        
        networkMonitor.start(queue: recoveryQueue)
    }
    
    private func setupFallbackStrategies() {
        // Twitch fallback strategies
        fallbackStrategies[.twitch] = [
            TwitchMobileStrategy(),
            TwitchAlternativeParentStrategy(),
            TwitchLegacyEmbedStrategy()
        ]
        
        // YouTube fallback strategies
        fallbackStrategies[.youtube] = [
            YouTubeNoCookieStrategy(),
            YouTubeMobileStrategy(),
            YouTubeAlternativeEmbedStrategy()
        ]
        
        // Kick fallback strategies
        fallbackStrategies[.kick] = [
            KickAlternativeStrategy()
        ]
    }
    
    private func startErrorTracking() {
        // Track errors every minute
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateErrorStatistics()
        }
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        isNetworkAvailable = path.status == .satisfied
        
        // Update network quality
        if path.status == .satisfied {
            if path.isExpensive {
                networkQuality = .poor
            } else if path.usesInterfaceType(.cellular) {
                networkQuality = .fair
            } else if path.usesInterfaceType(.wifi) {
                networkQuality = .good
            } else if path.usesInterfaceType(.wiredEthernet) {
                networkQuality = .excellent
            } else {
                networkQuality = .fair
            }
        } else {
            networkQuality = .none
        }
        
        print("📡 Network status: \(isNetworkAvailable ? "Available" : "Unavailable") - Quality: \(networkQuality)")
    }
    
    private func performRecovery(
        attempt: RecoveryAttempt,
        completion: @escaping (RecoveryResult) -> Void
    ) {
        guard shouldRetryStream(attempt.streamId) else {
            activeRecoveryAttempts.removeValue(forKey: attempt.streamId)
            completion(.failed(reason: "Maximum retry attempts exceeded"))
            return
        }
        
        // Update attempt count
        var updatedAttempt = attempt
        updatedAttempt.attemptCount += 1
        activeRecoveryAttempts[attempt.streamId] = updatedAttempt
        
        // Wait for retry delay
        let delay = getRetryDelay(for: attempt.streamId)
        
        recoveryQueue.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                self.executeRecoveryStrategy(attempt: updatedAttempt, completion: completion)
            }
        }
    }
    
    private func executeRecoveryStrategy(
        attempt: RecoveryAttempt,
        completion: @escaping (RecoveryResult) -> Void
    ) {
        print("🔧 Executing recovery strategy for \(attempt.streamId) - Attempt \(attempt.attemptCount)")
        
        // Try fallback strategies first
        if let fallbackURL = getFallbackURL(for: attempt.originalURL, platform: attempt.platform) {
            completion(.recovered(newURL: fallbackURL, strategy: "Fallback strategy"))
        } else {
            completion(.retry(originalURL: attempt.originalURL))
        }
    }
    
    private func recordError(_ error: StreamError, for platform: StreamPlatform) {
        errorStatistics.totalErrors += 1
        errorStatistics.errorsByPlatform[platform, default: 0] += 1
        errorStatistics.errorsByType[error.errorType, default: 0] += 1
        errorStatistics.lastErrorTime = Date()
    }
    
    private func updateErrorStatistics() {
        // Calculate error rates and cleanup old data
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        // Remove old recovery attempts
        activeRecoveryAttempts = activeRecoveryAttempts.filter { _, attempt in
            attempt.startTime > oneHourAgo
        }
    }
}

// MARK: - Supporting Types

public enum StreamPlatform: String, CaseIterable {
    case twitch = "twitch"
    case youtube = "youtube"
    case kick = "kick"
}

public enum NetworkQuality: String, CaseIterable {
    case none = "none"
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
}

public enum StreamError {
    case networkError(Error)
    case corsError
    case embedNotSupported
    case streamOffline
    case loadTimeout
    case invalidURL
    case platformError(String)
    case unknown(Error)
    
    var errorType: String {
        switch self {
        case .networkError: return "network"
        case .corsError: return "cors"
        case .embedNotSupported: return "embed"
        case .streamOffline: return "offline"
        case .loadTimeout: return "timeout"
        case .invalidURL: return "invalid_url"
        case .platformError: return "platform"
        case .unknown: return "unknown"
        }
    }
}

public enum RecoveryResult {
    case recovered(newURL: String, strategy: String)
    case retry(originalURL: String)
    case retryLater(delay: TimeInterval)
    case failed(reason: String)
    case alreadyInProgress
}

public struct RecoveryAttempt {
    let streamId: String
    let platform: StreamPlatform
    let originalURL: String
    let error: StreamError
    let startTime: Date
    var attemptCount: Int
}

public struct ErrorStatistics {
    var totalErrors = 0
    var errorsByPlatform: [StreamPlatform: Int] = [:]
    var errorsByType: [String: Int] = [:]
    var successfulRecoveries = 0
    var recoverySuccessRate: Double = 0.0
    var lastErrorTime: Date?
}

// MARK: - Fallback Strategy Protocol

protocol FallbackStrategy {
    var name: String { get }
    func canHandleError(_ error: StreamError) -> Bool
    func generateFallbackURL(from originalURL: String) -> String?
}

// MARK: - Twitch Fallback Strategies

struct TwitchMobileStrategy: FallbackStrategy {
    let name = "Twitch Mobile"
    
    func canHandleError(_ error: StreamError) -> Bool {
        switch error {
        case .corsError, .embedNotSupported, .loadTimeout:
            return true
        default:
            return false
        }
    }
    
    func generateFallbackURL(from originalURL: String) -> String? {
        guard let channelName = extractTwitchChannelName(from: originalURL) else { return nil }
        return "https://m.twitch.tv/\(channelName)"
    }
}

struct TwitchAlternativeParentStrategy: FallbackStrategy {
    let name = "Twitch Alternative Parent"
    
    func canHandleError(_ error: StreamError) -> Bool {
        return error.errorType == "cors"
    }
    
    func generateFallbackURL(from originalURL: String) -> String? {
        guard let channelName = extractTwitchChannelName(from: originalURL) else { return nil }
        
        // Use different parent domains for CORS compatibility
        let parentDomains = ["localhost", "twitch.tv", "player.twitch.tv", "127.0.0.1", "streamyyy.com"]
        let parentParam = parentDomains.map { "parent=\($0)" }.joined(separator: "&")
        
        return "https://player.twitch.tv/?channel=\(channelName)&\(parentParam)&autoplay=true&muted=false"
    }
}

struct TwitchLegacyEmbedStrategy: FallbackStrategy {
    let name = "Twitch Legacy Embed"
    
    func canHandleError(_ error: StreamError) -> Bool {
        return error.errorType == "embed"
    }
    
    func generateFallbackURL(from originalURL: String) -> String? {
        guard let channelName = extractTwitchChannelName(from: originalURL) else { return nil }
        return "https://www.twitch.tv/\(channelName)/embed"
    }
}

// MARK: - YouTube Fallback Strategies

struct YouTubeNoCookieStrategy: FallbackStrategy {
    let name = "YouTube No Cookie"
    
    func canHandleError(_ error: StreamError) -> Bool {
        switch error {
        case .corsError, .embedNotSupported:
            return true
        default:
            return false
        }
    }
    
    func generateFallbackURL(from originalURL: String) -> String? {
        guard let videoId = extractYouTubeVideoId(from: originalURL) else { return nil }
        return "https://www.youtube-nocookie.com/embed/\(videoId)?autoplay=1&controls=0"
    }
}

struct YouTubeMobileStrategy: FallbackStrategy {
    let name = "YouTube Mobile"
    
    func canHandleError(_ error: StreamError) -> Bool {
        return error.errorType == "embed"
    }
    
    func generateFallbackURL(from originalURL: String) -> String? {
        guard let videoId = extractYouTubeVideoId(from: originalURL) else { return nil }
        return "https://m.youtube.com/watch?v=\(videoId)"
    }
}

struct YouTubeAlternativeEmbedStrategy: FallbackStrategy {
    let name = "YouTube Alternative Embed"
    
    func canHandleError(_ error: StreamError) -> Bool {
        return true
    }
    
    func generateFallbackURL(from originalURL: String) -> String? {
        guard let videoId = extractYouTubeVideoId(from: originalURL) else { return nil }
        return "https://www.youtube.com/embed/\(videoId)?enablejsapi=1&origin=https://streamyyy.com"
    }
}

// MARK: - Kick Fallback Strategies

struct KickAlternativeStrategy: FallbackStrategy {
    let name = "Kick Alternative"
    
    func canHandleError(_ error: StreamError) -> Bool {
        return true
    }
    
    func generateFallbackURL(from originalURL: String) -> String? {
        let components = URLComponents(string: originalURL)
        let pathComponents = components?.path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard let channelName = pathComponents?.first else { return nil }
        return "https://player.kick.com/\(channelName)"
    }
}

// MARK: - Helper Functions

private func extractTwitchChannelName(from url: String) -> String? {
    let components = URLComponents(string: url)
    let path = components?.path ?? ""
    let channelName = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return channelName.isEmpty ? nil : channelName
}

private func extractYouTubeVideoId(from url: String) -> String? {
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