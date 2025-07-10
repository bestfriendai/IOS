//
//  StreamSyncManager.swift
//  StreamyyyApp
//
//  Comprehensive stream synchronization manager with real-time updates and conflict resolution
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import Network

// MARK: - Stream Sync Manager
@MainActor
public class StreamSyncManager: ObservableObject {
    
    // MARK: - Properties
    public static let shared = StreamSyncManager()
    
    @Published public var syncStatus: SyncStatus = .disconnected
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date?
    @Published public var syncProgress: Double = 0.0
    @Published public var pendingOperations: [SyncOperation] = []
    @Published public var conflictResolutions: [ConflictResolution] = []
    @Published public var isOnline: Bool = false
    @Published public var streams: [Stream] = []
    
    private let supabaseService = SupabaseService.shared
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Service integrations
    private let healthMonitor: StreamHealthMonitor
    private let cacheManager: StreamCacheManager
    private let validationService: StreamValidationService
    
    // Real-time subscriptions
    private var streamSubscription: RealtimeChannel?
    private var userSubscription: RealtimeChannel?
    
    // Sync queues
    private var syncQueue = DispatchQueue(label: "stream.sync.queue", qos: .userInitiated)
    private var operationQueue: [SyncOperation] = []
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "network.monitor")
    
    // Conflict resolution
    private let conflictResolver = ConflictResolver()
    
    // Sync statistics
    private var syncStats = SyncStats(
        userId: "",
        totalSyncs: 0,
        successfulSyncs: 0,
        failedSyncs: 0,
        lastSyncAt: nil,
        averageSyncTime: 0,
        dataTransferred: 0,
        conflictsResolved: 0,
        updatedAt: Date()
    )
    
    // MARK: - Initialization
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Initialize service dependencies
        self.healthMonitor = StreamHealthMonitor.shared
        self.cacheManager = StreamCacheManager.shared
        self.validationService = StreamValidationService.shared
        
        setupNetworkMonitoring()
        setupSupabaseObservers()
        setupServiceIntegrations()
        setupPeriodicSync()
        
        // Load pending operations from storage
        loadPendingOperations()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    self?.processPendingOperations()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Supabase Observers
    private func setupSupabaseObservers() {
        supabaseService.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
                if status == .connected {
                    self?.setupRealtimeSubscriptions()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Service Integrations
    private func setupServiceIntegrations() {
        // Observe health monitor updates
        healthMonitor.$healthUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] healthUpdates in
                self?.handleHealthUpdates(healthUpdates)
            }
            .store(in: &cancellables)
        
        // Observe cache updates
        cacheManager.$cacheUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cacheUpdates in
                self?.handleCacheUpdates(cacheUpdates)
            }
            .store(in: &cancellables)
        
        // Observe validation service updates
        validationService.$lastValidationResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] validationResult in
                self?.handleValidationResult(validationResult)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Periodic Sync
    private func setupPeriodicSync() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.performPeriodicSync()
            }
        }
    }
    
    // MARK: - Real-time Subscriptions
    private func setupRealtimeSubscriptions() {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        // Subscribe to streams table
        do {
            streamSubscription = try supabaseService.subscribeToTable(table: "streams") { [weak self] payload in
                Task {
                    await self?.handleStreamRealtimeUpdate(payload: payload)
                }
            }
        } catch {
            print("❌ Failed to subscribe to streams: \(error)")
        }
        
        // Subscribe to users table
        do {
            userSubscription = try supabaseService.subscribeToTable(table: "users") { [weak self] payload in
                Task {
                    await self?.handleUserRealtimeUpdate(payload: payload)
                }
            }
        } catch {
            print("❌ Failed to subscribe to users: \(error)")
        }
    }
    
    // MARK: - Service Integration Handlers
    private func handleHealthUpdates(_ healthUpdates: [StreamHealthUpdate]) {
        for update in healthUpdates {
            // Update stream health status in sync data
            if let stream = streams.first(where: { $0.id == update.streamId }) {
                stream.healthStatus = update.status
                stream.updatedAt = Date()
                
                // Queue for sync if connected
                if supabaseService.canSync {
                    queueOperation(
                        type: .update,
                        entityType: "stream",
                        entityId: stream.id,
                        userId: supabaseService.currentUser?.id.uuidString ?? "",
                        data: nil
                    )
                }
            }
        }
    }
    
    private func handleCacheUpdates(_ cacheUpdates: [StreamCacheUpdate]) {
        for update in cacheUpdates {
            switch update.type {
            case .streamAdded:
                // Handle stream added to cache
                if let stream = update.stream {
                    // Ensure stream is in sync queue
                    queueOperation(
                        type: .sync,
                        entityType: "stream",
                        entityId: stream.id,
                        userId: supabaseService.currentUser?.id.uuidString ?? "",
                        data: nil
                    )
                }
            case .streamUpdated:
                // Handle stream updated in cache
                if let stream = update.stream {
                    // Queue for sync
                    queueOperation(
                        type: .update,
                        entityType: "stream",
                        entityId: stream.id,
                        userId: supabaseService.currentUser?.id.uuidString ?? "",
                        data: nil
                    )
                }
            case .streamRemoved:
                // Handle stream removed from cache
                if let streamId = update.streamId {
                    // Queue for deletion
                    queueOperation(
                        type: .delete,
                        entityType: "stream",
                        entityId: streamId,
                        userId: supabaseService.currentUser?.id.uuidString ?? "",
                        data: nil
                    )
                }
            default:
                break
            }
        }
    }
    
    private func handleValidationResult(_ validationResult: ValidationResult?) {
        guard let result = validationResult else { return }
        
        // If validation was successful, update stream metadata
        if result.isValid, let stream = streams.first(where: { $0.url == result.url }) {
            stream.title = result.title
            stream.description = result.description
            stream.thumbnailURL = result.thumbnailURL
            stream.streamerName = result.streamerName
            stream.streamerAvatarURL = result.streamerAvatarURL
            stream.category = result.category
            stream.tags = result.tags
            stream.viewerCount = result.viewerCount
            stream.isLive = result.isLive
            stream.updatedAt = Date()
            
            // Queue for sync
            queueOperation(
                type: .update,
                entityType: "stream",
                entityId: stream.id,
                userId: supabaseService.currentUser?.id.uuidString ?? "",
                data: nil
            )
        }
    }
    
    // MARK: - Stream Operations
    public func syncStream(_ stream: Stream) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw StreamSyncError.notAuthenticated
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let syncStream = SyncStream(from: stream, userId: userId)
            
            // Check if stream exists remotely
            let existingStream = try await fetchRemoteStream(id: stream.id)
            
            if let existing = existingStream {
                // Update existing stream
                try await updateRemoteStream(syncStream, existing: existing)
            } else {
                // Create new stream
                try await createRemoteStream(syncStream)
            }
            
            // Update local sync status
            updateLocalStreamSyncStatus(stream: stream, status: "synced")
            
            print("✅ Stream synced: \(stream.title)")
            
        } catch {
            // Queue operation for retry
            queueOperation(
                type: .sync,
                entityType: "stream",
                entityId: stream.id,
                userId: userId,
                data: nil
            )
            
            throw error
        }
    }
    
    public func syncAllStreams() async throws {
        let localStreams = try await fetchLocalStreams()
        self.streams = localStreams
        
        for stream in localStreams {
            try await syncStream(stream)
        }
    }
    
    public func deleteRemoteStream(id: String) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw StreamSyncError.notAuthenticated
        }
        
        do {
            try await supabaseService.delete(table: "streams", id: id)
            print("✅ Stream deleted remotely: \(id)")
            
        } catch {
            // Queue operation for retry
            queueOperation(
                type: .delete,
                entityType: "stream",
                entityId: id,
                userId: userId,
                data: nil
            )
            
            throw error
        }
    }
    
    // MARK: - Conflict Resolution
    private func resolveStreamConflict(
        local: Stream,
        remote: SyncStream
    ) async throws -> Stream {
        let conflict = ConflictResolution(
            id: UUID().uuidString,
            userId: remote.userId,
            entityType: "stream",
            entityId: local.id,
            localData: try local.toDictionary(),
            remoteData: try remote.toDictionary(),
            resolvedData: nil,
            resolution: ConflictResolutionType.merge.rawValue,
            timestamp: Date(),
            resolvedAt: nil
        )
        
        conflictResolutions.append(conflict)
        
        // Use conflict resolver to merge changes
        let resolvedStream = try await conflictResolver.resolveStreamConflict(
            local: local,
            remote: remote
        )
        
        return resolvedStream
    }
    
    // MARK: - Real-time Update Handlers
    private func handleStreamRealtimeUpdate(payload: PostgrestResponse) async {
        // Handle real-time stream updates
        guard let eventType = payload.eventType,
              let record = payload.record else { return }
        
        switch eventType {
        case "INSERT":
            await handleStreamInsert(record: record)
        case "UPDATE":
            await handleStreamUpdate(record: record)
        case "DELETE":
            await handleStreamDelete(record: record)
        default:
            break
        }
    }
    
    private func handleUserRealtimeUpdate(payload: PostgrestResponse) async {
        // Handle real-time user updates
        guard let eventType = payload.eventType,
              let record = payload.record else { return }
        
        switch eventType {
        case "UPDATE":
            await handleUserUpdate(record: record)
        default:
            break
        }
    }
    
    private func handleStreamInsert(record: [String: Any]) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            let syncStream = try JSONDecoder().decode(SyncStream.self, from: data)
            
            // Check if stream already exists locally
            let existingStream = try await fetchLocalStream(id: syncStream.id)
            
            if existingStream == nil {
                // Create new local stream
                let stream = syncStream.toStream()
                try await createLocalStream(stream)
                
                print("✅ New stream created from remote: \(syncStream.title)")
            }
            
        } catch {
            print("❌ Failed to handle stream insert: \(error)")
        }
    }
    
    private func handleStreamUpdate(record: [String: Any]) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            let syncStream = try JSONDecoder().decode(SyncStream.self, from: data)
            
            // Check if stream exists locally
            if let localStream = try await fetchLocalStream(id: syncStream.id) {
                // Check for conflicts
                if localStream.updatedAt > syncStream.updatedAt {
                    // Local is newer, resolve conflict
                    let resolvedStream = try await resolveStreamConflict(
                        local: localStream,
                        remote: syncStream
                    )
                    try await updateLocalStream(resolvedStream)
                } else {
                    // Remote is newer, update local
                    let updatedStream = syncStream.toStream()
                    try await updateLocalStream(updatedStream)
                }
                
                print("✅ Stream updated from remote: \(syncStream.title)")
            }
            
        } catch {
            print("❌ Failed to handle stream update: \(error)")
        }
    }
    
    private func handleStreamDelete(record: [String: Any]) async {
        guard let id = record["id"] as? String else { return }
        
        do {
            try await deleteLocalStream(id: id)
            print("✅ Stream deleted from local: \(id)")
            
        } catch {
            print("❌ Failed to handle stream delete: \(error)")
        }
    }
    
    private func handleUserUpdate(record: [String: Any]) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            let syncUser = try JSONDecoder().decode(SyncUser.self, from: data)
            
            // Update local user data
            let user = syncUser.toUser()
            try await updateLocalUser(user)
            
            print("✅ User updated from remote: \(syncUser.email)")
            
        } catch {
            print("❌ Failed to handle user update: \(error)")
        }
    }
    
    // MARK: - Offline Operations
    private func queueOperation(
        type: SyncOperationType,
        entityType: String,
        entityId: String,
        userId: String,
        data: [String: Any]?
    ) {
        let operation = SyncOperation(
            userId: userId,
            entityType: entityType,
            entityId: entityId,
            operation: type,
            data: data
        )
        
        operationQueue.append(operation)
        pendingOperations.append(operation)
        
        // Save to persistent storage
        savePendingOperations()
    }
    
    private func processPendingOperations() {
        guard isOnline && supabaseService.canSync else { return }
        
        syncQueue.async {
            for operation in self.operationQueue {
                Task {
                    await self.processOperation(operation)
                }
            }
        }
    }
    
    private func processOperation(_ operation: SyncOperation) async {
        do {
            switch SyncOperationType(rawValue: operation.operation) {
            case .create:
                try await processCreateOperation(operation)
            case .update:
                try await processUpdateOperation(operation)
            case .delete:
                try await processDeleteOperation(operation)
            case .sync:
                try await processSyncOperation(operation)
            default:
                break
            }
            
            // Remove completed operation
            removeOperation(operation)
            
        } catch {
            // Handle operation failure
            await handleOperationFailure(operation, error: error)
        }
    }
    
    private func processCreateOperation(_ operation: SyncOperation) async throws {
        // Process create operation
        if operation.entityType == "stream" {
            if let stream = try await fetchLocalStream(id: operation.entityId) {
                try await syncStream(stream)
            }
        }
    }
    
    private func processUpdateOperation(_ operation: SyncOperation) async throws {
        // Process update operation
        if operation.entityType == "stream" {
            if let stream = try await fetchLocalStream(id: operation.entityId) {
                try await syncStream(stream)
            }
        }
    }
    
    private func processDeleteOperation(_ operation: SyncOperation) async throws {
        // Process delete operation
        if operation.entityType == "stream" {
            try await deleteRemoteStream(id: operation.entityId)
        }
    }
    
    private func processSyncOperation(_ operation: SyncOperation) async throws {
        // Process sync operation
        if operation.entityType == "stream" {
            if let stream = try await fetchLocalStream(id: operation.entityId) {
                try await syncStream(stream)
            }
        }
    }
    
    private func handleOperationFailure(_ operation: SyncOperation, error: Error) async {
        var updatedOperation = operation
        updatedOperation.retryCount += 1
        
        if updatedOperation.retryCount < updatedOperation.maxRetries {
            // Retry after delay
            let delay = Double(updatedOperation.retryCount * 2) // Exponential backoff
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Task {
                    await self.processOperation(updatedOperation)
                }
            }
        } else {
            // Max retries reached, mark as failed
            print("❌ Operation failed after \(updatedOperation.maxRetries) retries: \(error)")
            removeOperation(operation)
        }
    }
    
    private func removeOperation(_ operation: SyncOperation) {
        operationQueue.removeAll { $0.id == operation.id }
        pendingOperations.removeAll { $0.id == operation.id }
        savePendingOperations()
    }
    
    // MARK: - Periodic Sync
    private func performPeriodicSync() async {
        guard isOnline && supabaseService.canSync else { return }
        
        do {
            syncStats.totalSyncs += 1
            let startTime = Date()
            
            try await syncAllStreams()
            
            syncStats.successfulSyncs += 1
            syncStats.lastSyncAt = Date()
            syncStats.averageSyncTime = Date().timeIntervalSince(startTime)
            
            lastSyncTime = Date()
            
        } catch {
            syncStats.failedSyncs += 1
            print("❌ Periodic sync failed: \(error)")
        }
    }
    
    // MARK: - Data Access Methods
    private func fetchLocalStreams() async throws -> [Stream] {
        let descriptor = FetchDescriptor<Stream>()
        return try modelContext.fetch(descriptor)
    }
    
    private func fetchLocalStream(id: String) async throws -> Stream? {
        let descriptor = FetchDescriptor<Stream>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func createLocalStream(_ stream: Stream) async throws {
        modelContext.insert(stream)
        try modelContext.save()
    }
    
    private func updateLocalStream(_ stream: Stream) async throws {
        try modelContext.save()
    }
    
    private func deleteLocalStream(id: String) async throws {
        if let stream = try await fetchLocalStream(id: id) {
            modelContext.delete(stream)
            try modelContext.save()
        }
    }
    
    private func fetchRemoteStream(id: String) async throws -> SyncStream? {
        let query = supabaseService.client.database
            .from("streams")
            .select("*")
            .eq("id", value: id)
        
        let streams: [SyncStream] = try await supabaseService.executeQuery(
            table: "streams",
            query: query,
            type: SyncStream.self
        )
        
        return streams.first
    }
    
    private func createRemoteStream(_ stream: SyncStream) async throws {
        _ = try await supabaseService.insert(table: "streams", data: stream)
    }
    
    private func updateRemoteStream(_ stream: SyncStream, existing: SyncStream) async throws {
        let data = try stream.toDictionary()
        _ = try await supabaseService.update(
            table: "streams",
            id: stream.id,
            data: data
        ) as SyncStream
    }
    
    private func updateLocalUser(_ user: User) async throws {
        // Update user in local database
        try modelContext.save()
    }
    
    private func updateLocalStreamSyncStatus(stream: Stream, status: String) {
        stream.updatedAt = Date()
        try? modelContext.save()
    }
    
    // MARK: - Persistence
    private func savePendingOperations() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(operationQueue) {
            UserDefaults.standard.set(data, forKey: "pendingOperations")
        }
    }
    
    private func loadPendingOperations() {
        if let data = UserDefaults.standard.data(forKey: "pendingOperations") {
            let decoder = JSONDecoder()
            if let operations = try? decoder.decode([SyncOperation].self, from: data) {
                operationQueue = operations
                pendingOperations = operations
            }
        }
    }
    
    // MARK: - Enhanced Sync Operations
    public func syncStreamWithValidation(_ stream: Stream) async throws {
        // Validate stream before syncing
        let validationResult = try await validationService.validateAndExtractMetadata(url: stream.url)
        
        if validationResult.isValid {
            // Update stream with fresh metadata
            stream.title = validationResult.title
            stream.description = validationResult.description
            stream.thumbnailURL = validationResult.thumbnailURL
            stream.streamerName = validationResult.streamerName
            stream.streamerAvatarURL = validationResult.streamerAvatarURL
            stream.category = validationResult.category
            stream.tags = validationResult.tags
            stream.viewerCount = validationResult.viewerCount
            stream.isLive = validationResult.isLive
            stream.updatedAt = Date()
            
            // Cache the updated stream
            await cacheManager.updateStream(stream)
            
            // Start health monitoring
            await healthMonitor.startMonitoring(stream: stream)
            
            // Perform sync
            try await syncStream(stream)
        } else {
            throw StreamSyncError.operationFailed("Stream validation failed")
        }
    }
    
    public func syncAllStreamsWithHealthCheck() async throws {
        let streams = try await fetchLocalStreams()
        
        for stream in streams {
            // Check stream health before syncing
            if let healthData = await healthMonitor.getStreamHealth(streamId: stream.id) {
                if healthData.status == .healthy || healthData.status == .good {
                    try await syncStream(stream)
                }
            } else {
                // Start monitoring and sync
                await healthMonitor.startMonitoring(stream: stream)
                try await syncStream(stream)
            }
        }
    }
    
    public func syncWithOfflineSupport() async throws {
        if isOnline {
            try await syncAllStreams()
        } else {
            // Enable offline mode in cache manager
            cacheManager.enableOfflineMode()
            print("📱 Sync operating in offline mode")
        }
    }
    
    // MARK: - Public Interface
    public func startSync() async {
        guard isOnline && supabaseService.canSync else { return }
        
        do {
            try await syncAllStreams()
            processPendingOperations()
        } catch {
            print("❌ Failed to start sync: \(error)")
        }
    }
    
    public func pauseSync() {
        // Pause sync operations
        syncStatus = .connected
    }
    
    public func resumeSync() {
        // Resume sync operations
        Task {
            await startSync()
        }
    }
    
    public func forceSyncStream(_ stream: Stream) async throws {
        try await syncStream(stream)
    }
    
    public func getSyncStats() -> SyncStats {
        return syncStats
    }
    
    // MARK: - Cleanup
    deinit {
        streamSubscription?.unsubscribe()
        userSubscription?.unsubscribe()
        networkMonitor.cancel()
        cancellables.removeAll()
    }
}

// MARK: - Conflict Resolver
private class ConflictResolver {
    
    func resolveStreamConflict(local: Stream, remote: SyncStream) async throws -> Stream {
        // Merge strategy: prefer local user settings, remote metadata
        let resolved = local
        
        // Update with remote metadata
        resolved.thumbnailURL = remote.thumbnailURL
        resolved.streamerName = remote.streamerName
        resolved.streamerAvatarURL = remote.streamerAvatarURL
        resolved.category = remote.category
        resolved.viewerCount = remote.viewerCount
        resolved.isLive = remote.isLive
        
        // Keep local user preferences
        // resolved.isMuted, resolved.volume, resolved.position etc. stay local
        
        // Update timestamp
        resolved.updatedAt = Date()
        
        return resolved
    }
}

// MARK: - Stream Sync Errors
public enum StreamSyncError: Error, LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case syncConflict
    case dataCorruption
    case operationFailed(String)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .networkUnavailable:
            return "Network unavailable"
        case .syncConflict:
            return "Sync conflict detected"
        case .dataCorruption:
            return "Data corruption detected"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Extensions
extension Stream {
    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

extension SyncStream {
    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}