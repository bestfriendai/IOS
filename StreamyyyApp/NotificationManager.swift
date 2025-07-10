//
//  NotificationManager.swift
//  StreamyyyApp
//
//  Handles push notifications and local notifications
//

import Foundation
import UserNotifications
import UIKit
import Combine

// MARK: - Notification Manager
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        center.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                self?.checkAuthorizationStatus()
                
                if granted {
                    self?.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Local Notifications
    func scheduleStreamNotification(
        streamId: String,
        streamerName: String,
        title: String,
        scheduledTime: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "\(streamerName) is live!"
        content.body = title
        content.sound = .default
        content.badge = 1
        
        // Add custom data
        content.userInfo = [
            "type": "stream_live",
            "stream_id": streamId,
            "streamer_name": streamerName
        ]
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: scheduledTime.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "stream_\(streamId)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func scheduleFavoriteStreamNotification(
        streamId: String,
        streamerName: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Favorite streamer is live!"
        content.body = "\(streamerName) just started streaming"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "favorite_live",
            "stream_id": streamId,
            "streamer_name": streamerName
        ]
        
        // Immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "favorite_\(streamId)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule favorite notification: \(error)")
            }
        }
    }
    
    func scheduleSubscriptionReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Upgrade to Streamyyy Pro"
        content.body = "Unlock unlimited streams and premium features"
        content.sound = .default
        
        content.userInfo = [
            "type": "subscription_reminder"
        ]
        
        // Schedule for 3 days from now
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 3 * 24 * 60 * 60,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "subscription_reminder",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    // MARK: - Notification Management
    func cancelNotification(withIdentifier identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelStreamNotifications(for streamId: String) {
        center.getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.contains(streamId) }
                .map { $0.identifier }
            
            self.center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    func getPendingNotifications() -> AnyPublisher<[UNNotificationRequest], Never> {
        Future { promise in
            self.center.getPendingNotificationRequests { requests in
                promise(.success(requests))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Badge Management
    func updateBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Push Notification Token
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device token: \(tokenString)")
        
        // Send token to your server
        sendTokenToServer(tokenString)
    }
    
    private func sendTokenToServer(_ token: String) {
        // TODO: Fix concurrency issue
        // guard let userId = ClerkManager.shared.user?.id else { return }
        let userId = "mock_user_id"
        
        // TODO: Implement API call to send token to server
        let endpoint = APIEndpoint.updateDeviceToken(userId: userId, token: token)
        
        APIClient.shared.request(endpoint: endpoint, responseType: EmptyResponse.self)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to update device token: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("Device token updated successfully")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Handle Notification Response
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "stream_live", "favorite_live":
            if let streamId = userInfo["stream_id"] as? String {
                handleStreamNotification(streamId: streamId)
            }
            
        case "subscription_reminder":
            handleSubscriptionReminder()
            
        default:
            break
        }
    }
    
    private func handleStreamNotification(streamId: String) {
        // Navigate to stream or add to current view
        NotificationCenter.default.post(
            name: .openStream,
            object: nil,
            userInfo: ["streamId": streamId]
        )
    }
    
    private func handleSubscriptionReminder() {
        // Navigate to subscription view
        NotificationCenter.default.post(
            name: .showSubscription,
            object: nil
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationResponse(response)
        completionHandler()
    }
}

// MARK: - Notification Categories and Actions
extension NotificationManager {
    func setupNotificationCategories() {
        let streamCategory = UNNotificationCategory(
            identifier: "STREAM_CATEGORY",
            actions: [
                UNNotificationAction(
                    identifier: "WATCH_ACTION",
                    title: "Watch",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS_ACTION",
                    title: "Dismiss",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let subscriptionCategory = UNNotificationCategory(
            identifier: "SUBSCRIPTION_CATEGORY",
            actions: [
                UNNotificationAction(
                    identifier: "UPGRADE_ACTION",
                    title: "Upgrade",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "LATER_ACTION",
                    title: "Later",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([streamCategory, subscriptionCategory])
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let openStream = Notification.Name("openStream")
    static let showSubscription = Notification.Name("showSubscription")
    static let notificationPermissionChanged = Notification.Name("notificationPermissionChanged")
}

// MARK: - API Extensions
extension APIEndpoint {
    static func updateDeviceToken(userId: String, token: String) -> APIEndpoint {
        return .updateDeviceToken(userId: userId, token: token)
    }
}

extension APIEndpoint {
    // case updateDeviceToken(userId: String, token: String) // TODO: Fix enum structure
    
    var urlForDeviceToken: URL? {
        // TODO: Fix enum structure
        return nil
    }
    
    var methodForDeviceToken: HTTPMethod {
        // TODO: Fix enum structure
        return .GET
    }
    
    var bodyForDeviceToken: Codable? {
        // TODO: Fix enum structure
        return nil
    }
}

// MARK: - Empty Response Model
struct EmptyResponse: Codable {}

// MARK: - Notification Preferences
struct NotificationPreferences: Codable {
    var streamNotifications: Bool = true
    var favoriteNotifications: Bool = true
    var subscriptionReminders: Bool = true
    var marketingNotifications: Bool = false
    
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
}

// MARK: - Notification Analytics
class NotificationAnalytics {
    static let shared = NotificationAnalytics()
    
    private init() {}
    
    func trackNotificationSent(type: String, streamId: String? = nil) {
        // Track notification metrics
        let event = [
            "event": "notification_sent",
            "type": type,
            "stream_id": streamId ?? "",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Send to analytics service
        print("📊 Notification sent: \(event)")
    }
    
    func trackNotificationOpened(type: String, streamId: String? = nil) {
        let event = [
            "event": "notification_opened",
            "type": type,
            "stream_id": streamId ?? "",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        print("📊 Notification opened: \(event)")
    }
    
    func trackNotificationDismissed(type: String) {
        let event = [
            "event": "notification_dismissed",
            "type": type,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        print("📊 Notification dismissed: \(event)")
    }
}