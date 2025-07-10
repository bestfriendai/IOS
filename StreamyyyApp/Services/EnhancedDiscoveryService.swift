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
        // Mock implementation - would use YouTube Data API
        return generateMockStreams(platform: .youtube, count: 10)
    }
    
    private func loadYouTubeTrending() async throws -> [DiscoveredStream] {
        // Mock implementation - would use YouTube Data API
        return generateMockStreams(platform: .youtube, count: 15)
    }
    
    private func searchYouTube(query: String, filters: SearchFilters) async throws -> [DiscoveredStream] {
        // Mock implementation - would use YouTube Data API
        return generateMockStreams(platform: .youtube, count: 20, query: query)
    }
    
    private func loadYouTubeCategories() async throws -> [StreamCategory] {
        // Mock categories
        return [
            StreamCategory(id: "gaming", name: "Gaming", platform: .youtube, viewerCount: 50000, streamCount: 500),
            StreamCategory(id: "music", name: "Music", platform: .youtube, viewerCount: 30000, streamCount: 300),
            StreamCategory(id: "entertainment", name: "Entertainment", platform: .youtube, viewerCount: 40000, streamCount: 400)
        ]
    }
    
    private func getYouTubeRecommendations(categories: [String]) async throws -> [DiscoveredStream] {
        return generateMockStreams(platform: .youtube, count: 15)
    }
    
    private func loadRumbleFeatured() async throws -> [DiscoveredStream] {
        // Mock implementation - would use Rumble API if available
        return generateMockStreams(platform: .rumble, count: 8)
    }
    
    private func loadRumbleTrending() async throws -> [DiscoveredStream] {
        // Mock implementation
        return generateMockStreams(platform: .rumble, count: 12)
    }
    
    private func searchRumble(query: String, filters: SearchFilters) async throws -> [DiscoveredStream] {
        // Mock implementation
        return generateMockStreams(platform: .rumble, count: 15, query: query)
    }
    
    private func loadRumbleCategories() async throws -> [StreamCategory] {
        // Mock categories
        return [
            StreamCategory(id: "news", name: "News", platform: .rumble, viewerCount: 25000, streamCount: 150),
            StreamCategory(id: "politics", name: "Politics", platform: .rumble, viewerCount: 20000, streamCount: 100),
            StreamCategory(id: "education", name: "Education", platform: .rumble, viewerCount: 15000, streamCount: 80)
        ]
    }
    
    private func getRumbleRecommendations(categories: [String]) async throws -> [DiscoveredStream] {
        return generateMockStreams(platform: .rumble, count: 10)
    }
    
    // MARK: - Utility Methods
    
    private func calculateTrendingScore(_ stream: DiscoveredStream) -> Double {
        let viewerWeight = Double(stream.viewerCount) * 0.7
        let recencyWeight = stream.isLive ? 1000.0 : 0.0
        let platformWeight = stream.platform == .twitch ? 100.0 : 50.0
        
        return viewerWeight + recencyWeight + platformWeight
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
    
    // MARK: - Cache Management
    
    private func getCachedData(for key: NSString) -> CachedData? {
        guard let data = cache.object(forKey: key),
              Date().timeIntervalSince(data.timestamp) < cacheTimeout else {
            return nil
        }
        return data
    }
    
    private func cacheData(_ streams: [DiscoveredStream], for key: NSString) {
        let cachedData = CachedData(streams: streams, timestamp: Date())
        cache.setObject(cachedData, forKey: key)
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
            id: self.streamID ?? UUID().uuidString,
            title: self.title ?? "Untitled Stream",
            channelName: self.channelName ?? "Unknown Channel",
            platform: self.platform,
            viewerCount: self.viewerCount ?? 0,
            isLive: self.isLive,
            thumbnailURL: self.thumbnailURL,
            streamURL: self.url,
            category: self.category,
            language: self.language,
            startedAt: self.startedAt
        )
    }
}