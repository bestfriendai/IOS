//
//  RealSupabaseService.swift
//  StreamyyyApp
//
//  Real Supabase integration for data storage
//

import Foundation
import Combine

// MARK: - Supabase Models
struct SupabaseStreamFavorite: Codable, Identifiable {
    let id: String
    let userId: String
    let streamId: String
    let streamerName: String
    let platform: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case streamId = "stream_id"
        case streamerName = "streamer_name"
        case platform
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SupabaseUserProfile: Codable, Identifiable {
    let id: String
    let clerkUserId: String
    let email: String?
    let displayName: String?
    let profileImageUrl: String?
    let preferences: SupabaseUserPreferences?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case clerkUserId = "clerk_user_id"
        case email
        case displayName = "display_name"
        case profileImageUrl = "profile_image_url"
        case preferences
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SupabaseUserPreferences: Codable {
    let autoplay: Bool
    let quality: String
    let volume: Double
    let chatEnabled: Bool
    let notificationsEnabled: Bool
    let theme: String
    
    enum CodingKeys: String, CodingKey {
        case autoplay
        case quality
        case volume
        case chatEnabled = "chat_enabled"
        case notificationsEnabled = "notifications_enabled"
        case theme
    }
    
    static let defaultPreferences = SupabaseUserPreferences(
        autoplay: true,
        quality: "auto",
        volume: 0.8,
        chatEnabled: true,
        notificationsEnabled: true,
        theme: "system"
    )
}

struct SupabaseStreamSession: Codable, Identifiable {
    let id: String
    let userId: String
    let streamId: String
    let platform: String
    let startTime: String
    let endTime: String?
    let duration: Int?
    let quality: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case streamId = "stream_id"
        case platform
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case quality
    }
}

// MARK: - Supabase API Service
@MainActor
class RealSupabaseService: ObservableObject {
    static let shared = RealSupabaseService()
    
    @Published var isConnected = false
    @Published var currentUserProfile: SupabaseUserProfile?
    @Published var favorites: [SupabaseStreamFavorite] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let baseURL = Config.Supabase.url
    private let apiKey = Config.Supabase.anonKey
    private let session = URLSession.shared
    
    private init() {
        setupService()
    }
    
    // MARK: - Setup
    private func setupService() {
        isConnected = true
        print("✅ Supabase service initialized with URL: \(baseURL)")
    }
    
    // MARK: - User Profile Management
    func createUserProfile(clerkUserId: String, email: String?, displayName: String?) async {
        guard let url = URL(string: "\(baseURL)/rest/v1/user_profiles") else { return }
        
        let profile = [
            "clerk_user_id": clerkUserId,
            "email": email ?? "",
            "display_name": displayName ?? "",
            "preferences": SupabaseUserPreferences.defaultPreferences
        ] as [String: Any]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: profile)
            
            isLoading = true
            let (data, _) = try await session.data(for: request)
            
            if let profiles = try? JSONDecoder().decode([SupabaseUserProfile].self, from: data),
               let newProfile = profiles.first {
                currentUserProfile = newProfile
            }
            
            isLoading = false
            print("✅ User profile created successfully")
        } catch {
            print("❌ Failed to create user profile: \(error)")
            self.error = error
            isLoading = false
        }
    }
    
    func getUserProfile(clerkUserId: String) async {
        guard let url = URL(string: "\(baseURL)/rest/v1/user_profiles") else { return }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "clerk_user_id", value: "eq.\(clerkUserId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let finalURL = components?.url else { return }
        
        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await session.data(for: request)
            let profiles = try JSONDecoder().decode([SupabaseUserProfile].self, from: data)
            
            if let profile = profiles.first {
                currentUserProfile = profile
            } else {
                // Create profile if it doesn't exist
                await createUserProfile(clerkUserId: clerkUserId, email: nil, displayName: nil)
            }
        } catch {
            print("❌ Failed to get user profile: \(error)")
            self.error = error
        }
    }
    
    func updateUserProfile(preferences: SupabaseUserPreferences) async {
        guard let profile = currentUserProfile,
              let url = URL(string: "\(baseURL)/rest/v1/user_profiles") else { return }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: "eq.\(profile.id)")]
        
        guard let finalURL = components?.url else { return }
        
        let updateData = ["preferences": preferences]
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(updateData)
            let (_, _) = try await session.data(for: request)
            
            // Update local profile
            currentUserProfile = SupabaseUserProfile(
                id: profile.id,
                clerkUserId: profile.clerkUserId,
                email: profile.email,
                displayName: profile.displayName,
                profileImageUrl: profile.profileImageUrl,
                preferences: preferences,
                createdAt: profile.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            print("✅ User preferences updated successfully")
        } catch {
            print("❌ Failed to update user preferences: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Favorites Management
    func getFavorites(userId: String) async {
        guard let url = URL(string: "\(baseURL)/rest/v1/stream_favorites") else { return }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        
        guard let finalURL = components?.url else { return }
        
        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await session.data(for: request)
            favorites = try JSONDecoder().decode([SupabaseStreamFavorite].self, from: data)
        } catch {
            print("❌ Failed to get favorites: \(error)")
            self.error = error
        }
    }
    
    func addFavorite(userId: String, streamId: String, streamerName: String, platform: String) async {
        guard let url = URL(string: "\(baseURL)/rest/v1/stream_favorites") else { return }
        
        let favorite = [
            "user_id": userId,
            "stream_id": streamId,
            "streamer_name": streamerName,
            "platform": platform
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: favorite)
            let (data, _) = try await session.data(for: request)
            
            if let newFavorites = try? JSONDecoder().decode([SupabaseStreamFavorite].self, from: data) {
                favorites.append(contentsOf: newFavorites)
            }
            
            print("✅ Favorite added successfully")
        } catch {
            print("❌ Failed to add favorite: \(error)")
            self.error = error
        }
    }
    
    func removeFavorite(favoriteId: String) async {
        guard let url = URL(string: "\(baseURL)/rest/v1/stream_favorites") else { return }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: "eq.\(favoriteId)")]
        
        guard let finalURL = components?.url else { return }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, _) = try await session.data(for: request)
            favorites.removeAll { $0.id == favoriteId }
            
            print("✅ Favorite removed successfully")
        } catch {
            print("❌ Failed to remove favorite: \(error)")
            self.error = error
        }
    }
    
    func isFavorite(streamId: String) -> Bool {
        return favorites.contains { $0.streamId == streamId }
    }
    
    // MARK: - Stream Sessions
    func startStreamSession(userId: String, streamId: String, platform: String, quality: String) async {
        guard let url = URL(string: "\(baseURL)/rest/v1/stream_sessions") else { return }
        
        let sessionData = [
            "user_id": userId,
            "stream_id": streamId,
            "platform": platform,
            "start_time": ISO8601DateFormatter().string(from: Date()),
            "quality": quality
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: sessionData)
            let (_, _) = try await session.data(for: request)
            
            print("✅ Stream session started")
        } catch {
            print("❌ Failed to start stream session: \(error)")
            self.error = error
        }
    }
    
    func endStreamSession(sessionId: String, duration: Int) async {
        guard let url = URL(string: "\(baseURL)/rest/v1/stream_sessions") else { return }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: "eq.\(sessionId)")]
        
        guard let finalURL = components?.url else { return }
        
        let updateData = [
            "end_time": ISO8601DateFormatter().string(from: Date()),
            "duration": duration
        ] as [String: Any]
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
            let (_, _) = try await session.data(for: request)
            
            print("✅ Stream session ended")
        } catch {
            print("❌ Failed to end stream session: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Analytics
    func getWatchingStats(userId: String) async -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/rest/v1/stream_sessions") else { return [:] }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "duration,platform,quality")
        ]
        
        guard let finalURL = components?.url else { return [:] }
        
        var request = URLRequest(url: finalURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await session.data(for: request)
            let sessions = try JSONDecoder().decode([SupabaseStreamSession].self, from: data)
            
            let totalDuration = sessions.compactMap { $0.duration }.reduce(0, +)
            let platformCounts = Dictionary(grouping: sessions) { $0.platform }
                .mapValues { $0.count }
            
            return [
                "total_duration": totalDuration,
                "total_sessions": sessions.count,
                "platform_breakdown": platformCounts,
                "average_session": sessions.isEmpty ? 0 : totalDuration / sessions.count
            ]
        } catch {
            print("❌ Failed to get watching stats: \(error)")
            self.error = error
            return [:]
        }
    }
    
    // MARK: - Utility Methods
    func clearError() {
        error = nil
    }
    
    func signOut() {
        currentUserProfile = nil
        favorites = []
    }
}