//
//  TwitchOAuthManager.swift
//  StreamyyyApp
//
//  Manages Twitch OAuth flow for iOS
//

import SwiftUI
import AuthenticationServices

@MainActor
class TwitchOAuthManager: NSObject, ObservableObject {
    static let shared = TwitchOAuthManager()
    
    @Published var isShowingAuthSession = false
    @Published var authenticationError: Error?
    
    private var authSession: ASWebAuthenticationSession?
    
    override init() {
        super.init()
    }
    
    // MARK: - OAuth Flow
    func startTwitchLogin() {
        guard let authURL = RealTwitchAPIService.shared.startOAuthFlow() else {
            authenticationError = TwitchOAuthError.invalidAuthURL
            return
        }
        
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "streamyyy"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        // User cancelled - not an error
                        return
                    }
                    self?.authenticationError = error
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    self?.authenticationError = TwitchOAuthError.noCallbackURL
                    return
                }
                
                await RealTwitchAPIService.shared.handleOAuthCallback(url: callbackURL)
            }
        }
        
        // Configure the session
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        
        // Start the authentication session
        isShowingAuthSession = true
        authSession?.start()
    }
    
    func signOut() {
        RealTwitchAPIService.shared.signOut()
        authSession?.cancel()
        authSession = nil
    }
    
    func clearError() {
        authenticationError = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension TwitchOAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Twitch OAuth Errors
enum TwitchOAuthError: LocalizedError {
    case invalidAuthURL
    case noCallbackURL
    case authenticationFailed
    case tokenExchangeFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidAuthURL:
            return "Invalid authentication URL"
        case .noCallbackURL:
            return "No callback URL received"
        case .authenticationFailed:
            return "Authentication failed"
        case .tokenExchangeFailed:
            return "Failed to exchange code for token"
        }
    }
}

// MARK: - SwiftUI Integration
struct TwitchLoginButton: View {
    @StateObject private var oauthManager = TwitchOAuthManager.shared
    @ObservedObject private var twitchService = RealTwitchAPIService.shared
    
    var body: some View {
        Button(action: {
            if twitchService.isAuthenticated {
                oauthManager.signOut()
            } else {
                oauthManager.startTwitchLogin()
            }
        }) {
            HStack {
                Image(systemName: twitchService.isAuthenticated ? "person.crop.circle.fill" : "tv.fill")
                Text(twitchService.isAuthenticated ? "Sign Out of Twitch" : "Connect with Twitch")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(twitchService.isAuthenticated ? Color.red : Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .alert("Authentication Error", isPresented: .constant(oauthManager.authenticationError != nil)) {
            Button("OK") {
                oauthManager.clearError()
            }
        } message: {
            Text(oauthManager.authenticationError?.localizedDescription ?? "Unknown error")
        }
    }
}

// MARK: - Twitch User Profile View
struct TwitchUserProfileView: View {
    @ObservedObject private var twitchService = RealTwitchAPIService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            if twitchService.isAuthenticated, let user = twitchService.currentUser {
                AsyncImage(url: URL(string: user.profileImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                
                VStack(spacing: 8) {
                    Text(user.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("@\(user.login)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !user.description.isEmpty {
                        Text(user.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    
                    HStack {
                        Label("\(user.viewCount)", systemImage: "eye")
                        Spacer()
                        Label("Twitch", systemImage: "tv")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tv.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Not Connected to Twitch")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Connect your Twitch account to access personalized features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
}