import Foundation
import Combine
import Network

// MARK: - Twitch API Models

public struct TwitchUser: Codable, Identifiable {
    public let id: String
    public let login: String
    public let displayName: String
    public let type: String
    public let broadcasterType: String
    public let description: String
    public let profileImageURL: String
    public let offlineImageURL: String
    public let viewCount: Int
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, login, type, description
        case displayName = "display_name"
        case broadcasterType = "broadcaster_type"
        case profileImageURL = "profile_image_url"
        case offlineImageURL = "offline_image_url"
        case viewCount = "view_count"
        case createdAt = "created_at"
    }
}

public struct TwitchStream: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let gameId: String
    public let gameName: String
    public let type: String
    public let title: String
    public let viewerCount: Int
    public let startedAt: String
    public let language: String
    public let thumbnailURL: String
    public let tagIds: [String]?
    public let tags: [String]?
    public let isMature: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, language, tags
        case userId = "user_id"
        case userLogin = "user_login"
        case userName = "user_name"
        case gameId = "game_id"
        case gameName = "game_name"
        case viewerCount = "viewer_count"
        case startedAt = "started_at"
        case thumbnailURL = "thumbnail_url"
        case tagIds = "tag_ids"
        case isMature = "is_mature"
    }
}

public struct TwitchGame: Codable, Identifiable {
    public let id: String
    public let name: String
    public let boxArtURL: String
    public let igdbId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case boxArtURL = "box_art_url"
        case igdbId = "igdb_id"
    }
}

public struct TwitchChannel: Codable, Identifiable {
    public let id: String
    public let broadcasterLanguage: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let gameName: String
    public let gameId: String
    public let title: String
    public let delay: Int
    public let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, title, delay, tags
        case broadcasterLanguage = "broadcaster_language"
        case broadcasterLogin = "broadcaster_login"
        case broadcasterName = "broadcaster_name"
        case gameName = "game_name"
        case gameId = "game_id"
    }
}

public struct TwitchFollower: Codable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let followedAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userLogin = "user_login"
        case userName = "user_name"
        case followedAt = "followed_at"
    }
}

public struct TwitchClip: Codable, Identifiable {
    public let id: String
    public let url: String
    public let embedURL: String
    public let broadcasterId: String
    public let broadcasterName: String
    public let creatorId: String
    public let creatorName: String
    public let videoId: String
    public let gameId: String
    public let language: String
    public let title: String
    public let viewCount: Int
    public let createdAt: String
    public let thumbnailURL: String
    public let duration: Double
    public let vodOffset: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, url, language, title, duration
        case embedURL = "embed_url"
        case broadcasterId = "broadcaster_id"
        case broadcasterName = "broadcaster_name"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case videoId = "video_id"
        case gameId = "game_id"
        case viewCount = "view_count"
        case createdAt = "created_at"
        case thumbnailURL = "thumbnail_url"
        case vodOffset = "vod_offset"
    }
}

// MARK: - API Response Models

public struct TwitchAPIResponse<T: Codable>: Codable {
    public let data: [T]
    public let pagination: TwitchPagination?
    public let total: Int?
}

public struct TwitchPagination: Codable {
    public let cursor: String?
}

public struct TwitchAuthTokenResponse: Codable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int
    public let scope: [String]
    public let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

public struct TwitchValidateTokenResponse: Codable {
    public let clientId: String
    public let login: String?
    public let scopes: [String]
    public let userId: String?
    public let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case login
        case scopes
        case userId = "user_id"
        case expiresIn = "expires_in"
    }
}

// MARK: - Error Types

public enum TwitchAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case authenticationRequired
    case invalidToken
    case rateLimited(retryAfter: TimeInterval?)
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationRequired:
            return "Authentication required"
        case .invalidToken:
            return "Invalid or expired token"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after: \(retryAfter ?? 0) seconds"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Forbidden access"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Rate Limiter

public class TwitchRateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "twitch.rate.limiter", attributes: .concurrent)
    
    public init(maxRequests: Int = 800, timeWindow: TimeInterval = 60) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    public func canMakeRequest() -> Bool {
        return queue.sync {
            let now = Date()
            let cutoff = now.addingTimeInterval(-timeWindow)
            
            // Remove old requests
            requestTimes = requestTimes.filter { $0 > cutoff }
            
            return requestTimes.count < maxRequests
        }
    }
    
    public func recordRequest() {
        queue.async(flags: .barrier) {
            let now = Date()
            let cutoff = now.addingTimeInterval(-self.timeWindow)
            
            // Remove old requests and add new one
            self.requestTimes = self.requestTimes.filter { $0 > cutoff }
            self.requestTimes.append(now)
        }
    }
    
    public func timeUntilNextRequest() -> TimeInterval {
        return queue.sync {
            let now = Date()
            let cutoff = now.addingTimeInterval(-timeWindow)
            
            // Remove old requests
            requestTimes = requestTimes.filter { $0 > cutoff }
            
            if requestTimes.count < maxRequests {
                return 0
            }
            
            // Find the oldest request and calculate when it will expire
            if let oldestRequest = requestTimes.first {
                return oldestRequest.addingTimeInterval(timeWindow).timeIntervalSince(now)
            }
            
            return 0
        }
    }
}

// MARK: - Cache Manager

public class TwitchCacheManager {
    private let cache = NSCache<NSString, AnyObject>()
    private let cacheQueue = DispatchQueue(label: "twitch.cache", attributes: .concurrent)
    private var cacheExpiration: [String: Date] = [:]
    
    public init() {
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 10 // 10MB
    }
    
    public func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        return cacheQueue.sync {
            guard let expiration = cacheExpiration[key],
                  expiration > Date() else {
                remove(key)
                return nil
            }
            
            guard let data = cache.object(forKey: key as NSString) as? Data else {
                return nil
            }
            
            return try? JSONDecoder().decode(type, from: data)
        }
    }
    
    public func set<T: Codable>(_ key: String, value: T, expiration: TimeInterval = 300) {
        cacheQueue.async(flags: .barrier) {
            guard let data = try? JSONEncoder().encode(value) else { return }
            
            self.cache.setObject(data as NSData, forKey: key as NSString)
            self.cacheExpiration[key] = Date().addingTimeInterval(expiration)
        }
    }
    
    public func remove(_ key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeObject(forKey: key as NSString)
            self.cacheExpiration.removeValue(forKey: key)
        }
    }
    
    public func clear() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAllObjects()
            self.cacheExpiration.removeAll()
        }
    }
}

// MARK: - Main Twitch Service

@MainActor
public class TwitchService: ObservableObject {
    
    // MARK: - Properties
    
    public static let shared = TwitchService()
    
    private let baseURL = "https://api.twitch.tv/helix"
    private let authURL = "https://id.twitch.tv/oauth2"
    
    private let clientId: String
    private let clientSecret: String
    private let redirectURI: String
    
    @Published public var isAuthenticated = false
    @Published public var currentUser: TwitchUser?
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpirationDate: Date?
    
    private let rateLimiter = TwitchRateLimiter()
    private let cacheManager = TwitchCacheManager()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published public var isNetworkAvailable = true
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(clientId: String = Config.Twitch.clientId, clientSecret: String = Config.Twitch.clientSecret, redirectURI: String = Config.Twitch.redirectUri) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        
        setupNetworkMonitoring()
        loadStoredCredentials()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Authentication
    
    public func getAuthorizationURL(scopes: [String] = ["user:read:email", "user:read:follows"]) -> URL? {
        var components = URLComponents(string: "\(authURL)/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]
        return components?.url
    }
    
    public func handleAuthorizationCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw TwitchAPIError.invalidURL
        }
        
        try await exchangeCodeForToken(code: code)
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        let url = URL(string: "\(authURL)/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TwitchAPIError.authenticationRequired
        }
        
        let tokenResponse = try JSONDecoder().decode(TwitchAuthTokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        storeCredentials()
        self.isAuthenticated = true
        
        // Fetch current user info
        try await fetchCurrentUser()
    }
    
    public func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw TwitchAPIError.invalidToken
        }
        
        let url = URL(string: "\(authURL)/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TwitchAPIError.invalidToken
        }
        
        let tokenResponse = try JSONDecoder().decode(TwitchAuthTokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        if let newRefreshToken = tokenResponse.refreshToken {
            self.refreshToken = newRefreshToken
        }
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        storeCredentials()
    }
    
    public func validateToken() async throws -> Bool {
        guard let accessToken = accessToken else {
            throw TwitchAPIError.authenticationRequired
        }
        
        let url = URL(string: "\(authURL)/validate")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwitchAPIError.networkError(URLError(.badServerResponse))
        }
        
        if httpResponse.statusCode == 401 {
            self.isAuthenticated = false
            return false
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TwitchAPIError.serverError(httpResponse.statusCode)
        }
        
        let validation = try JSONDecoder().decode(TwitchValidateTokenResponse.self, from: data)
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(validation.expiresIn))
        
        return true
    }
    
    public func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil
        currentUser = nil
        isAuthenticated = false
        
        clearStoredCredentials()
        cacheManager.clear()
    }
    
    // MARK: - App Access Token (for public API access)
    
    public func getAppAccessToken() async throws {
        let url = URL(string: "\(authURL)/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "client_credentials"
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TwitchAPIError.authenticationRequired
        }
        
        let tokenResponse = try JSONDecoder().decode(TwitchAuthTokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        self.isAuthenticated = true
        
        storeCredentials()
    }
    
    // MARK: - Token Storage
    
    private func storeCredentials() {
        UserDefaults.standard.set(accessToken, forKey: "twitch_access_token")
        UserDefaults.standard.set(refreshToken, forKey: "twitch_refresh_token")
        UserDefaults.standard.set(tokenExpirationDate, forKey: "twitch_token_expiration")
    }
    
    private func loadStoredCredentials() {
        self.accessToken = UserDefaults.standard.string(forKey: "twitch_access_token")
        self.refreshToken = UserDefaults.standard.string(forKey: "twitch_refresh_token")
        self.tokenExpirationDate = UserDefaults.standard.object(forKey: "twitch_token_expiration") as? Date
        
        if accessToken != nil {
            self.isAuthenticated = true
            
            Task {
                do {
                    if try await validateToken() {
                        try await fetchCurrentUser()
                    }
                } catch {
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    private func clearStoredCredentials() {
        UserDefaults.standard.removeObject(forKey: "twitch_access_token")
        UserDefaults.standard.removeObject(forKey: "twitch_refresh_token")
        UserDefaults.standard.removeObject(forKey: "twitch_token_expiration")
    }
    
    // MARK: - API Request Helper
    
    private func makeAPIRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        parameters: [String: String] = [:],
        requiresAuth: Bool = false,
        cacheKey: String? = nil,
        cacheExpiration: TimeInterval = 300
    ) async throws -> TwitchAPIResponse<T> {
        
        // Check cache first
        if let cacheKey = cacheKey,
           let cachedResponse: TwitchAPIResponse<T> = cacheManager.get(cacheKey, type: TwitchAPIResponse<T>.self) {
            return cachedResponse
        }
        
        // Check network availability
        guard isNetworkAvailable else {
            throw TwitchAPIError.networkError(URLError(.notConnectedToInternet))
        }
        
        // Rate limiting
        if !rateLimiter.canMakeRequest() {
            let waitTime = rateLimiter.timeUntilNextRequest()
            throw TwitchAPIError.rateLimited(retryAfter: waitTime)
        }
        
        // Token validation and refresh
        if requiresAuth {
            guard isAuthenticated else {
                throw TwitchAPIError.authenticationRequired
            }
            
            if let expirationDate = tokenExpirationDate,
               expirationDate <= Date().addingTimeInterval(300) { // Refresh 5 minutes before expiration
                try await refreshAccessToken()
            }
        }
        
        // Build URL
        var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)")!
        if !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents.url else {
            throw TwitchAPIError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(clientId, forHTTPHeaderField: "Client-Id")
        
        if requiresAuth, let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Record request for rate limiting
        rateLimiter.recordRequest()
        
        // Make request with retry logic
        let (data, response) = try await performRequestWithRetry(request: request)
        
        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwitchAPIError.networkError(URLError(.badServerResponse))
        }
        
        try handleHTTPResponse(httpResponse, data: data)
        
        // Decode response
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        
        let apiResponse = try decoder.decode(TwitchAPIResponse<T>.self, from: data)
        
        // Cache response
        if let cacheKey = cacheKey {
            cacheManager.set(cacheKey, value: apiResponse, expiration: cacheExpiration)
        }
        
        return apiResponse
    }
    
    private func performRequestWithRetry(request: URLRequest, maxRetries: Int = 3) async throws -> (Data, URLResponse) {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await URLSession.shared.data(for: request)
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    // Exponential backoff
                    let delay = TimeInterval(pow(2.0, Double(attempt)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? TwitchAPIError.unknown(URLError(.unknown))
    }
    
    private func handleHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            break
        case 401:
            self.isAuthenticated = false
            throw TwitchAPIError.unauthorized
        case 403:
            throw TwitchAPIError.forbidden
        case 404:
            throw TwitchAPIError.notFound
        case 429:
            let retryAfter = response.allHeaderFields["Retry-After"] as? String
            throw TwitchAPIError.rateLimited(retryAfter: TimeInterval(retryAfter ?? "60"))
        case 500...599:
            throw TwitchAPIError.serverError(response.statusCode)
        default:
            throw TwitchAPIError.serverError(response.statusCode)
        }
    }
    
    // MARK: - User Data
    
    public func fetchCurrentUser() async throws {
        let response: TwitchAPIResponse<TwitchUser> = try await makeAPIRequest(
            endpoint: "/users",
            requiresAuth: true,
            cacheKey: "current_user",
            cacheExpiration: 600
        )
        
        self.currentUser = response.data.first
    }
    
    public func getUser(by login: String) async throws -> TwitchUser? {
        let response: TwitchAPIResponse<TwitchUser> = try await makeAPIRequest(
            endpoint: "/users",
            parameters: ["login": login],
            cacheKey: "user_\(login)",
            cacheExpiration: 600
        )
        
        return response.data.first
    }
    
    public func getUsers(by ids: [String]) async throws -> [TwitchUser] {
        guard !ids.isEmpty else { return [] }
        
        let response: TwitchAPIResponse<TwitchUser> = try await makeAPIRequest(
            endpoint: "/users",
            parameters: ["id": ids.joined(separator: "&id=")],
            cacheKey: "users_\(ids.joined(separator: "_"))",
            cacheExpiration: 600
        )
        
        return response.data
    }
    
    public func getFollowers(userId: String, after: String? = nil, first: Int = 20) async throws -> (followers: [TwitchFollower], pagination: TwitchPagination?) {
        var parameters = [
            "to_id": userId,
            "first": String(first)
        ]
        
        if let after = after {
            parameters["after"] = after
        }
        
        let response: TwitchAPIResponse<TwitchFollower> = try await makeAPIRequest(
            endpoint: "/users/follows",
            parameters: parameters,
            requiresAuth: true
        )
        
        return (response.data, response.pagination)
    }
    
    // MARK: - Stream Data
    
    public func getLiveStreams(
        gameId: String? = nil,
        userId: String? = nil,
        userLogin: String? = nil,
        language: String? = nil,
        first: Int = 20,
        after: String? = nil
    ) async throws -> (streams: [TwitchStream], pagination: TwitchPagination?) {
        
        var parameters = ["first": String(first)]
        
        if let gameId = gameId { parameters["game_id"] = gameId }
        if let userId = userId { parameters["user_id"] = userId }
        if let userLogin = userLogin { parameters["user_login"] = userLogin }
        if let language = language { parameters["language"] = language }
        if let after = after { parameters["after"] = after }
        
        let cacheKey = "live_streams_\(parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "_"))"
        
        let response: TwitchAPIResponse<TwitchStream> = try await makeAPIRequest(
            endpoint: "/streams",
            parameters: parameters,
            cacheKey: cacheKey,
            cacheExpiration: 60 // Cache for 1 minute since live data changes frequently
        )
        
        return (response.data, response.pagination)
    }
    
    public func getTopStreams(first: Int = 20, after: String? = nil) async throws -> (streams: [TwitchStream], pagination: TwitchPagination?) {
        var parameters = ["first": String(first)]
        if let after = after { parameters["after"] = after }
        
        let response: TwitchAPIResponse<TwitchStream> = try await makeAPIRequest(
            endpoint: "/streams",
            parameters: parameters,
            cacheKey: "top_streams_\(first)_\(after ?? "")",
            cacheExpiration: 60
        )
        
        return (response.data, response.pagination)
    }
    
    public func getChannelInformation(broadcasterId: String) async throws -> TwitchChannel? {
        let response: TwitchAPIResponse<TwitchChannel> = try await makeAPIRequest(
            endpoint: "/channels",
            parameters: ["broadcaster_id": broadcasterId],
            cacheKey: "channel_\(broadcasterId)",
            cacheExpiration: 300
        )
        
        return response.data.first
    }
    
    // MARK: - Categories/Games
    
    public func getTopGames(first: Int = 20, after: String? = nil) async throws -> (games: [TwitchGame], pagination: TwitchPagination?) {
        var parameters = ["first": String(first)]
        if let after = after { parameters["after"] = after }
        
        let response: TwitchAPIResponse<TwitchGame> = try await makeAPIRequest(
            endpoint: "/games/top",
            parameters: parameters,
            cacheKey: "top_games_\(first)_\(after ?? "")",
            cacheExpiration: 600
        )
        
        return (response.data, response.pagination)
    }
    
    public func getGames(ids: [String] = [], names: [String] = []) async throws -> [TwitchGame] {
        var parameters: [String: String] = [:]
        
        if !ids.isEmpty {
            parameters["id"] = ids.joined(separator: "&id=")
        }
        if !names.isEmpty {
            parameters["name"] = names.joined(separator: "&name=")
        }
        
        let cacheKey = "games_\(ids.joined(separator: "_"))_\(names.joined(separator: "_"))"
        
        let response: TwitchAPIResponse<TwitchGame> = try await makeAPIRequest(
            endpoint: "/games",
            parameters: parameters,
            cacheKey: cacheKey,
            cacheExpiration: 3600
        )
        
        return response.data
    }
    
    // MARK: - Search
    
    public func searchChannels(
        query: String,
        liveOnly: Bool = false,
        first: Int = 20,
        after: String? = nil
    ) async throws -> (channels: [TwitchChannel], pagination: TwitchPagination?) {
        
        var parameters = [
            "query": query,
            "first": String(first)
        ]
        
        if liveOnly {
            parameters["live_only"] = "true"
        }
        
        if let after = after {
            parameters["after"] = after
        }
        
        let response: TwitchAPIResponse<TwitchChannel> = try await makeAPIRequest(
            endpoint: "/search/channels",
            parameters: parameters,
            cacheKey: "search_channels_\(query)_\(liveOnly)_\(first)_\(after ?? "")",
            cacheExpiration: 300
        )
        
        return (response.data, response.pagination)
    }
    
    public func searchCategories(
        query: String,
        first: Int = 20,
        after: String? = nil
    ) async throws -> (games: [TwitchGame], pagination: TwitchPagination?) {
        
        var parameters = [
            "query": query,
            "first": String(first)
        ]
        
        if let after = after {
            parameters["after"] = after
        }
        
        let response: TwitchAPIResponse<TwitchGame> = try await makeAPIRequest(
            endpoint: "/search/categories",
            parameters: parameters,
            cacheKey: "search_categories_\(query)_\(first)_\(after ?? "")",
            cacheExpiration: 300
        )
        
        return (response.data, response.pagination)
    }
    
    // MARK: - Clips
    
    public func getClips(
        broadcasterId: String? = nil,
        gameId: String? = nil,
        startedAt: String? = nil,
        endedAt: String? = nil,
        first: Int = 20,
        after: String? = nil
    ) async throws -> (clips: [TwitchClip], pagination: TwitchPagination?) {
        
        var parameters = ["first": String(first)]
        
        if let broadcasterId = broadcasterId { parameters["broadcaster_id"] = broadcasterId }
        if let gameId = gameId { parameters["game_id"] = gameId }
        if let startedAt = startedAt { parameters["started_at"] = startedAt }
        if let endedAt = endedAt { parameters["ended_at"] = endedAt }
        if let after = after { parameters["after"] = after }
        
        let cacheKey = "clips_\(parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "_"))"
        
        let response: TwitchAPIResponse<TwitchClip> = try await makeAPIRequest(
            endpoint: "/clips",
            parameters: parameters,
            cacheKey: cacheKey,
            cacheExpiration: 600
        )
        
        return (response.data, response.pagination)
    }
    
    // MARK: - Utility Methods
    
    public func formatThumbnailURL(_ url: String, width: Int = 320, height: Int = 180) -> String {
        return url.replacingOccurrences(of: "{width}", with: String(width))
                  .replacingOccurrences(of: "{height}", with: String(height))
    }
    
    public func formatViewerCount(_ count: Int) -> String {
        if count < 1000 {
            return String(count)
        } else if count < 1000000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        }
    }
    
    public func isTokenExpired() -> Bool {
        guard let expirationDate = tokenExpirationDate else { return true }
        return expirationDate <= Date()
    }
    
    public func getRateLimitStatus() -> (requestsRemaining: Int, resetTime: TimeInterval) {
        let remaining = max(0, 800 - rateLimiter.timeUntilNextRequest())
        let resetTime = rateLimiter.timeUntilNextRequest()
        return (Int(remaining), resetTime)
    }
}

// MARK: - HTTP Method Enum

private enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Extensions

extension TwitchService {
    
    // MARK: - Pagination Helper
    
    public func getAllPages<T: Codable>(
        fetchFunction: @escaping (String?) async throws -> (data: [T], pagination: TwitchPagination?)
    ) async throws -> [T] {
        var allData: [T] = []
        var cursor: String?
        
        repeat {
            let result = try await fetchFunction(cursor)
            allData.append(contentsOf: result.data)
            cursor = result.pagination?.cursor
        } while cursor != nil
        
        return allData
    }
    
    // MARK: - Batch Operations
    
    public func batchGetUsers(logins: [String]) async throws -> [TwitchUser] {
        let batchSize = 100 // Twitch API limit
        var allUsers: [TwitchUser] = []
        
        for batch in logins.chunked(into: batchSize) {
            let response: TwitchAPIResponse<TwitchUser> = try await makeAPIRequest(
                endpoint: "/users",
                parameters: ["login": batch.joined(separator: "&login=")]
            )
            allUsers.append(contentsOf: response.data)
        }
        
        return allUsers
    }
    
    public func batchGetStreams(userIds: [String]) async throws -> [TwitchStream] {
        let batchSize = 100 // Twitch API limit
        var allStreams: [TwitchStream] = []
        
        for batch in userIds.chunked(into: batchSize) {
            let response: TwitchAPIResponse<TwitchStream> = try await makeAPIRequest(
                endpoint: "/streams",
                parameters: ["user_id": batch.joined(separator: "&user_id=")]
            )
            allStreams.append(contentsOf: response.data)
        }
        
        return allStreams
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}