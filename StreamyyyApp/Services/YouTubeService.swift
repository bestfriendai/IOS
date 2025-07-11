//
//  YouTubeService.swift
//  StreamyyyApp
//
//  YouTube Data API v3 service with comprehensive functionality
//  including quota management, caching, and live stream support
//

import Foundation
import Combine

// MARK: - YouTube API Models

struct YouTubeVideo: Codable, Identifiable {
    let id: String
    let snippet: VideoSnippet
    let statistics: VideoStatistics?
    let liveStreamingDetails: LiveStreamingDetails?
    let status: VideoStatus?
    let contentDetails: ContentDetails?
    
    struct VideoSnippet: Codable {
        let publishedAt: String
        let channelId: String
        let title: String
        let description: String
        let thumbnails: Thumbnails
        let channelTitle: String
        let tags: [String]?
        let categoryId: String
        let liveBroadcastContent: String
        let defaultLanguage: String?
        let localized: LocalizedText?
    }
    
    struct VideoStatistics: Codable {
        let viewCount: String?
        let likeCount: String?
        let dislikeCount: String?
        let favoriteCount: String?
        let commentCount: String?
    }
    
    struct LiveStreamingDetails: Codable {
        let actualStartTime: String?
        let actualEndTime: String?
        let scheduledStartTime: String?
        let scheduledEndTime: String?
        let concurrentViewers: String?
        let activeLiveChatId: String?
    }
    
    struct VideoStatus: Codable {
        let uploadStatus: String?
        let privacyStatus: String?
        let license: String?
        let embeddable: Bool?
        let publicStatsViewable: Bool?
        let madeForKids: Bool?
        let selfDeclaredMadeForKids: Bool?
    }
    
    struct ContentDetails: Codable {
        let duration: String?
        let dimension: String?
        let definition: String?
        let caption: String?
        let licensedContent: Bool?
        let projection: String?
        let hasCustomThumbnail: Bool?
    }
}

struct YouTubeChannel: Codable, Identifiable {
    let id: String
    let snippet: ChannelSnippet
    let statistics: ChannelStatistics?
    let contentDetails: ChannelContentDetails?
    let status: ChannelStatus?
    let brandingSettings: BrandingSettings?
    
    struct ChannelSnippet: Codable {
        let title: String
        let description: String
        let customUrl: String?
        let publishedAt: String
        let thumbnails: Thumbnails
        let defaultLanguage: String?
        let localized: LocalizedText?
        let country: String?
    }
    
    struct ChannelStatistics: Codable {
        let viewCount: String?
        let subscriberCount: String?
        let hiddenSubscriberCount: Bool?
        let videoCount: String?
    }
    
    struct ChannelContentDetails: Codable {
        let relatedPlaylists: RelatedPlaylists?
        
        struct RelatedPlaylists: Codable {
            let likes: String?
            let uploads: String?
            let watchHistory: String?
            let watchLater: String?
        }
    }
    
    struct ChannelStatus: Codable {
        let privacyStatus: String?
        let isLinked: Bool?
        let longUploadsStatus: String?
        let madeForKids: Bool?
        let selfDeclaredMadeForKids: Bool?
    }
    
    struct BrandingSettings: Codable {
        let channel: ChannelBranding?
        let image: ImageBranding?
        
        struct ChannelBranding: Codable {
            let title: String?
            let description: String?
            let keywords: String?
            let trackingAnalyticsAccountId: String?
            let moderateComments: Bool?
            let unsubscribedTrailer: String?
            let defaultLanguage: String?
            let country: String?
        }
        
        struct ImageBranding: Codable {
            let bannerExternalUrl: String?
            let bannerMobileExtraHdImageUrl: String?
            let bannerMobileHdImageUrl: String?
            let bannerMobileLowImageUrl: String?
            let bannerMobileMediumHdImageUrl: String?
            let bannerTabletExtraHdImageUrl: String?
            let bannerTabletHdImageUrl: String?
            let bannerTabletImageUrl: String?
            let bannerTabletLowImageUrl: String?
            let bannerTvHighImageUrl: String?
            let bannerTvImageUrl: String?
            let bannerTvLowImageUrl: String?
            let bannerTvMediumImageUrl: String?
        }
    }
}

struct YouTubePlaylist: Codable, Identifiable {
    let id: String
    let snippet: PlaylistSnippet
    let status: PlaylistStatus?
    let contentDetails: PlaylistContentDetails?
    let localizations: [String: LocalizedText]?
    
    struct PlaylistSnippet: Codable {
        let publishedAt: String
        let channelId: String
        let title: String
        let description: String
        let thumbnails: Thumbnails
        let channelTitle: String
        let tags: [String]?
        let defaultLanguage: String?
        let localized: LocalizedText?
    }
    
    struct PlaylistStatus: Codable {
        let privacyStatus: String?
    }
    
    struct PlaylistContentDetails: Codable {
        let itemCount: Int?
    }
}

struct YouTubePlaylistItem: Codable, Identifiable {
    let id: String
    let snippet: PlaylistItemSnippet
    let contentDetails: PlaylistItemContentDetails?
    let status: PlaylistItemStatus?
    
    struct PlaylistItemSnippet: Codable {
        let publishedAt: String
        let channelId: String
        let title: String
        let description: String
        let thumbnails: Thumbnails
        let channelTitle: String
        let playlistId: String
        let position: Int
        let resourceId: ResourceId
        let videoOwnerChannelTitle: String?
        let videoOwnerChannelId: String?
        
        struct ResourceId: Codable {
            let kind: String
            let videoId: String
        }
    }
    
    struct PlaylistItemContentDetails: Codable {
        let videoId: String
        let startAt: String?
        let endAt: String?
        let note: String?
        let videoPublishedAt: String?
    }
    
    struct PlaylistItemStatus: Codable {
        let privacyStatus: String?
    }
}

struct YouTubeComment: Codable, Identifiable {
    let id: String
    let snippet: CommentSnippet
    let replies: CommentReplies?
    
    struct CommentSnippet: Codable {
        let authorDisplayName: String
        let authorProfileImageUrl: String
        let authorChannelUrl: String?
        let authorChannelId: AuthorChannelId?
        let videoId: String?
        let textDisplay: String
        let textOriginal: String
        let likeCount: Int
        let moderationStatus: String?
        let publishedAt: String
        let updatedAt: String
        let canRate: Bool?
        let totalReplyCount: Int?
        let isPublic: Bool?
        
        struct AuthorChannelId: Codable {
            let value: String
        }
    }
    
    struct CommentReplies: Codable {
        let comments: [YouTubeComment]
    }
}

struct YouTubeSearchResult: Codable {
    let kind: String
    let etag: String
    let nextPageToken: String?
    let prevPageToken: String?
    let regionCode: String?
    let pageInfo: PageInfo
    let items: [SearchResultItem]
    
    struct SearchResultItem: Codable, Identifiable {
        let kind: String
        let etag: String
        let id: SearchResultId
        let snippet: SearchResultSnippet
        
        var id: String {
            return etag
        }
        
        struct SearchResultId: Codable {
            let kind: String
            let videoId: String?
            let channelId: String?
            let playlistId: String?
        }
        
        struct SearchResultSnippet: Codable {
            let publishedAt: String
            let channelId: String
            let title: String
            let description: String
            let thumbnails: Thumbnails
            let channelTitle: String
            let liveBroadcastContent: String
            let publishTime: String?
        }
    }
}

// MARK: - Common Models

struct Thumbnails: Codable {
    let `default`: ThumbnailInfo?
    let medium: ThumbnailInfo?
    let high: ThumbnailInfo?
    let standard: ThumbnailInfo?
    let maxres: ThumbnailInfo?
    
    struct ThumbnailInfo: Codable {
        let url: String
        let width: Int?
        let height: Int?
    }
}

struct LocalizedText: Codable {
    let title: String?
    let description: String?
}

struct PageInfo: Codable {
    let totalResults: Int
    let resultsPerPage: Int
}

struct YouTubeAPIResponse<T: Codable>: Codable {
    let kind: String
    let etag: String
    let nextPageToken: String?
    let prevPageToken: String?
    let pageInfo: PageInfo
    let items: [T]
}

// MARK: - YouTube API Service

@MainActor
class YouTubeService: ObservableObject {
    
    // MARK: - Properties
    
    private let apiKey: String
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let session = URLSession.shared
    
    // Cache management
    private var cache = NSCache<NSString, NSData>()
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    private var cacheTimestamps: [String: Date] = [:]
    
    // Quota management
    private var quotaUsed: Int = 0
    private var quotaResetTime: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60)
    private let maxQuotaPerDay: Int = 10000
    
    // Rate limiting
    private var lastRequestTime: Date = Date()
    private let minimumRequestInterval: TimeInterval = 0.1
    
    // Error tracking
    @Published var lastError: YouTubeAPIError?
    @Published var isLoading = false
    @Published var quotaStatus: QuotaStatus = .normal
    
    // MARK: - Initialization
    
    init(apiKey: String = Config.Platforms.YouTube.apiKey) {
        self.apiKey = apiKey
        setupCache()
        resetQuotaIfNeeded()
    }
    
    // MARK: - Setup Methods
    
    private func setupCache() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func resetQuotaIfNeeded() {
        if Date() > quotaResetTime {
            quotaUsed = 0
            quotaResetTime = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60)
            quotaStatus = .normal
        }
    }
    
    // MARK: - Video Methods
    
    func getVideo(id: String, parts: [String] = ["snippet", "statistics", "contentDetails", "status"]) async throws -> YouTubeVideo? {
        let cost = calculateQuotaCost(for: "videos", parts: parts)
        try await checkQuotaAndRateLimit(cost: cost)
        
        let partsString = parts.joined(separator: ",")
        let endpoint = "videos"
        let parameters = [
            "part": partsString,
            "id": id,
            "key": apiKey
        ]
        
        let response: YouTubeAPIResponse<YouTubeVideo> = try await makeRequest(endpoint: endpoint, parameters: parameters)
        return response.items.first
    }
    
    func getVideos(ids: [String], parts: [String] = ["snippet", "statistics", "contentDetails"]) async throws -> [YouTubeVideo] {
        let cost = calculateQuotaCost(for: "videos", parts: parts)
        try await checkQuotaAndRateLimit(cost: cost)
        
        let partsString = parts.joined(separator: ",")
        let idsString = ids.joined(separator: ",")
        let endpoint = "videos"
        let parameters = [
            "part": partsString,
            "id": idsString,
            "key": apiKey
        ]
        
        let response: YouTubeAPIResponse<YouTubeVideo> = try await makeRequest(endpoint: endpoint, parameters: parameters)
        return response.items
    }
    
    func getVideosByChannel(channelId: String, maxResults: Int = 25, pageToken: String? = nil) async throws -> YouTubeSearchResult {
        let cost = 100 // Search operation cost
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet",
            "channelId": channelId,
            "maxResults": String(maxResults),
            "order": "date",
            "type": "video",
            "key": apiKey
        ]
        
        if let pageToken = pageToken {
            parameters["pageToken"] = pageToken
        }
        
        return try await makeRequest(endpoint: "search", parameters: parameters)
    }
    
    func getLiveStreams(channelId: String? = nil, maxResults: Int = 25, pageToken: String? = nil) async throws -> YouTubeSearchResult {
        let cost = 100 // Search operation cost
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet",
            "eventType": "live",
            "type": "video",
            "maxResults": String(maxResults),
            "order": "viewCount",
            "key": apiKey
        ]
        
        if let channelId = channelId {
            parameters["channelId"] = channelId
        }
        
        if let pageToken = pageToken {
            parameters["pageToken"] = pageToken
        }
        
        return try await makeRequest(endpoint: "search", parameters: parameters)
    }
    
    func getUpcomingLiveStreams(channelId: String? = nil, maxResults: Int = 25) async throws -> YouTubeSearchResult {
        let cost = 100 // Search operation cost
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet",
            "eventType": "upcoming",
            "type": "video",
            "maxResults": String(maxResults),
            "order": "date",
            "key": apiKey
        ]
        
        if let channelId = channelId {
            parameters["channelId"] = channelId
        }
        
        return try await makeRequest(endpoint: "search", parameters: parameters)
    }
    
    // MARK: - Channel Methods
    
    func getChannel(id: String, parts: [String] = ["snippet", "statistics", "contentDetails", "brandingSettings"]) async throws -> YouTubeChannel? {
        let cost = calculateQuotaCost(for: "channels", parts: parts)
        try await checkQuotaAndRateLimit(cost: cost)
        
        let partsString = parts.joined(separator: ",")
        let endpoint = "channels"
        let parameters = [
            "part": partsString,
            "id": id,
            "key": apiKey
        ]
        
        let response: YouTubeAPIResponse<YouTubeChannel> = try await makeRequest(endpoint: endpoint, parameters: parameters)
        return response.items.first
    }
    
    func getChannelByUsername(username: String, parts: [String] = ["snippet", "statistics", "contentDetails"]) async throws -> YouTubeChannel? {
        let cost = calculateQuotaCost(for: "channels", parts: parts)
        try await checkQuotaAndRateLimit(cost: cost)
        
        let partsString = parts.joined(separator: ",")
        let endpoint = "channels"
        let parameters = [
            "part": partsString,
            "forUsername": username,
            "key": apiKey
        ]
        
        let response: YouTubeAPIResponse<YouTubeChannel> = try await makeRequest(endpoint: endpoint, parameters: parameters)
        return response.items.first
    }
    
    func getChannelsByIds(ids: [String], parts: [String] = ["snippet", "statistics"]) async throws -> [YouTubeChannel] {
        let cost = calculateQuotaCost(for: "channels", parts: parts)
        try await checkQuotaAndRateLimit(cost: cost)
        
        let partsString = parts.joined(separator: ",")
        let idsString = ids.joined(separator: ",")
        let endpoint = "channels"
        let parameters = [
            "part": partsString,
            "id": idsString,
            "key": apiKey
        ]
        
        let response: YouTubeAPIResponse<YouTubeChannel> = try await makeRequest(endpoint: endpoint, parameters: parameters)
        return response.items
    }
    
    // MARK: - Search Methods
    
    func search(query: String, type: YouTubeSearchType = .video, maxResults: Int = 25, pageToken: String? = nil, filters: SearchFilters = SearchFilters()) async throws -> YouTubeSearchResult {
        let cost = 100 // Search operation cost
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet",
            "q": query,
            "type": type.rawValue,
            "maxResults": String(maxResults),
            "key": apiKey
        ]
        
        if let pageToken = pageToken {
            parameters["pageToken"] = pageToken
        }
        
        // Apply filters
        if let order = filters.order {
            parameters["order"] = order.rawValue
        }
        
        if let duration = filters.duration {
            parameters["videoDuration"] = duration.rawValue
        }
        
        if let definition = filters.definition {
            parameters["videoDefinition"] = definition.rawValue
        }
        
        if let dimension = filters.dimension {
            parameters["videoDimension"] = dimension.rawValue
        }
        
        if let license = filters.license {
            parameters["videoLicense"] = license.rawValue
        }
        
        if let eventType = filters.eventType {
            parameters["eventType"] = eventType.rawValue
        }
        
        if let publishedAfter = filters.publishedAfter {
            parameters["publishedAfter"] = publishedAfter.iso8601String
        }
        
        if let publishedBefore = filters.publishedBefore {
            parameters["publishedBefore"] = publishedBefore.iso8601String
        }
        
        if let regionCode = filters.regionCode {
            parameters["regionCode"] = regionCode
        }
        
        if let relevanceLanguage = filters.relevanceLanguage {
            parameters["relevanceLanguage"] = relevanceLanguage
        }
        
        if let channelId = filters.channelId {
            parameters["channelId"] = channelId
        }
        
        if let categoryId = filters.categoryId {
            parameters["videoCategoryId"] = categoryId
        }
        
        return try await makeRequest(endpoint: "search", parameters: parameters)
    }
    
    func searchChannels(query: String, maxResults: Int = 25, pageToken: String? = nil) async throws -> YouTubeSearchResult {
        return try await search(query: query, type: .channel, maxResults: maxResults, pageToken: pageToken)
    }
    
    func searchPlaylists(query: String, maxResults: Int = 25, pageToken: String? = nil) async throws -> YouTubeSearchResult {
        return try await search(query: query, type: .playlist, maxResults: maxResults, pageToken: pageToken)
    }
    
    // MARK: - Playlist Methods
    
    func getPlaylist(id: String, parts: [String] = ["snippet", "contentDetails", "status"]) async throws -> YouTubePlaylist? {
        let cost = calculateQuotaCost(for: "playlists", parts: parts)
        try await checkQuotaAndRateLimit(cost: cost)
        
        let partsString = parts.joined(separator: ",")
        let endpoint = "playlists"
        let parameters = [
            "part": partsString,
            "id": id,
            "key": apiKey
        ]
        
        let response: YouTubeAPIResponse<YouTubePlaylist> = try await makeRequest(endpoint: endpoint, parameters: parameters)
        return response.items.first
    }
    
    func getPlaylistsByChannel(channelId: String, maxResults: Int = 25, pageToken: String? = nil) async throws -> YouTubeAPIResponse<YouTubePlaylist> {
        let cost = 1 // Base cost for playlists
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet,contentDetails",
            "channelId": channelId,
            "maxResults": String(maxResults),
            "key": apiKey
        ]
        
        if let pageToken = pageToken {
            parameters["pageToken"] = pageToken
        }
        
        return try await makeRequest(endpoint: "playlists", parameters: parameters)
    }
    
    func getPlaylistItems(playlistId: String, maxResults: Int = 50, pageToken: String? = nil) async throws -> YouTubeAPIResponse<YouTubePlaylistItem> {
        let cost = 1 // Base cost for playlist items
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet,contentDetails",
            "playlistId": playlistId,
            "maxResults": String(maxResults),
            "key": apiKey
        ]
        
        if let pageToken = pageToken {
            parameters["pageToken"] = pageToken
        }
        
        return try await makeRequest(endpoint: "playlistItems", parameters: parameters)
    }
    
    // MARK: - Comment Methods
    
    func getVideoComments(videoId: String, maxResults: Int = 20, pageToken: String? = nil, order: CommentOrder = .relevance) async throws -> YouTubeAPIResponse<YouTubeComment> {
        let cost = 1 // Base cost for comments
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet,replies",
            "videoId": videoId,
            "maxResults": String(maxResults),
            "order": order.rawValue,
            "key": apiKey
        ]
        
        if let pageToken = pageToken {
            parameters["pageToken"] = pageToken
        }
        
        return try await makeRequest(endpoint: "commentThreads", parameters: parameters)
    }
    
    func getCommentReplies(commentId: String, maxResults: Int = 20, pageToken: String? = nil) async throws -> YouTubeAPIResponse<YouTubeComment> {
        let cost = 1 // Base cost for comment replies
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet",
            "parentId": commentId,
            "maxResults": String(maxResults),
            "key": apiKey
        ]
        
        if let pageToken = pageToken {
            parameters["pageToken"] = pageToken
        }
        
        return try await makeRequest(endpoint: "comments", parameters: parameters)
    }
    
    // MARK: - Trending and Popular Content
    
    func getTrendingVideos(regionCode: String = "US", categoryId: String? = nil, maxResults: Int = 25) async throws -> YouTubeAPIResponse<YouTubeVideo> {
        let cost = 1 // Base cost for videos
        try await checkQuotaAndRateLimit(cost: cost)
        
        var parameters = [
            "part": "snippet,statistics,contentDetails",
            "chart": "mostPopular",
            "regionCode": regionCode,
            "maxResults": String(maxResults),
            "key": apiKey
        ]
        
        if let categoryId = categoryId {
            parameters["videoCategoryId"] = categoryId
        }
        
        return try await makeRequest(endpoint: "videos", parameters: parameters)
    }
    
    // MARK: - Live Stream Discovery Methods
    
    /// Get featured live streams (high viewer count, trending)
    func getFeaturedLiveStreams(maxResults: Int = 25, regionCode: String = "US") async throws -> YouTubeSearchResult {
        let cost = 100 // Search operation cost
        try await checkQuotaAndRateLimit(cost: cost)
        
        let parameters = [
            "part": "snippet",
            "eventType": "live",
            "type": "video",
            "maxResults": String(maxResults),
            "order": "viewCount",
            "regionCode": regionCode,
            "key": apiKey
        ]
        
        return try await makeRequest(endpoint: "search", parameters: parameters)
    }
    
    /// Get trending live streams (recently started with good engagement)
    func getTrendingLiveStreams(maxResults: Int = 25, regionCode: String = "US") async throws -> YouTubeSearchResult {
        let cost = 100 // Search operation cost
        try await checkQuotaAndRateLimit(cost: cost)
        
        // Get recent live streams and sort by relevance
        let parameters = [
            "part": "snippet",
            "eventType": "live",
            "type": "video",
            "maxResults": String(maxResults),
            "order": "relevance",
            "publishedAfter": getRecentTimestamp(), // Last 6 hours
            "regionCode": regionCode,
            "key": apiKey
        ]
        
        return try await makeRequest(endpoint: "search", parameters: parameters)
    }
    
    /// Search live streams with specific query
    func searchLiveStreams(query: String, maxResults: Int = 25, regionCode: String = "US") async throws -> YouTubeSearchResult {
        let cost = 100 // Search operation cost
        try await checkQuotaAndRateLimit(cost: cost)
        
        let parameters = [
            "part": "snippet",
            "q": query,
            "eventType": "live",
            "type": "video",
            "maxResults": String(maxResults),
            "order": "relevance",
            "regionCode": regionCode,
            "key": apiKey
        ]
        
        return try await makeRequest(endpoint: "search", parameters: parameters)
    }
    
    /// Get live streams by category
    func getLiveStreamsByCategory(categoryId: String, maxResults: Int = 25, regionCode: String = "US") async throws -> YouTubeSearchResult {
        let cost = 100 // Search operation cost
        try await checkQuotaAndRateLimit(cost: cost)
        
        let parameters = [
            "part": "snippet",
            "eventType": "live",
            "type": "video",
            "maxResults": String(maxResults),
            "order": "viewCount",
            "videoCategoryId": categoryId,
            "regionCode": regionCode,
            "key": apiKey
        ]
        
        return try await makeRequest(endpoint: "search", parameters: parameters)
    }
    
    /// Get enhanced video details for live streams (includes real-time data)
    func getEnhancedVideoDetails(videoIds: [String]) async throws -> YouTubeAPIResponse<YouTubeVideo> {
        let cost = calculateQuotaCost(for: "videos", parts: ["snippet", "statistics", "liveStreamingDetails", "contentDetails"])
        try await checkQuotaAndRateLimit(cost: cost)
        
        let idsString = videoIds.joined(separator: ",")
        let parameters = [
            "part": "snippet,statistics,liveStreamingDetails,contentDetails",
            "id": idsString,
            "key": apiKey
        ]
        
        return try await makeRequest(endpoint: "videos", parameters: parameters)
    }
    
    // MARK: - Helper Methods
    
    private func getRecentTimestamp() -> String {
        let sixHoursAgo = Date().addingTimeInterval(-6 * 3600) // 6 hours ago
        return sixHoursAgo.iso8601String
    }
    
    func getVideoCategories(regionCode: String = "US") async throws -> YouTubeAPIResponse<VideoCategory> {
        let cost = 1 // Base cost for categories
        try await checkQuotaAndRateLimit(cost: cost)
        
        let parameters = [
            "part": "snippet",
            "regionCode": regionCode,
            "key": apiKey
        ]
        
        return try await makeRequest(endpoint: "videoCategories", parameters: parameters)
    }
    
    // MARK: - Utility Methods
    
    func getVideoEmbedUrl(videoId: String, autoplay: Bool = false, muted: Bool = false, controls: Bool = true, startTime: Int? = nil) -> String {
        var urlComponents = URLComponents(string: "https://www.youtube.com/embed/\(videoId)")!
        var queryItems: [URLQueryItem] = []
        
        if autoplay {
            queryItems.append(URLQueryItem(name: "autoplay", value: "1"))
        }
        
        if muted {
            queryItems.append(URLQueryItem(name: "mute", value: "1"))
        }
        
        if !controls {
            queryItems.append(URLQueryItem(name: "controls", value: "0"))
        }
        
        if let startTime = startTime {
            queryItems.append(URLQueryItem(name: "start", value: String(startTime)))
        }
        
        // Add parameters for iOS compatibility
        queryItems.append(URLQueryItem(name: "playsinline", value: "1"))
        queryItems.append(URLQueryItem(name: "enablejsapi", value: "1"))
        queryItems.append(URLQueryItem(name: "origin", value: "https://streamyyy.com"))
        
        urlComponents.queryItems = queryItems
        return urlComponents.url?.absoluteString ?? ""
    }
    
    func isVideoLive(_ video: YouTubeVideo) -> Bool {
        return video.snippet.liveBroadcastContent == "live"
    }
    
    func isVideoUpcoming(_ video: YouTubeVideo) -> Bool {
        return video.snippet.liveBroadcastContent == "upcoming"
    }
    
    func parseDuration(_ duration: String) -> TimeInterval {
        // Parse ISO 8601 duration (PT4M13S -> 253 seconds)
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: duration, range: NSRange(duration.startIndex..., in: duration))
        
        guard let match = matches.first else { return 0 }
        
        var totalSeconds = 0
        
        // Hours
        if let hoursRange = Range(match.range(at: 1), in: duration) {
            totalSeconds += Int(duration[hoursRange])! * 3600
        }
        
        // Minutes
        if let minutesRange = Range(match.range(at: 2), in: duration) {
            totalSeconds += Int(duration[minutesRange])! * 60
        }
        
        // Seconds
        if let secondsRange = Range(match.range(at: 3), in: duration) {
            totalSeconds += Int(duration[secondsRange])!
        }
        
        return TimeInterval(totalSeconds)
    }
    
    // MARK: - Quota and Rate Limiting
    
    private func checkQuotaAndRateLimit(cost: Int) async throws {
        resetQuotaIfNeeded()
        
        // Check quota
        if quotaUsed + cost > maxQuotaPerDay {
            quotaStatus = .exceeded
            throw YouTubeAPIError.quotaExceeded
        }
        
        // Rate limiting
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minimumRequestInterval {
            let delay = minimumRequestInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        lastRequestTime = Date()
        quotaUsed += cost
        
        // Update quota status
        let quotaPercentage = Double(quotaUsed) / Double(maxQuotaPerDay)
        if quotaPercentage > 0.9 {
            quotaStatus = .critical
        } else if quotaPercentage > 0.7 {
            quotaStatus = .warning
        } else {
            quotaStatus = .normal
        }
    }
    
    private func calculateQuotaCost(for endpoint: String, parts: [String]) -> Int {
        let baseCost = 1
        let partCosts = parts.reduce(0) { total, part in
            switch part {
            case "contentDetails", "statistics", "status": return total + 2
            case "snippet": return total + 2
            case "topicDetails": return total + 2
            case "recordingDetails": return total + 2
            case "fileDetails": return total + 1
            case "processingDetails": return total + 1
            case "suggestions": return total + 1
            case "liveStreamingDetails": return total + 2
            case "localizations": return total + 2
            case "player": return total + 0
            default: return total + 1
            }
        }
        return baseCost + partCosts
    }
    
    // MARK: - Cache Management
    
    private func getCachedData(for key: String) -> Data? {
        guard let timestamp = cacheTimestamps[key],
              Date().timeIntervalSince(timestamp) < cacheExpiration else {
            cache.removeObject(forKey: key as NSString)
            cacheTimestamps.removeValue(forKey: key)
            return nil
        }
        return cache.object(forKey: key as NSString) as Data?
    }
    
    private func setCachedData(_ data: Data, for key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
        cacheTimestamps[key] = Date()
    }
    
    private func generateCacheKey(endpoint: String, parameters: [String: String]) -> String {
        let sortedParams = parameters.sorted { $0.key < $1.key }
        let paramString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return "\(endpoint)?\(paramString)"
    }
    
    // MARK: - Network Request
    
    private func makeRequest<T: Codable>(endpoint: String, parameters: [String: String]) async throws -> T {
        isLoading = true
        defer { isLoading = false }
        
        let cacheKey = generateCacheKey(endpoint: endpoint, parameters: parameters)
        
        // Check cache first
        if let cachedData = getCachedData(for: cacheKey) {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: cachedData)
        }
        
        // Build URL
        var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)")!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents.url else {
            throw YouTubeAPIError.invalidURL
        }
        
        // Make request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("StreamyyyApp/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw YouTubeAPIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                // Cache successful response
                setCachedData(data, for: cacheKey)
                
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
                
            case 400:
                throw YouTubeAPIError.badRequest
            case 401:
                throw YouTubeAPIError.unauthorized
            case 403:
                // Check if it's a quota error
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let errors = error["errors"] as? [[String: Any]],
                   let firstError = errors.first,
                   let reason = firstError["reason"] as? String,
                   reason == "quotaExceeded" {
                    throw YouTubeAPIError.quotaExceeded
                }
                throw YouTubeAPIError.forbidden
            case 404:
                throw YouTubeAPIError.notFound
            case 429:
                throw YouTubeAPIError.rateLimited
            case 500...599:
                throw YouTubeAPIError.serverError
            default:
                throw YouTubeAPIError.unknown(httpResponse.statusCode)
            }
        } catch {
            if error is YouTubeAPIError {
                lastError = error as? YouTubeAPIError
                throw error
            } else {
                let apiError = YouTubeAPIError.networkError(error)
                lastError = apiError
                throw apiError
            }
        }
    }
    
    // MARK: - Public Properties
    
    var remainingQuota: Int {
        return max(0, maxQuotaPerDay - quotaUsed)
    }
    
    var quotaPercentageUsed: Double {
        return Double(quotaUsed) / Double(maxQuotaPerDay)
    }
    
    var timeUntilQuotaReset: TimeInterval {
        return quotaResetTime.timeIntervalSince(Date())
    }
}

// MARK: - Supporting Types

enum YouTubeSearchType: String, CaseIterable {
    case video = "video"
    case channel = "channel"
    case playlist = "playlist"
}

enum SearchOrder: String, CaseIterable {
    case relevance = "relevance"
    case date = "date"
    case rating = "rating"
    case viewCount = "viewCount"
    case title = "title"
}

enum VideoDuration: String, CaseIterable {
    case short = "short"      // < 4 minutes
    case medium = "medium"    // 4-20 minutes
    case long = "long"        // > 20 minutes
}

enum VideoDefinition: String, CaseIterable {
    case high = "high"        // HD
    case standard = "standard" // SD
}

enum VideoDimension: String, CaseIterable {
    case dimension2d = "2d"
    case dimension3d = "3d"
}

enum VideoLicense: String, CaseIterable {
    case youtube = "youtube"
    case creativeCommon = "creativeCommon"
}

enum EventType: String, CaseIterable {
    case completed = "completed"
    case live = "live"
    case upcoming = "upcoming"
}

enum CommentOrder: String, CaseIterable {
    case relevance = "relevance"
    case time = "time"
}

enum QuotaStatus {
    case normal
    case warning
    case critical
    case exceeded
}

struct SearchFilters {
    var order: SearchOrder?
    var duration: VideoDuration?
    var definition: VideoDefinition?
    var dimension: VideoDimension?
    var license: VideoLicense?
    var eventType: EventType?
    var publishedAfter: Date?
    var publishedBefore: Date?
    var regionCode: String?
    var relevanceLanguage: String?
    var channelId: String?
    var categoryId: String?
    
    init() {}
}

struct VideoCategory: Codable, Identifiable {
    let id: String
    let snippet: CategorySnippet
    
    struct CategorySnippet: Codable {
        let channelId: String
        let title: String
        let assignable: Bool
    }
}

// MARK: - Error Handling

enum YouTubeAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case quotaExceeded
    case serverError
    case networkError(Error)
    case unknown(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest:
            return "Bad request"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Forbidden access"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limit exceeded"
        case .quotaExceeded:
            return "API quota exceeded"
        case .serverError:
            return "Server error"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let code):
            return "Unknown error (code: \(code))"
        }
    }
}

// MARK: - Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

extension YouTubeVideo {
    var isLive: Bool {
        return snippet.liveBroadcastContent == "live"
    }
    
    var isUpcoming: Bool {
        return snippet.liveBroadcastContent == "upcoming"
    }
    
    var viewCountInt: Int {
        return Int(statistics?.viewCount ?? "0") ?? 0
    }
    
    var likeCountInt: Int {
        return Int(statistics?.likeCount ?? "0") ?? 0
    }
    
    var commentCountInt: Int {
        return Int(statistics?.commentCount ?? "0") ?? 0
    }
    
    var durationSeconds: TimeInterval {
        guard let duration = contentDetails?.duration else { return 0 }
        return YouTubeService().parseDuration(duration)
    }
    
    var bestThumbnailUrl: String {
        return snippet.thumbnails.maxres?.url ??
               snippet.thumbnails.high?.url ??
               snippet.thumbnails.medium?.url ??
               snippet.thumbnails.default?.url ?? ""
    }
}

extension YouTubeChannel {
    var subscriberCountInt: Int {
        return Int(statistics?.subscriberCount ?? "0") ?? 0
    }
    
    var videoCountInt: Int {
        return Int(statistics?.videoCount ?? "0") ?? 0
    }
    
    var viewCountInt: Int {
        return Int(statistics?.viewCount ?? "0") ?? 0
    }
    
    var bestThumbnailUrl: String {
        return snippet.thumbnails.high?.url ??
               snippet.thumbnails.medium?.url ??
               snippet.thumbnails.default?.url ?? ""
    }
}

extension YouTubeSearchResult.SearchResultItem {
    var videoId: String? {
        return id.videoId
    }
    
    var channelId: String? {
        return id.channelId
    }
    
    var playlistId: String? {
        return id.playlistId
    }
    
    var isLive: Bool {
        return snippet.liveBroadcastContent == "live"
    }
    
    var isUpcoming: Bool {
        return snippet.liveBroadcastContent == "upcoming"
    }
    
    var bestThumbnailUrl: String {
        return snippet.thumbnails.high?.url ??
               snippet.thumbnails.medium?.url ??
               snippet.thumbnails.default?.url ?? ""
    }
}