//
//  StreamCacheManager.swift
//  StreamyyyApp
//
//  Cache management for streams with intelligent caching and offline support
//

import Foundation
import SwiftUI
import Combine

// MARK: - Stream Cache Manager
@MainActor
public class StreamCacheManager: ObservableObject {
    
    // MARK: - Properties
    public static let shared = StreamCacheManager()
    
    @Published public var cacheUpdates: [StreamCacheUpdate] = []
    @Published public var cacheSize: Int64 = 0
    @Published public var isOfflineMode: Bool = false
    @Published public var cacheStatus: CacheStatus = .healthy
    
    // Cache configuration
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 3600 // 7 days
    private let thumbnailCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let metadataCacheSize: Int64 = 50 * 1024 * 1024 // 50MB
    
    // Cache storage
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let thumbnailDirectory: URL
    private let metadataDirectory: URL
    
    // In-memory cache
    private var streamCache: [String: CachedStream] = [:]
    private var thumbnailCache: [String: CachedThumbnail] = [:]
    private var metadataCache: [String: CachedMetadata] = [:]
    
    // Cache queues
    private let cacheQueue = DispatchQueue(label: "stream.cache.queue", qos: .utility)
    private let thumbnailQueue = DispatchQueue(label: "thumbnail.cache.queue", qos: .utility)
    private let cleanupQueue = DispatchQueue(label: "cache.cleanup.queue", qos: .background)
    
    // Network session for downloads
    private let urlSession: URLSession
    
    // Cache statistics
    private var cacheStats = CacheStatistics()
    
    // MARK: - Initialization
    public init() {
        // Setup cache directories
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("StreamCache")
        self.thumbnailDirectory = cacheDirectory.appendingPathComponent("Thumbnails")
        self.metadataDirectory = cacheDirectory.appendingPathComponent("Metadata")
        
        // Configure URL session
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
        self.urlSession = URLSession(configuration: configuration)
        
        createCacheDirectories()
        loadCacheFromDisk()
        startCacheManagement()
    }
    
    // MARK: - Cache Setup
    private func createCacheDirectories() {
        let directories = [cacheDirectory, thumbnailDirectory, metadataDirectory]
        
        for directory in directories {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create cache directory: \(error)")
            }
        }
    }
    
    private func loadCacheFromDisk() {
        cacheQueue.async {
            self.loadStreamCache()
            self.loadThumbnailCache()
            self.loadMetadataCache()
            self.calculateCacheSize()
        }
    }
    
    private func startCacheManagement() {
        // Start periodic cleanup
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.performCacheCleanup()
        }
        
        // Start cache monitoring
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.monitorCacheHealth()
        }
    }
    
    // MARK: - Stream Caching
    public func cacheStream(_ stream: Stream) async {
        let cachedStream = CachedStream(
            stream: stream,
            cacheDate: Date(),
            lastAccessed: Date(),
            size: estimateStreamSize(stream)
        )
        
        await cacheQueue.async {
            self.streamCache[stream.id] = cachedStream
            self.saveStreamToDisk(cachedStream)
        }
        
        // Cache thumbnail if available
        if let thumbnailURL = stream.thumbnailURL {
            await cacheThumbnail(url: thumbnailURL, streamId: stream.id)
        }
        
        // Cache metadata
        await cacheMetadata(for: stream)
        
        // Update cache statistics
        updateCacheStats(operation: .streamCached, size: cachedStream.size)
        
        // Notify observers
        let update = StreamCacheUpdate(
            type: .streamAdded,
            stream: stream,
            streamId: stream.id,
            timestamp: Date()
        )
        
        await MainActor.run {
            cacheUpdates.append(update)
        }
    }
    
    public func updateStream(_ stream: Stream) async {
        guard let existingCache = streamCache[stream.id] else {
            await cacheStream(stream)
            return
        }
        
        let updatedCache = CachedStream(
            stream: stream,
            cacheDate: existingCache.cacheDate,
            lastAccessed: Date(),
            size: estimateStreamSize(stream)
        )
        
        await cacheQueue.async {
            self.streamCache[stream.id] = updatedCache
            self.saveStreamToDisk(updatedCache)
        }
        
        // Update thumbnail if changed
        if let thumbnailURL = stream.thumbnailURL {
            await cacheThumbnail(url: thumbnailURL, streamId: stream.id)
        }
        
        // Update metadata
        await cacheMetadata(for: stream)
        
        // Notify observers
        let update = StreamCacheUpdate(
            type: .streamUpdated,
            stream: stream,
            streamId: stream.id,
            timestamp: Date()
        )
        
        await MainActor.run {
            cacheUpdates.append(update)
        }
    }
    
    public func removeStream(id: String) async {
        await cacheQueue.async {
            if let cachedStream = self.streamCache[id] {
                self.streamCache.removeValue(forKey: id)
                self.removeStreamFromDisk(id: id)
                self.updateCacheStats(operation: .streamRemoved, size: cachedStream.size)
            }
        }
        
        // Remove associated thumbnail
        await removeThumbnail(streamId: id)
        
        // Remove associated metadata
        await removeMetadata(streamId: id)
        
        // Notify observers
        let update = StreamCacheUpdate(
            type: .streamRemoved,
            stream: nil,
            streamId: id,
            timestamp: Date()
        )
        
        await MainActor.run {
            cacheUpdates.append(update)
        }
    }
    
    public func getCachedStream(id: String) async -> Stream? {
        return await cacheQueue.sync {
            if let cachedStream = self.streamCache[id] {
                // Update last accessed time
                self.streamCache[id]?.lastAccessed = Date()
                return cachedStream.stream
            }
            return nil
        }
    }
    
    public func getCachedStreams() async -> [Stream] {
        return await cacheQueue.sync {
            return self.streamCache.values.map { $0.stream }
        }
    }
    
    // MARK: - Thumbnail Caching
    public func cacheThumbnail(url: String, streamId: String) async {
        guard let thumbnailURL = URL(string: url) else { return }
        
        do {
            let (data, _) = try await urlSession.data(from: thumbnailURL)
            
            let cachedThumbnail = CachedThumbnail(
                streamId: streamId,
                url: url,
                data: data,
                cacheDate: Date(),
                lastAccessed: Date(),
                size: Int64(data.count)
            )
            
            await thumbnailQueue.async {
                self.thumbnailCache[streamId] = cachedThumbnail
                self.saveThumbnailToDisk(cachedThumbnail)
            }
            
            updateCacheStats(operation: .thumbnailCached, size: cachedThumbnail.size)
            
        } catch {
            print("❌ Failed to cache thumbnail: \(error)")
        }
    }
    
    public func getCachedThumbnail(streamId: String) async -> Data? {
        return await thumbnailQueue.sync {
            if let cachedThumbnail = self.thumbnailCache[streamId] {
                // Update last accessed time
                self.thumbnailCache[streamId]?.lastAccessed = Date()
                return cachedThumbnail.data
            }
            return nil
        }
    }
    
    public func removeThumbnail(streamId: String) async {
        await thumbnailQueue.async {
            if let cachedThumbnail = self.thumbnailCache[streamId] {
                self.thumbnailCache.removeValue(forKey: streamId)
                self.removeThumbnailFromDisk(streamId: streamId)
                self.updateCacheStats(operation: .thumbnailRemoved, size: cachedThumbnail.size)
            }
        }
    }
    
    // MARK: - Metadata Caching
    public func cacheMetadata(for stream: Stream) async {
        let metadata = StreamMetadata(
            streamId: stream.id,
            title: stream.title,
            description: stream.description,
            streamerName: stream.streamerName,
            category: stream.category,
            tags: stream.tags,
            viewerCount: stream.viewerCount,
            isLive: stream.isLive,
            lastUpdated: Date()
        )
        
        let cachedMetadata = CachedMetadata(
            streamId: stream.id,
            metadata: metadata,
            cacheDate: Date(),
            lastAccessed: Date(),
            size: estimateMetadataSize(metadata)
        )
        
        await cacheQueue.async {
            self.metadataCache[stream.id] = cachedMetadata
            self.saveMetadataToDisk(cachedMetadata)
        }
        
        updateCacheStats(operation: .metadataCached, size: cachedMetadata.size)
    }
    
    public func getCachedMetadata(streamId: String) async -> StreamMetadata? {
        return await cacheQueue.sync {
            if let cachedMetadata = self.metadataCache[streamId] {
                // Update last accessed time
                self.metadataCache[streamId]?.lastAccessed = Date()
                return cachedMetadata.metadata
            }
            return nil
        }
    }
    
    public func removeMetadata(streamId: String) async {
        await cacheQueue.async {
            if let cachedMetadata = self.metadataCache[streamId] {
                self.metadataCache.removeValue(forKey: streamId)
                self.removeMetadataFromDisk(streamId: streamId)
                self.updateCacheStats(operation: .metadataRemoved, size: cachedMetadata.size)
            }
        }
    }
    
    // MARK: - Disk Operations
    private func saveStreamToDisk(_ cachedStream: CachedStream) {
        let fileURL = cacheDirectory.appendingPathComponent("\(cachedStream.stream.id).json")
        
        do {
            let data = try JSONEncoder().encode(cachedStream)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save stream to disk: \(error)")
        }
    }
    
    private func loadStreamCache() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs where fileURL.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let cachedStream = try JSONDecoder().decode(CachedStream.self, from: data)
                    streamCache[cachedStream.stream.id] = cachedStream
                } catch {
                    print("❌ Failed to load cached stream: \(error)")
                    // Remove corrupted file
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("❌ Failed to load stream cache: \(error)")
        }
    }
    
    private func removeStreamFromDisk(id: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(id).json")
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func saveThumbnailToDisk(_ cachedThumbnail: CachedThumbnail) {
        let fileURL = thumbnailDirectory.appendingPathComponent("\(cachedThumbnail.streamId)")
        
        do {
            try cachedThumbnail.data.write(to: fileURL)
        } catch {
            print("❌ Failed to save thumbnail to disk: \(error)")
        }
    }
    
    private func loadThumbnailCache() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: thumbnailDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
            
            for fileURL in fileURLs {
                let streamId = fileURL.lastPathComponent
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    
                    let cachedThumbnail = CachedThumbnail(
                        streamId: streamId,
                        url: "", // URL not stored on disk
                        data: data,
                        cacheDate: resourceValues.contentModificationDate ?? Date(),
                        lastAccessed: Date(),
                        size: Int64(resourceValues.fileSize ?? 0)
                    )
                    
                    thumbnailCache[streamId] = cachedThumbnail
                } catch {
                    print("❌ Failed to load cached thumbnail: \(error)")
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("❌ Failed to load thumbnail cache: \(error)")
        }
    }
    
    private func removeThumbnailFromDisk(streamId: String) {
        let fileURL = thumbnailDirectory.appendingPathComponent(streamId)
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func saveMetadataToDisk(_ cachedMetadata: CachedMetadata) {
        let fileURL = metadataDirectory.appendingPathComponent("\(cachedMetadata.streamId).json")
        
        do {
            let data = try JSONEncoder().encode(cachedMetadata)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save metadata to disk: \(error)")
        }
    }
    
    private func loadMetadataCache() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: metadataDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs where fileURL.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let cachedMetadata = try JSONDecoder().decode(CachedMetadata.self, from: data)
                    metadataCache[cachedMetadata.streamId] = cachedMetadata
                } catch {
                    print("❌ Failed to load cached metadata: \(error)")
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("❌ Failed to load metadata cache: \(error)")
        }
    }
    
    private func removeMetadataFromDisk(streamId: String) {
        let fileURL = metadataDirectory.appendingPathComponent("\(streamId).json")
        try? fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Cache Management
    private func calculateCacheSize() {
        var totalSize: Int64 = 0
        
        totalSize += streamCache.values.reduce(0) { $0 + $1.size }
        totalSize += thumbnailCache.values.reduce(0) { $0 + $1.size }
        totalSize += metadataCache.values.reduce(0) { $0 + $1.size }
        
        DispatchQueue.main.async {
            self.cacheSize = totalSize
        }
    }
    
    private func performCacheCleanup() {
        cleanupQueue.async {
            self.cleanupExpiredItems()
            self.cleanupOldItems()
            self.enforceMaxCacheSize()
            self.calculateCacheSize()
        }
    }
    
    private func cleanupExpiredItems() {
        let now = Date()
        let expirationDate = now.addingTimeInterval(-maxCacheAge)
        
        // Clean up expired streams
        let expiredStreams = streamCache.filter { $0.value.cacheDate < expirationDate }
        for (streamId, _) in expiredStreams {
            streamCache.removeValue(forKey: streamId)
            removeStreamFromDisk(id: streamId)
        }
        
        // Clean up expired thumbnails
        let expiredThumbnails = thumbnailCache.filter { $0.value.cacheDate < expirationDate }
        for (streamId, _) in expiredThumbnails {
            thumbnailCache.removeValue(forKey: streamId)
            removeThumbnailFromDisk(streamId: streamId)
        }
        
        // Clean up expired metadata
        let expiredMetadata = metadataCache.filter { $0.value.cacheDate < expirationDate }
        for (streamId, _) in expiredMetadata {
            metadataCache.removeValue(forKey: streamId)
            removeMetadataFromDisk(streamId: streamId)
        }
    }
    
    private func cleanupOldItems() {
        // Remove least recently used items if cache is too large
        if cacheSize > maxCacheSize {
            let sortedStreams = streamCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            let itemsToRemove = sortedStreams.prefix(streamCache.count / 4) // Remove 25% of items
            
            for (streamId, _) in itemsToRemove {
                streamCache.removeValue(forKey: streamId)
                removeStreamFromDisk(id: streamId)
            }
        }
    }
    
    private func enforceMaxCacheSize() {
        while cacheSize > maxCacheSize {
            // Remove the least recently used item
            if let lruStream = streamCache.min(by: { $0.value.lastAccessed < $1.value.lastAccessed }) {
                streamCache.removeValue(forKey: lruStream.key)
                removeStreamFromDisk(id: lruStream.key)
            } else {
                break
            }
        }
    }
    
    private func monitorCacheHealth() {
        let totalItems = streamCache.count + thumbnailCache.count + metadataCache.count
        let cacheUtilization = Double(cacheSize) / Double(maxCacheSize)
        
        if cacheUtilization > 0.9 {
            cacheStatus = .full
        } else if cacheUtilization > 0.7 {
            cacheStatus = .warning
        } else if totalItems == 0 {
            cacheStatus = .empty
        } else {
            cacheStatus = .healthy
        }
    }
    
    // MARK: - Offline Mode
    public func enableOfflineMode() {
        isOfflineMode = true
        print("📱 Offline mode enabled")
    }
    
    public func disableOfflineMode() {
        isOfflineMode = false
        print("📱 Offline mode disabled")
    }
    
    // MARK: - Cache Statistics
    private func updateCacheStats(operation: CacheOperation, size: Int64) {
        cacheStats.totalOperations += 1
        cacheStats.lastOperation = operation
        cacheStats.lastOperationTime = Date()
        
        switch operation {
        case .streamCached, .thumbnailCached, .metadataCached:
            cacheStats.cacheHits += 1
        case .streamRemoved, .thumbnailRemoved, .metadataRemoved:
            cacheStats.cacheMisses += 1
        }
        
        calculateCacheSize()
    }
    
    public func getCacheStatistics() -> CacheStatistics {
        return cacheStats
    }
    
    // MARK: - Utility Methods
    private func estimateStreamSize(_ stream: Stream) -> Int64 {
        // Estimate based on stream data
        let baseSize: Int64 = 1024 // 1KB base
        let titleSize = Int64(stream.title.count * 2)
        let descriptionSize = Int64((stream.description?.count ?? 0) * 2)
        let metadataSize = Int64(stream.metadata.values.reduce(0) { $0 + $1.count * 2 })
        
        return baseSize + titleSize + descriptionSize + metadataSize
    }
    
    private func estimateMetadataSize(_ metadata: StreamMetadata) -> Int64 {
        let titleSize = Int64(metadata.title.count * 2)
        let descriptionSize = Int64((metadata.description?.count ?? 0) * 2)
        let streamerSize = Int64((metadata.streamerName?.count ?? 0) * 2)
        let categorySize = Int64((metadata.category?.count ?? 0) * 2)
        let tagsSize = Int64(metadata.tags.reduce(0) { $0 + $1.count * 2 })
        
        return titleSize + descriptionSize + streamerSize + categorySize + tagsSize
    }
    
    // MARK: - Public API
    public func clearCache() async {
        await cacheQueue.async {
            self.streamCache.removeAll()
            self.thumbnailCache.removeAll()
            self.metadataCache.removeAll()
            
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            self.createCacheDirectories()
            
            self.cacheStats = CacheStatistics()
            self.calculateCacheSize()
        }
    }
    
    public func clearExpiredCache() async {
        await cleanupQueue.async {
            self.cleanupExpiredItems()
            self.calculateCacheSize()
        }
    }
    
    public func getCacheInfo() -> CacheInfo {
        return CacheInfo(
            totalSize: cacheSize,
            maxSize: maxCacheSize,
            streamCount: streamCache.count,
            thumbnailCount: thumbnailCache.count,
            metadataCount: metadataCache.count,
            status: cacheStatus,
            isOfflineMode: isOfflineMode
        )
    }
}

// MARK: - Cached Stream
public struct CachedStream: Codable {
    public let stream: Stream
    public let cacheDate: Date
    public var lastAccessed: Date
    public let size: Int64
}

// MARK: - Cached Thumbnail
public struct CachedThumbnail {
    public let streamId: String
    public let url: String
    public let data: Data
    public let cacheDate: Date
    public var lastAccessed: Date
    public let size: Int64
}

// MARK: - Cached Metadata
public struct CachedMetadata: Codable {
    public let streamId: String
    public let metadata: StreamMetadata
    public let cacheDate: Date
    public var lastAccessed: Date
    public let size: Int64
}

// MARK: - Stream Metadata
public struct StreamMetadata: Codable {
    public let streamId: String
    public let title: String
    public let description: String?
    public let streamerName: String?
    public let category: String?
    public let tags: [String]
    public let viewerCount: Int
    public let isLive: Bool
    public let lastUpdated: Date
}

// MARK: - Cache Update
public struct StreamCacheUpdate {
    public let type: CacheUpdateType
    public let stream: Stream?
    public let streamId: String?
    public let timestamp: Date
}

// MARK: - Cache Update Type
public enum CacheUpdateType {
    case streamAdded
    case streamUpdated
    case streamRemoved
    case thumbnailUpdated
    case metadataUpdated
}

// MARK: - Cache Status
public enum CacheStatus {
    case healthy
    case warning
    case full
    case empty
    case error
    
    public var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .full: return "Full"
        case .empty: return "Empty"
        case .error: return "Error"
        }
    }
    
    public var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .orange
        case .full: return .red
        case .empty: return .gray
        case .error: return .red
        }
    }
}

// MARK: - Cache Operation
public enum CacheOperation {
    case streamCached
    case streamRemoved
    case thumbnailCached
    case thumbnailRemoved
    case metadataCached
    case metadataRemoved
}

// MARK: - Cache Statistics
public struct CacheStatistics {
    public var totalOperations: Int = 0
    public var cacheHits: Int = 0
    public var cacheMisses: Int = 0
    public var lastOperation: CacheOperation?
    public var lastOperationTime: Date?
    
    public var hitRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(cacheHits) / Double(totalOperations) * 100
    }
}

// MARK: - Cache Info
public struct CacheInfo {
    public let totalSize: Int64
    public let maxSize: Int64
    public let streamCount: Int
    public let thumbnailCount: Int
    public let metadataCount: Int
    public let status: CacheStatus
    public let isOfflineMode: Bool
    
    public var utilizationPercentage: Double {
        guard maxSize > 0 else { return 0 }
        return Double(totalSize) / Double(maxSize) * 100
    }
    
    public var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    public var formattedMaxSize: String {
        return ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)
    }
}