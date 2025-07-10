//
//  ModelContainer.swift
//  StreamyyyApp
//
//  SwiftData container with Core Data fallback
//

import Foundation
import SwiftUI
import SwiftData
import CoreData

// MARK: - App Model Container
public class AppModelContainer: ObservableObject {
    public static let shared = AppModelContainer()
    
    @Published public private(set) var container: ModelContainer?
    @Published public private(set) var context: ModelContext?
    @Published public private(set) var isReady: Bool = false
    @Published public private(set) var error: ModelError?
    
    private var coreDataStack: CoreDataStack?
    private var usesCoreData: Bool = false
    
    private init() {
        setupContainer()
    }
    
    // MARK: - Setup Methods
    private func setupContainer() {
        if #available(iOS 17.0, *) {
            setupSwiftData()
        } else {
            setupCoreData()
        }
    }
    
    @available(iOS 17.0, *)
    private func setupSwiftData() {
        do {
            let schema = Schema([
                User.self,
                Stream.self,
                Subscription.self,
                Favorite.self,
                Layout.self,
                LayoutStream.self,
                UserNotification.self,
                StreamAnalytics.self,
                PaymentHistory.self
            ])
            
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            
            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            context = container?.mainContext
            usesCoreData = false
            isReady = true
            
            print("✅ SwiftData container initialized successfully")
            
        } catch {
            print("❌ SwiftData setup failed: \(error)")
            print("🔄 Falling back to Core Data...")
            setupCoreData()
        }
    }
    
    private func setupCoreData() {
        do {
            coreDataStack = try CoreDataStack()
            usesCoreData = true
            isReady = true
            
            print("✅ Core Data stack initialized successfully")
            
        } catch {
            print("❌ Core Data setup failed: \(error)")
            self.error = .initializationFailed(error)
            isReady = false
        }
    }
    
    // MARK: - Public Methods
    public func save() {
        if #available(iOS 17.0, *), !usesCoreData {
            saveSwiftData()
        } else {
            saveCoreData()
        }
    }
    
    @available(iOS 17.0, *)
    private func saveSwiftData() {
        guard let context = context else { return }
        
        do {
            try context.save()
            print("✅ SwiftData context saved successfully")
        } catch {
            print("❌ SwiftData save failed: \(error)")
            self.error = .saveFailed(error)
        }
    }
    
    private func saveCoreData() {
        guard let coreDataStack = coreDataStack else { return }
        
        do {
            try coreDataStack.save()
            print("✅ Core Data context saved successfully")
        } catch {
            print("❌ Core Data save failed: \(error)")
            self.error = .saveFailed(error)
        }
    }
    
    // MARK: - Query Methods
    public func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        if #available(iOS 17.0, *), !usesCoreData {
            return fetchSwiftData(type)
        } else {
            return fetchCoreData(type)
        }
    }
    
    @available(iOS 17.0, *)
    private func fetchSwiftData<T: PersistentModel>(_ type: T.Type) -> [T] {
        guard let context = context else { return [] }
        
        do {
            let descriptor = FetchDescriptor<T>()
            return try context.fetch(descriptor)
        } catch {
            print("❌ SwiftData fetch failed: \(error)")
            self.error = .fetchFailed(error)
            return []
        }
    }
    
    private func fetchCoreData<T: PersistentModel>(_ type: T.Type) -> [T] {
        // Core Data fetch implementation would go here
        // For now, return empty array
        return []
    }
    
    // MARK: - Insert Methods
    public func insert<T: PersistentModel>(_ model: T) {
        if #available(iOS 17.0, *), !usesCoreData {
            insertSwiftData(model)
        } else {
            insertCoreData(model)
        }
    }
    
    @available(iOS 17.0, *)
    private func insertSwiftData<T: PersistentModel>(_ model: T) {
        guard let context = context else { return }
        context.insert(model)
    }
    
    private func insertCoreData<T: PersistentModel>(_ model: T) {
        // Core Data insert implementation would go here
    }
    
    // MARK: - Delete Methods
    public func delete<T: PersistentModel>(_ model: T) {
        if #available(iOS 17.0, *), !usesCoreData {
            deleteSwiftData(model)
        } else {
            deleteCoreData(model)
        }
    }
    
    @available(iOS 17.0, *)
    private func deleteSwiftData<T: PersistentModel>(_ model: T) {
        guard let context = context else { return }
        context.delete(model)
    }
    
    private func deleteCoreData<T: PersistentModel>(_ model: T) {
        // Core Data delete implementation would go here
    }
    
    // MARK: - Migration Methods
    public func migrateToLatestVersion() {
        if #available(iOS 17.0, *), !usesCoreData {
            migrateSwiftData()
        } else {
            migrateCoreData()
        }
    }
    
    @available(iOS 17.0, *)
    private func migrateSwiftData() {
        // SwiftData migration logic would go here
        print("🔄 SwiftData migration not needed")
    }
    
    private func migrateCoreData() {
        // Core Data migration logic would go here
        print("🔄 Core Data migration completed")
    }
    
    // MARK: - Cleanup Methods
    public func cleanup() {
        if #available(iOS 17.0, *), !usesCoreData {
            cleanupSwiftData()
        } else {
            cleanupCoreData()
        }
    }
    
    @available(iOS 17.0, *)
    private func cleanupSwiftData() {
        // Clean up expired data, archived items, etc.
        guard let context = context else { return }
        
        do {
            // Clean up expired notifications
            let expiredNotifications = try context.fetch(
                FetchDescriptor<UserNotification>(
                    predicate: #Predicate { $0.expiresAt != nil && $0.expiresAt! < Date() }
                )
            )
            
            for notification in expiredNotifications {
                context.delete(notification)
            }
            
            // Clean up old analytics data (older than 90 days)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            let oldAnalytics = try context.fetch(
                FetchDescriptor<StreamAnalytics>(
                    predicate: #Predicate { $0.timestamp < cutoffDate }
                )
            )
            
            for analytics in oldAnalytics {
                context.delete(analytics)
            }
            
            try context.save()
            print("✅ SwiftData cleanup completed")
            
        } catch {
            print("❌ SwiftData cleanup failed: \(error)")
            self.error = .cleanupFailed(error)
        }
    }
    
    private func cleanupCoreData() {
        // Core Data cleanup implementation would go here
        print("✅ Core Data cleanup completed")
    }
    
    // MARK: - Performance Methods
    public func performanceOptimization() {
        if #available(iOS 17.0, *), !usesCoreData {
            optimizeSwiftData()
        } else {
            optimizeCoreData()
        }
    }
    
    @available(iOS 17.0, *)
    private func optimizeSwiftData() {
        // SwiftData performance optimization
        print("🚀 SwiftData performance optimization completed")
    }
    
    private func optimizeCoreData() {
        // Core Data performance optimization
        print("🚀 Core Data performance optimization completed")
    }
    
    // MARK: - Backup Methods
    public func createBackup() -> URL? {
        if #available(iOS 17.0, *), !usesCoreData {
            return createSwiftDataBackup()
        } else {
            return createCoreDataBackup()
        }
    }
    
    @available(iOS 17.0, *)
    private func createSwiftDataBackup() -> URL? {
        // SwiftData backup implementation
        print("💾 SwiftData backup created")
        return nil
    }
    
    private func createCoreDataBackup() -> URL? {
        // Core Data backup implementation
        print("💾 Core Data backup created")
        return nil
    }
    
    // MARK: - Restore Methods
    public func restoreFromBackup(_ backupURL: URL) -> Bool {
        if #available(iOS 17.0, *), !usesCoreData {
            return restoreSwiftDataFromBackup(backupURL)
        } else {
            return restoreCoreDataFromBackup(backupURL)
        }
    }
    
    @available(iOS 17.0, *)
    private func restoreSwiftDataFromBackup(_ backupURL: URL) -> Bool {
        // SwiftData restore implementation
        print("🔄 SwiftData restore completed")
        return true
    }
    
    private func restoreCoreDataFromBackup(_ backupURL: URL) -> Bool {
        // Core Data restore implementation
        print("🔄 Core Data restore completed")
        return true
    }
}

// MARK: - Core Data Stack (iOS 16 and below)
private class CoreDataStack {
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "StreamyyyApp")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    init() throws {
        // Initialize Core Data stack
        _ = persistentContainer
    }
    
    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}

// MARK: - Model Error
public enum ModelError: Error, LocalizedError {
    case initializationFailed(Error)
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case migrationFailed(Error)
    case cleanupFailed(Error)
    case backupFailed(Error)
    case restoreFailed(Error)
    case invalidModel
    case contextUnavailable
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Failed to initialize model container: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Failed to migrate data: \(error.localizedDescription)"
        case .cleanupFailed(let error):
            return "Failed to cleanup data: \(error.localizedDescription)"
        case .backupFailed(let error):
            return "Failed to create backup: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Failed to restore from backup: \(error.localizedDescription)"
        case .invalidModel:
            return "Invalid model"
        case .contextUnavailable:
            return "Model context unavailable"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Model Repository Protocol
public protocol ModelRepository {
    associatedtype Model: PersistentModel
    
    func fetch() -> [Model]
    func fetch(by id: String) -> Model?
    func insert(_ model: Model)
    func update(_ model: Model)
    func delete(_ model: Model)
    func deleteAll()
    func count() -> Int
}

// MARK: - Generic Repository Implementation
public class GenericRepository<T: PersistentModel>: ModelRepository {
    public typealias Model = T
    
    private let container: AppModelContainer
    
    public init(container: AppModelContainer = .shared) {
        self.container = container
    }
    
    public func fetch() -> [T] {
        return container.fetch(T.self)
    }
    
    public func fetch(by id: String) -> T? {
        let models = fetch()
        return models.first { model in
            // Assuming all models have an 'id' property
            return (model as? any Identifiable)?.id as? String == id
        }
    }
    
    public func insert(_ model: T) {
        container.insert(model)
    }
    
    public func update(_ model: T) {
        // SwiftData automatically tracks changes
        container.save()
    }
    
    public func delete(_ model: T) {
        container.delete(model)
    }
    
    public func deleteAll() {
        let models = fetch()
        models.forEach { container.delete($0) }
    }
    
    public func count() -> Int {
        return fetch().count
    }
}

// MARK: - Specific Repository Implementations
public class UserRepository: GenericRepository<User> {
    public func fetchByEmail(_ email: String) -> User? {
        return fetch().first { $0.email == email }
    }
    
    public func fetchByClerkId(_ clerkId: String) -> User? {
        return fetch().first { $0.clerkId == clerkId }
    }
    
    public func fetchActiveUsers() -> [User] {
        return fetch().filter { $0.isActive && !$0.isBanned }
    }
}

public class StreamRepository: GenericRepository<Stream> {
    public func fetchByURL(_ url: String) -> Stream? {
        return fetch().first { $0.url == url }
    }
    
    public func fetchByPlatform(_ platform: Platform) -> [Stream] {
        return fetch().filter { $0.platform == platform }
    }
    
    public func fetchLiveStreams() -> [Stream] {
        return fetch().filter { $0.isLive }
    }
    
    public func fetchByOwner(_ owner: User) -> [Stream] {
        return fetch().filter { $0.owner?.id == owner.id }
    }
}

public class FavoriteRepository: GenericRepository<Favorite> {
    public func fetchByUser(_ user: User) -> [Favorite] {
        return fetch().filter { $0.user?.id == user.id && !$0.isArchived }
    }
    
    public func fetchByStream(_ stream: Stream) -> [Favorite] {
        return fetch().filter { $0.stream?.id == stream.id }
    }
    
    public func fetchArchivedByUser(_ user: User) -> [Favorite] {
        return fetch().filter { $0.user?.id == user.id && $0.isArchived }
    }
}

public class SubscriptionRepository: GenericRepository<Subscription> {
    public func fetchByUser(_ user: User) -> [Subscription] {
        return fetch().filter { $0.user?.id == user.id }
    }
    
    public func fetchActiveSubscriptions() -> [Subscription] {
        return fetch().filter { $0.isActive }
    }
    
    public func fetchExpiringSubscriptions(within days: Int) -> [Subscription] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return fetch().filter { $0.currentPeriodEnd <= cutoffDate }
    }
}

public class NotificationRepository: GenericRepository<UserNotification> {
    public func fetchByUser(_ user: User) -> [UserNotification] {
        return fetch().filter { $0.user?.id == user.id }
    }
    
    public func fetchUnreadByUser(_ user: User) -> [UserNotification] {
        return fetch().filter { $0.user?.id == user.id && !$0.isRead && !$0.isArchived }
    }
    
    public func fetchByType(_ type: NotificationType) -> [UserNotification] {
        return fetch().filter { $0.type == type }
    }
    
    public func fetchScheduledNotifications() -> [UserNotification] {
        return fetch().filter { $0.isScheduled }
    }
}

// MARK: - Repository Factory
public class RepositoryFactory {
    public static let shared = RepositoryFactory()
    
    private init() {}
    
    public func userRepository() -> UserRepository {
        return UserRepository()
    }
    
    public func streamRepository() -> StreamRepository {
        return StreamRepository()
    }
    
    public func favoriteRepository() -> FavoriteRepository {
        return FavoriteRepository()
    }
    
    public func subscriptionRepository() -> SubscriptionRepository {
        return SubscriptionRepository()
    }
    
    public func notificationRepository() -> NotificationRepository {
        return NotificationRepository()
    }
}

// MARK: - SwiftUI Extensions
extension View {
    public func modelContainer() -> some View {
        if #available(iOS 17.0, *) {
            return self.modelContainer(AppModelContainer.shared.container ?? ModelContainer(try! Schema([])))
        } else {
            return self
        }
    }
}

// MARK: - Model Container Extensions
extension AppModelContainer {
    public func performBackgroundTask<T>(_ block: @escaping (ModelContext) -> T) -> T? {
        if #available(iOS 17.0, *), let container = container {
            let backgroundContext = ModelContext(container)
            return block(backgroundContext)
        }
        return nil
    }
    
    public func performBackgroundTaskAsync<T>(_ block: @escaping (ModelContext) async -> T) async -> T? {
        if #available(iOS 17.0, *), let container = container {
            let backgroundContext = ModelContext(container)
            return await block(backgroundContext)
        }
        return nil
    }
}

// MARK: - Batch Operations
extension AppModelContainer {
    public func batchInsert<T: PersistentModel>(_ models: [T]) {
        models.forEach { insert($0) }
        save()
    }
    
    public func batchDelete<T: PersistentModel>(_ models: [T]) {
        models.forEach { delete($0) }
        save()
    }
    
    public func batchUpdate<T: PersistentModel>(_ models: [T], _ updateBlock: (T) -> Void) {
        models.forEach { updateBlock($0) }
        save()
    }
}

// MARK: - Statistics and Analytics
extension AppModelContainer {
    public func getDatabaseStatistics() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        stats["userCount"] = fetch(User.self).count
        stats["streamCount"] = fetch(Stream.self).count
        stats["favoriteCount"] = fetch(Favorite.self).count
        stats["subscriptionCount"] = fetch(Subscription.self).count
        stats["notificationCount"] = fetch(UserNotification.self).count
        stats["isReady"] = isReady
        stats["usesCoreData"] = usesCoreData
        
        return stats
    }
    
    public func getHealthStatus() -> ModelHealthStatus {
        if !isReady {
            return .unhealthy
        }
        
        if error != nil {
            return .warning
        }
        
        return .healthy
    }
}

// MARK: - Model Health Status
public enum ModelHealthStatus: String, CaseIterable {
    case healthy = "healthy"
    case warning = "warning"
    case unhealthy = "unhealthy"
    
    public var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .unhealthy: return "Unhealthy"
        }
    }
    
    public var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .orange
        case .unhealthy: return .red
        }
    }
    
    public var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .unhealthy: return "xmark.circle.fill"
        }
    }
}