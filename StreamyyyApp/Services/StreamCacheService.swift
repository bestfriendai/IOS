//
//  CacheService.swift
//  StreamyyyApp
//
//  Comprehensive offline data management and intelligent caching
//  Provides robust caching for all app data with smart cleanup and offline support
//

import Foundation
import SwiftUI
import Combine

// MARK: - Cache Service
@MainActor
public class CacheService: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = CacheService()
    
    // MARK: - Published Properties
    @Published public private(set) var isOfflineModeEnabled: Bool = false
    @Published public private(set) var cacheSize: Int64 = 0
    @Published public private(set) var cacheStatus: CacheHealthStatus = .healthy
    @Published public private(set) var offlineAvailability: OfflineAvailability = .none
    @Published public private(set) var lastCleanupTime: Date?
    
    // MARK: - Cache Configuration
    private let maxCacheSize: Int64 = 1024 * 1024 * 1024 // 1GB
    private let maxOfflineDataAge: TimeInterval = 7 * 24 * 3600 // 7 days
    private let cleanupThreshold: Double = 0.8 // Start cleanup at 80% capacity
    private let criticalThreshold: Double = 0.95 // Critical cleanup at 95%
    
    // MARK: - Cache Directories
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let offlineDirectory: URL
    private let thumbnailDirectory: URL
    private let metadataDirectory: URL
    private let layoutDirectory: URL
    private let userDataDirectory: URL
    
    // MARK: - Cache Storage
    private var memoryCache: [String: CachedItem] = [:]
    private var diskCache: DiskCacheManager
    private var offlineDataManager: OfflineDataManager
    
    // MARK: - Performance Tracking
    private var cacheStats = CacheStatistics()
    private var accessPatterns: [String: CacheAccessPattern] = [:]
    
    // MARK: - Queue Management
    private let cacheQueue = DispatchQueue(label: "cache.service.queue", qos: .utility)
    private let cleanupQueue = DispatchQueue(label: "cache.cleanup.queue", qos: .background)
    private let offlineQueue = DispatchQueue(label: "offline.service.queue", qos: .utility)
    
    // MARK: - Initialization
    private init() {
        // Setup cache directories
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let appCacheDirectory = cachesDirectory.appendingPathComponent("StreamyyyApp")
        
        self.cacheDirectory = appCacheDirectory.appendingPathComponent("Cache")
        self.offlineDirectory = appCacheDirectory.appendingPathComponent("Offline")
        self.thumbnailDirectory = appCacheDirectory.appendingPathComponent("Thumbnails")
        self.metadataDirectory = appCacheDirectory.appendingPathComponent("Metadata")
        self.layoutDirectory = appCacheDirectory.appendingPathComponent("Layouts")
        self.userDataDirectory = appCacheDirectory.appendingPathComponent("UserData")
        
        // Initialize managers
        self.diskCache = DiskCacheManager(cacheDirectory: cacheDirectory)
        self.offlineDataManager = OfflineDataManager(offlineDirectory: offlineDirectory)
        
        setupCacheService()
    }
    
    // MARK: - Setup
    private func setupCacheService() {
        createCacheDirectories()
        loadCacheData()
        startPeriodicCleanup()
        calculateCacheSize()
        
        // Monitor app lifecycle
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.performBackgroundCleanup()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.saveAccessPatterns()
        }
    }
    
    private func createCacheDirectories() {
        let directories = [
            cacheDirectory, offlineDirectory, thumbnailDirectory,
            metadataDirectory, layoutDirectory, userDataDirectory
        ]
        
        for directory in directories {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create cache directory \(directory.lastPathComponent): \(error)")
            }
        }
    }
    
    private func loadCacheData() {
        cacheQueue.async {
            self.loadAccessPatterns()
            self.loadCacheStatistics()
        }
    }
    
    // MARK: - Stream Caching
    public func cacheStream(_ stream: Stream) async {
        let item = CachedItem(
            key: stream.id,
            data: try? JSONEncoder().encode(stream),
            type: .stream,
            size: estimateStreamSize(stream),
            createdAt: Date(),
            lastAccessed: Date(),
            metadata: [
                "title": stream.title,
                "platform": stream.platform.rawValue,
                "isLive": String(stream.isLive)
            ]
        )
        
        await cacheItem(item)
        
        // Cache associated data
        if let thumbnailURL = stream.thumbnailURL {
            await cacheThumbnail(url: thumbnailURL, key: stream.id)
        }
        
        await cacheStreamMetadata(stream)
        updateCacheStats(operation: .cache, hit: true)
    }
    
    public func getCachedStream(id: String) async -> Stream? {
        if let item = await getCachedItem(key: id, type: .stream) {
            updateAccessPattern(for: id)
            updateCacheStats(operation: .retrieve, hit: true)
            
            if let data = item.data,
               let stream = try? JSONDecoder().decode(Stream.self, from: data) {
                return stream
            }
        }
        
        updateCacheStats(operation: .retrieve, hit: false)
        return nil
    }
    
    // MARK: - Favorites Caching
    public func cacheFavorites(_ favorites: [Favorite], userId: String) async {
        let item = CachedItem(
            key: "favorites_\(userId)",
            data: try? JSONEncoder().encode(favorites),
            type: .favorites,
            size: estimateFavoritesSize(favorites),
            createdAt: Date(),
            lastAccessed: Date(),
            metadata: [
                "userId": userId,
                "count": String(favorites.count)
            ]
        )
        
        await cacheItem(item)
    }
    
    public func getCachedFavorites(userId: String) async -> [Favorite]? {
        if let item = await getCachedItem(key: "favorites_\(userId)", type: .favorites) {
            if let data = item.data,
               let favorites = try? JSONDecoder().decode([Favorite].self, from: data) {
                return favorites
            }
        }
        return nil
    }
    
    // MARK: - Layout Caching
    public func cacheLayout(_ layout: Layout) async {
        let item = CachedItem(
            key: layout.id,
            data: try? JSONEncoder().encode(layout),
            type: .layout,
            size: estimateLayoutSize(layout),
            createdAt: Date(),
            lastAccessed: Date(),
            metadata: [
                "name": layout.name,
                "type": layout.type.rawValue,
                "isDefault": String(layout.isDefault)
            ]
        )
        
        await cacheItem(item)
    }
    
    public func getCachedLayout(id: String) async -> Layout? {
        if let item = await getCachedItem(key: id, type: .layout) {
            if let data = item.data,
               let layout = try? JSONDecoder().decode(Layout.self, from: data) {
                return layout
            }
        }
        return nil
    }
    
    // MARK: - User Data Caching
    public func cacheUserData(_ user: User) async {
        let item = CachedItem(
            key: user.id,
            data: try? JSONEncoder().encode(user),
            type: .userData,
            size: estimateUserSize(user),
            createdAt: Date(),
            lastAccessed: Date(),
            metadata: [
                "email": user.email,
                "username": user.username ?? "",
                "subscriptionStatus": user.subscriptionStatus.rawValue
            ]
        )
        
        await cacheItem(item)
    }
    
    public func getCachedUserData(id: String) async -> User? {
        if let item = await getCachedItem(key: id, type: .userData) {
            if let data = item.data,
               let user = try? JSONDecoder().decode(User.self, from: data) {
                return user
            }
        }
        return nil
    }
    
    // MARK: - Thumbnail Caching
    public func cacheThumbnail(url: String, key: String) async {
        do {
            let thumbnailURL = URL(string: url)!
            let (data, _) = try await URLSession.shared.data(from: thumbnailURL)
            
            let item = CachedItem(
                key: "thumbnail_\(key)",
                data: data,
                type: .thumbnail,
                size: Int64(data.count),
                createdAt: Date(),
                lastAccessed: Date(),
                metadata: [
                    "url": url,
                    "streamId": key
                ]
            )
            
            await cacheItem(item)
        } catch {
            print("❌ Failed to cache thumbnail: \(error)")
        }
    }
    
    public func getCachedThumbnail(key: String) async -> Data? {
        if let item = await getCachedItem(key: "thumbnail_\(key)", type: .thumbnail) {
            return item.data
        }
        return nil
    }
    
    // MARK: - Core Cache Operations
    private func cacheItem(_ item: CachedItem) async {
        await cacheQueue.async {
            // Store in memory cache
            self.memoryCache[item.key] = item
            
            // Store on disk
            self.diskCache.store(item)
            
            // Update size
            self.cacheSize += item.size
            
            // Check if cleanup is needed
            if self.getCacheUtilization() > self.cleanupThreshold {
                Task {
                    await self.performIntelligentCleanup()
                }
            }
        }
    }
    
    private func getCachedItem(key: String, type: CacheItemType) async -> CachedItem? {
        return await cacheQueue.sync {
            // Check memory cache first
            if let item = self.memoryCache[key] {
                item.lastAccessed = Date()
                return item
            }
            
            // Check disk cache
            if let item = self.diskCache.retrieve(key: key) {
                // Load into memory cache for faster access
                self.memoryCache[key] = item
                item.lastAccessed = Date()
                return item
            }
            
            return nil
        }
    }
    
    // MARK: - Offline Support
    public func enableOfflineMode() async {
        isOfflineModeEnabled = true
        await prepareOfflineData()
        updateOfflineAvailability()
        print("📱 Offline mode enabled")
    }
    
    public func disableOfflineMode() {
        isOfflineModeEnabled = false
        updateOfflineAvailability()
        print("📱 Offline mode disabled")
    }
    
    private func prepareOfflineData() async {
        let offlineData = OfflineDataBundle(
            streams: await getAllCachedStreams(),
            favorites: await getAllCachedFavorites(),
            layouts: await getAllCachedLayouts(),
            userData: await getAllCachedUserData(),
            thumbnails: await getAllCachedThumbnails(),
            preparedAt: Date()
        )
        
        await offlineDataManager.storeOfflineBundle(offlineData)
        updateOfflineAvailability()
    }
    
    public func getOfflineData() async -> OfflineDataBundle? {
        return await offlineDataManager.getOfflineBundle()
    }
    
    private func updateOfflineAvailability() {
        Task {
            let hasStreams = await getAllCachedStreams().count > 0
            let hasFavorites = await getAllCachedFavorites().count > 0
            let hasLayouts = await getAllCachedLayouts().count > 0
            
            if hasStreams && hasFavorites && hasLayouts {
                offlineAvailability = .full
            } else if hasStreams || hasFavorites {
                offlineAvailability = .partial
            } else {
                offlineAvailability = .none
            }
        }
    }
    
    // MARK: - Cache Management
    private func performIntelligentCleanup() async {
        await cleanupQueue.async {
            let utilizationPercentage = self.getCacheUtilization()
            
            if utilizationPercentage > self.criticalThreshold {
                // Critical cleanup - remove 30% of cache
                self.performAggressiveCleanup()
            } else if utilizationPercentage > self.cleanupThreshold {
                // Smart cleanup - remove least valuable items
                self.performSmartCleanup()
            }
            
            self.calculateCacheSize()
            self.lastCleanupTime = Date()
        }
    }
    
    private func performSmartCleanup() {
        // Sort items by value score (access frequency, recency, size)
        let sortedItems = memoryCache.values.sorted { item1, item2 in
            let score1 = calculateItemValue(item1)
            let score2 = calculateItemValue(item2)
            return score1 < score2
        }
        
        // Remove bottom 15% of items
        let itemsToRemove = Int(Double(sortedItems.count) * 0.15)
        let itemsForRemoval = Array(sortedItems.prefix(itemsToRemove))
        
        for item in itemsForRemoval {
            removeItem(key: item.key)
        }
    }
    
    private func performAggressiveCleanup() {
        // Remove items older than 24 hours and least frequently accessed
        let oneDayAgo = Date().addingTimeInterval(-24 * 3600)
        let oldItems = memoryCache.values.filter { $0.lastAccessed < oneDayAgo }
        
        for item in oldItems {
            removeItem(key: item.key)
        }
        
        // If still over limit, remove by size (largest first)
        if getCacheUtilization() > cleanupThreshold {
            let sortedBySize = memoryCache.values.sorted { $0.size > $1.size }
            let itemsToRemove = Int(Double(sortedBySize.count) * 0.3)
            
            for item in sortedBySize.prefix(itemsToRemove) {
                removeItem(key: item.key)
            }
        }
    }
    
    private func performBackgroundCleanup() async {
        await cleanupExpiredItems()
        await optimizeCacheStructure()
        saveAccessPatterns()
    }
    
    private func cleanupExpiredItems() async {
        let expirationDate = Date().addingTimeInterval(-maxOfflineDataAge)
        
        let expiredItems = memoryCache.values.filter { $0.createdAt < expirationDate }
        for item in expiredItems {
            removeItem(key: item.key)
        }
    }
    
    private func optimizeCacheStructure() async {
        // Rebuild memory cache from most valuable disk items
        if memoryCache.count > 1000 {
            let valuableItems = memoryCache.values
                .sorted { calculateItemValue($0) > calculateItemValue($1) }
                .prefix(500)
            
            memoryCache.removeAll()
            
            for item in valuableItems {
                memoryCache[item.key] = item
            }
        }
    }
    
    private func removeItem(key: String) {
        if let item = memoryCache[key] {
            cacheSize -= item.size
            memoryCache.removeValue(forKey: key)
            diskCache.remove(key: key)
            accessPatterns.removeValue(forKey: key)
        }
    }
    
    // MARK: - Cache Statistics
    private func calculateItemValue(_ item: CachedItem) -> Double {
        let pattern = accessPatterns[item.key]
        let frequency = Double(pattern?.accessCount ?? 1)
        let recency = Date().timeIntervalSince(item.lastAccessed)
        let sizePenalty = Double(item.size) / 1024.0 // Size in KB
        
        // Higher frequency and more recent access = higher value
        // Larger size = lower value
        return (frequency * 100.0) / (recency / 3600.0 + 1.0) - (sizePenalty / 100.0)
    }
    
    private func updateAccessPattern(for key: String) {
        if var pattern = accessPatterns[key] {
            pattern.accessCount += 1
            pattern.lastAccessed = Date()
            accessPatterns[key] = pattern
        } else {
            accessPatterns[key] = CacheAccessPattern(
                key: key,
                accessCount: 1,
                firstAccessed: Date(),
                lastAccessed: Date()
            )
        }
    }
    
    private func updateCacheStats(operation: CacheOperation, hit: Bool) {
        cacheStats.totalOperations += 1
        if hit {
            cacheStats.hits += 1
        } else {
            cacheStats.misses += 1
        }
        cacheStats.lastOperation = operation
        cacheStats.lastOperationTime = Date()
    }
    
    // MARK: - Public API
    public func clearCache() async {
        await cacheQueue.async {
            self.memoryCache.removeAll()
            self.diskCache.clearAll()
            self.cacheSize = 0
            self.accessPatterns.removeAll()
            self.cacheStats = CacheStatistics()
        }
        
        updateOfflineAvailability()
        print("🗑️ Cache cleared")
    }
    
    public func getCacheSize() async -> Int64 {
        return cacheSize
    }
    
    public func getHitRate() async -> Double {
        return cacheStats.hitRate
    }
    
    public func getCacheUtilization() -> Double {
        return Double(cacheSize) / Double(maxCacheSize)
    }
    
    public func getCacheInfo() -> CacheInfo {
        return CacheInfo(
            totalSize: cacheSize,
            maxSize: maxCacheSize,
            itemCount: memoryCache.count,
            hitRate: cacheStats.hitRate,
            status: cacheStatus,
            isOfflineMode: isOfflineModeEnabled,
            offlineAvailability: offlineAvailability,
            lastCleanup: lastCleanupTime
        )
    }
    
    public func optimizeCache() async {
        await performIntelligentCleanup()
        await optimizeCacheStructure()
        updateCacheHealth()
        print("🚀 Cache optimization completed")
    }
    
    // MARK: - Helper Methods
    private func getAllCachedStreams() async -> [Stream] {
        let streamItems = memoryCache.values.filter { $0.type == .stream }
        return streamItems.compactMap { item in
            guard let data = item.data else { return nil }
            return try? JSONDecoder().decode(Stream.self, from: data)
        }
    }
    
    private func getAllCachedFavorites() async -> [Favorite] {
        let favoriteItems = memoryCache.values.filter { $0.type == .favorites }
        return favoriteItems.flatMap { item -> [Favorite] in
            guard let data = item.data else { return [] }
            return (try? JSONDecoder().decode([Favorite].self, from: data)) ?? []
        }
    }
    
    private func getAllCachedLayouts() async -> [Layout] {
        let layoutItems = memoryCache.values.filter { $0.type == .layout }
        return layoutItems.compactMap { item in
            guard let data = item.data else { return nil }
            return try? JSONDecoder().decode(Layout.self, from: data)
        }
    }
    
    private func getAllCachedUserData() async -> [User] {
        let userItems = memoryCache.values.filter { $0.type == .userData }
        return userItems.compactMap { item in
            guard let data = item.data else { return nil }
            return try? JSONDecoder().decode(User.self, from: data)
        }
    }
    
    private func getAllCachedThumbnails() async -> [Data] {
        let thumbnailItems = memoryCache.values.filter { $0.type == .thumbnail }
        return thumbnailItems.compactMap { $0.data }
    }
    
    // MARK: - Size Estimation
    private func estimateStreamSize(_ stream: Stream) -> Int64 {
        let baseSize: Int64 = 2048 // 2KB base
        let titleSize = Int64(stream.title.utf8.count)
        let descriptionSize = Int64((stream.description?.utf8.count ?? 0))
        let metadataSize = Int64(stream.metadata.values.reduce(0) { $0 + $1.utf8.count })
        
        return baseSize + titleSize + descriptionSize + metadataSize
    }
    
    private func estimateFavoritesSize(_ favorites: [Favorite]) -> Int64 {
        return Int64(favorites.count * 1024) // Estimate 1KB per favorite
    }
    
    private func estimateLayoutSize(_ layout: Layout) -> Int64 {
        let configSize = (try? JSONEncoder().encode(layout.configuration).count) ?? 0
        return Int64(2048 + configSize) // 2KB base + config
    }
    
    private func estimateUserSize(_ user: User) -> Int64 {
        let baseSize: Int64 = 1024 // 1KB base
        let emailSize = Int64(user.email.utf8.count)
        let nameSize = Int64((user.firstName?.utf8.count ?? 0) + (user.lastName?.utf8.count ?? 0))
        
        return baseSize + emailSize + nameSize
    }
    
    // MARK: - Metadata Caching
    private func cacheStreamMetadata(_ stream: Stream) async {
        let metadata = StreamCacheMetadata(
            streamId: stream.id,
            title: stream.title,
            platform: stream.platform.rawValue,
            isLive: stream.isLive,
            viewerCount: stream.viewerCount,
            lastUpdated: Date()
        )
        
        let item = CachedItem(
            key: "metadata_\(stream.id)",
            data: try? JSONEncoder().encode(metadata),
            type: .metadata,
            size: Int64(MemoryLayout.size(ofValue: metadata)),
            createdAt: Date(),
            lastAccessed: Date(),
            metadata: ["streamId": stream.id]
        )
        
        await cacheItem(item)
    }
    
    // MARK: - Periodic Tasks
    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.performIntelligentCleanup()
            }
        }
    }
    
    private func calculateCacheSize() {
        cacheSize = memoryCache.values.reduce(0) { $0 + $1.size }
        updateCacheHealth()
    }
    
    private func updateCacheHealth() {
        let utilization = getCacheUtilization()
        
        if utilization > 0.9 {
            cacheStatus = .critical
        } else if utilization > 0.7 {
            cacheStatus = .warning
        } else if memoryCache.isEmpty {
            cacheStatus = .empty
        } else {
            cacheStatus = .healthy
        }
    }
    
    // MARK: - Persistence
    private func saveAccessPatterns() {
        do {
            let data = try JSONEncoder().encode(accessPatterns)
            UserDefaults.standard.set(data, forKey: "CacheAccessPatterns")
        } catch {
            print("❌ Failed to save access patterns: \(error)")
        }
    }
    
    private func loadAccessPatterns() {
        guard let data = UserDefaults.standard.data(forKey: "CacheAccessPatterns") else { return }
        
        do {
            accessPatterns = try JSONDecoder().decode([String: CacheAccessPattern].self, from: data)
        } catch {
            print("❌ Failed to load access patterns: \(error)")
        }
    }
    
    private func loadCacheStatistics() {
        // Load cache statistics from UserDefaults or file
        if let data = UserDefaults.standard.data(forKey: "CacheStatistics") {
            do {
                cacheStats = try JSONDecoder().decode(CacheStatistics.self, from: data)
            } catch {
                print("❌ Failed to load cache statistics: \(error)")
            }
        }
    }
    
    deinit {
        saveAccessPatterns()
    }
}

// MARK: - Supporting Types

public struct CachedItem {
    public let key: String
    public let data: Data?
    public let type: CacheItemType
    public let size: Int64
    public let createdAt: Date
    public var lastAccessed: Date
    public let metadata: [String: String]
}

public enum CacheItemType: String, Codable {
    case stream = "stream"
    case favorites = "favorites"
    case layout = "layout"
    case userData = "userData"
    case thumbnail = "thumbnail"
    case metadata = "metadata"
}

public enum CacheHealthStatus {
    case healthy
    case warning
    case critical
    case empty
    
    public var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .empty: return "Empty"
        }
    }
    
    public var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        case .empty: return .gray
        }
    }
}

public enum OfflineAvailability {
    case none
    case partial
    case full
    
    public var displayName: String {
        switch self {
        case .none: return "No Offline Data"
        case .partial: return "Some Offline Data"
        case .full: return "Full Offline Support"
        }
    }
}

public struct CacheAccessPattern: Codable {
    public let key: String
    public var accessCount: Int
    public let firstAccessed: Date
    public var lastAccessed: Date
}

public struct CacheStatistics: Codable {
    public var totalOperations: Int = 0
    public var hits: Int = 0
    public var misses: Int = 0
    public var lastOperation: CacheOperation = .retrieve
    public var lastOperationTime: Date?
    
    public var hitRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(hits) / Double(totalOperations) * 100
    }
}

public enum CacheOperation: String, Codable {
    case cache = "cache"
    case retrieve = "retrieve"
    case remove = "remove"
    case cleanup = "cleanup"
}

public struct CacheInfo {
    public let totalSize: Int64
    public let maxSize: Int64
    public let itemCount: Int
    public let hitRate: Double
    public let status: CacheHealthStatus
    public let isOfflineMode: Bool
    public let offlineAvailability: OfflineAvailability
    public let lastCleanup: Date?
    
    public var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    public var utilizationPercentage: Double {
        return Double(totalSize) / Double(maxSize) * 100
    }
}

public struct OfflineDataBundle: Codable {
    public let streams: [Stream]
    public let favorites: [Favorite]
    public let layouts: [Layout]
    public let userData: [User]
    public let thumbnails: [Data]
    public let preparedAt: Date
}

public struct StreamCacheMetadata: Codable {
    public let streamId: String
    public let title: String
    public let platform: String
    public let isLive: Bool
    public let viewerCount: Int
    public let lastUpdated: Date
}

// MARK: - Disk Cache Manager
private class DiskCacheManager {
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
    }
    
    func store(_ item: CachedItem) {
        let fileURL = cacheDirectory.appendingPathComponent("\(item.key).cache")
        
        do {
            let data = try JSONEncoder().encode(CacheFileWrapper(item: item))
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to store cache item: \(error)")
        }
    }
    
    func retrieve(key: String) -> CachedItem? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let wrapper = try JSONDecoder().decode(CacheFileWrapper.self, from: data)
            return wrapper.item
        } catch {
            return nil
        }
    }
    
    func remove(key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Offline Data Manager
private class OfflineDataManager {
    private let offlineDirectory: URL
    private let bundleFileName = "offline_bundle.json"
    
    init(offlineDirectory: URL) {
        self.offlineDirectory = offlineDirectory
    }
    
    func storeOfflineBundle(_ bundle: OfflineDataBundle) async {
        let fileURL = offlineDirectory.appendingPathComponent(bundleFileName)
        
        do {
            let data = try JSONEncoder().encode(bundle)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to store offline bundle: \(error)")
        }
    }
    
    func getOfflineBundle() async -> OfflineDataBundle? {
        let fileURL = offlineDirectory.appendingPathComponent(bundleFileName)
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(OfflineDataBundle.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Cache File Wrapper
private struct CacheFileWrapper: Codable {
    let item: CachedItem
    
    enum CodingKeys: String, CodingKey {
        case key, data, type, size, createdAt, lastAccessed, metadata
    }
    
    init(item: CachedItem) {
        self.item = item
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let key = try container.decode(String.self, forKey: .key)
        let data = try container.decodeIfPresent(Data.self, forKey: .data)
        let type = try container.decode(CacheItemType.self, forKey: .type)
        let size = try container.decode(Int64.self, forKey: .size)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let lastAccessed = try container.decode(Date.self, forKey: .lastAccessed)
        let metadata = try container.decode([String: String].self, forKey: .metadata)
        
        item = CachedItem(
            key: key,
            data: data,
            type: type,
            size: size,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            metadata: metadata
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(item.key, forKey: .key)
        try container.encodeIfPresent(item.data, forKey: .data)
        try container.encode(item.type, forKey: .type)
        try container.encode(item.size, forKey: .size)
        try container.encode(item.createdAt, forKey: .createdAt)
        try container.encode(item.lastAccessed, forKey: .lastAccessed)
        try container.encode(item.metadata, forKey: .metadata)
    }
}

// MARK: - Legacy Compatibility
public typealias StreamCacheService = CacheService