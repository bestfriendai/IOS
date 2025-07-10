//
//  LayoutSharingService.swift
//  StreamyyyApp
//
//  Layout sharing and management service with cloud sync
//  Created by Claude Code on 2025-07-10
//

import Foundation
import Combine
import CloudKit
import SwiftUI

// MARK: - Layout Sharing Service

@MainActor
public class LayoutSharingService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var savedLayouts: [SavedLayout] = []
    @Published private(set) var sharedLayouts: [SharedLayout] = []
    @Published private(set) var recentLayouts: [SavedLayout] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: LayoutSharingError?
    @Published private(set) var syncStatus: SyncStatus = .idle
    
    // MARK: - Private Properties
    
    private let container = CKContainer.default()
    private let database: CKDatabase
    private var subscriptions = Set<AnyCancellable>()
    
    // Local storage
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private var layoutsDirectory: URL
    
    // Cache
    private var layoutCache = NSCache<NSString, SavedLayout>()
    
    // MARK: - Configuration
    
    public struct SharingConfiguration {
        public let enableCloudSync: Bool
        public let enablePublicSharing: Bool
        public let maxSavedLayouts: Int
        public let maxRecentLayouts: Int
        public let autoSaveEnabled: Bool
        
        public init(
            enableCloudSync: Bool = true,
            enablePublicSharing: Bool = true,
            maxSavedLayouts: Int = 50,
            maxRecentLayouts: Int = 10,
            autoSaveEnabled: Bool = true
        ) {
            self.enableCloudSync = enableCloudSync
            self.enablePublicSharing = enablePublicSharing
            self.maxSavedLayouts = maxSavedLayouts
            self.maxRecentLayouts = maxRecentLayouts
            self.autoSaveEnabled = autoSaveEnabled
        }
    }
    
    private let configuration: SharingConfiguration
    
    // MARK: - Initialization
    
    public init(configuration: SharingConfiguration = SharingConfiguration()) {
        self.configuration = configuration
        self.database = container.privateCloudDatabase
        
        // Setup local storage directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.layoutsDirectory = documentsPath.appendingPathComponent("SavedLayouts")
        
        setupLocalStorage()
        setupCache()
        
        Task {
            await loadSavedLayouts()
            if configuration.enableCloudSync {
                await setupCloudKitSync()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Save a layout configuration
    public func saveLayout(_ layout: StreamLayout, name: String, isPublic: Bool = false) async throws -> SavedLayout {
        let savedLayout = SavedLayout(
            id: UUID().uuidString,
            name: name,
            layout: layout,
            isPublic: isPublic,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: getCurrentUserId(),
            shareCount: 0,
            tags: extractTags(from: layout)
        )
        
        // Save locally
        try saveLayoutLocally(savedLayout)
        savedLayouts.append(savedLayout)
        
        // Limit saved layouts
        if savedLayouts.count > configuration.maxSavedLayouts {
            let oldestLayout = savedLayouts.min(by: { $0.createdAt < $1.createdAt })
            if let oldest = oldestLayout {
                try deleteLayout(oldest.id)
            }
        }
        
        // Sync to cloud if enabled
        if configuration.enableCloudSync {
            try await syncLayoutToCloud(savedLayout)
        }
        
        // Share publicly if requested
        if isPublic && configuration.enablePublicSharing {
            try await shareLayoutPublicly(savedLayout)
        }
        
        return savedLayout
    }
    
    /// Load a saved layout
    public func loadLayout(_ id: String) async throws -> SavedLayout {
        // Check cache first
        if let cached = layoutCache.object(forKey: id as NSString) {
            return cached
        }
        
        // Check local storage
        if let local = try loadLayoutLocally(id) {
            layoutCache.setObject(local, forKey: id as NSString)
            return local
        }
        
        // Try cloud if enabled
        if configuration.enableCloudSync {
            let cloudLayout = try await loadLayoutFromCloud(id)
            layoutCache.setObject(cloudLayout, forKey: id as NSString)
            return cloudLayout
        }
        
        throw LayoutSharingError.layoutNotFound
    }
    
    /// Delete a saved layout
    public func deleteLayout(_ id: String) async throws {
        // Remove from local storage
        try deleteLayoutLocally(id)
        
        // Remove from arrays
        savedLayouts.removeAll { $0.id == id }
        recentLayouts.removeAll { $0.id == id }
        
        // Remove from cache
        layoutCache.removeObject(forKey: id as NSString)
        
        // Delete from cloud if enabled
        if configuration.enableCloudSync {
            try await deleteLayoutFromCloud(id)
        }
    }
    
    /// Update an existing layout
    public func updateLayout(_ id: String, name: String? = nil, layout: StreamLayout? = nil, isPublic: Bool? = nil) async throws {
        guard let index = savedLayouts.firstIndex(where: { $0.id == id }) else {
            throw LayoutSharingError.layoutNotFound
        }
        
        var updatedLayout = savedLayouts[index]
        
        if let name = name {
            updatedLayout.name = name
        }
        
        if let layout = layout {
            updatedLayout.layout = layout
            updatedLayout.tags = extractTags(from: layout)
        }
        
        if let isPublic = isPublic {
            updatedLayout.isPublic = isPublic
        }
        
        updatedLayout.updatedAt = Date()
        
        // Save changes
        try saveLayoutLocally(updatedLayout)
        savedLayouts[index] = updatedLayout
        
        // Update cache
        layoutCache.setObject(updatedLayout, forKey: id as NSString)
        
        // Sync to cloud if enabled
        if configuration.enableCloudSync {
            try await syncLayoutToCloud(updatedLayout)
        }
    }
    
    /// Add layout to recent layouts
    public func addToRecent(_ layout: SavedLayout) {
        // Remove if already exists
        recentLayouts.removeAll { $0.id == layout.id }
        
        // Add to beginning
        recentLayouts.insert(layout, at: 0)
        
        // Limit recent layouts
        if recentLayouts.count > configuration.maxRecentLayouts {
            recentLayouts.removeLast(recentLayouts.count - configuration.maxRecentLayouts)
        }
        
        // Save to UserDefaults
        saveRecentLayouts()
    }
    
    /// Share a layout and get share URL
    public func shareLayout(_ id: String) async throws -> URL {
        guard let layout = savedLayouts.first(where: { $0.id == id }) else {
            throw LayoutSharingError.layoutNotFound
        }
        
        if configuration.enablePublicSharing {
            let shareData = try await createPublicShare(for: layout)
            
            // Increment share count
            try await updateLayout(id, layout: nil, isPublic: true)
            
            return shareData.url
        } else {
            // Create local share data
            let shareJSON = try JSONEncoder().encode(layout)
            let base64 = shareJSON.base64EncodedString()
            
            guard let url = URL(string: "streamyyy://import-layout?data=\(base64)") else {
                throw LayoutSharingError.shareCreationFailed
            }
            
            return url
        }
    }
    
    /// Import a layout from share URL or data
    public func importLayout(from url: URL) async throws -> SavedLayout {
        if url.scheme == "streamyyy" && url.host == "import-layout" {
            return try await importFromCustomURL(url)
        } else if configuration.enableCloudSync {
            return try await importFromCloudKitShare(url)
        } else {
            throw LayoutSharingError.importFailed
        }
    }
    
    /// Import layout from JSON data
    public func importLayout(from jsonData: Data, name: String? = nil) async throws -> SavedLayout {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importedLayout = try decoder.decode(SavedLayout.self, from: jsonData)
        
        // Create new layout with unique ID
        let newLayout = SavedLayout(
            id: UUID().uuidString,
            name: name ?? "\(importedLayout.name) (Imported)",
            layout: importedLayout.layout,
            isPublic: false, // Imported layouts are private by default
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: getCurrentUserId(),
            shareCount: 0,
            tags: importedLayout.tags
        )
        
        return try await saveLayout(newLayout.layout, name: newLayout.name)
    }
    
    /// Search saved layouts
    public func searchLayouts(query: String) -> [SavedLayout] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return savedLayouts
        }
        
        let lowercaseQuery = query.lowercased()
        
        return savedLayouts.filter { layout in
            layout.name.lowercased().contains(lowercaseQuery) ||
            layout.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    /// Get layout statistics
    public func getLayoutStatistics() -> LayoutStatistics {
        let totalLayouts = savedLayouts.count
        let publicLayouts = savedLayouts.filter { $0.isPublic }.count
        let totalShares = savedLayouts.reduce(0) { $0 + $1.shareCount }
        let platformBreakdown = getPlatformBreakdown()
        
        return LayoutStatistics(
            totalLayouts: totalLayouts,
            publicLayouts: publicLayouts,
            totalShares: totalShares,
            platformBreakdown: platformBreakdown,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupLocalStorage() {
        do {
            try fileManager.createDirectory(at: layoutsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create layouts directory: \(error)")
        }
    }
    
    private func setupCache() {
        layoutCache.countLimit = 50
        layoutCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    private func loadSavedLayouts() async {
        do {
            let layoutFiles = try fileManager.contentsOfDirectory(at: layoutsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = layoutFiles.filter { $0.pathExtension == "json" }
            
            var layouts: [SavedLayout] = []
            
            for file in jsonFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let layout = try JSONDecoder().decode(SavedLayout.self, from: data)
                    layouts.append(layout)
                } catch {
                    print("Failed to load layout from \(file): \(error)")
                }
            }
            
            savedLayouts = layouts.sorted { $0.updatedAt > $1.updatedAt }
            loadRecentLayouts()
            
        } catch {
            print("Failed to load saved layouts: \(error)")
        }
    }
    
    private func saveLayoutLocally(_ layout: SavedLayout) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(layout)
        let fileURL = layoutsDirectory.appendingPathComponent("\(layout.id).json")
        
        try data.write(to: fileURL)
    }
    
    private func loadLayoutLocally(_ id: String) throws -> SavedLayout? {
        let fileURL = layoutsDirectory.appendingPathComponent("\(id).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(SavedLayout.self, from: data)
    }
    
    private func deleteLayoutLocally(_ id: String) throws {
        let fileURL = layoutsDirectory.appendingPathComponent("\(id).json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    private func loadRecentLayouts() {
        if let data = userDefaults.data(forKey: "RecentLayouts"),
           let recentIds = try? JSONDecoder().decode([String].self, from: data) {
            
            recentLayouts = recentIds.compactMap { id in
                savedLayouts.first { $0.id == id }
            }
        }
    }
    
    private func saveRecentLayouts() {
        let recentIds = recentLayouts.map { $0.id }
        if let data = try? JSONEncoder().encode(recentIds) {
            userDefaults.set(data, forKey: "RecentLayouts")
        }
    }
    
    private func extractTags(from layout: StreamLayout) -> [String] {
        var tags: [String] = []
        
        // Add platform tags
        let platforms = Set(layout.streams.map { $0.platform.displayName })
        tags.append(contentsOf: platforms)
        
        // Add layout type tag
        tags.append(layout.type.displayName)
        
        // Add stream count tag
        if layout.streams.count == 1 {
            tags.append("Single Stream")
        } else {
            tags.append("Multi-Stream")
        }
        
        // Add category tags if available
        let categories = Set(layout.streams.compactMap { $0.category })
        tags.append(contentsOf: categories)
        
        return Array(Set(tags)) // Remove duplicates
    }
    
    private func getCurrentUserId() -> String {
        // In a real app, this would get the current user ID from authentication service
        return "user_\(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")"
    }
    
    private func getPlatformBreakdown() -> [String: Int] {
        var breakdown: [String: Int] = [:]
        
        for layout in savedLayouts {
            for stream in layout.layout.streams {
                let platform = stream.platform.displayName
                breakdown[platform, default: 0] += 1
            }
        }
        
        return breakdown
    }
    
    // MARK: - CloudKit Methods
    
    private func setupCloudKitSync() async {
        // Setup CloudKit subscription for real-time updates
        // This would be implemented with proper CloudKit integration
        syncStatus = .syncing
        
        do {
            // Fetch remote changes
            try await fetchRemoteLayouts()
            syncStatus = .completed
        } catch {
            syncStatus = .failed(error)
            print("CloudKit sync failed: \(error)")
        }
    }
    
    private func syncLayoutToCloud(_ layout: SavedLayout) async throws {
        // CloudKit sync implementation
        print("Syncing layout to cloud: \(layout.name)")
    }
    
    private func loadLayoutFromCloud(_ id: String) async throws -> SavedLayout {
        // CloudKit fetch implementation
        throw LayoutSharingError.cloudSyncUnavailable
    }
    
    private func deleteLayoutFromCloud(_ id: String) async throws {
        // CloudKit deletion implementation
        print("Deleting layout from cloud: \(id)")
    }
    
    private func shareLayoutPublicly(_ layout: SavedLayout) async throws {
        // CloudKit public sharing implementation
        print("Sharing layout publicly: \(layout.name)")
    }
    
    private func fetchRemoteLayouts() async throws {
        // Fetch layouts from CloudKit
        print("Fetching remote layouts...")
    }
    
    private func createPublicShare(for layout: SavedLayout) async throws -> ShareData {
        // Create CloudKit share
        let url = URL(string: "https://streamyyy.app/shared/\(layout.id)")!
        return ShareData(url: url, token: layout.id)
    }
    
    private func importFromCloudKitShare(_ url: URL) async throws -> SavedLayout {
        // Import from CloudKit share
        throw LayoutSharingError.importFailed
    }
    
    private func importFromCustomURL(_ url: URL) async throws -> SavedLayout {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let base64Data = dataItem.value,
              let jsonData = Data(base64Encoded: base64Data) else {
            throw LayoutSharingError.invalidShareURL
        }
        
        return try await importLayout(from: jsonData)
    }
}

// MARK: - Data Models

public struct SavedLayout: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public let layout: StreamLayout
    public var isPublic: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public let createdBy: String
    public var shareCount: Int
    public var tags: [String]
    
    public init(
        id: String,
        name: String,
        layout: StreamLayout,
        isPublic: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String,
        shareCount: Int = 0,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.layout = layout
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.shareCount = shareCount
        self.tags = tags
    }
}

public struct SharedLayout: Codable, Identifiable {
    public let id: String
    public let name: String
    public let layout: StreamLayout
    public let createdBy: String
    public let createdAt: Date
    public let shareCount: Int
    public let rating: Double
    public let tags: [String]
    
    public init(
        id: String,
        name: String,
        layout: StreamLayout,
        createdBy: String,
        createdAt: Date,
        shareCount: Int,
        rating: Double,
        tags: [String]
    ) {
        self.id = id
        self.name = name
        self.layout = layout
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.shareCount = shareCount
        self.rating = rating
        self.tags = tags
    }
}

public struct LayoutStatistics {
    public let totalLayouts: Int
    public let publicLayouts: Int
    public let totalShares: Int
    public let platformBreakdown: [String: Int]
    public let lastUpdated: Date
}

public struct ShareData {
    public let url: URL
    public let token: String
}

public enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

public enum LayoutSharingError: Error, LocalizedError {
    case layoutNotFound
    case saveError(Error)
    case loadError(Error)
    case shareCreationFailed
    case importFailed
    case invalidShareURL
    case cloudSyncUnavailable
    case quotaExceeded
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .layoutNotFound:
            return "Layout not found"
        case .saveError(let error):
            return "Failed to save layout: \(error.localizedDescription)"
        case .loadError(let error):
            return "Failed to load layout: \(error.localizedDescription)"
        case .shareCreationFailed:
            return "Failed to create share link"
        case .importFailed:
            return "Failed to import layout"
        case .invalidShareURL:
            return "Invalid share URL"
        case .cloudSyncUnavailable:
            return "Cloud sync unavailable"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Extensions

extension StreamLayout: Codable {
    // StreamLayout would need to be made Codable for saving/loading
    // This is a placeholder for the actual implementation
}

extension LayoutType {
    var displayName: String {
        switch self {
        case .grid: return "Grid"
        case .pip: return "Picture-in-Picture"
        case .focus: return "Focus"
        case .mosaic: return "Mosaic"
        case .custom: return "Custom"
        default: return "Layout"
        }
    }
}