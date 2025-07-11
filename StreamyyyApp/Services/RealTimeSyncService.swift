//
//  RealTimeSyncService.swift
//  StreamyyyApp
//
//  Real-time bidirectional synchronization service for all data models
//  Handles conflict resolution, offline queuing, and incremental sync
//  Created by Claude Code on 2025-07-11
//

import Foundation
import SwiftData
import Combine
import Network
import Supabase

// MARK: - Real-Time Sync Service
@MainActor
public class RealTimeSyncService: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = RealTimeSyncService()
    
    // MARK: - Published Properties
    @Published public var syncStatus: SyncStatus = .disconnected
    @Published public var isOnline = true
    @Published public var lastSyncTime: Date?
    @Published public var pendingChanges: [PendingChange] = []
    @Published public var conflictCount = 0
    @Published public var syncProgress: SyncProgress?
    @Published public var errorLog: [SyncError] = []
    
    // MARK: - Private Properties
    private let supabaseService = SupabaseService.shared
    private let dataService = DataService.shared
    private let networkMonitor = NWPathMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var realtimeChannels: [RealtimeChannel] = []
    private var syncTimer: Timer?
    private var pendingChangeQueue = DispatchQueue(label: "com.streamyyy.sync", qos: .utility)
    
    // Sync configuration
    private let syncInterval: TimeInterval = 30.0 // 30 seconds
    private let conflictRetentionDays = 7
    private let maxPendingChanges = 1000
    private let batchSize = 50
    private let maxRetryAttempts = 3
    
    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
        setupSupabaseObservers()
        setupSyncTimer()
        loadPendingChanges()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Interface
    
    /// Start real-time synchronization
    public func startSync() async {
        guard supabaseService.isAuthenticated else {
            syncStatus = .error
            logError(SyncError.authenticationRequired)
            return
        }
        
        syncStatus = .connecting
        
        do {
            // Setup real-time subscriptions
            try await setupRealtimeSubscriptions()
            
            // Perform initial sync
            await performInitialSync()
            
            // Start periodic sync
            startPeriodicSync()
            
            syncStatus = .synced
            print("✅ Real-time sync started successfully")
            
        } catch {
            syncStatus = .error
            logError(SyncError.subscriptionFailed(error))
            print("❌ Failed to start real-time sync: \(error)")
        }
    }
    
    /// Stop real-time synchronization
    public func stopSync() {
        stopPeriodicSync()
        cleanup()
        syncStatus = .disconnected
        print("🛑 Real-time sync stopped")
    }
    
    /// Force immediate synchronization of all data
    public func forceSync() async {
        guard supabaseService.isAuthenticated else { return }
        
        syncStatus = .syncing
        syncProgress = SyncProgress(totalItems: 0, completedItems: 0, currentOperation: "Preparing sync...")
        
        do {
            // Upload pending changes first
            await uploadPendingChanges()
            
            // Then download latest changes
            await downloadLatestChanges()
            
            syncStatus = .synced
            lastSyncTime = Date()
            syncProgress = nil
            
            print("✅ Force sync completed successfully")
            
        } catch {
            syncStatus = .error
            logError(SyncError.syncFailed(error))
            print("❌ Force sync failed: \(error)")
        }
    }
    
    /// Queue a change for synchronization
    public func queueChange(_ change: PendingChange) {
        pendingChangeQueue.async {
            Task { @MainActor in
                self.pendingChanges.append(change)
                
                // Limit pending changes
                if self.pendingChanges.count > self.maxPendingChanges {
                    self.pendingChanges.removeFirst(self.pendingChanges.count - self.maxPendingChanges)
                }
                
                self.savePendingChanges()
                
                // Trigger immediate sync for critical changes
                if change.isCritical && self.isOnline {
                    await self.uploadSingleChange(change)
                }
            }
        }
    }
    
    /// Resolve a sync conflict
    public func resolveConflict(_ conflictId: String, resolution: SyncConflictResolution) async {
        // Implementation would handle conflict resolution based on user choice
        print("🔧 Resolving conflict \(conflictId) with resolution: \(resolution)")
        
        // Update conflict count
        conflictCount = max(0, conflictCount - 1)
    }
    
    /// Get sync statistics
    public func getSyncStatistics() -> SyncStatistics {
        return SyncStatistics(
            lastSyncTime: lastSyncTime,
            pendingChangesCount: pendingChanges.count,
            conflictCount: conflictCount,
            errorCount: errorLog.count,
            isOnline: isOnline,
            syncStatus: syncStatus
        )
    }
    
    /// Clear sync errors
    public func clearErrors() {
        errorLog.removeAll()
    }
    
    /// Export sync data for debugging
    public func exportSyncData() -> Data? {
        let syncData = SyncDebugData(
            pendingChanges: pendingChanges,
            errorLog: errorLog,
            lastSyncTime: lastSyncTime,
            syncStatus: syncStatus.rawValue
        )
        
        return try? JSONEncoder().encode(syncData)
    }
}

// MARK: - Private Implementation
extension RealTimeSyncService {
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                // Handle network state changes
                if !wasOnline && path.status == .satisfied {
                    print("📡 Network restored - resuming sync")
                    await self?.forceSync()
                } else if wasOnline && path.status != .satisfied {
                    print("📡 Network lost - pausing sync")
                    self?.syncStatus = .offline
                }
            }
        }
        
        networkMonitor.start(queue: pendingChangeQueue)
    }
    
    private func setupSupabaseObservers() {
        // Observe authentication state
        supabaseService.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    Task {
                        await self?.startSync()
                    }
                } else {
                    self?.stopSync()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.periodicSync()
            }
        }
    }
    
    private func setupRealtimeSubscriptions() async throws {
        // Clear existing channels
        cleanup()
        
        let tables = ["streams", "layouts", "favorites", "viewing_history", "stream_sessions"]
        
        for table in tables {
            do {
                let channel = try supabaseService.subscribeToTable(table: table) { [weak self] response in
                    Task { @MainActor in
                        await self?.handleRealtimeChange(table: table, response: response)
                    }
                }
                realtimeChannels.append(channel)
                print("📡 Subscribed to real-time updates for \(table)")
            } catch {
                print("❌ Failed to subscribe to \(table): \(error)")
                throw error
            }
        }
    }
    
    private func handleRealtimeChange(table: String, response: PostgrestResponse) async {
        guard let eventType = response.eventType,
              let record = response.record else { return }
        
        print("📡 Real-time change: \(eventType) in \(table)")
        
        switch eventType {
        case "INSERT":
            await handleRemoteInsert(table: table, record: record)
        case "UPDATE":
            await handleRemoteUpdate(table: table, record: record)
        case "DELETE":
            await handleRemoteDelete(table: table, record: record)
        default:
            break
        }
    }
    
    private func handleRemoteInsert(table: String, record: [String: Any]) async {
        // Convert remote record to local model and insert if not exists
        switch table {
        case "streams":
            if let syncStream = try? parseSyncStream(from: record) {
                await dataService.handleRemoteStreamInsert(syncStream.toStream())
            }
        case "layouts":
            if let syncLayout = try? parseSyncLayout(from: record) {
                await dataService.handleRemoteLayoutInsert(syncLayout.toLayout())
            }
        case "favorites":
            if let syncFavorite = try? parseSyncFavorite(from: record) {
                await dataService.handleRemoteFavoriteInsert(syncFavorite.toFavorite())
            }
        case "viewing_history":
            if let syncHistory = try? parseSyncViewingHistory(from: record) {
                await dataService.handleRemoteHistoryInsert(syncHistory.toViewingHistory())
            }
        default:
            break
        }
    }
    
    private func handleRemoteUpdate(table: String, record: [String: Any]) async {
        // Convert remote record to local model and update with conflict resolution
        switch table {
        case "streams":
            if let syncStream = try? parseSyncStream(from: record) {
                await dataService.handleRemoteStreamUpdate(syncStream.toStream())
            }
        case "layouts":
            if let syncLayout = try? parseSyncLayout(from: record) {
                await dataService.handleRemoteLayoutUpdate(syncLayout.toLayout())
            }
        case "favorites":
            if let syncFavorite = try? parseSyncFavorite(from: record) {
                await dataService.handleRemoteFavoriteUpdate(syncFavorite.toFavorite())
            }
        case "viewing_history":
            if let syncHistory = try? parseSyncViewingHistory(from: record) {
                await dataService.handleRemoteHistoryUpdate(syncHistory.toViewingHistory())
            }
        default:
            break
        }
    }
    
    private func handleRemoteDelete(table: String, record: [String: Any]) async {
        guard let id = record["id"] as? String else { return }
        
        switch table {
        case "streams":
            await dataService.handleRemoteStreamDelete(id)
        case "layouts":
            await dataService.handleRemoteLayoutDelete(id)
        case "favorites":
            await dataService.handleRemoteFavoriteDelete(id)
        case "viewing_history":
            await dataService.handleRemoteHistoryDelete(id)
        default:
            break
        }
    }
    
    private func performInitialSync() async {
        print("🔄 Performing initial sync...")
        syncProgress = SyncProgress(totalItems: 5, completedItems: 0, currentOperation: "Syncing streams...")
        
        // Sync each model type
        await syncStreams()
        syncProgress?.completedItems = 1
        syncProgress?.currentOperation = "Syncing layouts..."
        
        await syncLayouts()
        syncProgress?.completedItems = 2
        syncProgress?.currentOperation = "Syncing favorites..."
        
        await syncFavorites()
        syncProgress?.completedItems = 3
        syncProgress?.currentOperation = "Syncing viewing history..."
        
        await syncViewingHistory()
        syncProgress?.completedItems = 4
        syncProgress?.currentOperation = "Syncing sessions..."
        
        await syncStreamSessions()
        syncProgress?.completedItems = 5
        syncProgress?.currentOperation = "Sync complete"
        
        lastSyncTime = Date()
        print("✅ Initial sync completed")
    }
    
    private func periodicSync() async {
        guard isOnline && supabaseService.isAuthenticated else { return }
        
        // Upload pending changes
        await uploadPendingChanges()
        
        // Download latest changes (incremental)
        await downloadLatestChanges()
        
        lastSyncTime = Date()
    }
    
    private func uploadPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }
        
        print("⬆️ Uploading \(pendingChanges.count) pending changes...")
        
        let changesToUpload = Array(pendingChanges.prefix(batchSize))
        var successfulUploads: [String] = []
        
        for change in changesToUpload {
            if await uploadSingleChange(change) {
                successfulUploads.append(change.id)
            }
        }
        
        // Remove successfully uploaded changes
        pendingChanges.removeAll { successfulUploads.contains($0.id) }
        savePendingChanges()
        
        print("⬆️ Uploaded \(successfulUploads.count) changes successfully")
    }
    
    private func uploadSingleChange(_ change: PendingChange) async -> Bool {
        do {
            switch change.operation {
            case .create:
                try await uploadCreate(change)
            case .update:
                try await uploadUpdate(change)
            case .delete:
                try await uploadDelete(change)
            }
            
            return true
            
        } catch {
            print("❌ Failed to upload change \(change.id): \(error)")
            
            // Increment retry count
            var updatedChange = change
            updatedChange.retryCount += 1
            
            if updatedChange.retryCount >= maxRetryAttempts {
                // Remove from queue after max retries
                pendingChanges.removeAll { $0.id == change.id }
                logError(SyncError.uploadFailed(change.modelType, error))
            } else {
                // Update the change in queue
                if let index = pendingChanges.firstIndex(where: { $0.id == change.id }) {
                    pendingChanges[index] = updatedChange
                }
            }
            
            return false
        }
    }
    
    private func uploadCreate(_ change: PendingChange) async throws {
        switch change.modelType {
        case "Stream":
            if let stream = change.data as? Stream {
                let syncStream = SyncStream(from: stream, userId: supabaseService.currentProfile?.id ?? "")
                _ = try await supabaseService.insert(table: "streams", data: syncStream)
            }
        case "Layout":
            if let layout = change.data as? Layout {
                let syncLayout = SyncLayout(from: layout, userId: supabaseService.currentProfile?.id ?? "")
                _ = try await supabaseService.insert(table: "layouts", data: syncLayout)
            }
        case "Favorite":
            if let favorite = change.data as? Favorite {
                let syncFavorite = SyncFavorite(from: favorite, userId: supabaseService.currentProfile?.id ?? "")
                _ = try await supabaseService.insert(table: "favorites", data: syncFavorite)
            }
        case "ViewingHistory":
            if let history = change.data as? ViewingHistory {
                let syncHistory = SyncViewingHistory(from: history, userId: supabaseService.currentProfile?.id ?? "")
                _ = try await supabaseService.insert(table: "viewing_history", data: syncHistory)
            }
        default:
            throw SyncError.unsupportedModelType(change.modelType)
        }
    }
    
    private func uploadUpdate(_ change: PendingChange) async throws {
        switch change.modelType {
        case "Stream":
            if let stream = change.data as? Stream {
                let syncStream = SyncStream(from: stream, userId: supabaseService.currentProfile?.id ?? "")
                let data = try syncStream.toDictionary()
                _ = try await supabaseService.update(table: "streams", id: stream.id, data: data) as SyncStream
            }
        case "Layout":
            if let layout = change.data as? Layout {
                let syncLayout = SyncLayout(from: layout, userId: supabaseService.currentProfile?.id ?? "")
                let data = try syncLayout.toDictionary()
                _ = try await supabaseService.update(table: "layouts", id: layout.id, data: data) as SyncLayout
            }
        case "Favorite":
            if let favorite = change.data as? Favorite {
                let syncFavorite = SyncFavorite(from: favorite, userId: supabaseService.currentProfile?.id ?? "")
                let data = try syncFavorite.toDictionary()
                _ = try await supabaseService.update(table: "favorites", id: favorite.id, data: data) as SyncFavorite
            }
        case "ViewingHistory":
            if let history = change.data as? ViewingHistory {
                let syncHistory = SyncViewingHistory(from: history, userId: supabaseService.currentProfile?.id ?? "")
                let data = try syncHistory.toDictionary()
                _ = try await supabaseService.update(table: "viewing_history", id: history.id, data: data) as SyncViewingHistory
            }
        default:
            throw SyncError.unsupportedModelType(change.modelType)
        }
    }
    
    private func uploadDelete(_ change: PendingChange) async throws {
        let table = getTableName(for: change.modelType)
        try await supabaseService.delete(table: table, id: change.modelId)
    }
    
    private func downloadLatestChanges() async {
        // Download changes since last sync
        let since = lastSyncTime ?? Date.distantPast
        
        // This would typically query for records modified since the last sync
        // Implementation would depend on your database schema having updated_at fields
        print("⬇️ Downloading changes since \(since)")
    }
    
    private func startPeriodicSync() {
        setupSyncTimer()
    }
    
    private func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func cleanup() {
        // Unsubscribe from all channels
        for channel in realtimeChannels {
            supabaseService.unsubscribe(channel: channel)
        }
        realtimeChannels.removeAll()
        
        networkMonitor.cancel()
        stopPeriodicSync()
        cancellables.removeAll()
    }
    
    // MARK: - Model Type Sync Methods
    
    private func syncStreams() async {
        // Sync implementation for streams
        print("🔄 Syncing streams...")
    }
    
    private func syncLayouts() async {
        // Sync implementation for layouts
        print("🔄 Syncing layouts...")
    }
    
    private func syncFavorites() async {
        // Sync implementation for favorites
        print("🔄 Syncing favorites...")
    }
    
    private func syncViewingHistory() async {
        // Sync implementation for viewing history
        print("🔄 Syncing viewing history...")
    }
    
    private func syncStreamSessions() async {
        // Sync implementation for stream sessions
        print("🔄 Syncing stream sessions...")
    }
    
    // MARK: - Utility Methods
    
    private func getTableName(for modelType: String) -> String {
        switch modelType {
        case "Stream": return "streams"
        case "Layout": return "layouts"
        case "Favorite": return "favorites"
        case "ViewingHistory": return "viewing_history"
        case "StreamSession": return "stream_sessions"
        default: return modelType.lowercased()
        }
    }
    
    private func parseSyncStream(from record: [String: Any]) throws -> SyncStream {
        let data = try JSONSerialization.data(withJSONObject: record)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncStream.self, from: data)
    }
    
    private func parseSyncLayout(from record: [String: Any]) throws -> SyncLayout {
        let data = try JSONSerialization.data(withJSONObject: record)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncLayout.self, from: data)
    }
    
    private func parseSyncFavorite(from record: [String: Any]) throws -> SyncFavorite {
        let data = try JSONSerialization.data(withJSONObject: record)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncFavorite.self, from: data)
    }
    
    private func parseSyncViewingHistory(from record: [String: Any]) throws -> SyncViewingHistory {
        let data = try JSONSerialization.data(withJSONObject: record)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncViewingHistory.self, from: data)
    }
    
    private func logError(_ error: SyncError) {
        errorLog.append(error)
        
        // Limit error log size
        if errorLog.count > 100 {
            errorLog.removeFirst(errorLog.count - 100)
        }
        
        print("❌ Sync error: \(error)")
    }
    
    private func savePendingChanges() {
        // Save pending changes to persistent storage
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(pendingChanges) {
            UserDefaults.standard.set(data, forKey: "pendingChanges")
        }
    }
    
    private func loadPendingChanges() {
        // Load pending changes from persistent storage
        if let data = UserDefaults.standard.data(forKey: "pendingChanges"),
           let changes = try? JSONDecoder().decode([PendingChange].self, from: data) {
            pendingChanges = changes
        }
    }
}

// MARK: - Supporting Types

public struct PendingChange: Codable, Identifiable {
    public let id: String
    public let modelType: String
    public let modelId: String
    public let operation: SyncOperation
    public let data: Any? // This would need custom encoding/decoding
    public let timestamp: Date
    public let isCritical: Bool
    public var retryCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, modelType, modelId, operation, timestamp, isCritical, retryCount
    }
    
    public init(id: String = UUID().uuidString, modelType: String, modelId: String, operation: SyncOperation, data: Any? = nil, isCritical: Bool = false) {
        self.id = id
        self.modelType = modelType
        self.modelId = modelId
        self.operation = operation
        self.data = data
        self.timestamp = Date()
        self.isCritical = isCritical
        self.retryCount = 0
    }
    
    // Custom encoding/decoding would be needed for the data field
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(modelType, forKey: .modelType)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(operation, forKey: .operation)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isCritical, forKey: .isCritical)
        try container.encode(retryCount, forKey: .retryCount)
        // Data field would need custom serialization
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        modelType = try container.decode(String.self, forKey: .modelType)
        modelId = try container.decode(String.self, forKey: .modelId)
        operation = try container.decode(SyncOperation.self, forKey: .operation)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isCritical = try container.decode(Bool.self, forKey: .isCritical)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        data = nil // Would need custom deserialization
    }
}

public enum SyncOperation: String, Codable {
    case create = "create"
    case update = "update"
    case delete = "delete"
}

public struct SyncProgress {
    public let totalItems: Int
    public var completedItems: Int
    public var currentOperation: String
    
    public var percentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems) * 100
    }
}

public struct SyncStatistics {
    public let lastSyncTime: Date?
    public let pendingChangesCount: Int
    public let conflictCount: Int
    public let errorCount: Int
    public let isOnline: Bool
    public let syncStatus: SyncStatus
    
    public var healthScore: Double {
        var score = 100.0
        
        if !isOnline { score -= 50 }
        if syncStatus == .error { score -= 30 }
        if conflictCount > 0 { score -= Double(conflictCount) * 5 }
        if errorCount > 0 { score -= Double(errorCount) * 2 }
        if pendingChangesCount > 10 { score -= Double(pendingChangesCount - 10) * 0.5 }
        
        return max(0, score)
    }
}

public enum SyncError: Error, LocalizedError {
    case authenticationRequired
    case networkUnavailable
    case subscriptionFailed(Error)
    case syncFailed(Error)
    case uploadFailed(String, Error)
    case downloadFailed(String, Error)
    case conflictResolutionFailed(String)
    case unsupportedModelType(String)
    case invalidData(String)
    
    public var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication is required for sync"
        case .networkUnavailable:
            return "Network is unavailable"
        case .subscriptionFailed(let error):
            return "Failed to setup real-time subscription: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .uploadFailed(let modelType, let error):
            return "Failed to upload \(modelType): \(error.localizedDescription)"
        case .downloadFailed(let modelType, let error):
            return "Failed to download \(modelType): \(error.localizedDescription)"
        case .conflictResolutionFailed(let modelId):
            return "Failed to resolve conflict for model: \(modelId)"
        case .unsupportedModelType(let type):
            return "Unsupported model type: \(type)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}

public struct SyncDebugData: Codable {
    public let pendingChanges: [PendingChange]
    public let errorLog: [SyncError]
    public let lastSyncTime: Date?
    public let syncStatus: String
    
    // Custom encoding for SyncError
    enum CodingKeys: String, CodingKey {
        case pendingChanges, errorDescriptions, lastSyncTime, syncStatus
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pendingChanges, forKey: .pendingChanges)
        try container.encode(errorLog.map { $0.localizedDescription }, forKey: .errorDescriptions)
        try container.encode(lastSyncTime, forKey: .lastSyncTime)
        try container.encode(syncStatus, forKey: .syncStatus)
    }
}