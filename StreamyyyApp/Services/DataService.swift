//
//  DataService.swift
//  StreamyyyApp
//
//  Core Data operations and sync logic for all models
//  Provides unified interface for data persistence, sync, and offline support
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import CloudKit

// MARK: - Data Service
@MainActor
public class DataService: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = DataService()
    
    // MARK: - Published Properties
    @Published public private(set) var isReady: Bool = false
    @Published public private(set) var syncStatus: DataSyncStatus = .offline
    @Published public private(set) var lastSyncTime: Date?
    @Published public private(set) var pendingSyncCount: Int = 0
    @Published public private(set) var error: DataServiceError?
    
    // MARK: - Services
    private let modelContainer: AppModelContainer
    private let supabaseService: SupabaseService
    private let cacheManager: StreamCacheManager
    private var cloudKitService: CloudKitService?
    
    // MARK: - Repositories
    public let userRepository: UserRepository
    public let streamRepository: StreamRepository
    public let favoriteRepository: FavoriteRepository
    public let layoutRepository: LayoutRepository
    public let subscriptionRepository: SubscriptionRepository
    public let notificationRepository: NotificationRepository
    public let viewingHistoryRepository: ViewingHistoryRepository
    
    // MARK: - Sync Configuration
    private let syncConfiguration: SyncConfiguration
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Background Context
    private var backgroundContext: ModelContext?
    
    // MARK: - Initialization
    private init() {
        self.modelContainer = AppModelContainer.shared
        self.supabaseService = SupabaseService.shared
        self.cacheManager = StreamCacheManager.shared
        self.syncConfiguration = SyncConfiguration()
        
        // Initialize repositories
        self.userRepository = UserRepository()
        self.streamRepository = StreamRepository()
        self.favoriteRepository = FavoriteRepository()
        self.layoutRepository = LayoutRepository()
        self.subscriptionRepository = SubscriptionRepository()
        self.notificationRepository = NotificationRepository()
        self.viewingHistoryRepository = ViewingHistoryRepository()
        
        setupDataService()
    }
    
    // MARK: - Setup
    private func setupDataService() {
        // Wait for model container to be ready
        modelContainer.$isReady
            .sink { [weak self] isReady in
                if isReady {
                    self?.initializeDataService()
                }
            }
            .store(in: &cancellables)
        
        // Monitor Supabase connection
        supabaseService.$syncStatus
            .sink { [weak self] status in
                self?.updateSyncStatus(from: status)
            }
            .store(in: &cancellables)
        
        // Monitor authentication state
        supabaseService.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task {
                        await self?.performInitialSync()
                    }
                } else {
                    self?.pauseSync()
                }
            }
            .store(in: &cancellables)
    }
    
    private func initializeDataService() {
        Task {
            do {
                // Setup background context for sync operations
                setupBackgroundContext()
                
                // Initialize CloudKit if available
                await initializeCloudKit()
                
                // Start sync services
                startSyncTimer()
                
                // Mark as ready
                isReady = true
                
                print("✅ DataService initialized successfully")
                
            } catch {
                print("❌ DataService initialization failed: \(error)")
                self.error = .initializationFailed(error)
            }
        }
    }
    
    private func setupBackgroundContext() {
        if #available(iOS 17.0, *), let container = modelContainer.container {
            backgroundContext = ModelContext(container)
        }
    }
    
    private func initializeCloudKit() async {
        do {
            cloudKitService = try CloudKitService()
            print("✅ CloudKit service initialized")
        } catch {
            print("⚠️ CloudKit service initialization failed: \(error)")
            // CloudKit is optional, continue without it
        }
    }
    
    // MARK: - User Data Operations
    public func createUser(email: String, username: String? = nil) async throws -> User {
        let user = User(
            email: email,
            username: username,
            timezone: TimeZone.current.identifier,
            locale: Locale.current.identifier
        )
        
        // Save locally first
        userRepository.insert(user)
        modelContainer.save()
        
        // Sync to remote services
        await syncUserToRemote(user)
        
        return user
    }
    
    public func updateUser(_ user: User) async throws {
        user.updatedAt = Date()
        userRepository.update(user)
        modelContainer.save()
        
        // Mark for sync
        await markForSync(user, operation: .update)
    }
    
    public func getCurrentUser() -> User? {
        return userRepository.fetchActiveUsers().first
    }
    
    // MARK: - Stream Data Operations
    public func addStream(_ stream: Stream, to user: User? = nil) async throws -> Stream {
        let targetUser = user ?? getCurrentUser()
        stream.owner = targetUser
        stream.createdAt = Date()
        stream.updatedAt = Date()
        
        // Save locally
        streamRepository.insert(stream)
        modelContainer.save()
        
        // Cache stream data
        await cacheManager.cacheStream(stream)
        
        // Mark for sync
        await markForSync(stream, operation: .create)
        
        return stream
    }
    
    public func updateStream(_ stream: Stream) async throws {
        stream.updatedAt = Date()
        streamRepository.update(stream)
        modelContainer.save()
        
        // Update cache
        await cacheManager.updateStream(stream)
        
        // Mark for sync
        await markForSync(stream, operation: .update)
    }
    
    public func removeStream(_ stream: Stream) async throws {
        // Remove from cache
        await cacheManager.removeStream(id: stream.id)
        
        // Mark for sync before deleting locally
        await markForSync(stream, operation: .delete)
        
        // Remove locally
        streamRepository.delete(stream)
        modelContainer.save()
    }
    
    public func getStreams(for user: User? = nil) -> [Stream] {
        if let user = user {
            return streamRepository.fetchByOwner(user)
        } else if let currentUser = getCurrentUser() {
            return streamRepository.fetchByOwner(currentUser)
        }
        return []
    }
    
    public func getLiveStreams() -> [Stream] {
        return streamRepository.fetchLiveStreams()
    }
    
    // MARK: - Favorites Operations
    public func addFavorite(stream: Stream, user: User? = nil) async throws -> Favorite {
        let targetUser = user ?? getCurrentUser()
        guard let targetUser = targetUser else {
            throw DataServiceError.userNotFound
        }
        
        // Check if already favorited
        let existingFavorites = favoriteRepository.fetchByUser(targetUser)
        if existingFavorites.contains(where: { $0.stream?.id == stream.id }) {
            throw DataServiceError.alreadyExists("Stream already favorited")
        }
        
        let favorite = Favorite(user: targetUser, stream: stream)
        
        // Save locally
        favoriteRepository.insert(favorite)
        modelContainer.save()
        
        // Mark for sync
        await markForSync(favorite, operation: .create)
        
        return favorite
    }
    
    public func removeFavorite(_ favorite: Favorite) async throws {
        // Mark for sync before deleting
        await markForSync(favorite, operation: .delete)
        
        // Remove locally
        favoriteRepository.delete(favorite)
        modelContainer.save()
    }
    
    public func getFavorites(for user: User? = nil) -> [Favorite] {
        if let user = user {
            return favoriteRepository.fetchByUser(user)
        } else if let currentUser = getCurrentUser() {
            return favoriteRepository.fetchByUser(currentUser)
        }
        return []
    }
    
    // MARK: - Layout Operations
    public func saveLayout(_ layout: Layout, user: User? = nil) async throws -> Layout {
        let targetUser = user ?? getCurrentUser()
        layout.owner = targetUser
        layout.updatedAt = Date()
        layout.version += 1
        
        // Save locally
        layoutRepository.insert(layout)
        modelContainer.save()
        
        // Mark for sync
        await markForSync(layout, operation: layout.createdAt == layout.updatedAt ? .create : .update)
        
        return layout
    }
    
    public func getLayouts(for user: User? = nil) -> [Layout] {
        if let user = user {
            return layoutRepository.fetchByOwner(user)
        } else if let currentUser = getCurrentUser() {
            return layoutRepository.fetchByOwner(currentUser)
        }
        return []
    }
    
    public func getDefaultLayout(for user: User? = nil) -> Layout? {
        let layouts = getLayouts(for: user)
        return layouts.first { $0.isDefault }
    }
    
    // MARK: - Viewing History Operations
    public func addToViewingHistory(stream: Stream, user: User? = nil) async throws -> ViewingHistory {
        let targetUser = user ?? getCurrentUser()
        guard let targetUser = targetUser else {
            throw DataServiceError.userNotFound
        }
        
        let viewingHistory = ViewingHistory(
            id: UUID().uuidString,
            user: targetUser,
            stream: stream,
            watchedAt: Date(),
            duration: 0
        )
        
        // Save locally
        viewingHistoryRepository.insert(viewingHistory)
        modelContainer.save()
        
        // Mark for sync
        await markForSync(viewingHistory, operation: .create)
        
        return viewingHistory
    }
    
    public func getViewingHistory(for user: User? = nil, limit: Int = 100) -> [ViewingHistory] {
        if let user = user {
            return viewingHistoryRepository.fetchByUser(user, limit: limit)
        } else if let currentUser = getCurrentUser() {
            return viewingHistoryRepository.fetchByUser(currentUser, limit: limit)
        }
        return []
    }
    
    // MARK: - Sync Operations
    private func updateSyncStatus(from supabaseStatus: SyncStatus) {
        switch supabaseStatus {
        case .connected:
            syncStatus = .online
        case .syncing:
            syncStatus = .syncing
        case .synced:
            syncStatus = .synced
            lastSyncTime = Date()
        case .error:
            syncStatus = .error
        case .offline:
            syncStatus = .offline
        default:
            syncStatus = .offline
        }
    }
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncConfiguration.autoSyncInterval, repeats: true) { _ in
            Task {
                await self.performIncrementalSync()
            }
        }
    }
    
    private func pauseSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        syncStatus = .offline
    }
    
    public func performFullSync() async {
        guard supabaseService.isAuthenticated else {
            syncStatus = .offline
            return
        }
        
        syncStatus = .syncing
        
        do {
            // Sync users
            await syncUsers()
            
            // Sync streams
            await syncStreams()
            
            // Sync favorites
            await syncFavorites()
            
            // Sync layouts
            await syncLayouts()
            
            // Sync viewing history
            await syncViewingHistory()
            
            // CloudKit sync
            if let cloudKitService = cloudKitService {
                await cloudKitService.performFullSync()
            }
            
            syncStatus = .synced
            lastSyncTime = Date()
            pendingSyncCount = 0
            
            print("✅ Full sync completed successfully")
            
        } catch {
            print("❌ Full sync failed: \(error)")
            syncStatus = .error
            self.error = .syncFailed(error)
        }
    }
    
    public func performIncrementalSync() async {
        guard supabaseService.isAuthenticated else { return }
        guard syncStatus != .syncing else { return }
        
        syncStatus = .syncing
        
        do {
            // Get pending sync items
            let pendingItems = getPendingSyncItems()
            
            if pendingItems.isEmpty {
                syncStatus = .synced
                return
            }
            
            // Process pending items
            for item in pendingItems {
                try await processSyncItem(item)
            }
            
            // CloudKit incremental sync
            if let cloudKitService = cloudKitService {
                await cloudKitService.performIncrementalSync()
            }
            
            syncStatus = .synced
            lastSyncTime = Date()
            pendingSyncCount = 0
            
        } catch {
            print("❌ Incremental sync failed: \(error)")
            syncStatus = .error
            self.error = .syncFailed(error)
        }
    }
    
    private func performInitialSync() async {
        await performFullSync()
    }
    
    // MARK: - Data Migration
    public func migrateDataIfNeeded() async throws {
        let currentVersion = UserDefaults.standard.integer(forKey: "DataVersion")
        let targetVersion = 1
        
        if currentVersion < targetVersion {
            print("🔄 Migrating data from version \(currentVersion) to \(targetVersion)")
            
            try await performDataMigration(from: currentVersion, to: targetVersion)
            
            UserDefaults.standard.set(targetVersion, forKey: "DataVersion")
            print("✅ Data migration completed")
        }
    }
    
    private func performDataMigration(from oldVersion: Int, to newVersion: Int) async throws {
        // Implement data migration logic here
        // This would handle schema changes, data transformations, etc.
        
        switch oldVersion {
        case 0:
            // Initial migration
            try await migrateFromVersion0()
        default:
            break
        }
    }
    
    private func migrateFromVersion0() async throws {
        // Example migration: convert old data format to new format
        // This is where you'd handle breaking changes in your data models
    }
    
    // MARK: - Offline Support
    public func enableOfflineMode() {
        cacheManager.enableOfflineMode()
        syncStatus = .offline
        print("📱 Offline mode enabled")
    }
    
    public func disableOfflineMode() {
        cacheManager.disableOfflineMode()
        if supabaseService.isAuthenticated {
            Task {
                await performIncrementalSync()
            }
        }
        print("📱 Offline mode disabled")
    }
    
    public func getOfflineData() -> OfflineData {
        let cachedStreams = streamRepository.fetch()
        let favorites = favoriteRepository.fetch()
        let layouts = layoutRepository.fetch()
        let viewingHistory = viewingHistoryRepository.fetch()
        
        return OfflineData(
            streams: cachedStreams,
            favorites: favorites,
            layouts: layouts,
            viewingHistory: viewingHistory,
            lastUpdated: lastSyncTime ?? Date()
        )
    }
    
    // MARK: - Performance Optimization
    public func optimizePerformance() async {
        // Clean up old data
        await cleanupOldData()
        
        // Optimize model container
        modelContainer.performanceOptimization()
        
        // Optimize cache
        await cacheManager.optimizeCache()
        
        print("🚀 Performance optimization completed")
    }
    
    private func cleanupOldData() async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        
        // Clean up old viewing history
        let oldHistory = viewingHistoryRepository.fetch().filter { $0.watchedAt < cutoffDate }
        oldHistory.forEach { viewingHistoryRepository.delete($0) }
        
        // Clean up archived favorites
        let archivedFavorites = favoriteRepository.fetch().filter { $0.isArchived && ($0.archivedAt ?? Date()) < cutoffDate }
        archivedFavorites.forEach { favoriteRepository.delete($0) }
        
        modelContainer.save()
    }
    
    // MARK: - Error Handling
    public func clearError() {
        error = nil
    }
    
    // MARK: - Helper Methods
    private func markForSync<T>(_ object: T, operation: SyncOperation) async {
        // Store sync operations for later processing
        // This would typically involve storing in a separate sync queue table
        pendingSyncCount += 1
    }
    
    private func syncUserToRemote(_ user: User) async {
        // Sync user to Supabase and CloudKit
        do {
            if supabaseService.isAuthenticated {
                // Supabase sync logic would go here
            }
            
            if let cloudKitService = cloudKitService {
                await cloudKitService.syncUser(user)
            }
        } catch {
            print("❌ Failed to sync user to remote: \(error)")
        }
    }
    
    private func getPendingSyncItems() -> [SyncItem] {
        // Return items that need to be synced
        // This would query a sync queue or check timestamps
        return []
    }
    
    private func processSyncItem(_ item: SyncItem) async throws {
        // Process individual sync items
        // This would handle the actual sync logic for each item type
    }
    
    // MARK: - Sync Helper Methods
    private func syncUsers() async {
        // Sync users with remote services
    }
    
    private func syncStreams() async {
        // Sync streams with remote services
    }
    
    private func syncFavorites() async {
        // Sync favorites with remote services
    }
    
    private func syncLayouts() async {
        // Sync layouts with remote services
    }
    
    private func syncViewingHistory() async {
        // Sync viewing history with remote services
    }
    
    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

public struct SyncConfiguration {
    public let autoSyncInterval: TimeInterval = 300 // 5 minutes
    public let batchSize: Int = 50
    public let maxRetryAttempts: Int = 3
    public let conflictResolutionStrategy: ConflictResolutionStrategy = .serverWins
}

public enum ConflictResolutionStrategy {
    case serverWins
    case clientWins
    case mostRecent
    case manual
}

public enum DataSyncStatus {
    case offline
    case online
    case syncing
    case synced
    case error
    
    public var displayName: String {
        switch self {
        case .offline: return "Offline"
        case .online: return "Online"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .error: return "Error"
        }
    }
    
    public var color: Color {
        switch self {
        case .offline: return .gray
        case .online: return .blue
        case .syncing: return .orange
        case .synced: return .green
        case .error: return .red
        }
    }
}

public enum SyncOperation {
    case create
    case update
    case delete
}

public struct SyncItem {
    public let id: String
    public let type: String
    public let operation: SyncOperation
    public let timestamp: Date
    public let data: [String: Any]
}

public struct OfflineData {
    public let streams: [Stream]
    public let favorites: [Favorite]
    public let layouts: [Layout]
    public let viewingHistory: [ViewingHistory]
    public let lastUpdated: Date
}

public enum DataServiceError: Error, LocalizedError {
    case initializationFailed(Error)
    case userNotFound
    case streamNotFound
    case alreadyExists(String)
    case syncFailed(Error)
    case migrationFailed(Error)
    case validationFailed(String)
    case networkUnavailable
    case authenticationRequired
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Failed to initialize data service: \(error.localizedDescription)"
        case .userNotFound:
            return "User not found"
        case .streamNotFound:
            return "Stream not found"
        case .alreadyExists(let message):
            return message
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Data migration failed: \(error.localizedDescription)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .networkUnavailable:
            return "Network is unavailable"
        case .authenticationRequired:
            return "Authentication required"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Repository Extensions for DataService

extension LayoutRepository {
    public func fetchByOwner(_ owner: User) -> [Layout] {
        return fetch().filter { $0.owner?.id == owner.id }
    }
}

public class ViewingHistoryRepository: GenericRepository<ViewingHistory> {
    public func fetchByUser(_ user: User, limit: Int = 100) -> [ViewingHistory] {
        let history = fetch().filter { $0.user?.id == user.id }
        return Array(history.sorted { $0.watchedAt > $1.watchedAt }.prefix(limit))
    }
    
    public func fetchRecentHistory(days: Int = 7) -> [ViewingHistory] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return fetch().filter { $0.watchedAt >= cutoffDate }
    }
}