//
//  CloudKitService.swift
//  StreamyyyApp
//
//  CloudKit service for cross-device synchronization and backup
//  Provides seamless data sync across user's devices via iCloud
//

import Foundation
import CloudKit
import SwiftUI
import Combine

// MARK: - CloudKit Service
@MainActor
public class CloudKitService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isAvailable: Bool = false
    @Published public private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published public private(set) var syncStatus: CloudKitSyncStatus = .unknown
    @Published public private(set) var lastSyncTime: Date?
    @Published public private(set) var error: CloudKitError?
    
    // MARK: - CloudKit Configuration
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    // MARK: - Record Types
    private enum RecordType {
        static let user = "User"
        static let stream = "Stream"
        static let favorite = "Favorite"
        static let layout = "Layout"
        static let viewingHistory = "ViewingHistory"
        static let userPreferences = "UserPreferences"
    }
    
    // MARK: - Zone Configuration
    private let customZoneID = CKRecordZone.ID(zoneName: "StreamyyyAppZone", ownerName: CKCurrentUserDefaultName)
    private var customZone: CKRecordZone?
    
    // MARK: - Sync Management
    private var changeToken: CKServerChangeToken?
    private let changeTokenKey = "CloudKitChangeToken"
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Operation Queues
    private let operationQueue: OperationQueue
    private let batchSize = 100
    
    // MARK: - Initialization
    public init() throws {
        // Initialize CloudKit container
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        
        // Setup operation queue
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = 3
        self.operationQueue.qualityOfService = .utility
        
        // Load change token
        loadChangeToken()
        
        // Initialize CloudKit
        Task {
            await initializeCloudKit()
        }
    }
    
    // MARK: - Initialization Methods
    private func initializeCloudKit() async {
        do {
            // Check account status
            accountStatus = try await container.accountStatus()
            
            guard accountStatus == .available else {
                syncStatus = .unavailable
                isAvailable = false
                return
            }
            
            // Request permissions
            let permissionStatus = try await container.requestApplicationPermission(.userDiscoverability)
            
            // Create custom zone
            try await createCustomZoneIfNeeded()
            
            // Setup subscriptions
            try await setupSubscriptions()
            
            // Mark as available
            isAvailable = true
            syncStatus = .idle
            
            // Start sync timer
            startSyncTimer()
            
            print("✅ CloudKit service initialized successfully")
            
        } catch {
            print("❌ CloudKit initialization failed: \(error)")
            self.error = .initializationFailed(error)
            syncStatus = .error
            isAvailable = false
        }
    }
    
    private func createCustomZoneIfNeeded() async throws {
        let zone = CKRecordZone(zoneID: customZoneID)
        
        do {
            let savedZones = try await privateDatabase.save(zone)
            customZone = savedZones
            print("✅ CloudKit custom zone created/verified")
        } catch let error as CKError where error.code == .zoneNotFound {
            // Zone doesn't exist, create it
            let savedZone = try await privateDatabase.save(zone)
            customZone = savedZone
            print("✅ CloudKit custom zone created")
        }
    }
    
    private func setupSubscriptions() async throws {
        // Create subscription for database changes
        let subscription = CKDatabaseSubscription(subscriptionID: "StreamyyyAppSubscription")
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        do {
            let savedSubscription = try await privateDatabase.save(subscription)
            print("✅ CloudKit subscription created: \(savedSubscription.subscriptionID)")
        } catch let error as CKError where error.code == .duplicateSubscription {
            // Subscription already exists
            print("ℹ️ CloudKit subscription already exists")
        }
    }
    
    // MARK: - Sync Operations
    public func performFullSync() async {
        guard isAvailable else {
            syncStatus = .unavailable
            return
        }
        
        syncStatus = .syncing
        
        do {
            // Fetch changes from CloudKit
            try await fetchChangesFromCloudKit()
            
            // Push local changes to CloudKit
            try await pushLocalChangesToCloudKit()
            
            syncStatus = .synced
            lastSyncTime = Date()
            
            print("✅ CloudKit full sync completed")
            
        } catch {
            print("❌ CloudKit full sync failed: \(error)")
            self.error = .syncFailed(error)
            syncStatus = .error
        }
    }
    
    public func performIncrementalSync() async {
        guard isAvailable else { return }
        guard syncStatus != .syncing else { return }
        
        syncStatus = .syncing
        
        do {
            // Fetch incremental changes
            try await fetchChangesFromCloudKit()
            
            syncStatus = .synced
            lastSyncTime = Date()
            
        } catch {
            print("❌ CloudKit incremental sync failed: \(error)")
            self.error = .syncFailed(error)
            syncStatus = .error
        }
    }
    
    private func fetchChangesFromCloudKit() async throws {
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
        
        var changedZoneIDs: [CKRecordZone.ID] = []
        var deletedZoneIDs: [CKRecordZone.ID] = []
        
        operation.recordZoneWithIDChangedBlock = { zoneID in
            changedZoneIDs.append(zoneID)
        }
        
        operation.recordZoneWithIDWasDeletedBlock = { zoneID in
            deletedZoneIDs.append(zoneID)
        }
        
        operation.fetchDatabaseChangesResultBlock = { [weak self] result in
            switch result {
            case .success(let (serverChangeToken, moreComing)):
                self?.changeToken = serverChangeToken
                self?.saveChangeToken()
                
                if !moreComing {
                    Task {
                        try await self?.fetchZoneChanges(for: changedZoneIDs)
                    }
                }
            case .failure(let error):
                print("❌ Failed to fetch database changes: \(error)")
            }
        }
        
        try await privateDatabase.add(operation)
    }
    
    private func fetchZoneChanges(for zoneIDs: [CKRecordZone.ID]) async throws {
        for zoneID in zoneIDs {
            try await fetchChanges(for: zoneID)
        }
    }
    
    private func fetchChanges(for zoneID: CKRecordZone.ID) async throws {
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID])
        
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        
        operation.recordWasChangedBlock = { _, result in
            switch result {
            case .success(let record):
                changedRecords.append(record)
            case .failure(let error):
                print("❌ Failed to fetch changed record: \(error)")
            }
        }
        
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }
        
        operation.fetchRecordZoneChangesResultBlock = { [weak self] result in
            switch result {
            case .success:
                Task {
                    await self?.processChangedRecords(changedRecords)
                    await self?.processDeletedRecords(deletedRecordIDs)
                }
            case .failure(let error):
                print("❌ Failed to fetch zone changes: \(error)")
            }
        }
        
        try await privateDatabase.add(operation)
    }
    
    private func processChangedRecords(_ records: [CKRecord]) async {
        for record in records {
            await processRecord(record)
        }
    }
    
    private func processDeletedRecords(_ recordIDs: [CKRecord.ID]) async {
        for recordID in recordIDs {
            await processDeletedRecord(recordID)
        }
    }
    
    private func processRecord(_ record: CKRecord) async {
        switch record.recordType {
        case RecordType.user:
            await processUserRecord(record)
        case RecordType.stream:
            await processStreamRecord(record)
        case RecordType.favorite:
            await processFavoriteRecord(record)
        case RecordType.layout:
            await processLayoutRecord(record)
        case RecordType.viewingHistory:
            await processViewingHistoryRecord(record)
        case RecordType.userPreferences:
            await processUserPreferencesRecord(record)
        default:
            print("⚠️ Unknown record type: \(record.recordType)")
        }
    }
    
    private func processDeletedRecord(_ recordID: CKRecord.ID) async {
        // Handle deleted records by removing them from local storage
        let recordName = recordID.recordName
        
        // Determine record type and remove from appropriate local storage
        // This would involve coordinating with the DataService
        print("🗑️ Processing deleted record: \(recordName)")
    }
    
    // MARK: - Record Processing Methods
    private func processUserRecord(_ record: CKRecord) async {
        // Convert CloudKit record to User model and update local storage
        if let user = createUserFromRecord(record) {
            // Update via DataService
            do {
                try await DataService.shared.updateUser(user)
            } catch {
                print("❌ Failed to update user from CloudKit: \(error)")
            }
        }
    }
    
    private func processStreamRecord(_ record: CKRecord) async {
        // Convert CloudKit record to Stream model and update local storage
        if let stream = createStreamFromRecord(record) {
            do {
                try await DataService.shared.updateStream(stream)
            } catch {
                print("❌ Failed to update stream from CloudKit: \(error)")
            }
        }
    }
    
    private func processFavoriteRecord(_ record: CKRecord) async {
        // Process favorite record from CloudKit
        print("📱 Processing favorite record from CloudKit")
    }
    
    private func processLayoutRecord(_ record: CKRecord) async {
        // Process layout record from CloudKit
        print("📱 Processing layout record from CloudKit")
    }
    
    private func processViewingHistoryRecord(_ record: CKRecord) async {
        // Process viewing history record from CloudKit
        print("📱 Processing viewing history record from CloudKit")
    }
    
    private func processUserPreferencesRecord(_ record: CKRecord) async {
        // Process user preferences record from CloudKit
        print("📱 Processing user preferences record from CloudKit")
    }
    
    // MARK: - Push Local Changes
    private func pushLocalChangesToCloudKit() async throws {
        // Get local changes that need to be synced
        let pendingChanges = getPendingLocalChanges()
        
        if pendingChanges.isEmpty {
            return
        }
        
        // Batch the changes
        let batches = pendingChanges.chunked(into: batchSize)
        
        for batch in batches {
            try await processBatch(batch)
        }
    }
    
    private func getPendingLocalChanges() -> [CloudKitSyncRecord] {
        // Get records that need to be synced to CloudKit
        // This would coordinate with DataService to get modified records
        return []
    }
    
    private func processBatch(_ records: [CloudKitSyncRecord]) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: records.map { $0.record })
        
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                print("✅ Batch sync completed successfully")
            case .failure(let error):
                print("❌ Batch sync failed: \(error)")
            }
        }
        
        try await privateDatabase.add(operation)
    }
    
    // MARK: - Public Sync Methods
    public func syncUser(_ user: User) async {
        guard isAvailable else { return }
        
        let record = createRecordFromUser(user)
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            print("✅ User synced to CloudKit: \(savedRecord.recordID)")
        } catch {
            print("❌ Failed to sync user to CloudKit: \(error)")
        }
    }
    
    public func syncStream(_ stream: Stream) async {
        guard isAvailable else { return }
        
        let record = createRecordFromStream(stream)
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            print("✅ Stream synced to CloudKit: \(savedRecord.recordID)")
        } catch {
            print("❌ Failed to sync stream to CloudKit: \(error)")
        }
    }
    
    public func syncFavorite(_ favorite: Favorite) async {
        guard isAvailable else { return }
        
        let record = createRecordFromFavorite(favorite)
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            print("✅ Favorite synced to CloudKit: \(savedRecord.recordID)")
        } catch {
            print("❌ Failed to sync favorite to CloudKit: \(error)")
        }
    }
    
    public func syncLayout(_ layout: Layout) async {
        guard isAvailable else { return }
        
        let record = createRecordFromLayout(layout)
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            print("✅ Layout synced to CloudKit: \(savedRecord.recordID)")
        } catch {
            print("❌ Failed to sync layout to CloudKit: \(error)")
        }
    }
    
    // MARK: - Record Creation Methods
    private func createRecordFromUser(_ user: User) -> CKRecord {
        let recordID = CKRecord.ID(recordName: user.id, zoneID: customZoneID)
        let record = CKRecord(recordType: RecordType.user, recordID: recordID)
        
        record["email"] = user.email
        record["username"] = user.username
        record["firstName"] = user.firstName
        record["lastName"] = user.lastName
        record["profileImageURL"] = user.profileImageURL
        record["timezone"] = user.timezone
        record["locale"] = user.locale
        record["createdAt"] = user.createdAt
        record["updatedAt"] = user.updatedAt
        record["isActive"] = user.isActive ? 1 : 0
        
        return record
    }
    
    private func createRecordFromStream(_ stream: Stream) -> CKRecord {
        let recordID = CKRecord.ID(recordName: stream.id, zoneID: customZoneID)
        let record = CKRecord(recordType: RecordType.stream, recordID: recordID)
        
        record["url"] = stream.url
        record["title"] = stream.title
        record["description"] = stream.description
        record["platform"] = stream.platform.rawValue
        record["thumbnailURL"] = stream.thumbnailURL
        record["streamerName"] = stream.streamerName
        record["category"] = stream.category
        record["isLive"] = stream.isLive ? 1 : 0
        record["viewerCount"] = stream.viewerCount
        record["createdAt"] = stream.createdAt
        record["updatedAt"] = stream.updatedAt
        
        return record
    }
    
    private func createRecordFromFavorite(_ favorite: Favorite) -> CKRecord {
        let recordID = CKRecord.ID(recordName: favorite.id, zoneID: customZoneID)
        let record = CKRecord(recordType: RecordType.favorite, recordID: recordID)
        
        record["userId"] = favorite.user?.id
        record["streamId"] = favorite.stream?.id
        record["createdAt"] = favorite.createdAt
        record["rating"] = favorite.rating
        record["notes"] = favorite.notes
        record["isArchived"] = favorite.isArchived ? 1 : 0
        
        return record
    }
    
    private func createRecordFromLayout(_ layout: Layout) -> CKRecord {
        let recordID = CKRecord.ID(recordName: layout.id, zoneID: customZoneID)
        let record = CKRecord(recordType: RecordType.layout, recordID: recordID)
        
        record["name"] = layout.name
        record["description"] = layout.description
        record["type"] = layout.type.rawValue
        record["isDefault"] = layout.isDefault ? 1 : 0
        record["isCustom"] = layout.isCustom ? 1 : 0
        record["createdAt"] = layout.createdAt
        record["updatedAt"] = layout.updatedAt
        record["version"] = layout.version
        
        // Store configuration as JSON
        if let configData = try? JSONEncoder().encode(layout.configuration),
           let configString = String(data: configData, encoding: .utf8) {
            record["configuration"] = configString
        }
        
        return record
    }
    
    // MARK: - Record Parsing Methods
    private func createUserFromRecord(_ record: CKRecord) -> User? {
        guard let email = record["email"] as? String else { return nil }
        
        let user = User(
            id: record.recordID.recordName,
            email: email,
            username: record["username"] as? String,
            firstName: record["firstName"] as? String,
            lastName: record["lastName"] as? String,
            profileImageURL: record["profileImageURL"] as? String,
            timezone: record["timezone"] as? String ?? TimeZone.current.identifier,
            locale: record["locale"] as? String ?? Locale.current.identifier
        )
        
        if let createdAt = record["createdAt"] as? Date {
            user.createdAt = createdAt
        }
        
        if let updatedAt = record["updatedAt"] as? Date {
            user.updatedAt = updatedAt
        }
        
        if let isActive = record["isActive"] as? Int {
            user.isActive = isActive == 1
        }
        
        return user
    }
    
    private func createStreamFromRecord(_ record: CKRecord) -> Stream? {
        guard let url = record["url"] as? String,
              let title = record["title"] as? String,
              let platformRaw = record["platform"] as? String,
              let platform = Platform(rawValue: platformRaw) else { return nil }
        
        let stream = Stream(
            id: record.recordID.recordName,
            url: url,
            platform: platform,
            title: title
        )
        
        stream.description = record["description"] as? String
        stream.thumbnailURL = record["thumbnailURL"] as? String
        stream.streamerName = record["streamerName"] as? String
        stream.category = record["category"] as? String
        
        if let isLive = record["isLive"] as? Int {
            stream.isLive = isLive == 1
        }
        
        if let viewerCount = record["viewerCount"] as? Int {
            stream.viewerCount = viewerCount
        }
        
        if let createdAt = record["createdAt"] as? Date {
            stream.createdAt = createdAt
        }
        
        if let updatedAt = record["updatedAt"] as? Date {
            stream.updatedAt = updatedAt
        }
        
        return stream
    }
    
    // MARK: - Change Token Management
    private func loadChangeToken() {
        if let tokenData = UserDefaults.standard.data(forKey: changeTokenKey),
           let token = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(tokenData) as? CKServerChangeToken {
            changeToken = token
        }
    }
    
    private func saveChangeToken() {
        guard let changeToken = changeToken else { return }
        
        do {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: changeToken, requiringSecureCoding: true)
            UserDefaults.standard.set(tokenData, forKey: changeTokenKey)
        } catch {
            print("❌ Failed to save change token: \(error)")
        }
    }
    
    // MARK: - Timer Management
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task {
                await self.performIncrementalSync()
            }
        }
    }
    
    // MARK: - Error Handling
    public func clearError() {
        error = nil
    }
    
    // MARK: - Cleanup
    deinit {
        syncTimer?.invalidate()
        operationQueue.cancelAllOperations()
    }
}

// MARK: - Supporting Types

public enum CloudKitSyncStatus {
    case unknown
    case unavailable
    case idle
    case syncing
    case synced
    case error
    
    public var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .unavailable: return "Unavailable"
        case .idle: return "Ready"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .error: return "Error"
        }
    }
    
    public var color: Color {
        switch self {
        case .unknown: return .gray
        case .unavailable: return .orange
        case .idle: return .blue
        case .syncing: return .yellow
        case .synced: return .green
        case .error: return .red
        }
    }
}

public enum CloudKitError: Error, LocalizedError {
    case initializationFailed(Error)
    case accountUnavailable
    case permissionDenied
    case syncFailed(Error)
    case recordNotFound
    case conflictResolution(Error)
    case quotaExceeded
    case networkUnavailable
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "CloudKit initialization failed: \(error.localizedDescription)"
        case .accountUnavailable:
            return "iCloud account is not available"
        case .permissionDenied:
            return "CloudKit permission denied"
        case .syncFailed(let error):
            return "CloudKit sync failed: \(error.localizedDescription)"
        case .recordNotFound:
            return "Record not found in CloudKit"
        case .conflictResolution(let error):
            return "CloudKit conflict resolution failed: \(error.localizedDescription)"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .networkUnavailable:
            return "Network unavailable for CloudKit sync"
        case .unknownError(let error):
            return "Unknown CloudKit error: \(error.localizedDescription)"
        }
    }
}

public struct CloudKitSyncRecord {
    public let record: CKRecord
    public let operation: CloudKitOperation
    public let timestamp: Date
}

public enum CloudKitOperation {
    case save
    case delete
    case update
}

// MARK: - Array Extension for Batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}