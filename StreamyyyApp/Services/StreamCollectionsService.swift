//
//  StreamCollectionsService.swift
//  StreamyyyApp
//
//  Service for managing stream collections/playlists with real persistence
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
public class StreamCollectionsService: ObservableObject {
    public static let shared = StreamCollectionsService()
    
    // MARK: - Published Properties
    @Published public var collections: [StreamCollection] = []
    @Published public var isLoading = false
    @Published public var error: CollectionError?
    @Published public var searchQuery = ""
    @Published public var filterCategory: CollectionCategory?
    @Published public var sortOption: CollectionSortOption = .dateUpdated
    @Published public var showPrivateOnly = false
    @Published public var showSharedOnly = false
    
    // MARK: - Statistics
    @Published public var totalCollections = 0
    @Published public var totalStreamsInCollections = 0
    @Published public var privateCollections = 0
    @Published public var sharedCollections = 0
    @Published public var averageCollectionSize: Double = 0.0
    @Published public var mostPopularCollection: StreamCollection?
    
    // MARK: - Private Properties
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let maxCollections = 500
    
    private init() {
        setupObservers()
        loadPreferences()
    }
    
    // MARK: - Setup Methods
    public func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCollections()
    }
    
    private func setupObservers() {
        // Search query observer
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterCollections()
            }
            .store(in: &cancellables)
        
        // Filter observers
        Publishers.CombineLatest4($filterCategory, $sortOption, $showPrivateOnly, $showSharedOnly)
            .sink { [weak self] _, _, _, _ in
                self?.filterCollections()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Create a new collection
    public func createCollection(
        name: String,
        description: String? = nil,
        icon: String = "folder",
        color: String = "blue",
        isPrivate: Bool = false,
        category: CollectionCategory = .other
    ) async throws -> StreamCollection {
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        // Validate name
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CollectionError.invalidName("Collection name cannot be empty")
        }
        
        // Check for duplicate names
        if collections.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            throw CollectionError.duplicateName(name)
        }
        
        // Check collection limit
        if collections.count >= maxCollections {
            throw CollectionError.limitReached(maxCollections)
        }
        
        isLoading = true
        error = nil
        
        do {
            let collection = StreamCollection(
                name: name,
                description: description,
                icon: icon,
                color: color,
                isPrivate: isPrivate
            )
            
            // Add category tag
            collection.addTag(category.rawValue)
            
            modelContext.insert(collection)
            try modelContext.save()
            
            collections.append(collection)
            await updateStatistics()
            
            print("Created collection: \(name)")
            isLoading = false
            
            return collection
            
        } catch {
            self.error = .createFailed(error)
            isLoading = false
            throw error
        }
    }
    
    /// Update an existing collection
    public func updateCollection(
        _ collection: StreamCollection,
        name: String? = nil,
        description: String? = nil,
        icon: String? = nil,
        color: String? = nil,
        isPrivate: Bool? = nil
    ) async throws {
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        isLoading = true
        error = nil
        
        do {
            if let newName = name {
                // Check for duplicate names (excluding current collection)
                if collections.contains(where: { $0.id != collection.id && $0.name.lowercased() == newName.lowercased() }) {
                    throw CollectionError.duplicateName(newName)
                }
                collection.updateName(newName)
            }
            
            if let newDescription = description {
                collection.updateDescription(newDescription)
            }
            
            if let newIcon = icon {
                collection.updateIcon(newIcon)
            }
            
            if let newColor = color {
                collection.updateColor(newColor)
            }
            
            if let newPrivate = isPrivate {
                if newPrivate != collection.isPrivate {
                    collection.togglePrivacy()
                }
            }
            
            try modelContext.save()
            
            if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[index] = collection
            }
            
            await updateStatistics()
            
            print("Updated collection: \(collection.name)")
            isLoading = false
            
        } catch {
            self.error = .updateFailed(error)
            isLoading = false
            throw error
        }
    }
    
    /// Delete a collection
    public func deleteCollection(_ collection: StreamCollection) async throws {
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        isLoading = true
        error = nil
        
        do {
            modelContext.delete(collection)
            try modelContext.save()
            
            collections.removeAll { $0.id == collection.id }
            await updateStatistics()
            
            print("Deleted collection: \(collection.name)")
            isLoading = false
            
        } catch {
            self.error = .deleteFailed(error)
            isLoading = false
            throw error
        }
    }
    
    /// Add a stream to a collection
    public func addStream(
        _ streamData: StreamData,
        to collection: StreamCollection,
        order: Int? = nil
    ) async throws {
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        // Check if stream already exists in collection
        if collection.streams.contains(where: { $0.streamId == streamData.id }) {
            throw CollectionError.streamAlreadyExists(streamData.id)
        }
        
        do {
            collection.addStream(streamData, order: order)
            try modelContext.save()
            
            if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[index] = collection
            }
            
            await updateStatistics()
            
            print("Added stream '\(streamData.title)' to collection '\(collection.name)'")
            
        } catch {
            self.error = .addStreamFailed(error)
            throw error
        }
    }
    
    /// Remove a stream from a collection
    public func removeStream(
        _ streamId: String,
        from collection: StreamCollection
    ) async throws {
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        do {
            collection.removeStream(streamId)
            try modelContext.save()
            
            if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[index] = collection
            }
            
            await updateStatistics()
            
            print("Removed stream from collection '\(collection.name)'")
            
        } catch {
            self.error = .removeStreamFailed(error)
            throw error
        }
    }
    
    /// Move a stream within a collection
    public func moveStream(
        in collection: StreamCollection,
        from sourceIndex: Int,
        to destinationIndex: Int
    ) async throws {
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        do {
            collection.moveStream(from: sourceIndex, to: destinationIndex)
            try modelContext.save()
            
            if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[index] = collection
            }
            
            print("Moved stream in collection '\(collection.name)'")
            
        } catch {
            self.error = .updateFailed(error)
            throw error
        }
    }
    
    /// Duplicate a collection
    public func duplicateCollection(_ collection: StreamCollection) async throws -> StreamCollection {
        let newName = "\(collection.name) Copy"
        
        let duplicatedCollection = try await createCollection(
            name: newName,
            description: collection.description,
            icon: collection.icon,
            color: collection.color,
            isPrivate: collection.isPrivate
        )
        
        // Copy streams
        for stream in collection.streams.sorted(by: { $0.order < $1.order }) {
            if let streamData = stream.streamData {
                try await addStream(streamData, to: duplicatedCollection)
            }
        }
        
        // Copy tags (excluding category)
        for tag in collection.tags {
            duplicatedCollection.addTag(tag)
        }
        
        return duplicatedCollection
    }
    
    /// Toggle favorite status of a collection
    public func toggleFavorite(_ collection: StreamCollection) async throws {
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        do {
            collection.toggleFavorite()
            try modelContext.save()
            
            if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[index] = collection
            }
            
            print("Toggled favorite for collection: \(collection.name)")
            
        } catch {
            self.error = .updateFailed(error)
            throw error
        }
    }
    
    /// Share a collection
    public func shareCollection(_ collection: StreamCollection, authorName: String? = nil) async throws -> String {
        guard !collection.isPrivate else {
            throw CollectionError.cannotSharePrivate
        }
        
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        do {
            collection.enableSharing(authorName: authorName)
            try modelContext.save()
            
            if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[index] = collection
            }
            
            await updateStatistics()
            
            return collection.shareCode ?? ""
            
        } catch {
            self.error = .shareFailed(error)
            throw error
        }
    }
    
    /// Import a collection from share code
    public func importCollection(shareCode: String) async throws -> StreamCollection {
        // In a real implementation, this would fetch from a remote service
        // For now, we'll just create a placeholder
        throw CollectionError.importFailed(NSError(domain: "Import", code: 0, userInfo: [NSLocalizedDescriptionKey: "Import from share code not implemented"]))
    }
    
    /// Export a collection
    public func exportCollection(_ collection: StreamCollection, format: ExportFormat = .json) -> Data? {
        switch format {
        case .json:
            let exportData = collection.exportConfiguration()
            return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        case .csv:
            return exportCollectionAsCSV(collection)
        }
    }
    
    /// Import a collection from data
    public func importCollectionFromData(_ data: Data, format: ExportFormat = .json) async throws -> StreamCollection {
        switch format {
        case .json:
            return try await importCollectionFromJSON(data)
        case .csv:
            throw CollectionError.importFailed(NSError(domain: "Import", code: 0, userInfo: [NSLocalizedDescriptionKey: "CSV import not supported"]))
        }
    }
    
    /// Get collections by category
    public func getCollections(by category: CollectionCategory) -> [StreamCollection] {
        return collections.filter { $0.hasTag(category.rawValue) }
    }
    
    /// Get collections containing a specific stream
    public func getCollections(containing streamId: String) -> [StreamCollection] {
        return collections.filter { collection in
            collection.streams.contains { $0.streamId == streamId }
        }
    }
    
    /// Search collections
    public func searchCollections(_ query: String) -> [StreamCollection] {
        guard !query.isEmpty else { return collections }
        
        return collections.filter { collection in
            collection.name.localizedCaseInsensitiveContains(query) ||
            collection.description?.localizedCaseInsensitiveContains(query) == true ||
            collection.tags.joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCollections() {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        
        do {
            let descriptor = FetchDescriptor<StreamCollection>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            collections = try modelContext.fetch(descriptor)
            
            Task {
                await updateStatistics()
            }
            
        } catch {
            self.error = .loadFailed(error)
        }
        
        isLoading = false
    }
    
    private func filterCollections() {
        // Apply sorting
        collections.sort { lhs, rhs in
            switch sortOption {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .dateCreated:
                return lhs.createdAt > rhs.createdAt
            case .dateUpdated:
                return lhs.updatedAt > rhs.updatedAt
            case .lastAccessed:
                return (lhs.lastAccessedAt ?? Date.distantPast) > (rhs.lastAccessedAt ?? Date.distantPast)
            case .streamCount:
                return lhs.totalStreams > rhs.totalStreams
            case .duration:
                return lhs.totalDuration > rhs.totalDuration
            case .rating:
                return lhs.rating > rhs.rating
            case .accessCount:
                return lhs.accessCount > rhs.accessCount
            }
        }
    }
    
    private func updateStatistics() async {
        totalCollections = collections.count
        totalStreamsInCollections = collections.reduce(0) { $0 + $1.totalStreams }
        privateCollections = collections.filter { $0.isPrivate }.count
        sharedCollections = collections.filter { $0.isShared }.count
        
        if !collections.isEmpty {
            averageCollectionSize = Double(totalStreamsInCollections) / Double(totalCollections)
        } else {
            averageCollectionSize = 0.0
        }
        
        mostPopularCollection = collections.max { $0.accessCount < $1.accessCount }
        
        savePreferences()
    }
    
    private func loadPreferences() {
        if let sortRawValue = userDefaults.string(forKey: "collectionsSort"),
           let sort = CollectionSortOption(rawValue: sortRawValue) {
            sortOption = sort
        }
        
        showPrivateOnly = userDefaults.bool(forKey: "showPrivateOnly")
        showSharedOnly = userDefaults.bool(forKey: "showSharedOnly")
    }
    
    private func savePreferences() {
        userDefaults.set(sortOption.rawValue, forKey: "collectionsSort")
        userDefaults.set(showPrivateOnly, forKey: "showPrivateOnly")
        userDefaults.set(showSharedOnly, forKey: "showSharedOnly")
    }
    
    private func exportCollectionAsCSV(_ collection: StreamCollection) -> Data? {
        var csv = "Order,Stream Title,Streamer,Platform,Added Date,View Count,Notes\n"
        
        for stream in collection.streams.sorted(by: { $0.order < $1.order }) {
            let row = [
                String(stream.order),
                stream.displayTitle,
                stream.streamData?.streamerName ?? "",
                stream.streamData?.platform.displayName ?? "",
                DateFormatter.localizedString(from: stream.addedAt, dateStyle: .medium, timeStyle: .short),
                String(stream.viewCount),
                stream.notes ?? ""
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv.data(using: .utf8)
    }
    
    private func importCollectionFromJSON(_ data: Data) async throws -> StreamCollection {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let collection = StreamCollection.importConfiguration(json) else {
            throw CollectionError.importFailed(NSError(domain: "Import", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid collection data"]))
        }
        
        guard let modelContext = modelContext else {
            throw CollectionError.contextNotSet
        }
        
        // Make sure name is unique
        var finalName = collection.name
        var counter = 1
        while collections.contains(where: { $0.name.lowercased() == finalName.lowercased() }) {
            finalName = "\(collection.name) (\(counter))"
            counter += 1
        }
        collection.updateName(finalName)
        
        do {
            modelContext.insert(collection)
            try modelContext.save()
            
            collections.append(collection)
            await updateStatistics()
            
            return collection
            
        } catch {
            throw CollectionError.importFailed(error)
        }
    }
}

// MARK: - Collection Error
public enum CollectionError: Error, LocalizedError {
    case contextNotSet
    case invalidName(String)
    case duplicateName(String)
    case limitReached(Int)
    case createFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case loadFailed(Error)
    case addStreamFailed(Error)
    case removeStreamFailed(Error)
    case streamAlreadyExists(String)
    case streamNotFound(String)
    case cannotSharePrivate
    case shareFailed(Error)
    case importFailed(Error)
    case exportFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .contextNotSet:
            return "Database context not set"
        case .invalidName(let message):
            return message
        case .duplicateName(let name):
            return "Collection '\(name)' already exists"
        case .limitReached(let limit):
            return "Maximum collections limit reached (\(limit))"
        case .createFailed(let error):
            return "Failed to create collection: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update collection: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete collection: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load collections: \(error.localizedDescription)"
        case .addStreamFailed(let error):
            return "Failed to add stream: \(error.localizedDescription)"
        case .removeStreamFailed(let error):
            return "Failed to remove stream: \(error.localizedDescription)"
        case .streamAlreadyExists(let id):
            return "Stream '\(id)' already exists in collection"
        case .streamNotFound(let id):
            return "Stream '\(id)' not found in collection"
        case .cannotSharePrivate:
            return "Cannot share private collections"
        case .shareFailed(let error):
            return "Failed to share collection: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Failed to import collection: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Failed to export collection: \(error.localizedDescription)"
        }
    }
}