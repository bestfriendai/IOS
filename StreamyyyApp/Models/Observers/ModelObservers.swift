//
//  ModelObservers.swift
//  StreamyyyApp
//
//  Real-time model observers for reactive UI updates
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Model Observer Protocol
public protocol ModelObserver: AnyObject {
    associatedtype Model: PersistentModel
    
    func modelDidChange(_ model: Model)
    func modelDidCreate(_ model: Model)
    func modelDidUpdate(_ model: Model)
    func modelDidDelete(_ model: Model)
}

// MARK: - Observable Model Manager
@MainActor
public class ObservableModelManager: ObservableObject {
    public static let shared = ObservableModelManager()
    
    @Published public private(set) var isObserving = false
    @Published public private(set) var observerCount = 0
    @Published public private(set) var lastUpdate: Date?
    
    private var cancellables = Set<AnyCancellable>()
    private var observers: [String: AnyModelObserver] = [:]
    private var modelChangeSubjects: [String: PassthroughSubject<ModelChangeEvent, Never>] = [:]
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen to model container changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.handleModelContextChange()
            }
            .store(in: &cancellables)
        
        // Listen to network changes for real-time updates
        NotificationCenter.default.publisher(for: .init("NetworkConnectivityChanged"))
            .sink { [weak self] _ in
                self?.handleNetworkChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleModelContextChange() {
        lastUpdate = Date()
        
        // Notify all observers
        observers.values.forEach { observer in
            observer.notifyChange()
        }
    }
    
    private func handleNetworkChange() {
        // Handle network connectivity changes
        // This would trigger real-time sync with backend
        print("Network connectivity changed - updating real-time sync")
    }
    
    // MARK: - Observer Management
    public func addObserver<T: PersistentModel>(_ observer: AnyModelObserver, for modelType: T.Type) {
        let key = String(describing: modelType)
        observers[key] = observer
        observerCount = observers.count
        
        if !isObserving {
            startObserving()
        }
    }
    
    public func removeObserver<T: PersistentModel>(for modelType: T.Type) {
        let key = String(describing: modelType)
        observers.removeValue(forKey: key)
        observerCount = observers.count
        
        if observers.isEmpty {
            stopObserving()
        }
    }
    
    public func removeAllObservers() {
        observers.removeAll()
        modelChangeSubjects.removeAll()
        observerCount = 0
        stopObserving()
    }
    
    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        print("✅ Model observing started")
    }
    
    private func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        print("🛑 Model observing stopped")
    }
    
    // MARK: - Change Notification
    public func notifyChange<T: PersistentModel>(_ event: ModelChangeEvent, for model: T) {
        let key = String(describing: T.self)
        modelChangeSubjects[key]?.send(event)
        
        // Update last update timestamp
        lastUpdate = Date()
    }
    
    // MARK: - Publisher Access
    public func publisher<T: PersistentModel>(for modelType: T.Type) -> AnyPublisher<ModelChangeEvent, Never> {
        let key = String(describing: modelType)
        
        if modelChangeSubjects[key] == nil {
            modelChangeSubjects[key] = PassthroughSubject<ModelChangeEvent, Never>()
        }
        
        return modelChangeSubjects[key]!.eraseToAnyPublisher()
    }
}

// MARK: - Model Change Event
public struct ModelChangeEvent {
    public let type: ChangeType
    public let modelId: String
    public let modelType: String
    public let timestamp: Date
    public let metadata: [String: Any]
    
    public enum ChangeType {
        case created
        case updated
        case deleted
        case archived
        case restored
        case synchronized
    }
    
    public init(type: ChangeType, modelId: String, modelType: String, metadata: [String: Any] = [:]) {
        self.type = type
        self.modelId = modelId
        self.modelType = modelType
        self.timestamp = Date()
        self.metadata = metadata
    }
}

// MARK: - Type-Erased Model Observer
public class AnyModelObserver {
    private let _notifyChange: () -> Void
    
    public init<T: ModelObserver>(_ observer: T) {
        _notifyChange = { [weak observer] in
            // This would need to be implemented based on specific observer type
            print("Observer notified: \(T.self)")
        }
    }
    
    public func notifyChange() {
        _notifyChange()
    }
}

// MARK: - User Observer
@MainActor
public class UserObserver: ObservableObject, ModelObserver {
    public typealias Model = User
    
    @Published public var users: [User] = []
    @Published public var activeUsers: [User] = []
    @Published public var premiumUsers: [User] = []
    @Published public var recentlyJoined: [User] = []
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let repository = RepositoryFactory.shared.userRepository()
    
    public init() {
        setupObserver()
        loadUsers()
    }
    
    private func setupObserver() {
        ObservableModelManager.shared.addObserver(AnyModelObserver(self), for: User.self)
        
        // Listen to specific user changes
        ObservableModelManager.shared.publisher(for: User.self)
            .sink { [weak self] event in
                self?.handleUserChange(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleUserChange(_ event: ModelChangeEvent) {
        switch event.type {
        case .created, .updated, .restored:
            loadUsers()
        case .deleted, .archived:
            removeUser(with: event.modelId)
        case .synchronized:
            syncUser(with: event.modelId)
        }
    }
    
    private func loadUsers() {
        isLoading = true
        
        DispatchQueue.main.async { [weak self] in
            self?.users = self?.repository.fetch() ?? []
            self?.updateDerivedCollections()
            self?.isLoading = false
        }
    }
    
    private func updateDerivedCollections() {
        activeUsers = users.filter { $0.isActive && !$0.isBanned }
        premiumUsers = users.filter { $0.isPremium }
        recentlyJoined = users.filter { $0.accountAge < 86400 * 7 } // 7 days
    }
    
    private func removeUser(with id: String) {
        users.removeAll { $0.id == id }
        updateDerivedCollections()
    }
    
    private func syncUser(with id: String) {
        // Sync specific user with backend
        Task {
            // Implementation for syncing user
            print("Syncing user: \(id)")
        }
    }
    
    // MARK: - ModelObserver Implementation
    public func modelDidChange(_ model: User) {
        if let index = users.firstIndex(where: { $0.id == model.id }) {
            users[index] = model
        } else {
            users.append(model)
        }
        updateDerivedCollections()
    }
    
    public func modelDidCreate(_ model: User) {
        users.append(model)
        updateDerivedCollections()
        
        // Send analytics event
        model.trackEvent(.profileCreated)
    }
    
    public func modelDidUpdate(_ model: User) {
        if let index = users.firstIndex(where: { $0.id == model.id }) {
            users[index] = model
        }
        updateDerivedCollections()
        
        // Send analytics event
        model.trackEvent(.profileUpdated)
    }
    
    public func modelDidDelete(_ model: User) {
        users.removeAll { $0.id == model.id }
        updateDerivedCollections()
        
        // Send analytics event
        model.trackEvent(.accountDeactivated)
    }
    
    // MARK: - Public Methods
    public func refresh() {
        loadUsers()
    }
    
    public func startRealTimeSync() {
        // Start real-time synchronization with backend
        print("Starting real-time user sync")
    }
    
    public func stopRealTimeSync() {
        // Stop real-time synchronization
        print("Stopping real-time user sync")
    }
    
    deinit {
        ObservableModelManager.shared.removeObserver(for: User.self)
    }
}

// MARK: - Stream Observer
@MainActor
public class StreamObserver: ObservableObject, ModelObserver {
    public typealias Model = Stream
    
    @Published public var streams: [Stream] = []
    @Published public var liveStreams: [Stream] = []
    @Published public var offlineStreams: [Stream] = []
    @Published public var healthyStreams: [Stream] = []
    @Published public var streamsByPlatform: [Platform: [Stream]] = [:]
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let repository = RepositoryFactory.shared.streamRepository()
    private var healthCheckTimer: Timer?
    
    public init() {
        setupObserver()
        loadStreams()
        startHealthMonitoring()
    }
    
    private func setupObserver() {
        ObservableModelManager.shared.addObserver(AnyModelObserver(self), for: Stream.self)
        
        ObservableModelManager.shared.publisher(for: Stream.self)
            .sink { [weak self] event in
                self?.handleStreamChange(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleStreamChange(_ event: ModelChangeEvent) {
        switch event.type {
        case .created, .updated, .restored:
            loadStreams()
        case .deleted, .archived:
            removeStream(with: event.modelId)
        case .synchronized:
            syncStream(with: event.modelId)
        }
    }
    
    private func loadStreams() {
        isLoading = true
        
        DispatchQueue.main.async { [weak self] in
            self?.streams = self?.repository.fetch() ?? []
            self?.updateDerivedCollections()
            self?.isLoading = false
        }
    }
    
    private func updateDerivedCollections() {
        liveStreams = streams.filter { $0.isLive }
        offlineStreams = streams.filter { !$0.isLive }
        healthyStreams = streams.filter { $0.isHealthy }
        streamsByPlatform = Dictionary(grouping: streams) { $0.platform }
    }
    
    private func removeStream(with id: String) {
        streams.removeAll { $0.id == id }
        updateDerivedCollections()
    }
    
    private func syncStream(with id: String) {
        // Sync specific stream with platform API
        Task {
            if let stream = streams.first(where: { $0.id == id }) {
                try await stream.fetchMetadataFromPlatform()
            }
        }
    }
    
    private func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }
    
    private func performHealthCheck() {
        Task {
            for stream in streams {
                await stream.checkHealth()
            }
            
            await MainActor.run {
                self.updateDerivedCollections()
            }
        }
    }
    
    // MARK: - ModelObserver Implementation
    public func modelDidChange(_ model: Stream) {
        if let index = streams.firstIndex(where: { $0.id == model.id }) {
            streams[index] = model
        } else {
            streams.append(model)
        }
        updateDerivedCollections()
    }
    
    public func modelDidCreate(_ model: Stream) {
        streams.append(model)
        updateDerivedCollections()
        
        // Track analytics
        model.trackEvent(.streamStart)
        
        // Send notification if stream goes live
        if model.isLive {
            sendLiveStreamNotification(for: model)
        }
    }
    
    public func modelDidUpdate(_ model: Stream) {
        if let index = streams.firstIndex(where: { $0.id == model.id }) {
            let oldStream = streams[index]
            streams[index] = model
            
            // Check if stream went live
            if !oldStream.isLive && model.isLive {
                sendLiveStreamNotification(for: model)
                model.trackEvent(.streamStart)
            } else if oldStream.isLive && !model.isLive {
                model.trackEvent(.streamEnd)
            }
        }
        updateDerivedCollections()
    }
    
    public func modelDidDelete(_ model: Stream) {
        streams.removeAll { $0.id == model.id }
        updateDerivedCollections()
        
        // Track analytics
        model.trackEvent(.streamEnd)
    }
    
    private func sendLiveStreamNotification(for stream: Stream) {
        guard let owner = stream.owner else { return }
        
        // Create notification for users who favorited this stream
        let favoriteRepository = RepositoryFactory.shared.favoriteRepository()
        let favorites = favoriteRepository.fetchByStream(stream)
        
        for favorite in favorites {
            guard let user = favorite.user, favorite.isNotificationEnabled else { continue }
            
            let notification = UserNotification.createStreamLiveNotification(
                for: user,
                streamTitle: stream.title,
                streamerName: stream.streamerName ?? "Unknown",
                streamId: stream.id
            )
            
            Task {
                await NotificationManager().scheduleNotification(notification)
            }
        }
    }
    
    // MARK: - Public Methods
    public func refresh() {
        loadStreams()
    }
    
    public func refreshHealthStatus() {
        performHealthCheck()
    }
    
    public func startRealTimeSync() {
        print("Starting real-time stream sync")
    }
    
    public func stopRealTimeSync() {
        print("Stopping real-time stream sync")
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    deinit {
        ObservableModelManager.shared.removeObserver(for: Stream.self)
        healthCheckTimer?.invalidate()
    }
}

// MARK: - Favorite Observer
@MainActor
public class FavoriteObserver: ObservableObject, ModelObserver {
    public typealias Model = Favorite
    
    @Published public var favorites: [Favorite] = []
    @Published public var favoritesByUser: [String: [Favorite]] = [:]
    @Published public var recentlyAdded: [Favorite] = []
    @Published public var topRated: [Favorite] = []
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let repository = RepositoryFactory.shared.favoriteRepository()
    
    public init() {
        setupObserver()
        loadFavorites()
    }
    
    private func setupObserver() {
        ObservableModelManager.shared.addObserver(AnyModelObserver(self), for: Favorite.self)
        
        ObservableModelManager.shared.publisher(for: Favorite.self)
            .sink { [weak self] event in
                self?.handleFavoriteChange(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleFavoriteChange(_ event: ModelChangeEvent) {
        switch event.type {
        case .created, .updated, .restored:
            loadFavorites()
        case .deleted, .archived:
            removeFavorite(with: event.modelId)
        case .synchronized:
            syncFavorite(with: event.modelId)
        }
    }
    
    private func loadFavorites() {
        isLoading = true
        
        DispatchQueue.main.async { [weak self] in
            self?.favorites = self?.repository.fetch() ?? []
            self?.updateDerivedCollections()
            self?.isLoading = false
        }
    }
    
    private func updateDerivedCollections() {
        favoritesByUser = Dictionary(grouping: favorites) { $0.user?.id ?? "" }
        
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        recentlyAdded = favorites.filter { $0.createdAt >= weekAgo }
        
        topRated = favorites.filter { $0.rating >= 4 }.sorted { $0.rating > $1.rating }
    }
    
    private func removeFavorite(with id: String) {
        favorites.removeAll { $0.id == id }
        updateDerivedCollections()
    }
    
    private func syncFavorite(with id: String) {
        // Sync specific favorite with backend
        print("Syncing favorite: \(id)")
    }
    
    // MARK: - ModelObserver Implementation
    public func modelDidChange(_ model: Favorite) {
        if let index = favorites.firstIndex(where: { $0.id == model.id }) {
            favorites[index] = model
        } else {
            favorites.append(model)
        }
        updateDerivedCollections()
    }
    
    public func modelDidCreate(_ model: Favorite) {
        favorites.append(model)
        updateDerivedCollections()
        
        // Track analytics
        model.user?.trackEvent(.favoriteAdded)
    }
    
    public func modelDidUpdate(_ model: Favorite) {
        if let index = favorites.firstIndex(where: { $0.id == model.id }) {
            favorites[index] = model
        }
        updateDerivedCollections()
    }
    
    public func modelDidDelete(_ model: Favorite) {
        favorites.removeAll { $0.id == model.id }
        updateDerivedCollections()
        
        // Track analytics
        model.user?.trackEvent(.favoriteRemoved)
    }
    
    // MARK: - Public Methods
    public func refresh() {
        loadFavorites()
    }
    
    public func getFavorites(for user: User) -> [Favorite] {
        return favoritesByUser[user.id] ?? []
    }
    
    deinit {
        ObservableModelManager.shared.removeObserver(for: Favorite.self)
    }
}

// MARK: - Subscription Observer
@MainActor
public class SubscriptionObserver: ObservableObject, ModelObserver {
    public typealias Model = Subscription
    
    @Published public var subscriptions: [Subscription] = []
    @Published public var activeSubscriptions: [Subscription] = []
    @Published public var expiringSubscriptions: [Subscription] = []
    @Published public var canceledSubscriptions: [Subscription] = []
    @Published public var subscriptionsByPlan: [SubscriptionPlan: [Subscription]] = [:]
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let repository = RepositoryFactory.shared.subscriptionRepository()
    private var expirationCheckTimer: Timer?
    
    public init() {
        setupObserver()
        loadSubscriptions()
        startExpirationMonitoring()
    }
    
    private func setupObserver() {
        ObservableModelManager.shared.addObserver(AnyModelObserver(self), for: Subscription.self)
        
        ObservableModelManager.shared.publisher(for: Subscription.self)
            .sink { [weak self] event in
                self?.handleSubscriptionChange(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleSubscriptionChange(_ event: ModelChangeEvent) {
        loadSubscriptions()
    }
    
    private func loadSubscriptions() {
        isLoading = true
        
        DispatchQueue.main.async { [weak self] in
            self?.subscriptions = self?.repository.fetch() ?? []
            self?.updateDerivedCollections()
            self?.isLoading = false
        }
    }
    
    private func updateDerivedCollections() {
        activeSubscriptions = subscriptions.filter { $0.isActive }
        expiringSubscriptions = repository.fetchExpiringSubscriptions(within: 7)
        canceledSubscriptions = subscriptions.filter { $0.isCanceled }
        subscriptionsByPlan = Dictionary(grouping: subscriptions) { $0.plan }
    }
    
    private func startExpirationMonitoring() {
        expirationCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600.0, repeats: true) { [weak self] _ in
            self?.checkExpirations()
        }
    }
    
    private func checkExpirations() {
        let expiringIn3Days = repository.fetchExpiringSubscriptions(within: 3)
        
        for subscription in expiringIn3Days {
            guard let user = subscription.user else { continue }
            
            let notification = UserNotification.createSubscriptionExpiringNotification(
                for: user,
                daysUntilExpiration: subscription.daysUntilRenewal
            )
            
            Task {
                await NotificationManager().scheduleNotification(notification)
            }
        }
    }
    
    // MARK: - ModelObserver Implementation
    public func modelDidChange(_ model: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == model.id }) {
            subscriptions[index] = model
        } else {
            subscriptions.append(model)
        }
        updateDerivedCollections()
    }
    
    public func modelDidCreate(_ model: Subscription) {
        subscriptions.append(model)
        updateDerivedCollections()
        
        // Track analytics
        model.user?.trackEvent(.subscriptionUpgraded)
    }
    
    public func modelDidUpdate(_ model: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == model.id }) {
            subscriptions[index] = model
        }
        updateDerivedCollections()
    }
    
    public func modelDidDelete(_ model: Subscription) {
        subscriptions.removeAll { $0.id == model.id }
        updateDerivedCollections()
        
        // Track analytics
        model.user?.trackEvent(.subscriptionCanceled)
    }
    
    // MARK: - Public Methods
    public func refresh() {
        loadSubscriptions()
    }
    
    public func checkExpiringSubscriptions() {
        checkExpirations()
    }
    
    deinit {
        ObservableModelManager.shared.removeObserver(for: Subscription.self)
        expirationCheckTimer?.invalidate()
    }
}

// MARK: - Notification Observer
@MainActor
public class NotificationObserver: ObservableObject, ModelObserver {
    public typealias Model = UserNotification
    
    @Published public var notifications: [UserNotification] = []
    @Published public var unreadNotifications: [UserNotification] = []
    @Published public var notificationsByType: [NotificationType: [UserNotification]] = [:]
    @Published public var unreadCount: Int = 0
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let repository = RepositoryFactory.shared.notificationRepository()
    
    public init() {
        setupObserver()
        loadNotifications()
    }
    
    private func setupObserver() {
        ObservableModelManager.shared.addObserver(AnyModelObserver(self), for: UserNotification.self)
        
        ObservableModelManager.shared.publisher(for: UserNotification.self)
            .sink { [weak self] event in
                self?.handleNotificationChange(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleNotificationChange(_ event: ModelChangeEvent) {
        loadNotifications()
    }
    
    private func loadNotifications() {
        isLoading = true
        
        DispatchQueue.main.async { [weak self] in
            self?.notifications = self?.repository.fetch() ?? []
            self?.updateDerivedCollections()
            self?.isLoading = false
        }
    }
    
    private func updateDerivedCollections() {
        unreadNotifications = notifications.filter { !$0.isRead && !$0.isArchived }
        notificationsByType = Dictionary(grouping: notifications) { $0.type }
        unreadCount = unreadNotifications.count
    }
    
    // MARK: - ModelObserver Implementation
    public func modelDidChange(_ model: UserNotification) {
        if let index = notifications.firstIndex(where: { $0.id == model.id }) {
            notifications[index] = model
        } else {
            notifications.append(model)
        }
        updateDerivedCollections()
    }
    
    public func modelDidCreate(_ model: UserNotification) {
        notifications.append(model)
        updateDerivedCollections()
        
        // Show system notification if appropriate
        if model.type.defaultPriority == .high || model.type.defaultPriority == .urgent {
            showSystemNotification(for: model)
        }
    }
    
    public func modelDidUpdate(_ model: UserNotification) {
        if let index = notifications.firstIndex(where: { $0.id == model.id }) {
            notifications[index] = model
        }
        updateDerivedCollections()
    }
    
    public func modelDidDelete(_ model: UserNotification) {
        notifications.removeAll { $0.id == model.id }
        updateDerivedCollections()
    }
    
    private func showSystemNotification(for notification: UserNotification) {
        // Show system notification
        print("Showing system notification: \(notification.title)")
    }
    
    // MARK: - Public Methods
    public func refresh() {
        loadNotifications()
    }
    
    public func markAllAsRead() {
        unreadNotifications.forEach { $0.markAsRead() }
        updateDerivedCollections()
    }
    
    deinit {
        ObservableModelManager.shared.removeObserver(for: UserNotification.self)
    }
}

// MARK: - Global Observer Manager
@MainActor
public class GlobalModelObserver: ObservableObject {
    public static let shared = GlobalModelObserver()
    
    @Published public var userObserver = UserObserver()
    @Published public var streamObserver = StreamObserver()
    @Published public var favoriteObserver = FavoriteObserver()
    @Published public var subscriptionObserver = SubscriptionObserver()
    @Published public var notificationObserver = NotificationObserver()
    
    @Published public var isRealTimeSyncEnabled = false
    @Published public var lastSyncTime: Date?
    @Published public var syncStatus: SyncStatus = .idle
    
    public enum SyncStatus {
        case idle
        case syncing
        case success
        case failed(Error)
        
        var displayName: String {
            switch self {
            case .idle: return "Idle"
            case .syncing: return "Syncing"
            case .success: return "Success"
            case .failed: return "Failed"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .syncing: return .blue
            case .success: return .green
            case .failed: return .red
            }
        }
    }
    
    private init() {
        setupRealTimeSync()
    }
    
    private func setupRealTimeSync() {
        // Setup real-time sync with backend
        print("Setting up real-time sync")
    }
    
    public func startRealTimeSync() {
        guard !isRealTimeSyncEnabled else { return }
        
        isRealTimeSyncEnabled = true
        syncStatus = .syncing
        
        userObserver.startRealTimeSync()
        streamObserver.startRealTimeSync()
        
        // Simulate sync completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.syncStatus = .success
            self.lastSyncTime = Date()
        }
    }
    
    public func stopRealTimeSync() {
        guard isRealTimeSyncEnabled else { return }
        
        isRealTimeSyncEnabled = false
        syncStatus = .idle
        
        userObserver.stopRealTimeSync()
        streamObserver.stopRealTimeSync()
    }
    
    public func refreshAll() {
        userObserver.refresh()
        streamObserver.refresh()
        favoriteObserver.refresh()
        subscriptionObserver.refresh()
        notificationObserver.refresh()
    }
    
    public func syncStatusView: some View {
        HStack {
            Circle()
                .fill(syncStatus.color)
                .frame(width: 8, height: 8)
            
            Text(syncStatus.displayName)
                .font(.caption)
                .foregroundColor(syncStatus.color)
            
            if let lastSyncTime = lastSyncTime {
                Text("• \(lastSyncTime.timeAgoDisplay)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}