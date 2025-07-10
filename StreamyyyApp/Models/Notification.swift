//
//  Notification.swift
//  StreamyyyApp
//
//  User notification preferences and management model
//

import Foundation
import SwiftUI
import SwiftData
import UserNotifications

// MARK: - User Notification Model
@Model
public class UserNotification: Identifiable, Codable, ObservableObject {
    @Attribute(.unique) public var id: String
    public var type: NotificationType
    public var title: String
    public var message: String
    public var data: [String: String]
    public var isRead: Bool
    public var isArchived: Bool
    public var priority: NotificationPriority
    public var category: NotificationCategory
    public var actionType: NotificationActionType?
    public var actionData: [String: String]
    public var scheduledAt: Date?
    public var deliveredAt: Date?
    public var readAt: Date?
    public var expiresAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var deviceToken: String?
    public var pushIdentifier: String?
    public var retryCount: Int
    public var lastRetryAt: Date?
    public var metadata: [String: String]
    
    // MARK: - Relationships
    @Relationship(inverse: \User.notifications)
    public var user: User?
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        type: NotificationType,
        title: String,
        message: String,
        user: User? = nil,
        data: [String: String] = [:],
        priority: NotificationPriority = .normal,
        category: NotificationCategory = .general
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.data = data
        self.isRead = false
        self.isArchived = false
        self.priority = priority
        self.category = category
        self.actionType = nil
        self.actionData = [:]
        self.scheduledAt = nil
        self.deliveredAt = nil
        self.readAt = nil
        self.expiresAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.deviceToken = nil
        self.pushIdentifier = nil
        self.retryCount = 0
        self.lastRetryAt = nil
        self.metadata = [:]
        self.user = user
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, type, title, message, data, isRead, isArchived, priority, category
        case actionType, actionData, scheduledAt, deliveredAt, readAt, expiresAt
        case createdAt, updatedAt, deviceToken, pushIdentifier, retryCount, lastRetryAt, metadata
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(NotificationType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        data = try container.decode([String: String].self, forKey: .data)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        priority = try container.decode(NotificationPriority.self, forKey: .priority)
        category = try container.decode(NotificationCategory.self, forKey: .category)
        actionType = try container.decodeIfPresent(NotificationActionType.self, forKey: .actionType)
        actionData = try container.decode([String: String].self, forKey: .actionData)
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
        deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deviceToken = try container.decodeIfPresent(String.self, forKey: .deviceToken)
        pushIdentifier = try container.decodeIfPresent(String.self, forKey: .pushIdentifier)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        lastRetryAt = try container.decodeIfPresent(Date.self, forKey: .lastRetryAt)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(data, forKey: .data)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(priority, forKey: .priority)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(actionType, forKey: .actionType)
        try container.encode(actionData, forKey: .actionData)
        try container.encodeIfPresent(scheduledAt, forKey: .scheduledAt)
        try container.encodeIfPresent(deliveredAt, forKey: .deliveredAt)
        try container.encodeIfPresent(readAt, forKey: .readAt)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deviceToken, forKey: .deviceToken)
        try container.encodeIfPresent(pushIdentifier, forKey: .pushIdentifier)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(lastRetryAt, forKey: .lastRetryAt)
        try container.encode(metadata, forKey: .metadata)
    }
}

// MARK: - UserNotification Extensions
extension UserNotification {
    
    // MARK: - Computed Properties
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    public var isPending: Bool {
        return !isRead && !isArchived && !isExpired
    }
    
    public var isDelivered: Bool {
        return deliveredAt != nil
    }
    
    public var isScheduled: Bool {
        return scheduledAt != nil && deliveredAt == nil
    }
    
    public var canRetry: Bool {
        return retryCount < 3 && !isDelivered
    }
    
    public var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    public var priorityColor: Color {
        return priority.color
    }
    
    public var priorityIcon: String {
        return priority.icon
    }
    
    public var categoryIcon: String {
        return category.icon
    }
    
    public var categoryColor: Color {
        return category.color
    }
    
    public var hasAction: Bool {
        return actionType != nil
    }
    
    public var actionTitle: String {
        return actionType?.displayName ?? "View"
    }
    
    // MARK: - Status Methods
    public func markAsRead() {
        isRead = true
        readAt = Date()
        updatedAt = Date()
    }
    
    public func markAsUnread() {
        isRead = false
        readAt = nil
        updatedAt = Date()
    }
    
    public func archive() {
        isArchived = true
        updatedAt = Date()
    }
    
    public func unarchive() {
        isArchived = false
        updatedAt = Date()
    }
    
    public func markAsDelivered() {
        deliveredAt = Date()
        updatedAt = Date()
    }
    
    public func scheduleFor(_ date: Date) {
        scheduledAt = date
        updatedAt = Date()
    }
    
    public func setExpiration(_ date: Date) {
        expiresAt = date
        updatedAt = Date()
    }
    
    // MARK: - Retry Methods
    public func incrementRetryCount() {
        retryCount += 1
        lastRetryAt = Date()
        updatedAt = Date()
    }
    
    public func resetRetryCount() {
        retryCount = 0
        lastRetryAt = nil
        updatedAt = Date()
    }
    
    // MARK: - Action Methods
    public func setAction(_ actionType: NotificationActionType, data: [String: String] = [:]) {
        self.actionType = actionType
        self.actionData = data
        updatedAt = Date()
    }
    
    public func performAction() -> Bool {
        guard let actionType = actionType else { return false }
        
        switch actionType {
        case .openApp:
            return true
        case .openStream:
            return actionData["streamId"] != nil
        case .openProfile:
            return actionData["userId"] != nil
        case .openSettings:
            return true
        case .viewFavorites:
            return true
        case .dismissNotification:
            archive()
            return true
        case .snooze:
            if let snoozeMinutes = actionData["snoozeMinutes"], let minutes = Int(snoozeMinutes) {
                scheduleFor(Date().addingTimeInterval(TimeInterval(minutes * 60)))
            }
            return true
        case .custom:
            return actionData["customAction"] != nil
        }
    }
    
    // MARK: - Data Methods
    public func setData(key: String, value: String) {
        data[key] = value
        updatedAt = Date()
    }
    
    public func getData(key: String) -> String? {
        return data[key]
    }
    
    public func removeData(key: String) {
        data.removeValue(forKey: key)
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
    
    // MARK: - Push Notification Methods
    public func toPushNotificationContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.badge = 1
        content.categoryIdentifier = category.rawValue
        content.userInfo = [
            "notificationId": id,
            "type": type.rawValue,
            "data": data,
            "actionType": actionType?.rawValue ?? ""
        ]
        
        // Set sound based on priority
        switch priority {
        case .low:
            content.sound = nil
        case .normal:
            content.sound = .default
        case .high:
            content.sound = .defaultCritical
        case .urgent:
            content.sound = .defaultCritical
        }
        
        return content
    }
    
    public func createPushNotificationTrigger() -> UNNotificationTrigger? {
        guard let scheduledAt = scheduledAt else { return nil }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: scheduledAt)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}

// MARK: - Notification Type
public enum NotificationType: String, CaseIterable, Codable {
    case streamLive = "stream_live"
    case streamOffline = "stream_offline"
    case newFollower = "new_follower"
    case subscriptionExpiring = "subscription_expiring"
    case subscriptionRenewed = "subscription_renewed"
    case paymentFailed = "payment_failed"
    case appUpdate = "app_update"
    case maintenance = "maintenance"
    case security = "security"
    case promotional = "promotional"
    case achievement = "achievement"
    case reminder = "reminder"
    case system = "system"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .streamLive: return "Stream Live"
        case .streamOffline: return "Stream Offline"
        case .newFollower: return "New Follower"
        case .subscriptionExpiring: return "Subscription Expiring"
        case .subscriptionRenewed: return "Subscription Renewed"
        case .paymentFailed: return "Payment Failed"
        case .appUpdate: return "App Update"
        case .maintenance: return "Maintenance"
        case .security: return "Security Alert"
        case .promotional: return "Promotional"
        case .achievement: return "Achievement"
        case .reminder: return "Reminder"
        case .system: return "System"
        case .custom: return "Custom"
        }
    }
    
    public var icon: String {
        switch self {
        case .streamLive: return "broadcast"
        case .streamOffline: return "broadcast.slash"
        case .newFollower: return "person.badge.plus"
        case .subscriptionExpiring: return "clock.badge.exclamationmark"
        case .subscriptionRenewed: return "checkmark.circle"
        case .paymentFailed: return "creditcard.trianglebadge.exclamationmark"
        case .appUpdate: return "arrow.down.app"
        case .maintenance: return "wrench"
        case .security: return "shield.lefthalf.filled"
        case .promotional: return "tag"
        case .achievement: return "trophy"
        case .reminder: return "bell"
        case .system: return "gear"
        case .custom: return "star"
        }
    }
    
    public var color: Color {
        switch self {
        case .streamLive: return .green
        case .streamOffline: return .red
        case .newFollower: return .blue
        case .subscriptionExpiring: return .orange
        case .subscriptionRenewed: return .green
        case .paymentFailed: return .red
        case .appUpdate: return .blue
        case .maintenance: return .yellow
        case .security: return .red
        case .promotional: return .purple
        case .achievement: return .yellow
        case .reminder: return .blue
        case .system: return .gray
        case .custom: return .indigo
        }
    }
    
    public var defaultPriority: NotificationPriority {
        switch self {
        case .streamLive: return .normal
        case .streamOffline: return .low
        case .newFollower: return .normal
        case .subscriptionExpiring: return .high
        case .subscriptionRenewed: return .normal
        case .paymentFailed: return .high
        case .appUpdate: return .normal
        case .maintenance: return .high
        case .security: return .urgent
        case .promotional: return .low
        case .achievement: return .normal
        case .reminder: return .normal
        case .system: return .normal
        case .custom: return .normal
        }
    }
}

// MARK: - Notification Priority
public enum NotificationPriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    public var color: Color {
        switch self {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    public var icon: String {
        switch self {
        case .low: return "chevron.down"
        case .normal: return "minus"
        case .high: return "chevron.up"
        case .urgent: return "exclamationmark"
        }
    }
    
    public var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        }
    }
}

// MARK: - Notification Category
public enum NotificationCategory: String, CaseIterable, Codable {
    case general = "general"
    case stream = "stream"
    case social = "social"
    case billing = "billing"
    case security = "security"
    case system = "system"
    case marketing = "marketing"
    case achievement = "achievement"
    
    public var displayName: String {
        switch self {
        case .general: return "General"
        case .stream: return "Streams"
        case .social: return "Social"
        case .billing: return "Billing"
        case .security: return "Security"
        case .system: return "System"
        case .marketing: return "Marketing"
        case .achievement: return "Achievements"
        }
    }
    
    public var icon: String {
        switch self {
        case .general: return "bell"
        case .stream: return "tv"
        case .social: return "person.2"
        case .billing: return "creditcard"
        case .security: return "shield"
        case .system: return "gear"
        case .marketing: return "megaphone"
        case .achievement: return "trophy"
        }
    }
    
    public var color: Color {
        switch self {
        case .general: return .blue
        case .stream: return .purple
        case .social: return .green
        case .billing: return .orange
        case .security: return .red
        case .system: return .gray
        case .marketing: return .pink
        case .achievement: return .yellow
        }
    }
}

// MARK: - Notification Action Type
public enum NotificationActionType: String, CaseIterable, Codable {
    case openApp = "open_app"
    case openStream = "open_stream"
    case openProfile = "open_profile"
    case openSettings = "open_settings"
    case viewFavorites = "view_favorites"
    case dismissNotification = "dismiss_notification"
    case snooze = "snooze"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .openApp: return "Open App"
        case .openStream: return "Open Stream"
        case .openProfile: return "View Profile"
        case .openSettings: return "Open Settings"
        case .viewFavorites: return "View Favorites"
        case .dismissNotification: return "Dismiss"
        case .snooze: return "Snooze"
        case .custom: return "Custom Action"
        }
    }
    
    public var icon: String {
        switch self {
        case .openApp: return "app.badge"
        case .openStream: return "play.circle"
        case .openProfile: return "person.circle"
        case .openSettings: return "gear"
        case .viewFavorites: return "heart"
        case .dismissNotification: return "xmark"
        case .snooze: return "clock"
        case .custom: return "star"
        }
    }
}

// MARK: - Notification Settings
public struct NotificationSettings: Codable {
    public var isEnabled: Bool
    public var enabledTypes: Set<NotificationType>
    public var enabledCategories: Set<NotificationCategory>
    public var quietHours: QuietHours?
    public var groupByCategory: Bool
    public var showPreview: Bool
    public var enableSound: Bool
    public var enableVibration: Bool
    public var enableBadge: Bool
    public var snoozeDefaultMinutes: Int
    public var maxNotificationsPerDay: Int
    public var autoArchiveAfterDays: Int
    public var priorityFilter: NotificationPriority
    
    public init() {
        self.isEnabled = true
        self.enabledTypes = Set(NotificationType.allCases)
        self.enabledCategories = Set(NotificationCategory.allCases)
        self.quietHours = QuietHours()
        self.groupByCategory = false
        self.showPreview = true
        self.enableSound = true
        self.enableVibration = true
        self.enableBadge = true
        self.snoozeDefaultMinutes = 15
        self.maxNotificationsPerDay = 50
        self.autoArchiveAfterDays = 30
        self.priorityFilter = .low
    }
    
    public func isTypeEnabled(_ type: NotificationType) -> Bool {
        return isEnabled && enabledTypes.contains(type)
    }
    
    public func isCategoryEnabled(_ category: NotificationCategory) -> Bool {
        return isEnabled && enabledCategories.contains(category)
    }
    
    public func shouldShowNotification(_ notification: UserNotification) -> Bool {
        return isEnabled &&
               enabledTypes.contains(notification.type) &&
               enabledCategories.contains(notification.category) &&
               notification.priority.sortOrder <= priorityFilter.sortOrder &&
               !isInQuietHours()
    }
    
    public func isInQuietHours() -> Bool {
        guard let quietHours = quietHours, quietHours.isEnabled else { return false }
        return quietHours.isCurrentTimeInQuietHours()
    }
}

// MARK: - Quiet Hours
public struct QuietHours: Codable {
    public var isEnabled: Bool
    public var startTime: Date
    public var endTime: Date
    public var enabledDays: Set<Int> // 1-7 (Sunday-Saturday)
    
    public init() {
        self.isEnabled = false
        self.startTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
        self.endTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        self.enabledDays = Set([1, 2, 3, 4, 5, 6, 7]) // All days
    }
    
    public func isCurrentTimeInQuietHours() -> Bool {
        guard isEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.weekday, from: now)
        
        guard enabledDays.contains(currentDay) else { return false }
        
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let currentMinutes = (currentTime.hour ?? 0) * 60 + (currentTime.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        if startMinutes <= endMinutes {
            // Same day quiet hours
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Cross-midnight quiet hours
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
}

// MARK: - Notification Manager
public class NotificationManager: ObservableObject {
    @Published public var notifications: [UserNotification] = []
    @Published public var settings: NotificationSettings = NotificationSettings()
    @Published public var unreadCount: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var error: NotificationError?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    public init() {
        updateUnreadCount()
        setupNotificationCategories()
    }
    
    // MARK: - Public Methods
    public func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            self.error = .permissionDenied
            return false
        }
    }
    
    public func scheduleNotification(_ notification: UserNotification) async {
        guard settings.shouldShowNotification(notification) else { return }
        
        let content = notification.toPushNotificationContent()
        let trigger = notification.createPushNotificationTrigger()
        
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            notification.markAsDelivered()
            await MainActor.run {
                addNotification(notification)
            }
        } catch {
            await MainActor.run {
                self.error = .schedulingFailed
            }
        }
    }
    
    public func cancelNotification(_ notification: UserNotification) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notification.id])
        notification.archive()
    }
    
    public func addNotification(_ notification: UserNotification) {
        notifications.append(notification)
        updateUnreadCount()
    }
    
    public func removeNotification(_ notification: UserNotification) {
        notifications.removeAll { $0.id == notification.id }
        updateUnreadCount()
    }
    
    public func markAllAsRead() {
        notifications.forEach { $0.markAsRead() }
        updateUnreadCount()
    }
    
    public func archiveAllRead() {
        notifications.filter { $0.isRead }.forEach { $0.archive() }
        updateUnreadCount()
    }
    
    public func clearAll() {
        notifications.removeAll()
        updateUnreadCount()
    }
    
    // MARK: - Private Methods
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead && !$0.isArchived }.count
    }
    
    private func setupNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        // Stream category with actions
        let streamActions = [
            UNNotificationAction(identifier: "open_stream", title: "Open Stream", options: [.foreground]),
            UNNotificationAction(identifier: "dismiss", title: "Dismiss", options: [])
        ]
        categories.insert(UNNotificationCategory(identifier: "stream", actions: streamActions, intentIdentifiers: [], options: []))
        
        // General category
        let generalActions = [
            UNNotificationAction(identifier: "open_app", title: "Open App", options: [.foreground]),
            UNNotificationAction(identifier: "dismiss", title: "Dismiss", options: [])
        ]
        categories.insert(UNNotificationCategory(identifier: "general", actions: generalActions, intentIdentifiers: [], options: []))
        
        notificationCenter.setNotificationCategories(categories)
    }
    
    // MARK: - Computed Properties
    public var activeNotifications: [UserNotification] {
        return notifications.filter { $0.isPending }
    }
    
    public var archivedNotifications: [UserNotification] {
        return notifications.filter { $0.isArchived }
    }
    
    public var groupedNotifications: [NotificationCategory: [UserNotification]] {
        return Dictionary(grouping: activeNotifications) { $0.category }
    }
    
    public var sortedNotifications: [UserNotification] {
        return notifications.sorted { lhs, rhs in
            if lhs.priority.sortOrder != rhs.priority.sortOrder {
                return lhs.priority.sortOrder < rhs.priority.sortOrder
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

// MARK: - Notification Errors
public enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed
    case deliveryFailed
    case invalidNotification
    case quotaExceeded
    case deviceTokenMissing
    case networkError
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .schedulingFailed:
            return "Failed to schedule notification"
        case .deliveryFailed:
            return "Failed to deliver notification"
        case .invalidNotification:
            return "Invalid notification"
        case .quotaExceeded:
            return "Notification quota exceeded"
        case .deviceTokenMissing:
            return "Device token missing"
        case .networkError:
            return "Network error"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Notification Extensions
extension UserNotification {
    public static func createStreamLiveNotification(
        for user: User,
        streamTitle: String,
        streamerName: String,
        streamId: String
    ) -> UserNotification {
        let notification = UserNotification(
            type: .streamLive,
            title: "\(streamerName) is now live!",
            message: streamTitle,
            user: user,
            data: [
                "streamId": streamId,
                "streamerName": streamerName,
                "streamTitle": streamTitle
            ],
            priority: .normal,
            category: .stream
        )
        
        notification.setAction(.openStream, data: ["streamId": streamId])
        return notification
    }
    
    public static func createSubscriptionExpiringNotification(
        for user: User,
        daysUntilExpiration: Int
    ) -> UserNotification {
        let notification = UserNotification(
            type: .subscriptionExpiring,
            title: "Subscription Expiring Soon",
            message: "Your subscription expires in \(daysUntilExpiration) days",
            user: user,
            data: ["daysUntilExpiration": "\(daysUntilExpiration)"],
            priority: .high,
            category: .billing
        )
        
        notification.setAction(.openSettings, data: ["section": "subscription"])
        return notification
    }
    
    public static func createPaymentFailedNotification(
        for user: User,
        amount: String
    ) -> UserNotification {
        let notification = UserNotification(
            type: .paymentFailed,
            title: "Payment Failed",
            message: "Unable to process payment of \(amount)",
            user: user,
            data: ["amount": amount],
            priority: .high,
            category: .billing
        )
        
        notification.setAction(.openSettings, data: ["section": "billing"])
        return notification
    }
}