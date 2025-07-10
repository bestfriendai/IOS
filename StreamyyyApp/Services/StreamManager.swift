//
//  StreamManager.swift
//  StreamyyyApp
//
//  Central stream management service that handles all stream operations
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import Network

// MARK: - Stream Manager
@MainActor
public class StreamManager: ObservableObject {
    
    // MARK: - Properties
    public static let shared = StreamManager()
    
    @Published public var streams: [Stream] = []
    @Published public var activeStreams: [Stream] = []
    @Published public var isLoading: Bool = false
    @Published public var error: StreamManagerError?
    @Published public var operationProgress: Double = 0.0
    
    // Service dependencies
    private let supabaseService = SupabaseService.shared
    private let syncManager: StreamSyncManager
    private let healthMonitor: StreamHealthMonitor
    private let cacheManager: StreamCacheManager
    private let validationService: StreamValidationService
    
    // Core data management
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Operation queues
    private let operationQueue = OperationQueue()
    private let batchOperationQueue = DispatchQueue(label: "stream.batch.operations", qos: .userInitiated)
    
    // Stream state management
    private var streamStates: [String: StreamState] = [:]
    private var pendingOperations: [String: StreamOperation] = [:]
    
    // Performance monitoring
    private var performanceMetrics = StreamPerformanceMetrics()
    
    // MARK: - Initialization
    public init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext ?? ModelContext.shared
        self.syncManager = StreamSyncManager.shared
        self.healthMonitor = StreamHealthMonitor.shared
        self.cacheManager = StreamCacheManager.shared
        self.validationService = StreamValidationService.shared
        
        setupObservers()
        setupOperationQueue()
        loadStreams()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe sync manager updates
        syncManager.$streams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncedStreams in
                self?.handleSyncedStreams(syncedStreams)
            }
            .store(in: &cancellables)
        
        // Observe health monitor updates
        healthMonitor.$healthUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] healthUpdate in
                self?.updateStreamHealth(healthUpdate)
            }
            .store(in: &cancellables)
        
        // Observe cache manager updates
        cacheManager.$cacheUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cacheUpdate in
                self?.handleCacheUpdate(cacheUpdate)
            }
            .store(in: &cancellables)
    }
    
    private func setupOperationQueue() {
        operationQueue.maxConcurrentOperationCount = 3
        operationQueue.qualityOfService = .userInitiated
    }
    
    // MARK: - Stream Loading
    private func loadStreams() {
        isLoading = true
        
        Task {
            do {
                let localStreams = try await fetchLocalStreams()
                await updateStreams(localStreams)
                
                // Load from cache if available
                let cachedStreams = await cacheManager.getCachedStreams()
                if !cachedStreams.isEmpty {
                    await updateStreams(cachedStreams)
                }
                
                // Start health monitoring for active streams
                await startHealthMonitoring()
                
            } catch {
                await handleError(.loadingFailed(error))
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Stream Operations
    public func addStream(url: String, platform: Platform? = nil) async throws -> Stream {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate URL
            let validatedData = try await validationService.validateAndExtractMetadata(url: url)
            
            // Check for duplicates
            if let existingStream = streams.first(where: { $0.url == validatedData.url }) {
                throw StreamManagerError.duplicateStream(existingStream.id)
            }
            
            // Create stream
            let detectedPlatform = platform ?? validatedData.platform
            let stream = Stream(
                url: validatedData.url,
                platform: detectedPlatform,
                title: validatedData.title
            )
            
            // Apply extracted metadata
            stream.description = validatedData.description
            stream.thumbnailURL = validatedData.thumbnailURL
            stream.streamerName = validatedData.streamerName
            stream.streamerAvatarURL = validatedData.streamerAvatarURL
            stream.category = validatedData.category
            stream.tags = validatedData.tags
            stream.isLive = validatedData.isLive
            stream.viewerCount = validatedData.viewerCount
            
            // Save locally
            try await saveStreamLocally(stream)
            
            // Start health monitoring
            await healthMonitor.startMonitoring(stream: stream)
            
            // Cache stream data
            await cacheManager.cacheStream(stream)
            
            // Sync to cloud
            try await syncManager.syncStream(stream)
            
            // Update UI
            await addStreamToList(stream)
            
            // Record analytics
            await recordStreamAnalytics(stream: stream, event: .streamStart)
            
            return stream
            
        } catch {
            throw StreamManagerError.addStreamFailed(error)
        }
    }
    
    public func removeStream(id: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let stream = streams.first(where: { $0.id == id }) else {
            throw StreamManagerError.streamNotFound(id)
        }
        
        do {
            // Stop health monitoring
            await healthMonitor.stopMonitoring(streamId: id)
            
            // Remove from cache
            await cacheManager.removeStream(id: id)
            
            // Delete locally
            try await deleteStreamLocally(id: id)
            
            // Delete from cloud
            try await syncManager.deleteRemoteStream(id: id)
            
            // Update UI
            await removeStreamFromList(id: id)
            
            // Record analytics
            await recordStreamAnalytics(stream: stream, event: .streamEnd)
            
        } catch {
            throw StreamManagerError.removeStreamFailed(error)
        }
    }
    
    public func updateStream(_ stream: Stream) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Update locally
            try await updateStreamLocally(stream)
            
            // Update cache
            await cacheManager.updateStream(stream)
            
            // Sync to cloud
            try await syncManager.syncStream(stream)
            
            // Update UI
            await updateStreamInList(stream)
            
        } catch {
            throw StreamManagerError.updateStreamFailed(error)
        }
    }
    
    public func refreshStream(id: String) async throws -> Stream {
        guard let stream = streams.first(where: { $0.id == id }) else {
            throw StreamManagerError.streamNotFound(id)
        }
        
        do {
            // Re-validate and extract fresh metadata
            let validatedData = try await validationService.validateAndExtractMetadata(url: stream.url)
            
            // Update stream with fresh data
            stream.title = validatedData.title
            stream.description = validatedData.description
            stream.thumbnailURL = validatedData.thumbnailURL
            stream.streamerName = validatedData.streamerName
            stream.streamerAvatarURL = validatedData.streamerAvatarURL
            stream.category = validatedData.category
            stream.tags = validatedData.tags
            stream.isLive = validatedData.isLive
            stream.viewerCount = validatedData.viewerCount
            stream.updatedAt = Date()
            
            // Save changes
            try await updateStream(stream)
            
            return stream
            
        } catch {
            throw StreamManagerError.refreshStreamFailed(error)
        }
    }
    
    // MARK: - Batch Operations
    public func addStreams(urls: [String]) async throws -> [Stream] {
        var addedStreams: [Stream] = []
        var errors: [String: Error] = [:]
        
        operationProgress = 0.0
        
        for (index, url) in urls.enumerated() {
            do {
                let stream = try await addStream(url: url)
                addedStreams.append(stream)
            } catch {
                errors[url] = error
            }
            
            operationProgress = Double(index + 1) / Double(urls.count)
        }
        
        if !errors.isEmpty {
            throw StreamManagerError.batchOperationFailed(errors)
        }
        
        return addedStreams
    }
    
    public func removeStreams(ids: [String]) async throws {
        var errors: [String: Error] = [:]
        
        operationProgress = 0.0
        
        for (index, id) in ids.enumerated() {
            do {
                try await removeStream(id: id)
            } catch {
                errors[id] = error
            }
            
            operationProgress = Double(index + 1) / Double(ids.count)
        }
        
        if !errors.isEmpty {
            throw StreamManagerError.batchOperationFailed(errors)
        }
    }
    
    public func refreshAllStreams() async throws {
        var errors: [String: Error] = [:]
        
        operationProgress = 0.0
        
        for (index, stream) in streams.enumerated() {
            do {
                try await refreshStream(id: stream.id)
            } catch {
                errors[stream.id] = error
            }
            
            operationProgress = Double(index + 1) / Double(streams.count)
        }
        
        if !errors.isEmpty {
            throw StreamManagerError.batchOperationFailed(errors)
        }
    }
    
    // MARK: - Stream State Management
    public func getStreamState(id: String) -> StreamState? {
        return streamStates[id]
    }
    
    public func updateStreamState(id: String, state: StreamState) {
        streamStates[id] = state
        
        // Notify observers
        NotificationCenter.default.post(
            name: .streamStateDidChange,
            object: self,
            userInfo: ["streamId": id, "state": state]
        )
    }
    
    // MARK: - Search and Filtering
    public func searchStreams(query: String) -> [Stream] {
        guard !query.isEmpty else { return streams }
        
        return streams.filter { stream in
            stream.title.localizedCaseInsensitiveContains(query) ||
            stream.streamerName?.localizedCaseInsensitiveContains(query) ?? false ||
            stream.category?.localizedCaseInsensitiveContains(query) ?? false ||
            stream.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    public func filterStreams(by platform: Platform) -> [Stream] {
        return streams.filter { $0.platform == platform }
    }
    
    public func filterStreams(isLive: Bool) -> [Stream] {
        return streams.filter { $0.isLive == isLive }
    }
    
    public func filterStreams(by category: String) -> [Stream] {
        return streams.filter { $0.category == category }
    }
    
    public func getStreamsByTags(_ tags: [String]) -> [Stream] {
        return streams.filter { stream in
            tags.contains { tag in
                stream.tags.contains { $0.localizedCaseInsensitiveContains(tag) }
            }
        }
    }
    
    // MARK: - Analytics
    public func getStreamAnalytics(streamId: String) async throws -> [StreamAnalytics] {
        return try await supabaseService.getStreamAnalytics(streamId: streamId)
    }
    
    public func getUserAnalytics() async throws -> [StreamAnalytics] {
        return try await supabaseService.getUserAnalytics()
    }
    
    private func recordStreamAnalytics(stream: Stream, event: AnalyticsEvent, value: Double = 1.0) async {
        let analytics = StreamAnalytics(
            event: event,
            value: value,
            stream: stream
        )
        
        do {
            try await supabaseService.recordStreamAnalytics(analytics)
        } catch {
            print("❌ Failed to record analytics: \(error)")
        }
    }
    
    // MARK: - Performance Monitoring
    public func getPerformanceMetrics() -> StreamPerformanceMetrics {
        return performanceMetrics
    }
    
    private func updatePerformanceMetrics() {
        performanceMetrics.totalStreams = streams.count
        performanceMetrics.activeStreams = activeStreams.count
        performanceMetrics.healthyStreams = streams.filter { $0.isHealthy }.count
        performanceMetrics.averageResponseTime = healthMonitor.getAverageResponseTime()
        performanceMetrics.lastUpdated = Date()
    }
    
    // MARK: - Health Monitoring
    private func startHealthMonitoring() async {
        for stream in streams {
            await healthMonitor.startMonitoring(stream: stream)
        }
    }
    
    private func updateStreamHealth(_ healthUpdate: StreamHealthUpdate) {
        guard let stream = streams.first(where: { $0.id == healthUpdate.streamId }) else { return }
        
        stream.healthStatus = healthUpdate.status
        stream.updatedAt = Date()
        
        // Update cache
        Task {
            await cacheManager.updateStream(stream)
        }
        
        // Update performance metrics
        updatePerformanceMetrics()
    }
    
    // MARK: - Data Management
    private func fetchLocalStreams() async throws -> [Stream] {
        let descriptor = FetchDescriptor<Stream>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    private func saveStreamLocally(_ stream: Stream) async throws {
        modelContext.insert(stream)
        try modelContext.save()
    }
    
    private func updateStreamLocally(_ stream: Stream) async throws {
        stream.updatedAt = Date()
        try modelContext.save()
    }
    
    private func deleteStreamLocally(id: String) async throws {
        let descriptor = FetchDescriptor<Stream>(
            predicate: #Predicate { $0.id == id }
        )
        
        if let stream = try modelContext.fetch(descriptor).first {
            modelContext.delete(stream)
            try modelContext.save()
        }
    }
    
    // MARK: - UI Updates
    private func updateStreams(_ newStreams: [Stream]) async {
        streams = newStreams
        activeStreams = streams.filter { $0.isLive }
        updatePerformanceMetrics()
    }
    
    private func addStreamToList(_ stream: Stream) async {
        streams.append(stream)
        if stream.isLive {
            activeStreams.append(stream)
        }
        updatePerformanceMetrics()
    }
    
    private func removeStreamFromList(id: String) async {
        streams.removeAll { $0.id == id }
        activeStreams.removeAll { $0.id == id }
        updatePerformanceMetrics()
    }
    
    private func updateStreamInList(_ stream: Stream) async {
        if let index = streams.firstIndex(where: { $0.id == stream.id }) {
            streams[index] = stream
        }
        
        if stream.isLive {
            if !activeStreams.contains(where: { $0.id == stream.id }) {
                activeStreams.append(stream)
            }
        } else {
            activeStreams.removeAll { $0.id == stream.id }
        }
        
        updatePerformanceMetrics()
    }
    
    // MARK: - Event Handlers
    private func handleSyncedStreams(_ syncedStreams: [Stream]) {
        // Update local streams with synced data
        Task {
            await updateStreams(syncedStreams)
        }
    }
    
    private func handleCacheUpdate(_ cacheUpdate: StreamCacheUpdate) {
        // Handle cache updates
        Task {
            switch cacheUpdate.type {
            case .streamAdded:
                if let stream = cacheUpdate.stream {
                    await addStreamToList(stream)
                }
            case .streamUpdated:
                if let stream = cacheUpdate.stream {
                    await updateStreamInList(stream)
                }
            case .streamRemoved:
                if let streamId = cacheUpdate.streamId {
                    await removeStreamFromList(id: streamId)
                }
            }
        }
    }
    
    private func handleError(_ error: StreamManagerError) async {
        self.error = error
        print("❌ StreamManager Error: \(error.localizedDescription)")
    }
    
    // MARK: - Offline Support
    public func enableOfflineMode() {
        // Enable offline mode - use cached data only
        cacheManager.enableOfflineMode()
    }
    
    public func disableOfflineMode() {
        // Disable offline mode - resume normal operations
        cacheManager.disableOfflineMode()
        
        // Sync pending changes
        Task {
            try await syncManager.startSync()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        cancellables.removeAll()
        operationQueue.cancelAllOperations()
    }
}

// MARK: - Stream State
public enum StreamState: String, CaseIterable {
    case idle = "idle"
    case loading = "loading"
    case playing = "playing"
    case paused = "paused"
    case buffering = "buffering"
    case error = "error"
    case offline = "offline"
    
    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .loading: return "Loading"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .buffering: return "Buffering"
        case .error: return "Error"
        case .offline: return "Offline"
        }
    }
    
    public var color: Color {
        switch self {
        case .idle: return .gray
        case .loading: return .orange
        case .playing: return .green
        case .paused: return .blue
        case .buffering: return .yellow
        case .error: return .red
        case .offline: return .gray
        }
    }
}

// MARK: - Stream Operation
public struct StreamOperation: Identifiable {
    public let id = UUID()
    public let type: OperationType
    public let streamId: String
    public let timestamp: Date
    public let status: OperationStatus
    
    public enum OperationType {
        case add
        case update
        case remove
        case refresh
        case sync
    }
    
    public enum OperationStatus {
        case pending
        case inProgress
        case completed
        case failed
    }
}

// MARK: - Stream Performance Metrics
public struct StreamPerformanceMetrics {
    public var totalStreams: Int = 0
    public var activeStreams: Int = 0
    public var healthyStreams: Int = 0
    public var averageResponseTime: TimeInterval = 0
    public var lastUpdated: Date = Date()
    
    public var healthPercentage: Double {
        guard totalStreams > 0 else { return 0 }
        return Double(healthyStreams) / Double(totalStreams) * 100
    }
}

// MARK: - Stream Manager Errors
public enum StreamManagerError: Error, LocalizedError {
    case streamNotFound(String)
    case duplicateStream(String)
    case addStreamFailed(Error)
    case removeStreamFailed(Error)
    case updateStreamFailed(Error)
    case refreshStreamFailed(Error)
    case loadingFailed(Error)
    case batchOperationFailed([String: Error])
    case validationFailed(Error)
    case syncFailed(Error)
    case cacheFailed(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .streamNotFound(let id):
            return "Stream not found: \(id)"
        case .duplicateStream(let id):
            return "Stream already exists: \(id)"
        case .addStreamFailed(let error):
            return "Failed to add stream: \(error.localizedDescription)"
        case .removeStreamFailed(let error):
            return "Failed to remove stream: \(error.localizedDescription)"
        case .updateStreamFailed(let error):
            return "Failed to update stream: \(error.localizedDescription)"
        case .refreshStreamFailed(let error):
            return "Failed to refresh stream: \(error.localizedDescription)"
        case .loadingFailed(let error):
            return "Failed to load streams: \(error.localizedDescription)"
        case .batchOperationFailed(let errors):
            return "Batch operation failed with \(errors.count) errors"
        case .validationFailed(let error):
            return "Validation failed: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .cacheFailed(let error):
            return "Cache operation failed: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .streamNotFound:
            return "Please check the stream ID and try again"
        case .duplicateStream:
            return "This stream is already in your collection"
        case .addStreamFailed, .removeStreamFailed, .updateStreamFailed:
            return "Please try again later"
        case .refreshStreamFailed:
            return "Please check your internet connection and try again"
        case .loadingFailed:
            return "Please restart the app and try again"
        case .batchOperationFailed:
            return "Some operations failed. Please check individual errors"
        case .validationFailed:
            return "Please check the stream URL and try again"
        case .syncFailed:
            return "Please check your internet connection and try again"
        case .cacheFailed:
            return "Please clear cache and try again"
        case .unknown:
            return "Please try again or contact support"
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let streamStateDidChange = Notification.Name("streamStateDidChange")
    static let streamHealthDidUpdate = Notification.Name("streamHealthDidUpdate")
    static let streamCacheDidUpdate = Notification.Name("streamCacheDidUpdate")
}

// MARK: - Model Context Extension
extension ModelContext {
    static var shared: ModelContext {
        // This should be properly initialized in your app
        // For now, we'll use a placeholder
        return ModelContext(.init())
    }
}