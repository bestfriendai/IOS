//
//  SupabaseService.swift
//  StreamyyyApp
//
//  Complete Supabase service layer with authentication, database operations,
//  real-time subscriptions, file storage, error handling, and offline mode support
//

import Foundation
import Supabase
import Combine
import SwiftUI
import Network
import OSLog

// MARK: - Logger
private let logger = Logger(subsystem: "com.streamyyy.app", category: "SupabaseService")

// MARK: - Main Supabase Service
@MainActor
public class SupabaseService: ObservableObject {
    
    // MARK: - Properties
    public static let shared = SupabaseService()
    
    private let client: SupabaseClient
    private let storage: SupabaseStorage
    private let auth: SupabaseAuth
    private let database: SupabaseDatabase
    private let realtime: SupabaseRealtime
    
    // Published properties for SwiftUI
    @Published public var isConnected: Bool = false
    @Published public var currentUser: User?
    @Published public var authState: AuthState = .unauthenticated
    @Published public var syncStatus: SyncStatus = .disconnected
    @Published public var lastSyncTime: Date?
    @Published public var isOfflineMode: Bool = false
    @Published public var networkStatus: NetworkStatus = .disconnected
    
    // Internal properties
    private var cancellables = Set<AnyCancellable>()
    private var authStateListenerTask: Task<Void, Never>?
    private var connectionMonitorTask: Task<Void, Never>?
    private var realtimeChannels: [String: RealtimeChannel] = [:]
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Rate limiting
    private var rateLimiter = RateLimiter()
    
    // Caching
    private var cache = SupabaseCache()
    
    // Offline storage
    private var offlineStorage = OfflineStorage()
    
    // Retry logic
    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    private let retryDelay: TimeInterval = 2.0
    
    // MARK: - Initialization
    private init() {
        logger.info("Initializing SupabaseService")
        
        // Initialize Supabase client
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.Supabase.url)!,
            supabaseKey: Config.Supabase.anonKey
        )
        
        // Initialize components
        self.storage = SupabaseStorage(client: client)
        self.auth = SupabaseAuth(client: client)
        self.database = SupabaseDatabase(client: client)
        self.realtime = SupabaseRealtime(client: client)
        
        // Setup monitoring and listeners
        setupNetworkMonitoring()
        setupAuthStateListener()
        setupConnectionMonitoring()
        
        // Validate configuration
        validateConfiguration()
        
        logger.info("SupabaseService initialized successfully")
    }
    
    // MARK: - Configuration Validation
    private func validateConfiguration() {
        guard Config.validateConfiguration() else {
            logger.error("Invalid Supabase configuration")
            syncStatus = .error
            return
        }
        
        logger.info("Configuration validated successfully")
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkChange(path: path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func handleNetworkChange(path: NWPath) {
        let newStatus: NetworkStatus = path.status == .satisfied ? .connected : .disconnected
        
        if networkStatus != newStatus {
            networkStatus = newStatus
            isOfflineMode = newStatus == .disconnected
            
            logger.info("Network status changed: \(newStatus)")
            
            if newStatus == .connected {
                // Network restored, attempt to sync offline changes
                Task {
                    await syncOfflineChanges()
                }
            }
        }
    }
    
    // MARK: - Connection Monitoring
    private func setupConnectionMonitoring() {
        connectionMonitorTask = Task {
            while !Task.isCancelled {
                await checkConnection()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }
    
    private func checkConnection() async {
        guard networkStatus == .connected else {
            isConnected = false
            syncStatus = .offline
            return
        }
        
        do {
            // Simple health check
            let _ = try await client.database
                .from("health_check")
                .select("id")
                .limit(1)
                .execute()
            
            if !isConnected {
                isConnected = true
                syncStatus = currentUser != nil ? .connected : .disconnected
                retryCount = 0
                logger.info("Supabase connection restored")
            }
        } catch {
            if isConnected {
                isConnected = false
                syncStatus = .disconnected
                logger.error("Supabase connection lost: \(error)")
            }
            
            await handleConnectionError(error)
        }
    }
    
    private func handleConnectionError(_ error: Error) async {
        if retryCount < maxRetries {
            retryCount += 1
            let delay = retryDelay * Double(retryCount)
            
            logger.info("Retrying connection in \(delay) seconds (attempt \(retryCount)/\(maxRetries))")
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await checkConnection()
        } else {
            logger.error("Max connection retries exceeded")
            syncStatus = .error
        }
    }
    
    // MARK: - Authentication State Listener
    private func setupAuthStateListener() {
        authStateListenerTask = Task {
            for await (event, session) in client.auth.authStateChanges {
                await handleAuthStateChange(event: event, session: session)
            }
        }
    }
    
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        logger.info("Auth state changed: \(event)")
        
        switch event {
        case .signedIn:
            if let user = session?.user {
                currentUser = user
                authState = .authenticated
                await syncUserData(user: user)
                await startRealtimeSubscriptions()
            }
        case .signedOut:
            currentUser = nil
            authState = .unauthenticated
            await stopRealtimeSubscriptions()
            await clearCache()
        case .tokenRefreshed:
            logger.info("Token refreshed")
        default:
            break
        }
    }
    
    // MARK: - Authentication Methods
    public func signUp(email: String, password: String, metadata: [String: Any] = [:]) async throws -> User {
        logger.info("Signing up user with email: \(email)")
        
        guard await rateLimiter.canMakeRequest(for: "signup") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )
            
            guard let user = response.user else {
                throw SupabaseError.authenticationFailed
            }
            
            await createUserProfile(user: user, metadata: metadata)
            logger.info("User signed up successfully: \(user.id)")
            return user
            
        } catch {
            logger.error("Sign up failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func signIn(email: String, password: String) async throws -> User {
        logger.info("Signing in user with email: \(email)")
        
        guard await rateLimiter.canMakeRequest(for: "signin") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let response = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            guard let user = response.user else {
                throw SupabaseError.authenticationFailed
            }
            
            logger.info("User signed in successfully: \(user.id)")
            return user
            
        } catch {
            logger.error("Sign in failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func signInWithOAuth(provider: OAuthProvider) async throws -> User {
        logger.info("Signing in with OAuth provider: \(provider)")
        
        guard await rateLimiter.canMakeRequest(for: "oauth") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let response = try await client.auth.signInWithOAuth(provider: provider)
            
            guard let user = response.user else {
                throw SupabaseError.authenticationFailed
            }
            
            logger.info("OAuth sign in successful: \(user.id)")
            return user
            
        } catch {
            logger.error("OAuth sign in failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func signOut() async throws {
        logger.info("Signing out user")
        
        do {
            try await client.auth.signOut()
            logger.info("User signed out successfully")
        } catch {
            logger.error("Sign out failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func resetPassword(email: String) async throws {
        logger.info("Resetting password for email: \(email)")
        
        guard await rateLimiter.canMakeRequest(for: "reset_password") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            try await client.auth.resetPassword(email: email)
            logger.info("Password reset email sent")
        } catch {
            logger.error("Password reset failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func updatePassword(_ password: String) async throws {
        logger.info("Updating user password")
        
        guard currentUser != nil else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            try await client.auth.update(password: password)
            logger.info("Password updated successfully")
        } catch {
            logger.error("Password update failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func updateEmail(_ email: String) async throws {
        logger.info("Updating user email to: \(email)")
        
        guard currentUser != nil else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            try await client.auth.update(email: email)
            logger.info("Email updated successfully")
        } catch {
            logger.error("Email update failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func getCurrentUser() async throws -> User? {
        do {
            return try await client.auth.user
        } catch {
            logger.error("Failed to get current user: \(error)")
            throw handleError(error)
        }
    }
    
    public func getSession() async throws -> Session? {
        do {
            return try await client.auth.session
        } catch {
            logger.error("Failed to get session: \(error)")
            throw handleError(error)
        }
    }
    
    public func refreshSession() async throws -> Session {
        logger.info("Refreshing session")
        
        do {
            let session = try await client.auth.refreshSession()
            logger.info("Session refreshed successfully")
            return session
        } catch {
            logger.error("Session refresh failed: \(error)")
            throw handleError(error)
        }
    }
    
    // MARK: - User Profile Management
    private func createUserProfile(user: User, metadata: [String: Any] = [:]) async {
        logger.info("Creating user profile for: \(user.id)")
        
        do {
            let profile = UserProfile(
                id: user.id.uuidString,
                email: user.email ?? "",
                createdAt: Date(),
                updatedAt: Date(),
                metadata: metadata
            )
            
            try await database.insert(table: "profiles", data: profile)
            logger.info("User profile created successfully")
        } catch {
            logger.error("Failed to create user profile: \(error)")
        }
    }
    
    private func syncUserData(user: User) async {
        logger.info("Syncing user data for: \(user.id)")
        
        do {
            let profile = try await database.select(
                table: "profiles",
                filter: DatabaseFilter(column: "id", value: user.id.uuidString)
            )
            
            currentUser = user
            syncStatus = .connected
            logger.info("User data synced successfully")
        } catch {
            logger.error("Failed to sync user data: \(error)")
        }
    }
    
    public func getUserProfile(userId: String? = nil) async throws -> UserProfile? {
        let targetUserId = userId ?? currentUser?.id.uuidString
        
        guard let targetUserId = targetUserId else {
            throw SupabaseError.authenticationFailed
        }
        
        // Check cache first
        if let cachedProfile: UserProfile = await cache.get(key: "profile_\(targetUserId)") {
            return cachedProfile
        }
        
        do {
            let profile: UserProfile? = try await database.selectSingle(
                table: "profiles",
                filter: DatabaseFilter(column: "id", value: targetUserId)
            )
            
            // Cache the result
            if let profile = profile {
                await cache.set(key: "profile_\(targetUserId)", value: profile, ttl: 300) // 5 minutes
            }
            
            return profile
        } catch {
            logger.error("Failed to get user profile: \(error)")
            throw handleError(error)
        }
    }
    
    public func updateUserProfile(_ profile: UserProfile) async throws -> UserProfile {
        logger.info("Updating user profile: \(profile.id)")
        
        guard currentUser?.id.uuidString == profile.id else {
            throw SupabaseError.unauthorized
        }
        
        do {
            let updatedProfile = try await database.update(
                table: "profiles",
                id: profile.id,
                data: profile
            )
            
            // Update cache
            await cache.set(key: "profile_\(profile.id)", value: updatedProfile, ttl: 300)
            
            logger.info("User profile updated successfully")
            return updatedProfile
        } catch {
            logger.error("Failed to update user profile: \(error)")
            throw handleError(error)
        }
    }
    
    // MARK: - Database Operations
    public func insert<T: Codable>(table: String, data: T) async throws -> T {
        logger.info("Inserting data into table: \(table)")
        
        if isOfflineMode {
            await offlineStorage.queueOperation(.insert, table: table, data: data)
            return data // Return optimistically
        }
        
        guard await rateLimiter.canMakeRequest(for: "database_write") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let result = try await database.insert(table: table, data: data)
            logger.info("Data inserted successfully into \(table)")
            return result
        } catch {
            // Queue for offline sync
            await offlineStorage.queueOperation(.insert, table: table, data: data)
            logger.error("Database insert failed, queued for offline sync: \(error)")
            throw handleError(error)
        }
    }
    
    public func select<T: Codable>(
        table: String,
        type: T.Type,
        filter: DatabaseFilter? = nil,
        orderBy: DatabaseOrder? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [T] {
        logger.info("Selecting data from table: \(table)")
        
        // Generate cache key
        let cacheKey = generateCacheKey(table: table, filter: filter, orderBy: orderBy, limit: limit, offset: offset)
        
        // Check cache first
        if let cachedData: [T] = await cache.get(key: cacheKey) {
            logger.info("Returning cached data for \(table)")
            return cachedData
        }
        
        guard await rateLimiter.canMakeRequest(for: "database_read") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let results = try await database.select(
                table: table,
                type: type,
                filter: filter,
                orderBy: orderBy,
                limit: limit,
                offset: offset
            )
            
            // Cache the results
            await cache.set(key: cacheKey, value: results, ttl: 60) // 1 minute
            
            logger.info("Data selected successfully from \(table)")
            return results
        } catch {
            logger.error("Database select failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func selectSingle<T: Codable>(
        table: String,
        type: T.Type,
        filter: DatabaseFilter
    ) async throws -> T? {
        let results: [T] = try await select(table: table, type: type, filter: filter, limit: 1)
        return results.first
    }
    
    public func update<T: Codable>(table: String, id: String, data: T) async throws -> T {
        logger.info("Updating data in table: \(table), id: \(id)")
        
        if isOfflineMode {
            await offlineStorage.queueOperation(.update, table: table, id: id, data: data)
            return data // Return optimistically
        }
        
        guard await rateLimiter.canMakeRequest(for: "database_write") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let result = try await database.update(table: table, id: id, data: data)
            
            // Invalidate cache
            await cache.invalidate(pattern: "\(table)_*")
            
            logger.info("Data updated successfully in \(table)")
            return result
        } catch {
            // Queue for offline sync
            await offlineStorage.queueOperation(.update, table: table, id: id, data: data)
            logger.error("Database update failed, queued for offline sync: \(error)")
            throw handleError(error)
        }
    }
    
    public func delete(table: String, id: String) async throws {
        logger.info("Deleting data from table: \(table), id: \(id)")
        
        if isOfflineMode {
            await offlineStorage.queueOperation(.delete, table: table, id: id)
            return // Return optimistically
        }
        
        guard await rateLimiter.canMakeRequest(for: "database_write") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            try await database.delete(table: table, id: id)
            
            // Invalidate cache
            await cache.invalidate(pattern: "\(table)_*")
            
            logger.info("Data deleted successfully from \(table)")
        } catch {
            // Queue for offline sync
            await offlineStorage.queueOperation(.delete, table: table, id: id)
            logger.error("Database delete failed, queued for offline sync: \(error)")
            throw handleError(error)
        }
    }
    
    public func batchInsert<T: Codable>(table: String, data: [T]) async throws -> [T] {
        logger.info("Batch inserting \(data.count) items into table: \(table)")
        
        if isOfflineMode {
            for item in data {
                await offlineStorage.queueOperation(.insert, table: table, data: item)
            }
            return data // Return optimistically
        }
        
        guard await rateLimiter.canMakeRequest(for: "database_batch_write") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let results = try await database.batchInsert(table: table, data: data)
            logger.info("Batch insert successful for \(table)")
            return results
        } catch {
            // Queue for offline sync
            for item in data {
                await offlineStorage.queueOperation(.insert, table: table, data: item)
            }
            logger.error("Batch insert failed, queued for offline sync: \(error)")
            throw handleError(error)
        }
    }
    
    public func batchUpdate<T: Codable>(table: String, updates: [(id: String, data: T)]) async throws {
        logger.info("Batch updating \(updates.count) items in table: \(table)")
        
        if isOfflineMode {
            for update in updates {
                await offlineStorage.queueOperation(.update, table: table, id: update.id, data: update.data)
            }
            return // Return optimistically
        }
        
        guard await rateLimiter.canMakeRequest(for: "database_batch_write") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            try await database.batchUpdate(table: table, updates: updates)
            
            // Invalidate cache
            await cache.invalidate(pattern: "\(table)_*")
            
            logger.info("Batch update successful for \(table)")
        } catch {
            // Queue for offline sync
            for update in updates {
                await offlineStorage.queueOperation(.update, table: table, id: update.id, data: update.data)
            }
            logger.error("Batch update failed, queued for offline sync: \(error)")
            throw handleError(error)
        }
    }
    
    public func batchDelete(table: String, ids: [String]) async throws {
        logger.info("Batch deleting \(ids.count) items from table: \(table)")
        
        if isOfflineMode {
            for id in ids {
                await offlineStorage.queueOperation(.delete, table: table, id: id)
            }
            return // Return optimistically
        }
        
        guard await rateLimiter.canMakeRequest(for: "database_batch_write") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            try await database.batchDelete(table: table, ids: ids)
            
            // Invalidate cache
            await cache.invalidate(pattern: "\(table)_*")
            
            logger.info("Batch delete successful for \(table)")
        } catch {
            // Queue for offline sync
            for id in ids {
                await offlineStorage.queueOperation(.delete, table: table, id: id)
            }
            logger.error("Batch delete failed, queued for offline sync: \(error)")
            throw handleError(error)
        }
    }
    
    // MARK: - Real-time Subscriptions
    public func subscribeToTable(
        table: String,
        filter: DatabaseFilter? = nil,
        callback: @escaping (RealtimeMessage) -> Void
    ) throws -> String {
        logger.info("Subscribing to table: \(table)")
        
        let channelId = UUID().uuidString
        let channel = client.realtime.channel("public:\(table)")
        
        var subscription = channel.on(.all)
        
        if let filter = filter {
            subscription = subscription.filter(filter.column, "eq", filter.value)
        }
        
        subscription.subscribe { payload in
            callback(payload)
        }
        
        try channel.subscribe()
        realtimeChannels[channelId] = channel
        
        logger.info("Subscribed to table \(table) with channel ID: \(channelId)")
        return channelId
    }
    
    public func subscribeToUserData(
        userId: String,
        callback: @escaping (RealtimeMessage) -> Void
    ) throws -> String {
        logger.info("Subscribing to user data for: \(userId)")
        
        return try subscribeToTable(
            table: "profiles",
            filter: DatabaseFilter(column: "id", value: userId),
            callback: callback
        )
    }
    
    public func unsubscribe(channelId: String) {
        logger.info("Unsubscribing from channel: \(channelId)")
        
        if let channel = realtimeChannels[channelId] {
            channel.unsubscribe()
            realtimeChannels.removeValue(forKey: channelId)
        }
    }
    
    private func startRealtimeSubscriptions() async {
        logger.info("Starting realtime subscriptions")
        
        guard let userId = currentUser?.id.uuidString else { return }
        
        // Subscribe to user-specific updates
        do {
            let _ = try subscribeToUserData(userId: userId) { [weak self] message in
                Task { @MainActor in
                    await self?.handleUserDataUpdate(message)
                }
            }
        } catch {
            logger.error("Failed to start realtime subscriptions: \(error)")
        }
    }
    
    private func stopRealtimeSubscriptions() async {
        logger.info("Stopping realtime subscriptions")
        
        for (channelId, _) in realtimeChannels {
            unsubscribe(channelId: channelId)
        }
    }
    
    private func handleUserDataUpdate(_ message: RealtimeMessage) async {
        logger.info("Received user data update: \(message.eventType)")
        
        // Handle the realtime message
        switch message.eventType {
        case .insert, .update:
            // Invalidate user cache
            if let userId = currentUser?.id.uuidString {
                await cache.invalidate(key: "profile_\(userId)")
            }
        case .delete:
            // Handle user deletion
            break
        default:
            break
        }
    }
    
    // MARK: - File Storage Operations
    public func uploadFile(
        bucket: String,
        fileName: String,
        data: Data,
        contentType: String? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> UploadResponse {
        logger.info("Uploading file: \(fileName) to bucket: \(bucket)")
        
        guard await rateLimiter.canMakeRequest(for: "storage_upload") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let response = try await storage.upload(
                bucket: bucket,
                fileName: fileName,
                data: data,
                contentType: contentType,
                progressHandler: progressHandler
            )
            
            logger.info("File uploaded successfully: \(fileName)")
            return response
        } catch {
            logger.error("File upload failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func downloadFile(
        bucket: String,
        fileName: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Data {
        logger.info("Downloading file: \(fileName) from bucket: \(bucket)")
        
        // Check cache first
        let cacheKey = "file_\(bucket)_\(fileName)"
        if let cachedData: Data = await cache.get(key: cacheKey) {
            logger.info("Returning cached file data for \(fileName)")
            return cachedData
        }
        
        guard await rateLimiter.canMakeRequest(for: "storage_download") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let data = try await storage.download(
                bucket: bucket,
                fileName: fileName,
                progressHandler: progressHandler
            )
            
            // Cache the file data (with shorter TTL for large files)
            let ttl = data.count > 1024 * 1024 ? 300 : 3600 // 5 min for large files, 1 hour for small
            await cache.set(key: cacheKey, value: data, ttl: ttl)
            
            logger.info("File downloaded successfully: \(fileName)")
            return data
        } catch {
            logger.error("File download failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func deleteFile(bucket: String, fileName: String) async throws {
        logger.info("Deleting file: \(fileName) from bucket: \(bucket)")
        
        guard await rateLimiter.canMakeRequest(for: "storage_delete") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            try await storage.delete(bucket: bucket, fileName: fileName)
            
            // Remove from cache
            await cache.invalidate(key: "file_\(bucket)_\(fileName)")
            
            logger.info("File deleted successfully: \(fileName)")
        } catch {
            logger.error("File deletion failed: \(error)")
            throw handleError(error)
        }
    }
    
    public func getFileUrl(bucket: String, fileName: String) async throws -> URL {
        logger.info("Getting file URL for: \(fileName) in bucket: \(bucket)")
        
        do {
            let url = try await storage.getPublicUrl(bucket: bucket, fileName: fileName)
            logger.info("File URL generated successfully for: \(fileName)")
            return url
        } catch {
            logger.error("Failed to get file URL: \(error)")
            throw handleError(error)
        }
    }
    
    public func listFiles(bucket: String, prefix: String? = nil) async throws -> [FileInfo] {
        logger.info("Listing files in bucket: \(bucket)")
        
        let cacheKey = "files_\(bucket)_\(prefix ?? "")"
        if let cachedFiles: [FileInfo] = await cache.get(key: cacheKey) {
            return cachedFiles
        }
        
        guard await rateLimiter.canMakeRequest(for: "storage_list") else {
            throw SupabaseError.rateLimitExceeded
        }
        
        do {
            let files = try await storage.list(bucket: bucket, prefix: prefix)
            
            // Cache the file list
            await cache.set(key: cacheKey, value: files, ttl: 300) // 5 minutes
            
            logger.info("Files listed successfully from bucket: \(bucket)")
            return files
        } catch {
            logger.error("Failed to list files: \(error)")
            throw handleError(error)
        }
    }
    
    // MARK: - Specialized Operations
    public func uploadAvatar(userId: String, imageData: Data) async throws -> String {
        logger.info("Uploading avatar for user: \(userId)")
        
        let fileName = "avatar_\(userId)_\(Date().timeIntervalSince1970).jpg"
        
        let response = try await uploadFile(
            bucket: "avatars",
            fileName: fileName,
            data: imageData,
            contentType: "image/jpeg"
        )
        
        let avatarUrl = try await getFileUrl(bucket: "avatars", fileName: fileName)
        
        // Update user profile with new avatar URL
        if var profile = try await getUserProfile(userId: userId) {
            profile.avatarUrl = avatarUrl.absoluteString
            try await updateUserProfile(profile)
        }
        
        logger.info("Avatar uploaded successfully for user: \(userId)")
        return avatarUrl.absoluteString
    }
    
    public func uploadThumbnail(streamId: String, imageData: Data) async throws -> String {
        logger.info("Uploading thumbnail for stream: \(streamId)")
        
        let fileName = "thumbnail_\(streamId)_\(Date().timeIntervalSince1970).jpg"
        
        let response = try await uploadFile(
            bucket: "thumbnails",
            fileName: fileName,
            data: imageData,
            contentType: "image/jpeg"
        )
        
        let thumbnailUrl = try await getFileUrl(bucket: "thumbnails", fileName: fileName)
        
        logger.info("Thumbnail uploaded successfully for stream: \(streamId)")
        return thumbnailUrl.absoluteString
    }
    
    // MARK: - Offline Mode Support
    private func syncOfflineChanges() async {
        logger.info("Syncing offline changes")
        
        guard isConnected && !isOfflineMode else {
            logger.info("Cannot sync offline changes - not connected")
            return
        }
        
        syncStatus = .syncing
        
        do {
            let operations = await offlineStorage.getPendingOperations()
            
            for operation in operations {
                do {
                    try await executeOfflineOperation(operation)
                    await offlineStorage.markOperationCompleted(operation.id)
                } catch {
                    logger.error("Failed to execute offline operation: \(error)")
                    await offlineStorage.markOperationFailed(operation.id, error: error)
                }
            }
            
            syncStatus = .synced
            lastSyncTime = Date()
            logger.info("Offline changes synced successfully")
        } catch {
            logger.error("Failed to sync offline changes: \(error)")
            syncStatus = .error
        }
    }
    
    private func executeOfflineOperation(_ operation: OfflineOperation) async throws {
        switch operation.type {
        case .insert:
            let _ = try await database.insert(table: operation.table, data: operation.data)
        case .update:
            let _ = try await database.update(table: operation.table, id: operation.id!, data: operation.data)
        case .delete:
            try await database.delete(table: operation.table, id: operation.id!)
        }
    }
    
    // MARK: - Cache Management
    private func generateCacheKey(
        table: String,
        filter: DatabaseFilter?,
        orderBy: DatabaseOrder?,
        limit: Int?,
        offset: Int?
    ) -> String {
        var key = "\(table)"
        
        if let filter = filter {
            key += "_\(filter.column)_\(filter.value)"
        }
        
        if let orderBy = orderBy {
            key += "_\(orderBy.column)_\(orderBy.ascending ? "asc" : "desc")"
        }
        
        if let limit = limit {
            key += "_limit_\(limit)"
        }
        
        if let offset = offset {
            key += "_offset_\(offset)"
        }
        
        return key
    }
    
    private func clearCache() async {
        await cache.clear()
        logger.info("Cache cleared")
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) -> SupabaseError {
        if let supabaseError = error as? SupabaseError {
            return supabaseError
        }
        
        if let postgrestError = error as? PostgrestError {
            return .databaseError(postgrestError.localizedDescription)
        }
        
        if let authError = error as? AuthError {
            return .authenticationFailed
        }
        
        if let storageError = error as? StorageError {
            return .storageError(storageError.localizedDescription)
        }
        
        return .unknown(error.localizedDescription)
    }
    
    // MARK: - Health Check
    public func performHealthCheck() async -> HealthStatus {
        logger.info("Performing health check")
        
        var status = HealthStatus()
        
        // Check database connection
        do {
            let _ = try await client.database.from("health_check").select("id").limit(1).execute()
            status.database = .healthy
        } catch {
            status.database = .unhealthy
        }
        
        // Check authentication
        do {
            let _ = try await client.auth.session
            status.authentication = .healthy
        } catch {
            status.authentication = .unhealthy
        }
        
        // Check storage
        do {
            let _ = try await client.storage.listBuckets()
            status.storage = .healthy
        } catch {
            status.storage = .unhealthy
        }
        
        // Check realtime
        status.realtime = realtimeChannels.isEmpty ? .unknown : .healthy
        
        logger.info("Health check completed: \(status)")
        return status
    }
    
    // MARK: - Analytics and Logging
    public func logEvent(_ event: String, parameters: [String: Any] = [:]) {
        logger.info("Event: \(event), Parameters: \(parameters)")
        
        // Log to external analytics service if needed
        // AnalyticsService.shared.logEvent(event, parameters: parameters)
    }
    
    // MARK: - Cleanup
    deinit {
        logger.info("Deinitializing SupabaseService")
        
        authStateListenerTask?.cancel()
        connectionMonitorTask?.cancel()
        networkMonitor.cancel()
        
        for (_, channel) in realtimeChannels {
            channel.unsubscribe()
        }
        
        cancellables.removeAll()
    }
}

// MARK: - Computed Properties
extension SupabaseService {
    public var isAuthenticated: Bool {
        return authState == .authenticated && currentUser != nil
    }
    
    public var canSync: Bool {
        return isAuthenticated && isConnected && !isOfflineMode
    }
    
    public var healthStatus: String {
        if isOfflineMode {
            return "📴 Offline Mode"
        } else if !isConnected {
            return "❌ Disconnected"
        } else if !isAuthenticated {
            return "⚠️ Not authenticated"
        } else {
            return "✅ Healthy"
        }
    }
    
    public var syncStatusText: String {
        switch syncStatus {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error:
            return "Error"
        case .offline:
            return "Offline"
        }
    }
}

// MARK: - Supporting Types and Enums

// Auth State
public enum AuthState {
    case authenticated
    case unauthenticated
    case loading
}

// Network Status
public enum NetworkStatus {
    case connected
    case disconnected
    case unknown
}

// Sync Status
public enum SyncStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case syncing = "syncing"
    case synced = "synced"
    case error = "error"
    case offline = "offline"
    
    public var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .error: return "Error"
        case .offline: return "Offline"
        }
    }
    
    public var color: Color {
        switch self {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected: return .blue
        case .syncing: return .yellow
        case .synced: return .green
        case .error: return .red
        case .offline: return .gray
        }
    }
    
    public var icon: String {
        switch self {
        case .disconnected: return "wifi.slash"
        case .connecting: return "wifi.circle"
        case .connected: return "wifi"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.circle"
        case .error: return "exclamationmark.triangle"
        case .offline: return "airplane"
        }
    }
}

// Supabase Errors
public enum SupabaseError: Error, LocalizedError {
    case configurationInvalid
    case authenticationFailed
    case unauthorized
    case networkError(String)
    case databaseError(String)
    case storageError(String)
    case rateLimitExceeded
    case syncConflict
    case dataCorruption
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationInvalid:
            return "Supabase configuration is invalid"
        case .authenticationFailed:
            return "Authentication failed"
        case .unauthorized:
            return "Unauthorized access"
        case .networkError(let message):
            return "Network error: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .syncConflict:
            return "Sync conflict detected"
        case .dataCorruption:
            return "Data corruption detected"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .configurationInvalid:
            return "Please check your Supabase configuration in Config.swift"
        case .authenticationFailed:
            return "Please check your credentials and try again"
        case .unauthorized:
            return "Please sign in and try again"
        case .networkError:
            return "Please check your internet connection and try again"
        case .databaseError:
            return "Please try again later"
        case .storageError:
            return "Please try again later"
        case .rateLimitExceeded:
            return "Please wait a moment and try again"
        case .syncConflict:
            return "Please resolve the sync conflict and try again"
        case .dataCorruption:
            return "Please restore from backup or contact support"
        case .unknown:
            return "Please try again or contact support"
        }
    }
}

// Database Filter
public struct DatabaseFilter {
    public let column: String
    public let value: Any
    public let operator: String
    
    public init(column: String, value: Any, operator: String = "eq") {
        self.column = column
        self.value = value
        self.operator = `operator`
    }
}

// Database Order
public struct DatabaseOrder {
    public let column: String
    public let ascending: Bool
    
    public init(column: String, ascending: Bool = true) {
        self.column = column
        self.ascending = ascending
    }
}

// User Profile
public struct UserProfile: Codable {
    public var id: String
    public var email: String
    public var username: String?
    public var firstName: String?
    public var lastName: String?
    public var avatarUrl: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var metadata: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, email, username
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
    }
    
    public init(id: String, email: String, createdAt: Date, updatedAt: Date, metadata: [String: Any] = [:]) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

// Health Status
public struct HealthStatus {
    public var database: ComponentHealth = .unknown
    public var authentication: ComponentHealth = .unknown
    public var storage: ComponentHealth = .unknown
    public var realtime: ComponentHealth = .unknown
    
    public enum ComponentHealth {
        case healthy
        case unhealthy
        case unknown
    }
}

// Offline Operation
public struct OfflineOperation: Codable {
    public let id: String
    public let type: OperationType
    public let table: String
    public let data: Data
    public let id_: String?
    public let createdAt: Date
    public var retryCount: Int
    
    public enum OperationType: String, Codable {
        case insert
        case update
        case delete
    }
}

// Upload Response
public struct UploadResponse: Codable {
    public let path: String
    public let fullPath: String
    public let id: String
}

// File Info
public struct FileInfo: Codable {
    public let name: String
    public let id: String
    public let size: Int64
    public let createdAt: Date
    public let updatedAt: Date
    public let mimeType: String?
    
    enum CodingKeys: String, CodingKey {
        case name, id, size
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case mimeType = "mime_type"
    }
}

// Realtime Message
public struct RealtimeMessage {
    public let eventType: EventType
    public let schema: String
    public let table: String
    public let commit_timestamp: Date
    public let record: [String: Any]?
    public let old_record: [String: Any]?
    
    public enum EventType: String {
        case insert = "INSERT"
        case update = "UPDATE"
        case delete = "DELETE"
    }
}

// MARK: - Helper Classes

// Rate Limiter
private actor RateLimiter {
    private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]
    private let limits: [String: Int] = [
        "signup": 5,
        "signin": 10,
        "oauth": 10,
        "reset_password": 3,
        "database_read": 100,
        "database_write": 50,
        "database_batch_write": 10,
        "storage_upload": 20,
        "storage_download": 50,
        "storage_delete": 30,
        "storage_list": 30
    ]
    
    func canMakeRequest(for endpoint: String) -> Bool {
        let limit = limits[endpoint] ?? 60
        let window: TimeInterval = 60 // 1 minute
        
        let now = Date()
        
        if let entry = requestCounts[endpoint] {
            if now < entry.resetTime {
                if entry.count >= limit {
                    return false
                }
                requestCounts[endpoint] = (count: entry.count + 1, resetTime: entry.resetTime)
            } else {
                requestCounts[endpoint] = (count: 1, resetTime: now.addingTimeInterval(window))
            }
        } else {
            requestCounts[endpoint] = (count: 1, resetTime: now.addingTimeInterval(window))
        }
        
        return true
    }
}

// Cache
private actor SupabaseCache {
    private var cache: [String: CacheItem] = [:]
    
    private struct CacheItem {
        let data: Any
        let expiresAt: Date
    }
    
    func get<T>(key: String) -> T? {
        guard let item = cache[key] else { return nil }
        
        if Date() > item.expiresAt {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return item.data as? T
    }
    
    func set<T>(key: String, value: T, ttl: TimeInterval) {
        let expiresAt = Date().addingTimeInterval(ttl)
        cache[key] = CacheItem(data: value, expiresAt: expiresAt)
    }
    
    func invalidate(key: String) {
        cache.removeValue(forKey: key)
    }
    
    func invalidate(pattern: String) {
        let keys = cache.keys.filter { $0.contains(pattern.replacingOccurrences(of: "*", with: "")) }
        for key in keys {
            cache.removeValue(forKey: key)
        }
    }
    
    func clear() {
        cache.removeAll()
    }
}

// Offline Storage
private actor OfflineStorage {
    private var operations: [OfflineOperation] = []
    
    func queueOperation<T: Codable>(
        _ type: OfflineOperation.OperationType,
        table: String,
        data: T? = nil,
        id: String? = nil
    ) {
        let operation = OfflineOperation(
            id: UUID().uuidString,
            type: type,
            table: table,
            data: (try? JSONEncoder().encode(data)) ?? Data(),
            id_: id,
            createdAt: Date(),
            retryCount: 0
        )
        
        operations.append(operation)
    }
    
    func getPendingOperations() -> [OfflineOperation] {
        return operations.filter { $0.retryCount < 3 }
    }
    
    func markOperationCompleted(_ id: String) {
        operations.removeAll { $0.id == id }
    }
    
    func markOperationFailed(_ id: String, error: Error) {
        if let index = operations.firstIndex(where: { $0.id == id }) {
            operations[index].retryCount += 1
        }
    }
}

// Mock implementations for protocol conformance
private class SupabaseStorage {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func upload(
        bucket: String,
        fileName: String,
        data: Data,
        contentType: String?,
        progressHandler: ((Double) -> Void)?
    ) async throws -> UploadResponse {
        // Implementation would use client.storage.upload
        throw SupabaseError.unknown("Not implemented")
    }
    
    func download(
        bucket: String,
        fileName: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> Data {
        // Implementation would use client.storage.download
        throw SupabaseError.unknown("Not implemented")
    }
    
    func delete(bucket: String, fileName: String) async throws {
        // Implementation would use client.storage.delete
        throw SupabaseError.unknown("Not implemented")
    }
    
    func getPublicUrl(bucket: String, fileName: String) async throws -> URL {
        // Implementation would use client.storage.getPublicUrl
        throw SupabaseError.unknown("Not implemented")
    }
    
    func list(bucket: String, prefix: String?) async throws -> [FileInfo] {
        // Implementation would use client.storage.list
        throw SupabaseError.unknown("Not implemented")
    }
}

private class SupabaseAuth {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func signUp(email: String, password: String, data: [String: Any]) async throws -> AuthResponse {
        return try await client.auth.signUp(email: email, password: password, data: data)
    }
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        return try await client.auth.signIn(email: email, password: password)
    }
    
    func signInWithOAuth(provider: OAuthProvider) async throws -> AuthResponse {
        return try await client.auth.signInWithOAuth(provider: provider)
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await client.auth.resetPassword(email: email)
    }
    
    func update(password: String) async throws {
        try await client.auth.update(password: password)
    }
    
    func update(email: String) async throws {
        try await client.auth.update(email: email)
    }
}

private class SupabaseDatabase {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func insert<T: Codable>(table: String, data: T) async throws -> T {
        let response = try await client.database
            .from(table)
            .insert(data)
            .single()
            .execute()
        
        return try response.decoded(as: T.self)
    }
    
    func select<T: Codable>(
        table: String,
        type: T.Type,
        filter: DatabaseFilter? = nil,
        orderBy: DatabaseOrder? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [T] {
        var query = client.database.from(table).select("*")
        
        if let filter = filter {
            query = query.eq(filter.column, value: filter.value)
        }
        
        if let orderBy = orderBy {
            query = query.order(orderBy.column, ascending: orderBy.ascending)
        }
        
        if let limit = limit {
            query = query.limit(limit)
        }
        
        if let offset = offset {
            query = query.range(from: offset, to: offset + (limit ?? 100))
        }
        
        let response = try await query.execute()
        return try response.decoded(as: [T].self)
    }
    
    func selectSingle<T: Codable>(
        table: String,
        filter: DatabaseFilter
    ) async throws -> T? {
        let response = try await client.database
            .from(table)
            .select("*")
            .eq(filter.column, value: filter.value)
            .single()
            .execute()
        
        return try response.decoded(as: T.self)
    }
    
    func update<T: Codable>(table: String, id: String, data: T) async throws -> T {
        let response = try await client.database
            .from(table)
            .update(data)
            .eq("id", value: id)
            .single()
            .execute()
        
        return try response.decoded(as: T.self)
    }
    
    func delete(table: String, id: String) async throws {
        try await client.database
            .from(table)
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func batchInsert<T: Codable>(table: String, data: [T]) async throws -> [T] {
        let response = try await client.database
            .from(table)
            .insert(data)
            .execute()
        
        return try response.decoded(as: [T].self)
    }
    
    func batchUpdate<T: Codable>(table: String, updates: [(id: String, data: T)]) async throws {
        for update in updates {
            try await client.database
                .from(table)
                .update(update.data)
                .eq("id", value: update.id)
                .execute()
        }
    }
    
    func batchDelete(table: String, ids: [String]) async throws {
        try await client.database
            .from(table)
            .delete()
            .in("id", values: ids)
            .execute()
    }
}

private class SupabaseRealtime {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
}