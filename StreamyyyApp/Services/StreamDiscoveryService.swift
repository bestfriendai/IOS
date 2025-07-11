//
//  StreamDiscoveryService.swift
//  StreamyyyApp
//
//  Comprehensive stream discovery service that aggregates data from multiple platforms
//  Provides unified discovery, search, and recommendation functionality
//  Created by Claude Code on 2025-07-11
//

import Foundation
import Combine
import SwiftUI

// MARK: - Unified Stream Models

/// Unified stream model that can represent streams from any platform
public struct DiscoveredStream: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let channelName: String
    public let platform: Platform
    public let viewerCount: Int
    public let isLive: Bool
    public let thumbnailURL: String?
    public let streamURL: String
    public let category: String?
    public let language: String?
    public let startedAt: Date?
    public let tags: [String]
    public let description: String?
    public let isMature: Bool
    
    public init(
        id: String,
        title: String,
        channelName: String,
        platform: Platform,
        viewerCount: Int,
        isLive: Bool,
        thumbnailURL: String? = nil,
        streamURL: String,
        category: String? = nil,
        language: String? = nil,
        startedAt: Date? = nil,
        tags: [String] = [],
        description: String? = nil,
        isMature: Bool = false
    ) {
        self.id = id
        self.title = title
        self.channelName = channelName
        self.platform = platform
        self.viewerCount = viewerCount
        self.isLive = isLive
        self.thumbnailURL = thumbnailURL
        self.streamURL = streamURL
        self.category = category
        self.language = language
        self.startedAt = startedAt
        self.tags = tags
        self.description = description
        self.isMature = isMature
    }
    
    public static func == (lhs: DiscoveredStream, rhs: DiscoveredStream) -> Bool {
        return lhs.id == rhs.id && lhs.platform == rhs.platform
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(platform)
    }
}

/// Search filters for cross-platform discovery
public struct SearchFilters {
    public var platforms: Set<Platform>?
    public var categories: Set<String>?
    public var languages: Set<String>?
    public var liveOnly: Bool
    public var minViewers: Int?
    public var maxViewers: Int?
    public var sortBy: SortOption
    public var includeNSFW: Bool
    
    public init(
        platforms: Set<Platform>? = nil,
        categories: Set<String>? = nil,
        languages: Set<String>? = nil,
        liveOnly: Bool = false,
        minViewers: Int? = nil,
        maxViewers: Int? = nil,
        sortBy: SortOption = .relevance,
        includeNSFW: Bool = false
    ) {
        self.platforms = platforms
        self.categories = categories
        self.languages = languages
        self.liveOnly = liveOnly
        self.minViewers = minViewers
        self.maxViewers = maxViewers
        self.sortBy = sortBy
        self.includeNSFW = includeNSFW
    }
    
    public enum SortOption: String, CaseIterable {
        case relevance = "relevance"
        case viewerCount = "viewer_count"
        case startTime = "start_time"
        case alphabetical = "alphabetical"
        case platform = "platform"
        
        public var displayName: String {
            switch self {
            case .relevance: return "Relevance"
            case .viewerCount: return "Viewer Count"
            case .startTime: return "Recently Started"
            case .alphabetical: return "Alphabetical"
            case .platform: return "Platform"
            }
        }
    }
}

// MARK: - Stream Discovery Service

@MainActor
public class StreamDiscoveryService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var featuredStreams: [DiscoveredStream] = []
    @Published public private(set) var trendingStreams: [DiscoveredStream] = []
    @Published public private(set) var popularCategories: [StreamCategory] = []
    @Published public private(set) var searchResults: [DiscoveredStream] = []
    @Published public private(set) var recommendedStreams: [DiscoveredStream] = []
    
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: StreamDiscoveryError?
    @Published public private(set) var lastUpdated: Date?
    
    // Platform-specific state
    @Published public private(set) var twitchStreamCount: Int = 0
    @Published public private(set) var youtubeStreamCount: Int = 0
    @Published public private(set) var platformsOnline: Set<Platform> = []
    
    // MARK: - Configuration
    
    public struct Configuration {
        public let enabledPlatforms: Set<Platform>
        public let preferredLanguages: [String]
        public let contentRating: ContentRating
        public let cacheDuration: TimeInterval
        public let maxConcurrentRequests: Int
        public let autoRefreshInterval: TimeInterval
        
        public init(
            enabledPlatforms: Set<Platform> = [.twitch, .youtube],
            preferredLanguages: [String] = ["en"],
            contentRating: ContentRating = .general,
            cacheDuration: TimeInterval = 300,
            maxConcurrentRequests: Int = 6,
            autoRefreshInterval: TimeInterval = 600
        ) {
            self.enabledPlatforms = enabledPlatforms
            self.preferredLanguages = preferredLanguages
            self.contentRating = contentRating
            self.cacheDuration = cacheDuration
            self.maxConcurrentRequests = maxConcurrentRequests
            self.autoRefreshInterval = autoRefreshInterval
        }
    }
    
    // MARK: - Services and Dependencies
    
    private let configuration: Configuration
    private let twitchService: TwitchService
    private let youtubeService: YouTubeService
    private let cacheManager: StreamCacheManager
    
    // MARK: - Caching and Performance
    
    private var memoryCache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheQueue = DispatchQueue(label: "stream.discovery.cache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // MARK: - Rate Limiting and Concurrency
    
    private let requestQueue: OperationQueue
    private var activeRequests: Set<String> = []
    private let requestsLock = NSLock()
    
    // MARK: - Analytics
    
    private var searchQueries: [String] = []
    private var platformPerformance: [Platform: TimeInterval] = [:]
    private var errorCounts: [Platform: Int] = [:]
    
    // MARK: - Initialization
    
    public init(
        configuration: Configuration = Configuration(),
        twitchService: TwitchService = TwitchService.shared,
        youtubeService: YouTubeService? = nil,
        cacheManager: StreamCacheManager? = nil
    ) {
        self.configuration = configuration
        self.twitchService = twitchService
        self.youtubeService = youtubeService ?? YouTubeService()
        self.cacheManager = cacheManager ?? StreamCacheManager.shared
        
        // Setup operation queue for concurrent requests
        self.requestQueue = OperationQueue()
        self.requestQueue.maxConcurrentOperationCount = configuration.maxConcurrentRequests
        self.requestQueue.name = "StreamDiscoveryService.RequestQueue"
        
        setupAutoRefresh()
        setupErrorHandling()
    }
    
    // MARK: - Public Discovery Methods
    
    /// Load featured content from all enabled platforms
    public func loadFeaturedContent() async {
        await performDiscoveryTask("loadFeaturedContent") {
            var allFeaturedStreams: [DiscoveredStream] = []
            
            try await withThrowingTaskGroup(of: [DiscoveredStream].self) { group in
                // Add Twitch featured streams task
                if self.configuration.enabledPlatforms.contains(.twitch) {
                    group.addTask {
                        try await self.loadTwitchFeaturedStreams()
                    }
                }
                
                // Add YouTube featured streams task
                if self.configuration.enabledPlatforms.contains(.youtube) {
                    group.addTask {
                        try await self.loadYouTubeFeaturedStreams()
                    }
                }
                
                // Collect all results
                for try await platformStreams in group {
                    allFeaturedStreams.append(contentsOf: platformStreams)
                }
            }
            
            // Sort by viewer count and remove duplicates
            self.featuredStreams = Array(Set(allFeaturedStreams))
                .sorted { $0.viewerCount > $1.viewerCount }
                .prefix(20)
                .map { $0 }
        }
    }
    
    /// Load trending content from all enabled platforms
    public func loadTrendingContent() async {
        await performDiscoveryTask("loadTrendingContent") {
            var allTrendingStreams: [DiscoveredStream] = []
            
            try await withThrowingTaskGroup(of: [DiscoveredStream].self) { group in
                // Add Twitch trending streams task
                if self.configuration.enabledPlatforms.contains(.twitch) {
                    group.addTask {
                        try await self.loadTwitchTrendingStreams()
                    }
                }
                
                // Add YouTube trending streams task
                if self.configuration.enabledPlatforms.contains(.youtube) {
                    group.addTask {
                        try await self.loadYouTubeTrendingStreams()
                    }
                }
                
                // Collect all results
                for try await platformStreams in group {
                    allTrendingStreams.append(contentsOf: platformStreams)
                }
            }
            
            // Sort by viewer count and recency
            self.trendingStreams = Array(Set(allTrendingStreams))
                .sorted { stream1, stream2 in
                    // Prioritize recent streams with high viewer counts
                    let score1 = self.calculateTrendingScore(stream1)
                    let score2 = self.calculateTrendingScore(stream2)
                    return score1 > score2
                }
                .prefix(20)
                .map { $0 }
        }
    }
    
    /// Load popular categories across platforms
    public func loadPopularCategories() async {
        await performDiscoveryTask("loadPopularCategories") {
            var allCategories: Set<String> = []
            
            // Get categories from Twitch
            if self.configuration.enabledPlatforms.contains(.twitch) {
                do {
                    let games = try await self.twitchService.getTopGames(first: 20)
                    for game in games.games {
                        allCategories.insert(game.name)
                    }
                } catch {
                    print("Failed to load Twitch categories: \(error)")
                }
            }
            
            // Get categories from YouTube
            if self.configuration.enabledPlatforms.contains(.youtube) {
                do {
                    let categories = try await self.youtubeService.getVideoCategories()
                    for category in categories.items {
                        allCategories.insert(category.snippet.title)
                    }
                } catch {
                    print("Failed to load YouTube categories: \(error)")
                }
            }
            
            // Convert to StreamCategory objects
            self.popularCategories = Array(allCategories.prefix(12)).compactMap { categoryName in
                StreamCategory.from(name: categoryName)
            }.sorted { $0.displayName < $1.displayName }
        }
    }
    
    /// Search across all enabled platforms
    public func search(query: String, filters: SearchFilters = SearchFilters()) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        // Track search queries for analytics
        searchQueries.append(query)
        if searchQueries.count > 100 {
            searchQueries.removeFirst(50) // Keep last 50 queries
        }
        
        await performDiscoveryTask("search") {
            var allSearchResults: [DiscoveredStream] = []
            
            try await withThrowingTaskGroup(of: [DiscoveredStream].self) { group in
                // Search Twitch if enabled and included in filters
                if self.shouldSearchPlatform(.twitch, filters: filters) {
                    group.addTask {
                        try await self.searchTwitchStreams(query: query, filters: filters)
                    }
                }
                
                // Search YouTube if enabled and included in filters
                if self.shouldSearchPlatform(.youtube, filters: filters) {
                    group.addTask {
                        try await self.searchYouTubeStreams(query: query, filters: filters)
                    }
                }
                
                // Collect all results
                for try await platformResults in group {
                    allSearchResults.append(contentsOf: platformResults)
                }
            }
            
            // Apply additional filters and sorting
            let filteredResults = self.applyFilters(allSearchResults, filters: filters)
            self.searchResults = self.sortSearchResults(filteredResults, by: filters.sortBy)
        }
    }
    
    /// Get personalized recommendations
    public func getRecommendations(based history: [Stream] = []) async -> [DiscoveredStream] {
        let cacheKey = "recommendations_\(history.map { $0.id }.joined(separator: "_"))"
        
        if let cached: [DiscoveredStream] = getCachedData(cacheKey) {
            return cached
        }
        
        var recommendations: [DiscoveredStream] = []
        
        // Extract categories from viewing history
        let watchedCategories = Set(history.compactMap { $0.category })
        let categoryArray = Array(watchedCategories.prefix(5))
        
        do {
            // Get recommendations from Twitch
            if configuration.enabledPlatforms.contains(.twitch) {
                let twitchRecs = try await twitchService.getRecommendedStreams(
                    basedOnCategories: categoryArray,
                    excludeUserIds: history.filter { $0.platform == .twitch }.map { $0.streamerName ?? "" },
                    first: 10
                )
                recommendations.append(contentsOf: twitchRecs.map { $0.toDiscovered() })
            }
            
            // Get recommendations from YouTube
            if configuration.enabledPlatforms.contains(.youtube) {
                let youtubeRecs = try await youtubeService.getLiveStreams(maxResults: 10)
                recommendations.append(contentsOf: youtubeRecs.items.compactMap { 
                    convertYouTubeSearchToDiscovered($0)
                })
            }
            
            // Remove duplicates and sort by relevance
            let uniqueRecommendations = Array(Set(recommendations))
                .sorted { $0.viewerCount > $1.viewerCount }
                .prefix(15)
            
            let result = Array(uniqueRecommendations)
            setCachedData(cacheKey, data: result, expiration: 600) // 10 minutes
            return result
            
        } catch {
            print("Failed to load recommendations: \(error)")
            return []
        }
    }
    
    /// Clear all caches
    public func clearCache() {
        cacheQueue.async {
            self.memoryCache.removeAll()
        }
        cacheManager.clearCache()
    }
    
    // MARK: - Platform-Specific Loading Methods
    
    private func loadTwitchFeaturedStreams() async throws -> [DiscoveredStream] {
        let startTime = Date()
        defer {
            platformPerformance[.twitch] = Date().timeIntervalSince(startTime)
        }
        
        do {
            let result = try await twitchService.getFeaturedStreams(first: 15)
            platformsOnline.insert(.twitch)
            twitchStreamCount = result.streams.count
            return result.streams.map { $0.toDiscovered() }
        } catch {
            platformsOnline.remove(.twitch)
            errorCounts[.twitch, default: 0] += 1
            throw error
        }
    }
    
    private func loadTwitchTrendingStreams() async throws -> [DiscoveredStream] {
        do {
            let streams = try await twitchService.getTrendingStreams(first: 15)
            return streams.map { $0.toDiscovered() }
        } catch {
            errorCounts[.twitch, default: 0] += 1
            throw error
        }
    }
    
    private func loadYouTubeFeaturedStreams() async throws -> [DiscoveredStream] {
        let startTime = Date()
        defer {
            platformPerformance[.youtube] = Date().timeIntervalSince(startTime)
        }
        
        do {
            let result = try await youtubeService.getFeaturedLiveStreams(maxResults: 15)
            platformsOnline.insert(.youtube)
            youtubeStreamCount = result.items.count
            
            // Get enhanced details for these videos to get viewer counts
            let videoIds = result.items.compactMap { $0.videoId }
            if !videoIds.isEmpty {
                let detailedVideos = try await youtubeService.getEnhancedVideoDetails(videoIds: videoIds)
                return detailedVideos.items.compactMap { convertYouTubeVideoToDiscovered($0) }
            } else {
                return result.items.compactMap { convertYouTubeSearchToDiscovered($0) }
            }
        } catch {
            platformsOnline.remove(.youtube)
            errorCounts[.youtube, default: 0] += 1
            throw error
        }
    }
    
    private func loadYouTubeTrendingStreams() async throws -> [DiscoveredStream] {
        do {
            let result = try await youtubeService.getTrendingLiveStreams(maxResults: 15)
            
            // Get enhanced details for better data
            let videoIds = result.items.compactMap { $0.videoId }
            if !videoIds.isEmpty {
                let detailedVideos = try await youtubeService.getEnhancedVideoDetails(videoIds: videoIds)
                return detailedVideos.items.filter { $0.isLive }.map { convertYouTubeVideoToDiscovered($0) }
            } else {
                return result.items.compactMap { convertYouTubeSearchToDiscovered($0) }
            }
        } catch {
            errorCounts[.youtube, default: 0] += 1
            throw error
        }
    }
    
    // MARK: - Search Methods
    
    private func searchTwitchStreams(query: String, filters: SearchFilters) async throws -> [DiscoveredStream] {
        let result = try await twitchService.searchLiveStreams(query: query, first: 15)
        return result.streams.map { $0.toDiscovered() }
    }
    
    private func searchYouTubeStreams(query: String, filters: SearchFilters) async throws -> [DiscoveredStream] {
        let result = try await youtubeService.searchLiveStreams(
            query: query,
            maxResults: 15
        )
        
        // Get enhanced details for better data if we have video IDs
        let videoIds = result.items.compactMap { $0.videoId }
        if !videoIds.isEmpty {
            let detailedVideos = try await youtubeService.getEnhancedVideoDetails(videoIds: videoIds)
            return detailedVideos.items.filter { $0.isLive }.map { convertYouTubeVideoToDiscovered($0) }
        } else {
            return result.items.compactMap { convertYouTubeSearchToDiscovered($0) }
        }
    }
    
    // MARK: - Helper Methods
    
    private func shouldSearchPlatform(_ platform: Platform, filters: SearchFilters) -> Bool {
        guard configuration.enabledPlatforms.contains(platform) else { return false }
        
        if let allowedPlatforms = filters.platforms {
            return allowedPlatforms.contains(platform)
        }
        
        return true
    }
    
    private func applyFilters(_ streams: [DiscoveredStream], filters: SearchFilters) -> [DiscoveredStream] {
        return streams.filter { stream in
            // Live only filter
            if filters.liveOnly && !stream.isLive {
                return false
            }
            
            // Viewer count filters
            if let minViewers = filters.minViewers, stream.viewerCount < minViewers {
                return false
            }
            
            if let maxViewers = filters.maxViewers, stream.viewerCount > maxViewers {
                return false
            }
            
            // Language filter
            if let languages = filters.languages,
               let streamLanguage = stream.language,
               !languages.contains(streamLanguage) {
                return false
            }
            
            // Category filter
            if let categories = filters.categories,
               let streamCategory = stream.category,
               !categories.contains(streamCategory) {
                return false
            }
            
            // NSFW filter
            if !filters.includeNSFW && stream.isMature {
                return false
            }
            
            return true
        }
    }
    
    private func sortSearchResults(_ streams: [DiscoveredStream], by sortOption: SearchFilters.SortOption) -> [DiscoveredStream] {
        switch sortOption {
        case .relevance:
            return streams // Already sorted by relevance from APIs
        case .viewerCount:
            return streams.sorted { $0.viewerCount > $1.viewerCount }
        case .startTime:
            return streams.sorted { (stream1, stream2) in
                guard let start1 = stream1.startedAt, let start2 = stream2.startedAt else {
                    return stream1.startedAt != nil
                }
                return start1 > start2
            }
        case .alphabetical:
            return streams.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .platform:
            return streams.sorted { $0.platform.displayName < $1.platform.displayName }
        }
    }
    
    private func calculateTrendingScore(_ stream: DiscoveredStream) -> Double {
        var score = Double(stream.viewerCount)
        
        // Boost recent streams
        if let startedAt = stream.startedAt {
            let hoursAgo = Date().timeIntervalSince(startedAt) / 3600
            if hoursAgo < 2 {
                score *= 1.5 // 50% boost for streams started in last 2 hours
            } else if hoursAgo < 6 {
                score *= 1.2 // 20% boost for streams started in last 6 hours
            }
        }
        
        return score
    }
    
    // MARK: - Conversion Methods
    
    private func convertYouTubeSearchToDiscovered(_ item: YouTubeSearchResult.SearchResultItem) -> DiscoveredStream? {
        guard item.isLive, let videoId = item.videoId else { return nil }
        
        return DiscoveredStream(
            id: "youtube_\(videoId)",
            title: item.snippet.title,
            channelName: item.snippet.channelTitle,
            platform: .youtube,
            viewerCount: 0, // YouTube search doesn't provide viewer count
            isLive: true,
            thumbnailURL: item.bestThumbnailUrl,
            streamURL: "https://www.youtube.com/watch?v=\(videoId)",
            category: nil,
            language: configuration.preferredLanguages.first,
            startedAt: parseISODate(item.snippet.publishedAt),
            tags: [],
            description: item.snippet.description,
            isMature: false
        )
    }
    
    private func convertYouTubeVideoToDiscovered(_ video: YouTubeVideo) -> DiscoveredStream {
        return DiscoveredStream(
            id: "youtube_\(video.id)",
            title: video.snippet.title,
            channelName: video.snippet.channelTitle,
            platform: .youtube,
            viewerCount: video.viewCountInt,
            isLive: video.isLive,
            thumbnailURL: video.bestThumbnailUrl,
            streamURL: "https://www.youtube.com/watch?v=\(video.id)",
            category: nil, // Would need to map category ID
            language: video.snippet.defaultLanguage,
            startedAt: parseISODate(video.snippet.publishedAt),
            tags: video.snippet.tags ?? [],
            description: video.snippet.description,
            isMature: false
        )
    }
    
    private func parseISODate(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: isoString)
    }
    
    // MARK: - Cache Management
    
    private func getCachedData<T: Codable>(_ key: String) -> T? {
        return cacheQueue.sync {
            guard let cached = memoryCache[key],
                  Date().timeIntervalSince(cached.timestamp) < configuration.cacheDuration else {
                memoryCache.removeValue(forKey: key)
                return nil
            }
            
            return cached.data as? T
        }
    }
    
    private func setCachedData<T: Codable>(_ key: String, data: T, expiration: TimeInterval? = nil) {
        let expirationTime = expiration ?? configuration.cacheDuration
        cacheQueue.async {
            self.memoryCache[key] = (data, Date())
            
            // Clean up old cache entries
            let cutoff = Date().addingTimeInterval(-expirationTime)
            self.memoryCache = self.memoryCache.filter { $0.value.timestamp > cutoff }
        }
    }
    
    // MARK: - Task Management
    
    private func performDiscoveryTask<T>(_ taskName: String, operation: @escaping () async throws -> T) async rethrows -> T? {
        isLoading = true
        error = nil
        
        // Prevent duplicate requests
        requestsLock.lock()
        if activeRequests.contains(taskName) {
            requestsLock.unlock()
            return nil
        }
        activeRequests.insert(taskName)
        requestsLock.unlock()
        
        defer {
            isLoading = false
            requestsLock.lock()
            activeRequests.remove(taskName)
            requestsLock.unlock()
        }
        
        do {
            let result = try await operation()
            lastUpdated = Date()
            return result
        } catch {
            let discoveryError = StreamDiscoveryError.operationFailed(taskName, error)
            self.error = discoveryError
            print("❌ StreamDiscoveryService task '\(taskName)' failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Auto Refresh and Monitoring
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: configuration.autoRefreshInterval, repeats: true) { _ in
            Task {
                await self.loadTrendingContent()
            }
        }
    }
    
    private func setupErrorHandling() {
        // Monitor Twitch service errors
        twitchService.$error
            .compactMap { $0 }
            .sink { [weak self] twitchError in
                self?.error = .platformError(.twitch, twitchError)
            }
            .store(in: &cancellables)
        
        // Monitor YouTube service errors
        youtubeService.$lastError
            .compactMap { $0 }
            .sink { [weak self] youtubeError in
                self?.error = .platformError(.youtube, youtubeError)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Live Status Monitoring
    
    /// Monitor live status of followed streams
    public func startLiveStatusMonitoring(for streamIds: [String]) async {
        guard !streamIds.isEmpty else { return }
        
        await performDiscoveryTask("liveStatusMonitoring") {
            var liveStatusUpdates: [String: Bool] = [:]
            
            // Check Twitch streams
            let twitchStreamIds = streamIds.filter { $0.hasPrefix("twitch_") }
                .map { String($0.dropFirst(7)) } // Remove "twitch_" prefix
            
            if !twitchStreamIds.isEmpty && self.configuration.enabledPlatforms.contains(.twitch) {
                do {
                    let twitchStreams = try await self.twitchService.getStreamsByIds(twitchStreamIds)
                    for stream in twitchStreams.streams {
                        liveStatusUpdates["twitch_\(stream.id)"] = stream.type == "live"
                    }
                } catch {
                    print("Failed to check Twitch live status: \(error)")
                }
            }
            
            // Check YouTube streams
            let youtubeVideoIds = streamIds.filter { $0.hasPrefix("youtube_") }
                .map { String($0.dropFirst(8)) } // Remove "youtube_" prefix
            
            if !youtubeVideoIds.isEmpty && self.configuration.enabledPlatforms.contains(.youtube) {
                do {
                    let youtubeVideos = try await self.youtubeService.getEnhancedVideoDetails(videoIds: youtubeVideoIds)
                    for video in youtubeVideos.items {
                        liveStatusUpdates["youtube_\(video.id)"] = video.isLive
                    }
                } catch {
                    print("Failed to check YouTube live status: \(error)")
                }
            }
            
            // Notify about status changes
            for (streamId, isLive) in liveStatusUpdates {
                await self.notifyLiveStatusChange(streamId: streamId, isLive: isLive)
            }
        }
    }
    
    /// Check if a specific stream is currently live
    public func checkStreamLiveStatus(streamId: String) async -> Bool? {
        if streamId.hasPrefix("twitch_") {
            let twitchId = String(streamId.dropFirst(7))
            do {
                let result = try await twitchService.getStreamsByIds([twitchId])
                return result.streams.first?.type == "live"
            } catch {
                print("Failed to check Twitch stream status: \(error)")
                return nil
            }
        } else if streamId.hasPrefix("youtube_") {
            let videoId = String(streamId.dropFirst(8))
            do {
                let result = try await youtubeService.getEnhancedVideoDetails(videoIds: [videoId])
                return result.items.first?.isLive
            } catch {
                print("Failed to check YouTube stream status: \(error)")
                return nil
            }
        }
        return nil
    }
    
    /// Get notification preferences for live status updates
    public func getLiveNotificationPreferences() -> LiveNotificationPreferences {
        let defaults = UserDefaults.standard
        return LiveNotificationPreferences(
            enabled: defaults.bool(forKey: "live_notifications_enabled"),
            showBanner: defaults.bool(forKey: "live_notifications_banner"),
            playSound: defaults.bool(forKey: "live_notifications_sound"),
            platforms: Set(defaults.stringArray(forKey: "live_notifications_platforms")?.compactMap(Platform.init) ?? [.twitch, .youtube])
        )
    }
    
    /// Update notification preferences for live status updates
    public func updateLiveNotificationPreferences(_ preferences: LiveNotificationPreferences) {
        let defaults = UserDefaults.standard
        defaults.set(preferences.enabled, forKey: "live_notifications_enabled")
        defaults.set(preferences.showBanner, forKey: "live_notifications_banner")
        defaults.set(preferences.playSound, forKey: "live_notifications_sound")
        defaults.set(preferences.platforms.map { $0.rawValue }, forKey: "live_notifications_platforms")
    }
    
    private func notifyLiveStatusChange(streamId: String, isLive: Bool) async {
        let preferences = getLiveNotificationPreferences()
        guard preferences.enabled else { return }
        
        // Get stream details for notification
        if let cachedStream = getCachedStreamDetails(streamId) {
            await sendLiveStatusNotification(stream: cachedStream, isLive: isLive, preferences: preferences)
        }
    }
    
    private func getCachedStreamDetails(_ streamId: String) -> DiscoveredStream? {
        // Check in featured streams
        if let stream = featuredStreams.first(where: { $0.id == streamId }) {
            return stream
        }
        
        // Check in trending streams
        if let stream = trendingStreams.first(where: { $0.id == streamId }) {
            return stream
        }
        
        // Check in search results
        if let stream = searchResults.first(where: { $0.id == streamId }) {
            return stream
        }
        
        return nil
    }
    
    private func sendLiveStatusNotification(stream: DiscoveredStream, isLive: Bool, preferences: LiveNotificationPreferences) async {
        guard preferences.platforms.contains(stream.platform) else { return }
        
        let title = isLive ? "🔴 Stream Started" : "⏹️ Stream Ended"
        let body = isLive 
            ? "\(stream.channelName) is now live: \(stream.title)"
            : "\(stream.channelName) has ended their stream"
        
        // Send local notification
        await NotificationManager.shared.scheduleNotification(
            id: "live_status_\(stream.id)",
            title: title,
            body: body,
            data: [
                "stream_id": stream.id,
                "platform": stream.platform.rawValue,
                "is_live": isLive
            ],
            playSound: preferences.playSound
        )
        
        // Track analytics
        AnalyticsManager.shared.trackStreamStatusChange(
            streamId: stream.id,
            platform: stream.platform.rawValue,
            isLive: isLive
        )
    }
    
    // MARK: - Analytics and Performance
    
    public func getPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            platformPerformance: platformPerformance,
            errorCounts: errorCounts,
            searchQueries: searchQueries,
            cacheHitRate: calculateCacheHitRate(),
            lastUpdated: lastUpdated
        )
    }
    
    private func calculateCacheHitRate() -> Double {
        // Simplified cache hit rate calculation
        let totalRequests = platformPerformance.values.count
        guard totalRequests > 0 else { return 0 }
        
        let cacheSize = memoryCache.count
        return Double(cacheSize) / Double(totalRequests)
    }
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

public enum ContentRating {
    case general
    case teen
    case mature
    case all
}

public struct LiveNotificationPreferences {
    public var enabled: Bool
    public var showBanner: Bool
    public var playSound: Bool
    public var platforms: Set<Platform>
    
    public init(enabled: Bool = true, showBanner: Bool = true, playSound: Bool = true, platforms: Set<Platform> = [.twitch, .youtube]) {
        self.enabled = enabled
        self.showBanner = showBanner
        self.playSound = playSound
        self.platforms = platforms
    }
}

public struct StreamCategory {
    public let name: String
    public let displayName: String
    public let icon: String
    public let color: Color
    
    public static func from(name: String) -> StreamCategory? {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("gaming") || lowercaseName.contains("game") {
            return StreamCategory(name: name, displayName: "Gaming", icon: "gamecontroller.fill", color: .blue)
        } else if lowercaseName.contains("music") {
            return StreamCategory(name: name, displayName: "Music", icon: "music.note", color: .purple)
        } else if lowercaseName.contains("tech") || lowercaseName.contains("science") {
            return StreamCategory(name: name, displayName: "Tech", icon: "laptopcomputer", color: .green)
        } else if lowercaseName.contains("sport") {
            return StreamCategory(name: name, displayName: "Sports", icon: "sportscourt.fill", color: .orange)
        } else if lowercaseName.contains("art") || lowercaseName.contains("creative") {
            return StreamCategory(name: name, displayName: "Art", icon: "paintbrush.fill", color: .pink)
        } else if lowercaseName.contains("chat") || lowercaseName.contains("talk") {
            return StreamCategory(name: name, displayName: "Chat", icon: "bubble.left.and.bubble.right.fill", color: .teal)
        } else {
            return StreamCategory(name: name, displayName: name, icon: "tv.fill", color: .gray)
        }
    }
}

public enum StreamDiscoveryError: Error, LocalizedError {
    case operationFailed(String, Error)
    case platformError(Platform, Error)
    case invalidConfiguration
    case networkUnavailable
    case noResultsFound
    case rateLimitExceeded(Platform)
    
    public var errorDescription: String? {
        switch self {
        case .operationFailed(let operation, let error):
            return "Operation '\(operation)' failed: \(error.localizedDescription)"
        case .platformError(let platform, let error):
            return "\(platform.displayName) error: \(error.localizedDescription)"
        case .invalidConfiguration:
            return "Invalid service configuration"
        case .networkUnavailable:
            return "Network is unavailable"
        case .noResultsFound:
            return "No results found"
        case .rateLimitExceeded(let platform):
            return "Rate limit exceeded for \(platform.displayName)"
        }
    }
}

public struct PerformanceMetrics {
    public let platformPerformance: [Platform: TimeInterval]
    public let errorCounts: [Platform: Int]
    public let searchQueries: [String]
    public let cacheHitRate: Double
    public let lastUpdated: Date?
    
    public var averageResponseTime: TimeInterval {
        let times = platformPerformance.values
        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }
    
    public var totalErrors: Int {
        return errorCounts.values.reduce(0, +)
    }
    
    public var mostSearchedTerms: [String] {
        let queryCount = Dictionary(grouping: searchQueries) { $0 }
            .mapValues { $0.count }
        
        return queryCount.sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
    }
}

// MARK: - Platform Integration Extensions

extension TwitchStream {
    func toDiscovered() -> DiscoveredStream {
        return DiscoveredStream(
            id: "twitch_\(id)",
            title: title,
            channelName: userName,
            platform: .twitch,
            viewerCount: viewerCount,
            isLive: type == "live",
            thumbnailURL: thumbnailURL,
            streamURL: "https://twitch.tv/\(userLogin)",
            category: gameName.isEmpty ? nil : gameName,
            language: language,
            startedAt: parseISODate(startedAt),
            tags: tags ?? [],
            description: nil,
            isMature: isMature
        )
    }
    
    private func parseISODate(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: isoString)
    }
}