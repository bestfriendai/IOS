//
//  SyncModels.swift
//  StreamyyyApp
//
//  Sync models for Supabase integration - compatible with React web app schema
//  These models bridge between local SwiftData models and Supabase database
//  Created by Claude Code on 2025-07-11
//

import Foundation
import SwiftData

// MARK: - Sync Protocol
protocol SyncModel: Codable {
    var id: String { get }
    var userId: String { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var version: Int { get set }
    var isDeleted: Bool { get set }
    var lastSyncedAt: Date? { get set }
    
    func toDictionary() throws -> [String: Any]
}

// MARK: - SyncLayout Model
public struct SyncLayout: SyncModel {
    public let id: String
    public let userId: String
    public let name: String
    public let description: String?
    public let type: String // "grid", "custom", "mosaic"
    public let configuration: LayoutConfiguration
    public let isPublic: Bool
    public let isDefault: Bool
    public let tags: [String]
    public let category: String?
    public let thumbnailUrl: String?
    public let streamCount: Int
    public let downloads: Int
    public let rating: Double
    public let ratingCount: Int
    public let createdAt: Date
    public let updatedAt: Date
    public var version: Int
    public var isDeleted: Bool
    public var lastSyncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, type, configuration
        case isPublic = "is_public"
        case isDefault = "is_default"
        case tags, category
        case thumbnailUrl = "thumbnail_url"
        case streamCount = "stream_count"
        case downloads, rating
        case ratingCount = "rating_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case version
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
    }
    
    public init(from layout: Layout, userId: String) {
        self.id = layout.id
        self.userId = userId
        self.name = layout.name
        self.description = layout.layoutDescription
        self.type = layout.type.rawValue
        self.configuration = LayoutConfiguration(from: layout.configuration)
        self.isPublic = layout.isPublic
        self.isDefault = layout.isDefault
        self.tags = layout.tags
        self.category = layout.category
        self.thumbnailUrl = layout.thumbnailURL
        self.streamCount = layout.streamCount
        self.downloads = layout.downloads
        self.rating = layout.rating
        self.ratingCount = layout.ratingCount
        self.createdAt = layout.createdAt
        self.updatedAt = layout.updatedAt
        self.version = layout.version
        self.isDeleted = false
        self.lastSyncedAt = nil
    }
    
    public func toLayout() -> Layout {
        let layout = Layout(
            name: name,
            type: LayoutType(rawValue: type) ?? .grid,
            configuration: configuration.toLayoutConfig()
        )
        layout.id = id
        layout.layoutDescription = description
        layout.isPublic = isPublic
        layout.isDefault = isDefault
        layout.tags = tags
        layout.category = category
        layout.thumbnailURL = thumbnailUrl
        layout.streamCount = streamCount
        layout.downloads = downloads
        layout.rating = rating
        layout.ratingCount = ratingCount
        layout.createdAt = createdAt
        layout.updatedAt = updatedAt
        layout.version = version
        return layout
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - LayoutConfiguration
public struct LayoutConfiguration: Codable {
    public let columns: Int
    public let rows: Int
    public let aspectRatio: Double
    public let spacing: Double
    public let padding: EdgeInsets
    public let streamPositions: [StreamPosition]
    public let responsiveBreakpoints: [ResponsiveBreakpoint]
    public let animations: AnimationSettings
    
    enum CodingKeys: String, CodingKey {
        case columns, rows
        case aspectRatio = "aspect_ratio"
        case spacing, padding
        case streamPositions = "stream_positions"
        case responsiveBreakpoints = "responsive_breakpoints"
        case animations
    }
    
    public init(from config: LayoutConfig) {
        self.columns = config.columns
        self.rows = config.rows
        self.aspectRatio = config.aspectRatio
        self.spacing = config.spacing
        self.padding = EdgeInsets(
            top: config.padding.top,
            leading: config.padding.leading,
            bottom: config.padding.bottom,
            trailing: config.padding.trailing
        )
        self.streamPositions = config.streamPositions.map { StreamPosition(from: $0) }
        self.responsiveBreakpoints = config.responsiveBreakpoints.map { ResponsiveBreakpoint(from: $0) }
        self.animations = AnimationSettings(from: config.animations)
    }
    
    public func toLayoutConfig() -> LayoutConfig {
        let config = LayoutConfig(columns: columns, rows: rows)
        config.aspectRatio = aspectRatio
        config.spacing = spacing
        config.padding = LayoutPadding(
            top: padding.top,
            leading: padding.leading,
            bottom: padding.bottom,
            trailing: padding.trailing
        )
        config.streamPositions = streamPositions.map { $0.toStreamPosition() }
        config.responsiveBreakpoints = responsiveBreakpoints.map { $0.toResponsiveBreakpoint() }
        config.animations = animations.toAnimationSettings()
        return config
    }
}

// MARK: - Supporting Layout Structures
public struct EdgeInsets: Codable {
    public let top: Double
    public let leading: Double
    public let bottom: Double
    public let trailing: Double
}

public struct StreamPosition: Codable {
    public let id: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let zIndex: Int
    public let isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, x, y, width, height
        case zIndex = "z_index"
        case isLocked = "is_locked"
    }
    
    public init(from position: StreamPosition) {
        self.id = position.id
        self.x = position.x
        self.y = position.y
        self.width = position.width
        self.height = position.height
        self.zIndex = position.zIndex
        self.isLocked = position.isLocked
    }
    
    public func toStreamPosition() -> StreamPosition {
        return StreamPosition(
            id: id,
            x: x,
            y: y,
            width: width,
            height: height,
            zIndex: zIndex,
            isLocked: isLocked
        )
    }
}

public struct ResponsiveBreakpoint: Codable {
    public let minWidth: Double
    public let maxWidth: Double
    public let columns: Int
    public let rows: Int
    
    enum CodingKeys: String, CodingKey {
        case minWidth = "min_width"
        case maxWidth = "max_width"
        case columns, rows
    }
    
    public init(from breakpoint: ResponsiveBreakpoint) {
        self.minWidth = breakpoint.minWidth
        self.maxWidth = breakpoint.maxWidth
        self.columns = breakpoint.columns
        self.rows = breakpoint.rows
    }
    
    public func toResponsiveBreakpoint() -> ResponsiveBreakpoint {
        return ResponsiveBreakpoint(
            minWidth: minWidth,
            maxWidth: maxWidth,
            columns: columns,
            rows: rows
        )
    }
}

public struct AnimationSettings: Codable {
    public let enableTransitions: Bool
    public let transitionDuration: Double
    public let easing: String
    public let enableHover: Bool
    public let enableFocus: Bool
    
    enum CodingKeys: String, CodingKey {
        case enableTransitions = "enable_transitions"
        case transitionDuration = "transition_duration"
        case easing
        case enableHover = "enable_hover"
        case enableFocus = "enable_focus"
    }
    
    public init(from settings: AnimationSettings) {
        self.enableTransitions = settings.enableTransitions
        self.transitionDuration = settings.transitionDuration
        self.easing = settings.easing
        self.enableHover = settings.enableHover
        self.enableFocus = settings.enableFocus
    }
    
    public func toAnimationSettings() -> AnimationSettings {
        return AnimationSettings(
            enableTransitions: enableTransitions,
            transitionDuration: transitionDuration,
            easing: easing,
            enableHover: enableHover,
            enableFocus: enableFocus
        )
    }
}

// MARK: - SyncStream Model
public struct SyncStream: SyncModel {
    public let id: String
    public let userId: String
    public let url: String
    public let title: String
    public let platform: String
    public let channelName: String?
    public let category: String?
    public let language: String?
    public let thumbnailUrl: String?
    public let isLive: Bool
    public let viewerCount: Int?
    public let quality: String
    public let tags: [String]
    public let description: String?
    public let startTime: Date?
    public let endTime: Date?
    public let duration: TimeInterval?
    public let isFavorite: Bool
    public let isArchived: Bool
    public let isPrivate: Bool
    public let customName: String?
    public let notes: String?
    public let rating: Int?
    public let lastWatchedAt: Date?
    public let watchDuration: TimeInterval
    public let createdAt: Date
    public let updatedAt: Date
    public var version: Int
    public var isDeleted: Bool
    public var lastSyncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, url, title, platform
        case channelName = "channel_name"
        case category, language
        case thumbnailUrl = "thumbnail_url"
        case isLive = "is_live"
        case viewerCount = "viewer_count"
        case quality, tags, description
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case isFavorite = "is_favorite"
        case isArchived = "is_archived"
        case isPrivate = "is_private"
        case customName = "custom_name"
        case notes, rating
        case lastWatchedAt = "last_watched_at"
        case watchDuration = "watch_duration"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case version
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
    }
    
    public init(from stream: Stream, userId: String) {
        self.id = stream.id
        self.userId = userId
        self.url = stream.url
        self.title = stream.title
        self.platform = stream.platform.rawValue
        self.channelName = stream.channelName
        self.category = stream.category
        self.language = stream.language
        self.thumbnailUrl = stream.thumbnailURL
        self.isLive = stream.isLive
        self.viewerCount = stream.viewerCount
        self.quality = stream.quality.rawValue
        self.tags = stream.tags
        self.description = stream.streamDescription
        self.startTime = stream.startTime
        self.endTime = stream.endTime
        self.duration = stream.duration
        self.isFavorite = stream.isFavorite
        self.isArchived = stream.isArchived
        self.isPrivate = stream.isPrivate
        self.customName = stream.customName
        self.notes = stream.notes
        self.rating = stream.rating
        self.lastWatchedAt = stream.lastWatchedAt
        self.watchDuration = stream.watchDuration
        self.createdAt = stream.createdAt
        self.updatedAt = stream.updatedAt
        self.version = stream.version
        self.isDeleted = false
        self.lastSyncedAt = nil
    }
    
    public func toStream() -> Stream {
        let stream = Stream(
            url: url,
            platform: Platform(rawValue: platform) ?? .other
        )
        stream.id = id
        stream.title = title
        stream.channelName = channelName
        stream.category = category
        stream.language = language
        stream.thumbnailURL = thumbnailUrl
        stream.isLive = isLive
        stream.viewerCount = viewerCount
        stream.quality = StreamQuality(rawValue: quality) ?? .medium
        stream.tags = tags
        stream.streamDescription = description
        stream.startTime = startTime
        stream.endTime = endTime
        stream.duration = duration
        stream.isFavorite = isFavorite
        stream.isArchived = isArchived
        stream.isPrivate = isPrivate
        stream.customName = customName
        stream.notes = notes
        stream.rating = rating
        stream.lastWatchedAt = lastWatchedAt
        stream.watchDuration = watchDuration
        stream.createdAt = createdAt
        stream.updatedAt = updatedAt
        stream.version = version
        return stream
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - SyncFavorite Model
public struct SyncFavorite: SyncModel {
    public let id: String
    public let userId: String
    public let streamId: String
    public let streamUrl: String
    public let streamTitle: String
    public let platform: String
    public let channelName: String?
    public let thumbnailUrl: String?
    public let tags: [String]
    public let notes: String?
    public let addedAt: Date
    public let notificationsEnabled: Bool
    public let priority: Int
    public let category: String?
    public let isArchived: Bool
    public let lastNotificationAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public var version: Int
    public var isDeleted: Bool
    public var lastSyncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case streamId = "stream_id"
        case streamUrl = "stream_url"
        case streamTitle = "stream_title"
        case platform
        case channelName = "channel_name"
        case thumbnailUrl = "thumbnail_url"
        case tags, notes
        case addedAt = "added_at"
        case notificationsEnabled = "notifications_enabled"
        case priority, category
        case isArchived = "is_archived"
        case lastNotificationAt = "last_notification_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case version
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
    }
    
    public init(from favorite: Favorite, userId: String) {
        self.id = favorite.id
        self.userId = userId
        self.streamId = favorite.streamId
        self.streamUrl = favorite.streamUrl
        self.streamTitle = favorite.streamTitle
        self.platform = favorite.platform.rawValue
        self.channelName = favorite.channelName
        self.thumbnailUrl = favorite.thumbnailURL
        self.tags = favorite.tags
        self.notes = favorite.notes
        self.addedAt = favorite.addedAt
        self.notificationsEnabled = favorite.notificationsEnabled
        self.priority = favorite.priority
        self.category = favorite.category
        self.isArchived = favorite.isArchived
        self.lastNotificationAt = favorite.lastNotificationAt
        self.createdAt = favorite.createdAt
        self.updatedAt = favorite.updatedAt
        self.version = favorite.version
        self.isDeleted = false
        self.lastSyncedAt = nil
    }
    
    public func toFavorite() -> Favorite {
        let favorite = Favorite(
            streamId: streamId,
            streamUrl: streamUrl,
            streamTitle: streamTitle,
            platform: Platform(rawValue: platform) ?? .other
        )
        favorite.id = id
        favorite.channelName = channelName
        favorite.thumbnailURL = thumbnailUrl
        favorite.tags = tags
        favorite.notes = notes
        favorite.addedAt = addedAt
        favorite.notificationsEnabled = notificationsEnabled
        favorite.priority = priority
        favorite.category = category
        favorite.isArchived = isArchived
        favorite.lastNotificationAt = lastNotificationAt
        favorite.createdAt = createdAt
        favorite.updatedAt = updatedAt
        favorite.version = version
        return favorite
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - SyncViewingHistory Model
public struct SyncViewingHistory: SyncModel {
    public let id: String
    public let userId: String
    public let streamId: String
    public let streamTitle: String
    public let streamUrl: String
    public let platform: String
    public let streamerName: String?
    public let thumbnailUrl: String?
    public let category: String?
    public let viewedAt: Date
    public let viewDuration: TimeInterval
    public let totalStreamDuration: TimeInterval?
    public let watchPercentage: Double
    public let watchQuality: String
    public let sessionId: String
    public let wasLive: Bool
    public let viewerCountAtView: Int?
    public let exitReason: String?
    public let isCompleted: Bool
    public let rating: Int?
    public let notes: String?
    public let deviceType: String
    public let createdAt: Date
    public let updatedAt: Date
    public var version: Int
    public var isDeleted: Bool
    public var lastSyncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case streamId = "stream_id"
        case streamTitle = "stream_title"
        case streamUrl = "stream_url"
        case platform
        case streamerName = "streamer_name"
        case thumbnailUrl = "thumbnail_url"
        case category
        case viewedAt = "viewed_at"
        case viewDuration = "view_duration"
        case totalStreamDuration = "total_stream_duration"
        case watchPercentage = "watch_percentage"
        case watchQuality = "watch_quality"
        case sessionId = "session_id"
        case wasLive = "was_live"
        case viewerCountAtView = "viewer_count_at_view"
        case exitReason = "exit_reason"
        case isCompleted = "is_completed"
        case rating, notes
        case deviceType = "device_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case version
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
    }
    
    public init(from history: ViewingHistory, userId: String) {
        self.id = history.id
        self.userId = userId
        self.streamId = history.streamId
        self.streamTitle = history.streamTitle
        self.streamUrl = history.streamURL
        self.platform = history.platform.rawValue
        self.streamerName = history.streamerName
        self.thumbnailUrl = history.thumbnailURL
        self.category = history.category
        self.viewedAt = history.viewedAt
        self.viewDuration = history.viewDuration
        self.totalStreamDuration = history.totalStreamDuration
        self.watchPercentage = history.watchPercentage
        self.watchQuality = history.watchQuality.rawValue
        self.sessionId = history.sessionId
        self.wasLive = history.wasLive
        self.viewerCountAtView = history.viewerCountAtView
        self.exitReason = history.exitReason?.rawValue
        self.isCompleted = history.isCompleted
        self.rating = history.rating
        self.notes = history.notes
        self.deviceType = "ios"
        self.createdAt = history.createdAt
        self.updatedAt = history.updatedAt
        self.version = history.version
        self.isDeleted = false
        self.lastSyncedAt = nil
    }
    
    public func toViewingHistory() -> ViewingHistory {
        let history = ViewingHistory(
            streamId: streamId,
            streamTitle: streamTitle,
            streamURL: streamUrl,
            platform: Platform(rawValue: platform) ?? .other,
            streamerName: streamerName,
            thumbnailURL: thumbnailUrl,
            category: category,
            viewedAt: viewedAt,
            viewDuration: viewDuration,
            watchQuality: StreamQuality(rawValue: watchQuality) ?? .medium,
            sessionId: sessionId,
            wasLive: wasLive
        )
        history.id = id
        history.totalStreamDuration = totalStreamDuration
        history.watchPercentage = watchPercentage
        history.viewerCountAtView = viewerCountAtView
        history.exitReason = exitReason.flatMap { ViewingExitReason(rawValue: $0) }
        history.isCompleted = isCompleted
        history.rating = rating
        history.notes = notes
        history.createdAt = createdAt
        history.updatedAt = updatedAt
        history.version = version
        return history
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - SyncStreamSession Model
public struct SyncStreamSession: SyncModel {
    public let id: String
    public let userId: String
    public let sessionName: String
    public let description: String?
    public let streamIds: [String]
    public let layoutId: String?
    public let layoutConfiguration: LayoutConfiguration?
    public let isActive: Bool
    public let startTime: Date
    public let endTime: Date?
    public let duration: TimeInterval?
    public let tags: [String]
    public let isPublic: Bool
    public let shareUrl: String?
    public let thumbnailUrl: String?
    public let viewCount: Int
    public let lastAccessedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public var version: Int
    public var isDeleted: Bool
    public var lastSyncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionName = "session_name"
        case description
        case streamIds = "stream_ids"
        case layoutId = "layout_id"
        case layoutConfiguration = "layout_configuration"
        case isActive = "is_active"
        case startTime = "start_time"
        case endTime = "end_time"
        case duration, tags
        case isPublic = "is_public"
        case shareUrl = "share_url"
        case thumbnailUrl = "thumbnail_url"
        case viewCount = "view_count"
        case lastAccessedAt = "last_accessed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case version
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
    }
    
    public init(from session: StreamSession, userId: String) {
        self.id = session.id
        self.userId = userId
        self.sessionName = session.name
        self.description = session.sessionDescription
        self.streamIds = session.streamIds
        self.layoutId = session.layoutId
        self.layoutConfiguration = session.layoutConfiguration.map { LayoutConfiguration(from: $0) }
        self.isActive = session.isActive
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.duration = session.duration
        self.tags = session.tags
        self.isPublic = session.isPublic
        self.shareUrl = session.shareURL
        self.thumbnailUrl = session.thumbnailURL
        self.viewCount = session.viewCount
        self.lastAccessedAt = session.lastAccessedAt
        self.createdAt = session.createdAt
        self.updatedAt = session.updatedAt
        self.version = session.version
        self.isDeleted = false
        self.lastSyncedAt = nil
    }
    
    public func toStreamSession() -> StreamSession {
        let session = StreamSession(name: sessionName)
        session.id = id
        session.sessionDescription = description
        session.streamIds = streamIds
        session.layoutId = layoutId
        session.layoutConfiguration = layoutConfiguration?.toLayoutConfig()
        session.isActive = isActive
        session.startTime = startTime
        session.endTime = endTime
        session.duration = duration
        session.tags = tags
        session.isPublic = isPublic
        session.shareURL = shareUrl
        session.thumbnailURL = thumbnailUrl
        session.viewCount = viewCount
        session.lastAccessedAt = lastAccessedAt
        session.createdAt = createdAt
        session.updatedAt = updatedAt
        session.version = version
        return session
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - SyncStreamAnalytics Model
public struct SyncStreamAnalytics: SyncModel {
    public let id: String
    public let userId: String
    public let streamId: String
    public let sessionId: String?
    public let eventType: String
    public let eventData: [String: Any]
    public let timestamp: Date
    public let platform: String
    public let deviceType: String
    public let userAgent: String?
    public let ipAddress: String?
    public let geolocation: String?
    public let referrer: String?
    public let createdAt: Date
    public let updatedAt: Date
    public var version: Int
    public var isDeleted: Bool
    public var lastSyncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case streamId = "stream_id"
        case sessionId = "session_id"
        case eventType = "event_type"
        case eventData = "event_data"
        case timestamp, platform
        case deviceType = "device_type"
        case userAgent = "user_agent"
        case ipAddress = "ip_address"
        case geolocation, referrer
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case version
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
    }
    
    public init(from analytics: StreamAnalytics, userId: String) {
        self.id = analytics.id
        self.userId = userId
        self.streamId = analytics.streamId
        self.sessionId = analytics.sessionId
        self.eventType = analytics.eventType.rawValue
        self.eventData = analytics.eventData
        self.timestamp = analytics.timestamp
        self.platform = analytics.platform.rawValue
        self.deviceType = "ios"
        self.userAgent = analytics.userAgent
        self.ipAddress = nil // Don't sync IP address for privacy
        self.geolocation = analytics.geolocation
        self.referrer = analytics.referrer
        self.createdAt = analytics.createdAt
        self.updatedAt = analytics.updatedAt
        self.version = analytics.version
        self.isDeleted = false
        self.lastSyncedAt = nil
    }
    
    public func toStreamAnalytics() -> StreamAnalytics {
        let analytics = StreamAnalytics(
            streamId: streamId,
            eventType: AnalyticsEventType(rawValue: eventType) ?? .view,
            eventData: eventData,
            timestamp: timestamp,
            platform: Platform(rawValue: platform) ?? .other
        )
        analytics.id = id
        analytics.sessionId = sessionId
        analytics.userAgent = userAgent
        analytics.geolocation = geolocation
        analytics.referrer = referrer
        analytics.createdAt = createdAt
        analytics.updatedAt = updatedAt
        analytics.version = version
        return analytics
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - SyncStreamBackup Model
public struct SyncStreamBackup: SyncModel {
    public let id: String
    public let userId: String
    public let name: String
    public let description: String?
    public let backupType: String
    public let dataVersion: String
    public let fileSize: Int64
    public let compressionType: String?
    public let checksum: String
    public let isEncrypted: Bool
    public let metadata: BackupMetadata
    public let downloadUrl: String?
    public let expiresAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public var version: Int
    public var isDeleted: Bool
    public var lastSyncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case backupType = "backup_type"
        case dataVersion = "data_version"
        case fileSize = "file_size"
        case compressionType = "compression_type"
        case checksum
        case isEncrypted = "is_encrypted"
        case metadata
        case downloadUrl = "download_url"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case version
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
    }
    
    public init(from backup: StreamBackup) {
        self.id = backup.id
        self.userId = backup.userId
        self.name = backup.name
        self.description = backup.description
        self.backupType = "full"
        self.dataVersion = "1.0"
        self.fileSize = Int64(backup.estimatedSize)
        self.compressionType = "gzip"
        self.checksum = backup.checksum
        self.isEncrypted = backup.isEncrypted
        self.metadata = BackupMetadata(
            streamCount: backup.data.streams.count,
            layoutCount: backup.data.layouts.count,
            sessionCount: backup.data.sessions.count,
            deviceInfo: backup.deviceInfo
        )
        self.downloadUrl = backup.downloadURL
        self.expiresAt = backup.expiresAt
        self.createdAt = backup.createdAt
        self.updatedAt = backup.updatedAt
        self.version = backup.version
        self.isDeleted = false
        self.lastSyncedAt = nil
    }
    
    public func toStreamBackup() -> StreamBackup {
        let backup = StreamBackup(
            id: id,
            userId: userId,
            name: name,
            data: BackupData(streams: [], layouts: [], sessions: []), // Will be loaded separately
            createdAt: createdAt
        )
        backup.description = description
        backup.checksum = checksum
        backup.isEncrypted = isEncrypted
        backup.downloadURL = downloadUrl
        backup.expiresAt = expiresAt
        backup.updatedAt = updatedAt
        backup.version = version
        return backup
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - SyncStreamTemplate Model
public struct SyncStreamTemplate: SyncModel {
    public let id: String
    public let userId: String
    public let name: String
    public let description: String
    public let category: String
    public let tags: [String]
    public let templateType: String
    public let configuration: TemplateConfiguration
    public let previewImages: [String]
    public let isPublic: Bool
    public let isPremium: Bool
    public let price: Double?
    public let currency: String?
    public let downloads: Int
    public let rating: Double
    public let ratingCount: Int
    public let version: String
    public let compatibility: [String]
    public let requirements: TemplateRequirements
    public let createdAt: Date
    public let updatedAt: Date
    public var syncVersion: Int
    public var isDeleted: Bool
    public var lastSyncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, tags
        case templateType = "template_type"
        case configuration
        case previewImages = "preview_images"
        case isPublic = "is_public"
        case isPremium = "is_premium"
        case price, currency, downloads, rating
        case ratingCount = "rating_count"
        case version, compatibility, requirements
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case syncVersion = "sync_version"
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
    }
    
    // Implement SyncModel requirements
    public var createdAt: Date { createdAt }
    public var updatedAt: Date { updatedAt }
    public var version: Int {
        get { syncVersion }
        set { syncVersion = newValue }
    }
    
    public init(from template: StreamTemplate, userId: String) {
        self.id = template.id
        self.userId = userId
        self.name = template.name
        self.description = template.templateDescription
        self.category = template.category
        self.tags = template.tags
        self.templateType = template.templateType.rawValue
        self.configuration = TemplateConfiguration(from: template.configuration)
        self.previewImages = template.previewImages
        self.isPublic = template.isPublic
        self.isPremium = template.isPremium
        self.price = template.price
        self.currency = template.currency
        self.downloads = template.downloads
        self.rating = template.rating
        self.ratingCount = template.ratingCount
        self.version = template.templateVersion
        self.compatibility = template.compatibility
        self.requirements = TemplateRequirements(from: template.requirements)
        self.createdAt = template.createdAt
        self.updatedAt = template.updatedAt
        self.syncVersion = template.version
        self.isDeleted = false
        self.lastSyncedAt = nil
    }
    
    public func toStreamTemplate() -> StreamTemplate {
        let template = StreamTemplate(
            name: name,
            templateType: TemplateType(rawValue: templateType) ?? .layout,
            configuration: configuration.toTemplateConfig()
        )
        template.id = id
        template.templateDescription = description
        template.category = category
        template.tags = tags
        template.previewImages = previewImages
        template.isPublic = isPublic
        template.isPremium = isPremium
        template.price = price
        template.currency = currency
        template.downloads = downloads
        template.rating = rating
        template.ratingCount = ratingCount
        template.templateVersion = version
        template.compatibility = compatibility
        template.requirements = requirements.toTemplateRequirements()
        template.createdAt = createdAt
        template.updatedAt = updatedAt
        template.version = syncVersion
        return template
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - Supporting Template Structures
public struct TemplateConfiguration: Codable {
    public let layoutConfig: LayoutConfiguration?
    public let streamConfig: StreamConfiguration?
    public let uiConfig: UIConfiguration?
    public let behaviorConfig: BehaviorConfiguration?
    
    enum CodingKeys: String, CodingKey {
        case layoutConfig = "layout_config"
        case streamConfig = "stream_config"
        case uiConfig = "ui_config"
        case behaviorConfig = "behavior_config"
    }
    
    public init(from config: TemplateConfig) {
        self.layoutConfig = config.layoutConfig.map { LayoutConfiguration(from: $0) }
        self.streamConfig = config.streamConfig.map { StreamConfiguration(from: $0) }
        self.uiConfig = config.uiConfig.map { UIConfiguration(from: $0) }
        self.behaviorConfig = config.behaviorConfig.map { BehaviorConfiguration(from: $0) }
    }
    
    public func toTemplateConfig() -> TemplateConfig {
        let config = TemplateConfig()
        config.layoutConfig = layoutConfig?.toLayoutConfig()
        config.streamConfig = streamConfig?.toStreamConfig()
        config.uiConfig = uiConfig?.toUIConfig()
        config.behaviorConfig = behaviorConfig?.toBehaviorConfig()
        return config
    }
}

public struct StreamConfiguration: Codable {
    public let defaultQuality: String
    public let autoReconnect: Bool
    public let bufferSize: Int
    public let maxRetries: Int
    
    enum CodingKeys: String, CodingKey {
        case defaultQuality = "default_quality"
        case autoReconnect = "auto_reconnect"
        case bufferSize = "buffer_size"
        case maxRetries = "max_retries"
    }
    
    public init(from config: StreamConfig) {
        self.defaultQuality = config.defaultQuality.rawValue
        self.autoReconnect = config.autoReconnect
        self.bufferSize = config.bufferSize
        self.maxRetries = config.maxRetries
    }
    
    public func toStreamConfig() -> StreamConfig {
        let config = StreamConfig()
        config.defaultQuality = StreamQuality(rawValue: defaultQuality) ?? .medium
        config.autoReconnect = autoReconnect
        config.bufferSize = bufferSize
        config.maxRetries = maxRetries
        return config
    }
}

public struct UIConfiguration: Codable {
    public let theme: String
    public let colorScheme: String
    public let fontSize: Double
    public let showControls: Bool
    
    enum CodingKeys: String, CodingKey {
        case theme
        case colorScheme = "color_scheme"
        case fontSize = "font_size"
        case showControls = "show_controls"
    }
    
    public init(from config: UIConfig) {
        self.theme = config.theme
        self.colorScheme = config.colorScheme
        self.fontSize = config.fontSize
        self.showControls = config.showControls
    }
    
    public func toUIConfig() -> UIConfig {
        let config = UIConfig()
        config.theme = theme
        config.colorScheme = colorScheme
        config.fontSize = fontSize
        config.showControls = showControls
        return config
    }
}

public struct BehaviorConfiguration: Codable {
    public let autoPlay: Bool
    public let loopEnabled: Bool
    public let muteOnStart: Bool
    public let showNotifications: Bool
    
    enum CodingKeys: String, CodingKey {
        case autoPlay = "auto_play"
        case loopEnabled = "loop_enabled"
        case muteOnStart = "mute_on_start"
        case showNotifications = "show_notifications"
    }
    
    public init(from config: BehaviorConfig) {
        self.autoPlay = config.autoPlay
        self.loopEnabled = config.loopEnabled
        self.muteOnStart = config.muteOnStart
        self.showNotifications = config.showNotifications
    }
    
    public func toBehaviorConfig() -> BehaviorConfig {
        let config = BehaviorConfig()
        config.autoPlay = autoPlay
        config.loopEnabled = loopEnabled
        config.muteOnStart = muteOnStart
        config.showNotifications = showNotifications
        return config
    }
}

public struct TemplateRequirements: Codable {
    public let minimumVersion: String
    public let supportedPlatforms: [String]
    public let requiredFeatures: [String]
    public let memoryRequirement: Int64
    public let storageRequirement: Int64
    
    enum CodingKeys: String, CodingKey {
        case minimumVersion = "minimum_version"
        case supportedPlatforms = "supported_platforms"
        case requiredFeatures = "required_features"
        case memoryRequirement = "memory_requirement"
        case storageRequirement = "storage_requirement"
    }
    
    public init(from requirements: TemplateRequirements) {
        self.minimumVersion = requirements.minimumVersion
        self.supportedPlatforms = requirements.supportedPlatforms
        self.requiredFeatures = requirements.requiredFeatures
        self.memoryRequirement = requirements.memoryRequirement
        self.storageRequirement = requirements.storageRequirement
    }
    
    public func toTemplateRequirements() -> TemplateRequirements {
        return TemplateRequirements(
            minimumVersion: minimumVersion,
            supportedPlatforms: supportedPlatforms,
            requiredFeatures: requiredFeatures,
            memoryRequirement: memoryRequirement,
            storageRequirement: storageRequirement
        )
    }
}

// MARK: - Supporting Backup Structures
public struct BackupMetadata: Codable {
    public let streamCount: Int
    public let layoutCount: Int
    public let sessionCount: Int
    public let deviceInfo: DeviceInfo
    
    enum CodingKeys: String, CodingKey {
        case streamCount = "stream_count"
        case layoutCount = "layout_count"
        case sessionCount = "session_count"
        case deviceInfo = "device_info"
    }
}

public struct DeviceInfo: Codable {
    public let platform: String
    public let version: String
    public let model: String
    public let identifier: String
    
    public init() {
        self.platform = "iOS"
        self.version = UIDevice.current.systemVersion
        self.model = UIDevice.current.model
        self.identifier = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}

// MARK: - Sync Conflict Resolution
public struct SyncConflict: Codable {
    public let id: String
    public let modelType: String
    public let modelId: String
    public let localVersion: Int
    public let remoteVersion: Int
    public let localData: [String: Any]
    public let remoteData: [String: Any]
    public let conflictType: SyncConflictType
    public let detectedAt: Date
    public let resolvedAt: Date?
    public let resolution: SyncConflictResolution?
    
    enum CodingKeys: String, CodingKey {
        case id
        case modelType = "model_type"
        case modelId = "model_id"
        case localVersion = "local_version"
        case remoteVersion = "remote_version"
        case localData = "local_data"
        case remoteData = "remote_data"
        case conflictType = "conflict_type"
        case detectedAt = "detected_at"
        case resolvedAt = "resolved_at"
        case resolution
    }
}

public enum SyncConflictType: String, Codable {
    case updateConflict = "update_conflict"
    case deleteConflict = "delete_conflict"
    case createConflict = "create_conflict"
    case versionMismatch = "version_mismatch"
}

public enum SyncConflictResolution: String, Codable {
    case useLocal = "use_local"
    case useRemote = "use_remote"
    case merge = "merge"
    case manual = "manual"
    case skip = "skip"
}

// MARK: - Sync Utilities
extension SyncModel {
    public func isNewerThan(_ other: Self) -> Bool {
        return self.updatedAt > other.updatedAt || 
               (self.updatedAt == other.updatedAt && self.version > other.version)
    }
    
    public func hasConflictWith(_ other: Self) -> Bool {
        return self.id == other.id && 
               self.updatedAt != other.updatedAt &&
               self.version == other.version
    }
    
    public mutating func markForSync() {
        self.version += 1
        self.lastSyncedAt = nil
    }
    
    public mutating func markSynced() {
        self.lastSyncedAt = Date()
    }
}