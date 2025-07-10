//
//  OfflineModeService.swift
//  StreamyyyApp
//
//  Offline mode service for cached data and functionality
//

import Foundation
import Combine
import SwiftUI

@MainActor
class OfflineModeService: ObservableObject {
    static let shared = OfflineModeService()
    
    // MARK: - Published Properties
    @Published var isOfflineMode = false
    @Published var offlineData: OfflineData = OfflineData()
    @Published var lastSyncTime: Date?
    @Published var offlineCapabilities: OfflineCapabilities = OfflineCapabilities()
    @Published var syncProgress: Double = 0.0
    @Published var isSyncing = false
    
    // MARK: - Private Properties
    private let networkManager = NetworkManager.shared
    private let cacheManager = CacheManager.shared
    private let twitchService = TwitchService.shared
    private let youtubeService = YouTubeService()
    
    private var cancellables = Set<AnyCancellable>()
    private let offlineDataKey = "offline_data"
    private let lastSyncKey = "last_sync_time"
    
    // Configuration
    private let maxOfflineStreams = 100
    private let maxOfflineThumbnails = 200
    private let maxOfflineUserData = 50
    private let syncInterval: TimeInterval = 3600 // 1 hour
    
    private init() {
        setupNetworkMonitoring()
        loadOfflineData()
        setupPeriodicSync()
    }
    
    // MARK: - Public Methods
    
    func enableOfflineMode() {
        isOfflineMode = true
        updateOfflineCapabilities()
    }
    
    func disableOfflineMode() {
        isOfflineMode = false
        updateOfflineCapabilities()
    }
    
    func syncForOfflineUse() async {
        guard networkManager.isConnected else {
            print("Cannot sync: No network connection")
            return
        }
        
        isSyncing = true
        syncProgress = 0.0
        
        do {
            // Sync streams
            await syncStreams()
            syncProgress = 0.3
            
            // Sync thumbnails
            await syncThumbnails()
            syncProgress = 0.6
            
            // Sync user data
            await syncUserData()
            syncProgress = 0.8
            
            // Sync favorites
            await syncFavorites()
            syncProgress = 0.9
            
            // Save offline data
            saveOfflineData()
            lastSyncTime = Date()
            syncProgress = 1.0
            
        } catch {
            print("Sync failed: \(error)")
        }
        
        isSyncing = false
    }
    
    func getOfflineStreams() -> [AppStream] {
        return offlineData.streams
    }
    
    func getOfflineFavorites() -> [AppStream] {
        return offlineData.favorites
    }
    
    func getOfflineUserData() -> [UserProfile] {
        return offlineData.userData
    }
    
    func searchOfflineStreams(query: String) -> [AppStream] {
        let lowercaseQuery = query.lowercased()
        return offlineData.streams.filter { stream in
            stream.title.lowercased().contains(lowercaseQuery) ||
            stream.streamerName.lowercased().contains(lowercaseQuery) ||
            stream.gameName.lowercased().contains(lowercaseQuery)
        }
    }
    
    func addStreamToOffline(_ stream: AppStream) {
        if !offlineData.streams.contains(where: { $0.id == stream.id }) {
            offlineData.streams.append(stream)
            
            // Limit offline streams
            if offlineData.streams.count > maxOfflineStreams {
                offlineData.streams.removeFirst(offlineData.streams.count - maxOfflineStreams)
            }
            
            saveOfflineData()
        }
    }
    
    func removeStreamFromOffline(_ streamId: String) {
        offlineData.streams.removeAll { $0.id == streamId }
        saveOfflineData()
    }
    
    func addFavoriteToOffline(_ stream: AppStream) {
        if !offlineData.favorites.contains(where: { $0.id == stream.id }) {
            offlineData.favorites.append(stream)
            saveOfflineData()
        }
    }
    
    func removeFavoriteFromOffline(_ streamId: String) {
        offlineData.favorites.removeAll { $0.id == streamId }
        saveOfflineData()
    }
    
    func getOfflineThumbnail(for streamId: String) -> UIImage? {
        guard let thumbnailData = cacheManager.retrieveThumbnail(forKey: streamId) else {
            return nil
        }
        return UIImage(data: thumbnailData)
    }
    
    func getCachedStreamData(for key: String) -> [AppStream]? {
        return cacheManager.retrieveStreamData(forKey: key)
    }
    
    func isStreamAvailableOffline(_ streamId: String) -> Bool {
        return offlineData.streams.contains { $0.id == streamId }
    }
    
    func getOfflineDataSize() -> Int64 {
        return cacheManager.cacheSize
    }
    
    func clearOfflineData() {
        offlineData = OfflineData()
        saveOfflineData()
        cacheManager.clearAll()
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if !isConnected && !self?.isOfflineMode ?? false {
                    self?.enableOfflineMode()
                } else if isConnected && self?.isOfflineMode ?? false {
                    // Optionally disable offline mode when connection is restored
                    // self?.disableOfflineMode()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadOfflineData() {
        if let data = UserDefaults.standard.data(forKey: offlineDataKey),
           let offlineData = try? JSONDecoder().decode(OfflineData.self, from: data) {
            self.offlineData = offlineData
        }
        
        if let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncTime = lastSync
        }
        
        updateOfflineCapabilities()
    }
    
    private func saveOfflineData() {
        if let data = try? JSONEncoder().encode(offlineData) {
            UserDefaults.standard.set(data, forKey: offlineDataKey)
        }
        
        if let lastSync = lastSyncTime {
            UserDefaults.standard.set(lastSync, forKey: lastSyncKey)
        }
    }
    
    private func setupPeriodicSync() {
        Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            if NetworkManager.shared.isConnected {
                Task {
                    await self.syncForOfflineUse()
                }
            }
        }
    }
    
    private func updateOfflineCapabilities() {
        offlineCapabilities = OfflineCapabilities(
            canBrowseStreams: !offlineData.streams.isEmpty,
            canViewFavorites: !offlineData.favorites.isEmpty,
            canSearch: !offlineData.streams.isEmpty,
            canViewProfile: !offlineData.userData.isEmpty,
            canViewThumbnails: true, // Cached thumbnails
            canPlayStreams: false, // Cannot play streams offline
            canAddFavorites: true, // Can add to local favorites
            canModifySettings: true,
            totalStreamsAvailable: offlineData.streams.count,
            totalFavoritesAvailable: offlineData.favorites.count,
            totalUserDataAvailable: offlineData.userData.count,
            lastSyncTime: lastSyncTime
        )
    }
    
    private func syncStreams() async {
        do {
            // Sync popular streams from multiple platforms
            let twitchStreams = try await syncTwitchStreams()
            let youtubeStreams = try await syncYouTubeStreams()
            
            let allStreams = twitchStreams + youtubeStreams
            
            // Limit and sort by popularity
            let popularStreams = allStreams
                .sorted { $0.viewerCount > $1.viewerCount }
                .prefix(maxOfflineStreams)
            
            offlineData.streams = Array(popularStreams)
            
            // Cache stream data
            cacheManager.storeStreamData(offlineData.streams, forKey: "offline_streams")
            
        } catch {
            print("Failed to sync streams: \(error)")
        }
    }
    
    private func syncTwitchStreams() async throws -> [AppStream] {
        if !twitchService.isAuthenticated {
            try await twitchService.getAppAccessToken()
        }
        
        let (twitchStreams, _) = try await twitchService.getTopStreams(first: 50)
        
        return twitchStreams.map { twitchStream in
            AppStream(
                id: twitchStream.id,
                title: twitchStream.title,
                url: "https://twitch.tv/\(twitchStream.userLogin)",
                platform: "Twitch",
                isLive: twitchStream.type == "live",
                viewerCount: twitchStream.viewerCount,
                streamerName: twitchStream.userName,
                gameName: twitchStream.gameName,
                thumbnailURL: twitchService.formatThumbnailURL(twitchStream.thumbnailURL),
                language: twitchStream.language ?? "en",
                startedAt: ISO8601DateFormatter().date(from: twitchStream.startedAt) ?? Date()
            )
        }
    }
    
    private func syncYouTubeStreams() async throws -> [AppStream] {
        let searchResult = try await youtubeService.getLiveStreams(maxResults: 50)
        
        return searchResult.items.compactMap { item in
            guard let videoId = item.videoId else { return nil }
            
            return AppStream(
                id: videoId,
                title: item.snippet.title,
                url: "https://youtube.com/watch?v=\(videoId)",
                platform: "YouTube",
                isLive: item.isLive,
                viewerCount: 0,
                streamerName: item.snippet.channelTitle,
                gameName: "",
                thumbnailURL: item.bestThumbnailUrl,
                language: "en",
                startedAt: ISO8601DateFormatter().date(from: item.snippet.publishedAt) ?? Date()
            )
        }
    }
    
    private func syncThumbnails() async {
        for stream in offlineData.streams.prefix(maxOfflineThumbnails) {
            guard !stream.thumbnailURL.isEmpty,
                  let url = URL(string: stream.thumbnailURL) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                cacheManager.storeThumbnail(data, forKey: stream.id)
            } catch {
                print("Failed to cache thumbnail for \(stream.id): \(error)")
            }
        }
    }
    
    private func syncUserData() async {
        // Sync user profiles and related data
        // This would fetch user data from the authenticated services
        offlineData.userData = [] // Placeholder
    }
    
    private func syncFavorites() async {
        // Sync favorites from cloud storage or user preferences
        if let favoritesData = UserDefaults.standard.data(forKey: "favorite_streams"),
           let favorites = try? JSONDecoder().decode([AppStream].self, from: favoritesData) {
            offlineData.favorites = favorites
        }
    }
    
    // MARK: - Computed Properties
    
    var canFunctionOffline: Bool {
        return !offlineData.streams.isEmpty || !offlineData.favorites.isEmpty
    }
    
    var timeSinceLastSync: TimeInterval? {
        guard let lastSync = lastSyncTime else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
    
    var syncStatus: String {
        if isSyncing {
            return "Syncing... \(Int(syncProgress * 100))%"
        } else if let timeSince = timeSinceLastSync {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            return "Last sync: \(formatter.string(from: timeSince) ?? "Unknown")"
        } else {
            return "Never synced"
        }
    }
}

// MARK: - Supporting Models

struct OfflineData: Codable {
    var streams: [AppStream] = []
    var favorites: [AppStream] = []
    var userData: [UserProfile] = []
    var settings: [String: String] = [:]
    var lastUpdated: Date = Date()
}

struct OfflineCapabilities {
    let canBrowseStreams: Bool
    let canViewFavorites: Bool
    let canSearch: Bool
    let canViewProfile: Bool
    let canViewThumbnails: Bool
    let canPlayStreams: Bool
    let canAddFavorites: Bool
    let canModifySettings: Bool
    let totalStreamsAvailable: Int
    let totalFavoritesAvailable: Int
    let totalUserDataAvailable: Int
    let lastSyncTime: Date?
    
    init(canBrowseStreams: Bool = false, canViewFavorites: Bool = false, canSearch: Bool = false, canViewProfile: Bool = false, canViewThumbnails: Bool = false, canPlayStreams: Bool = false, canAddFavorites: Bool = false, canModifySettings: Bool = false, totalStreamsAvailable: Int = 0, totalFavoritesAvailable: Int = 0, totalUserDataAvailable: Int = 0, lastSyncTime: Date? = nil) {
        self.canBrowseStreams = canBrowseStreams
        self.canViewFavorites = canViewFavorites
        self.canSearch = canSearch
        self.canViewProfile = canViewProfile
        self.canViewThumbnails = canViewThumbnails
        self.canPlayStreams = canPlayStreams
        self.canAddFavorites = canAddFavorites
        self.canModifySettings = canModifySettings
        self.totalStreamsAvailable = totalStreamsAvailable
        self.totalFavoritesAvailable = totalFavoritesAvailable
        self.totalUserDataAvailable = totalUserDataAvailable
        self.lastSyncTime = lastSyncTime
    }
}

// MARK: - Offline Mode Views

struct OfflineModeIndicator: View {
    @ObservedObject var offlineService = OfflineModeService.shared
    @ObservedObject var networkManager = NetworkManager.shared
    
    var body: some View {
        Group {
            if offlineService.isOfflineMode {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                    Text("Offline Mode")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            } else if !networkManager.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.red)
                    Text("No Connection")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
}

struct OfflineModeSettings: View {
    @ObservedObject var offlineService = OfflineModeService.shared
    @State private var showingClearConfirmation = false
    
    var body: some View {
        Section(header: Text("Offline Mode")) {
            Toggle("Enable Offline Mode", isOn: Binding(
                get: { offlineService.isOfflineMode },
                set: { enabled in
                    if enabled {
                        offlineService.enableOfflineMode()
                    } else {
                        offlineService.disableOfflineMode()
                    }
                }
            ))
            
            if offlineService.isOfflineMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Offline Capabilities")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    OfflineCapabilityRow(
                        title: "Browse Streams",
                        available: offlineService.offlineCapabilities.canBrowseStreams,
                        count: offlineService.offlineCapabilities.totalStreamsAvailable
                    )
                    
                    OfflineCapabilityRow(
                        title: "View Favorites",
                        available: offlineService.offlineCapabilities.canViewFavorites,
                        count: offlineService.offlineCapabilities.totalFavoritesAvailable
                    )
                    
                    OfflineCapabilityRow(
                        title: "Search",
                        available: offlineService.offlineCapabilities.canSearch,
                        count: nil
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Sync Status")
                        .font(.subheadline)
                    Text(offlineService.syncStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Sync Now") {
                    Task {
                        await offlineService.syncForOfflineUse()
                    }
                }
                .disabled(offlineService.isSyncing)
            }
            
            if offlineService.isSyncing {
                ProgressView(value: offlineService.syncProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            HStack {
                Text("Offline Data Size")
                Spacer()
                Text(offlineService.cacheManager.formattedCacheSize)
                    .foregroundColor(.secondary)
            }
            
            Button("Clear Offline Data") {
                showingClearConfirmation = true
            }
            .foregroundColor(.red)
            .confirmationDialog("Clear Offline Data", isPresented: $showingClearConfirmation) {
                Button("Clear All Data", role: .destructive) {
                    offlineService.clearOfflineData()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

struct OfflineCapabilityRow: View {
    let title: String
    let available: Bool
    let count: Int?
    
    var body: some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(available ? .green : .red)
            
            Text(title)
                .font(.caption)
            
            Spacer()
            
            if let count = count {
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}