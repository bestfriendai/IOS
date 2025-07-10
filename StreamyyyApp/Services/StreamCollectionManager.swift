//
//  StreamCollectionManager.swift
//  StreamyyyApp
//
//  Observable stream collection manager with persistence and synchronization
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import Combine
import SwiftData
import Network

// MARK: - Stream Collection Manager
@MainActor
public class StreamCollectionManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = StreamCollectionManager()
    
    // MARK: - Published Properties
    @Published public var streams: [Stream] = []
    @Published public var favoriteStreams: [Stream] = []
    @Published public var recentStreams: [Stream] = []
    @Published public var isLoading = false
    @Published public var isSyncing = false
    @Published public var error: StreamCollectionError?
    @Published public var lastSyncDate: Date?
    @Published public var syncProgress: Double = 0.0
    
    // MARK: - Collection State
    @Published public var totalStreamCount = 0
    @Published public var activeStreamCount = 0
    @Published public var offlineStreamCount = 0
    @Published public var errorStreamCount = 0
    @Published public var searchQuery = ""
    @Published public var selectedPlatforms: Set<Platform> = []
    @Published public var sortOption: StreamSortOption = .recentlyAdded
    @Published public var filterOption: StreamFilterOption = .all
    
    // MARK: - Real-time Updates
    @Published public var liveUpdateEnabled = true
    @Published public var lastUpdateTime: Date?
    @Published public var updateInterval: TimeInterval = 30.0
    @Published public var connectionStatus: ConnectionStatus = .disconnected
    @Published public var pendingOperations: [StreamCollectionOperation] = []
    
    // MARK: - Cache Management
    @Published public var cacheSize: Int = 0
    @Published public var cacheHitRate: Double = 0.0
    @Published public var lastCacheCleanup: Date?
    
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "stream.collection.network")
    
    // Dependencies
    private let persistenceService = StreamPersistenceService.shared
    private let syncService = StreamSyncService.shared
    private let cacheService = StreamCacheService.shared
    private let validationService = StreamValidationService.shared
    private let notificationManager = PopupNotificationManager.shared
    
    private init() {
        setupNetworkMonitoring()
        setupObservers()
        loadInitialData()
        startRealTimeUpdates()
    }
    
    // MARK: - Setup Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let isConnected = path.status == .satisfied
                self?.connectionStatus = isConnected ? .connected : .disconnected
                
                if isConnected {
                    await self?.handleNetworkConnected()
                } else {
                    await self?.handleNetworkDisconnected()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupObservers() {
        // Search query observer
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                Task { @MainActor in
                    await self?.filterStreams()
                }
            }
            .store(in: &cancellables)
        
        // Platform filter observer
        $selectedPlatforms
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.filterStreams()
                }
            }
            .store(in: &cancellables)
        
        // Sort option observer
        $sortOption
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.sortStreams()
                }
            }
            .store(in: &cancellables)
        
        // Multi-stream events
        NotificationCenter.default.publisher(for: .streamAdded)
            .sink { [weak self] notification in
                if let stream = notification.object as? Stream {
                    Task { @MainActor in
                        await self?.handleStreamAdded(stream)
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .streamRemoved)
            .sink { [weak self] notification in
                if let streamId = notification.object as? String {
                    Task { @MainActor in
                        await self?.handleStreamRemoved(streamId)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await loadStreamsFromPersistence()
            await updateStatistics()
        }
    }
    
    private func startRealTimeUpdates() {
        guard liveUpdateEnabled else { return }
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshLiveData()
            }
        }
    }
    
    // MARK: - Public Methods
    
    public func addStream(_ stream: Stream) async throws {
        isLoading = true
        error = nil
        
        let operation = StreamCollectionOperation(
            type: .add,
            streamId: stream.id,
            timestamp: Date()
        )
        pendingOperations.append(operation)
        
        do {
            // Validate stream
            let validationResult = await validationService.validateStream(stream)
            guard validationResult.isValid else {
                throw StreamCollectionError.invalidStream(validationResult.errors)
            }
            
            // Check for duplicates
            if streams.contains(where: { $0.id == stream.id }) {
                throw StreamCollectionError.duplicateStream(stream.id)
            }
            
            // Add to collection
            streams.append(stream)
            
            // Add to recent streams
            addToRecentStreams(stream)
            
            // Persist the change
            try await persistenceService.saveStream(stream)
            
            // Sync if connected
            if connectionStatus == .connected {
                await syncStreamAddition(stream)
            }
            
            // Update statistics
            await updateStatistics()
            
            // Show success notification
            notificationManager.showStreamSuccess(
                title: "Stream Added",
                message: "Added \(stream.title) to your collection",
                streamId: stream.id
            )
            
            // Remove from pending operations
            pendingOperations.removeAll { $0.id == operation.id }
            
            isLoading = false
            
            // Post notification
            NotificationCenter.default.post(
                name: .streamCollectionUpdated,
                object: StreamCollectionUpdate(type: .added, stream: stream)
            )
            
        } catch {
            // Remove from pending operations
            pendingOperations.removeAll { $0.id == operation.id }
            
            self.error = error as? StreamCollectionError ?? .operationFailed(error)
            isLoading = false
            
            // Show error notification
            notificationManager.showStreamError(
                title: "Failed to Add Stream",
                message: error.localizedDescription,
                streamId: stream.id
            )
            
            throw error
        }
    }
    
    public func removeStream(_ streamId: String) async throws {
        isLoading = true
        error = nil
        
        let operation = StreamCollectionOperation(
            type: .remove,
            streamId: streamId,
            timestamp: Date()
        )
        pendingOperations.append(operation)
        
        do {
            guard let index = streams.firstIndex(where: { $0.id == streamId }) else {
                throw StreamCollectionError.streamNotFound(streamId)
            }
            
            let stream = streams[index]
            
            // Remove from collection
            streams.remove(at: index)
            
            // Remove from favorites if present
            favoriteStreams.removeAll { $0.id == streamId }
            
            // Persist the change
            try await persistenceService.deleteStream(streamId)
            
            // Sync if connected
            if connectionStatus == .connected {
                await syncStreamRemoval(streamId)
            }
            
            // Update statistics
            await updateStatistics()
            
            // Show notification
            notificationManager.showCustom(
                title: "Stream Removed",
                message: "Removed \(stream.title) from your collection",
                icon: "minus.circle.fill",
                color: .orange,
                data: ["streamId": streamId]
            )
            
            // Remove from pending operations
            pendingOperations.removeAll { $0.id == operation.id }
            
            isLoading = false
            
            // Post notification
            NotificationCenter.default.post(
                name: .streamCollectionUpdated,
                object: StreamCollectionUpdate(type: .removed, stream: stream)
            )
            
        } catch {
            // Remove from pending operations
            pendingOperations.removeAll { $0.id == operation.id }
            
            self.error = error as? StreamCollectionError ?? .operationFailed(error)
            isLoading = false
            
            throw error
        }
    }
    
    public func toggleFavorite(_ streamId: String) async throws {
        guard let stream = streams.first(where: { $0.id == streamId }) else {
            throw StreamCollectionError.streamNotFound(streamId)
        }
        
        if favoriteStreams.contains(where: { $0.id == streamId }) {
            // Remove from favorites
            favoriteStreams.removeAll { $0.id == streamId }
            
            try await persistenceService.removeFavorite(streamId)
            
            notificationManager.showCustom(
                title: "Removed from Favorites",
                message: "Removed \(stream.title) from favorites",
                icon: "heart.slash.fill",
                color: .gray
            )
        } else {
            // Add to favorites
            favoriteStreams.append(stream)
            
            try await persistenceService.addFavorite(streamId)
            
            notificationManager.showCustom(
                title: "Added to Favorites",
                message: "Added \(stream.title) to favorites",
                icon: "heart.fill",
                color: .red
            )
        }
        
        // Sync favorites if connected
        if connectionStatus == .connected {
            await syncFavorites()
        }
    }
    
    public func refreshStreams() async {
        isLoading = true
        error = nil
        
        do {
            // Validate all streams
            var updatedStreams: [Stream] = []
            
            for stream in streams {
                let validationResult = await validationService.validateStream(stream)
                
                if validationResult.isValid {
                    updatedStreams.append(stream)
                } else {
                    // Mark as error but keep in collection
                    var errorStream = stream
                    errorStream.updateHealthStatus(.error)
                    updatedStreams.append(errorStream)
                }
            }
            
            streams = updatedStreams
            await updateStatistics()
            
            // Sync with remote if connected
            if connectionStatus == .connected {
                await syncWithRemote()
            }
            
            lastUpdateTime = Date()
            isLoading = false
            
        } catch {
            self.error = .refreshFailed(error)
            isLoading = false
        }
    }
    
    public func syncWithRemote() async {
        guard connectionStatus == .connected, !isSyncing else { return }
        
        isSyncing = true
        syncProgress = 0.0
        error = nil
        
        do {
            // Upload local changes
            syncProgress = 0.2
            let localState = createSyncState()
            try await syncService.uploadState(localState)
            
            // Download remote changes
            syncProgress = 0.5
            let remoteState = try await syncService.downloadState()
            
            // Merge changes
            syncProgress = 0.8
            await mergeRemoteState(remoteState)
            
            // Update persistence
            try await persistenceService.saveSyncState(localState)
            
            syncProgress = 1.0
            lastSyncDate = Date()
            
            notificationManager.showCustom(
                title: "Sync Complete",
                message: "Successfully synced \(streams.count) streams",
                icon: "icloud.and.arrow.up.fill",
                color: .green
            )
            
        } catch {
            self.error = .syncFailed(error)
            
            notificationManager.showStreamError(
                title: "Sync Failed",
                message: "Failed to sync with cloud: \(error.localizedDescription)"
            )
        }
        
        isSyncing = false
        syncProgress = 0.0
    }
    
    public func clearCollection() async {
        isLoading = true
        
        do {
            streams.removeAll()
            favoriteStreams.removeAll()
            recentStreams.removeAll()
            
            try await persistenceService.clearAllStreams()
            await updateStatistics()
            
            notificationManager.showCustom(
                title: "Collection Cleared",
                message: "Removed all streams from collection",
                icon: "trash.fill",
                color: .red
            )
            
        } catch {
            self.error = .operationFailed(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Filtering and Sorting
    
    public func setSearchQuery(_ query: String) {
        searchQuery = query
    }
    
    public func setPlatformFilter(_ platforms: Set<Platform>) {
        selectedPlatforms = platforms
    }
    
    public func setSortOption(_ option: StreamSortOption) {
        sortOption = option
    }
    
    public func setFilterOption(_ option: StreamFilterOption) {
        filterOption = option
    }
    
    private func filterStreams() async {
        // This would apply current filters to the streams array
        // Implementation would filter based on search query, platforms, etc.
    }
    
    private func sortStreams() async {
        streams.sort { lhs, rhs in
            switch sortOption {
            case .recentlyAdded:
                return lhs.createdAt > rhs.createdAt
            case .alphabetical:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .viewerCount:
                return lhs.viewerCount > rhs.viewerCount
            case .platform:
                return lhs.platform.displayName.localizedCaseInsensitiveCompare(rhs.platform.displayName) == .orderedAscending
            case .lastViewed:
                return (lhs.lastViewedAt ?? Date.distantPast) > (rhs.lastViewedAt ?? Date.distantPast)
            }
        }
    }
    
    // MARK: - Statistics and Analytics
    
    private func updateStatistics() async {
        totalStreamCount = streams.count
        activeStreamCount = streams.filter { $0.isLive }.count
        offlineStreamCount = streams.filter { !$0.isLive }.count
        errorStreamCount = streams.filter { $0.healthStatus == .error }.count
        
        // Update cache statistics
        cacheSize = await cacheService.getCacheSize()
        cacheHitRate = await cacheService.getHitRate()
    }
    
    // MARK: - Private Methods
    
    private func loadStreamsFromPersistence() async {
        do {
            let persistedStreams = try await persistenceService.loadAllStreams()
            streams = persistedStreams
            
            let persistedFavorites = try await persistenceService.loadFavorites()
            favoriteStreams = streams.filter { stream in
                persistedFavorites.contains(stream.id)
            }
            
            let persistedRecent = try await persistenceService.loadRecentStreams()
            recentStreams = Array(persistedRecent.prefix(20))
            
        } catch {
            self.error = .loadFailed(error)
        }
    }
    
    private func addToRecentStreams(_ stream: Stream) {
        // Remove if already exists
        recentStreams.removeAll { $0.id == stream.id }
        
        // Add to beginning
        recentStreams.insert(stream, at: 0)
        
        // Keep only last 20
        if recentStreams.count > 20 {
            recentStreams = Array(recentStreams.prefix(20))
        }
    }
    
    private func refreshLiveData() async {
        guard liveUpdateEnabled, connectionStatus == .connected else { return }
        
        // Update stream live status and viewer counts
        for (index, stream) in streams.enumerated() {
            let validationResult = await validationService.validateStream(stream)
            
            if validationResult.isValid {
                // Update stream data from API if available
                if let updatedStream = await fetchUpdatedStreamData(stream) {
                    streams[index] = updatedStream
                }
            }
        }
        
        await updateStatistics()
        lastUpdateTime = Date()
    }
    
    private func fetchUpdatedStreamData(_ stream: Stream) async -> Stream? {
        // This would fetch updated data from the platform API
        // For now, just return the original stream
        return stream
    }
    
    private func handleNetworkConnected() async {
        connectionStatus = .connected
        
        // Resume sync operations
        await syncWithRemote()
        
        // Process pending operations
        await processPendingOperations()
    }
    
    private func handleNetworkDisconnected() async {
        connectionStatus = .disconnected
        
        notificationManager.showNetworkStatus(
            title: "Network Disconnected",
            message: "Operating in offline mode",
            isConnected: false
        )
    }
    
    private func processPendingOperations() async {
        for operation in pendingOperations {
            switch operation.type {
            case .add:
                if let stream = streams.first(where: { $0.id == operation.streamId }) {
                    await syncStreamAddition(stream)
                }
            case .remove:
                await syncStreamRemoval(operation.streamId)
            case .favorite:
                await syncFavorites()
            }
        }
        
        pendingOperations.removeAll()
    }
    
    private func syncStreamAddition(_ stream: Stream) async {
        do {
            try await syncService.uploadStream(stream)
        } catch {
            print("Failed to sync stream addition: \(error)")
        }
    }
    
    private func syncStreamRemoval(_ streamId: String) async {
        do {
            try await syncService.removeStream(streamId)
        } catch {
            print("Failed to sync stream removal: \(error)")
        }
    }
    
    private func syncFavorites() async {
        do {
            let favoriteIds = favoriteStreams.map { $0.id }
            try await syncService.uploadFavorites(favoriteIds)
        } catch {
            print("Failed to sync favorites: \(error)")
        }
    }
    
    private func handleStreamAdded(_ stream: Stream) async {
        if !streams.contains(where: { $0.id == stream.id }) {
            streams.append(stream)
            addToRecentStreams(stream)
            await updateStatistics()
        }
    }
    
    private func handleStreamRemoved(_ streamId: String) async {
        streams.removeAll { $0.id == streamId }
        favoriteStreams.removeAll { $0.id == streamId }
        recentStreams.removeAll { $0.id == streamId }
        await updateStatistics()
    }
    
    private func createSyncState() -> StreamCollectionSyncState {
        return StreamCollectionSyncState(
            streams: streams,
            favorites: favoriteStreams.map { $0.id },
            lastModified: Date()
        )
    }
    
    private func mergeRemoteState(_ remoteState: StreamCollectionSyncState) async {
        // Simple merge strategy - in production this would be more sophisticated
        if let remoteDate = remoteState.lastModified,
           let localDate = lastSyncDate,
           remoteDate > localDate {
            
            // Apply remote changes
            streams = remoteState.streams
            favoriteStreams = streams.filter { stream in
                remoteState.favorites.contains(stream.id)
            }
            
            await updateStatistics()
        }
    }
    
    // MARK: - Cache Management
    
    public func clearCache() async {
        await cacheService.clearCache()
        lastCacheCleanup = Date()
        await updateStatistics()
        
        notificationManager.showCustom(
            title: "Cache Cleared",
            message: "Cleared stream cache to free up space",
            icon: "arrow.clockwise",
            color: .blue
        )
    }
    
    public func optimizeCache() async {
        await cacheService.optimizeCache()
        await updateStatistics()
    }
}

// MARK: - Supporting Types

public struct StreamCollectionOperation: Identifiable {
    public let id = UUID()
    public let type: OperationType
    public let streamId: String
    public let timestamp: Date
    
    public enum OperationType: String, CaseIterable {
        case add = "add"
        case remove = "remove"
        case favorite = "favorite"
    }
}

public struct StreamCollectionUpdate {
    public let type: UpdateType
    public let stream: Stream
    
    public enum UpdateType {
        case added
        case removed
        case updated
        case favorited
        case unfavorited
    }
}

public struct StreamCollectionSyncState: Codable {
    public let streams: [Stream]
    public let favorites: [String]
    public let lastModified: Date?
}

public enum StreamSortOption: String, CaseIterable {
    case recentlyAdded = "recently_added"
    case alphabetical = "alphabetical"
    case viewerCount = "viewer_count"
    case platform = "platform"
    case lastViewed = "last_viewed"
    
    public var displayName: String {
        switch self {
        case .recentlyAdded: return "Recently Added"
        case .alphabetical: return "Alphabetical"
        case .viewerCount: return "Viewer Count"
        case .platform: return "Platform"
        case .lastViewed: return "Last Viewed"
        }
    }
}

public enum StreamFilterOption: String, CaseIterable {
    case all = "all"
    case live = "live"
    case offline = "offline"
    case favorites = "favorites"
    case recent = "recent"
    case errors = "errors"
    
    public var displayName: String {
        switch self {
        case .all: return "All Streams"
        case .live: return "Live Streams"
        case .offline: return "Offline Streams"
        case .favorites: return "Favorites"
        case .recent: return "Recently Added"
        case .errors: return "Error Streams"
        }
    }
}

public enum StreamCollectionError: Error, LocalizedError {
    case invalidStream([String])
    case duplicateStream(String)
    case streamNotFound(String)
    case operationFailed(Error)
    case loadFailed(Error)
    case syncFailed(Error)
    case refreshFailed(Error)
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .invalidStream(let errors):
            return "Invalid stream: \(errors.joined(separator: ", "))"
        case .duplicateStream(let id):
            return "Stream \(id) already exists in collection"
        case .streamNotFound(let id):
            return "Stream \(id) not found in collection"
        case .operationFailed(let error):
            return "Operation failed: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load streams: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .refreshFailed(let error):
            return "Refresh failed: \(error.localizedDescription)"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let streamCollectionUpdated = Notification.Name("streamCollectionUpdated")
}