//
//  NotificationManager.swift
//  StreamyyyApp
//
//  Local notification management for stream status updates and app events
//  Created by Claude Code on 2025-07-11
//

import Foundation
import UserNotifications
import UIKit
import Combine

// MARK: - Notification Manager
@MainActor
public class NotificationManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    public static let shared = NotificationManager()
    
    // MARK: - Published Properties
    @Published public var isAuthorized = false
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var pendingNotifications: [PendingNotification] = []
    
    // MARK: - Private Properties
    private let center = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    private let analyticsManager = AnalyticsManager.shared
    
    // MARK: - Notification Categories
    private enum NotificationCategory: String, CaseIterable {
        case liveStatus = "LIVE_STATUS"
        case subscription = "SUBSCRIPTION"
        case general = "GENERAL"
        case promotion = "PROMOTION"
        
        var identifier: String { rawValue }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationCenter()
        checkAuthorizationStatus()
    }
    
    // MARK: - Setup
    private func setupNotificationCenter() {
        center.delegate = self
        setupNotificationCategories()
        
        // Monitor app lifecycle for badge management
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.clearBadgeCount()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationCategories() {
        let categories: Set<UNNotificationCategory> = [
            // Live Status Category with actions
            UNNotificationCategory(
                identifier: NotificationCategory.liveStatus.identifier,
                actions: [
                    UNNotificationAction(
                        identifier: "WATCH_STREAM",
                        title: "Watch",
                        options: [.foreground]
                    ),
                    UNNotificationAction(
                        identifier: "DISMISS",
                        title: "Dismiss",
                        options: []
                    )
                ],
                intentIdentifiers: [],
                options: [.customDismissAction]
            ),
            
            // Subscription Category
            UNNotificationCategory(
                identifier: NotificationCategory.subscription.identifier,
                actions: [
                    UNNotificationAction(
                        identifier: "VIEW_SUBSCRIPTION",
                        title: "View",
                        options: [.foreground]
                    )
                ],
                intentIdentifiers: [],
                options: []
            ),
            
            // General Category
            UNNotificationCategory(
                identifier: NotificationCategory.general.identifier,
                actions: [],
                intentIdentifiers: [],
                options: []
            )
        ]
        
        center.setNotificationCategories(categories)
    }
    
    // MARK: - Permission Management
    public func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await updateAuthorizationStatus()
            
            if granted {
                analyticsManager.track(name: "notification_permission_granted")
            } else {
                analyticsManager.track(name: "notification_permission_denied")
            }
            
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            analyticsManager.trackError(error: error, context: "notification_permission_request")
            return false
        }
    }
    
    private func updateAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    private func checkAuthorizationStatus() {
        Task {
            await updateAuthorizationStatus()
        }
    }
    
    // MARK: - Notification Scheduling
    public func scheduleNotification(
        id: String,
        title: String,
        body: String,
        data: [String: Any] = [:],
        delay: TimeInterval = 0,
        category: String = NotificationCategory.general.identifier,
        playSound: Bool = true
    ) async {
        guard isAuthorized else {
            print("⚠️ Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.userInfo = data
        
        if playSound {
            content.sound = .default
        }
        
        // Add badge increment
        let currentBadge = await getCurrentBadgeCount()
        content.badge = NSNumber(value: currentBadge + 1)
        
        let trigger = delay > 0 
            ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            : nil
        
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📱 Scheduled notification: \(title)")
            
            // Track analytics
            analyticsManager.track(name: "notification_scheduled", properties: [
                "notification_id": id,
                "category": category,
                "has_delay": delay > 0
            ])
            
        } catch {
            print("❌ Failed to schedule notification: \(error)")
            analyticsManager.trackError(error: error, context: "notification_scheduling")
        }
    }
    
    // MARK: - Live Stream Notifications
    public func scheduleStreamLiveNotification(stream: DiscoveredStream) async {
        await scheduleNotification(
            id: "stream_live_\(stream.id)",
            title: "🔴 \(stream.channelName) is Live!",
            body: stream.title,
            data: [
                "stream_id": stream.id,
                "platform": stream.platform.rawValue,
                "action": "stream_started"
            ],
            category: NotificationCategory.liveStatus.identifier
        )
        
        analyticsManager.trackLiveNotificationSent(
            streamId: stream.id,
            platform: stream.platform.rawValue,
            type: "stream_started"
        )
    }
    
    public func scheduleStreamOfflineNotification(stream: DiscoveredStream) async {
        await scheduleNotification(
            id: "stream_offline_\(stream.id)",
            title: "⏹️ Stream Ended",
            body: "\(stream.channelName) has ended their stream",
            data: [
                "stream_id": stream.id,
                "platform": stream.platform.rawValue,
                "action": "stream_ended"
            ],
            category: NotificationCategory.liveStatus.identifier,
            playSound: false // Less intrusive for stream endings
        )
        
        analyticsManager.trackLiveNotificationSent(
            streamId: stream.id,
            platform: stream.platform.rawValue,
            type: "stream_ended"
        )
    }
    
    // MARK: - Subscription Notifications
    public func scheduleSubscriptionNotification(type: SubscriptionNotificationType, title: String, body: String) async {
        await scheduleNotification(
            id: "subscription_\(type.rawValue)_\(Date().timeIntervalSince1970)",
            title: title,
            body: body,
            data: [
                "subscription_type": type.rawValue,
                "action": "subscription_update"
            ],
            category: NotificationCategory.subscription.identifier
        )
    }
    
    // MARK: - Notification Management
    public func cancelNotification(withId id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
        
        analyticsManager.track(name: "notification_cancelled", properties: [
            "notification_id": id
        ])
    }
    
    public func cancelAllStreamNotifications(streamId: String) {
        let identifiers = [
            "stream_live_\(streamId)",
            "stream_offline_\(streamId)",
            "live_status_\(streamId)"
        ]
        
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    public func getPendingNotifications() async -> [PendingNotification] {
        let requests = await center.pendingNotificationRequests()
        return requests.map { request in
            PendingNotification(
                id: request.identifier,
                title: request.content.title,
                body: request.content.body,
                scheduledDate: (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate(),
                category: request.content.categoryIdentifier,
                data: request.content.userInfo
            )
        }
    }
    
    public func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        
        analyticsManager.track(name: "all_notifications_cleared")
    }
    
    // MARK: - Badge Management
    private func getCurrentBadgeCount() async -> Int {
        return await UIApplication.shared.applicationIconBadgeNumber
    }
    
    private func clearBadgeCount() async {
        await UIApplication.shared.setApplicationIconBadgeNumber(0)
    }
    
    public func setBadgeCount(_ count: Int) async {
        await UIApplication.shared.setApplicationIconBadgeNumber(count)
    }
    
    // MARK: - Settings
    public func openNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
            analyticsManager.track(name: "notification_settings_opened")
        }
    }
    
    // MARK: - Analytics
    public func getNotificationMetrics() -> NotificationMetrics {
        Task {
            let pending = await getPendingNotifications()
            let currentBadge = await getCurrentBadgeCount()
            
            await MainActor.run {
                self.pendingNotifications = pending
            }
            
            return NotificationMetrics(
                authorizationStatus: authorizationStatus,
                pendingCount: pending.count,
                currentBadgeCount: currentBadge,
                categoryCounts: Dictionary(grouping: pending) { $0.category }
                    .mapValues { $0.count }
            )
        }
        
        // Return placeholder for now since this is async
        return NotificationMetrics(
            authorizationStatus: authorizationStatus,
            pendingCount: 0,
            currentBadgeCount: 0,
            categoryCounts: [:]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
        
        analyticsManager.track(name: "notification_presented_foreground", properties: [
            "notification_id": notification.request.identifier,
            "category": notification.request.content.categoryIdentifier
        ])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Track analytics
        analyticsManager.track(name: "notification_interacted", properties: [
            "notification_id": response.notification.request.identifier,
            "action": actionIdentifier,
            "category": response.notification.request.content.categoryIdentifier
        ])
        
        // Handle notification actions
        Task { @MainActor in
            await handleNotificationResponse(response)
            completionHandler()
        }
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Handle stream live notifications
        if let streamId = userInfo["stream_id"] as? String,
           let platform = userInfo["platform"] as? String {
            
            switch actionIdentifier {
            case "WATCH_STREAM":
                // Open stream in app
                await openStream(streamId: streamId, platform: platform)
                
                analyticsManager.trackLiveNotificationInteracted(
                    streamId: streamId,
                    platform: platform,
                    action: "watch"
                )
                
            case UNNotificationDefaultActionIdentifier:
                // Default tap - open app to stream
                await openStream(streamId: streamId, platform: platform)
                
                analyticsManager.trackLiveNotificationInteracted(
                    streamId: streamId,
                    platform: platform,
                    action: "tap"
                )
                
            default:
                break
            }
        }
        
        // Handle subscription notifications
        if let subscriptionType = userInfo["subscription_type"] as? String {
            switch actionIdentifier {
            case "VIEW_SUBSCRIPTION":
                // Open subscription view
                await openSubscriptionView()
                
            default:
                break
            }
        }
    }
    
    private func openStream(streamId: String, platform: String) async {
        // TODO: Implement navigation to specific stream
        // This would typically involve updating app state or sending a notification
        // to navigate to the stream view
        
        NotificationCenter.default.post(
            name: .openStreamFromNotification,
            object: nil,
            userInfo: [
                "stream_id": streamId,
                "platform": platform
            ]
        )
    }
    
    private func openSubscriptionView() async {
        // TODO: Implement navigation to subscription view
        NotificationCenter.default.post(
            name: .openSubscriptionFromNotification,
            object: nil
        )
    }
}

// MARK: - Supporting Types

public struct PendingNotification {
    public let id: String
    public let title: String
    public let body: String
    public let scheduledDate: Date?
    public let category: String
    public let data: [AnyHashable: Any]
}

public struct NotificationMetrics {
    public let authorizationStatus: UNAuthorizationStatus
    public let pendingCount: Int
    public let currentBadgeCount: Int
    public let categoryCounts: [String: Int]
    
    public var isAuthorized: Bool {
        return authorizationStatus == .authorized
    }
    
    public var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Permission not requested"
        case .denied:
            return "Permission denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional authorization"
        case .ephemeral:
            return "Ephemeral authorization"
        @unknown default:
            return "Unknown status"
        }
    }
}

public enum SubscriptionNotificationType: String {
    case created = "created"
    case updated = "updated"
    case cancelled = "cancelled"
    case renewed = "renewed"
    case expired = "expired"
}

// MARK: - Notification Names

extension Notification.Name {
    static let openStreamFromNotification = Notification.Name("openStreamFromNotification")
    static let openSubscriptionFromNotification = Notification.Name("openSubscriptionFromNotification")
}