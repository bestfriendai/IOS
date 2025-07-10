//
//  StreamMonitoringService.swift
//  StreamyyyApp
//
//  Real-time stream monitoring and health checking service
//

import Foundation
import Combine
import Network

@MainActor
class StreamMonitoringService: ObservableObject {
    static let shared = StreamMonitoringService()
    
    // MARK: - Published Properties
    @Published var monitoredStreams: [String: StreamMonitorStatus] = [:]
    @Published var isMonitoring = false
    @Published var lastUpdateTime: Date?
    @Published var monitoringErrors: [StreamMonitorError] = []
    
    // MARK: - Private Properties
    private let twitchService = TwitchService.shared
    private let youtubeService = YouTubeService()
    private let networkManager = NetworkManager.shared
    private let cacheManager = CacheManager.shared
    
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let monitoringInterval: TimeInterval = 30 // 30 seconds
    private let batchSize = 20
    private let maxRetries = 3
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { _ in
            Task {
                await self.performMonitoringCycle()
            }
        }
        
        // Perform initial check
        Task {
            await performMonitoringCycle()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    func addStreamToMonitoring(streamId: String, platform: String, url: String) {
        let status = StreamMonitorStatus(
            streamId: streamId,
            platform: platform,
            url: url,
            isLive: false,
            viewerCount: 0,
            lastChecked: Date(),
            healthStatus: .unknown,
            consecutiveErrors: 0
        )
        
        monitoredStreams[streamId] = status
        
        // Perform immediate check for new stream
        Task {
            await checkStreamStatus(streamId: streamId)
        }
    }
    
    func removeStreamFromMonitoring(streamId: String) {
        monitoredStreams.removeValue(forKey: streamId)
    }
    
    func getStreamStatus(streamId: String) -> StreamMonitorStatus? {
        return monitoredStreams[streamId]
    }
    
    func refreshStreamStatus(streamId: String) async {
        await checkStreamStatus(streamId: streamId)
    }
    
    func refreshAllStreams() async {
        await performMonitoringCycle()
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        // Monitor network changes
        networkManager.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                if isConnected {
                    // Network restored, refresh all streams
                    Task {
                        await self?.performMonitoringCycle()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func performMonitoringCycle() async {
        guard isMonitoring, networkManager.isConnected else { return }
        
        let streamIds = Array(monitoredStreams.keys)
        
        // Process streams in batches to avoid rate limiting
        for batch in streamIds.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for streamId in batch {
                    group.addTask {
                        await self.checkStreamStatus(streamId: streamId)
                    }
                }
            }
            
            // Small delay between batches
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        lastUpdateTime = Date()
    }
    
    private func checkStreamStatus(streamId: String) async {
        guard let currentStatus = monitoredStreams[streamId] else { return }
        
        do {
            let newStatus = try await fetchStreamStatus(for: currentStatus)
            
            // Update status
            monitoredStreams[streamId] = newStatus
            
            // Cache the result
            cacheStreamStatus(newStatus)
            
            // Check for status changes
            if currentStatus.isLive != newStatus.isLive {
                handleStreamStatusChange(from: currentStatus, to: newStatus)
            }
            
        } catch {
            // Handle errors
            let errorStatus = handleStreamError(currentStatus: currentStatus, error: error)
            monitoredStreams[streamId] = errorStatus
            
            // Log error
            let monitorError = StreamMonitorError(
                streamId: streamId,
                error: error,
                timestamp: Date(),
                retryCount: errorStatus.consecutiveErrors
            )
            
            monitoringErrors.append(monitorError)
            
            // Keep only recent errors
            if monitoringErrors.count > 100 {
                monitoringErrors.removeFirst(monitoringErrors.count - 100)
            }
        }
    }
    
    private func fetchStreamStatus(for currentStatus: StreamMonitorStatus) async throws -> StreamMonitorStatus {
        switch currentStatus.platform.lowercased() {
        case "twitch":
            return try await fetchTwitchStreamStatus(for: currentStatus)
        case "youtube":
            return try await fetchYouTubeStreamStatus(for: currentStatus)
        default:
            throw StreamMonitoringError.unsupportedPlatform
        }
    }
    
    private func fetchTwitchStreamStatus(for currentStatus: StreamMonitorStatus) async throws -> StreamMonitorStatus {
        // Extract username from URL
        let username = extractTwitchUsername(from: currentStatus.url)
        
        // Get live streams for this user
        let (streams, _) = try await twitchService.getLiveStreams(userLogin: username, first: 1)
        
        let isLive = !streams.isEmpty
        let stream = streams.first
        
        return StreamMonitorStatus(
            streamId: currentStatus.streamId,
            platform: currentStatus.platform,
            url: currentStatus.url,
            isLive: isLive,
            viewerCount: stream?.viewerCount ?? 0,
            lastChecked: Date(),
            healthStatus: isLive ? .healthy : .offline,
            consecutiveErrors: 0,
            title: stream?.title,
            gameName: stream?.gameName,
            thumbnailURL: stream?.thumbnailURL,
            startedAt: stream?.startedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
    
    private func fetchYouTubeStreamStatus(for currentStatus: StreamMonitorStatus) async throws -> StreamMonitorStatus {
        // Extract video ID from URL
        let videoId = extractYouTubeVideoId(from: currentStatus.url)
        
        // Get video details
        let video = try await youtubeService.getVideo(id: videoId, parts: ["snippet", "liveStreamingDetails"])
        
        guard let video = video else {
            throw StreamMonitoringError.streamNotFound
        }
        
        let isLive = video.isLive
        let viewerCount = video.liveStreamingDetails?.concurrentViewers.flatMap { Int($0) } ?? 0
        
        return StreamMonitorStatus(
            streamId: currentStatus.streamId,
            platform: currentStatus.platform,
            url: currentStatus.url,
            isLive: isLive,
            viewerCount: viewerCount,
            lastChecked: Date(),
            healthStatus: isLive ? .healthy : .offline,
            consecutiveErrors: 0,
            title: video.snippet.title,
            gameName: nil,
            thumbnailURL: video.bestThumbnailUrl,
            startedAt: video.liveStreamingDetails?.actualStartTime.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
    
    private func handleStreamError(currentStatus: StreamMonitorStatus, error: Error) -> StreamMonitorStatus {
        let consecutiveErrors = currentStatus.consecutiveErrors + 1
        
        // Determine health status based on error count
        let healthStatus: StreamHealthStatus
        if consecutiveErrors >= 5 {
            healthStatus = .error
        } else if consecutiveErrors >= 3 {
            healthStatus = .warning
        } else {
            healthStatus = .unknown
        }
        
        return StreamMonitorStatus(
            streamId: currentStatus.streamId,
            platform: currentStatus.platform,
            url: currentStatus.url,
            isLive: currentStatus.isLive, // Keep previous status
            viewerCount: currentStatus.viewerCount,
            lastChecked: Date(),
            healthStatus: healthStatus,
            consecutiveErrors: consecutiveErrors,
            title: currentStatus.title,
            gameName: currentStatus.gameName,
            thumbnailURL: currentStatus.thumbnailURL,
            startedAt: currentStatus.startedAt
        )
    }
    
    private func handleStreamStatusChange(from oldStatus: StreamMonitorStatus, to newStatus: StreamMonitorStatus) {
        // Post notifications for stream status changes
        if oldStatus.isLive && !newStatus.isLive {
            // Stream went offline
            NotificationCenter.default.post(
                name: .streamWentOffline,
                object: nil,
                userInfo: ["streamId": newStatus.streamId, "status": newStatus]
            )
        } else if !oldStatus.isLive && newStatus.isLive {
            // Stream went live
            NotificationCenter.default.post(
                name: .streamWentLive,
                object: nil,
                userInfo: ["streamId": newStatus.streamId, "status": newStatus]
            )
        }
    }
    
    private func cacheStreamStatus(_ status: StreamMonitorStatus) {
        cacheManager.store(status, forKey: "stream_status_\(status.streamId)", expiration: 60)
    }
    
    private func extractTwitchUsername(from url: String) -> String {
        let components = url.components(separatedBy: "/")
        return components.last?.components(separatedBy: "?").first ?? ""
    }
    
    private func extractYouTubeVideoId(from url: String) -> String {
        if let urlComponents = URLComponents(string: url) {
            if let queryItems = urlComponents.queryItems,
               let videoId = queryItems.first(where: { $0.name == "v" })?.value {
                return videoId
            }
            if url.contains("youtu.be") {
                return urlComponents.path.replacingOccurrences(of: "/", with: "")
            }
        }
        return ""
    }
    
    // MARK: - Statistics
    
    var totalMonitoredStreams: Int {
        monitoredStreams.count
    }
    
    var liveStreamsCount: Int {
        monitoredStreams.values.filter { $0.isLive }.count
    }
    
    var offlineStreamsCount: Int {
        monitoredStreams.values.filter { !$0.isLive }.count
    }
    
    var errorStreamsCount: Int {
        monitoredStreams.values.filter { $0.healthStatus == .error }.count
    }
    
    var averageViewerCount: Int {
        let totalViewers = monitoredStreams.values.reduce(0) { $0 + $1.viewerCount }
        return totalViewers / max(1, totalMonitoredStreams)
    }
    
    var uptime: Double {
        let totalStreams = Double(totalMonitoredStreams)
        let healthyStreams = Double(monitoredStreams.values.filter { $0.healthStatus == .healthy }.count)
        return totalStreams > 0 ? healthyStreams / totalStreams : 0
    }
}

// MARK: - Supporting Models

struct StreamMonitorStatus: Codable, Identifiable {
    let id = UUID()
    let streamId: String
    let platform: String
    let url: String
    let isLive: Bool
    let viewerCount: Int
    let lastChecked: Date
    let healthStatus: StreamHealthStatus
    let consecutiveErrors: Int
    let title: String?
    let gameName: String?
    let thumbnailURL: String?
    let startedAt: Date?
    
    init(streamId: String, platform: String, url: String, isLive: Bool, viewerCount: Int, lastChecked: Date, healthStatus: StreamHealthStatus, consecutiveErrors: Int, title: String? = nil, gameName: String? = nil, thumbnailURL: String? = nil, startedAt: Date? = nil) {
        self.streamId = streamId
        self.platform = platform
        self.url = url
        self.isLive = isLive
        self.viewerCount = viewerCount
        self.lastChecked = lastChecked
        self.healthStatus = healthStatus
        self.consecutiveErrors = consecutiveErrors
        self.title = title
        self.gameName = gameName
        self.thumbnailURL = thumbnailURL
        self.startedAt = startedAt
    }
}

struct StreamMonitorError: Identifiable {
    let id = UUID()
    let streamId: String
    let error: Error
    let timestamp: Date
    let retryCount: Int
    
    var errorDescription: String {
        return error.localizedDescription
    }
}

enum StreamMonitoringError: Error, LocalizedError {
    case unsupportedPlatform
    case streamNotFound
    case rateLimited
    case networkError
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Unsupported platform"
        case .streamNotFound:
            return "Stream not found"
        case .rateLimited:
            return "Rate limited"
        case .networkError:
            return "Network error"
        case .authenticationRequired:
            return "Authentication required"
        }
    }
}

enum StreamHealthStatus: String, Codable {
    case healthy = "healthy"
    case warning = "warning"
    case error = "error"
    case offline = "offline"
    case unknown = "unknown"
    
    var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .orange
        case .error: return .red
        case .offline: return .gray
        case .unknown: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .offline: return "moon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let streamWentLive = Notification.Name("streamWentLive")
    static let streamWentOffline = Notification.Name("streamWentOffline")
    static let streamStatusUpdated = Notification.Name("streamStatusUpdated")
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

import SwiftUI

extension Color {
    static let streamOnline = Color.green
    static let streamOffline = Color.gray
    static let streamError = Color.red
    static let streamWarning = Color.orange
}