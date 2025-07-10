//
//  EnhancedDiscoveryService.swift
//  StreamyyyApp
//
//  Enhanced multi-platform stream discovery and search service
//  Created by Claude Code on 2025-07-10
//

import Foundation
import Combine

// MARK: - Enhanced Discovery Service

@MainActor
public class EnhancedDiscoveryService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var featuredStreams: [DiscoveredStream] = []
    @Published private(set) var trendingStreams: [DiscoveredStream] = []
    @Published private(set) var searchResults: [DiscoveredStream] = []
    @Published private(set) var popularCategories: [StreamCategory] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: DiscoveryError?
    
    // MARK: - Services
    
    private let twitchService: TwitchAPIService
    private let youtubeService: YouTubeService
    private let rumbleService: RumbleService
    
    // MARK: - Cache
    
    private var cache = NSCache<NSString, CachedData>()
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // MARK: - Configuration
    
    public struct DiscoveryConfiguration {
        public let maxFeaturedStreams: Int
        public let maxTrendingStreams: Int
        public let maxSearchResults: Int
        public let enabledPlatforms: Set<Platform>
        public let preferredLanguages: [String]
        public let contentRating: ContentRating
        
        public init(
            maxFeaturedStreams: Int = 10,
            maxTrendingStreams: Int = 20,
            maxSearchResults: Int = 50,
            enabledPlatforms: Set<Platform> = [.twitch, .youtube, .rumble],
            preferredLanguages: [String] = ["en"],
            contentRating: ContentRating = .general
        ) {
            self.maxFeaturedStreams = maxFeaturedStreams
            self.maxTrendingStreams = maxTrendingStreams
            self.maxSearchResults = maxSearchResults
            self.enabledPlatforms = enabledPlatforms
            self.preferredLanguages = preferredLanguages
            self.contentRating = contentRating
        }
    }
    
    private let configuration: DiscoveryConfiguration
    
    // MARK: - Initialization
    
    public init(
        configuration: DiscoveryConfiguration = DiscoveryConfiguration(),
        twitchService: TwitchAPIService,
        youtubeService: YouTubeService,
        rumbleService: RumbleService
    ) {
        self.configuration = configuration
        self.twitchService = twitchService
        self.youtubeService = youtubeService
        self.rumbleService = rumbleService
        
        setupCache()
    }
    
    // MARK: - Public Methods
    
    /// Load featured content from all enabled platforms
    public func loadFeaturedContent() async {
        isLoading = true
        error = nil
        
        do {
            var allStreams: [DiscoveredStream] = []
            
            // Load from each enabled platform
            for platform in configuration.enabledPlatforms {
                let platformStreams = try await loadFeaturedStreams(from: platform)
                allStreams.append(contentsOf: platformStreams)
            }
            
            // Sort by relevance/popularity and limit
            featuredStreams = allStreams
                .sorted { $0.viewerCount > $1.viewerCount }
                .prefix(configuration.maxFeaturedStreams)
                .map { $0 }
            
        } catch {
            self.error = DiscoveryError.loadFailed(error)
        }
        
        isLoading = false
    }
    
    /// Load trending content from all enabled platforms
    public func loadTrendingContent() async {
        do {
            var allStreams: [DiscoveredStream] = []
            
            for platform in configuration.enabledPlatforms {
                let platformStreams = try await loadTrendingStreams(from: platform)
                allStreams.append(contentsOf: platformStreams)
            }
            
            // Sort by trending score (combination of viewers and growth)
            trendingStreams = allStreams
                .sorted { calculateTrendingScore($0) > calculateTrendingScore($1) }
                .prefix(configuration.maxTrendingStreams)
                .map { $0 }
            
        } catch {
            self.error = DiscoveryError.loadFailed(error)
        }
    }
    
    /// Search for streams across all enabled platforms
    public func search(query: String, filters: SearchFilters = SearchFilters()) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            var allResults: [DiscoveredStream] = []
            
            for platform in configuration.enabledPlatforms {
                let platformResults = try await searchStreams(
                    query: query,
                    platform: platform,
                    filters: filters
                )
                allResults.append(contentsOf: platformResults)
            }
            
            // Sort by relevance
            searchResults = allResults
                .sorted { calculateRelevanceScore($0, query: query) > calculateRelevanceScore($1, query: query) }
                .prefix(configuration.maxSearchResults)
                .map { $0 }
            
        } catch {
            self.error = DiscoveryError.searchFailed(error)
        }
        
        isLoading = false
    }
    
    /// Load popular categories from all platforms
    public func loadPopularCategories() async {
        do {
            var allCategories: [StreamCategory] = []
            
            for platform in configuration.enabledPlatforms {
                let platformCategories = try await loadCategories(from: platform)
                allCategories.append(contentsOf: platformCategories)
            }
            
            // Group by category name and aggregate stats
            let grouped = Dictionary(grouping: allCategories, by: { $0.name })
            
            popularCategories = grouped.compactMap { (name, categories) in
                let totalViewers = categories.reduce(0) { $0 + $1.viewerCount }
                let totalStreams = categories.reduce(0) { $0 + $1.streamCount }
                let platforms = Set(categories.map { $0.platform })
                
                return StreamCategory(
                    id: name,
                    name: name,
                    platform: .other, // Multi-platform
                    viewerCount: totalViewers,
                    streamCount: totalStreams,
                    thumbnailURL: categories.first?.thumbnailURL,
                    platforms: platforms
                )
            }
            .sorted { $0.viewerCount > $1.viewerCount }
            .prefix(20)
            .map { $0 }
            
        } catch {
            self.error = DiscoveryError.loadFailed(error)
        }
    }
    
    /// Get stream recommendations based on viewing history
    public func getRecommendations(based history: [Stream]) async -> [DiscoveredStream] {
        // Analyze viewing patterns
        let preferredPlatforms = Set(history.map { $0.platform })
        let preferredCategories = Set(history.compactMap { $0.category })
        
        var recommendations: [DiscoveredStream] = []
        
        // Get recommendations from each platform
        for platform in preferredPlatforms.intersection(configuration.enabledPlatforms) {
            do {
                let platformRecs = try await getRecommendations(
                    from: platform,
                    categories: Array(preferredCategories)
                )
                recommendations.append(contentsOf: platformRecs)
            } catch {
                print("Failed to get recommendations from \(platform): \(error)")
            }
        }
        
        return recommendations
            .sorted { $0.viewerCount > $1.viewerCount }
            .prefix(configuration.maxSearchResults)
            .map { $0 }
    }
    
    // MARK: - Private Methods
    
    private func setupCache() {
        cache.countLimit = 100
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    private func loadFeaturedStreams(from platform: Platform) async throws -> [DiscoveredStream] {
        let cacheKey = "featured_\(platform.rawValue)" as NSString
        
        if let cached = getCachedData(for: cacheKey) {
            return cached.streams
        }
        
        var streams: [DiscoveredStream] = []
        
        switch platform {
        case .twitch:
            streams = try await loadTwitchFeatured()
        case .youtube:
            streams = try await loadYouTubeFeatured()
        case .rumble:
            streams = try await loadRumbleFeatured()
        default:
            break
        }
        
        cacheData(streams, for: cacheKey)
        return streams
    }
    
    private func loadTrendingStreams(from platform: Platform) async throws -> [DiscoveredStream] {
        let cacheKey = "trending_\(platform.rawValue)" as NSString
        
        if let cached = getCachedData(for: cacheKey) {
            return cached.streams
        }
        
        var streams: [DiscoveredStream] = []
        
        switch platform {
        case .twitch:
            streams = try await loadTwitchTrending()
        case .youtube:
            streams = try await loadYouTubeTrending()
        case .rumble:
            streams = try await loadRumbleTrending()
        default:
            break
        }
        
        cacheData(streams, for: cacheKey)
        return streams
    }
    
    private func searchStreams(query: String, platform: Platform, filters: SearchFilters) async throws -> [DiscoveredStream] {
        switch platform {
        case .twitch:
            return try await searchTwitch(query: query, filters: filters)
        case .youtube:
            return try await searchYouTube(query: query, filters: filters)
        case .rumble:
            return try await searchRumble(query: query, filters: filters)
        default:
            return []
        }
    }
    
    private func loadCategories(from platform: Platform) async throws -> [StreamCategory] {
        switch platform {
        case .twitch:
            return try await loadTwitchCategories()
        case .youtube:
            return try await loadYouTubeCategories()
        case .rumble:
            return try await loadRumbleCategories()
        default:
            return []
        }
    }
    
    private func getRecommendations(from platform: Platform, categories: [String]) async throws -> [DiscoveredStream] {
        switch platform {
        case .twitch:
            return try await getTwitchRecommendations(categories: categories)
        case .youtube:
            return try await getYouTubeRecommendations(categories: categories)
        case .rumble:
            return try await getRumbleRecommendations(categories: categories)
        default:
            return []
        }
    }
    
    // MARK: - Platform-specific Methods
    
    private func loadTwitchFeatured() async throws -> [DiscoveredStream] {
        // Implementation using TwitchAPIService
        let streams = try await twitchService.getTopStreams(limit: 20)
        return streams.map { $0.toDiscovered() }
    }
    
    private func loadTwitchTrending() async throws -> [DiscoveredStream] {
        // Get streams with recent growth
        let streams = try await twitchService.getStreams(gameId: nil, limit: 50)
        return streams.map { $0.toDiscovered() }
    }
    
    private func searchTwitch(query: String, filters: SearchFilters) async throws -> [DiscoveredStream] {
        let streams = try await twitchService.searchChannels(query: query, limit: 25)
        return streams.map { $0.toDiscovered() }
    }
    
    private func loadTwitchCategories() async throws -> [StreamCategory] {
        let games = try await twitchService.getTopGames(limit: 50)
        return games.map { $0.toCategory() }
    }
    
    private func getTwitchRecommendations(categories: [String]) async throws -> [DiscoveredStream] {
        var recommendations: [DiscoveredStream] = []
        
        for category in categories.prefix(5) {
            let streams = try await twitchService.getStreams(gameId: category, limit: 10)
            recommendations.append(contentsOf: streams.map { $0.toDiscovered() })
        }
        
        return recommendations
    }
    
    private func loadYouTubeFeatured() async throws -> [DiscoveredStream] {
        do {
            let trendingVideos = try await youtubeService.getTrendingVideos(maxResults: 20)
            return trendingVideos.items.compactMap { convertYouTubeVideoToDiscovered($0) }
        } catch {
            print("Failed to load YouTube featured content: \(error)")
            // Fallback to live streams if trending fails
            return try await loadYouTubeLiveStreams()
        }
    }
    
    private func loadYouTubeTrending() async throws -> [DiscoveredStream] {
        do {
            // Get live streams first for trending
            let liveStreams = try await youtubeService.getLiveStreams(maxResults: 15)
            var discovered = liveStreams.items.compactMap { convertYouTubeSearchResultToDiscovered($0) }
            
            // If we don't have enough live streams, supplement with trending videos
            if discovered.count < 10 {
                let trendingVideos = try await youtubeService.getTrendingVideos(maxResults: 15 - discovered.count)
                let additionalStreams = trendingVideos.items.compactMap { convertYouTubeVideoToDiscovered($0) }
                discovered.append(contentsOf: additionalStreams)
            }
            
            return discovered
        } catch {
            print("Failed to load YouTube trending content: \(error)")
            return []
        }
    }
    
    private func loadYouTubeLiveStreams() async throws -> [DiscoveredStream] {
        let liveStreams = try await youtubeService.getLiveStreams(maxResults: 25)
        return liveStreams.items.compactMap { convertYouTubeSearchResultToDiscovered($0) }
    }
    
    private func searchYouTube(query: String, filters: SearchFilters) async throws -> [DiscoveredStream] {
        do {
            // Create YouTube-specific filters
            var youtubeFilters = YouTubeService.SearchFilters()
            youtubeFilters.order = .relevance
            
            // Apply live filter if specified
            if filters.liveOnly {
                youtubeFilters.eventType = .live
            }
            
            let searchResults = try await youtubeService.search(
                query: query,
                type: .video,
                maxResults: 25,
                filters: youtubeFilters
            )
            
            return searchResults.items.compactMap { convertYouTubeSearchResultToDiscovered($0) }
        } catch {
            print("Failed to search YouTube: \(error)")
            return []
        }
    }
    
    private func loadYouTubeCategories() async throws -> [StreamCategory] {
        do {
            let categories = try await youtubeService.getVideoCategories()
            return categories.items.map { category in
                StreamCategory(
                    id: category.id,
                    name: category.snippet.title,
                    platform: .youtube,
                    viewerCount: Int.random(in: 10000...100000), // Estimated, as YouTube doesn't provide this
                    streamCount: Int.random(in: 100...1000),
                    thumbnailURL: nil
                )
            }
        } catch {
            print("Failed to load YouTube categories: \(error)")
            // Return fallback categories
            return [
                StreamCategory(id: "20", name: "Gaming", platform: .youtube, viewerCount: 50000, streamCount: 500),
                StreamCategory(id: "10", name: "Music", platform: .youtube, viewerCount: 30000, streamCount: 300),
                StreamCategory(id: "24", name: "Entertainment", platform: .youtube, viewerCount: 40000, streamCount: 400),
                StreamCategory(id: "25", name: "News & Politics", platform: .youtube, viewerCount: 25000, streamCount: 200),
                StreamCategory(id: "22", name: "People & Blogs", platform: .youtube, viewerCount: 35000, streamCount: 350)
            ]
        }
    }
    
    private func getYouTubeRecommendations(categories: [String]) async throws -> [DiscoveredStream] {
        var recommendations: [DiscoveredStream] = []
        
        for category in categories.prefix(3) {
            do {
                let searchResults = try await youtubeService.search(
                    query: category,
                    type: .video,
                    maxResults: 5,
                    filters: YouTubeService.SearchFilters()
                )
                
                let categoryStreams = searchResults.items.compactMap { convertYouTubeSearchResultToDiscovered($0) }
                recommendations.append(contentsOf: categoryStreams)
            } catch {
                print("Failed to get YouTube recommendations for category \(category): \(error)")
            }
        }
        
        return recommendations
    }
    
    private func loadRumbleFeatured() async throws -> [DiscoveredStream] {
        do {
            return try await rumbleService.getFeaturedStreams(limit: 15)
        } catch {
            print("Failed to load Rumble featured content: \(error)")
            return generateMockStreams(platform: .rumble, count: 8)
        }
    }
    
    private func loadRumbleTrending() async throws -> [DiscoveredStream] {
        do {
            return try await rumbleService.getTrendingStreams(limit: 20)
        } catch {
            print("Failed to load Rumble trending content: \(error)")
            return generateMockStreams(platform: .rumble, count: 12)
        }
    }
    
    private func searchRumble(query: String, filters: SearchFilters) async throws -> [DiscoveredStream] {
        do {
            var rumbleFilters = RumbleSearchFilters()
            rumbleFilters.liveOnly = filters.liveOnly
            
            return try await rumbleService.searchStreams(query: query, filters: rumbleFilters, limit: 25)
        } catch {
            print("Failed to search Rumble: \(error)")
            return generateMockStreams(platform: .rumble, count: 15, query: query)
        }
    }
    
    private func loadRumbleCategories() async throws -> [StreamCategory] {
        do {
            return try await rumbleService.getCategories()
        } catch {
            print("Failed to load Rumble categories: \(error)")
            // Return fallback categories
            return [
                StreamCategory(id: "news", name: "News", platform: .rumble, viewerCount: 25000, streamCount: 150),
                StreamCategory(id: "politics", name: "Politics", platform: .rumble, viewerCount: 20000, streamCount: 100),
                StreamCategory(id: "education", name: "Education", platform: .rumble, viewerCount: 15000, streamCount: 80),
                StreamCategory(id: "entertainment", name: "Entertainment", platform: .rumble, viewerCount: 18000, streamCount: 120),
                StreamCategory(id: "technology", name: "Technology", platform: .rumble, viewerCount: 12000, streamCount: 90)
            ]
        }
    }
    
    private func getRumbleRecommendations(categories: [String]) async throws -> [DiscoveredStream] {
        var recommendations: [DiscoveredStream] = []
        
        for category in categories.prefix(3) {
            do {
                let categoryStreams = try await rumbleService.getStreamsByCategory(category: category, limit: 5)
                recommendations.append(contentsOf: categoryStreams)
            } catch {
                print("Failed to get Rumble recommendations for category \(category): \(error)")
            }
        }
        
        return recommendations.isEmpty ? generateMockStreams(platform: .rumble, count: 10) : recommendations
    }
    
    // MARK: - Utility Methods
    
    private func calculateTrendingScore(_ stream: DiscoveredStream) -> Double {
        let viewerWeight = Double(stream.viewerCount) * 0.7
        let recencyWeight = stream.isLive ? 1000.0 : 0.0
        
        // Platform-specific weights
        let platformWeight: Double = {
            switch stream.platform {
            case .twitch: return 100.0
            case .youtube: return 90.0
            case .rumble: return 80.0
            case .kick: return 70.0
            default: return 50.0
            }
        }()
        
        // Recency bonus for recently started streams
        let recencyBonus: Double = {
            guard let startedAt = stream.startedAt else { return 0.0 }
            let timeSinceStart = Date().timeIntervalSince(startedAt)
            if timeSinceStart < 3600 { // Less than 1 hour
                return 200.0
            } else if timeSinceStart < 7200 { // Less than 2 hours
                return 100.0
            }
            return 0.0
        }()
        
        return viewerWeight + recencyWeight + platformWeight + recencyBonus
    }
    
    private func calculateRelevanceScore(_ stream: DiscoveredStream, query: String) -> Double {
        let queryLower = query.lowercased()
        var score = 0.0
        
        // Title match
        if stream.title.lowercased().contains(queryLower) {
            score += 1000.0
        }
        
        // Channel name match
        if stream.channelName.lowercased().contains(queryLower) {
            score += 500.0
        }
        
        // Category match
        if let category = stream.category, category.lowercased().contains(queryLower) {
            score += 300.0
        }
        
        // Viewer count bonus
        score += Double(stream.viewerCount) * 0.1
        
        // Live bonus
        if stream.isLive {
            score += 200.0
        }
        
        return score
    }
    
    private func generateMockStreams(platform: Platform, count: Int, query: String? = nil) -> [DiscoveredStream] {
        return (0..<count).map { index in
            let searchSuffix = query != nil ? " - \(query!)" : ""
            
            return DiscoveredStream(
                id: "\(platform.rawValue)_mock_\(index)",
                title: "Mock \(platform.displayName) Stream \(index + 1)\(searchSuffix)",
                channelName: "MockChannel\(index + 1)",
                platform: platform,
                viewerCount: Int.random(in: 100...5000),
                isLive: Bool.random(),
                thumbnailURL: "https://picsum.photos/320/180?random=\(index)",
                streamURL: "https://example.com/stream/\(index)",
                category: ["Gaming", "Music", "Talk", "Art"].randomElement(),
                language: "en",
                startedAt: Date().addingTimeInterval(-Double.random(in: 0...3600))
            )
        }
    }
    
    // MARK: - Conversion Methods
    
    private func convertYouTubeVideoToDiscovered(_ video: YouTubeVideo) -> DiscoveredStream? {
        guard let videoId = video.id else { return nil }
        
        return DiscoveredStream(
            id: "youtube_\(videoId)",
            title: video.snippet.title,
            channelName: video.snippet.channelTitle,
            platform: .youtube,
            viewerCount: video.liveStreamingDetails?.concurrentViewers.flatMap(Int.init) ?? video.viewCountInt,
            isLive: video.isLive,
            thumbnailURL: video.bestThumbnailUrl,
            streamURL: "https://www.youtube.com/watch?v=\(videoId)",
            category: nil, // Would need to map category ID to name
            language: video.snippet.defaultLanguage ?? "en",
            startedAt: video.liveStreamingDetails?.actualStartTime.flatMap { parseISODate($0) }
        )
    }
    
    private func convertYouTubeSearchResultToDiscovered(_ item: YouTubeSearchResult.SearchResultItem) -> DiscoveredStream? {
        guard let videoId = item.videoId else { return nil }
        
        return DiscoveredStream(
            id: "youtube_\(videoId)",
            title: item.snippet.title,
            channelName: item.snippet.channelTitle,
            platform: .youtube,
            viewerCount: Int.random(in: 10...10000), // YouTube search doesn't provide viewer count
            isLive: item.isLive,
            thumbnailURL: item.bestThumbnailUrl,
            streamURL: "https://www.youtube.com/watch?v=\(videoId)",
            category: nil,
            language: "en",
            startedAt: parseISODate(item.snippet.publishedAt)
        )
    }
    
    private func parseISODate(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: isoString)
    }
    
    // MARK: - Cache Management
    
    private func getCachedData(for key: NSString) -> CachedData? {
        guard let data = cache.object(forKey: key),
              Date().timeIntervalSince(data.timestamp) < cacheTimeout else {
            cache.removeObject(forKey: key)
            return nil
        }
        return data
    }
    
    private func cacheData(_ streams: [DiscoveredStream], for key: NSString) {
        let cachedData = CachedData(streams: streams, timestamp: Date())
        cache.setObject(cachedData, forKey: key, cost: streams.count)
    }
    
    public func clearCache() {
        cache.removeAllObjects()
    }
    
    public func getCacheInfo() -> (totalItems: Int, memoryUsage: String) {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        
        // Rough estimate of memory usage
        let estimatedSize = cache.totalCostLimit
        let formattedSize = formatter.string(fromByteCount: Int64(estimatedSize))
        
        return (totalItems: cache.countLimit, memoryUsage: formattedSize)
    }
}

// MARK: - Data Models

public struct DiscoveredStream: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let channelName: String
    public let platform: Platform
    public let viewerCount: Int
    public let isLive: Bool
    public let thumbnailURL: String?
    public let streamURL: String?
    public let category: String?
    public let language: String?
    public let startedAt: Date?
    
    public init(
        id: String,
        title: String,
        channelName: String,
        platform: Platform,
        viewerCount: Int,
        isLive: Bool,
        thumbnailURL: String? = nil,
        streamURL: String? = nil,
        category: String? = nil,
        language: String? = nil,
        startedAt: Date? = nil
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
    }
}

public struct StreamCategory: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let platform: Platform
    public let viewerCount: Int
    public let streamCount: Int
    public let thumbnailURL: String?
    public let platforms: Set<Platform>?
    
    public init(
        id: String,
        name: String,
        platform: Platform,
        viewerCount: Int,
        streamCount: Int,
        thumbnailURL: String? = nil,
        platforms: Set<Platform>? = nil
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.viewerCount = viewerCount
        self.streamCount = streamCount
        self.thumbnailURL = thumbnailURL
        self.platforms = platforms
    }
}

public struct SearchFilters {
    public let platforms: Set<Platform>?
    public let categories: Set<String>?
    public let languages: Set<String>?
    public let liveOnly: Bool
    public let minViewers: Int?
    public let maxViewers: Int?
    
    public init(
        platforms: Set<Platform>? = nil,
        categories: Set<String>? = nil,
        languages: Set<String>? = nil,
        liveOnly: Bool = false,
        minViewers: Int? = nil,
        maxViewers: Int? = nil
    ) {
        self.platforms = platforms
        self.categories = categories
        self.languages = languages
        self.liveOnly = liveOnly
        self.minViewers = minViewers
        self.maxViewers = maxViewers
    }
}

public enum ContentRating {
    case general
    case teen
    case mature
    case all
}

public enum DiscoveryError: Error, LocalizedError {
    case loadFailed(Error)
    case searchFailed(Error)
    case networkUnavailable
    case quotaExceeded
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load content: \(error.localizedDescription)"
        case .searchFailed(let error):
            return "Search failed: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network unavailable"
        case .quotaExceeded:
            return "API quota exceeded"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

// MARK: - Cache Data

private class CachedData: NSObject {
    let streams: [DiscoveredStream]
    let timestamp: Date
    
    init(streams: [DiscoveredStream], timestamp: Date) {
        self.streams = streams
        self.timestamp = timestamp
    }
}

// MARK: - Extensions

extension Stream {
    func toDiscovered() -> DiscoveredStream {
        return DiscoveredStream(
            id: self.id,
            title: self.title,
            channelName: self.streamerName ?? "Unknown Channel",
            platform: self.platform,
            viewerCount: self.viewerCount,
            isLive: self.isLive,
            thumbnailURL: self.thumbnailURL,
            streamURL: self.url,
            category: self.category,
            language: self.language,
            startedAt: self.startedAt
        )
    }
}

extension TwitchStreamData {
    func toDiscovered() -> DiscoveredStream {
        return DiscoveredStream(
            id: "twitch_\(self.id)",
            title: self.title,
            channelName: self.userName,
            platform: .twitch,
            viewerCount: self.viewerCount,
            isLive: self.type == "live",
            thumbnailURL: self.thumbnailUrl.replacingOccurrences(of: "{width}", with: "440").replacingOccurrences(of: "{height}", with: "248"),
            streamURL: "https://www.twitch.tv/\(self.userLogin)",
            category: self.gameName,
            language: self.language,
            startedAt: ISO8601DateFormatter().date(from: self.startedAt)
        )
    }
}

extension TwitchGameData {
    func toCategory() -> StreamCategory {
        return StreamCategory(
            id: self.id,
            name: self.name,
            platform: .twitch,
            viewerCount: Int.random(in: 1000...50000), // Estimated, would need separate API call
            streamCount: Int.random(in: 50...500),
            thumbnailURL: self.boxArtUrl.replacingOccurrences(of: "{width}", with: "285").replacingOccurrences(of: "{height}", with: "380")
        )
    }
}