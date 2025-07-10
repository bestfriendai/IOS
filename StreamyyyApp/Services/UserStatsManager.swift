//
//  UserStatsManager.swift
//  StreamyyyApp
//
//  User statistics and analytics management
//

import Foundation
import SwiftUI
import Combine
import SwiftData

@MainActor
class UserStatsManager: ObservableObject {
    @Published var userStats: UserStats?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let modelContext: ModelContext
    private let profileManager: ProfileManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, profileManager: ProfileManager) {
        self.modelContext = modelContext
        self.profileManager = profileManager
        
        setupObservers()
        loadUserStats()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        profileManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                if user != nil {
                    self?.loadUserStats()
                } else {
                    self?.clearStats()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Stats Loading
    
    func loadUserStats() {
        guard let user = profileManager.currentUser else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let stats = try await calculateUserStats(for: user)
                userStats = stats
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    private func calculateUserStats(for user: User) async throws -> UserStats {
        // Load user's streams
        let streamsDescriptor = FetchDescriptor<Stream>(
            predicate: #Predicate<Stream> { $0.owner?.id == user.id }
        )
        let userStreams = try modelContext.fetch(streamsDescriptor)
        
        // Load user's favorites
        let favoritesDescriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate<Favorite> { $0.user?.id == user.id }
        )
        let userFavorites = try modelContext.fetch(favoritesDescriptor)
        
        // Calculate statistics
        let totalStreamsWatched = userStreams.count
        let totalWatchTime = userStreams.reduce(0) { $0 + $1.duration }
        let favoriteStreams = userFavorites.count
        
        // Calculate additional stats
        let uniquePlatforms = Set(userStreams.map { $0.platform }).count
        let averageSessionTime = totalStreamsWatched > 0 ? totalWatchTime / Double(totalStreamsWatched) : 0
        
        let liveStreamsWatched = userStreams.filter { $0.isLive }.count
        let archivedStreamsWatched = userStreams.filter { $0.isArchived }.count
        
        // Most watched platform
        let platformCounts = Dictionary(grouping: userStreams, by: { $0.platform })
            .mapValues { $0.count }
        let mostWatchedPlatform = platformCounts.max(by: { $0.value < $1.value })?.key
        
        // Recent activity (last 7 days)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentStreams = userStreams.filter { $0.createdAt >= weekAgo }
        let recentWatchTime = recentStreams.reduce(0) { $0 + $1.duration }
        
        return UserStats(
            totalStreamsWatched: totalStreamsWatched,
            totalWatchTime: totalWatchTime,
            favoriteStreams: favoriteStreams,
            uniquePlatforms: uniquePlatforms,
            averageSessionTime: averageSessionTime,
            liveStreamsWatched: liveStreamsWatched,
            archivedStreamsWatched: archivedStreamsWatched,
            mostWatchedPlatform: mostWatchedPlatform,
            recentStreams: recentStreams.count,
            recentWatchTime: recentWatchTime,
            memberSince: user.createdAt,
            lastActive: user.lastActiveAt
        )
    }
    
    // MARK: - Stats Recording
    
    func recordStreamView(stream: Stream, duration: TimeInterval) async {
        guard let user = profileManager.currentUser else { return }
        
        // Update stream duration
        stream.duration = duration
        stream.lastViewedAt = Date()
        stream.viewCount += 1
        
        // Update user's last active
        user.updateLastActive()
        
        try? modelContext.save()
        
        // Reload stats
        await loadUserStats()
    }
    
    func recordFavoriteAction(stream: Stream, isFavorite: Bool) async {
        guard let user = profileManager.currentUser else { return }
        
        if isFavorite {
            // Add favorite
            let favorite = Favorite(
                user: user,
                stream: stream,
                platform: stream.platform,
                streamTitle: stream.title,
                streamerName: stream.streamerName ?? "Unknown",
                streamURL: stream.url,
                thumbnailURL: stream.thumbnailURL
            )
            
            modelContext.insert(favorite)
        } else {
            // Remove favorite
            let descriptor = FetchDescriptor<Favorite>(
                predicate: #Predicate<Favorite> { 
                    $0.user?.id == user.id && $0.stream?.id == stream.id 
                }
            )
            
            if let existingFavorite = try? modelContext.fetch(descriptor).first {
                modelContext.delete(existingFavorite)
            }
        }
        
        try? modelContext.save()
        
        // Reload stats
        await loadUserStats()
    }
    
    // MARK: - Utility Methods
    
    private func clearStats() {
        userStats = nil
    }
    
    func refreshStats() async {
        await loadUserStats()
    }
    
    // MARK: - Computed Properties
    
    var hasStats: Bool {
        return userStats != nil
    }
    
    var totalStreamsWatched: Int {
        return userStats?.totalStreamsWatched ?? 0
    }
    
    var totalWatchTime: TimeInterval {
        return userStats?.totalWatchTime ?? 0
    }
    
    var favoriteStreams: Int {
        return userStats?.favoriteStreams ?? 0
    }
    
    var formattedWatchTime: String {
        return userStats?.formattedWatchTime ?? "0m"
    }
    
    var membershipDuration: String {
        return userStats?.membershipDuration ?? "Just joined"
    }
    
    var mostWatchedPlatform: Platform? {
        return userStats?.mostWatchedPlatform
    }
    
    var recentActivitySummary: String {
        guard let stats = userStats else { return "No activity" }
        
        if stats.recentStreams == 0 {
            return "No recent activity"
        } else {
            return "\(stats.recentStreams) streams watched this week"
        }
    }
}

// MARK: - Enhanced User Statistics Model

struct UserStats: Codable {
    let totalStreamsWatched: Int
    let totalWatchTime: TimeInterval
    let favoriteStreams: Int
    let uniquePlatforms: Int
    let averageSessionTime: TimeInterval
    let liveStreamsWatched: Int
    let archivedStreamsWatched: Int
    let mostWatchedPlatform: Platform?
    let recentStreams: Int
    let recentWatchTime: TimeInterval
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
    
    var formattedAverageSession: String {
        let minutes = Int(averageSessionTime) / 60
        return "\(minutes)m"
    }
    
    var formattedRecentWatchTime: String {
        let hours = Int(recentWatchTime) / 3600
        let minutes = Int(recentWatchTime % 3600) / 60
        
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
    
    var lastSeenFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActive, relativeTo: Date())
    }
    
    var activityLevel: ActivityLevel {
        if recentStreams >= 20 {
            return .veryActive
        } else if recentStreams >= 10 {
            return .active
        } else if recentStreams >= 5 {
            return .moderate
        } else if recentStreams >= 1 {
            return .light
        } else {
            return .inactive
        }
    }
}

// MARK: - Activity Level

enum ActivityLevel: String, CaseIterable {
    case veryActive = "very_active"
    case active = "active"
    case moderate = "moderate"
    case light = "light"
    case inactive = "inactive"
    
    var displayName: String {
        switch self {
        case .veryActive: return "Very Active"
        case .active: return "Active"
        case .moderate: return "Moderate"
        case .light: return "Light"
        case .inactive: return "Inactive"
        }
    }
    
    var color: Color {
        switch self {
        case .veryActive: return .green
        case .active: return .blue
        case .moderate: return .orange
        case .light: return .yellow
        case .inactive: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .veryActive: return "bolt.fill"
        case .active: return "flame.fill"
        case .moderate: return "sun.max.fill"
        case .light: return "moon.fill"
        case .inactive: return "sleep"
        }
    }
}

// MARK: - Environment Key

struct UserStatsManagerKey: EnvironmentKey {
    static let defaultValue: UserStatsManager? = nil
}

extension EnvironmentValues {
    var userStatsManager: UserStatsManager? {
        get { self[UserStatsManagerKey.self] }
        set { self[UserStatsManagerKey.self] = newValue }
    }
}