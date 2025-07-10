//
//  StreamDataService.swift
//  StreamyyyApp
//
//  Unified data service for stream discovery and management across all platforms
//  Created by Claude Code on 2025-07-10
//

import Foundation
import Combine
import SwiftUI

// MARK: - Stream Data Service

/// Unified service that consolidates all platform-specific services and provides a single interface
/// for stream discovery, search, and management across multiple platforms
@MainActor
public class StreamDataService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var discoveredStreams: [DiscoveredStream] = []
    @Published public private(set) var featuredStreams: [DiscoveredStream] = []
    @Published public private(set) var trendingStreams: [DiscoveredStream] = []
    @Published public private(set) var searchResults: [DiscoveredStream] = []
    @Published public private(set) var recommendedStreams: [DiscoveredStream] = []
    @Published public private(set) var categories: [StreamCategory] = []
    
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: StreamDataError?
    @Published public private(set) var lastUpdated: Date?
    
    // MARK: - Services
    
    private let discoveryService: EnhancedDiscoveryService
    private let twitchService: TwitchAPIService
    private let youtubeService: YouTubeService
    private let rumbleService: RumbleService
    private let cacheManager: StreamCacheManager
    
    // MARK: - Configuration
    
    public struct Configuration {
        public let enabledPlatforms: Set<Platform>
        public let maxConcurrentRequests: Int
        public let cacheDuration: TimeInterval
        public let preferredLanguages: [String]
        public let contentRating: ContentRating
        public let autoRefreshInterval: TimeInterval
        
        public init(
            enabledPlatforms: Set<Platform> = [.twitch, .youtube, .rumble],
            maxConcurrentRequests: Int = 10,
            cacheDuration: TimeInterval = 300, // 5 minutes
            preferredLanguages: [String] = ["en"],
            contentRating: ContentRating = .general,
            autoRefreshInterval: TimeInterval = 600 // 10 minutes
        ) {
            self.enabledPlatforms = enabledPlatforms
            self.maxConcurrentRequests = maxConcurrentRequests
            self.cacheDuration = cacheDuration
            self.preferredLanguages = preferredLanguages
            self.contentRating = contentRating
            self.autoRefreshInterval = autoRefreshInterval
        }
    }
    
    private let configuration: Configuration
    
    // MARK: - Concurrency Management
    
    private let concurrencyQueue: OperationQueue
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // MARK: - Analytics and Performance
    
    private var analyticsData = AnalyticsData()
    private let performanceMonitor = PerformanceMonitor()
    
    // MARK: - Initialization
    
    public init(
        configuration: Configuration = Configuration(),
        twitchService: TwitchAPIService,
        youtubeService: YouTubeService,
        rumbleService: RumbleService,
        cacheManager: StreamCacheManager = StreamCacheManager.shared
    ) {
        self.configuration = configuration
        self.twitchService = twitchService
        self.youtubeService = youtubeService
        self.rumbleService = rumbleService
        self.cacheManager = cacheManager
        
        // Initialize discovery service
        let discoveryConfig = EnhancedDiscoveryService.DiscoveryConfiguration(
            enabledPlatforms: configuration.enabledPlatforms,
            preferredLanguages: configuration.preferredLanguages,
            contentRating: configuration.contentRating
        )
        self.discoveryService = EnhancedDiscoveryService(
            configuration: discoveryConfig,
            twitchService: twitchService,
            youtubeService: youtubeService,
            rumbleService: rumbleService
        )
        
        // Setup concurrency
        self.concurrencyQueue = OperationQueue()
        self.concurrencyQueue.maxConcurrentOperationCount = configuration.maxConcurrentRequests
        self.concurrencyQueue.name = "StreamDataService.ConcurrencyQueue"
        
        setupAutoRefresh()
        setupAnalytics()
    }
    
    // MARK: - Public API Methods
    
    /// Load all featured content from enabled platforms
    public func loadFeaturedContent() async {
        await performTask(name: "loadFeaturedContent") {
            await self.discoveryService.loadFeaturedContent()
            self.featuredStreams = self.discoveryService.featuredStreams
            self.lastUpdated = Date()
        }
    }
    
    /// Load trending content from enabled platforms
    public func loadTrendingContent() async {
        await performTask(name: "loadTrendingContent") {
            await self.discoveryService.loadTrendingContent()
            self.trendingStreams = self.discoveryService.trendingStreams
            self.lastUpdated = Date()
        }
    }
    
    /// Load popular categories from all platforms
    public func loadCategories() async {
        await performTask(name: "loadCategories") {
            await self.discoveryService.loadPopularCategories()
            self.categories = self.discoveryService.popularCategories
            self.lastUpdated = Date()
        }
    }
    
    /// Search for streams across all enabled platforms
    public func search(query: String, filters: UnifiedSearchFilters = UnifiedSearchFilters()) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        await performTask(name: "search") {
            let searchFilters = self.convertToDiscoveryFilters(filters)
            await self.discoveryService.search(query: query, filters: searchFilters)
            self.searchResults = self.discoveryService.searchResults
            self.analyticsData.recordSearch(query: query, resultCount: self.searchResults.count)
            self.lastUpdated = Date()
        }
    }
    
    /// Get personalized recommendations based on viewing history
    public func loadRecommendations(basedOn history: [Stream] = []) async {
        await performTask(name: "loadRecommendations") {
            self.recommendedStreams = await self.discoveryService.getRecommendations(based: history)
            self.lastUpdated = Date()
        }
    }
    
    /// Load comprehensive stream data (featured + trending + categories)
    public func loadAllContent() async {
        await performTask(name: "loadAllContent") {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadFeaturedContent() }
                group.addTask { await self.loadTrendingContent() }
                group.addTask { await self.loadCategories() }
            }
            
            // Combine all streams for discovery
            self.discoveredStreams = Array(Set(self.featuredStreams + self.trendingStreams))
                .sorted { $0.viewerCount > $1.viewerCount }
            
            self.lastUpdated = Date()
        }
    }
    
    /// Get streams by platform
    public func getStreams(for platform: Platform, limit: Int = 20) async -> [DiscoveredStream] {
        switch platform {
        case .twitch:
            return await getTwitchStreams(limit: limit)
        case .youtube:
            return await getYouTubeStreams(limit: limit)
        case .rumble:
            return await getRumbleStreams(limit: limit)
        default:
            return []
        }
    }
    
    /// Get streams by category
    public func getStreams(for category: String, limit: Int = 20) async -> [DiscoveredStream] {
        let allStreams = featuredStreams + trendingStreams + discoveredStreams
        return Array(allStreams.filter { $0.category?.lowercased() == category.lowercased() }
            .prefix(limit))
    }
    
    /// Refresh all cached data
    public func refreshAllData() async {
        await performTask(name: "refreshAllData") {
            self.cacheManager.clearCache()
            self.discoveryService.clearCache()
            await self.loadAllContent()
        }
    }
    
    // MARK: - Platform-Specific Methods
    
    private func getTwitchStreams(limit: Int) async -> [DiscoveredStream] {
        do {
            let streams = try await twitchService.getTopStreams(limit: limit)
            return streams.map { $0.toDiscovered() }
        } catch {
            print("Failed to get Twitch streams: \(error)")
            analyticsData.recordError(error, platform: .twitch)
            return []
        }
    }
    
    private func getYouTubeStreams(limit: Int) async -> [DiscoveredStream] {
        do {
            let videos = try await youtubeService.getTrendingVideos(maxResults: limit)
            return videos.items.compactMap { video in
                convertYouTubeVideoToDiscovered(video)
            }
        } catch {
            print("Failed to get YouTube streams: \(error)")
            analyticsData.recordError(error, platform: .youtube)
            return []
        }
    }
    
    private func getRumbleStreams(limit: Int) async -> [DiscoveredStream] {
        do {
            return try await rumbleService.getFeaturedStreams(limit: limit)
        } catch {
            print("Failed to get Rumble streams: \(error)")
            analyticsData.recordError(error, platform: .rumble)
            return []
        }
    }
    
    // MARK: - Cache Management
    
    /// Get cached streams if available
    public func getCachedStreams() async -> [Stream] {
        return await cacheManager.getCachedStreams()
    }
    
    /// Cache a stream for offline access
    public func cacheStream(_ stream: Stream) async {
        await cacheManager.cacheStream(stream)
    }
    
    /// Remove a stream from cache
    public func removeCachedStream(id: String) async {
        await cacheManager.removeStream(id: id)
    }
    
    /// Get cache information
    public func getCacheInfo() -> CacheInfo {
        return cacheManager.getCacheInfo()
    }
    
    // MARK: - Analytics and Performance
    
    /// Get analytics data
    public func getAnalytics() -> AnalyticsData {
        return analyticsData
    }
    
    /// Get performance metrics
    public func getPerformanceMetrics() -> PerformanceMetrics {
        return performanceMonitor.getMetrics()
    }
    
    // MARK: - Utility Methods
    
    private func performTask<T>(name: String, operation: @escaping () async throws -> T) async rethrows -> T? {
        isLoading = true
        error = nil
        
        let startTime = Date()
        
        defer {
            isLoading = false
            let duration = Date().timeIntervalSince(startTime)
            performanceMonitor.recordOperation(name: name, duration: duration)
        }
        
        do {
            let result = try await operation()
            analyticsData.recordSuccess(operation: name)
            return result
        } catch {
            let streamError = StreamDataError.operationFailed(name, error)
            self.error = streamError
            analyticsData.recordError(error, operation: name)
            print("❌ StreamDataService operation '\(name)' failed: \(error)")
            throw error
        }
    }
    
    private func convertToDiscoveryFilters(_ filters: UnifiedSearchFilters) -> SearchFilters {
        return SearchFilters(
            platforms: filters.platforms,
            categories: filters.categories,
            languages: filters.languages,
            liveOnly: filters.liveOnly,
            minViewers: filters.minViewers,
            maxViewers: filters.maxViewers
        )
    }
    
    private func convertYouTubeVideoToDiscovered(_ video: YouTubeVideo) -> DiscoveredStream? {
        return DiscoveredStream(
            id: "youtube_\(video.id)",
            title: video.snippet.title,
            channelName: video.snippet.channelTitle,
            platform: .youtube,
            viewerCount: video.viewCountInt,
            isLive: video.isLive,
            thumbnailURL: video.bestThumbnailUrl,
            streamURL: "https://www.youtube.com/watch?v=\(video.id)",
            category: nil,
            language: video.snippet.defaultLanguage ?? "en",
            startedAt: parseISODate(video.snippet.publishedAt)
        )
    }
    
    private func parseISODate(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: isoString)
    }
    
    // MARK: - Auto Refresh
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: configuration.autoRefreshInterval, repeats: true) { _ in
            Task {
                await self.loadTrendingContent()
            }
        }
    }
    
    private func setupAnalytics() {
        // Track discovery service errors
        discoveryService.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.analyticsData.recordError(error, operation: "discovery")
            }
            .store(in: &cancellables)
    }
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

/// Unified search filters that work across all platforms
public struct UnifiedSearchFilters {
    public var platforms: Set<Platform>?
    public var categories: Set<String>?
    public var languages: Set<String>?
    public var liveOnly: Bool
    public var minViewers: Int?
    public var maxViewers: Int?
    public var dateRange: DateRange?
    public var duration: DurationRange?
    public var sortBy: SortOption
    
    public init(
        platforms: Set<Platform>? = nil,
        categories: Set<String>? = nil,
        languages: Set<String>? = nil,
        liveOnly: Bool = false,
        minViewers: Int? = nil,
        maxViewers: Int? = nil,
        dateRange: DateRange? = nil,
        duration: DurationRange? = nil,
        sortBy: SortOption = .relevance
    ) {
        self.platforms = platforms
        self.categories = categories
        self.languages = languages
        self.liveOnly = liveOnly
        self.minViewers = minViewers
        self.maxViewers = maxViewers
        self.dateRange = dateRange
        self.duration = duration
        self.sortBy = sortBy
    }
    
    public enum DateRange {
        case today
        case thisWeek
        case thisMonth
        case thisYear
        case custom(from: Date, to: Date)
    }
    
    public enum DurationRange {
        case short      // < 4 minutes
        case medium     // 4-20 minutes
        case long       // > 20 minutes
        case any
    }
    
    public enum SortOption {
        case relevance
        case viewCount
        case date
        case alphabetical
        case platform
    }
}

/// Content rating for filtering appropriate content
public enum ContentRating {
    case general
    case teen
    case mature
    case all
}

/// Stream data service errors
public enum StreamDataError: Error, LocalizedError {
    case operationFailed(String, Error)
    case platformUnavailable(Platform)
    case invalidConfiguration
    case cacheError(Error)
    case networkUnavailable
    case rateLimitExceeded(Platform)
    case authenticationRequired(Platform)
    
    public var errorDescription: String? {
        switch self {
        case .operationFailed(let operation, let error):
            return "Operation '\(operation)' failed: \(error.localizedDescription)"
        case .platformUnavailable(let platform):
            return "Platform \(platform.displayName) is unavailable"
        case .invalidConfiguration:
            return "Invalid service configuration"
        case .cacheError(let error):
            return "Cache error: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network is unavailable"
        case .rateLimitExceeded(let platform):
            return "Rate limit exceeded for \(platform.displayName)"
        case .authenticationRequired(let platform):
            return "Authentication required for \(platform.displayName)"
        }
    }
}

// MARK: - Analytics

/// Analytics data collection for service performance and usage
public struct AnalyticsData {
    public private(set) var totalOperations: Int = 0
    public private(set) var successfulOperations: Int = 0
    public private(set) var failedOperations: Int = 0
    public private(set) var searches: [SearchRecord] = []
    public private(set) var errors: [ErrorRecord] = []
    public private(set) var platformUsage: [Platform: Int] = [:]
    
    public struct SearchRecord {
        public let query: String
        public let resultCount: Int
        public let timestamp: Date
        
        public init(query: String, resultCount: Int, timestamp: Date = Date()) {
            self.query = query
            self.resultCount = resultCount
            self.timestamp = timestamp
        }
    }
    
    public struct ErrorRecord {
        public let error: Error
        public let platform: Platform?
        public let operation: String?
        public let timestamp: Date
        
        public init(error: Error, platform: Platform? = nil, operation: String? = nil, timestamp: Date = Date()) {
            self.error = error
            self.platform = platform
            self.operation = operation
            self.timestamp = timestamp
        }
    }
    
    public mutating func recordSuccess(operation: String) {
        totalOperations += 1
        successfulOperations += 1
    }
    
    public mutating func recordError(_ error: Error, platform: Platform? = nil, operation: String? = nil) {
        totalOperations += 1
        failedOperations += 1
        errors.append(ErrorRecord(error: error, platform: platform, operation: operation))
        
        if let platform = platform {
            platformUsage[platform, default: 0] += 1
        }
    }
    
    public mutating func recordSearch(query: String, resultCount: Int) {
        searches.append(SearchRecord(query: query, resultCount: resultCount))
    }
    
    public var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
    
    public var averageSearchResults: Double {
        guard !searches.isEmpty else { return 0 }
        let total = searches.reduce(0) { $0 + $1.resultCount }
        return Double(total) / Double(searches.count)
    }
}

// MARK: - Performance Monitoring

/// Performance monitoring for service operations
public class PerformanceMonitor {
    private var operations: [String: [TimeInterval]] = [:]
    private let queue = DispatchQueue(label: "performance.monitor", qos: .utility)
    
    public func recordOperation(name: String, duration: TimeInterval) {
        queue.async {
            self.operations[name, default: []].append(duration)
            
            // Keep only the last 100 operations per type
            if self.operations[name]!.count > 100 {
                self.operations[name]!.removeFirst()
            }
        }
    }
    
    public func getMetrics() -> PerformanceMetrics {
        return queue.sync {
            var metrics: [String: OperationMetrics] = [:]
            
            for (operation, durations) in operations {
                let avgDuration = durations.reduce(0, +) / Double(durations.count)
                let maxDuration = durations.max() ?? 0
                let minDuration = durations.min() ?? 0
                
                metrics[operation] = OperationMetrics(
                    averageDuration: avgDuration,
                    maxDuration: maxDuration,
                    minDuration: minDuration,
                    operationCount: durations.count
                )
            }
            
            return PerformanceMetrics(operations: metrics)
        }
    }
}

public struct PerformanceMetrics {
    public let operations: [String: OperationMetrics]
    
    public var overallAverageDuration: TimeInterval {
        let allDurations = operations.values.map { $0.averageDuration }
        guard !allDurations.isEmpty else { return 0 }
        return allDurations.reduce(0, +) / Double(allDurations.count)
    }
}

public struct OperationMetrics {
    public let averageDuration: TimeInterval
    public let maxDuration: TimeInterval
    public let minDuration: TimeInterval
    public let operationCount: Int
}