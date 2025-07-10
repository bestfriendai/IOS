//
//  AuthenticationService.swift
//  StreamyyyApp
//
//  OAuth authentication service for Twitch and YouTube
//

import Foundation
import Combine
import AuthenticationServices
import SwiftUI

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: AuthenticatedUser?
    @Published var authenticationError: AuthenticationError?
    @Published var isLoading = false
    
    // Platform-specific authentication status
    @Published var twitchAuthStatus: PlatformAuthStatus = .notAuthenticated
    @Published var youtubeAuthStatus: PlatformAuthStatus = .notAuthenticated
    
    // MARK: - Private Properties
    private let twitchService = TwitchService.shared
    private let youtubeService = YouTubeService()
    private let networkManager = NetworkManager.shared
    private let cacheManager = CacheManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var currentAuthSession: ASWebAuthenticationSession?
    
    // OAuth Configuration
    private let twitchConfig = OAuthConfig(
        clientId: Config.Twitch.clientId,
        clientSecret: Config.Twitch.clientSecret,
        redirectUri: Config.Twitch.redirectUri,
        scopes: Config.Twitch.scopes,
        authURL: "https://id.twitch.tv/oauth2/authorize",
        tokenURL: "https://id.twitch.tv/oauth2/token"
    )
    
    private let youtubeConfig = OAuthConfig(
        clientId: Config.Platforms.YouTube.clientId,
        clientSecret: Config.Platforms.YouTube.clientSecret,
        redirectUri: Config.Platforms.YouTube.redirectURI,
        scopes: Config.Platforms.YouTube.scopes,
        authURL: "https://accounts.google.com/o/oauth2/v2/auth",
        tokenURL: "https://oauth2.googleapis.com/token"
    )
    
    private override init() {
        super.init()
        loadStoredAuthentication()
        setupAuthenticationObservers()
    }
    
    // MARK: - Public Methods
    
    func authenticateWithTwitch() async throws {
        guard networkManager.isConnected else {
            throw AuthenticationError.networkError
        }
        
        isLoading = true
        twitchAuthStatus = .authenticating
        
        do {
            let authResult = try await performOAuthFlow(config: twitchConfig, platform: .twitch)
            try await completeTwitchAuthentication(authResult: authResult)
        } catch {
            twitchAuthStatus = .error(error)
            throw error
        }
        
        isLoading = false
    }
    
    func authenticateWithYouTube() async throws {
        guard networkManager.isConnected else {
            throw AuthenticationError.networkError
        }
        
        isLoading = true
        youtubeAuthStatus = .authenticating
        
        do {
            let authResult = try await performOAuthFlow(config: youtubeConfig, platform: .youtube)
            try await completeYouTubeAuthentication(authResult: authResult)
        } catch {
            youtubeAuthStatus = .error(error)
            throw error
        }
        
        isLoading = false
    }
    
    func signOut() async {
        // Clear tokens and user data
        currentUser = nil
        isAuthenticated = false
        twitchAuthStatus = .notAuthenticated
        youtubeAuthStatus = .notAuthenticated
        
        // Clear stored credentials
        clearStoredCredentials()
        
        // Clear service authentications
        twitchService.logout()
        
        // Clear cached data
        cacheManager.clearAll()
    }
    
    func refreshAuthentication() async {
        guard let user = currentUser else { return }
        
        do {
            // Refresh platform tokens
            if user.twitchAuth != nil {
                try await refreshTwitchToken()
            }
            
            if user.youtubeAuth != nil {
                try await refreshYouTubeToken()
            }
            
            // Update user data
            await updateUserData()
            
        } catch {
            authenticationError = AuthenticationError.tokenRefreshFailed
        }
    }
    
    // MARK: - Private Methods
    
    private func loadStoredAuthentication() {
        // Load stored authentication data
        if let userData = UserDefaults.standard.data(forKey: "authenticated_user"),
           let user = try? JSONDecoder().decode(AuthenticatedUser.self, from: userData) {
            currentUser = user
            isAuthenticated = true
            
            // Update platform statuses
            twitchAuthStatus = user.twitchAuth != nil ? .authenticated : .notAuthenticated
            youtubeAuthStatus = user.youtubeAuth != nil ? .authenticated : .notAuthenticated
            
            // Validate tokens
            Task {
                await validateStoredTokens()
            }
        }
    }
    
    private func setupAuthenticationObservers() {
        // Monitor network connectivity
        networkManager.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.authenticationError = AuthenticationError.networkError
                }
            }
            .store(in: &cancellables)
    }
    
    private func performOAuthFlow(config: OAuthConfig, platform: AuthPlatform) async throws -> OAuthResult {
        return try await withCheckedThrowingContinuation { continuation in
            let authURL = buildAuthURL(config: config)
            
            currentAuthSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: extractScheme(from: config.redirectUri)
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: AuthenticationError.oauthError(error))
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthenticationError.invalidCallback)
                    return
                }
                
                do {
                    let authCode = try self.extractAuthCode(from: callbackURL)
                    
                    Task {
                        do {
                            let tokens = try await self.exchangeCodeForTokens(
                                authCode: authCode,
                                config: config
                            )
                            
                            let result = OAuthResult(
                                platform: platform,
                                accessToken: tokens.accessToken,
                                refreshToken: tokens.refreshToken,
                                expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expiresIn)),
                                scopes: tokens.scopes
                            )
                            
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            currentAuthSession?.presentationContextProvider = self
            currentAuthSession?.prefersEphemeralWebBrowserSession = false
            currentAuthSession?.start()
        }
    }
    
    private func buildAuthURL(config: OAuthConfig) -> URL {
        var components = URLComponents(string: config.authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]
        
        return components.url!
    }
    
    private func extractScheme(from url: String) -> String {
        return URL(string: url)?.scheme ?? "streamyyy"
    }
    
    private func extractAuthCode(from url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw AuthenticationError.invalidCallback
        }
        
        // Check for error
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            throw AuthenticationError.oauthError(NSError(domain: "OAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }
        
        // Extract code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw AuthenticationError.invalidCallback
        }
        
        return code
    }
    
    private func exchangeCodeForTokens(authCode: String, config: OAuthConfig) async throws -> TokenResponse {
        guard let url = URL(string: config.tokenURL) else {
            throw AuthenticationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "code": authCode,
            "grant_type": "authorization_code",
            "redirect_uri": config.redirectUri
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthenticationError.tokenExchangeFailed
        }
        
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    
    private func completeTwitchAuthentication(authResult: OAuthResult) async throws {
        // Store tokens in TwitchService
        // This would integrate with the existing TwitchService
        
        // Fetch user profile
        let userProfile = try await fetchTwitchUserProfile(accessToken: authResult.accessToken)
        
        // Create or update user
        let twitchAuth = PlatformAuthentication(
            platform: .twitch,
            accessToken: authResult.accessToken,
            refreshToken: authResult.refreshToken,
            expiresAt: authResult.expiresAt,
            scopes: authResult.scopes,
            userProfile: userProfile
        )
        
        if currentUser != nil {
            currentUser?.twitchAuth = twitchAuth
        } else {
            currentUser = AuthenticatedUser(
                id: userProfile.id,
                primaryEmail: userProfile.email,
                displayName: userProfile.displayName,
                avatarURL: userProfile.profileImageURL,
                twitchAuth: twitchAuth,
                youtubeAuth: nil,
                createdAt: Date(),
                lastLoginAt: Date()
            )
        }
        
        twitchAuthStatus = .authenticated
        isAuthenticated = true
        
        // Store credentials
        storeCredentials()
    }
    
    private func completeYouTubeAuthentication(authResult: OAuthResult) async throws {
        // Fetch user profile
        let userProfile = try await fetchYouTubeUserProfile(accessToken: authResult.accessToken)
        
        // Create or update user
        let youtubeAuth = PlatformAuthentication(
            platform: .youtube,
            accessToken: authResult.accessToken,
            refreshToken: authResult.refreshToken,
            expiresAt: authResult.expiresAt,
            scopes: authResult.scopes,
            userProfile: userProfile
        )
        
        if currentUser != nil {
            currentUser?.youtubeAuth = youtubeAuth
        } else {
            currentUser = AuthenticatedUser(
                id: userProfile.id,
                primaryEmail: userProfile.email,
                displayName: userProfile.displayName,
                avatarURL: userProfile.profileImageURL,
                twitchAuth: nil,
                youtubeAuth: youtubeAuth,
                createdAt: Date(),
                lastLoginAt: Date()
            )
        }
        
        youtubeAuthStatus = .authenticated
        isAuthenticated = true
        
        // Store credentials
        storeCredentials()
    }
    
    private func fetchTwitchUserProfile(accessToken: String) async throws -> UserProfile {
        // This would use the TwitchService to fetch user profile
        // Placeholder implementation
        return UserProfile(
            id: "twitch_user_id",
            email: "user@example.com",
            displayName: "Twitch User",
            username: "twitchuser",
            profileImageURL: nil,
            platform: .twitch
        )
    }
    
    private func fetchYouTubeUserProfile(accessToken: String) async throws -> UserProfile {
        // This would use the YouTubeService to fetch user profile
        // Placeholder implementation
        return UserProfile(
            id: "youtube_user_id",
            email: "user@example.com",
            displayName: "YouTube User",
            username: "youtubeuser",
            profileImageURL: nil,
            platform: .youtube
        )
    }
    
    private func refreshTwitchToken() async throws {
        guard let twitchAuth = currentUser?.twitchAuth,
              let refreshToken = twitchAuth.refreshToken else {
            throw AuthenticationError.noRefreshToken
        }
        
        let tokens = try await refreshTokens(refreshToken: refreshToken, config: twitchConfig)
        
        // Update stored authentication
        currentUser?.twitchAuth?.accessToken = tokens.accessToken
        currentUser?.twitchAuth?.expiresAt = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
        if let newRefreshToken = tokens.refreshToken {
            currentUser?.twitchAuth?.refreshToken = newRefreshToken
        }
        
        storeCredentials()
    }
    
    private func refreshYouTubeToken() async throws {
        guard let youtubeAuth = currentUser?.youtubeAuth,
              let refreshToken = youtubeAuth.refreshToken else {
            throw AuthenticationError.noRefreshToken
        }
        
        let tokens = try await refreshTokens(refreshToken: refreshToken, config: youtubeConfig)
        
        // Update stored authentication
        currentUser?.youtubeAuth?.accessToken = tokens.accessToken
        currentUser?.youtubeAuth?.expiresAt = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
        if let newRefreshToken = tokens.refreshToken {
            currentUser?.youtubeAuth?.refreshToken = newRefreshToken
        }
        
        storeCredentials()
    }
    
    private func refreshTokens(refreshToken: String, config: OAuthConfig) async throws -> TokenResponse {
        guard let url = URL(string: config.tokenURL) else {
            throw AuthenticationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthenticationError.tokenRefreshFailed
        }
        
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    
    private func validateStoredTokens() async {
        guard let user = currentUser else { return }
        
        // Check Twitch token
        if let twitchAuth = user.twitchAuth {
            if twitchAuth.expiresAt <= Date() {
                do {
                    try await refreshTwitchToken()
                } catch {
                    twitchAuthStatus = .error(error)
                }
            }
        }
        
        // Check YouTube token
        if let youtubeAuth = user.youtubeAuth {
            if youtubeAuth.expiresAt <= Date() {
                do {
                    try await refreshYouTubeToken()
                } catch {
                    youtubeAuthStatus = .error(error)
                }
            }
        }
    }
    
    private func updateUserData() async {
        guard let user = currentUser else { return }
        
        // Update user data from platforms
        if let twitchAuth = user.twitchAuth {
            do {
                let profile = try await fetchTwitchUserProfile(accessToken: twitchAuth.accessToken)
                currentUser?.twitchAuth?.userProfile = profile
            } catch {
                print("Failed to update Twitch profile: \(error)")
            }
        }
        
        if let youtubeAuth = user.youtubeAuth {
            do {
                let profile = try await fetchYouTubeUserProfile(accessToken: youtubeAuth.accessToken)
                currentUser?.youtubeAuth?.userProfile = profile
            } catch {
                print("Failed to update YouTube profile: \(error)")
            }
        }
        
        storeCredentials()
    }
    
    private func storeCredentials() {
        guard let user = currentUser else { return }
        
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "authenticated_user")
        }
    }
    
    private func clearStoredCredentials() {
        UserDefaults.standard.removeObject(forKey: "authenticated_user")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthenticationService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Supporting Models

struct AuthenticatedUser: Codable {
    let id: String
    let primaryEmail: String
    let displayName: String
    let avatarURL: String?
    var twitchAuth: PlatformAuthentication?
    var youtubeAuth: PlatformAuthentication?
    let createdAt: Date
    var lastLoginAt: Date
}

struct PlatformAuthentication: Codable {
    let platform: AuthPlatform
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    let scopes: [String]
    var userProfile: UserProfile
}

struct UserProfile: Codable {
    let id: String
    let email: String
    let displayName: String
    let username: String
    let profileImageURL: String?
    let platform: AuthPlatform
}

enum AuthPlatform: String, Codable {
    case twitch = "twitch"
    case youtube = "youtube"
}

enum PlatformAuthStatus {
    case notAuthenticated
    case authenticating
    case authenticated
    case error(Error)
}

struct OAuthConfig {
    let clientId: String
    let clientSecret: String
    let redirectUri: String
    let scopes: [String]
    let authURL: String
    let tokenURL: String
}

struct OAuthResult {
    let platform: AuthPlatform
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scopes: [String]
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let scopes: [String]?
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scopes = "scope"
        case tokenType = "token_type"
    }
}

enum AuthenticationError: Error, LocalizedError {
    case networkError
    case invalidURL
    case invalidCallback
    case oauthError(Error)
    case tokenExchangeFailed
    case tokenRefreshFailed
    case noRefreshToken
    case userCancelled
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection required"
        case .invalidURL:
            return "Invalid authentication URL"
        case .invalidCallback:
            return "Invalid authentication callback"
        case .oauthError(let error):
            return "OAuth error: \(error.localizedDescription)"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .noRefreshToken:
            return "No refresh token available"
        case .userCancelled:
            return "Authentication was cancelled"
        case .unknown(let error):
            return "Unknown authentication error: \(error.localizedDescription)"
        }
    }
}