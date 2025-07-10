//
//  ProfileManager.swift
//  StreamyyyApp
//
//  Comprehensive user profile management service
//

import Foundation
import SwiftUI
import Combine
import SwiftData
// import ClerkSDK // Commented out until SDK is properly integrated

@MainActor
class ProfileManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var userStats: UserStats?
    @Published var lastSyncDate: Date?
    
    private var cancellables = Set<AnyCancellable>()
    private let clerkManager: ClerkManager
    private let modelContext: ModelContext
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    init(clerkManager: ClerkManager, modelContext: ModelContext) {
        self.clerkManager = clerkManager
        self.modelContext = modelContext
        
        setupAuthenticationObserver()
        loadCachedProfile()
    }
    
    // MARK: - Authentication Observer
    
    private func setupAuthenticationObserver() {
        clerkManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.loadUserProfile()
                } else {
                    self?.clearUserProfile()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Profile Loading
    
    func loadUserProfile() {
        guard clerkManager.isAuthenticated,
              let clerkUser = clerkManager.user else {
            return
        }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                // First, try to load from local database
                if let existingUser = try await fetchUserFromDatabase(clerkId: clerkUser.id) {
                    currentUser = existingUser
                    currentUser?.updateFromClerk(clerkUser)
                    try await saveUserToDatabase(currentUser!)
                } else {
                    // Create new user from Clerk data
                    let newUser = createUserFromClerk(clerkUser)
                    currentUser = newUser
                    try await saveUserToDatabase(newUser)
                }
                
                // Load user statistics
                await loadUserStats()
                
                // Cache profile data
                cacheProfile()
                
                lastSyncDate = Date()
                isLoading = false
                
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    private func fetchUserFromDatabase(clerkId: String) async throws -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.clerkId == clerkId }
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    private func saveUserToDatabase(_ user: User) async throws {
        modelContext.insert(user)
        try modelContext.save()
    }
    
    private func createUserFromClerk(_ clerkUser: ClerkUser) -> User {
        let user = User(
            clerkId: clerkUser.id,
            email: clerkUser.primaryEmailAddress?.emailAddress ?? "",
            firstName: clerkUser.firstName,
            lastName: clerkUser.lastName,
            profileImageURL: clerkUser.imageURL,
            phoneNumber: clerkUser.primaryPhoneNumber?.phoneNumber
        )
        
        user.updateFromClerk(clerkUser)
        return user
    }
    
    // MARK: - Profile Caching
    
    private func cacheProfile() {
        guard let user = currentUser else { return }
        
        do {
            let userData = try JSONEncoder().encode(user)
            userDefaults.set(userData, forKey: "cached_user_profile")
            userDefaults.set(Date(), forKey: "profile_cache_date")
        } catch {
            print("Failed to cache profile: \(error)")
        }
    }
    
    private func loadCachedProfile() {
        guard let userData = userDefaults.data(forKey: "cached_user_profile"),
              let cacheDate = userDefaults.object(forKey: "profile_cache_date") as? Date else {
            return
        }
        
        // Only use cached data if it's less than 24 hours old
        if Date().timeIntervalSince(cacheDate) < 86400 {
            do {
                currentUser = try JSONDecoder().decode(User.self, from: userData)
                lastSyncDate = cacheDate
            } catch {
                print("Failed to load cached profile: \(error)")
            }
        }
    }
    
    private func clearUserProfile() {
        currentUser = nil
        userStats = nil
        lastSyncDate = nil
        
        // Clear cached data
        userDefaults.removeObject(forKey: "cached_user_profile")
        userDefaults.removeObject(forKey: "profile_cache_date")
        userDefaults.removeObject(forKey: "cached_user_stats")
    }
    
    // MARK: - User Statistics
    
    private func loadUserStats() async {
        guard let user = currentUser else { return }
        
        do {
            // Load streams data
            let streamsDescriptor = FetchDescriptor<Stream>(
                predicate: #Predicate<Stream> { $0.owner?.id == user.id }
            )
            let userStreams = try modelContext.fetch(streamsDescriptor)
            
            // Load favorites data
            let favoritesDescriptor = FetchDescriptor<Favorite>(
                predicate: #Predicate<Favorite> { $0.user?.id == user.id }
            )
            let userFavorites = try modelContext.fetch(favoritesDescriptor)
            
            // Calculate statistics
            let totalWatchTime = userStreams.reduce(0) { $0 + $1.duration }
            let totalStreamsWatched = userStreams.count
            let favoriteStreams = userFavorites.count
            
            userStats = UserStats(
                totalStreamsWatched: totalStreamsWatched,
                totalWatchTime: totalWatchTime,
                favoriteStreams: favoriteStreams,
                memberSince: user.createdAt,
                lastActive: user.lastActiveAt
            )
            
            // Cache stats
            cacheUserStats()
            
        } catch {
            print("Failed to load user stats: \(error)")
        }
    }
    
    private func cacheUserStats() {
        guard let stats = userStats else { return }
        
        do {
            let statsData = try JSONEncoder().encode(stats)
            userDefaults.set(statsData, forKey: "cached_user_stats")
        } catch {
            print("Failed to cache user stats: \(error)")
        }
    }
    
    // MARK: - Profile Updates
    
    func updateProfile(firstName: String?, lastName: String?, username: String?) async throws {
        guard var user = currentUser else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Update user object
            user.firstName = firstName
            user.lastName = lastName
            user.username = username
            user.updatedAt = Date()
            
            // Update in Clerk if authenticated
            if clerkManager.isAuthenticated {
                try await clerkManager.updateUserProfile(
                    firstName: firstName ?? "",
                    lastName: lastName ?? ""
                )
            }
            
            // Save to database
            try await saveUserToDatabase(user)
            
            // Update current user
            currentUser = user
            
            // Update cache
            cacheProfile()
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    func updatePreferences(_ preferences: UserPreferences) async throws {
        guard var user = currentUser else { return }
        
        user.updatePreferences(preferences)
        
        try await saveUserToDatabase(user)
        currentUser = user
        cacheProfile()
    }
    
    func updateLastActive() async {
        guard var user = currentUser else { return }
        
        user.updateLastActive()
        
        try await saveUserToDatabase(user)
        currentUser = user
        cacheProfile()
    }
    
    // MARK: - Account Management
    
    func deleteAccount() async throws {
        guard let user = currentUser else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Delete from Clerk
            if clerkManager.isAuthenticated {
                try await clerkManager.deleteUser()
            }
            
            // Delete from local database
            modelContext.delete(user)
            try modelContext.save()
            
            // Clear local data
            clearUserProfile()
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    func exportUserData() async throws -> Data {
        guard let user = currentUser else {
            throw ProfileError.noUserData
        }
        
        // Create export data structure
        let exportData = UserExportData(
            user: user,
            stats: userStats,
            favorites: user.favorites,
            streams: user.streams,
            subscriptions: user.subscriptions,
            notifications: user.notifications,
            exportDate: Date()
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    // MARK: - Refresh
    
    func refreshProfile() async {
        await loadUserProfile()
    }
    
    // MARK: - Computed Properties
    
    var isAuthenticated: Bool {
        return clerkManager.isAuthenticated
    }
    
    var displayName: String {
        return currentUser?.displayName ?? "Guest"
    }
    
    var userEmail: String? {
        return currentUser?.email
    }
    
    var userInitials: String {
        return currentUser?.initials ?? "G"
    }
    
    var memberSince: String {
        guard let user = currentUser else { return "N/A" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: user.createdAt)
    }
    
    var isPremiumUser: Bool {
        return currentUser?.isPremium ?? false
    }
    
    var subscriptionStatus: SubscriptionStatus {
        return currentUser?.subscriptionStatus ?? .free
    }
}

// MARK: - User Statistics Model

struct UserStats: Codable {
    let totalStreamsWatched: Int
    let totalWatchTime: TimeInterval
    let favoriteStreams: Int
    let memberSince: Date
    let lastActive: Date
    
    var formattedWatchTime: String {
        let hours = Int(totalWatchTime) / 3600
        let minutes = Int(totalWatchTime % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var membershipDuration: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: memberSince, relativeTo: Date())
    }
}

// MARK: - User Export Data

struct UserExportData: Codable {
    let user: User
    let stats: UserStats?
    let favorites: [Favorite]
    let streams: [Stream]
    let subscriptions: [Subscription]
    let notifications: [UserNotification]
    let exportDate: Date
}

// MARK: - Profile Errors

enum ProfileError: Error, LocalizedError {
    case noUserData
    case updateFailed
    case syncFailed
    case exportFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .noUserData:
            return "No user data available"
        case .updateFailed:
            return "Failed to update profile"
        case .syncFailed:
            return "Failed to sync profile data"
        case .exportFailed:
            return "Failed to export user data"
        case .deleteFailed:
            return "Failed to delete account"
        }
    }
}

// MARK: - Environment Key

struct ProfileManagerKey: EnvironmentKey {
    static let defaultValue: ProfileManager? = nil
}

extension EnvironmentValues {
    var profileManager: ProfileManager? {
        get { self[ProfileManagerKey.self] }
        set { self[ProfileManagerKey.self] = newValue }
    }
}