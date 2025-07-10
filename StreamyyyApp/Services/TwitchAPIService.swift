//
//  TwitchAPIService.swift
//  StreamyyyApp
//
//  Real-time Twitch API integration for fetching live top streamers
//

import Foundation
import Combine

// MARK: - Twitch API Models
struct TwitchStreamResponse: Codable {
    let data: [TwitchStreamData]
    let pagination: TwitchPagination?
}

struct TwitchStreamData: Codable {
    let id: String
    let userId: String
    let userLogin: String
    let userName: String
    let gameId: String?
    let gameName: String?
    let type: String
    let title: String
    let viewerCount: Int
    let startedAt: String
    let language: String
    let thumbnailUrl: String
    let tags: [String]?
    let isMature: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userLogin = "user_login"
        case userName = "user_name"
        case gameId = "game_id"
        case gameName = "game_name"
        case type
        case title
        case viewerCount = "viewer_count"
        case startedAt = "started_at"
        case language
        case thumbnailUrl = "thumbnail_url"
        case tags
        case isMature = "is_mature"
    }
}

struct TwitchPagination: Codable {
    let cursor: String?
}

struct TwitchTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct TwitchGameResponse: Codable {
    let data: [TwitchGameData]
}

struct TwitchGameData: Codable {
    let id: String
    let name: String
    let boxArtUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case boxArtUrl = "box_art_url"
    }
}

// MARK: - Rate Limiting
class TwitchRateLimitHandler: ObservableObject {
    private var remaining: Int = 800
    private var resetTime: Date = Date()
    private var limit: Int = 800
    
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 0.1 // 100ms between requests
    
    func canMakeRequest() -> Bool {
        let now = Date()
        
        // Check if we're within rate limit
        if now > resetTime {
            // Reset window has passed, refresh limits
            remaining = limit
            resetTime = now.addingTimeInterval(60) // 1 minute window
        }
        
        // Check if we have remaining requests
        return remaining > 0 && now.timeIntervalSince(lastRequestTime) >= minimumRequestInterval
    }
    
    func recordRequest(headers: [String: String]) {
        lastRequestTime = Date()
        
        if let remainingStr = headers["ratelimit-remaining"],
           let remaining = Int(remainingStr) {
            self.remaining = remaining
        }
        
        if let resetStr = headers["ratelimit-reset"],
           let resetTimestamp = TimeInterval(resetStr) {
            self.resetTime = Date(timeIntervalSince1970: resetTimestamp)
        }
        
        if let limitStr = headers["ratelimit-limit"],
           let limit = Int(limitStr) {
            self.limit = limit
        }
    }
    
    func waitTimeUntilNextRequest() -> TimeInterval {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < minimumRequestInterval {
            return minimumRequestInterval - timeSinceLastRequest
        }
        
        if remaining <= 0 && now < resetTime {
            return resetTime.timeIntervalSince(now)
        }
        
        return 0
    }
}

// MARK: - Token Manager
class TwitchTokenManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasError = false
    @Published var errorMessage: String?
    
    private var accessToken: String?
    private var tokenExpiryDate: Date?
    private let clientId: String
    private let clientSecret: String
    
    private let tokenEndpoint = "https://id.twitch.tv/oauth2/token"
    
    init() {
        // Use hardcoded values from Config.swift
        self.clientId = "840q0uzqa2ny9oob3yp8ako6dqs31g"
        self.clientSecret = "6359is1cljkasakhaobken9r0shohc"
    }
    
    func getValidToken() async throws -> String {
        if let token = accessToken,
           let expiryDate = tokenExpiryDate,
           Date() < expiryDate.addingTimeInterval(-300) { // Refresh 5 minutes early
            return token
        }
        
        return try await refreshToken()
    }
    
    private func refreshToken() async throws -> String {
        hasError = false
        errorMessage = nil
        
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "client_credentials"
        ]
        
        let bodyData = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.httpBody = bodyData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TwitchAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw TwitchAPIError.authenticationFailed(httpResponse.statusCode)
            }
            
            let tokenResponse = try JSONDecoder().decode(TwitchTokenResponse.self, from: data)
            
            await MainActor.run {
                self.accessToken = tokenResponse.accessToken
                self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
                self.isAuthenticated = true
            }
            
            print("✅ Twitch token refreshed successfully. Expires in \(tokenResponse.expiresIn) seconds")
            return tokenResponse.accessToken
            
        } catch {
            await MainActor.run {
                self.hasError = true
                self.errorMessage = error.localizedDescription
                self.isAuthenticated = false
            }
            print("❌ Twitch token refresh failed: \(error)")
            throw error
        }
    }
}

// MARK: - API Errors
enum TwitchAPIError: Error, LocalizedError {
    case invalidResponse
    case authenticationFailed(Int)
    case rateLimitExceeded
    case networkError(Error)
    case decodingError(Error)
    case invalidURL
    case noToken
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Twitch API"
        case .authenticationFailed(let status):
            return "Twitch authentication failed with status \(status)"
        case .rateLimitExceeded:
            return "Twitch API rate limit exceeded"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid API URL"
        case .noToken:
            return "No valid authentication token"
        }
    }
}

// MARK: - Main Twitch API Service
@MainActor
class TwitchAPIService: ObservableObject {
    static let shared = TwitchAPIService()
    
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    
    private let tokenManager = TwitchTokenManager()
    private let rateLimitHandler = TwitchRateLimitHandler()
    private let baseURL = "https://api.twitch.tv/helix"
    private let clientId: String
    
    // Cache for API responses
    private var streamCache: [TwitchStreamData] = []
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 120 // 2 minutes
    
    private init() {
        // Use hardcoded values from Config.swift
        self.clientId = "840q0uzqa2ny9oob3yp8ako6dqs31g"
    }
    
    // MARK: - Public API Methods
    
    /// Fetches top live streams with optional filtering
    func getTopStreams(
        limit: Int = 20,
        gameId: String? = nil,
        language: String? = nil
    ) async throws -> [TwitchStreamData] {
        
        // Check cache first
        if let cachedStreams = getCachedStreams(limit: limit, gameId: gameId, language: language) {
            print("📦 Returning cached Twitch streams (\(cachedStreams.count) streams)")
            return cachedStreams
        }
        
        isLoading = true
        hasError = false
        errorMessage = nil
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            // Wait for rate limit if needed
            let waitTime = rateLimitHandler.waitTimeUntilNextRequest()
            if waitTime > 0 {
                print("⏳ Rate limit wait: \(waitTime)s")
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
            
            guard rateLimitHandler.canMakeRequest() else {
                throw TwitchAPIError.rateLimitExceeded
            }
            
            var urlComponents = URLComponents(string: "\(baseURL)/streams")!
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "first", value: String(min(limit, 100)))
            ]
            
            if let gameId = gameId {
                queryItems.append(URLQueryItem(name: "game_id", value: gameId))
            }
            
            if let language = language {
                queryItems.append(URLQueryItem(name: "language", value: language))
            }
            
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else {
                throw TwitchAPIError.invalidURL
            }
            
            let token = try await tokenManager.getValidToken()
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(clientId, forHTTPHeaderField: "Client-Id")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TwitchAPIError.invalidResponse
            }
            
            // Update rate limit info
            let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
            rateLimitHandler.recordRequest(headers: headers)
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    throw TwitchAPIError.rateLimitExceeded
                }
                throw TwitchAPIError.authenticationFailed(httpResponse.statusCode)
            }
            
            let streamResponse = try JSONDecoder().decode(TwitchStreamResponse.self, from: data)
            
            // Update cache
            streamCache = streamResponse.data
            cacheTimestamp = Date()
            lastUpdated = Date()
            
            print("✅ Fetched \(streamResponse.data.count) live streams from Twitch API")
            return streamResponse.data
            
        } catch {
            hasError = true
            errorMessage = error.localizedDescription
            print("❌ Twitch API error: \(error)")
            throw error
        }
    }
    
    /// Fetches streams for specific games/categories
    func getStreamsForCategory(_ category: String, limit: Int = 20) async throws -> [TwitchStreamData] {
        switch category.lowercased() {
        case "just chatting":
            return try await getTopStreams(limit: limit, gameId: "509658") // Just Chatting game ID
        case "gaming", "games":
            // Get top games first, then streams for those games
            return try await getTopStreams(limit: limit)
        case "music":
            return try await getTopStreams(limit: limit, gameId: "26936") // Music & Performing Arts
        default:
            return try await getTopStreams(limit: limit)
        }
    }
    
    /// Searches for streams by query
    func searchStreams(query: String, limit: Int = 20) async throws -> [TwitchStreamData] {
        let allStreams = try await getTopStreams(limit: 100) // Get more streams to search through
        
        let filteredStreams = allStreams.filter { stream in
            stream.title.localizedCaseInsensitiveContains(query) ||
            stream.userName.localizedCaseInsensitiveContains(query) ||
            stream.gameName?.localizedCaseInsensitiveContains(query) == true
        }
        
        return Array(filteredStreams.prefix(limit))
    }
    
    // MARK: - Helper Methods
    
    private func getCachedStreams(limit: Int, gameId: String?, language: String?) -> [TwitchStreamData]? {
        guard let cacheTimestamp = cacheTimestamp,
              Date().timeIntervalSince(cacheTimestamp) < cacheValidDuration,
              !streamCache.isEmpty else {
            return nil
        }
        
        var filteredStreams = streamCache
        
        // Apply filters to cached data
        if let gameId = gameId {
            filteredStreams = filteredStreams.filter { $0.gameId == gameId }
        }
        
        if let language = language {
            filteredStreams = filteredStreams.filter { $0.language == language }
        }
        
        return Array(filteredStreams.prefix(limit))
    }
    
    /// Converts TwitchStreamData to StreamModel for UI compatibility
    func convertToStreamModel(_ twitchStream: TwitchStreamData) -> StreamModel {
        let thumbnailURL = getThumbnailURL(from: twitchStream.thumbnailUrl, width: 440, height: 248)
        
        return StreamModel(
            id: twitchStream.id,
            url: "https://twitch.tv/\(twitchStream.userLogin)",
            type: .twitch,
            title: twitchStream.title,
            isLive: twitchStream.type == "live",
            viewerCount: twitchStream.viewerCount,
            isMuted: false,
            isFavorite: false,
            thumbnailURL: thumbnailURL,
            channelName: twitchStream.userName,
            gameName: twitchStream.gameName
        )
    }
    
    /// Forces a refresh of cached data
    func refreshData() {
        cacheTimestamp = nil
        streamCache.removeAll()
    }
    
    /// Gets authentication status
    var isAuthenticated: Bool {
        tokenManager.isAuthenticated
    }
}

// MARK: - Convenience Extensions
extension TwitchAPIService {
    /// Gets formatted thumbnail URL with specified dimensions
    func getThumbnailURL(from template: String, width: Int = 320, height: Int = 180) -> String {
        return template
            .replacingOccurrences(of: "{width}", with: String(width))
            .replacingOccurrences(of: "{height}", with: String(height))
    }
    
    /// Formats stream duration from started_at timestamp
    func getStreamDuration(startedAt: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let startDate = formatter.date(from: startedAt) else {
            return "Unknown"
        }
        
        let duration = Date().timeIntervalSince(startDate)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}