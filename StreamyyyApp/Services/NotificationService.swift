//
//  NotificationService.swift
//  StreamyyyApp
//
//  Enhanced notification service with push notification support
//  Handles local notifications, remote push notifications, and server integration
//

import Foundation
import UserNotifications
import UIKit
import Combine

// MARK: - Notification Service
@MainActor
public class NotificationService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    public static let shared = NotificationService()
    
    // MARK: - Published Properties
    @Published public var isAuthorized = false
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var deviceToken: String?
    @Published public var preferences = NotificationPreferences()
    @Published public var pendingNotifications: [UNNotificationRequest] = []
    @Published public var deliveredNotifications: [UNNotification] = []
    
    // MARK: - Private Properties
    private let center = UNUserNotificationCenter.current()
    private let networkService = NotificationNetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    private var isInitialized = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationService()
    }
    
    // MARK: - Setup
    private func setupNotificationService() {
        guard !isInitialized else { return }
        isInitialized = true
        
        center.delegate = self
        setupNotificationCategories()
        checkAuthorizationStatus()
        loadPreferences()
        setupObservers()
    }
    
    private func setupObservers() {
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshNotificationData()
                }
            }
            .store(in: &cancellables)
        
        // Monitor subscription changes
        NotificationCenter.default.publisher(for: .subscriptionCreated)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleSubscriptionChange(type: "created", notification: notification)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .subscriptionUpdated)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleSubscriptionChange(type: "updated", notification: notification)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .subscriptionCanceled)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleSubscriptionChange(type: "canceled", notification: notification)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authorization
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound, .provisional, .criticalAlert])
            
            isAuthorized = granted
            await checkAuthorizationStatus()
            
            if granted {
                await registerForRemoteNotifications()
                AnalyticsManager.shared.trackNotificationPermissionGranted()
            } else {
                AnalyticsManager.shared.trackNotificationPermissionDenied()
            }
            
            return granted
            
        } catch {
            print("Failed to request notification authorization: \(error)")
            AnalyticsManager.shared.trackNotificationPermissionError(error)
            return false
        }
    }
    
    public func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        
        // Update preferences based on current settings
        preferences.soundEnabled = settings.soundSetting == .enabled
        preferences.badgeEnabled = settings.badgeSetting == .enabled
        preferences.alertEnabled = settings.alertSetting == .enabled
    }
    
    @MainActor
    private func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    // MARK: - Device Token Management
    public func handleDeviceToken(_ deviceToken: Data) async {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        print("📱 Device token received: \(tokenString)")
        
        // Send token to server
        await sendTokenToServer(tokenString)
        
        // Track analytics
        AnalyticsManager.shared.trackDeviceTokenUpdated()
    }
    
    public func handleDeviceTokenError(_ error: Error) {
        print("❌ Failed to get device token: \(error)")
        AnalyticsManager.shared.trackDeviceTokenError(error)
    }
    
    private func sendTokenToServer(_ token: String) async {
        do {
            try await networkService.updateDeviceToken(token: token)
            print("✅ Device token sent to server successfully")
        } catch {
            print("❌ Failed to send device token to server: \(error)")
        }
    }
    
    // MARK: - Local Notifications
    public func scheduleStreamLiveNotification(
        streamId: String,
        streamerName: String,
        streamTitle: String,
        platform: String = "Twitch",
        delay: TimeInterval = 1
    ) async {
        guard preferences.streamNotifications && isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🔴 \(streamerName) is live!"
        content.body = streamTitle
        content.sound = preferences.soundEnabled ? .default : nil
        content.badge = preferences.badgeEnabled ? 1 : 0
        content.categoryIdentifier = NotificationCategory.streamLive.rawValue
        
        // Add custom data
        content.userInfo = [
            "type": NotificationType.streamLive.rawValue,
            "stream_id": streamId,
            "streamer_name": streamerName,
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Add image if available
        if let imageURL = await getStreamerThumbnail(streamId: streamId) {
            content.attachments = [try await createImageAttachment(from: imageURL)]
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "stream_live_\(streamId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📨 Scheduled stream live notification for \(streamerName)")
            AnalyticsManager.shared.trackNotificationScheduled(type: "stream_live")
        } catch {
            print("❌ Failed to schedule stream live notification: \(error)")
        }
    }
    
    public func scheduleSubscriptionNotification(
        type: SubscriptionNotificationType,
        title: String,
        body: String,
        delay: TimeInterval = 1,
        metadata: [String: Any] = [:]
    ) async {
        guard preferences.subscriptionNotifications && isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = preferences.soundEnabled ? .default : nil
        content.badge = preferences.badgeEnabled ? 1 : 0
        content.categoryIdentifier = NotificationCategory.subscription.rawValue
        
        var userInfo: [String: Any] = [
            "type": NotificationType.subscription.rawValue,
            "subscription_type": type.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Merge metadata
        for (key, value) in metadata {
            userInfo[key] = value
        }
        
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "subscription_\(type.rawValue)_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📨 Scheduled subscription notification: \(type.rawValue)")
            AnalyticsManager.shared.trackNotificationScheduled(type: "subscription")
        } catch {
            print("❌ Failed to schedule subscription notification: \(error)")
        }
    }
    
    public func scheduleAppEngagementNotification(
        title: String,
        body: String,
        delay: TimeInterval
    ) async {
        guard preferences.engagementNotifications && isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = preferences.soundEnabled ? .default : nil
        content.badge = preferences.badgeEnabled ? 1 : 0
        content.categoryIdentifier = NotificationCategory.engagement.rawValue
        
        content.userInfo = [
            "type": NotificationType.engagement.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "engagement_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📨 Scheduled engagement notification")
            AnalyticsManager.shared.trackNotificationScheduled(type: "engagement")
        } catch {
            print("❌ Failed to schedule engagement notification: \(error)")
        }
    }
    
    // MARK: - Push Notifications
    public func handlePushNotification(_ userInfo: [AnyHashable: Any]) async {
        print("📲 Received push notification: \(userInfo)")
        
        guard let typeString = userInfo["type"] as? String,
              let notificationType = NotificationType(rawValue: typeString) else {
            print("❌ Invalid notification type in push notification")
            return
        }
        
        // Track analytics
        AnalyticsManager.shared.trackPushNotificationReceived(type: typeString)
        
        // Handle different notification types
        switch notificationType {
        case .streamLive:
            await handleStreamLivePush(userInfo)
        case .subscription:
            await handleSubscriptionPush(userInfo)
        case .engagement:
            await handleEngagementPush(userInfo)
        case .systemUpdate:
            await handleSystemUpdatePush(userInfo)
        }
    }
    
    private func handleStreamLivePush(_ userInfo: [AnyHashable: Any]) async {
        guard let streamId = userInfo["stream_id"] as? String,
              let streamerName = userInfo["streamer_name"] as? String else { return }
        
        // Update local data or show immediate notification if app is active
        if UIApplication.shared.applicationState == .active {
            await showInAppNotification(
                title: "🔴 \(streamerName) is live!",
                body: userInfo["stream_title"] as? String ?? "Check out the stream",
                data: userInfo
            )
        }
        
        // Track engagement
        AnalyticsManager.shared.trackStreamNotificationReceived(streamId: streamId)
    }
    
    private func handleSubscriptionPush(_ userInfo: [AnyHashable: Any]) async {
        // Handle subscription-related push notifications
        if let subscriptionType = userInfo["subscription_type"] as? String {
            switch subscriptionType {
            case "trial_ending":
                await handleTrialEndingPush(userInfo)
            case "payment_failed":
                await handlePaymentFailedPush(userInfo)
            case "renewed":
                await handleSubscriptionRenewedPush(userInfo)
            default:
                break
            }
        }
    }
    
    private func handleEngagementPush(_ userInfo: [AnyHashable: Any]) async {
        // Handle engagement push notifications
        print("📱 Received engagement push notification")
    }
    
    private func handleSystemUpdatePush(_ userInfo: [AnyHashable: Any]) async {
        // Handle system update notifications
        print("🔧 Received system update notification")
    }
    
    // MARK: - Notification Management
    public func cancelNotification(withIdentifier identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        await refreshNotificationData()
    }
    
    public func cancelAllStreamNotifications(for streamId: String) async {
        let pendingRequests = await center.pendingNotificationRequests()
        let identifiersToRemove = pendingRequests
            .filter { request in
                request.identifier.contains(streamId) ||
                (request.content.userInfo["stream_id"] as? String) == streamId
            }
            .map { $0.identifier }
        
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        await refreshNotificationData()
    }
    
    public func cancelAllNotifications() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        await refreshNotificationData()
    }
    
    public func refreshNotificationData() async {
        pendingNotifications = await center.pendingNotificationRequests()
        deliveredNotifications = await center.deliveredNotifications()
    }
    
    // MARK: - Badge Management
    public func updateBadgeCount(_ count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
        AnalyticsManager.shared.trackBadgeCountUpdated(count: count)
    }
    
    public func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Preferences Management
    public func updatePreferences(_ newPreferences: NotificationPreferences) {
        preferences = newPreferences
        savePreferences()
        
        // Sync preferences with server
        Task {
            try? await networkService.updateNotificationPreferences(preferences)
        }
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "notification_preferences"),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = decoded
        }
    }
    
    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "notification_preferences")
        }
    }
    
    // MARK: - Helper Methods
    private func createImageAttachment(from url: URL) async throws -> UNNotificationAttachment {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFile = tempDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        
        try data.write(to: tempFile)
        
        return try UNNotificationAttachment(
            identifier: UUID().uuidString,
            url: tempFile,
            options: [UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg"]
        )
    }
    
    private func getStreamerThumbnail(streamId: String) async -> URL? {
        // TODO: Implement thumbnail fetching from stream service
        return nil
    }
    
    private func showInAppNotification(title: String, body: String, data: [AnyHashable: Any]) async {
        // TODO: Implement in-app notification banner
        print("📱 In-app notification: \(title) - \(body)")
    }
    
    // MARK: - Event Handlers
    private func handleSubscriptionChange(type: String, notification: Notification) async {
        switch type {
        case "created":
            await scheduleSubscriptionNotification(
                type: .activated,
                title: "Welcome to Streamyyy Pro! 🎉",
                body: "Your subscription is now active. Enjoy unlimited streaming!"
            )
        case "updated":
            await scheduleSubscriptionNotification(
                type: .updated,
                title: "Subscription Updated",
                body: "Your subscription plan has been changed successfully."
            )
        case "canceled":
            await scheduleSubscriptionNotification(
                type: .canceled,
                title: "Subscription Canceled",
                body: "Your subscription will remain active until the end of your billing period."
            )
        default:
            break
        }
    }
    
    private func handleTrialEndingPush(_ userInfo: [AnyHashable: Any]) async {
        let daysRemaining = userInfo["days_remaining"] as? Int ?? 1
        
        await scheduleSubscriptionNotification(
            type: .trialEnding,
            title: "Trial Ending Soon",
            body: "Your free trial ends in \(daysRemaining) day\(daysRemaining == 1 ? "" : "s"). Upgrade to continue enjoying premium features!",
            metadata: userInfo
        )
    }
    
    private func handlePaymentFailedPush(_ userInfo: [AnyHashable: Any]) async {
        await scheduleSubscriptionNotification(
            type: .paymentFailed,
            title: "Payment Failed",
            body: "We couldn't process your payment. Please update your payment method to continue your subscription.",
            metadata: userInfo
        )
    }
    
    private func handleSubscriptionRenewedPush(_ userInfo: [AnyHashable: Any]) async {
        await scheduleSubscriptionNotification(
            type: .renewed,
            title: "Subscription Renewed",
            body: "Your Streamyyy Pro subscription has been renewed successfully. Thank you!",
            metadata: userInfo
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        var options: UNNotificationPresentationOptions = [.banner]
        
        if preferences.soundEnabled {
            options.insert(.sound)
        }
        
        if preferences.badgeEnabled {
            options.insert(.badge)
        }
        
        completionHandler(options)
        
        // Track analytics
        if let type = notification.request.content.userInfo["type"] as? String {
            AnalyticsManager.shared.trackNotificationDisplayed(type: type)
        }
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Track analytics
        if let type = userInfo["type"] as? String {
            AnalyticsManager.shared.trackNotificationTapped(type: type, action: response.actionIdentifier)
        }
        
        Task { @MainActor in
            await handleNotificationResponse(response)
        }
        
        completionHandler()
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        guard let typeString = userInfo["type"] as? String,
              let notificationType = NotificationType(rawValue: typeString) else {
            return
        }
        
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // Handle default tap action
            await handleDefaultNotificationAction(notificationType, userInfo: userInfo)
            
        case NotificationAction.watch.rawValue:
            await handleWatchAction(userInfo)
            
        case NotificationAction.dismiss.rawValue:
            await handleDismissAction(userInfo)
            
        case NotificationAction.upgrade.rawValue:
            await handleUpgradeAction(userInfo)
            
        case NotificationAction.updatePayment.rawValue:
            await handleUpdatePaymentAction(userInfo)
            
        default:
            break
        }
    }
    
    private func handleDefaultNotificationAction(_ type: NotificationType, userInfo: [AnyHashable: Any]) async {
        switch type {
        case .streamLive:
            if let streamId = userInfo["stream_id"] as? String {
                NotificationCenter.default.post(
                    name: .openStream,
                    object: nil,
                    userInfo: ["streamId": streamId]
                )
            }
            
        case .subscription:
            NotificationCenter.default.post(
                name: .showSubscription,
                object: nil
            )
            
        case .engagement:
            NotificationCenter.default.post(
                name: .showMainApp,
                object: nil
            )
            
        case .systemUpdate:
            // Handle system update action
            break
        }
    }
    
    private func handleWatchAction(_ userInfo: [AnyHashable: Any]) async {
        if let streamId = userInfo["stream_id"] as? String {
            NotificationCenter.default.post(
                name: .openStream,
                object: nil,
                userInfo: ["streamId": streamId, "autoPlay": true]
            )
        }
    }
    
    private func handleDismissAction(_ userInfo: [AnyHashable: Any]) async {
        // Just dismiss, no action needed
    }
    
    private func handleUpgradeAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .showSubscription,
            object: nil,
            userInfo: ["showUpgrade": true]
        )
    }
    
    private func handleUpdatePaymentAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .showPaymentMethods,
            object: nil
        )
    }
}

// MARK: - Notification Categories and Actions
extension NotificationService {
    
    private func setupNotificationCategories() {
        let streamCategory = UNNotificationCategory(
            identifier: NotificationCategory.streamLive.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: NotificationAction.watch.rawValue,
                    title: "Watch",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: NotificationAction.dismiss.rawValue,
                    title: "Dismiss",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let subscriptionCategory = UNNotificationCategory(
            identifier: NotificationCategory.subscription.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: NotificationAction.upgrade.rawValue,
                    title: "Upgrade",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: NotificationAction.updatePayment.rawValue,
                    title: "Update Payment",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let engagementCategory = UNNotificationCategory(
            identifier: NotificationCategory.engagement.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let systemCategory = UNNotificationCategory(
            identifier: NotificationCategory.systemUpdate.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([
            streamCategory,
            subscriptionCategory,
            engagementCategory,
            systemCategory
        ])
    }
}

// MARK: - Notification Models
public enum NotificationType: String, CaseIterable {
    case streamLive = "stream_live"
    case subscription = "subscription"
    case engagement = "engagement"
    case systemUpdate = "system_update"
}

public enum NotificationCategory: String, CaseIterable {
    case streamLive = "STREAM_LIVE"
    case subscription = "SUBSCRIPTION"
    case engagement = "ENGAGEMENT"
    case systemUpdate = "SYSTEM_UPDATE"
}

public enum NotificationAction: String, CaseIterable {
    case watch = "WATCH"
    case dismiss = "DISMISS"
    case upgrade = "UPGRADE"
    case updatePayment = "UPDATE_PAYMENT"
}

public enum SubscriptionNotificationType: String, CaseIterable {
    case activated = "activated"
    case updated = "updated"
    case canceled = "canceled"
    case trialEnding = "trial_ending"
    case trialExpired = "trial_expired"
    case paymentFailed = "payment_failed"
    case renewed = "renewed"
    case refunded = "refunded"
}

public struct NotificationPreferences: Codable {
    public var streamNotifications: Bool = true
    public var subscriptionNotifications: Bool = true
    public var engagementNotifications: Bool = true
    public var systemNotifications: Bool = true
    
    public var soundEnabled: Bool = true
    public var badgeEnabled: Bool = true
    public var alertEnabled: Bool = true
    
    public var quietHoursEnabled: Bool = false
    public var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    public var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
    
    public var followedStreamersOnly: Bool = false
    public var minimumViewerCount: Int = 0
    
    public init() {}
}

// MARK: - Network Service
class NotificationNetworkService {
    static let shared = NotificationNetworkService()
    
    private let baseURL = Config.API.baseURL
    private let session = URLSession.shared
    
    private init() {}
    
    func updateDeviceToken(token: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/notifications/device-token") else {
            throw NotificationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "device_token": token,
            "platform": "ios",
            "user_id": getCurrentUserId() ?? "anonymous"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NotificationError.serverError
        }
    }
    
    func updateNotificationPreferences(_ preferences: NotificationPreferences) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/notifications/preferences") else {
            throw NotificationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(preferences)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NotificationError.serverError
        }
    }
    
    private func getCurrentUserId() -> String? {
        // TODO: Get actual user ID from authentication service
        return "user_123"
    }
}

// MARK: - Notification Error
enum NotificationError: Error {
    case invalidURL
    case serverError
    case notAuthorized
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let openStream = Notification.Name("openStream")
    static let showSubscription = Notification.Name("showSubscription")
    static let showMainApp = Notification.Name("showMainApp")
    static let showPaymentMethods = Notification.Name("showPaymentMethods")
    static let notificationPermissionChanged = Notification.Name("notificationPermissionChanged")
}

// MARK: - Analytics Extensions
extension AnalyticsManager {
    func trackNotificationPermissionGranted() {
        track(name: "notification_permission_granted")
    }
    
    func trackNotificationPermissionDenied() {
        track(name: "notification_permission_denied")
    }
    
    func trackNotificationPermissionError(_ error: Error) {
        track(name: "notification_permission_error", properties: [
            "error": error.localizedDescription
        ])
    }
    
    func trackDeviceTokenUpdated() {
        track(name: "device_token_updated")
    }
    
    func trackDeviceTokenError(_ error: Error) {
        track(name: "device_token_error", properties: [
            "error": error.localizedDescription
        ])
    }
    
    func trackNotificationScheduled(type: String) {
        track(name: "notification_scheduled", properties: [
            "type": type
        ])
    }
    
    func trackNotificationDisplayed(type: String) {
        track(name: "notification_displayed", properties: [
            "type": type
        ])
    }
    
    func trackNotificationTapped(type: String, action: String) {
        track(name: "notification_tapped", properties: [
            "type": type,
            "action": action
        ])
    }
    
    func trackPushNotificationReceived(type: String) {
        track(name: "push_notification_received", properties: [
            "type": type
        ])
    }
    
    func trackStreamNotificationReceived(streamId: String) {
        track(name: "stream_notification_received", properties: [
            "stream_id": streamId
        ])
    }
    
    func trackBadgeCountUpdated(count: Int) {
        track(name: "badge_count_updated", properties: [
            "count": count
        ])
    }
    
    func trackApplePaySuccess() {
        track(name: "apple_pay_success")
    }
    
    func trackApplePayFailed() {
        track(name: "apple_pay_failed")
    }
    
    func trackApplePayCanceled() {
        track(name: "apple_pay_canceled")
    }
    
    func trackPaymentSuccess() {
        track(name: "payment_success")
    }
    
    func trackPaymentCanceled() {
        track(name: "payment_canceled")
    }
    
    func trackPaymentFailed(_ error: Error) {
        track(name: "payment_failed", properties: [
            "error": error.localizedDescription
        ])
    }
    
    func trackSubscriptionAttempt(plan: SubscriptionPlan, interval: BillingInterval) {
        track(name: "subscription_attempt", properties: [
            "plan": plan.rawValue,
            "interval": interval.rawValue
        ])
    }
    
    func trackSubscriptionSuccess(plan: SubscriptionPlan, interval: BillingInterval) {
        track(name: "subscription_success", properties: [
            "plan": plan.rawValue,
            "interval": interval.rawValue
        ])
    }
    
    func trackSubscriptionFailure(plan: SubscriptionPlan, interval: BillingInterval, error: Error) {
        track(name: "subscription_failure", properties: [
            "plan": plan.rawValue,
            "interval": interval.rawValue,
            "error": error.localizedDescription
        ])
    }
    
    func trackSubscriptionUpgrade(from: SubscriptionPlan, to: SubscriptionPlan) {
        track(name: "subscription_upgrade", properties: [
            "from_plan": from.rawValue,
            "to_plan": to.rawValue
        ])
    }
    
    func trackSubscriptionUpgradeSuccess(from: SubscriptionPlan, to: SubscriptionPlan) {
        track(name: "subscription_upgrade_success", properties: [
            "from_plan": from.rawValue,
            "to_plan": to.rawValue
        ])
    }
    
    func trackSubscriptionUpgradeFailure(from: SubscriptionPlan, to: SubscriptionPlan, error: Error) {
        track(name: "subscription_upgrade_failure", properties: [
            "from_plan": from.rawValue,
            "to_plan": to.rawValue,
            "error": error.localizedDescription
        ])
    }
    
    func trackSubscriptionDowngrade(from: SubscriptionPlan, to: SubscriptionPlan) {
        track(name: "subscription_downgrade", properties: [
            "from_plan": from.rawValue,
            "to_plan": to.rawValue
        ])
    }
    
    func trackSubscriptionDowngradeSuccess(from: SubscriptionPlan, to: SubscriptionPlan) {
        track(name: "subscription_downgrade_success", properties: [
            "from_plan": from.rawValue,
            "to_plan": to.rawValue
        ])
    }
    
    func trackSubscriptionDowngradeFailure(from: SubscriptionPlan, to: SubscriptionPlan, error: Error) {
        track(name: "subscription_downgrade_failure", properties: [
            "from_plan": from.rawValue,
            "to_plan": to.rawValue,
            "error": error.localizedDescription
        ])
    }
    
    func trackSubscriptionCancellation(plan: SubscriptionPlan, immediately: Bool) {
        track(name: "subscription_cancellation", properties: [
            "plan": plan.rawValue,
            "immediately": immediately
        ])
    }
    
    func trackSubscriptionCancellationSuccess(plan: SubscriptionPlan, immediately: Bool) {
        track(name: "subscription_cancellation_success", properties: [
            "plan": plan.rawValue,
            "immediately": immediately
        ])
    }
    
    func trackSubscriptionCancellationFailure(plan: SubscriptionPlan, error: Error) {
        track(name: "subscription_cancellation_failure", properties: [
            "plan": plan.rawValue,
            "error": error.localizedDescription
        ])
    }
    
    func trackSubscriptionReactivation(plan: SubscriptionPlan) {
        track(name: "subscription_reactivation", properties: [
            "plan": plan.rawValue
        ])
    }
    
    func trackSubscriptionReactivationSuccess(plan: SubscriptionPlan) {
        track(name: "subscription_reactivation_success", properties: [
            "plan": plan.rawValue
        ])
    }
    
    func trackSubscriptionReactivationFailure(plan: SubscriptionPlan, error: Error) {
        track(name: "subscription_reactivation_failure", properties: [
            "plan": plan.rawValue,
            "error": error.localizedDescription
        ])
    }
    
    func trackSubscriptionError(_ error: Error) {
        track(name: "subscription_error", properties: [
            "error": error.localizedDescription
        ])
    }
}