//
//  RumbleService.swift
//  StreamyyyApp
//
//  Rumble platform integration for video and live stream embedding
//  Created by Claude Code on 2025-07-10
//

import Foundation
import Combine

// MARK: - Rumble Models

/// Rumble video/stream information
public struct RumbleVideo: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String?
    public let duration: TimeInterval?
    public let thumbnailURL: String?
    public let embedURL: String
    public let viewCount: Int?
    public let publishedAt: Date?
    public let isLive: Bool
    public let channelName: String?
    public let channelURL: String?
    
    public init(
        id: String,
        title: String,
        description: String? = nil,
        duration: TimeInterval? = nil,
        thumbnailURL: String? = nil,
        embedURL: String,
        viewCount: Int? = nil,
        publishedAt: Date? = nil,
        isLive: Bool = false,
        channelName: String? = nil,
        channelURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.embedURL = embedURL
        self.viewCount = viewCount
        self.publishedAt = publishedAt
        self.isLive = isLive
        self.channelName = channelName
        self.channelURL = channelURL
    }
}

/// Rumble channel information
public struct RumbleChannel: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let thumbnailURL: String?
    public let subscriberCount: Int?
    public let videoCount: Int?
    public let isLive: Bool
    public let channelURL: String
    
    public init(
        id: String,
        name: String,
        description: String? = nil,
        thumbnailURL: String? = nil,
        subscriberCount: Int? = nil,
        videoCount: Int? = nil,
        isLive: Bool = false,
        channelURL: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.subscriberCount = subscriberCount
        self.videoCount = videoCount
        self.isLive = isLive
        self.channelURL = channelURL
    }
}

// MARK: - Rumble Service Errors

public enum RumbleServiceError: Error, LocalizedError {
    case invalidURL
    case invalidVideoID
    case invalidChannelID
    case networkError(Error)
    case parseError
    case embedNotSupported
    case videoNotFound
    case channelNotFound
    case rateLimitExceeded
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Rumble URL"
        case .invalidVideoID:
            return "Invalid video ID"
        case .invalidChannelID:
            return "Invalid channel ID"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError:
            return "Failed to parse Rumble response"
        case .embedNotSupported:
            return "Embedding not supported for this content"
        case .videoNotFound:
            return "Video not found"
        case .channelNotFound:
            return "Channel not found"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

// MARK: - Rumble Service

/// Service for interacting with Rumble platform
@MainActor
public class RumbleService: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL = "https://rumble.com"
    private let embedURL = "https://rumble.com/embed"
    private let apiURL = "https://rumble.com/api"
    
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    public struct Configuration {
        public let userAgent: String
        public let timeout: TimeInterval
        public let maxRetries: Int
        
        public init(
            userAgent: String = "StreamyyyApp/1.0.0 (iOS) RumblePlayer/1.0",
            timeout: TimeInterval = 30.0,
            maxRetries: Int = 3
        ) {
            self.userAgent = userAgent
            self.timeout = timeout
            self.maxRetries = maxRetries
        }
    }
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.httpAdditionalHeaders = [
            "User-Agent": configuration.userAgent,
            "Accept": "application/json, text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8"
        ]
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - URL Validation and Parsing
    
    /// Validates if a URL is a valid Rumble URL
    public func isValidRumbleURL(_ url: String) -> Bool {
        guard let url = URL(string: url),
              let host = url.host?.lowercased() else {
            return false
        }
        
        return host.contains("rumble.com")
    }
    
    /// Extracts video/channel identifier from Rumble URL
    public func extractIdentifier(from url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        
        let pathComponents = url.pathComponents
        
        // Handle different Rumble URL patterns:
        // rumble.com/v{videoId}-{title}
        // rumble.com/c/{channelName}
        // rumble.com/{channelName}
        
        if let lastComponent = pathComponents.last {
            // Video URL pattern: v{videoId}-{title}
            if lastComponent.hasPrefix("v") && lastComponent.contains("-") {
                let parts = lastComponent.components(separatedBy: "-")
                if let firstPart = parts.first {
                    return String(firstPart.dropFirst()) // Remove 'v' prefix
                }
            }
            
            // Channel URL pattern: c/{channelName} or direct /{channelName}
            if pathComponents.count >= 2 {
                let secondLast = pathComponents[pathComponents.count - 2]
                if secondLast == "c" {
                    return lastComponent // Channel name
                }
            }
            
            // Direct channel name (no 'c/' prefix)
            if !lastComponent.isEmpty && lastComponent != "/" {
                return lastComponent
            }
        }
        
        return nil
    }
    
    /// Determines content type from URL
    public func getContentType(from url: String) -> ContentType {
        guard let identifier = extractIdentifier(from: url) else {
            return .unknown
        }
        
        // If identifier starts with numbers, it's likely a video ID
        if identifier.first?.isNumber == true {
            return .video
        }
        
        // Otherwise assume it's a channel
        return .channel
    }
    
    public enum ContentType {
        case video
        case channel
        case unknown
    }
    
    // MARK: - Embed URL Generation
    
    /// Generates embed URL for Rumble content
    public func generateEmbedURL(for identifier: String, options: EmbedOptions = EmbedOptions()) -> String {
        var params: [String] = []
        
        if options.autoplay {
            params.append("autoplay=1")
        }
        
        if options.muted {
            params.append("muted=1")
        }
        
        if !options.showControls {
            params.append("controls=0")
        }
        
        if let startTime = options.startTime {
            params.append("t=\(Int(startTime))")
        }
        
        let paramString = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return "\(embedURL)/\(identifier)\(paramString)"
    }
    
    // MARK: - Basic Content Information
    
    /// Attempts to get basic video information from URL
    public func getVideoInfo(from url: String) async throws -> RumbleVideo {
        guard isValidRumbleURL(url),
              let identifier = extractIdentifier(from: url) else {
            throw RumbleServiceError.invalidURL
        }
        
        // Since Rumble doesn't have a public API, we'll create a basic video object
        // with the information we can extract from the URL
        let embedURL = generateEmbedURL(for: identifier)
        
        return RumbleVideo(
            id: identifier,
            title: "Rumble Video",
            description: nil,
            duration: nil,
            thumbnailURL: nil,
            embedURL: embedURL,
            viewCount: nil,
            publishedAt: nil,
            isLive: false,
            channelName: nil,
            channelURL: url
        )
    }
    
    /// Attempts to get basic channel information from URL
    public func getChannelInfo(from url: String) async throws -> RumbleChannel {
        guard isValidRumbleURL(url),
              let identifier = extractIdentifier(from: url) else {
            throw RumbleServiceError.invalidURL
        }
        
        let channelURL = "\(baseURL)/c/\(identifier)"
        
        return RumbleChannel(
            id: identifier,
            name: identifier.capitalized,
            description: nil,
            thumbnailURL: nil,
            subscriberCount: nil,
            videoCount: nil,
            isLive: false,
            channelURL: channelURL
        )
    }
    
    // MARK: - Stream Detection
    
    /// Checks if a Rumble URL is a live stream
    public func isLiveStream(_ url: String) async -> Bool {
        // Without API access, we can't reliably detect live streams
        // This would require scraping the page or using unofficial methods
        return false
    }
    
    /// Gets live stream status for a channel
    public func getLiveStreamStatus(for channelId: String) async -> Bool {
        // Without API access, we can't reliably detect live streams
        return false
    }
    
    // MARK: - Discovery Methods
    
    /// Get featured streams (mock implementation since no public API)
    public func getFeaturedStreams(limit: Int = 15) async throws -> [DiscoveredStream] {
        return generateMockRumbleStreams(count: limit, type: "featured")
    }
    
    /// Get trending streams (mock implementation since no public API)
    public func getTrendingStreams(limit: Int = 20) async throws -> [DiscoveredStream] {
        return generateMockRumbleStreams(count: limit, type: "trending")
    }
    
    /// Search for streams (mock implementation since no public API)
    public func searchStreams(query: String, filters: RumbleSearchFilters, limit: Int = 25) async throws -> [DiscoveredStream] {
        return generateMockRumbleStreams(count: limit, type: "search", query: query)
    }
    
    /// Get streams by category (mock implementation since no public API)
    public func getStreamsByCategory(category: String, limit: Int = 10) async throws -> [DiscoveredStream] {
        return generateMockRumbleStreams(count: limit, type: "category", category: category)
    }
    
    /// Get categories (mock implementation since no public API)
    public func getCategories() async throws -> [StreamCategory] {
        return [
            StreamCategory(id: "news", name: "News", platform: .rumble, viewerCount: 25000, streamCount: 150),
            StreamCategory(id: "politics", name: "Politics", platform: .rumble, viewerCount: 20000, streamCount: 100),
            StreamCategory(id: "education", name: "Education", platform: .rumble, viewerCount: 15000, streamCount: 80),
            StreamCategory(id: "entertainment", name: "Entertainment", platform: .rumble, viewerCount: 18000, streamCount: 120),
            StreamCategory(id: "technology", name: "Technology", platform: .rumble, viewerCount: 12000, streamCount: 90),
            StreamCategory(id: "finance", name: "Finance", platform: .rumble, viewerCount: 10000, streamCount: 70),
            StreamCategory(id: "health", name: "Health", platform: .rumble, viewerCount: 8000, streamCount: 60),
            StreamCategory(id: "lifestyle", name: "Lifestyle", platform: .rumble, viewerCount: 7000, streamCount: 50)
        ]
    }
    
    /// Generate mock Rumble streams since no public API is available
    private func generateMockRumbleStreams(count: Int, type: String, query: String? = nil, category: String? = nil) -> [DiscoveredStream] {
        let categories = ["News", "Politics", "Education", "Entertainment", "Technology", "Finance", "Health", "Lifestyle"]
        let newsChannels = ["NewsMax", "RSBN", "InfoWars", "TimCast", "Stew Peters", "Red Elephant", "Bannons War Room", "X22 Report"]
        let contentTypes = ["LIVE:", "BREAKING:", "EXCLUSIVE:", "ANALYSIS:", "REPORT:", "UPDATE:"]
        
        return (0..<count).map { index in
            let channelName = newsChannels.randomElement() ?? "RumbleChannel\(index + 1)"
            let contentType = contentTypes.randomElement() ?? ""
            let selectedCategory = category ?? categories.randomElement() ?? "News"
            
            var title = "\(contentType) \(selectedCategory) Stream \(index + 1)"
            if let query = query {
                title = "\(contentType) \(query) - \(selectedCategory) Discussion"
            }
            
            let videoId = "rumble_\(type)_\(index)_\(Int.random(in: 1000...9999))"
            let viewerCount = Int.random(in: 50...5000)
            let isLive = type == "trending" ? Bool.random() : (type == "featured" ? true : Bool.random())
            
            return DiscoveredStream(
                id: videoId,
                title: title,
                channelName: channelName,
                platform: .rumble,
                viewerCount: viewerCount,
                isLive: isLive,
                thumbnailURL: "https://picsum.photos/320/180?random=\(index + 100)",
                streamURL: "https://rumble.com/v\(videoId)",
                category: selectedCategory,
                language: "en",
                startedAt: Date().addingTimeInterval(-Double.random(in: 0...7200)) // Started within last 2 hours
            )
        }
    }
    
    // MARK: - Utility Methods
    
    /// Creates a properly formatted Rumble URL from identifier
    public func createRumbleURL(from identifier: String, type: ContentType = .channel) -> String {
        switch type {
        case .video:
            return "\(baseURL)/v\(identifier)"
        case .channel:
            return "\(baseURL)/c/\(identifier)"
        case .unknown:
            return "\(baseURL)/\(identifier)"
        }
    }
    
    /// Validates video ID format
    public func isValidVideoID(_ id: String) -> Bool {
        // Rumble video IDs are typically alphanumeric
        return !id.isEmpty && id.allSatisfy { $0.isAlphanumeric }
    }
    
    /// Validates channel ID/name format
    public func isValidChannelID(_ id: String) -> Bool {
        // Rumble channel names can contain letters, numbers, underscores, and hyphens
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return !id.isEmpty && id.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) -> RumbleServiceError {
        if let rumbleError = error as? RumbleServiceError {
            return rumbleError
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(error)
            case .timedOut:
                return .networkError(error)
            case .badURL:
                return .invalidURL
            default:
                return .networkError(error)
            }
        }
        
        return .networkError(error)
    }
}

// MARK: - Search Filters

/// Search filters for Rumble content
public struct RumbleSearchFilters {
    public var liveOnly: Bool
    public var categories: [String]?
    public var dateRange: DateRange?
    public var duration: DurationFilter?
    public var sortBy: SortOrder
    
    public init(
        liveOnly: Bool = false,
        categories: [String]? = nil,
        dateRange: DateRange? = nil,
        duration: DurationFilter? = nil,
        sortBy: SortOrder = .relevance
    ) {
        self.liveOnly = liveOnly
        self.categories = categories
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
    
    public enum DurationFilter {
        case short      // < 4 minutes
        case medium     // 4-20 minutes
        case long       // > 20 minutes
    }
    
    public enum SortOrder {
        case relevance
        case date
        case viewCount
        case rating
    }
}

// MARK: - Embed Options

/// Options for Rumble embed configuration
public struct RumbleEmbedOptions {
    public var autoplay: Bool = false
    public var muted: Bool = true
    public var showControls: Bool = true
    public var startTime: TimeInterval?
    public var loop: Bool = false
    
    public init(
        autoplay: Bool = false,
        muted: Bool = true,
        showControls: Bool = true,
        startTime: TimeInterval? = nil,
        loop: Bool = false
    ) {
        self.autoplay = autoplay
        self.muted = muted
        self.showControls = showControls
        self.startTime = startTime
        self.loop = loop
    }
}

// MARK: - Extensions

extension Character {
    var isAlphanumeric: Bool {
        return isLetter || isNumber
    }
}

// MARK: - Preview Support

#if DEBUG
extension RumbleService {
    /// Creates a mock service for previews and testing
    public static var mock: RumbleService {
        return RumbleService()
    }
    
    /// Sample video for testing
    public static var sampleVideo: RumbleVideo {
        return RumbleVideo(
            id: "sample123",
            title: "Sample Rumble Video",
            description: "This is a sample video for testing purposes",
            duration: 300,
            thumbnailURL: "https://example.com/thumbnail.jpg",
            embedURL: "https://rumble.com/embed/sample123",
            viewCount: 1000,
            publishedAt: Date(),
            isLive: false,
            channelName: "SampleChannel",
            channelURL: "https://rumble.com/c/SampleChannel"
        )
    }
    
    /// Sample channel for testing
    public static var sampleChannel: RumbleChannel {
        return RumbleChannel(
            id: "samplechannel",
            name: "Sample Channel",
            description: "This is a sample channel for testing purposes",
            thumbnailURL: "https://example.com/channel.jpg",
            subscriberCount: 5000,
            videoCount: 50,
            isLive: true,
            channelURL: "https://rumble.com/c/samplechannel"
        )
    }
}
#endif