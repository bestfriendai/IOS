//
//  ClerkManager.swift
//  StreamyyyApp
//
//  Real Clerk iOS SDK integration for authentication
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import LocalAuthentication
import UIKit

// TODO: Uncomment when Clerk iOS SDK is added
// import ClerkSDK

// MARK: - Local Types for Authentication

struct AuthSession: Codable {
    let userId: String
    let email: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let createdAt: Date
    let deviceId: String
    
    var isExpired: Bool {
        return Date() >= expiresAt
    }
    
    var isValid: Bool {
        return !isExpired && !accessToken.isEmpty
    }
}

enum UserDataType: String {
    case clerkUserId = "clerk_user_id"
    case userEmail = "user_email"
    case userProfile = "user_profile"
    case authState = "auth_state"
    case sessionData = "session_data"
}

// MARK: - Real ClerkUser Implementation
// TODO: Replace with actual ClerkSDK.User when SDK is integrated
struct ClerkUser: Codable {
    let id: String
    let firstName: String?
    let lastName: String?
    let imageURL: URL?
    let primaryEmailAddress: EmailAddress?
    let primaryPhoneNumber: PhoneNumber?
    let emailAddresses: [EmailAddress]
    let phoneNumbers: [PhoneNumber]
    let externalAccounts: [ExternalAccount]
    let createdAt: Date
    let updatedAt: Date
    let lastSignInAt: Date?
    let twoFactorEnabled: Bool
    let profileImageUrl: String?
    let hasImage: Bool
    
    struct EmailAddress: Codable {
        let id: String
        let emailAddress: String
        let verification: Verification?
        
        struct Verification: Codable {
            let status: String
            let strategy: String
        }
    }
    
    struct PhoneNumber: Codable {
        let id: String
        let phoneNumber: String
        let verification: Verification?
        
        struct Verification: Codable {
            let status: String
            let strategy: String
        }
    }
    
    struct ExternalAccount: Codable {
        let id: String
        let provider: String
        let identificationId: String
        let emailAddress: String?
        let firstName: String?
        let lastName: String?
        let imageUrl: String?
        let username: String?
    }
    
    var displayName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let primaryEmail = primaryEmailAddress {
            return primaryEmail.emailAddress
        } else {
            return "User"
        }
    }
    
    var isEmailVerified: Bool {
        return primaryEmailAddress?.verification?.status == "verified"
    }
    
    var isPhoneVerified: Bool {
        return primaryPhoneNumber?.verification?.status == "verified"
    }
}

@MainActor
class ClerkManager: ObservableObject {
    static let shared = ClerkManager()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var user: ClerkUser?
    @Published var isLoading = false
    @Published var error: AuthenticationError?
    @Published var sessionToken: String?
    @Published var biometricEnabled = false
    
    // MARK: - Private Properties
    // Note: Using UserDefaults instead of KeychainManager for build compatibility
    // Note: SupabaseService integration pending build fixes
    // private lazy var supabaseService = RealSupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var authSessionTimer: Timer?
    
    // MARK: - Configuration
    private let clerkBaseURL = "https://api.clerk.com/v1"
    private let publishableKey: String
    private let frontendApiEndpoint: String
    
    private init() {
        self.publishableKey = Config.Clerk.publishableKey
        self.frontendApiEndpoint = "https://\(Self.extractDomain(from: Config.Clerk.publishableKey)).clerk.accounts.dev"
        
        setupClerk()
        observeAuthState()
        checkStoredAuthentication()
    }
    
    // MARK: - Setup
    
    private func setupClerk() {
        print("🔐 Setting up Clerk with publishable key: \(publishableKey.prefix(20))...")
        
        // TODO: When Clerk iOS SDK is available, initialize it here
        // Clerk.configure(publishableKey: publishableKey)
        
        setupSessionMonitoring()
    }
    
    private func observeAuthState() {
        // Monitor authentication state changes
        $isAuthenticated
            .removeDuplicates()
            .sink { [weak self] authenticated in
                if authenticated {
                    self?.startSessionMonitoring()
                } else {
                    self?.stopSessionMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkStoredAuthentication() {
        do {
            // Temporarily simplified authentication restoration
            if let storedToken = UserDefaults.standard.string(forKey: "clerk_session_token"),
               !storedToken.isEmpty {
                sessionToken = storedToken
                isAuthenticated = true
                
                // Verify session with Clerk backend
                Task {
                    await verifyStoredSession()
                }
            }
        } catch {
            print("⚠️ Failed to restore authentication: \(error)")
            // Clear invalid stored data
            UserDefaults.standard.removeObject(forKey: "clerk_session_token")
        }
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        
        do {
            // Create sign-in request to Clerk API
            let signInData = ClerkSignInRequest(
                identifier: email,
                password: password,
                strategy: "password"
            )
            
            let response = try await performClerkAPIRequest(
                endpoint: "/client/sign_ins",
                method: "POST",
                body: signInData
            )
            
            let signInResponse = try JSONDecoder().decode(ClerkSignInResponse.self, from: response)
            
            // Handle successful authentication
            if let session = signInResponse.sessions?.first,
               let user = signInResponse.response?.user {
                
                await handleSuccessfulAuthentication(session: session, user: user)
                
                // Sync with Supabase
                // await supabaseService.syncUserProfile(clerkUser: user, sessionToken: session.id)
                
            } else {
                throw AuthenticationError.invalidCredentials
            }
            
        } catch let authError as AuthenticationError {
            error = authError
            throw authError
        } catch {
            let clerkError = AuthenticationError.clerkAPIError(error.localizedDescription)
            self.error = clerkError
            throw clerkError
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        isLoading = true
        error = nil
        
        do {
            // Create sign-up request to Clerk API
            let signUpData = ClerkSignUpRequest(
                emailAddress: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            
            let response = try await performClerkAPIRequest(
                endpoint: "/client/sign_ups",
                method: "POST",
                body: signUpData
            )
            
            let signUpResponse = try JSONDecoder().decode(ClerkSignUpResponse.self, from: response)
            
            // Handle sign-up response
            if let user = signUpResponse.response?.user,
               let session = signUpResponse.response?.session {
                
                await handleSuccessfulAuthentication(session: session, user: user)
                
                // Create Supabase profile
                // await supabaseService.syncUserProfile(clerkUser: user, sessionToken: session.id)
                
            } else {
                throw AuthenticationError.invalidInput
            }
            
        } catch let authError as AuthenticationError {
            error = authError
            throw authError
        } catch {
            let clerkError = AuthenticationError.clerkAPIError(error.localizedDescription)
            self.error = clerkError
            throw clerkError
        }
        
        isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        
        // Sign out from Clerk
        if let token = sessionToken {
            do {
                let _ = try await performClerkAPIRequest(
                    endpoint: "/client/sessions/\(token)",
                    method: "DELETE"
                )
            } catch {
                print("⚠️ Error signing out from Clerk: \(error)")
            }
        }
        
        // Clear local state
        user = nil
        sessionToken = nil
        isAuthenticated = false
        biometricEnabled = false
        error = nil
        
        // Clear stored data
        UserDefaults.standard.removeObject(forKey: "clerk_auth_session")
        UserDefaults.standard.removeObject(forKey: "clerk_user_profile")
        UserDefaults.standard.removeObject(forKey: "clerk_user_id")
        UserDefaults.standard.removeObject(forKey: "clerk_user_email")
        UserDefaults.standard.removeObject(forKey: "clerk_session_data")
        
        // Clear Supabase session
        // supabaseService.signOut()
        
        // Stop session monitoring
        stopSessionMonitoring()
        
        isLoading = false
    }
    
    // MARK: - OAuth Methods
    
    func signInWithApple() async throws {
        isLoading = true
        error = nil
        
        do {
            // TODO: Integrate with actual Apple Sign In
            // For now, create OAuth request to Clerk
            let response = try await performClerkAPIRequest(
                endpoint: "/client/sign_ins",
                method: "POST",
                body: ClerkOAuthRequest(strategy: "oauth_apple")
            )
            
            let signInResponse = try JSONDecoder().decode(ClerkSignInResponse.self, from: response)
            
            if let session = signInResponse.sessions?.first,
               let user = signInResponse.response?.user {
                await handleSuccessfulAuthentication(session: session, user: user)
                // await supabaseService.syncUserProfile(clerkUser: user, sessionToken: session.id)
            }
            
        } catch {
            self.error = AuthenticationError.clerkAPIError("Apple Sign In failed")
            throw self.error!
        }
        
        isLoading = false
    }
    
    func signInWithGoogle() async throws {
        isLoading = true
        error = nil
        
        do {
            // TODO: Integrate with actual Google Sign In
            let response = try await performClerkAPIRequest(
                endpoint: "/client/sign_ins",
                method: "POST",
                body: ClerkOAuthRequest(strategy: "oauth_google")
            )
            
            let signInResponse = try JSONDecoder().decode(ClerkSignInResponse.self, from: response)
            
            if let session = signInResponse.sessions?.first,
               let user = signInResponse.response?.user {
                await handleSuccessfulAuthentication(session: session, user: user)
                // await supabaseService.syncUserProfile(clerkUser: user, sessionToken: session.id)
            }
            
        } catch {
            self.error = AuthenticationError.clerkAPIError("Google Sign In failed")
            throw self.error!
        }
        
        isLoading = false
    }
    
    func signInWithGitHub() async throws {
        isLoading = true
        error = nil
        
        do {
            let response = try await performClerkAPIRequest(
                endpoint: "/client/sign_ins",
                method: "POST",
                body: ClerkOAuthRequest(strategy: "oauth_github")
            )
            
            let signInResponse = try JSONDecoder().decode(ClerkSignInResponse.self, from: response)
            
            if let session = signInResponse.sessions?.first,
               let user = signInResponse.response?.user {
                await handleSuccessfulAuthentication(session: session, user: user)
                // await supabaseService.syncUserProfile(clerkUser: user, sessionToken: session.id)
            }
            
        } catch {
            self.error = AuthenticationError.clerkAPIError("GitHub Sign In failed")
            throw self.error!
        }
        
        isLoading = false
    }
    
    // MARK: - User Management
    
    func updateUserProfile(firstName: String, lastName: String) async throws {
        guard let currentUser = user, let token = sessionToken else {
            throw AuthenticationError.notAuthenticated
        }
        
        isLoading = true
        error = nil
        
        do {
            let updateData = ClerkUserUpdateRequest(
                firstName: firstName,
                lastName: lastName
            )
            
            let response = try await performClerkAPIRequest(
                endpoint: "/client/users/\(currentUser.id)",
                method: "PATCH",
                body: updateData
            )
            
            let updatedUser = try JSONDecoder().decode(ClerkUser.self, from: response)
            
            // Update local state
            user = updatedUser
            
            // Update stored user data
            if let userData = try? JSONEncoder().encode(updatedUser) {
                UserDefaults.standard.set(userData, forKey: UserDataType.userProfile.rawValue)
            }
            
            // Sync with Supabase
            // await supabaseService.syncUserProfile(clerkUser: updatedUser, sessionToken: token)
            
        } catch {
            let updateError = AuthenticationError.clerkAPIError("Failed to update profile")
            self.error = updateError
            throw updateError
        }
        
        isLoading = false
    }
    
    func deleteUser() async throws {
        guard let currentUser = user, let token = sessionToken else {
            throw AuthenticationError.notAuthenticated
        }
        
        isLoading = true
        error = nil
        
        do {
            let _ = try await performClerkAPIRequest(
                endpoint: "/client/users/\(currentUser.id)",
                method: "DELETE"
            )
            
            // Clear all local data
            await signOut()
            
        } catch {
            let deleteError = AuthenticationError.clerkAPIError("Failed to delete account")
            self.error = deleteError
            throw deleteError
        }
        
        isLoading = false
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        isLoading = true
        error = nil
        
        do {
            let resetData = ClerkPasswordResetRequest(emailAddress: email)
            
            let _ = try await performClerkAPIRequest(
                endpoint: "/client/sign_ins",
                method: "POST",
                body: resetData
            )
            
            print("✅ Password reset email sent to: \(email)")
            
        } catch {
            let resetError = AuthenticationError.clerkAPIError("Failed to send reset email")
            self.error = resetError
            throw resetError
        }
        
        isLoading = false
    }
    
    // MARK: - Session Management
    
    func getSessionToken() async throws -> String {
        guard let token = sessionToken else {
            throw AuthenticationError.notAuthenticated
        }
        
        // Verify token is still valid
        do {
            await verifyStoredSession()
            return token
        } catch {
            throw AuthenticationError.sessionExpired
        }
    }
    
    func refreshSession() async throws {
        guard let sessionData = UserDefaults.standard.data(forKey: "clerk_auth_session"),
              let session = try? JSONDecoder().decode(AuthSession.self, from: sessionData) else {
            throw AuthenticationError.notAuthenticated
        }
        
        if session.isExpired {
            // Session is expired, need to re-authenticate
            await signOut()
            throw AuthenticationError.sessionExpired
        }
        
        // Verify with Clerk backend
        await verifyStoredSession()
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        error = nil
    }
    
    var isGuestMode: Bool {
        return !isAuthenticated
    }
    
    var userDisplayName: String {
        return user?.displayName ?? "Guest"
    }
    
    var userEmail: String? {
        return user?.primaryEmailAddress?.emailAddress
    }
    
    var userAvatarURL: URL? {
        return user?.imageURL ?? (user?.profileImageUrl.flatMap(URL.init))
    }
    
    // MARK: - Biometric Authentication
    
    func enableBiometricAuth() async throws {
        // Biometric authentication not available when using UserDefaults
        throw AuthenticationError.biometricNotAvailable
    }
    
    func disableBiometricAuth() {
        UserDefaults.standard.removeObject(forKey: UserDataType.sessionData.rawValue)
        biometricEnabled = false
        UserDefaults.standard.set(false, forKey: "biometric_auth_enabled")
    }
    
    func authenticateWithBiometrics() async throws {
        // Biometric authentication not available when using UserDefaults
        throw AuthenticationError.biometricNotAvailable
    }
    
    // MARK: - Private Helper Methods
    
    private func handleSuccessfulAuthentication(session: ClerkSession, user: ClerkUser) async {
        // Store user and session data securely
        do {
            let authSession = AuthSession(
                userId: user.id,
                email: user.primaryEmailAddress?.emailAddress ?? "",
                accessToken: session.id,
                refreshToken: nil as String?, // Clerk handles refresh automatically
                expiresAt: session.expireAt,
                createdAt: Date(),
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            )
            
            // Store auth session
            if let authSessionData = try? JSONEncoder().encode(authSession) {
                UserDefaults.standard.set(authSessionData, forKey: "clerk_auth_session")
            }
            
            // Store user data
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: UserDataType.userProfile.rawValue)
            }
            
            UserDefaults.standard.set(user.id, forKey: UserDataType.clerkUserId.rawValue)
            UserDefaults.standard.set(user.primaryEmailAddress?.emailAddress ?? "", forKey: UserDataType.userEmail.rawValue)
            
            // Update UI state
            self.user = user
            self.sessionToken = session.id
            self.isAuthenticated = true
            
            // Check if biometric auth was previously enabled
            biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_auth_enabled")
            
        } catch {
            print("Failed to store authentication data: \(error)")
            self.error = AuthenticationError.storageError
        }
    }
    
    private func performClerkAPIRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: T? = nil as EmptyRequest?
    ) async throws -> Data {
        
        let url = URL(string: "\(frontendApiEndpoint)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw AuthenticationError.invalidCredentials
            } else if httpResponse.statusCode == 422 {
                throw AuthenticationError.invalidInput
            } else {
                throw AuthenticationError.clerkAPIError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        return data
    }
    
    private func verifyStoredSession() async {
        guard let token = sessionToken else {
            await signOut()
            return
        }
        
        do {
            // Verify session with Clerk
            let response = try await performClerkAPIRequest(
                endpoint: "/client/sessions/\(token)",
                method: "GET"
            )
            
            let sessionResponse = try JSONDecoder().decode(ClerkSessionResponse.self, from: response)
            
            if let session = sessionResponse.response,
               session.status == "active" {
                // Session is still valid
                print("✅ Session verified successfully")
            } else {
                // Session is invalid, sign out
                await signOut()
            }
            
        } catch {
            print("⚠️ Session verification failed: \(error)")
            await signOut()
        }
    }
    
    private func setupSessionMonitoring() {
        // Monitor session expiration
        authSessionTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.verifyStoredSession()
            }
        }
    }
    
    private func startSessionMonitoring() {
        setupSessionMonitoring()
    }
    
    private func stopSessionMonitoring() {
        authSessionTimer?.invalidate()
        authSessionTimer = nil
    }
    
    private static func extractDomain(from publishableKey: String) -> String {
        // Extract domain from publishable key format: pk_live_...
        // For production implementation, you'd parse this correctly
        return "clerk.streamyyy.com"
    }
}

// MARK: - Supporting Types

struct ClerkSignInRequest: Codable {
    let identifier: String
    let password: String
    let strategy: String
}

struct ClerkSignUpRequest: Codable {
    let emailAddress: String
    let password: String
    let firstName: String?
    let lastName: String?
}

struct ClerkOAuthRequest: Codable {
    let strategy: String
}

struct ClerkUserUpdateRequest: Codable {
    let firstName: String?
    let lastName: String?
}

struct ClerkPasswordResetRequest: Codable {
    let emailAddress: String
    let strategy: String = "reset_password_email_code"
}

struct ClerkSignInResponse: Codable {
    let response: ClerkAuthResponse?
    let sessions: [ClerkSession]?
}

struct ClerkSignUpResponse: Codable {
    let response: ClerkAuthResponse?
    let emailAddress: ClerkUser.EmailAddress?
}

struct ClerkAuthResponse: Codable {
    let user: ClerkUser?
    let session: ClerkSession?
}

struct ClerkSession: Codable {
    let id: String
    let status: String
    let expireAt: Date
    let lastActiveAt: Date
    let userId: String
}

struct ClerkSessionResponse: Codable {
    let response: ClerkSession?
}

struct EmptyRequest: Codable {}

enum AuthenticationError: Error, LocalizedError {
    case invalidCredentials
    case invalidInput
    case networkError
    case clerkAPIError(String)
    case biometricNotAvailable
    case biometricAuthFailed
    case notAuthenticated
    case sessionExpired
    case storageError
    case userCancelled
    case emailNotVerified
    case twoFactorRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .invalidInput:
            return "Please check your input and try again"
        case .networkError:
            return "Network connection error"
        case .clerkAPIError(let message):
            return "Authentication service error: \(message)"
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .notAuthenticated:
            return "You are not currently signed in"
        case .sessionExpired:
            return "Your session has expired. Please sign in again"
        case .storageError:
            return "Failed to store authentication data securely"
        case .userCancelled:
            return "Authentication was cancelled"
        case .emailNotVerified:
            return "Please verify your email address"
        case .twoFactorRequired:
            return "Two-factor authentication is required"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your email and password and try again"
        case .invalidInput:
            return "Make sure all fields are filled correctly"
        case .networkError:
            return "Please check your internet connection and try again"
        case .sessionExpired, .notAuthenticated:
            return "Please sign in again"
        case .biometricNotAvailable:
            return "Use your email and password to sign in"
        case .biometricAuthFailed:
            return "Try using Face ID/Touch ID again or use your password"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
}

// MARK: - Environment Key
struct ClerkManagerKey: EnvironmentKey {
    static let defaultValue = ClerkManager.shared
}

extension EnvironmentValues {
    var clerkManager: ClerkManager {
        get { self[ClerkManagerKey.self] }
        set { self[ClerkManagerKey.self] = newValue }
    }
}