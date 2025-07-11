//
//  AuthenticationService.swift
//  StreamyyyApp
//
//  Updated authentication service that integrates with ClerkManager
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
    @Published var currentUser: UserProfile?
    @Published var authenticationError: AuthenticationError?
    @Published var isLoading = false
    @Published var lastError: Error?
    
    // Platform-specific authentication status
    @Published var twitchAuthStatus: PlatformAuthStatus = .notAuthenticated
    @Published var youtubeAuthStatus: PlatformAuthStatus = .notAuthenticated
    
    // MARK: - Private Properties
    private let clerkManager = ClerkManager.shared
    private let supabaseService = SupabaseService.shared
    private let twitchService = TwitchService.shared
    private let youtubeService = YouTubeService()
    private let networkManager = NetworkManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var currentAuthSession: ASWebAuthenticationSession?
    
    // OAuth Configuration for platforms
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
        setupAuthenticationObservers()
    }
    
    // MARK: - Setup and Observers
    
    private func setupAuthenticationObservers() {
        // Observe ClerkManager authentication state
        clerkManager.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        clerkManager.$isLoading
            .assign(to: &$isLoading)
        
        clerkManager.$error
            .assign(to: &$authenticationError)
        
        // Observe Supabase profile changes
        supabaseService.$currentProfile
            .assign(to: &$currentUser)
        
        // Monitor network connectivity
        networkManager.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.lastError = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network connection lost"])
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Authentication Methods (delegate to ClerkManager)
    
    func signIn(email: String, password: String) async throws {
        try await clerkManager.signIn(email: email, password: password)
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        try await clerkManager.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
    }
    
    func signOut() async {
        await clerkManager.signOut()
        
        // Clear platform authentications
        twitchAuthStatus = .notAuthenticated
        youtubeAuthStatus = .notAuthenticated
        
        // Clear platform tokens
        try? KeychainManager.shared.deleteToken(type: .twitchAccessToken)
        try? KeychainManager.shared.deleteToken(type: .twitchRefreshToken)
        try? KeychainManager.shared.deleteToken(type: .youtubeAccessToken)
        try? KeychainManager.shared.deleteToken(type: .youtubeRefreshToken)
        
        // Clear service authentications
        twitchService.logout()
    }
    
    func refreshAuthentication() async {
        do {
            try await clerkManager.refreshSession()
        } catch {
            lastError = error
        }
    }
    
    // MARK: - OAuth Authentication (Apple, Google, GitHub)
    
    func signInWithApple() async throws {
        try await clerkManager.signInWithApple()
    }
    
    func signInWithGoogle() async throws {
        try await clerkManager.signInWithGoogle()
    }
    
    func signInWithGitHub() async throws {
        try await clerkManager.signInWithGitHub()
    }
    
    // MARK: - Platform OAuth (Twitch, YouTube)
    
    func authenticateWithTwitch() async throws {
        guard networkManager.isConnected else {
            throw AuthenticationError.networkError
        }
        
        guard isAuthenticated else {
            throw AuthenticationError.notAuthenticated
        }
        
        twitchAuthStatus = .authenticating
        
        do {
            let authResult = try await performOAuthFlow(config: twitchConfig, platform: .twitch)
            try await completeTwitchAuthentication(authResult: authResult)
        } catch {
            twitchAuthStatus = .error(error)
            throw error
        }
    }
    
    func authenticateWithYouTube() async throws {
        guard networkManager.isConnected else {
            throw AuthenticationError.networkError
        }
        
        guard isAuthenticated else {
            throw AuthenticationError.notAuthenticated
        }
        
        youtubeAuthStatus = .authenticating
        
        do {
            let authResult = try await performOAuthFlow(config: youtubeConfig, platform: .youtube)
            try await completeYouTubeAuthentication(authResult: authResult)
        } catch {
            youtubeAuthStatus = .error(error)
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func checkStoredPlatformTokens() {
        // Check for stored platform tokens
        let keychainManager = KeychainManager.shared
        
        // Check Twitch tokens
        if keychainManager.isTokenStored(type: .twitchAccessToken) {
            twitchAuthStatus = .authenticated
        }
        
        // Check YouTube tokens
        if keychainManager.isTokenStored(type: .youtubeAccessToken) {
            youtubeAuthStatus = .authenticated
        }
        
        // Validate tokens if needed
        Task {
            await validateStoredTokens()
        }
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
        let keychainManager = KeychainManager.shared
        
        do {
            // Store tokens securely
            try keychainManager.storeToken(authResult.accessToken, type: .twitchAccessToken)
            if let refreshToken = authResult.refreshToken {
                try keychainManager.storeToken(refreshToken, type: .twitchRefreshToken)
            }
            
            // Fetch and store user profile
            let userProfile = try await fetchTwitchUserProfile(accessToken: authResult.accessToken)
            let platformAuth = PlatformAuthentication(
                platform: .twitch,
                accessToken: authResult.accessToken,
                refreshToken: authResult.refreshToken,
                expiresAt: authResult.expiresAt,
                scopes: authResult.scopes,
                userProfile: userProfile
            )
            
            try keychainManager.storeUserData(platformAuth, type: .authState)
            
            // Configure TwitchService with new token
            twitchService.configure(with: authResult.accessToken)
            
            twitchAuthStatus = .authenticated
            print("✅ Twitch authentication completed successfully")
            
        } catch {
            print("❌ Failed to complete Twitch authentication: \(error)")
            throw AuthenticationError.storageError
        }
    }
    
    private func completeYouTubeAuthentication(authResult: OAuthResult) async throws {
        let keychainManager = KeychainManager.shared
        
        do {
            // Store tokens securely
            try keychainManager.storeToken(authResult.accessToken, type: .youtubeAccessToken)
            if let refreshToken = authResult.refreshToken {
                try keychainManager.storeToken(refreshToken, type: .youtubeRefreshToken)
            }
            
            // Fetch and store user profile
            let userProfile = try await fetchYouTubeUserProfile(accessToken: authResult.accessToken)
            let platformAuth = PlatformAuthentication(
                platform: .youtube,
                accessToken: authResult.accessToken,
                refreshToken: authResult.refreshToken,
                expiresAt: authResult.expiresAt,
                scopes: authResult.scopes,
                userProfile: userProfile
            )
            
            try keychainManager.storeUserData(platformAuth, type: .authState)
            
            youtubeAuthStatus = .authenticated
            print("✅ YouTube authentication completed successfully")
            
        } catch {
            print("❌ Failed to complete YouTube authentication: \(error)")
            throw AuthenticationError.storageError
        }
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
        let keychainManager = KeychainManager.shared
        
        guard let refreshToken = try keychainManager.retrieveToken(type: .twitchRefreshToken) else {
            throw AuthenticationError.noRefreshToken
        }
        
        let tokens = try await refreshTokens(refreshToken: refreshToken, config: twitchConfig)
        
        // Update stored tokens
        try keychainManager.storeToken(tokens.accessToken, type: .twitchAccessToken)
        if let newRefreshToken = tokens.refreshToken {
            try keychainManager.storeToken(newRefreshToken, type: .twitchRefreshToken)
        }
        
        // Update TwitchService
        twitchService.configure(with: tokens.accessToken)
        
        print("✅ Twitch token refreshed successfully")
    }
    
    private func refreshYouTubeToken() async throws {
        let keychainManager = KeychainManager.shared
        
        guard let refreshToken = try keychainManager.retrieveToken(type: .youtubeRefreshToken) else {
            throw AuthenticationError.noRefreshToken
        }
        
        let tokens = try await refreshTokens(refreshToken: refreshToken, config: youtubeConfig)
        
        // Update stored tokens
        try keychainManager.storeToken(tokens.accessToken, type: .youtubeAccessToken)
        if let newRefreshToken = tokens.refreshToken {
            try keychainManager.storeToken(newRefreshToken, type: .youtubeRefreshToken)
        }
        
        print("✅ YouTube token refreshed successfully")
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
        let keychainManager = KeychainManager.shared
        
        // Check Twitch token
        if keychainManager.isTokenStored(type: .twitchAccessToken) {
            do {
                if let platformAuth = try keychainManager.retrieveUserData(type: .authState, as: PlatformAuthentication.self),
                   platformAuth.platform == .twitch,
                   platformAuth.expiresAt <= Date() {
                    // Token is expired, try to refresh
                    try await refreshTwitchToken()
                } else {
                    twitchAuthStatus = .authenticated
                }
            } catch {
                print("⚠️ Twitch token validation failed: \(error)")
                twitchAuthStatus = .error(error)
                // Clear invalid token
                try? keychainManager.deleteToken(type: .twitchAccessToken)
                try? keychainManager.deleteToken(type: .twitchRefreshToken)
            }
        }
        
        // Check YouTube token
        if keychainManager.isTokenStored(type: .youtubeAccessToken) {
            do {
                if let platformAuth = try keychainManager.retrieveUserData(type: .authState, as: PlatformAuthentication.self),
                   platformAuth.platform == .youtube,
                   platformAuth.expiresAt <= Date() {
                    // Token is expired, try to refresh
                    try await refreshYouTubeToken()
                } else {
                    youtubeAuthStatus = .authenticated
                }
            } catch {
                print("⚠️ YouTube token validation failed: \(error)")
                youtubeAuthStatus = .error(error)
                // Clear invalid token
                try? keychainManager.deleteToken(type: .youtubeAccessToken)
                try? keychainManager.deleteToken(type: .youtubeRefreshToken)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        authenticationError = nil
        lastError = nil
    }
    
    func getTwitchAccessToken() throws -> String? {
        return try KeychainManager.shared.retrieveToken(type: .twitchAccessToken)
    }
    
    func getYouTubeAccessToken() throws -> String? {
        return try KeychainManager.shared.retrieveToken(type: .youtubeAccessToken)
    }
    
    func isPlatformConnected(_ platform: AuthPlatform) -> Bool {
        switch platform {
        case .twitch:
            return twitchAuthStatus == .authenticated
        case .youtube:
            return youtubeAuthStatus == .authenticated
        }
    }
    
    func disconnectPlatform(_ platform: AuthPlatform) async {
        let keychainManager = KeychainManager.shared
        
        switch platform {
        case .twitch:
            try? keychainManager.deleteToken(type: .twitchAccessToken)
            try? keychainManager.deleteToken(type: .twitchRefreshToken)
            twitchAuthStatus = .notAuthenticated
            twitchService.logout()
            print("✅ Twitch disconnected")
            
        case .youtube:
            try? keychainManager.deleteToken(type: .youtubeAccessToken)
            try? keychainManager.deleteToken(type: .youtubeRefreshToken)
            youtubeAuthStatus = .notAuthenticated
            print("✅ YouTube disconnected")
        }
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

enum PlatformAuthStatus: Equatable {
    case notAuthenticated
    case authenticating
    case authenticated
    case error(Error)
    
    static func == (lhs: PlatformAuthStatus, rhs: PlatformAuthStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated),
             (.authenticating, .authenticating),
             (.authenticated, .authenticated):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
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