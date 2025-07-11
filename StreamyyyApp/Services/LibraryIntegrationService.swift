//
//  LibraryIntegrationService.swift
//  StreamyyyApp
//
//  Service for integrating Library functionality with multi-stream viewing and persistence
//

import Foundation
import SwiftUI
import Combine

@MainActor
public class LibraryIntegrationService: ObservableObject {
    public static let shared = LibraryIntegrationService()
    
    // MARK: - Published Properties
    @Published public var isIntegrationActive = false
    @Published public var lastAction: LibraryAction?
    @Published public var actionHistory: [LibraryAction] = []
    
    // MARK: - Dependencies
    private let favoritesService = UserFavoritesService.shared
    private let viewingHistoryService = ViewingHistoryService.shared
    private let collectionsService = StreamCollectionsService.shared
    private let layoutManager = LayoutPersistenceManager.shared
    private let multiStreamManager = MultiStreamManager.shared
    private let audioManager = MultiStreamAudioManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupMultiStreamObservers()
        setupLibraryObservers()
    }
    
    // MARK: - Setup Methods
    
    private func setupMultiStreamObservers() {
        // Observe stream additions
        NotificationCenter.default.publisher(for: .streamAdded)
            .sink { [weak self] notification in
                if let streamData = notification.userInfo?["stream"] as? TwitchStream {
                    Task {
                        await self?.handleStreamAdded(streamData)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe stream removals
        NotificationCenter.default.publisher(for: .streamRemoved)
            .sink { [weak self] notification in
                if let streamId = notification.userInfo?["streamId"] as? String {
                    Task {
                        await self?.handleStreamRemoved(streamId)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe layout changes
        NotificationCenter.default.publisher(for: .layoutChanged)
            .sink { [weak self] notification in
                if let layout = notification.userInfo?["layout"] as? MultiStreamLayout {
                    Task {
                        await self?.handleLayoutChanged(layout)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe viewing session starts
        NotificationCenter.default.publisher(for: .viewingSessionStarted)
            .sink { [weak self] notification in
                if let sessionData = notification.userInfo as? [String: Any] {
                    Task {
                        await self?.handleViewingSessionStarted(sessionData)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe viewing session ends
        NotificationCenter.default.publisher(for: .viewingSessionEnded)
            .sink { [weak self] notification in
                if let sessionData = notification.userInfo as? [String: Any] {
                    Task {
                        await self?.handleViewingSessionEnded(sessionData)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupLibraryObservers() {
        // Observe favorite changes
        favoritesService.$favorites
            .dropFirst()
            .sink { [weak self] favorites in
                self?.recordAction(.favoriteUpdated(count: favorites.count))
            }
            .store(in: &cancellables)
        
        // Observe collection changes
        collectionsService.$collections
            .dropFirst()
            .sink { [weak self] collections in
                self?.recordAction(.collectionsUpdated(count: collections.count))
            }
            .store(in: &cancellables)
        
        // Observe layout changes
        layoutManager.$savedLayouts
            .dropFirst()
            .sink { [weak self] layouts in
                self?.recordAction(.layoutsUpdated(count: layouts.count))
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Multi-Stream to Library Integration
    
    /// Add a stream from library favorites to multi-stream view
    public func addFavoriteToMultiStream(_ favorite: FavoriteStream, slotIndex: Int? = nil) async {
        let twitchStream = favorite.asAppStream.toTwitchStream()
        
        let targetIndex = slotIndex ?? findAvailableSlot()
        guard targetIndex != -1 else {
            recordAction(.addToMultiStreamFailed(reason: "No available slots"))
            return
        }
        
        multiStreamManager.addStream(twitchStream, to: targetIndex)
        
        // Start viewing session tracking
        await startViewingSession(for: favorite.asAppStream)
        
        recordAction(.addedToMultiStream(streamTitle: favorite.title, slotIndex: targetIndex))
    }
    
    /// Add a stream from viewing history to multi-stream view
    public func addHistoryToMultiStream(_ history: ViewingHistory, slotIndex: Int? = nil) async {
        let streamData = history.toAppStream()
        let twitchStream = streamData.toTwitchStream()
        
        let targetIndex = slotIndex ?? findAvailableSlot()
        guard targetIndex != -1 else {
            recordAction(.addToMultiStreamFailed(reason: "No available slots"))
            return
        }
        
        multiStreamManager.addStream(twitchStream, to: targetIndex)
        
        // Start viewing session tracking
        await startViewingSession(for: streamData)
        
        recordAction(.addedToMultiStream(streamTitle: history.displayTitle, slotIndex: targetIndex))
    }
    
    /// Add streams from a collection to multi-stream view
    public func addCollectionToMultiStream(_ collection: StreamCollection, replaceAll: Bool = false) async {
        if replaceAll {
            multiStreamManager.clearAll()
        }
        
        var addedCount = 0
        let availableSlots = replaceAll ? multiStreamManager.currentLayout.maxStreams : 
                           multiStreamManager.currentLayout.maxStreams - multiStreamManager.activeStreams.filter { $0.stream != nil }.count
        
        for (index, collectionStream) in collection.streams.prefix(availableSlots).enumerated() {
            if let streamData = collectionStream.streamData {
                let twitchStream = streamData.toTwitchStream()
                let slotIndex = replaceAll ? index : findAvailableSlot()
                
                if slotIndex != -1 {
                    multiStreamManager.addStream(twitchStream, to: slotIndex)
                    addedCount += 1
                    
                    // Record view for collection stream
                    collectionStream.recordView()
                }
            }
        }
        
        // Mark collection as accessed
        collection.recordAccess()
        
        recordAction(.addedCollectionToMultiStream(
            collectionName: collection.name,
            streamsAdded: addedCount
        ))
    }
    
    /// Apply a saved layout
    public func applyLayout(_ layout: Layout) async {
        // Convert Layout to MultiStreamLayout if possible
        if let multiStreamLayout = layout.type.toMultiStreamLayout() {
            multiStreamManager.updateLayout(multiStreamLayout)
            layout.recordUsage()
            layoutManager.addToRecentLayouts(layout)
            
            recordAction(.layoutApplied(layoutName: layout.name))
        }
    }
    
    // MARK: - Library Integration from Multi-Stream
    
    /// Save current multi-stream setup as a collection
    public func saveCurrentSetupAsCollection(
        name: String,
        description: String? = nil,
        isPrivate: Bool = false
    ) async throws {
        let activeStreams = multiStreamManager.activeStreams.compactMap { $0.stream }
        guard !activeStreams.isEmpty else {
            throw LibraryIntegrationError.noActiveStreams
        }
        
        let collection = try await collectionsService.createCollection(
            name: name,
            description: description,
            isPrivate: isPrivate
        )
        
        for stream in activeStreams {
            let streamData = stream.toStreamData()
            try await collectionsService.addStream(streamData, to: collection)
        }
        
        recordAction(.createdCollectionFromMultiStream(
            collectionName: name,
            streamCount: activeStreams.count
        ))
    }
    
    /// Save current layout configuration
    public func saveCurrentLayoutConfiguration(
        name: String,
        description: String? = nil
    ) async throws {
        let currentLayout = multiStreamManager.currentLayout
        let layoutConfig = currentLayout.toLayoutConfiguration()
        
        let layout = Layout(
            name: name,
            type: currentLayout.toLayoutType(),
            configuration: layoutConfig
        )
        
        layout.description = description
        layoutManager.saveLayout(layout)
        
        recordAction(.savedLayout(layoutName: name))
    }
    
    /// Add current stream to favorites
    public func addCurrentStreamToFavorites(streamId: String) async {
        guard let streamSlot = multiStreamManager.activeStreams.first(where: { $0.stream?.id == streamId }),
              let stream = streamSlot.stream else {
            recordAction(.addToFavoritesFailed(reason: "Stream not found"))
            return
        }
        
        let appStream = stream.toAppStream()
        await favoritesService.addFavorite(appStream)
        
        recordAction(.addedToFavorites(streamTitle: stream.title))
    }
    
    // MARK: - Viewing Session Management
    
    private func startViewingSession(for stream: AppStream) async {
        viewingHistoryService.startSession(
            streamId: stream.id,
            streamTitle: stream.title,
            streamURL: stream.url,
            platform: Platform.detect(from: stream.url),
            streamerName: stream.streamerName,
            thumbnailURL: stream.thumbnailURL,
            category: stream.gameName,
            wasLive: stream.isLive,
            viewerCount: stream.viewerCount
        )
    }
    
    private func endViewingSession(streamId: String, reason: ViewingExitReason = .userChoice) async {
        // Find and update session if it matches
        if let session = viewingHistoryService.currentSession,
           session.streamId == streamId {
            viewingHistoryService.endCurrentSession(reason: reason)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleStreamAdded(_ stream: TwitchStream) async {
        // Start viewing session
        let appStream = stream.toAppStream()
        await startViewingSession(for: appStream)
        
        recordAction(.streamAddedToMultiStream(streamTitle: stream.title))
    }
    
    private func handleStreamRemoved(_ streamId: String) async {
        // End viewing session
        await endViewingSession(streamId: streamId, reason: .userChoice)
        
        recordAction(.streamRemovedFromMultiStream(streamId: streamId))
    }
    
    private func handleLayoutChanged(_ layout: MultiStreamLayout) async {
        recordAction(.layoutChanged(layoutName: layout.displayName))
    }
    
    private func handleViewingSessionStarted(_ sessionData: [String: Any]) async {
        if let streamTitle = sessionData["streamTitle"] as? String {
            recordAction(.viewingSessionStarted(streamTitle: streamTitle))
        }
    }
    
    private func handleViewingSessionEnded(_ sessionData: [String: Any]) async {
        if let streamTitle = sessionData["streamTitle"] as? String,
           let duration = sessionData["duration"] as? TimeInterval {
            recordAction(.viewingSessionEnded(streamTitle: streamTitle, duration: duration))
        }
    }
    
    // MARK: - Helper Methods
    
    private func findAvailableSlot() -> Int {
        for (index, slot) in multiStreamManager.activeStreams.enumerated() {
            if slot.stream == nil {
                return index
            }
        }
        return -1
    }
    
    private func recordAction(_ action: LibraryAction) {
        lastAction = action
        actionHistory.append(action)
        
        // Keep only last 100 actions
        if actionHistory.count > 100 {
            actionHistory.removeFirst(actionHistory.count - 100)
        }
        
        print("Library Integration: \(action.description)")
    }
    
    // MARK: - Export/Import Support
    
    /// Export library data
    public func exportLibraryData() async throws -> LibraryExportData {
        let favorites = favoritesService.favorites
        let history = viewingHistoryService.viewingHistory
        let collections = collectionsService.collections
        let layouts = layoutManager.savedLayouts
        
        return LibraryExportData(
            favorites: favorites,
            viewingHistory: history,
            collections: collections,
            layouts: layouts,
            exportDate: Date(),
            version: "1.0"
        )
    }
    
    /// Import library data
    public func importLibraryData(_ data: LibraryExportData) async throws {
        // Import would be implemented based on specific requirements
        // This is a placeholder for the functionality
        throw LibraryIntegrationError.importNotImplemented
    }
}

// MARK: - Supporting Types

public enum LibraryAction {
    case favoriteUpdated(count: Int)
    case collectionsUpdated(count: Int)
    case layoutsUpdated(count: Int)
    case addedToMultiStream(streamTitle: String, slotIndex: Int)
    case addToMultiStreamFailed(reason: String)
    case addedCollectionToMultiStream(collectionName: String, streamsAdded: Int)
    case layoutApplied(layoutName: String)
    case createdCollectionFromMultiStream(collectionName: String, streamCount: Int)
    case savedLayout(layoutName: String)
    case addedToFavorites(streamTitle: String)
    case addToFavoritesFailed(reason: String)
    case streamAddedToMultiStream(streamTitle: String)
    case streamRemovedFromMultiStream(streamId: String)
    case layoutChanged(layoutName: String)
    case viewingSessionStarted(streamTitle: String)
    case viewingSessionEnded(streamTitle: String, duration: TimeInterval)
    
    public var description: String {
        switch self {
        case .favoriteUpdated(let count):
            return "Favorites updated (\(count) total)"
        case .collectionsUpdated(let count):
            return "Collections updated (\(count) total)"
        case .layoutsUpdated(let count):
            return "Layouts updated (\(count) total)"
        case .addedToMultiStream(let title, let slot):
            return "Added '\(title)' to multi-stream slot \(slot)"
        case .addToMultiStreamFailed(let reason):
            return "Failed to add to multi-stream: \(reason)"
        case .addedCollectionToMultiStream(let name, let count):
            return "Added collection '\(name)' (\(count) streams) to multi-stream"
        case .layoutApplied(let name):
            return "Applied layout '\(name)'"
        case .createdCollectionFromMultiStream(let name, let count):
            return "Created collection '\(name)' from \(count) streams"
        case .savedLayout(let name):
            return "Saved layout '\(name)'"
        case .addedToFavorites(let title):
            return "Added '\(title)' to favorites"
        case .addToFavoritesFailed(let reason):
            return "Failed to add to favorites: \(reason)"
        case .streamAddedToMultiStream(let title):
            return "Stream '\(title)' added to multi-stream"
        case .streamRemovedFromMultiStream(let id):
            return "Stream \(id) removed from multi-stream"
        case .layoutChanged(let name):
            return "Layout changed to '\(name)'"
        case .viewingSessionStarted(let title):
            return "Started viewing '\(title)'"
        case .viewingSessionEnded(let title, let duration):
            return "Ended viewing '\(title)' after \(Int(duration/60))m"
        }
    }
}

public struct LibraryExportData: Codable {
    public let favorites: [FavoriteStream]
    public let viewingHistory: [ViewingHistory]
    public let collections: [StreamCollection]
    public let layouts: [Layout]
    public let exportDate: Date
    public let version: String
}

public enum LibraryIntegrationError: Error, LocalizedError {
    case noActiveStreams
    case importNotImplemented
    case invalidData
    case conversionFailed
    
    public var errorDescription: String? {
        switch self {
        case .noActiveStreams:
            return "No active streams to save"
        case .importNotImplemented:
            return "Import functionality not yet implemented"
        case .invalidData:
            return "Invalid library data"
        case .conversionFailed:
            return "Failed to convert data"
        }
    }
}

// MARK: - Extension Helpers

private extension AppStream {
    func toTwitchStream() -> TwitchStream {
        return TwitchStream(
            id: self.id,
            userId: "user_\(self.streamerName)",
            userLogin: self.streamerName.lowercased(),
            userName: self.streamerName,
            gameId: "",
            gameName: self.gameName,
            type: "live",
            title: self.title,
            viewerCount: self.viewerCount,
            startedAt: ISO8601DateFormatter().string(from: Date()),
            language: self.language,
            thumbnailUrl: self.thumbnailURL,
            tagIds: nil,
            tags: nil,
            isMature: false
        )
    }
}

private extension TwitchStream {
    func toAppStream() -> AppStream {
        return AppStream(
            id: self.id,
            title: self.title,
            url: "https://twitch.tv/\(self.userLogin)",
            platform: "Twitch",
            isLive: self.type == "live",
            viewerCount: self.viewerCount,
            streamerName: self.userName,
            gameName: self.gameName ?? "",
            thumbnailURL: self.thumbnailUrl,
            language: self.language,
            startedAt: Date()
        )
    }
    
    func toStreamData() -> StreamData {
        return StreamData(
            id: self.id,
            title: self.title,
            url: "https://twitch.tv/\(self.userLogin)",
            platform: .twitch,
            streamerName: self.userName,
            thumbnailURL: self.thumbnailUrl,
            isLive: self.type == "live",
            viewerCount: self.viewerCount,
            category: self.gameName
        )
    }
}

private extension ViewingHistory {
    func toAppStream() -> AppStream {
        return AppStream(
            id: self.streamId,
            title: self.streamTitle,
            url: self.streamURL,
            platform: self.platform.displayName,
            isLive: self.wasLive,
            viewerCount: self.viewerCountAtView ?? 0,
            streamerName: self.streamerName ?? "",
            gameName: self.category ?? "",
            thumbnailURL: self.thumbnailURL ?? "",
            language: "en",
            startedAt: self.viewedAt
        )
    }
}

private extension LayoutType {
    func toMultiStreamLayout() -> MultiStreamLayout? {
        switch self {
        case .grid2x2: return .twoByTwo
        case .grid3x3: return .threeByThree
        case .grid4x4: return .fourByFour
        default: return nil
        }
    }
}

private extension MultiStreamLayout {
    func toLayoutType() -> LayoutType {
        switch self {
        case .single: return .focus
        case .twoByTwo: return .grid2x2
        case .threeByThree: return .grid3x3
        case .fourByFour: return .grid4x4
        }
    }
    
    func toLayoutConfiguration() -> LayoutConfiguration {
        return LayoutConfiguration.default(for: self.toLayoutType())
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let streamAdded = Notification.Name("streamAdded")
    static let streamRemoved = Notification.Name("streamRemoved")
    static let layoutChanged = Notification.Name("layoutChanged")
    static let viewingSessionStarted = Notification.Name("viewingSessionStarted")
    static let viewingSessionEnded = Notification.Name("viewingSessionEnded")
}