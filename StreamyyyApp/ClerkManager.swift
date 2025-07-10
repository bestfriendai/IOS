//
//  ClerkManager.swift
//  StreamyyyApp
//
//  Clerk iOS SDK integration for authentication
//

import Foundation
import SwiftUI
import Combine
// import ClerkSDK // Commented out until SDK is properly integrated

// Mock ClerkUser structure
struct ClerkUser {
    let id: String
    let firstName: String?
    let lastName: String?
    let imageURL: URL?
    let primaryEmailAddress: EmailAddress?
    let primaryPhoneNumber: PhoneNumber?
    
    struct EmailAddress {
        let emailAddress: String
    }
    
    struct PhoneNumber {
        let phoneNumber: String
    }
}

@MainActor
class ClerkManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: ClerkUser?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupClerk()
        observeAuthState()
    }
    
    // MARK: - Setup
    
    private func setupClerk() {
        // Real Clerk setup using production credentials
        print("✅ Setting up Clerk with publishable key: \(Config.Clerk.publishableKey.prefix(20))...")
        
        // In a real implementation, you would initialize the Clerk SDK here
        // For now, we'll use mock implementation with real credential structure
    }
    
    private func observeAuthState() {
        // Real auth state observer - would connect to Clerk SDK
        print("✅ Observing Clerk auth state...")
        
        // Check for stored session
        if let storedUserId = UserDefaults.standard.string(forKey: "clerk_user_id"),
           let storedEmail = UserDefaults.standard.string(forKey: "clerk_user_email") {
            
            // Restore user session
            user = ClerkUser(
                id: storedUserId,
                firstName: UserDefaults.standard.string(forKey: "clerk_user_first_name"),
                lastName: UserDefaults.standard.string(forKey: "clerk_user_last_name"),
                imageURL: nil,
                primaryEmailAddress: ClerkUser.EmailAddress(emailAddress: storedEmail),
                primaryPhoneNumber: nil
            )
            isAuthenticated = true
            
            // Initialize Supabase profile
            Task {
                await RealSupabaseService.shared.getUserProfile(clerkUserId: storedUserId)
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        
        // Mock authentication - replace with actual Clerk authentication
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        if email.contains("@") && password.count >= 6 {
            let userId = UUID().uuidString
            user = ClerkUser(
                id: userId,
                firstName: "Streamyyy",
                lastName: "User",
                imageURL: nil,
                primaryEmailAddress: ClerkUser.EmailAddress(emailAddress: email),
                primaryPhoneNumber: nil
            )
            isAuthenticated = true
            
            // Store session data
            UserDefaults.standard.set(userId, forKey: "clerk_user_id")
            UserDefaults.standard.set(email, forKey: "clerk_user_email")
            UserDefaults.standard.set("Streamyyy", forKey: "clerk_user_first_name")
            UserDefaults.standard.set("User", forKey: "clerk_user_last_name")
            
            // Initialize Supabase profile
            await RealSupabaseService.shared.getUserProfile(clerkUserId: userId)
        } else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        isLoading = true
        error = nil
        
        // Mock sign up - replace with actual Clerk sign up
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        if email.contains("@") && password.count >= 6 {
            let userId = UUID().uuidString
            user = ClerkUser(
                id: userId,
                firstName: firstName,
                lastName: lastName,
                imageURL: nil,
                primaryEmailAddress: ClerkUser.EmailAddress(emailAddress: email),
                primaryPhoneNumber: nil
            )
            isAuthenticated = true
            
            // Store session data
            UserDefaults.standard.set(userId, forKey: "clerk_user_id")
            UserDefaults.standard.set(email, forKey: "clerk_user_email")
            UserDefaults.standard.set(firstName, forKey: "clerk_user_first_name")
            UserDefaults.standard.set(lastName, forKey: "clerk_user_last_name")
            
            // Create Supabase profile
            await RealSupabaseService.shared.createUserProfile(
                clerkUserId: userId,
                email: email,
                displayName: "\(firstName) \(lastName)"
            )
        } else {
            throw NSError(domain: "AuthError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid input"])
        }
        
        isLoading = false
    }
    
    func signOut() async throws {
        isLoading = true
        error = nil
        
        // Mock sign out
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        user = nil
        isAuthenticated = false
        
        // Clear stored session data
        UserDefaults.standard.removeObject(forKey: "clerk_user_id")
        UserDefaults.standard.removeObject(forKey: "clerk_user_email")
        UserDefaults.standard.removeObject(forKey: "clerk_user_first_name")
        UserDefaults.standard.removeObject(forKey: "clerk_user_last_name")
        
        // Clear Supabase data
        RealSupabaseService.shared.signOut()
        
        isLoading = false
    }
    
    // MARK: - OAuth Methods
    
    func signInWithApple() async throws {
        // Mock Apple sign in
        try await signIn(email: "apple@example.com", password: "password")
    }
    
    func signInWithGoogle() async throws {
        // Mock Google sign in
        try await signIn(email: "google@example.com", password: "password")
    }
    
    func signInWithGitHub() async throws {
        // Mock GitHub sign in
        try await signIn(email: "github@example.com", password: "password")
    }
    
    // MARK: - User Management
    
    func updateUserProfile(firstName: String, lastName: String) async throws {
        guard let currentUser = user else { return }
        
        isLoading = true
        error = nil
        
        // Mock update
        try await Task.sleep(nanoseconds: 500_000_000)
        
        user = ClerkUser(
            id: currentUser.id,
            firstName: firstName,
            lastName: lastName,
            imageURL: currentUser.imageURL,
            primaryEmailAddress: currentUser.primaryEmailAddress,
            primaryPhoneNumber: currentUser.primaryPhoneNumber
        )
        
        isLoading = false
    }
    
    func deleteUser() async throws {
        guard user != nil else { return }
        
        isLoading = true
        error = nil
        
        // Mock delete
        try await Task.sleep(nanoseconds: 500_000_000)
        
        user = nil
        isAuthenticated = false
        
        isLoading = false
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        // Mock password reset
        isLoading = true
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
        print("Password reset email sent to: \(email)")
    }
    
    func verifyResetCode(code: String) async throws {
        // Mock code verification
        isLoading = true
        try await Task.sleep(nanoseconds: 500_000_000)
        if code != "123456" {
            throw NSError(domain: "AuthError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid reset code"])
        }
        isLoading = false
    }
    
    func completePasswordReset(newPassword: String) async throws {
        // Mock password reset completion
        isLoading = true
        try await Task.sleep(nanoseconds: 500_000_000)
        if newPassword.count < 6 {
            throw NSError(domain: "AuthError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Password too short"])
        }
        isLoading = false
        print("Password reset completed")
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        error = nil
    }
    
    var isGuestMode: Bool {
        return !isAuthenticated
    }
    
    var userDisplayName: String {
        guard let user = user else { return "Guest" }
        
        if let firstName = user.firstName, let lastName = user.lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = user.firstName {
            return firstName
        } else if let email = user.primaryEmailAddress?.emailAddress {
            return email
        } else {
            return "User"
        }
    }
    
    var userEmail: String? {
        return user?.primaryEmailAddress?.emailAddress
    }
    
    var userAvatarURL: URL? {
        return user?.imageURL
    }
}

// MARK: - Error Handling
extension ClerkManager {
    func handleError(_ error: Error) -> String {
        // Mock error handling
        let nsError = error as NSError
        switch nsError.code {
        case 401:
            return "Invalid email or password. Please try again."
        case 404:
            return "No account found with this email address."
        case 400:
            return "Invalid input. Please check your information."
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - SwiftUI Environment
extension ClerkManager {
    static let shared = ClerkManager()
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