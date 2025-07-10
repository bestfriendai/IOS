//
//  UserFavoritesService.swift
//  StreamyyyApp
//
//  User favorites synchronization with cloud backend
//

import Foundation
import Combine
import CloudKit

@MainActor
class UserFavoritesService: ObservableObject {
    static let shared = UserFavoritesService()
    
    // MARK: - Published Properties
    @Published var favorites: [FavoriteStream] = []
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: FavoritesError?
    @Published var cloudKitStatus: CloudKitStatus = .unknown
    
    // MARK: - Private Properties
    private let container = CKContainer.default()
    private let database: CKDatabase
    private let networkManager = NetworkManager.shared
    private let cacheManager = CacheManager.shared
    private let authService = AuthenticationService.shared
    private let offlineService = OfflineModeService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let recordType = "FavoriteStream"
    private let localStorageKey = "user_favorites"
    private let lastSyncKey = "favorites_last_sync"
    private let maxFavorites = 100
    
    private init() {
        self.database = container.privateCloudDatabase
        
        setupCloudKitStatus()
        loadLocalFavorites()
        setupAuthenticationObserver()
        setupNetworkObserver()
    }
    
    // MARK: - Public Methods
    
    func addFavorite(_ stream: AppStream) async {
        let favorite = FavoriteStream(
            id: stream.id,
            streamId: stream.id,
            title: stream.title,
            streamerName: stream.streamerName,
            platform: stream.platform,
            url: stream.url,
            thumbnailURL: stream.thumbnailURL,
            gameName: stream.gameName,
            addedAt: Date(),
            lastUpdated: Date(),
            isActive: true
        )
        
        // Add to local favorites
        if !favorites.contains(where: { $0.streamId == favorite.streamId }) {
            favorites.append(favorite)
            
            // Limit favorites
            if favorites.count > maxFavorites {
                favorites.removeFirst(favorites.count - maxFavorites)
            }
            
            saveLocalFavorites()
            
            // Add to offline data
            offlineService.addFavoriteToOffline(stream)
            
            // Sync to cloud
            await syncFavoriteToCloud(favorite)
        }
    }
    
    func removeFavorite(_ streamId: String) async {
        if let index = favorites.firstIndex(where: { $0.streamId == streamId }) {
            let favorite = favorites[index]
            favorites.remove(at: index)
            
            saveLocalFavorites()
            
            // Remove from offline data
            offlineService.removeFavoriteFromOffline(streamId)
            
            // Remove from cloud
            await removeFavoriteFromCloud(favorite)
        }
    }
    
    func toggleFavorite(_ stream: AppStream) async {
        if isFavorite(stream.id) {
            await removeFavorite(stream.id)
        } else {
            await addFavorite(stream)
        }
    }
    
    func isFavorite(_ streamId: String) -> Bool {
        return favorites.contains(where: { $0.streamId == streamId })
    }
    
    func getFavorites() -> [FavoriteStream] {
        return favorites.filter { $0.isActive }
    }
    
    func getFavoritesByPlatform(_ platform: String) -> [FavoriteStream] {
        return favorites.filter { $0.platform == platform && $0.isActive }
    }
    
    func searchFavorites(_ query: String) -> [FavoriteStream] {
        let lowercaseQuery = query.lowercased()
        return favorites.filter { favorite in
            favorite.title.lowercased().contains(lowercaseQuery) ||
            favorite.streamerName.lowercased().contains(lowercaseQuery) ||
            favorite.gameName.lowercased().contains(lowercaseQuery)
        }
    }
    
    func syncFavorites() async {
        guard networkManager.isConnected else {
            syncError = .networkError
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            try await performFullSync()
            lastSyncTime = Date()
            UserDefaults.standard.set(lastSyncTime, forKey: lastSyncKey)
        } catch {
            syncError = FavoritesError.syncFailed(error)
        }
        
        isSyncing = false
    }
    
    func clearAllFavorites() async {
        // Clear local favorites
        favorites.removeAll()
        saveLocalFavorites()
        
        // Clear offline favorites
        for favorite in favorites {
            offlineService.removeFavoriteFromOffline(favorite.streamId)
        }
        
        // Clear cloud favorites
        await clearCloudFavorites()
    }
    
    // MARK: - Private Methods
    
    private func setupCloudKitStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.cloudKitStatus = .available
                case .noAccount:
                    self?.cloudKitStatus = .noAccount
                case .restricted:
                    self?.cloudKitStatus = .restricted
                case .couldNotDetermine:
                    self?.cloudKitStatus = .unknown
                @unknown default:
                    self?.cloudKitStatus = .unknown
                }
            }
        }
    }
    
    private func loadLocalFavorites() {
        if let data = UserDefaults.standard.data(forKey: localStorageKey),
           let favorites = try? JSONDecoder().decode([FavoriteStream].self, from: data) {
            self.favorites = favorites
        }
        
        if let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncTime = lastSync
        }
    }
    
    private func saveLocalFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: localStorageKey)
        }
    }
    
    private func setupAuthenticationObserver() {
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task {
                        await self?.syncFavorites()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupNetworkObserver() {
        networkManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    Task {
                        await self?.syncFavorites()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func syncFavoriteToCloud(_ favorite: FavoriteStream) async {
        guard cloudKitStatus == .available else { return }
        
        do {
            let record = try createCloudKitRecord(from: favorite)
            try await database.save(record)
        } catch {
            syncError = FavoritesError.cloudKitError(error)
        }
    }
    
    private func removeFavoriteFromCloud(_ favorite: FavoriteStream) async {
        guard cloudKitStatus == .available else { return }
        
        do {
            let recordID = CKRecord.ID(recordName: favorite.id)
            try await database.deleteRecord(withID: recordID)
        } catch {
            syncError = FavoritesError.cloudKitError(error)
        }
    }
    
    private func performFullSync() async throws {
        guard cloudKitStatus == .available else {
            throw FavoritesError.cloudKitUnavailable
        }
        
        // Fetch all favorites from CloudKit
        let cloudFavorites = try await fetchCloudFavorites()
        
        // Merge with local favorites
        let mergedFavorites = mergeLocalAndCloudFavorites(
            local: favorites,
            cloud: cloudFavorites
        )
        
        // Update local favorites
        favorites = mergedFavorites
        saveLocalFavorites()
        
        // Sync any new local favorites to cloud
        for favorite in favorites {
            if !cloudFavorites.contains(where: { $0.id == favorite.id }) {
                await syncFavoriteToCloud(favorite)
            }
        }
    }
    
    private func fetchCloudFavorites() async throws -> [FavoriteStream] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: false)]
        
        let (matchResults, _) = try await database.records(matching: query)
        
        var cloudFavorites: [FavoriteStream] = []
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let favorite = createFavoriteStream(from: record) {
                    cloudFavorites.append(favorite)
                }
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        
        return cloudFavorites
    }
    
    private func createCloudKitRecord(from favorite: FavoriteStream) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: favorite.id)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        record["streamId"] = favorite.streamId
        record["title"] = favorite.title
        record["streamerName"] = favorite.streamerName
        record["platform"] = favorite.platform
        record["url"] = favorite.url
        record["thumbnailURL"] = favorite.thumbnailURL
        record["gameName"] = favorite.gameName
        record["addedAt"] = favorite.addedAt
        record["lastUpdated"] = favorite.lastUpdated
        record["isActive"] = favorite.isActive
        
        return record
    }
    
    private func createFavoriteStream(from record: CKRecord) -> FavoriteStream? {
        guard let streamId = record["streamId"] as? String,
              let title = record["title"] as? String,
              let streamerName = record["streamerName"] as? String,
              let platform = record["platform"] as? String,
              let url = record["url"] as? String,
              let addedAt = record["addedAt"] as? Date,
              let lastUpdated = record["lastUpdated"] as? Date,
              let isActive = record["isActive"] as? Bool else {
            return nil
        }
        
        return FavoriteStream(
            id: record.recordID.recordName,
            streamId: streamId,
            title: title,
            streamerName: streamerName,
            platform: platform,
            url: url,
            thumbnailURL: record["thumbnailURL"] as? String ?? "",
            gameName: record["gameName"] as? String ?? "",
            addedAt: addedAt,
            lastUpdated: lastUpdated,
            isActive: isActive
        )
    }
    
    private func mergeLocalAndCloudFavorites(
        local: [FavoriteStream],
        cloud: [FavoriteStream]
    ) -> [FavoriteStream] {
        var merged: [String: FavoriteStream] = [:]
        
        // Add all cloud favorites
        for favorite in cloud {
            merged[favorite.id] = favorite
        }
        
        // Add or update with local favorites
        for favorite in local {
            if let existing = merged[favorite.id] {
                // Keep the most recently updated version
                if favorite.lastUpdated > existing.lastUpdated {
                    merged[favorite.id] = favorite
                }
            } else {
                merged[favorite.id] = favorite
            }
        }
        
        return Array(merged.values)
            .sorted { $0.addedAt > $1.addedAt }
            .prefix(maxFavorites)
            .compactMap { $0 }
    }
    
    private func clearCloudFavorites() async {
        guard cloudKitStatus == .available else { return }
        
        do {
            let cloudFavorites = try await fetchCloudFavorites()
            
            for favorite in cloudFavorites {
                let recordID = CKRecord.ID(recordName: favorite.id)
                try await database.deleteRecord(withID: recordID)
            }
        } catch {
            syncError = FavoritesError.cloudKitError(error)
        }
    }
    
    // MARK: - Computed Properties
    
    var favoritesCount: Int {
        return favorites.filter { $0.isActive }.count
    }
    
    var favoritesByPlatform: [String: Int] {
        let activeFavorites = favorites.filter { $0.isActive }
        var counts: [String: Int] = [:]
        
        for favorite in activeFavorites {
            counts[favorite.platform, default: 0] += 1
        }
        
        return counts
    }
    
    var canSync: Bool {
        return networkManager.isConnected && cloudKitStatus == .available
    }
    
    var syncStatusText: String {
        if isSyncing {
            return "Syncing favorites..."
        } else if let lastSync = lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            return "Last sync: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Never synced"
        }
    }
}

// MARK: - Supporting Models

struct FavoriteStream: Codable, Identifiable {
    let id: String
    let streamId: String
    let title: String
    let streamerName: String
    let platform: String
    let url: String
    let thumbnailURL: String
    let gameName: String
    let addedAt: Date
    let lastUpdated: Date
    let isActive: Bool
    
    init(id: String = UUID().uuidString, streamId: String, title: String, streamerName: String, platform: String, url: String, thumbnailURL: String, gameName: String, addedAt: Date, lastUpdated: Date, isActive: Bool) {
        self.id = id
        self.streamId = streamId
        self.title = title
        self.streamerName = streamerName
        self.platform = platform
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.gameName = gameName
        self.addedAt = addedAt
        self.lastUpdated = lastUpdated
        self.isActive = isActive
    }
    
    var asAppStream: AppStream {
        return AppStream(
            id: streamId,
            title: title,
            url: url,
            platform: platform,
            isLive: true, // Assume live for favorites
            viewerCount: 0,
            streamerName: streamerName,
            gameName: gameName,
            thumbnailURL: thumbnailURL,
            language: "en",
            startedAt: addedAt
        )
    }
}

enum CloudKitStatus {
    case available
    case noAccount
    case restricted
    case unknown
    
    var displayName: String {
        switch self {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "Restricted"
        case .unknown:
            return "Unknown"
        }
    }
    
    var color: Color {
        switch self {
        case .available:
            return .green
        case .noAccount:
            return .orange
        case .restricted:
            return .red
        case .unknown:
            return .gray
        }
    }
}

enum FavoritesError: Error, LocalizedError {
    case networkError
    case cloudKitUnavailable
    case cloudKitError(Error)
    case syncFailed(Error)
    case maxFavoritesReached
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection required"
        case .cloudKitUnavailable:
            return "iCloud is not available"
        case .cloudKitError(let error):
            return "CloudKit error: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .maxFavoritesReached:
            return "Maximum favorites limit reached"
        }
    }
}

// MARK: - SwiftUI Views

struct FavoritesStatusView: View {
    @ObservedObject var favoritesService = UserFavoritesService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Favorites")
                    .font(.headline)
                
                Spacer()
                
                Text("\(favoritesService.favoritesCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Circle()
                    .fill(favoritesService.cloudKitStatus.color)
                    .frame(width: 8, height: 8)
                
                Text(favoritesService.cloudKitStatus.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if favoritesService.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text(favoritesService.syncStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct FavoriteButton: View {
    let stream: AppStream
    @ObservedObject var favoritesService = UserFavoritesService.shared
    @State private var isProcessing = false
    
    var body: some View {
        Button(action: {
            isProcessing = true
            Task {
                await favoritesService.toggleFavorite(stream)
                isProcessing = false
            }
        }) {
            Image(systemName: favoritesService.isFavorite(stream.id) ? "heart.fill" : "heart")
                .foregroundColor(favoritesService.isFavorite(stream.id) ? .red : .gray)
                .scaleEffect(isProcessing ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isProcessing)
        }
        .disabled(isProcessing)
    }
}