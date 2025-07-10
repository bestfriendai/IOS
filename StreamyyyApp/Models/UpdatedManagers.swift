//
//  UpdatedManagers.swift
//  StreamyyyApp
//
//  Updated managers using comprehensive data models
//

import Foundation
import SwiftUI
import SwiftData
import ClerkSDK
import Combine

// MARK: - Enhanced Stream Manager
@MainActor
public class EnhancedStreamManager: ObservableObject {
    @Published public var streams: [Stream] = []
    @Published public var currentLayout: Layout?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var selectedLayoutType: LayoutType = .grid2x2
    @Published public var isRealTimeEnabled = false
    
    private let streamRepository = RepositoryFactory.shared.streamRepository()
    private let layoutRepository = GenericRepository<Layout>()
    private let streamObserver = StreamObserver()
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupObservers()
        loadStreams()
        setupDefaultLayout()
    }
    
    private func setupObservers() {
        streamObserver.$streams
            .sink { [weak self] streams in
                self?.streams = streams
            }
            .store(in: &cancellables)
        
        streamObserver.$liveStreams
            .sink { [weak self] liveStreams in
                self?.updateLiveStreamNotifications(liveStreams)
            }
            .store(in: &cancellables)
        
        streamObserver.$isLoading
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
    }
    
    private func loadStreams() {
        isLoading = true
        
        Task {
            let fetchedStreams = streamRepository.fetch()
            await MainActor.run {
                self.streams = fetchedStreams
                self.isLoading = false
            }
        }
    }
    
    private func setupDefaultLayout() {
        let defaultLayout = Layout(
            name: "Default Layout",
            type: selectedLayoutType,
            configuration: selectedLayoutType.defaultConfiguration
        )
        defaultLayout.setAsDefault()
        currentLayout = defaultLayout
    }
    
    private func updateLiveStreamNotifications(_ liveStreams: [Stream]) {
        // Handle live stream notifications
        for stream in liveStreams {
            if stream.isLive {
                NotificationCenter.default.post(
                    name: .init("StreamWentLive"),
                    object: stream
                )
            }
        }
    }
    
    // MARK: - Stream Management
    public func addStream(url: String, user: User? = nil) async throws {
        guard !url.isEmpty else {
            throw StreamError.invalidURL
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let platform = Platform.detect(from: url)
            guard platform.isValidURL(url) else {
                throw StreamError.invalidURL
            }
            
            let stream = Stream(
                url: url,
                platform: platform,
                title: extractStreamTitle(from: url),
                owner: user
            )
            
            // Fetch metadata from platform
            try await stream.fetchMetadataFromPlatform()
            
            // Save to repository
            streamRepository.insert(stream)
            
            // Add to current layout if possible
            if let currentLayout = currentLayout, currentLayout.canAddMoreStreams {
                let position = calculateNextPosition()
                currentLayout.addStream(position: position, streamId: stream.id)
            }
            
            await MainActor.run {
                self.streams.append(stream)
                self.isLoading = false
            }
            
            // Track analytics
            stream.trackEvent(.streamStart)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    public func removeStream(_ stream: Stream) {
        streamRepository.delete(stream)
        streams.removeAll { $0.id == stream.id }
        
        // Remove from current layout
        currentLayout?.removeStream(streamId: stream.id)
        
        // Track analytics
        stream.trackEvent(.streamEnd)
    }
    
    public func clearAllStreams() {
        for stream in streams {
            streamRepository.delete(stream)
        }
        streams.removeAll()
        currentLayout?.streams.removeAll()
    }
    
    public func updateStreamPosition(_ stream: Stream, to position: StreamPosition) {
        stream.updatePosition(position)
        currentLayout?.updateStreamPosition(streamId: stream.id, position: position)
        streamRepository.update(stream)
    }
    
    public func toggleStreamMute(_ stream: Stream) {
        stream.toggleMute()
        streamRepository.update(stream)
    }
    
    public func updateStreamQuality(_ stream: Stream, quality: StreamQuality) {
        stream.updateQuality(quality)
        streamRepository.update(stream)
    }
    
    // MARK: - Layout Management
    public func updateLayout(_ newLayout: Layout) {
        currentLayout = newLayout
        selectedLayoutType = newLayout.type
        
        // Update stream positions based on layout
        updateStreamPositionsForLayout(newLayout)
        
        // Save layout
        layoutRepository.insert(newLayout)
        newLayout.recordUsage()
    }
    
    public func changeLayoutType(_ type: LayoutType) {
        selectedLayoutType = type
        
        let newLayout = Layout(
            name: "\(type.displayName) Layout",
            type: type,
            configuration: type.defaultConfiguration
        )
        
        updateLayout(newLayout)
    }
    
    private func updateStreamPositionsForLayout(_ layout: Layout) {
        let config = layout.configuration
        let availableSpace = CGSize(width: 1000, height: 800) // Example screen size
        
        for (index, stream) in streams.enumerated() {
            let position = calculatePositionForStream(
                at: index,
                layoutType: layout.type,
                availableSpace: availableSpace,
                config: config
            )
            
            stream.updatePosition(position)
        }
    }
    
    private func calculatePositionForStream(
        at index: Int,
        layoutType: LayoutType,
        availableSpace: CGSize,
        config: LayoutConfiguration
    ) -> StreamPosition {
        
        switch layoutType {
        case .grid2x2:
            let cols = 2
            let rows = 2
            let col = index % cols
            let row = index / cols
            
            let width = (availableSpace.width - config.spacing * Double(cols - 1)) / Double(cols)
            let height = (availableSpace.height - config.spacing * Double(rows - 1)) / Double(rows)
            
            return StreamPosition(
                x: Double(col) * (width + config.spacing),
                y: Double(row) * (height + config.spacing),
                width: width,
                height: height,
                zIndex: index
            )
            
        case .grid3x3:
            let cols = 3
            let rows = 3
            let col = index % cols
            let row = index / cols
            
            let width = (availableSpace.width - config.spacing * Double(cols - 1)) / Double(cols)
            let height = (availableSpace.height - config.spacing * Double(rows - 1)) / Double(rows)
            
            return StreamPosition(
                x: Double(col) * (width + config.spacing),
                y: Double(row) * (height + config.spacing),
                width: width,
                height: height,
                zIndex: index
            )
            
        case .stack:
            let height = (availableSpace.height - config.spacing * Double(streams.count - 1)) / Double(streams.count)
            
            return StreamPosition(
                x: 0,
                y: Double(index) * (height + config.spacing),
                width: availableSpace.width,
                height: height,
                zIndex: index
            )
            
        case .carousel:
            let width = min(config.maxStreamSize.width, availableSpace.width * 0.7)
            let height = min(config.maxStreamSize.height, availableSpace.height * 0.8)
            
            return StreamPosition(
                x: Double(index) * (width + config.spacing),
                y: (availableSpace.height - height) / 2,
                width: width,
                height: height,
                zIndex: index
            )
            
        case .focus:
            if index == 0 {
                // Main stream
                return StreamPosition(
                    x: 0,
                    y: 0,
                    width: availableSpace.width * 0.75,
                    height: availableSpace.height,
                    zIndex: 0
                )
            } else {
                // Thumbnail streams
                let thumbWidth = availableSpace.width * 0.25
                let thumbHeight = thumbWidth * 9/16
                
                return StreamPosition(
                    x: availableSpace.width * 0.75,
                    y: Double(index - 1) * (thumbHeight + config.spacing),
                    width: thumbWidth,
                    height: thumbHeight,
                    zIndex: index
                )
            }
            
        default:
            return StreamPosition(
                x: 0,
                y: 0,
                width: availableSpace.width,
                height: availableSpace.height,
                zIndex: index
            )
        }
    }
    
    private func calculateNextPosition() -> StreamPosition {
        let index = streams.count
        let availableSpace = CGSize(width: 1000, height: 800)
        
        return calculatePositionForStream(
            at: index,
            layoutType: selectedLayoutType,
            availableSpace: availableSpace,
            config: currentLayout?.configuration ?? LayoutConfiguration()
        )
    }
    
    // MARK: - Helper Methods
    private func extractStreamTitle(from url: String) -> String {
        let platform = Platform.detect(from: url)
        if let identifier = platform.extractStreamIdentifier(from: url) {
            return "\(platform.displayName) - \(identifier)"
        }
        return "\(platform.displayName) Stream"
    }
    
    // MARK: - Real-time Features
    public func enableRealTimeSync() {
        isRealTimeEnabled = true
        streamObserver.startRealTimeSync()
    }
    
    public func disableRealTimeSync() {
        isRealTimeEnabled = false
        streamObserver.stopRealTimeSync()
    }
    
    public func refreshStreams() {
        streamObserver.refresh()
    }
    
    public func checkStreamHealth() {
        streamObserver.refreshHealthStatus()
    }
    
    // MARK: - Analytics
    public func getStreamAnalytics() -> [String: Any] {
        return [
            "totalStreams": streams.count,
            "liveStreams": streams.filter { $0.isLive }.count,
            "platformDistribution": Dictionary(grouping: streams) { $0.platform.rawValue }
                .mapValues { $0.count },
            "averageViewerCount": streams.map { $0.viewerCount }.reduce(0, +) / max(streams.count, 1),
            "healthyStreams": streams.filter { $0.isHealthy }.count,
            "currentLayout": currentLayout?.type.rawValue ?? "none"
        ]
    }
}

// MARK: - Enhanced User Manager
@MainActor
public class EnhancedUserManager: ObservableObject {
    @Published public var currentUser: User?
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var authenticationState: AuthenticationState = .unauthenticated
    
    public enum AuthenticationState {
        case unauthenticated
        case authenticating
        case authenticated
        case error(String)
    }
    
    private let userRepository = RepositoryFactory.shared.userRepository()
    private let userObserver = UserObserver()
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupObservers()
        checkAuthStatus()
    }
    
    private func setupObservers() {
        userObserver.$users
            .sink { [weak self] users in
                self?.handleUsersUpdate(users)
            }
            .store(in: &cancellables)
        
        // Listen to Clerk authentication changes
        NotificationCenter.default.publisher(for: .init("ClerkAuthenticationChanged"))
            .sink { [weak self] _ in
                self?.handleClerkAuthChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleUsersUpdate(_ users: [User]) {
        if let clerkUser = Clerk.shared.user,
           let user = users.first(where: { $0.clerkId == clerkUser.id }) {
            currentUser = user
            isAuthenticated = true
            authenticationState = .authenticated
        }
    }
    
    private func handleClerkAuthChange() {
        Task {
            await checkAuthStatus()
        }
    }
    
    private func checkAuthStatus() async {
        isLoading = true
        authenticationState = .authenticating
        
        do {
            if let clerkUser = Clerk.shared.user {
                // User is authenticated with Clerk
                let user = try await syncUserWithClerk(clerkUser)
                
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.authenticationState = .authenticated
                    self.isLoading = false
                }
                
                // Track analytics
                user.trackEvent(.loginSuccess)
                
            } else {
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.authenticationState = .unauthenticated
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.authenticationState = .error(error.localizedDescription)
                self.isLoading = false
            }
        }
    }
    
    private func syncUserWithClerk(_ clerkUser: ClerkSDK.User) async throws -> User {
        // Check if user exists in our database
        if let existingUser = userRepository.fetchByClerkId(clerkUser.id) {
            existingUser.updateFromClerk(clerkUser)
            existingUser.updateLastActive()
            userRepository.update(existingUser)
            return existingUser
        } else {
            // Create new user
            let newUser = User(
                clerkId: clerkUser.id,
                email: clerkUser.primaryEmailAddress?.emailAddress ?? "",
                firstName: clerkUser.firstName,
                lastName: clerkUser.lastName,
                profileImageURL: clerkUser.imageURL
            )
            
            newUser.updateFromClerk(clerkUser)
            userRepository.insert(newUser)
            
            // Track analytics
            newUser.trackEvent(.profileCreated)
            
            return newUser
        }
    }
    
    // MARK: - Authentication Methods
    public func signIn(email: String, password: String) async throws {
        isLoading = true
        authenticationState = .authenticating
        errorMessage = nil
        
        do {
            try await Clerk.shared.client.signIn.create(
                strategy: .password(password: password),
                identifier: email
            )
            
            await checkAuthStatus()
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.authenticationState = .error(error.localizedDescription)
                self.isLoading = false
            }
            
            // Track failed login
            if let user = currentUser {
                user.trackEvent(.loginFailed)
            }
            
            throw error
        }
    }
    
    public func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        isLoading = true
        authenticationState = .authenticating
        errorMessage = nil
        
        do {
            try await Clerk.shared.client.signUp.create(
                strategy: .password(password: password),
                identifier: email,
                firstName: firstName,
                lastName: lastName
            )
            
            await checkAuthStatus()
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.authenticationState = .error(error.localizedDescription)
                self.isLoading = false
            }
            throw error
        }
    }
    
    public func signOut() async {
        isLoading = true
        
        do {
            try await Clerk.shared.signOut()
            
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.authenticationState = .unauthenticated
                self.isLoading = false
            }
            
            // Track logout
            if let user = currentUser {
                user.trackEvent(.logoutSuccess)
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Profile Management
    public func updateProfile(firstName: String?, lastName: String?, username: String?) async throws {
        guard let currentUser = currentUser else {
            throw UserError.accountNotVerified
        }
        
        isLoading = true
        
        do {
            // Update locally
            currentUser.firstName = firstName
            currentUser.lastName = lastName
            currentUser.username = username
            currentUser.updatedAt = Date()
            
            // Update in Clerk
            try await currentUser.updateClerkProfile()
            
            // Update in repository
            userRepository.update(currentUser)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            // Track analytics
            currentUser.trackEvent(.profileUpdated)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    public func updateUserPreferences(_ preferences: UserPreferences) async throws {
        guard let currentUser = currentUser else {
            throw UserError.accountNotVerified
        }
        
        currentUser.updatePreferences(preferences)
        userRepository.update(currentUser)
        
        // Track analytics
        currentUser.trackEvent(.settingsChanged)
    }
    
    public func deleteAccount() async throws {
        guard let currentUser = currentUser else {
            throw UserError.accountNotVerified
        }
        
        isLoading = true
        
        do {
            // Delete from Clerk
            try await Clerk.shared.user?.delete()
            
            // Soft delete from our database
            currentUser.isActive = false
            currentUser.updatedAt = Date()
            userRepository.update(currentUser)
            
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.authenticationState = .unauthenticated
                self.isLoading = false
            }
            
            // Track analytics
            currentUser.trackEvent(.accountDeactivated)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Subscription Management
    public func checkSubscriptionStatus() async {
        guard let currentUser = currentUser else { return }
        
        let subscriptionRepository = RepositoryFactory.shared.subscriptionRepository()
        let userSubscriptions = subscriptionRepository.fetchByUser(currentUser)
        
        if let activeSubscription = userSubscriptions.first(where: { $0.isActive }) {
            currentUser.subscriptionStatus = activeSubscription.status == .active ? .premium : .free
            currentUser.subscriptionId = activeSubscription.id
        } else {
            currentUser.subscriptionStatus = .free
            currentUser.subscriptionId = nil
        }
        
        userRepository.update(currentUser)
    }
    
    // MARK: - Analytics
    public func getUserAnalytics() -> [String: Any] {
        guard let user = currentUser else { return [:] }
        
        return [
            "userId": user.id,
            "subscriptionStatus": user.subscriptionStatus.rawValue,
            "accountAge": user.accountAge,
            "streamCount": user.streams.count,
            "favoriteCount": user.favorites.count,
            "isEmailVerified": user.isEmailVerified,
            "lastActive": user.lastActiveAt.timeIntervalSince1970
        ]
    }
}

// MARK: - Enhanced Subscription Manager
@MainActor
public class EnhancedSubscriptionManager: ObservableObject {
    @Published public var currentSubscription: Subscription?
    @Published public var isSubscribed = false
    @Published public var subscriptionType: SubscriptionPlan = .free
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var paymentMethods: [PaymentMethod] = []
    
    public struct PaymentMethod {
        public let id: String
        public let type: String
        public let last4: String
        public let expiryMonth: Int
        public let expiryYear: Int
        public let isDefault: Bool
    }
    
    private let subscriptionRepository = RepositoryFactory.shared.subscriptionRepository()
    private let subscriptionObserver = SubscriptionObserver()
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupObservers()
    }
    
    private func setupObservers() {
        subscriptionObserver.$activeSubscriptions
            .sink { [weak self] subscriptions in
                self?.handleSubscriptionUpdate(subscriptions)
            }
            .store(in: &cancellables)
    }
    
    private func handleSubscriptionUpdate(_ subscriptions: [Subscription]) {
        if let userSubscription = subscriptions.first(where: { $0.user?.id == EnhancedUserManager().currentUser?.id }) {
            currentSubscription = userSubscription
            isSubscribed = userSubscription.isActive
            subscriptionType = userSubscription.plan
        } else {
            currentSubscription = nil
            isSubscribed = false
            subscriptionType = .free
        }
    }
    
    // MARK: - Subscription Management
    public func subscribe(to plan: SubscriptionPlan, billingInterval: BillingInterval) async throws {
        guard let currentUser = EnhancedUserManager().currentUser else {
            throw SubscriptionError.invalidPlan
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create subscription
            let subscription = Subscription(
                plan: plan,
                billingInterval: billingInterval,
                user: currentUser
            )
            
            // Process payment with Stripe
            let paymentSuccess = try await processPayment(for: subscription)
            
            if paymentSuccess {
                // Save subscription
                subscriptionRepository.insert(subscription)
                
                // Update user subscription status
                currentUser.subscriptionStatus = plan == .free ? .free : .premium
                currentUser.subscriptionId = subscription.id
                
                await MainActor.run {
                    self.currentSubscription = subscription
                    self.isSubscribed = true
                    self.subscriptionType = plan
                    self.isLoading = false
                }
                
                // Track analytics
                currentUser.trackEvent(.subscriptionUpgraded)
                
            } else {
                throw SubscriptionError.paymentFailed
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    public func cancelSubscription() async throws {
        guard let subscription = currentSubscription else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        isLoading = true
        
        do {
            // Cancel with Stripe
            try await cancelStripeSubscription(subscription.stripeSubscriptionId)
            
            // Update subscription
            subscription.scheduleCancel()
            subscriptionRepository.update(subscription)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            // Track analytics
            subscription.user?.trackEvent(.subscriptionCanceled)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    public func updateSubscription(to plan: SubscriptionPlan) async throws {
        guard let subscription = currentSubscription else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        isLoading = true
        
        do {
            // Update with Stripe
            try await updateStripeSubscription(subscription.stripeSubscriptionId, to: plan)
            
            // Update local subscription
            subscription.plan = plan
            subscription.amount = plan.price(for: subscription.billingInterval)
            subscription.updatedAt = Date()
            subscriptionRepository.update(subscription)
            
            await MainActor.run {
                self.subscriptionType = plan
                self.isLoading = false
            }
            
            // Track analytics
            let event: UserAnalyticsEvent = plan.maxStreams > subscription.plan.maxStreams ? .subscriptionUpgraded : .subscriptionDowngraded
            subscription.user?.trackEvent(event)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Payment Processing
    private func processPayment(for subscription: Subscription) async throws -> Bool {
        // Integrate with Stripe Payment Processing
        // This is a placeholder implementation
        
        // Simulate payment processing
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Record payment
        subscription.recordPayment(amount: subscription.amount)
        
        return true
    }
    
    private func cancelStripeSubscription(_ subscriptionId: String?) async throws {
        guard let subscriptionId = subscriptionId else { return }
        
        // Cancel Stripe subscription
        // This is a placeholder implementation
        print("Canceling Stripe subscription: \(subscriptionId)")
    }
    
    private func updateStripeSubscription(_ subscriptionId: String?, to plan: SubscriptionPlan) async throws {
        guard let subscriptionId = subscriptionId else { return }
        
        // Update Stripe subscription
        // This is a placeholder implementation
        print("Updating Stripe subscription: \(subscriptionId) to \(plan.rawValue)")
    }
    
    // MARK: - Payment Methods
    public func loadPaymentMethods() async throws {
        guard let currentUser = EnhancedUserManager().currentUser,
              let stripeCustomerId = currentUser.stripeCustomerId else {
            return
        }
        
        isLoading = true
        
        do {
            // Load payment methods from Stripe
            let methods = try await fetchStripePaymentMethods(stripeCustomerId)
            
            await MainActor.run {
                self.paymentMethods = methods
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    private func fetchStripePaymentMethods(_ customerId: String) async throws -> [PaymentMethod] {
        // Fetch payment methods from Stripe
        // This is a placeholder implementation
        return [
            PaymentMethod(
                id: "pm_1234",
                type: "card",
                last4: "4242",
                expiryMonth: 12,
                expiryYear: 2025,
                isDefault: true
            )
        ]
    }
    
    // MARK: - Helper Methods
    public func getSubscriptionFeatures() -> [SubscriptionFeature] {
        return subscriptionType.features
    }
    
    public func hasFeature(_ feature: SubscriptionFeature) -> Bool {
        return subscriptionType.features.contains(feature)
    }
    
    public func daysUntilRenewal() -> Int {
        return currentSubscription?.daysUntilRenewal ?? 0
    }
    
    public func getUsageStats() -> SubscriptionUsage {
        return currentSubscription?.usageStats ?? SubscriptionUsage()
    }
}

// MARK: - Enhanced Notification Manager
@MainActor
public class EnhancedNotificationManager: ObservableObject {
    @Published public var notifications: [UserNotification] = []
    @Published public var unreadCount: Int = 0
    @Published public var settings: NotificationSettings = NotificationSettings()
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var permissionStatus: PermissionStatus = .notDetermined
    
    public enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case provisional
    }
    
    private let notificationRepository = RepositoryFactory.shared.notificationRepository()
    private let notificationObserver = NotificationObserver()
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupObservers()
        checkPermissionStatus()
    }
    
    private func setupObservers() {
        notificationObserver.$notifications
            .sink { [weak self] notifications in
                self?.notifications = notifications
            }
            .store(in: &cancellables)
        
        notificationObserver.$unreadCount
            .sink { [weak self] count in
                self?.unreadCount = count
            }
            .store(in: &cancellables)
    }
    
    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    self.permissionStatus = .granted
                case .denied:
                    self.permissionStatus = .denied
                case .provisional:
                    self.permissionStatus = .provisional
                case .notDetermined:
                    self.permissionStatus = .notDetermined
                case .ephemeral:
                    self.permissionStatus = .granted
                @unknown default:
                    self.permissionStatus = .notDetermined
                }
            }
        }
    }
    
    // MARK: - Permission Management
    public func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            await MainActor.run {
                self.permissionStatus = granted ? .granted : .denied
            }
            
            return granted
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.permissionStatus = .denied
            }
            return false
        }
    }
    
    // MARK: - Notification Management
    public func scheduleNotification(_ notification: UserNotification) async {
        guard permissionStatus == .granted else { return }
        guard settings.shouldShowNotification(notification) else { return }
        
        do {
            let content = notification.toPushNotificationContent()
            let trigger = notification.createPushNotificationTrigger()
            
            let request = UNNotificationRequest(
                identifier: notification.id,
                content: content,
                trigger: trigger
            )
            
            try await UNUserNotificationCenter.current().add(request)
            
            notification.markAsDelivered()
            notificationRepository.insert(notification)
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func cancelNotification(_ notification: UserNotification) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notification.id]
        )
        
        notification.archive()
        notificationRepository.update(notification)
    }
    
    public func markAsRead(_ notification: UserNotification) {
        notification.markAsRead()
        notificationRepository.update(notification)
    }
    
    public func markAllAsRead() {
        let unreadNotifications = notifications.filter { !$0.isRead }
        unreadNotifications.forEach { $0.markAsRead() }
        
        unreadNotifications.forEach { notificationRepository.update($0) }
    }
    
    public func deleteNotification(_ notification: UserNotification) {
        notificationRepository.delete(notification)
        cancelNotification(notification)
    }
    
    // MARK: - Settings Management
    public func updateSettings(_ newSettings: NotificationSettings) {
        settings = newSettings
        
        // Save settings to user preferences
        if let currentUser = EnhancedUserManager().currentUser {
            currentUser.setMetadata(key: "notification_settings", value: encodeSettings(newSettings))
        }
    }
    
    private func encodeSettings(_ settings: NotificationSettings) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(settings) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func decodeSettings(_ string: String) -> NotificationSettings {
        let decoder = JSONDecoder()
        guard let data = string.data(using: .utf8),
              let settings = try? decoder.decode(NotificationSettings.self, from: data) else {
            return NotificationSettings()
        }
        return settings
    }
    
    // MARK: - Analytics
    public func getNotificationAnalytics() -> [String: Any] {
        let typeDistribution = Dictionary(grouping: notifications) { $0.type.rawValue }
            .mapValues { $0.count }
        
        let priorityDistribution = Dictionary(grouping: notifications) { $0.priority.rawValue }
            .mapValues { $0.count }
        
        return [
            "totalNotifications": notifications.count,
            "unreadCount": unreadCount,
            "typeDistribution": typeDistribution,
            "priorityDistribution": priorityDistribution,
            "readRate": Double(notifications.filter { $0.isRead }.count) / Double(max(notifications.count, 1)),
            "permissionStatus": permissionStatus.rawValue
        ]
    }
}

// MARK: - Permission Status Extension
extension EnhancedNotificationManager.PermissionStatus {
    var rawValue: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .granted: return "granted"
        case .denied: return "denied"
        case .provisional: return "provisional"
        }
    }
}