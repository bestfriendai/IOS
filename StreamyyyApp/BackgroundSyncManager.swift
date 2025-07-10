//
//  BackgroundSyncManager.swift
//  StreamyyyApp
//
//  Comprehensive background sync system for stream data, favorites, and user settings
//  Optimized for iOS background execution limits and battery efficiency
//

import Foundation
import BackgroundTasks
import UIKit
import Combine
import Network

// MARK: - Sync Types
enum SyncType: String, CaseIterable {
    case streams = "streams"
    case favorites = "favorites"
    case subscriptions = "subscriptions"
    case userSettings = "user_settings"
    case notifications = "notifications"
    case analytics = "analytics"
    case thumbnails = "thumbnails"
    case liveStatus = "live_status"
}

// MARK: - Sync Priority
enum SyncPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

// MARK: - Sync Status
enum SyncStatus: String, CaseIterable {
    case idle = "idle"
    case syncing = "syncing"
    case success = "success"
    case failed = "failed"
    case cancelled = "cancelled"
    case scheduled = "scheduled"
}

// MARK: - Sync Error
enum SyncError: Error, LocalizedError {
    case networkUnavailable
    case backgroundTimeExpired
    case dataCorrupted
    case authenticationFailed
    case rateLimited
    case serverError(Int)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .backgroundTimeExpired:
            return "Background sync time expired"
        case .dataCorrupted:
            return "Local data is corrupted"
        case .authenticationFailed:
            return "Authentication failed"
        case .rateLimited:
            return "Sync rate limited"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sync Item
struct SyncItem {
    let id: String
    let type: SyncType
    let priority: SyncPriority
    let lastSyncTime: Date?
    let scheduledTime: Date?
    let retryCount: Int
    let maxRetries: Int
    let data: [String: Any]
    let requiresNetwork: Bool
    let estimatedDuration: TimeInterval
    let dependencies: [String]
    
    var isExpired: Bool {
        guard let scheduledTime = scheduledTime else { return false }
        return Date().timeIntervalSince(scheduledTime) > 3600 // 1 hour
    }
    
    var canRetry: Bool {
        return retryCount < maxRetries
    }
}

// MARK: - Sync Configuration
struct SyncConfiguration {
    let syncInterval: TimeInterval
    let maxSyncDuration: TimeInterval
    let retryDelay: TimeInterval
    let maxRetries: Int
    let batchSize: Int
    let enabledTypes: Set<SyncType>
    let networkRequiredTypes: Set<SyncType>
    let backgroundSyncEnabled: Bool
    let lowPowerModeEnabled: Bool
    let wifiOnlyTypes: Set<SyncType>
    
    static let `default` = SyncConfiguration(
        syncInterval: 15 * 60, // 15 minutes
        maxSyncDuration: 25, // 25 seconds (iOS background limit is 30s)
        retryDelay: 30, // 30 seconds
        maxRetries: 3,
        batchSize: 10,
        enabledTypes: Set(SyncType.allCases),
        networkRequiredTypes: [.streams, .liveStatus, .subscriptions, .analytics],
        backgroundSyncEnabled: true,
        lowPowerModeEnabled: false,
        wifiOnlyTypes: [.thumbnails]
    )
}

// MARK: - Sync Statistics
struct SyncStatistics {
    var totalSyncs: Int = 0
    var successfulSyncs: Int = 0
    var failedSyncs: Int = 0
    var averageSyncDuration: TimeInterval = 0
    var lastSyncTime: Date?
    var networkUsage: Int64 = 0
    var batteryUsage: Double = 0
    var syncsByType: [SyncType: Int] = [:]
    var errorsByType: [SyncError: Int] = [:]
    
    var successRate: Double {
        guard totalSyncs > 0 else { return 0 }
        return Double(successfulSyncs) / Double(totalSyncs)
    }
}

// MARK: - Background Sync Manager
@MainActor
class BackgroundSyncManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    static let shared = BackgroundSyncManager()
    
    @Published var isRunning = false
    @Published var currentSyncStatus: SyncStatus = .idle
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncTime: Date?
    @Published var syncStatistics = SyncStatistics()
    @Published var isNetworkAvailable = true
    @Published var isLowPowerMode = false
    
    private var syncQueue: [SyncItem] = []
    private var activeSyncTasks: Set<String> = []
    private var syncConfiguration = SyncConfiguration.default
    private var cancellables = Set<AnyCancellable>()
    
    // Background task management
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskIdentifier = "com.streamyyy.background-sync"
    private var syncTimer: Timer?
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Data managers
    private let streamManager = StreamManager.shared
    private let supabaseService = SupabaseService.shared
    private let notificationManager = NotificationManager.shared
    
    // Storage
    private let userDefaults = UserDefaults.standard
    private let configKey = "sync_configuration"
    private let statisticsKey = "sync_statistics"
    private let queueKey = "sync_queue"
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupBackgroundSync()
        setupNetworkMonitoring()
        setupPowerModeMonitoring()
        loadConfiguration()
        loadStatistics()
        loadSyncQueue()
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        networkMonitor.cancel()
        syncTimer?.invalidate()
    }
    
    // MARK: - Configuration
    private func setupBackgroundSync() {
        // Register background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
                
                if path.status == .satisfied {
                    self?.startSyncIfNeeded()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupPowerModeMonitoring() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
    
    // MARK: - Public API
    func startSync() {
        guard !isRunning else { return }
        
        isRunning = true
        currentSyncStatus = .syncing
        
        Task {
            await performSync()
        }
    }
    
    func stopSync() {
        guard isRunning else { return }
        
        isRunning = false
        currentSyncStatus = .cancelled
        
        // Cancel all active tasks
        activeSyncTasks.removeAll()
        
        // End background task
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    func scheduleSyncItem(_ item: SyncItem) {
        // Check if item already exists
        if let existingIndex = syncQueue.firstIndex(where: { $0.id == item.id }) {
            // Update existing item
            syncQueue[existingIndex] = item
        } else {
            // Add new item
            syncQueue.append(item)
        }
        
        // Sort by priority and scheduled time
        syncQueue.sort { item1, item2 in
            if item1.priority != item2.priority {
                return item1.priority.rawValue > item2.priority.rawValue
            }
            
            let time1 = item1.scheduledTime ?? Date()
            let time2 = item2.scheduledTime ?? Date()
            return time1 < time2
        }
        
        saveSyncQueue()
        startSyncIfNeeded()
    }
    
    func cancelSyncItem(id: String) {
        syncQueue.removeAll { $0.id == id }
        activeSyncTasks.remove(id)
        saveSyncQueue()
    }
    
    func updateConfiguration(_ config: SyncConfiguration) {
        syncConfiguration = config
        saveConfiguration()
        
        // Restart sync with new configuration
        if isRunning {
            stopSync()
            startSync()
        }
    }
    
    func forceSyncType(_ type: SyncType) {
        let item = SyncItem(
            id: "\(type.rawValue)_force_\(UUID().uuidString)",
            type: type,
            priority: .high,
            lastSyncTime: nil,
            scheduledTime: Date(),
            retryCount: 0,
            maxRetries: 3,
            data: [:],
            requiresNetwork: syncConfiguration.networkRequiredTypes.contains(type),
            estimatedDuration: 5.0,
            dependencies: []
        )
        
        scheduleSyncItem(item)
    }
    
    // MARK: - Sync Logic
    private func performSync() async {
        guard isRunning else { return }
        
        let startTime = Date()
        var processedCount = 0
        var successCount = 0
        
        // Begin background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "StreamSyncTask"
        ) { [weak self] in
            self?.handleBackgroundTaskExpiration()
        }
        
        defer {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        
        // Process sync queue
        while isRunning && !syncQueue.isEmpty {
            // Check if we're running out of background time
            if backgroundTaskID != .invalid &&
               UIApplication.shared.backgroundTimeRemaining < 5.0 {
                print("⏰ Background sync time running out, stopping")
                break
            }
            
            // Check if we've exceeded max duration
            if Date().timeIntervalSince(startTime) > syncConfiguration.maxSyncDuration {
                print("⏰ Max sync duration exceeded, stopping")
                break
            }
            
            // Get next item to process
            guard let item = getNextSyncItem() else { break }
            
            // Check if item can be processed
            if !canProcessItem(item) {
                continue
            }
            
            // Process item
            do {
                try await processItem(item)
                successCount += 1
                
                // Update progress
                await MainActor.run {
                    syncProgress = Double(processedCount) / Double(syncQueue.count + processedCount)
                }
                
            } catch {
                print("❌ Failed to sync item \(item.id): \(error)")
                await handleSyncError(item, error: error)
            }
            
            processedCount += 1
            
            // Small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Update statistics
        await updateStatistics(
            totalProcessed: processedCount,
            successCount: successCount,
            duration: Date().timeIntervalSince(startTime)
        )
        
        // Schedule next sync
        scheduleNextSync()
        
        await MainActor.run {
            isRunning = false
            currentSyncStatus = .success
            lastSyncTime = Date()
            syncProgress = 1.0
        }
    }
    
    private func getNextSyncItem() -> SyncItem? {
        // Remove expired items
        syncQueue.removeAll { $0.isExpired }
        
        // Find next item that can be processed
        for (index, item) in syncQueue.enumerated() {
            if canProcessItem(item) {
                return syncQueue.remove(at: index)
            }
        }
        
        return nil
    }
    
    private func canProcessItem(_ item: SyncItem) -> Bool {
        // Check if already processing
        if activeSyncTasks.contains(item.id) {
            return false
        }
        
        // Check network requirements
        if item.requiresNetwork && !isNetworkAvailable {
            return false
        }
        
        // Check WiFi requirements
        if syncConfiguration.wifiOnlyTypes.contains(item.type) {
            // Implementation would check if connected to WiFi
            // For now, assume true
        }
        
        // Check low power mode
        if isLowPowerMode && !syncConfiguration.lowPowerModeEnabled {
            return false
        }
        
        // Check dependencies
        for dependency in item.dependencies {
            if activeSyncTasks.contains(dependency) {
                return false
            }
        }
        
        // Check if scheduled time has passed
        if let scheduledTime = item.scheduledTime,
           scheduledTime > Date() {
            return false
        }
        
        return true
    }
    
    private func processItem(_ item: SyncItem) async throws {
        activeSyncTasks.insert(item.id)
        
        defer {
            activeSyncTasks.remove(item.id)
        }
        
        switch item.type {
        case .streams:
            try await syncStreams(item)
        case .favorites:
            try await syncFavorites(item)
        case .subscriptions:
            try await syncSubscriptions(item)
        case .userSettings:
            try await syncUserSettings(item)
        case .notifications:
            try await syncNotifications(item)
        case .analytics:
            try await syncAnalytics(item)
        case .thumbnails:
            try await syncThumbnails(item)
        case .liveStatus:
            try await syncLiveStatus(item)
        }
    }
    
    // MARK: - Sync Implementations
    private func syncStreams(_ item: SyncItem) async throws {
        // Sync stream data from server
        let streams = try await supabaseService.fetchStreams()
        
        // Update local storage
        await streamManager.updateStreams(streams)
        
        // Schedule notifications for new live streams
        for stream in streams.filter({ $0.isLive }) {
            try await notificationManager.scheduleStreamGoLiveNotification(
                streamId: stream.id,
                streamerId: stream.streamerId,
                streamerName: stream.streamerName,
                title: stream.title,
                thumbnailURL: stream.thumbnailURL
            )
        }
    }
    
    private func syncFavorites(_ item: SyncItem) async throws {
        // Sync favorites from server
        let favorites = try await supabaseService.fetchFavorites()
        
        // Update local storage
        await streamManager.updateFavorites(favorites)
    }
    
    private func syncSubscriptions(_ item: SyncItem) async throws {
        // Sync subscription status from server
        let subscriptions = try await supabaseService.fetchSubscriptions()
        
        // Update local storage and notify UI
        await MainActor.run {
            // Update subscription manager
            NotificationCenter.default.post(
                name: .subscriptionStatusUpdated,
                object: nil,
                userInfo: ["subscriptions": subscriptions]
            )
        }
    }
    
    private func syncUserSettings(_ item: SyncItem) async throws {
        // Sync user settings from server
        let settings = try await supabaseService.fetchUserSettings()
        
        // Update local storage
        userDefaults.set(settings, forKey: "user_settings")
    }
    
    private func syncNotifications(_ item: SyncItem) async throws {
        // Sync notification preferences and history
        let notificationSettings = try await supabaseService.fetchNotificationSettings()
        
        // Update notification manager
        await notificationManager.updateSettings(notificationSettings)
    }
    
    private func syncAnalytics(_ item: SyncItem) async throws {
        // Send analytics data to server
        let analyticsData = getAnalyticsData()
        try await supabaseService.sendAnalytics(analyticsData)
    }
    
    private func syncThumbnails(_ item: SyncItem) async throws {
        // Sync thumbnail images
        let thumbnailURLs = item.data["urls"] as? [String] ?? []
        
        for url in thumbnailURLs {
            try await downloadThumbnail(url)
        }
    }
    
    private func syncLiveStatus(_ item: SyncItem) async throws {
        // Quick sync of live status for priority streamers
        let streamerIds = item.data["streamer_ids"] as? [String] ?? []
        
        for streamerId in streamerIds {
            let isLive = try await supabaseService.checkStreamLiveStatus(streamerId)
            
            if isLive {
                // Notify that streamer is live
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .streamerWentLive,
                        object: nil,
                        userInfo: ["streamerId": streamerId]
                    )
                }
            }
        }
    }
    
    // MARK: - Error Handling
    private func handleSyncError(_ item: SyncItem, error: Error) async {
        let syncError = mapToSyncError(error)
        
        // Update statistics
        syncStatistics.errorsByType[syncError, default: 0] += 1
        
        // Retry if possible
        if item.canRetry {
            let retryItem = SyncItem(
                id: item.id,
                type: item.type,
                priority: item.priority,
                lastSyncTime: item.lastSyncTime,
                scheduledTime: Date().addingTimeInterval(syncConfiguration.retryDelay),
                retryCount: item.retryCount + 1,
                maxRetries: item.maxRetries,
                data: item.data,
                requiresNetwork: item.requiresNetwork,
                estimatedDuration: item.estimatedDuration,
                dependencies: item.dependencies
            )
            
            syncQueue.append(retryItem)
            saveSyncQueue()
        }
        
        // Log error
        print("🔄 Sync error for \(item.type): \(syncError.localizedDescription)")
    }
    
    private func mapToSyncError(_ error: Error) -> SyncError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .backgroundTimeExpired
            default:
                return .unknown(error)
            }
        }
        
        return .unknown(error)
    }
    
    // MARK: - Background Task Handling
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await performSync()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func handleBackgroundTaskExpiration() {
        stopSync()
    }
    
    private func scheduleNextSync() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: syncConfiguration.syncInterval)
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    // MARK: - Utility Methods
    private func startSyncIfNeeded() {
        guard !isRunning else { return }
        guard !syncQueue.isEmpty else { return }
        guard syncConfiguration.backgroundSyncEnabled else { return }
        
        startSync()
    }
    
    private func getAnalyticsData() -> [String: Any] {
        return [
            "sync_statistics": syncStatistics,
            "app_usage": getAppUsageData(),
            "performance_metrics": getPerformanceMetrics()
        ]
    }
    
    private func getAppUsageData() -> [String: Any] {
        return [
            "session_count": userDefaults.integer(forKey: "session_count"),
            "total_app_time": userDefaults.double(forKey: "total_app_time"),
            "features_used": userDefaults.array(forKey: "features_used") ?? []
        ]
    }
    
    private func getPerformanceMetrics() -> [String: Any] {
        return [
            "average_sync_duration": syncStatistics.averageSyncDuration,
            "sync_success_rate": syncStatistics.successRate,
            "network_usage": syncStatistics.networkUsage,
            "battery_usage": syncStatistics.batteryUsage
        ]
    }
    
    private func downloadThumbnail(_ url: String) async throws {
        // Download and cache thumbnail
        guard let thumbnailURL = URL(string: url) else { return }
        
        let (data, _) = try await URLSession.shared.data(from: thumbnailURL)
        
        // Save to cache
        let cacheURL = getCacheURL(for: url)
        try data.write(to: cacheURL)
    }
    
    private func getCacheURL(for url: String) -> URL {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let thumbnailsDirectory = cacheDirectory.appendingPathComponent("thumbnails")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        
        let filename = url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return thumbnailsDirectory.appendingPathComponent(filename)
    }
    
    // MARK: - Statistics
    private func updateStatistics(totalProcessed: Int, successCount: Int, duration: TimeInterval) async {
        await MainActor.run {
            syncStatistics.totalSyncs += totalProcessed
            syncStatistics.successfulSyncs += successCount
            syncStatistics.failedSyncs += (totalProcessed - successCount)
            
            // Update average duration
            let totalDuration = syncStatistics.averageSyncDuration * Double(syncStatistics.totalSyncs - totalProcessed)
            syncStatistics.averageSyncDuration = (totalDuration + duration) / Double(syncStatistics.totalSyncs)
            
            syncStatistics.lastSyncTime = Date()
            
            saveStatistics()
        }
    }
    
    // MARK: - Persistence
    private func loadConfiguration() {
        if let data = userDefaults.data(forKey: configKey),
           let config = try? JSONDecoder().decode(SyncConfiguration.self, from: data) {
            syncConfiguration = config
        }
    }
    
    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(syncConfiguration) {
            userDefaults.set(data, forKey: configKey)
        }
    }
    
    private func loadStatistics() {
        if let data = userDefaults.data(forKey: statisticsKey),
           let stats = try? JSONDecoder().decode(SyncStatistics.self, from: data) {
            syncStatistics = stats
        }
    }
    
    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(syncStatistics) {
            userDefaults.set(data, forKey: statisticsKey)
        }
    }
    
    private func loadSyncQueue() {
        if let data = userDefaults.data(forKey: queueKey),
           let queue = try? JSONDecoder().decode([SyncItem].self, from: data) {
            syncQueue = queue
        }
    }
    
    private func saveSyncQueue() {
        if let data = try? JSONEncoder().encode(syncQueue) {
            userDefaults.set(data, forKey: queueKey)
        }
    }
    
    // MARK: - App Lifecycle
    @objc private func appDidEnterBackground() {
        // Schedule background sync
        scheduleNextSync()
    }
    
    @objc private func appWillEnterForeground() {
        // Cancel background sync and start foreground sync
        stopSync()
        startSyncIfNeeded()
    }
}

// MARK: - Extensions
extension SyncConfiguration: Codable {}
extension SyncStatistics: Codable {}
extension SyncItem: Codable {}

// MARK: - Notification Extensions
extension Notification.Name {
    static let subscriptionStatusUpdated = Notification.Name("subscriptionStatusUpdated")
    static let streamerWentLive = Notification.Name("streamerWentLive")
    static let syncStatusChanged = Notification.Name("syncStatusChanged")
}

// MARK: - Sync Item Factory
class SyncItemFactory {
    static func createStreamSyncItem(priority: SyncPriority = .normal) -> SyncItem {
        return SyncItem(
            id: "streams_\(UUID().uuidString)",
            type: .streams,
            priority: priority,
            lastSyncTime: nil,
            scheduledTime: Date(),
            retryCount: 0,
            maxRetries: 3,
            data: [:],
            requiresNetwork: true,
            estimatedDuration: 10.0,
            dependencies: []
        )
    }
    
    static func createLiveStatusSyncItem(streamerIds: [String], priority: SyncPriority = .high) -> SyncItem {
        return SyncItem(
            id: "live_status_\(UUID().uuidString)",
            type: .liveStatus,
            priority: priority,
            lastSyncTime: nil,
            scheduledTime: Date(),
            retryCount: 0,
            maxRetries: 2,
            data: ["streamer_ids": streamerIds],
            requiresNetwork: true,
            estimatedDuration: 5.0,
            dependencies: []
        )
    }
    
    static func createThumbnailSyncItem(urls: [String], priority: SyncPriority = .low) -> SyncItem {
        return SyncItem(
            id: "thumbnails_\(UUID().uuidString)",
            type: .thumbnails,
            priority: priority,
            lastSyncTime: nil,
            scheduledTime: Date(),
            retryCount: 0,
            maxRetries: 2,
            data: ["urls": urls],
            requiresNetwork: true,
            estimatedDuration: 15.0,
            dependencies: []
        )
    }
}