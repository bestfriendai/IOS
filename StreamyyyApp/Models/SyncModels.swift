//
//  SyncModels.swift
//  StreamyyyApp
//
//  Database schema models for Supabase synchronization
//

import Foundation
import SwiftUI

// MARK: - Sync Stream Model
public struct SyncStream: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let url: String
    public let originalURL: String
    public let embedURL: String?
    public let platform: String
    public let title: String
    public let description: String?
    public let thumbnailURL: String?
    public let streamerName: String?
    public let streamerAvatarURL: String?
    public let category: String?
    public let language: String?
    public let tags: [String]
    public let isLive: Bool
    public let viewerCount: Int
    public let startedAt: Date?
    public let endedAt: Date?
    public let duration: TimeInterval
    public let quality: String
    public let availableQualities: [String]
    public let isMuted: Bool
    public let volume: Double
    public let isFullscreen: Bool
    public let isPictureInPicture: Bool
    public let isAutoPlay: Bool
    public let isVisible: Bool
    public let position: SyncStreamPosition
    public let metadata: [String: String]
    public let createdAt: Date
    public let updatedAt: Date
    public let lastViewedAt: Date?
    public let viewCount: Int
    public let isArchived: Bool
    public let archiveReason: String?
    public let healthStatus: String
    public let connectionAttempts: Int
    public let lastConnectionAttempt: Date?
    public let syncStatus: String
    public let lastSyncAt: Date?
    public let version: Int
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", url, originalURL = "original_url"
        case embedURL = "embed_url", platform, title, description
        case thumbnailURL = "thumbnail_url", streamerName = "streamer_name"
        case streamerAvatarURL = "streamer_avatar_url", category, language, tags
        case isLive = "is_live", viewerCount = "viewer_count"
        case startedAt = "started_at", endedAt = "ended_at", duration
        case quality, availableQualities = "available_qualities"
        case isMuted = "is_muted", volume, isFullscreen = "is_fullscreen"
        case isPictureInPicture = "is_picture_in_picture"
        case isAutoPlay = "is_auto_play", isVisible = "is_visible"
        case position, metadata, createdAt = "created_at"
        case updatedAt = "updated_at", lastViewedAt = "last_viewed_at"
        case viewCount = "view_count", isArchived = "is_archived"
        case archiveReason = "archive_reason", healthStatus = "health_status"
        case connectionAttempts = "connection_attempts"
        case lastConnectionAttempt = "last_connection_attempt"
        case syncStatus = "sync_status", lastSyncAt = "last_sync_at"
        case version
    }
    
    // MARK: - Transformation from Local Stream
    public init(from stream: Stream, userId: String) {
        self.id = stream.id
        self.userId = userId
        self.url = stream.url
        self.originalURL = stream.originalURL
        self.embedURL = stream.embedURL
        self.platform = stream.platform.rawValue
        self.title = stream.title
        self.description = stream.description
        self.thumbnailURL = stream.thumbnailURL
        self.streamerName = stream.streamerName
        self.streamerAvatarURL = stream.streamerAvatarURL
        self.category = stream.category
        self.language = stream.language
        self.tags = stream.tags
        self.isLive = stream.isLive
        self.viewerCount = stream.viewerCount
        self.startedAt = stream.startedAt
        self.endedAt = stream.endedAt
        self.duration = stream.duration
        self.quality = stream.quality.rawValue
        self.availableQualities = stream.availableQualities.map { $0.rawValue }
        self.isMuted = stream.isMuted
        self.volume = stream.volume
        self.isFullscreen = stream.isFullscreen
        self.isPictureInPicture = stream.isPictureInPicture
        self.isAutoPlay = stream.isAutoPlay
        self.isVisible = stream.isVisible
        self.position = SyncStreamPosition(from: stream.position)
        self.metadata = stream.metadata
        self.createdAt = stream.createdAt
        self.updatedAt = stream.updatedAt
        self.lastViewedAt = stream.lastViewedAt
        self.viewCount = stream.viewCount
        self.isArchived = stream.isArchived
        self.archiveReason = stream.archiveReason
        self.healthStatus = stream.healthStatus.rawValue
        self.connectionAttempts = stream.connectionAttempts
        self.lastConnectionAttempt = stream.lastConnectionAttempt
        self.syncStatus = "synced"
        self.lastSyncAt = Date()
        self.version = 1
    }
    
    // MARK: - Transformation to Local Stream
    public func toStream() -> Stream {
        let stream = Stream(
            id: id,
            url: url,
            platform: Platform(rawValue: platform),
            title: title
        )
        
        // Update all properties
        stream.originalURL = originalURL
        stream.embedURL = embedURL
        stream.description = description
        stream.thumbnailURL = thumbnailURL
        stream.streamerName = streamerName
        stream.streamerAvatarURL = streamerAvatarURL
        stream.category = category
        stream.language = language
        stream.tags = tags
        stream.isLive = isLive
        stream.viewerCount = viewerCount
        stream.startedAt = startedAt
        stream.endedAt = endedAt
        stream.duration = duration
        stream.quality = StreamQuality(rawValue: quality) ?? .auto
        stream.availableQualities = availableQualities.compactMap { StreamQuality(rawValue: $0) }
        stream.isMuted = isMuted
        stream.volume = volume
        stream.isFullscreen = isFullscreen
        stream.isPictureInPicture = isPictureInPicture
        stream.isAutoPlay = isAutoPlay
        stream.isVisible = isVisible
        stream.position = position.toStreamPosition()
        stream.metadata = metadata
        stream.createdAt = createdAt
        stream.updatedAt = updatedAt
        stream.lastViewedAt = lastViewedAt
        stream.viewCount = viewCount
        stream.isArchived = isArchived
        stream.archiveReason = archiveReason
        stream.healthStatus = StreamHealthStatus(rawValue: healthStatus) ?? .unknown
        stream.connectionAttempts = connectionAttempts
        stream.lastConnectionAttempt = lastConnectionAttempt
        
        return stream
    }
}

// MARK: - Sync Stream Position
public struct SyncStreamPosition: Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let zIndex: Int
    
    public init(from position: StreamPosition) {
        self.x = position.x
        self.y = position.y
        self.width = position.width
        self.height = position.height
        self.zIndex = position.zIndex
    }
    
    public func toStreamPosition() -> StreamPosition {
        return StreamPosition(x: x, y: y, width: width, height: height, zIndex: zIndex)
    }
}

// MARK: - Sync User Model
public struct SyncUser: Codable, Identifiable {
    public let id: String
    public let clerkId: String?
    public let email: String
    public let username: String?
    public let firstName: String?
    public let lastName: String?
    public let profileImageURL: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let lastActiveAt: Date
    public let isEmailVerified: Bool
    public let phoneNumber: String?
    public let isPhoneVerified: Bool
    public let timezone: String
    public let locale: String
    public let preferences: SyncUserPreferences
    public let subscriptionStatus: String
    public let subscriptionId: String?
    public let stripeCustomerId: String?
    public let isActive: Bool
    public let isBanned: Bool
    public let banReason: String?
    public let banExpiresAt: Date?
    public let metadata: [String: String]
    public let syncStatus: String
    public let lastSyncAt: Date?
    public let version: Int
    
    enum CodingKeys: String, CodingKey {
        case id, clerkId = "clerk_id", email, username
        case firstName = "first_name", lastName = "last_name"
        case profileImageURL = "profile_image_url"
        case createdAt = "created_at", updatedAt = "updated_at"
        case lastActiveAt = "last_active_at"
        case isEmailVerified = "is_email_verified"
        case phoneNumber = "phone_number"
        case isPhoneVerified = "is_phone_verified"
        case timezone, locale, preferences
        case subscriptionStatus = "subscription_status"
        case subscriptionId = "subscription_id"
        case stripeCustomerId = "stripe_customer_id"
        case isActive = "is_active", isBanned = "is_banned"
        case banReason = "ban_reason", banExpiresAt = "ban_expires_at"
        case metadata, syncStatus = "sync_status"
        case lastSyncAt = "last_sync_at", version
    }
    
    // MARK: - Transformation from Local User
    public init(from user: User) {
        self.id = user.id
        self.clerkId = user.clerkId
        self.email = user.email
        self.username = user.username
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.profileImageURL = user.profileImageURL
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
        self.lastActiveAt = user.lastActiveAt
        self.isEmailVerified = user.isEmailVerified
        self.phoneNumber = user.phoneNumber
        self.isPhoneVerified = user.isPhoneVerified
        self.timezone = user.timezone
        self.locale = user.locale
        self.preferences = SyncUserPreferences(from: user.preferences)
        self.subscriptionStatus = user.subscriptionStatus.rawValue
        self.subscriptionId = user.subscriptionId
        self.stripeCustomerId = user.stripeCustomerId
        self.isActive = user.isActive
        self.isBanned = user.isBanned
        self.banReason = user.banReason
        self.banExpiresAt = user.banExpiresAt
        self.metadata = user.metadata
        self.syncStatus = "synced"
        self.lastSyncAt = Date()
        self.version = 1
    }
    
    // MARK: - Transformation to Local User
    public func toUser() -> User {
        let user = User(
            id: id,
            clerkId: clerkId,
            email: email,
            username: username,
            firstName: firstName,
            lastName: lastName,
            profileImageURL: profileImageURL,
            phoneNumber: phoneNumber,
            timezone: timezone,
            locale: locale
        )
        
        // Update all properties
        user.createdAt = createdAt
        user.updatedAt = updatedAt
        user.lastActiveAt = lastActiveAt
        user.isEmailVerified = isEmailVerified
        user.isPhoneVerified = isPhoneVerified
        user.preferences = preferences.toUserPreferences()
        user.subscriptionStatus = SubscriptionStatus(rawValue: subscriptionStatus) ?? .free
        user.subscriptionId = subscriptionId
        user.stripeCustomerId = stripeCustomerId
        user.isActive = isActive
        user.isBanned = isBanned
        user.banReason = banReason
        user.banExpiresAt = banExpiresAt
        user.metadata = metadata
        
        return user
    }
}

// MARK: - Sync User Preferences
public struct SyncUserPreferences: Codable {
    public let theme: String
    public let autoPlayStreams: Bool
    public let enableNotifications: Bool
    public let enableAnalytics: Bool
    public let defaultQuality: String
    public let enablePictureInPicture: Bool
    public let enableHapticFeedback: Bool
    public let enableSoundEffects: Bool
    public let chatSettings: SyncChatSettings
    public let privacySettings: SyncPrivacySettings
    public let layoutSettings: SyncLayoutSettings
    
    enum CodingKeys: String, CodingKey {
        case theme, autoPlayStreams = "auto_play_streams"
        case enableNotifications = "enable_notifications"
        case enableAnalytics = "enable_analytics"
        case defaultQuality = "default_quality"
        case enablePictureInPicture = "enable_picture_in_picture"
        case enableHapticFeedback = "enable_haptic_feedback"
        case enableSoundEffects = "enable_sound_effects"
        case chatSettings = "chat_settings"
        case privacySettings = "privacy_settings"
        case layoutSettings = "layout_settings"
    }
    
    public init(from preferences: UserPreferences) {
        self.theme = preferences.theme.rawValue
        self.autoPlayStreams = preferences.autoPlayStreams
        self.enableNotifications = preferences.enableNotifications
        self.enableAnalytics = preferences.enableAnalytics
        self.defaultQuality = preferences.defaultQuality.rawValue
        self.enablePictureInPicture = preferences.enablePictureInPicture
        self.enableHapticFeedback = preferences.enableHapticFeedback
        self.enableSoundEffects = preferences.enableSoundEffects
        self.chatSettings = SyncChatSettings(from: preferences.chatSettings)
        self.privacySettings = SyncPrivacySettings(from: preferences.privacySettings)
        self.layoutSettings = SyncLayoutSettings(from: preferences.layoutSettings)
    }
    
    public func toUserPreferences() -> UserPreferences {
        var preferences = UserPreferences()
        preferences.theme = AppTheme(rawValue: theme) ?? .system
        preferences.autoPlayStreams = autoPlayStreams
        preferences.enableNotifications = enableNotifications
        preferences.enableAnalytics = enableAnalytics
        preferences.defaultQuality = StreamQuality(rawValue: defaultQuality) ?? .high
        preferences.enablePictureInPicture = enablePictureInPicture
        preferences.enableHapticFeedback = enableHapticFeedback
        preferences.enableSoundEffects = enableSoundEffects
        preferences.chatSettings = chatSettings.toChatSettings()
        preferences.privacySettings = privacySettings.toPrivacySettings()
        preferences.layoutSettings = layoutSettings.toLayoutSettings()
        return preferences
    }
}

// MARK: - Sync Chat Settings
public struct SyncChatSettings: Codable {
    public let enableChat: Bool
    public let enableEmotes: Bool
    public let enableMentions: Bool
    public let fontSize: String
    public let autoHideDelay: TimeInterval
    public let enableProfanityFilter: Bool
    public let enableSpamProtection: Bool
    
    enum CodingKeys: String, CodingKey {
        case enableChat = "enable_chat"
        case enableEmotes = "enable_emotes"
        case enableMentions = "enable_mentions"
        case fontSize = "font_size"
        case autoHideDelay = "auto_hide_delay"
        case enableProfanityFilter = "enable_profanity_filter"
        case enableSpamProtection = "enable_spam_protection"
    }
    
    public init(from settings: ChatSettings) {
        self.enableChat = settings.enableChat
        self.enableEmotes = settings.enableEmotes
        self.enableMentions = settings.enableMentions
        self.fontSize = settings.fontSize.rawValue
        self.autoHideDelay = settings.autoHideDelay
        self.enableProfanityFilter = settings.enableProfanityFilter
        self.enableSpamProtection = settings.enableSpamProtection
    }
    
    public func toChatSettings() -> ChatSettings {
        var settings = ChatSettings()
        settings.enableChat = enableChat
        settings.enableEmotes = enableEmotes
        settings.enableMentions = enableMentions
        settings.fontSize = ChatFontSize(rawValue: fontSize) ?? .medium
        settings.autoHideDelay = autoHideDelay
        settings.enableProfanityFilter = enableProfanityFilter
        settings.enableSpamProtection = enableSpamProtection
        return settings
    }
}

// MARK: - Sync Privacy Settings
public struct SyncPrivacySettings: Codable {
    public let allowAnalytics: Bool
    public let allowCrashReporting: Bool
    public let allowPersonalizedAds: Bool
    public let shareUsageData: Bool
    public let allowLocationAccess: Bool
    
    enum CodingKeys: String, CodingKey {
        case allowAnalytics = "allow_analytics"
        case allowCrashReporting = "allow_crash_reporting"
        case allowPersonalizedAds = "allow_personalized_ads"
        case shareUsageData = "share_usage_data"
        case allowLocationAccess = "allow_location_access"
    }
    
    public init(from settings: PrivacySettings) {
        self.allowAnalytics = settings.allowAnalytics
        self.allowCrashReporting = settings.allowCrashReporting
        self.allowPersonalizedAds = settings.allowPersonalizedAds
        self.shareUsageData = settings.shareUsageData
        self.allowLocationAccess = settings.allowLocationAccess
    }
    
    public func toPrivacySettings() -> PrivacySettings {
        var settings = PrivacySettings()
        settings.allowAnalytics = allowAnalytics
        settings.allowCrashReporting = allowCrashReporting
        settings.allowPersonalizedAds = allowPersonalizedAds
        settings.shareUsageData = shareUsageData
        settings.allowLocationAccess = allowLocationAccess
        return settings
    }
}

// MARK: - Sync Layout Settings
public struct SyncLayoutSettings: Codable {
    public let defaultLayout: String
    public let enableGridLines: Bool
    public let enableLabels: Bool
    public let compactMode: Bool
    public let animationsEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case defaultLayout = "default_layout"
        case enableGridLines = "enable_grid_lines"
        case enableLabels = "enable_labels"
        case compactMode = "compact_mode"
        case animationsEnabled = "animations_enabled"
    }
    
    public init(from settings: LayoutSettings) {
        self.defaultLayout = settings.defaultLayout
        self.enableGridLines = settings.enableGridLines
        self.enableLabels = settings.enableLabels
        self.compactMode = settings.compactMode
        self.animationsEnabled = settings.animationsEnabled
    }
    
    public func toLayoutSettings() -> LayoutSettings {
        var settings = LayoutSettings()
        settings.defaultLayout = defaultLayout
        settings.enableGridLines = enableGridLines
        settings.enableLabels = enableLabels
        settings.compactMode = compactMode
        settings.animationsEnabled = animationsEnabled
        return settings
    }
}

// MARK: - Sync Operation Model
public struct SyncOperation: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let entityType: String
    public let entityId: String
    public let operation: String
    public let data: [String: Any]?
    public let timestamp: Date
    public let retryCount: Int
    public let maxRetries: Int
    public let status: String
    public let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case operation, data, timestamp
        case retryCount = "retry_count"
        case maxRetries = "max_retries"
        case status, errorMessage = "error_message"
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        entityType: String,
        entityId: String,
        operation: SyncOperationType,
        data: [String: Any]? = nil,
        maxRetries: Int = 3
    ) {
        self.id = id
        self.userId = userId
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation.rawValue
        self.data = data
        self.timestamp = Date()
        self.retryCount = 0
        self.maxRetries = maxRetries
        self.status = SyncOperationStatus.pending.rawValue
        self.errorMessage = nil
    }
}

// MARK: - Sync Operation Type
public enum SyncOperationType: String, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case sync = "sync"
    case backup = "backup"
    case restore = "restore"
}

// MARK: - Sync Operation Status
public enum SyncOperationStatus: String, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case retrying = "retrying"
    case cancelled = "cancelled"
}

// MARK: - Conflict Resolution Model
public struct ConflictResolution: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let entityType: String
    public let entityId: String
    public let localData: [String: Any]
    public let remoteData: [String: Any]
    public let resolvedData: [String: Any]?
    public let resolution: String
    public let timestamp: Date
    public let resolvedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case localData = "local_data"
        case remoteData = "remote_data"
        case resolvedData = "resolved_data"
        case resolution, timestamp
        case resolvedAt = "resolved_at"
    }
}

// MARK: - Conflict Resolution Type
public enum ConflictResolutionType: String, CaseIterable {
    case useLocal = "use_local"
    case useRemote = "use_remote"
    case merge = "merge"
    case manual = "manual"
    case skip = "skip"
}

// MARK: - Sync Statistics
public struct SyncStats: Codable {
    public let userId: String
    public let totalSyncs: Int
    public let successfulSyncs: Int
    public let failedSyncs: Int
    public let lastSyncAt: Date?
    public let averageSyncTime: TimeInterval
    public let dataTransferred: Int64
    public let conflictsResolved: Int
    public let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalSyncs = "total_syncs"
        case successfulSyncs = "successful_syncs"
        case failedSyncs = "failed_syncs"
        case lastSyncAt = "last_sync_at"
        case averageSyncTime = "average_sync_time"
        case dataTransferred = "data_transferred"
        case conflictsResolved = "conflicts_resolved"
        case updatedAt = "updated_at"
    }
}

// MARK: - Sync Layout Model
public struct SyncLayout: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let name: String
    public let description: String?
    public let type: String
    public let configuration: [String: Any]
    public let isDefault: Bool
    public let isCustom: Bool
    public let isPremium: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let lastUsedAt: Date?
    public let useCount: Int
    public let thumbnailURL: String?
    public let tags: [String]
    public let metadata: [String: String]
    public let version: Int
    public let isShared: Bool
    public let shareCode: String?
    public let authorName: String?
    public let downloadCount: Int
    public let rating: Double
    public let ratingCount: Int
    public let syncStatus: String
    public let lastSyncAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", name, description, type, configuration
        case isDefault = "is_default", isCustom = "is_custom", isPremium = "is_premium"
        case createdAt = "created_at", updatedAt = "updated_at", lastUsedAt = "last_used_at"
        case useCount = "use_count", thumbnailURL = "thumbnail_url", tags, metadata, version
        case isShared = "is_shared", shareCode = "share_code", authorName = "author_name"
        case downloadCount = "download_count", rating, ratingCount = "rating_count"
        case syncStatus = "sync_status", lastSyncAt = "last_sync_at"
    }
    
    public init(from layout: Layout, userId: String) {
        self.id = layout.id
        self.userId = userId
        self.name = layout.name
        self.description = layout.description
        self.type = layout.type.rawValue
        self.configuration = layout.configuration.export()
        self.isDefault = layout.isDefault
        self.isCustom = layout.isCustom
        self.isPremium = layout.isPremium
        self.createdAt = layout.createdAt
        self.updatedAt = layout.updatedAt
        self.lastUsedAt = layout.lastUsedAt
        self.useCount = layout.useCount
        self.thumbnailURL = layout.thumbnailURL
        self.tags = layout.tags
        self.metadata = layout.metadata
        self.version = layout.version
        self.isShared = layout.isShared
        self.shareCode = layout.shareCode
        self.authorName = layout.authorName
        self.downloadCount = layout.downloadCount
        self.rating = layout.rating
        self.ratingCount = layout.ratingCount
        self.syncStatus = "synced"
        self.lastSyncAt = Date()
    }
    
    public func toLayout() -> Layout {
        let layoutType = LayoutType(rawValue: type) ?? .custom
        let configuration = LayoutConfiguration.import(self.configuration) ?? LayoutConfiguration.default(for: layoutType)
        
        let layout = Layout(
            id: id,
            name: name,
            type: layoutType,
            configuration: configuration
        )
        
        layout.description = description
        layout.isDefault = isDefault
        layout.isCustom = isCustom
        layout.isPremium = isPremium
        layout.createdAt = createdAt
        layout.updatedAt = updatedAt
        layout.lastUsedAt = lastUsedAt
        layout.useCount = useCount
        layout.thumbnailURL = thumbnailURL
        layout.tags = tags
        layout.metadata = metadata
        layout.version = version
        layout.isShared = isShared
        layout.shareCode = shareCode
        layout.authorName = authorName
        layout.downloadCount = downloadCount
        layout.rating = rating
        layout.ratingCount = ratingCount
        
        return layout
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - Sync Stream Session Model
public struct SyncStreamSession: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let name: String
    public let description: String?
    public let streamIds: [String]
    public let layoutId: String?
    public let isActive: Bool
    public let startedAt: Date
    public let endedAt: Date?
    public let duration: TimeInterval
    public let metadata: [String: String]
    public let createdAt: Date
    public let updatedAt: Date
    public let syncStatus: String
    public let lastSyncAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", name, description
        case streamIds = "stream_ids", layoutId = "layout_id"
        case isActive = "is_active", startedAt = "started_at", endedAt = "ended_at"
        case duration, metadata, createdAt = "created_at", updatedAt = "updated_at"
        case syncStatus = "sync_status", lastSyncAt = "last_sync_at"
    }
    
    public init(from session: StreamSession, userId: String) {
        self.id = session.id
        self.userId = userId
        self.name = session.name
        self.description = session.description
        self.streamIds = session.streamIds
        self.layoutId = session.layoutId
        self.isActive = session.isActive
        self.startedAt = session.startedAt
        self.endedAt = session.endedAt
        self.duration = session.duration
        self.metadata = session.metadata
        self.createdAt = session.createdAt
        self.updatedAt = session.updatedAt
        self.syncStatus = "synced"
        self.lastSyncAt = Date()
    }
    
    public func toStreamSession() -> StreamSession {
        return StreamSession(
            id: id,
            name: name,
            description: description,
            streamIds: streamIds,
            layoutId: layoutId,
            isActive: isActive,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - Sync Stream Analytics Model
public struct SyncStreamAnalytics: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let streamId: String
    public let event: String
    public let value: Double
    public let metadata: [String: String]
    public let timestamp: Date
    public let syncStatus: String
    public let lastSyncAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", streamId = "stream_id"
        case event, value, metadata, timestamp
        case syncStatus = "sync_status", lastSyncAt = "last_sync_at"
    }
    
    public init(from analytics: StreamAnalytics, userId: String) {
        self.id = analytics.id
        self.userId = userId
        self.streamId = analytics.stream?.id ?? ""
        self.event = analytics.event.rawValue
        self.value = analytics.value
        self.metadata = analytics.metadata
        self.timestamp = analytics.timestamp
        self.syncStatus = "synced"
        self.lastSyncAt = Date()
    }
    
    public func toStreamAnalytics() -> StreamAnalytics {
        return StreamAnalytics(
            id: id,
            timestamp: timestamp,
            event: AnalyticsEvent(rawValue: event) ?? .streamStart,
            value: value,
            metadata: metadata
        )
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - Sync Stream Backup Model
public struct SyncStreamBackup: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let name: String
    public let description: String?
    public let data: [String: Any]
    public let size: Int64
    public let createdAt: Date
    public let syncStatus: String
    public let lastSyncAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", name, description, data, size
        case createdAt = "created_at", syncStatus = "sync_status", lastSyncAt = "last_sync_at"
    }
    
    public init(from backup: StreamBackup) {
        self.id = backup.id
        self.userId = backup.userId
        self.name = backup.name
        self.description = backup.description
        self.data = backup.data.toDictionary()
        self.size = backup.size
        self.createdAt = backup.createdAt
        self.syncStatus = "synced"
        self.lastSyncAt = Date()
    }
    
    public func toStreamBackup() -> StreamBackup {
        return StreamBackup(
            id: id,
            userId: userId,
            name: name,
            description: description,
            data: BackupData.fromDictionary(data),
            size: size,
            createdAt: createdAt
        )
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - Sync Stream Template Model
public struct SyncStreamTemplate: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let name: String
    public let description: String?
    public let category: String
    public let tags: [String]
    public let layoutData: [String: Any]
    public let streamData: [String: Any]
    public let thumbnailURL: String?
    public let isPublic: Bool
    public let downloads: Int
    public let rating: Double
    public let ratingCount: Int
    public let version: Int
    public let createdAt: Date
    public let updatedAt: Date
    public let syncStatus: String
    public let lastSyncAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", name, description, category, tags
        case layoutData = "layout_data", streamData = "stream_data"
        case thumbnailURL = "thumbnail_url", isPublic = "is_public"
        case downloads, rating, ratingCount = "rating_count", version
        case createdAt = "created_at", updatedAt = "updated_at"
        case syncStatus = "sync_status", lastSyncAt = "last_sync_at"
    }
    
    public init(from template: StreamTemplate, userId: String) {
        self.id = template.id
        self.userId = userId
        self.name = template.name
        self.description = template.description
        self.category = template.category
        self.tags = template.tags
        self.layoutData = template.layoutData
        self.streamData = template.streamData
        self.thumbnailURL = template.thumbnailURL
        self.isPublic = template.isPublic
        self.downloads = template.downloads
        self.rating = template.rating
        self.ratingCount = template.ratingCount
        self.version = template.version
        self.createdAt = template.createdAt
        self.updatedAt = template.updatedAt
        self.syncStatus = "synced"
        self.lastSyncAt = Date()
    }
    
    public func toStreamTemplate() -> StreamTemplate {
        return StreamTemplate(
            id: id,
            name: name,
            description: description,
            category: category,
            tags: tags,
            layoutData: layoutData,
            streamData: streamData,
            thumbnailURL: thumbnailURL,
            isPublic: isPublic,
            downloads: downloads,
            rating: rating,
            ratingCount: ratingCount,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    public func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}