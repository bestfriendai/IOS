//
//  Stream.swift
//  StreamyyyApp
//
//  Enhanced stream model with validation and relationships
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Stream Model
@Model
public class Stream: Identifiable, Codable, ObservableObject {
    @Attribute(.unique) public var id: String
    public var url: String
    public var originalURL: String
    public var embedURL: String?
    public var platform: Platform
    public var title: String
    public var description: String?
    public var thumbnailURL: String?
    public var streamerName: String?
    public var streamerAvatarURL: String?
    public var category: String?
    public var language: String?
    public var tags: [String]
    public var isLive: Bool
    public var viewerCount: Int
    public var startedAt: Date?
    public var endedAt: Date?
    public var duration: TimeInterval
    public var quality: StreamQuality
    public var availableQualities: [StreamQuality]
    public var isMuted: Bool
    public var volume: Double
    public var isFullscreen: Bool
    public var isPictureInPicture: Bool
    public var isAutoPlay: Bool
    public var isVisible: Bool
    public var position: StreamPosition
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    public var lastViewedAt: Date?
    public var viewCount: Int
    public var isArchived: Bool
    public var archiveReason: String?
    public var healthStatus: StreamHealthStatus
    public var connectionAttempts: Int
    public var lastConnectionAttempt: Date?
    
    // MARK: - Sync Properties
    public var syncStatus: String
    public var lastSyncAt: Date?
    public var syncVersion: Int
    public var needsSync: Bool
    public var syncConflict: Bool
    
    // MARK: - Relationships
    @Relationship(inverse: \User.streams)
    public var owner: User?
    
    @Relationship(deleteRule: .cascade, inverse: \Favorite.stream)
    public var favoritedBy: [Favorite] = []
    
    @Relationship(deleteRule: .cascade, inverse: \StreamAnalytics.stream)
    public var analytics: [StreamAnalytics] = []
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        url: String,
        platform: Platform? = nil,
        title: String? = nil,
        owner: User? = nil
    ) {
        self.id = id
        self.url = url
        self.originalURL = url
        self.platform = platform ?? Platform.detect(from: url)
        self.title = title ?? self.extractTitle(from: url)
        self.description = nil
        self.thumbnailURL = nil
        self.streamerName = nil
        self.streamerAvatarURL = nil
        self.category = nil
        self.language = nil
        self.tags = []
        self.isLive = false
        self.viewerCount = 0
        self.startedAt = nil
        self.endedAt = nil
        self.duration = 0
        self.quality = self.platform.defaultQuality
        self.availableQualities = self.platform.availableQualities
        self.isMuted = false
        self.volume = 1.0
        self.isFullscreen = false
        self.isPictureInPicture = false
        self.isAutoPlay = true
        self.isVisible = true
        self.position = StreamPosition()
        self.metadata = [:]
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastViewedAt = nil
        self.viewCount = 0
        self.isArchived = false
        self.archiveReason = nil
        self.healthStatus = .unknown
        self.connectionAttempts = 0
        self.lastConnectionAttempt = nil
        self.owner = owner
        
        // Generate embed URL
        self.embedURL = generateEmbedURL()
    }

    // MARK: - Helpers
    public func getChannelName() -> String? {
        guard platform == .twitch else { return nil }
        let components = URLComponents(string: url)
        let path = components?.path ?? ""
        let channel = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return channel.isEmpty ? nil : channel
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, url, originalURL, embedURL, platform, title, description
        case thumbnailURL, streamerName, streamerAvatarURL, category, language, tags
        case isLive, viewerCount, startedAt, endedAt, duration, quality, availableQualities
        case isMuted, volume, isFullscreen, isPictureInPicture, isAutoPlay, isVisible
        case position, metadata, createdAt, updatedAt, lastViewedAt, viewCount
        case isArchived, archiveReason, healthStatus, connectionAttempts, lastConnectionAttempt
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        originalURL = try container.decode(String.self, forKey: .originalURL)
        embedURL = try container.decodeIfPresent(String.self, forKey: .embedURL)
        platform = try container.decode(Platform.self, forKey: .platform)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        streamerName = try container.decodeIfPresent(String.self, forKey: .streamerName)
        streamerAvatarURL = try container.decodeIfPresent(String.self, forKey: .streamerAvatarURL)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        tags = try container.decode([String].self, forKey: .tags)
        isLive = try container.decode(Bool.self, forKey: .isLive)
        viewerCount = try container.decode(Int.self, forKey: .viewerCount)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        quality = try container.decode(StreamQuality.self, forKey: .quality)
        availableQualities = try container.decode([StreamQuality].self, forKey: .availableQualities)
        isMuted = try container.decode(Bool.self, forKey: .isMuted)
        volume = try container.decode(Double.self, forKey: .volume)
        isFullscreen = try container.decode(Bool.self, forKey: .isFullscreen)
        isPictureInPicture = try container.decode(Bool.self, forKey: .isPictureInPicture)
        isAutoPlay = try container.decode(Bool.self, forKey: .isAutoPlay)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        position = try container.decode(StreamPosition.self, forKey: .position)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastViewedAt = try container.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        archiveReason = try container.decodeIfPresent(String.self, forKey: .archiveReason)
        healthStatus = try container.decode(StreamHealthStatus.self, forKey: .healthStatus)
        connectionAttempts = try container.decode(Int.self, forKey: .connectionAttempts)
        lastConnectionAttempt = try container.decodeIfPresent(Date.self, forKey: .lastConnectionAttempt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(originalURL, forKey: .originalURL)
        try container.encodeIfPresent(embedURL, forKey: .embedURL)
        try container.encode(platform, forKey: .platform)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encodeIfPresent(streamerName, forKey: .streamerName)
        try container.encodeIfPresent(streamerAvatarURL, forKey: .streamerAvatarURL)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encode(tags, forKey: .tags)
        try container.encode(isLive, forKey: .isLive)
        try container.encode(viewerCount, forKey: .viewerCount)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(duration, forKey: .duration)
        try container.encode(quality, forKey: .quality)
        try container.encode(availableQualities, forKey: .availableQualities)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(volume, forKey: .volume)
        try container.encode(isFullscreen, forKey: .isFullscreen)
        try container.encode(isPictureInPicture, forKey: .isPictureInPicture)
        try container.encode(isAutoPlay, forKey: .isAutoPlay)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(position, forKey: .position)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastViewedAt, forKey: .lastViewedAt)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encodeIfPresent(archiveReason, forKey: .archiveReason)
        try container.encode(healthStatus, forKey: .healthStatus)
        try container.encode(connectionAttempts, forKey: .connectionAttempts)
        try container.encodeIfPresent(lastConnectionAttempt, forKey: .lastConnectionAttempt)
    }
}

// MARK: - Stream Extensions
extension Stream {
    
    // MARK: - Computed Properties
    public var displayTitle: String {
        if title.isEmpty {
            return streamerName ?? "Untitled Stream"
        }
        return title
    }
    
    public var formattedViewerCount: String {
        if viewerCount >= 1000000 {
            return String(format: "%.1fM", Double(viewerCount) / 1000000.0)
        } else if viewerCount >= 1000 {
            return String(format: "%.1fK", Double(viewerCount) / 1000.0)
        } else {
            return "\(viewerCount)"
        }
    }
    
    public var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
    
    public var streamAge: String {
        guard let startedAt = startedAt else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: startedAt, relativeTo: Date())
    }
    
    public var isHealthy: Bool {
        return healthStatus == .healthy || healthStatus == .good
    }
    
    public var statusColor: Color {
        switch healthStatus {
        case .healthy: return .green
        case .good: return .blue
        case .warning: return .orange
        case .error: return .red
        case .unknown: return .gray
        }
    }
    
    public var platformColor: Color {
        return platform.color
    }
    
    public var isFavorited: Bool {
        return !favoritedBy.isEmpty
    }
    
    public var canPlayPictureInPicture: Bool {
        return platform.supportsEmbedding && Config.App.enablePictureInPicture
    }
    
    // MARK: - URL Generation
    private func generateEmbedURL() -> String? {
        guard platform.supportsEmbedding,
              let identifier = platform.extractStreamIdentifier(from: url) else {
            return nil
        }
        
        // Use the new Platform's generateEmbedURL method with default options
        let embedOptions = EmbedOptions(
            autoplay: isAutoPlay,
            muted: isMuted,
            showControls: true,
            chatEnabled: false,
            quality: quality,
            parentDomain: "streamyyy.com"
        )
        
        return platform.generateEmbedURL(for: identifier, options: embedOptions)
    }
    
    private func extractTitle(from url: String) -> String {
        if let identifier = platform.extractStreamIdentifier(from: url) {
            return "\(platform.displayName) - \(identifier)"
        }
        return "\(platform.displayName) Stream"
    }
    
    // MARK: - Validation
    public func validateURL() -> Bool {
        return platform.isValidURL(url)
    }
    
    public func validateEmbedURL() -> Bool {
        guard let embedURL = embedURL else { return false }
        return URL(string: embedURL) != nil
    }
    
    // MARK: - Update Methods
    public func updateMetadata(_ newMetadata: [String: String]) {
        metadata = newMetadata
        updatedAt = Date()
    }
    
    public func updateLiveStatus(_ live: Bool) {
        isLive = live
        if live {
            startedAt = startedAt ?? Date()
            endedAt = nil
        } else {
            endedAt = Date()
            if let startedAt = startedAt {
                duration = Date().timeIntervalSince(startedAt)
            }
        }
        updatedAt = Date()
    }
    
    public func updateViewerCount(_ count: Int) {
        viewerCount = max(0, count)
        updatedAt = Date()
    }
    
    public func updateQuality(_ newQuality: StreamQuality) {
        guard availableQualities.contains(newQuality) else { return }
        quality = newQuality
        updatedAt = Date()
    }
    
    public func updatePosition(_ newPosition: StreamPosition) {
        position = newPosition
        updatedAt = Date()
    }
    
    public func recordView() {
        viewCount += 1
        lastViewedAt = Date()
        updatedAt = Date()
    }
    
    public func updateHealthStatus(_ status: StreamHealthStatus) {
        healthStatus = status
        updatedAt = Date()
    }
    
    public func recordConnectionAttempt() {
        connectionAttempts += 1
        lastConnectionAttempt = Date()
        updatedAt = Date()
    }
    
    // MARK: - Archive Methods
    public func archive(reason: String? = nil) {
        isArchived = true
        archiveReason = reason
        updatedAt = Date()
    }
    
    public func unarchive() {
        isArchived = false
        archiveReason = nil
        updatedAt = Date()
    }
    
    // MARK: - Control Methods
    public func toggleMute() {
        isMuted.toggle()
        updatedAt = Date()
    }
    
    public func setVolume(_ newVolume: Double) {
        volume = max(0.0, min(1.0, newVolume))
        updatedAt = Date()
    }
    
    public func toggleFullscreen() {
        isFullscreen.toggle()
        updatedAt = Date()
    }
    
    public func togglePictureInPicture() {
        guard canPlayPictureInPicture else { return }
        isPictureInPicture.toggle()
        updatedAt = Date()
    }
    
    public func toggleVisibility() {
        isVisible.toggle()
        updatedAt = Date()
    }
    
    // MARK: - Metadata Methods
    public func setMetadata(key: String, value: String) {
        metadata[key] = value
        updatedAt = Date()
    }
    
    public func getMetadata(key: String) -> String? {
        return metadata[key]
    }
    
    public func removeMetadata(key: String) {
        metadata.removeValue(forKey: key)
        updatedAt = Date()
    }
    
    // MARK: - Tag Methods
    public func addTag(_ tag: String) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
        updatedAt = Date()
    }
    
    public func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updatedAt = Date()
    }
    
    public func hasTag(_ tag: String) -> Bool {
        return tags.contains(tag)
    }
}

// MARK: - Stream Position
public struct StreamPosition: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var zIndex: Int
    
    public init(x: Double = 0, y: Double = 0, width: Double = 300, height: Double = 200, zIndex: Int = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.zIndex = zIndex
    }
    
    public var rect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    public var center: CGPoint {
        return CGPoint(x: x + width / 2, y: y + height / 2)
    }
    
    public var aspectRatio: Double {
        return width / height
    }
}

// MARK: - Stream Health Status
public enum StreamHealthStatus: String, Codable, CaseIterable {
    case healthy = "healthy"
    case good = "good"
    case warning = "warning"
    case error = "error"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .good: return "Good"
        case .warning: return "Warning"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
    
    public var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    public var color: Color {
        switch self {
        case .healthy: return .green
        case .good: return .blue
        case .warning: return .orange
        case .error: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Stream Analytics Model
@Model
public class StreamAnalytics: Identifiable, Codable {
    @Attribute(.unique) public var id: String
    public var timestamp: Date
    public var event: AnalyticsEvent
    public var value: Double
    public var metadata: [String: String]
    
    @Relationship(inverse: \Stream.analytics)
    public var stream: Stream?
    
    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        event: AnalyticsEvent,
        value: Double,
        metadata: [String: String] = [:],
        stream: Stream? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.value = value
        self.metadata = metadata
        self.stream = stream
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, timestamp, event, value, metadata
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        event = try container.decode(AnalyticsEvent.self, forKey: .event)
        value = try container.decode(Double.self, forKey: .value)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(event, forKey: .event)
        try container.encode(value, forKey: .value)
        try container.encode(metadata, forKey: .metadata)
    }
}

// MARK: - Analytics Event
public enum AnalyticsEvent: String, Codable, CaseIterable {
    case streamStart = "stream_start"
    case streamEnd = "stream_end"
    case viewerJoin = "viewer_join"
    case viewerLeave = "viewer_leave"
    case qualityChange = "quality_change"
    case volumeChange = "volume_change"
    case fullscreenToggle = "fullscreen_toggle"
    case pipToggle = "pip_toggle"
    case muteToggle = "mute_toggle"
    case connectionError = "connection_error"
    case bufferingEvent = "buffering_event"
    case chatMessage = "chat_message"
    
    public var displayName: String {
        switch self {
        case .streamStart: return "Stream Start"
        case .streamEnd: return "Stream End"
        case .viewerJoin: return "Viewer Join"
        case .viewerLeave: return "Viewer Leave"
        case .qualityChange: return "Quality Change"
        case .volumeChange: return "Volume Change"
        case .fullscreenToggle: return "Fullscreen Toggle"
        case .pipToggle: return "PiP Toggle"
        case .muteToggle: return "Mute Toggle"
        case .connectionError: return "Connection Error"
        case .bufferingEvent: return "Buffering Event"
        case .chatMessage: return "Chat Message"
        }
    }
}

// MARK: - Stream Errors
public enum StreamError: Error, LocalizedError {
    case invalidURL
    case unsupportedPlatform
    case embedNotSupported
    case connectionFailed
    case streamOffline
    case qualityNotAvailable
    case permissionDenied
    case rateLimitExceeded
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid stream URL"
        case .unsupportedPlatform:
            return "Unsupported platform"
        case .embedNotSupported:
            return "Embedding not supported"
        case .connectionFailed:
            return "Connection failed"
        case .streamOffline:
            return "Stream is offline"
        case .qualityNotAvailable:
            return "Quality not available"
        case .permissionDenied:
            return "Permission denied"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}