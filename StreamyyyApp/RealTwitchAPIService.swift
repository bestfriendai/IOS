//
//  RealTwitchAPIService.swift
//  StreamyyyApp
//
//  Real Twitch API implementation with OAuth and live data
//

import Foundation
import Combine

// MARK: - Twitch API Models
struct TwitchStreamResponse: Codable {
    let data: [TwitchStream]
    let pagination: TwitchPagination?
}

struct TwitchStream: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let userLogin: String
    let userName: String
    let gameId: String
    let gameName: String
    let type: String
    let title: String
    let viewerCount: Int
    let startedAt: String
    let language: String
    let thumbnailUrl: String
    let tagIds: [String]?
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
        case tagIds = "tag_ids"
        case isMature = "is_mature"
    }
    
    // Helper computed properties
    var formattedViewerCount: String {
        if viewerCount >= 1000000 {
            return String(format: "%.1fM", Double(viewerCount) / 1000000.0)
        } else if viewerCount >= 1000 {
            return String(format: "%.1fK", Double(viewerCount) / 1000.0)
        } else {
            return "\(viewerCount)"
        }
    }
    
    var thumbnailUrlLarge: String {
        return thumbnailUrl.replacingOccurrences(of: "{width}", with: "640")
                          .replacingOccurrences(of: "{height}", with: "360")
    }
    
    var thumbnailUrlMedium: String {
        return thumbnailUrl.replacingOccurrences(of: "{width}", with: "320")
                          .replacingOccurrences(of: "{height}", with: "180")
    }
    
    var embedUrl: String {
        return "https://player.twitch.tv/?channel=\(userLogin)&parent=streamyyy.com"
    }
}

struct TwitchPagination: Codable {
    let cursor: String?
}

struct TwitchGame: Codable, Identifiable {
    let id: String
    let name: String
    let boxArtUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case boxArtUrl = "box_art_url"
    }
    
    var boxArtUrlLarge: String {
        return boxArtUrl.replacingOccurrences(of: "{width}", with: "285")
                       .replacingOccurrences(of: "{height}", with: "380")
    }
}

struct TwitchGameResponse: Codable {
    let data: [TwitchGame]
}

struct TwitchUser: Codable, Identifiable {
    let id: String
    let login: String
    let displayName: String
    let type: String
    let broadcasterType: String
    let description: String
    let profileImageUrl: String
    let offlineImageUrl: String
    let viewCount: Int
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case displayName = "display_name"
        case type
        case broadcasterType = "broadcaster_type"
        case description
        case profileImageUrl = "profile_image_url"
        case offlineImageUrl = "offline_image_url"
        case viewCount = "view_count"
        case createdAt = "created_at"
    }
}

struct TwitchUserResponse: Codable {
    let data: [TwitchUser]
}

struct TwitchTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let scope: [String]
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

struct TwitchAppTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Twitch API Service
@MainActor
class RealTwitchAPIService: ObservableObject {
    static let shared = RealTwitchAPIService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: TwitchUser?
    @Published var streams: [TwitchStream] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var appAccessToken: String?
    private var userAccessToken: String?
    private var tokenExpirationDate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private let session = URLSession.shared
    
    private init() {
        setupService()
    }
    
    // MARK: - Setup
    private func setupService() {
        // Check for stored tokens
        loadStoredTokens()
        
        // Get app access token for public API calls
        Task {
            await getAppAccessToken()
        }
    }
    
    private func loadStoredTokens() {
        if let storedToken = UserDefaults.standard.string(forKey: "twitch_user_token"),
           let expirationData = UserDefaults.standard.object(forKey: "twitch_token_expiration") as? Date,
           expirationData > Date() {
            userAccessToken = storedToken
            tokenExpirationDate = expirationData
            isAuthenticated = true
        }
        
        if let storedAppToken = UserDefaults.standard.string(forKey: "twitch_app_token"),
           let appExpirationData = UserDefaults.standard.object(forKey: "twitch_app_token_expiration") as? Date,
           appExpirationData > Date() {
            appAccessToken = storedAppToken
        }
    }
    
    private func saveTokens() {
        if let userToken = userAccessToken {
            UserDefaults.standard.set(userToken, forKey: "twitch_user_token")
        }
        if let expiration = tokenExpirationDate {
            UserDefaults.standard.set(expiration, forKey: "twitch_token_expiration")
        }
        if let appToken = appAccessToken {
            UserDefaults.standard.set(appToken, forKey: "twitch_app_token")
        }
    }
    
    // MARK: - App Access Token (for public API calls)
    func getAppAccessToken() async {
        guard let url = URL(string: "\(Config.Twitch.authURL)/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(Config.Twitch.clientId)&client_secret=\(Config.Twitch.clientSecret)&grant_type=client_credentials"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await session.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TwitchAppTokenResponse.self, from: data)
            
            appAccessToken = tokenResponse.accessToken
            
            // Set expiration date
            let expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            UserDefaults.standard.set(appAccessToken, forKey: "twitch_app_token")
            UserDefaults.standard.set(expirationDate, forKey: "twitch_app_token_expiration")
            
            print("✅ Twitch app access token obtained successfully")
        } catch {
            print("❌ Failed to get Twitch app access token: \(error)")
            self.error = error
        }
    }
    
    // MARK: - OAuth Authentication
    func startOAuthFlow() -> URL? {
        let state = UUID().uuidString
        UserDefaults.standard.set(state, forKey: "twitch_oauth_state")
        
        var components = URLComponents(string: "\(Config.Twitch.authURL)/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: Config.Twitch.clientId),
            URLQueryItem(name: "redirect_uri", value: Config.Twitch.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Config.Twitch.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]
        
        return components?.url
    }
    
    func handleOAuthCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            error = NSError(domain: "TwitchAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL"])
            return
        }
        
        let code = queryItems.first(where: { $0.name == "code" })?.value
        let state = queryItems.first(where: { $0.name == "state" })?.value
        let storedState = UserDefaults.standard.string(forKey: "twitch_oauth_state")
        
        guard let authCode = code,
              let receivedState = state,
              receivedState == storedState else {
            error = NSError(domain: "TwitchAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid OAuth state"])
            return
        }
        
        await exchangeCodeForToken(code: authCode)
    }
    
    private func exchangeCodeForToken(code: String) async {
        guard let url = URL(string: "\(Config.Twitch.authURL)/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(Config.Twitch.clientId)&client_secret=\(Config.Twitch.clientSecret)&code=\(code)&grant_type=authorization_code&redirect_uri=\(Config.Twitch.redirectUri)"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await session.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TwitchTokenResponse.self, from: data)
            
            userAccessToken = tokenResponse.accessToken
            tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            isAuthenticated = true
            
            saveTokens()
            await getCurrentUser()
            
            print("✅ Twitch user authentication successful")
        } catch {
            print("❌ Failed to exchange code for token: \(error)")
            self.error = error
        }
    }
    
    // MARK: - User Management
    func getCurrentUser() async {
        guard let token = userAccessToken,
              let url = URL(string: "\(Config.Twitch.baseURL)/users") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.Twitch.clientId, forHTTPHeaderField: "Client-Id")
        
        do {
            let (data, _) = try await session.data(for: request)
            let userResponse = try JSONDecoder().decode(TwitchUserResponse.self, from: data)
            
            if let user = userResponse.data.first {
                currentUser = user
            }
        } catch {
            print("❌ Failed to get current user: \(error)")
            self.error = error
        }
    }
    
    func signOut() {
        userAccessToken = nil
        currentUser = nil
        isAuthenticated = false
        tokenExpirationDate = nil
        
        UserDefaults.standard.removeObject(forKey: "twitch_user_token")
        UserDefaults.standard.removeObject(forKey: "twitch_token_expiration")
        UserDefaults.standard.removeObject(forKey: "twitch_oauth_state")
    }
    
    // MARK: - Stream API Calls
    func getTopStreams(first: Int = 20, after: String? = nil) async -> (streams: [TwitchStream], pagination: TwitchPagination?) {
        guard let token = appAccessToken,
              let url = URL(string: "\(Config.Twitch.baseURL)/streams") else {
            return ([], nil)
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "first", value: "\(first)")]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        components?.queryItems = queryItems
        
        guard let finalURL = components?.url else { return ([], nil) }
        
        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.Twitch.clientId, forHTTPHeaderField: "Client-Id")
        
        do {
            isLoading = true
            let (data, _) = try await session.data(for: request)
            let streamResponse = try JSONDecoder().decode(TwitchStreamResponse.self, from: data)
            
            isLoading = false
            return (streamResponse.data, streamResponse.pagination)
        } catch {
            print("❌ Failed to get top streams: \(error)")
            self.error = error
            isLoading = false
            return ([], nil)
        }
    }
    
    func getStreamsByGame(gameId: String, first: Int = 20) async -> [TwitchStream] {
        guard let token = appAccessToken,
              let url = URL(string: "\(Config.Twitch.baseURL)/streams") else {
            return []
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "game_id", value: gameId),
            URLQueryItem(name: "first", value: "\(first)")
        ]
        
        guard let finalURL = components?.url else { return [] }
        
        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.Twitch.clientId, forHTTPHeaderField: "Client-Id")
        
        do {
            let (data, _) = try await session.data(for: request)
            let streamResponse = try JSONDecoder().decode(TwitchStreamResponse.self, from: data)
            
            return streamResponse.data
        } catch {
            print("❌ Failed to get streams by game: \(error)")
            self.error = error
            return []
        }
    }
    
    func searchStreams(query: String, first: Int = 20) async -> [TwitchStream] {
        guard let token = appAccessToken,
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(Config.Twitch.baseURL)/search/channels") else {
            return []
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "query", value: encodedQuery),
            URLQueryItem(name: "first", value: "\(first)"),
            URLQueryItem(name: "live_only", value: "true")
        ]
        
        guard let finalURL = components?.url else { return [] }
        
        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.Twitch.clientId, forHTTPHeaderField: "Client-Id")
        
        do {
            let (data, _) = try await session.data(for: request)
            // Note: Search channels returns different format, would need different model
            // For now, return empty array and use regular stream search
            return []
        } catch {
            print("❌ Failed to search streams: \(error)")
            self.error = error
            return []
        }
    }
    
    func getTopGames(first: Int = 20) async -> [TwitchGame] {
        guard let token = appAccessToken,
              let url = URL(string: "\(Config.Twitch.baseURL)/games/top") else {
            return []
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "first", value: "\(first)")]
        
        guard let finalURL = components?.url else { return [] }
        
        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.Twitch.clientId, forHTTPHeaderField: "Client-Id")
        
        do {
            let (data, _) = try await session.data(for: request)
            let gameResponse = try JSONDecoder().decode(TwitchGameResponse.self, from: data)
            
            return gameResponse.data
        } catch {
            print("❌ Failed to get top games: \(error)")
            self.error = error
            return []
        }
    }
    
    // MARK: - Utility Methods
    func refreshStreams() async {
        let (newStreams, _) = await getTopStreams()
        streams = newStreams
    }
    
    func clearError() {
        error = nil
    }
    
    private func isTokenExpired() -> Bool {
        guard let expiration = tokenExpirationDate else { return true }
        return Date() >= expiration
    }
    
    func validateAndRefreshTokens() async {
        if isTokenExpired() && isAuthenticated {
            // In a real app, you'd implement refresh token logic here
            signOut()
        }
        
        if appAccessToken == nil || UserDefaults.standard.object(forKey: "twitch_app_token_expiration") as? Date ?? Date() <= Date() {
            await getAppAccessToken()
        }
    }
}

// MARK: - Extensions
extension RealTwitchAPIService {
    func getStreamEmbedHTML(for stream: TwitchStream, width: Int = 640, height: Int = 360) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; padding: 0; background: black; }
                iframe { width: 100%; height: 100vh; border: none; }
            </style>
        </head>
        <body>
            <iframe
                src="https://player.twitch.tv/?channel=\(stream.userLogin)&parent=streamyyy.com&autoplay=true&muted=false"
                allowfullscreen>
            </iframe>
        </body>
        </html>
        """
    }
}