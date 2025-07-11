//
//  SupabaseService.swift
//  StreamyyyApp
//
//  Real Clerk-authenticated Supabase service for database operations
//

import Foundation
import Supabase
import Combine
import SwiftUI

// Resolve naming conflict with local User model
typealias SupabaseUser = Supabase.User

// MARK: - Real Supabase Service with Clerk Integration
@MainActor
public class RealSupabaseService: ObservableObject {
    
    // MARK: - Properties
    public static let shared = RealSupabaseService()
    
    private let baseClient: SupabaseClient
    private var authenticatedClient: SupabaseClient?
    @Published public var isConnected: Bool = false
    @Published public var currentProfile: UserProfile?
    @Published public var currentUser: SupabaseUser?
    @Published public var syncStatus: SyncStatus = .disconnected
    @Published public var lastSyncTime: Date?
    
    private var cancellables = Set<AnyCancellable>()
    private var connectionMonitor: Timer?
    private var retryAttempts: Int = 0
    private let maxRetryAttempts: Int = 3
    private var currentSessionToken: String?
    
    // MARK: - Initialization
    private init() {
        // Initialize base Supabase client (for public operations)
        self.baseClient = SupabaseClient(
            supabaseURL: URL(string: Config.Supabase.url)!,
            supabaseKey: Config.Supabase.anonKey
        )
        
        setupConnectionMonitoring()
        observeClerkAuthentication()
    }
    
    // MARK: - Clerk Integration
    
    private func observeClerkAuthentication() {
        // Observe Clerk authentication state changes
        ClerkManager.shared.$isAuthenticated
            .combineLatest(ClerkManager.shared.$sessionToken)
            .sink { [weak self] isAuthenticated, sessionToken in
                if isAuthenticated, let token = sessionToken {
                    self?.setupAuthenticatedClient(sessionToken: token)
                } else {
                    self?.clearAuthenticatedClient()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAuthenticatedClient(sessionToken: String) {
        currentSessionToken = sessionToken
        
        // Create authenticated client with Clerk session token
        authenticatedClient = SupabaseClient(
            supabaseURL: URL(string: Config.Supabase.url)!,
            supabaseKey: Config.Supabase.anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseAuthClientOptions(
                    accessToken: { @MainActor in
                        return sessionToken
                    }
                )
            )
        )
        
        syncStatus = .connected
        isConnected = true
        
        print("✅ Supabase authenticated client setup completed")
    }
    
    private func clearAuthenticatedClient() {
        authenticatedClient = nil
        currentSessionToken = nil
        currentProfile = nil
        syncStatus = .disconnected
        isConnected = false
        
        print("ℹ️ Supabase authenticated client cleared")
    }
    
    // MARK: - Client Access
    
    private var client: SupabaseClient {
        return authenticatedClient ?? baseClient
    }
    
    private func requireAuthentication() throws {
        guard authenticatedClient != nil else {
            throw SupabaseError.authenticationRequired
        }
    }
    
    // MARK: - User Profile Management (Clerk Integration)
    
    public func syncUserProfile(clerkUser: ClerkUser, sessionToken: String) async {
        do {
            currentSessionToken = sessionToken
            
            // Check if profile exists
            let existingProfile = try await getUserProfile(clerkUserId: clerkUser.id)
            
            if let profile = existingProfile {
                // Update existing profile
                let updatedProfile = try await updateUserProfile(clerkUser: clerkUser, sessionToken: sessionToken)
                currentProfile = updatedProfile
            } else {
                // Create new profile
                let newProfile = try await createUserProfile(clerkUser: clerkUser, sessionToken: sessionToken)
                currentProfile = newProfile
            }
            
            syncStatus = .synced
            lastSyncTime = Date()
            
        } catch {
            print("❌ Failed to sync user profile: \(error)")
            syncStatus = .error
        }
    }
    
    public func syncUserProfile(clerkUser: ClerkUser, sessionToken: String) async {
        do {
            try await createUserProfile(clerkUser: clerkUser, sessionToken: sessionToken)
        } catch {
            print("Failed to sync user profile: \(error)")
        }
    }
    
    public func createUserProfile(clerkUser: ClerkUser, sessionToken: String) async throws -> UserProfile {
        try requireAuthentication()
        
        let profile = UserProfile(
            id: UUID().uuidString,
            clerkUserId: clerkUser.id,
            stripeCustomerId: nil,
            email: clerkUser.primaryEmailAddress?.emailAddress ?? "",
            fullName: clerkUser.displayName,
            avatarUrl: clerkUser.profileImageUrl,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let response = try await client.database
            .from("profiles")
            .insert(profile)
            .select()
            .single()
            .execute()
        
        let createdProfile = try response.value.decode(as: UserProfile.self)
        print("✅ User profile created in Supabase")
        
        return createdProfile
    }
    
    public func updateUserProfile(clerkUser: ClerkUser, sessionToken: String) async throws -> UserProfile {
        try requireAuthentication()
        
        let updateData: [String: Any] = [
            "email": clerkUser.primaryEmailAddress?.emailAddress ?? "",
            "full_name": clerkUser.displayName,
            "avatar_url": clerkUser.profileImageUrl ?? NSNull(),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let response = try await client.database
            .from("profiles")
            .update(updateData)
            .eq("clerk_user_id", value: clerkUser.id)
            .select()
            .single()
            .execute()
        
        let updatedProfile = try response.value.decode(as: UserProfile.self)
        print("✅ User profile updated in Supabase")
        
        return updatedProfile
    }
    
    public func getUserProfile(clerkUserId: String) async throws -> UserProfile? {
        let response = try await client.database
            .from("profiles")
            .select("*")
            .eq("clerk_user_id", value: clerkUserId)
            .maybeSingle()
            .execute()
        
        return try response.value.decode(as: UserProfile?.self)
    }
    
    public func signOut() {
        clearAuthenticatedClient()
        currentProfile = nil
        syncStatus = .disconnected
        lastSyncTime = nil
    }
    
    // MARK: - Connection Management
    private func setupConnectionMonitoring() {
        connectionMonitor = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.checkConnection()
            }
        }
    }
    
    private func checkConnection() async {
        do {
            // Simple ping to check connection
            _ = try await client.database.from("streams").select("id").limit(1).execute()
            
            if !isConnected {
                isConnected = true
                syncStatus = currentUser != nil ? .connected : .disconnected
                retryAttempts = 0
                print("✅ Supabase connection restored")
            }
        } catch {
            if isConnected {
                isConnected = false
                syncStatus = .disconnected
                print("❌ Supabase connection lost: \(error)")
            }
            
            // Retry connection
            if retryAttempts < maxRetryAttempts {
                retryAttempts += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryAttempts * 5)) {
                    Task {
                        await self.checkConnection()
                    }
                }
            }
        }
    }
    
    // MARK: - User Profile Management
    private func createUserProfile(user: SupabaseUser) async {
        do {
            let profile: [String: Any] = [
                "id": user.id.uuidString,
                "email": user.email ?? "",
                "created_at": ISO8601DateFormatter().string(from: Date()),
                "updated_at": ISO8601DateFormatter().string(from: Date()),
                "is_active": true
            ]
            
            try await client.database
                .from("users")
                .insert(profile)
                .execute()
            
            print("✅ User profile created")
        } catch {
            print("❌ Failed to create user profile: \(error)")
        }
    }
    
    private func syncUserData(user: SupabaseUser) async {
        do {
            let response = try await client.database
                .from("users")
                .select("*")
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
            
            // Update local user data
            currentUser = user
            syncStatus = .connected
            
            print("✅ User data synced")
        } catch {
            print("❌ Failed to sync user data: \(error)")
        }
    }
    
    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        client.auth.onAuthStateChange { [weak self] event, session in
            Task { @MainActor in
                switch event {
                case .signedIn:
                    self?.currentUser = session?.user
                    self?.syncStatus = .connected
                    print("✅ User signed in")
                case .signedOut:
                    self?.currentUser = nil
                    self?.syncStatus = .disconnected
                    print("ℹ️ User signed out")
                case .tokenRefreshed:
                    print("🔄 Token refreshed")
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Database Operations
    public func executeQuery<T: Codable>(
        table: String,
        query: PostgrestQueryBuilder,
        type: T.Type
    ) async throws -> [T] {
        do {
            let response = try await query.execute()
            return try JSONDecoder().decode([T].self, from: response.data)
        } catch {
            throw handleError(error)
        }
    }
    
    public func insert<T: Codable>(
        table: String,
        data: T
    ) async throws -> T {
        do {
            let response = try await client.database
                .from(table)
                .insert(data)
                .single()
                .execute()
            
            return try JSONDecoder().decode(T.self, from: response.data)
        } catch {
            throw handleError(error)
        }
    }
    
    public func update<T: Codable>(
        table: String,
        id: String,
        data: [String: Any]
    ) async throws -> T {
        do {
            let response = try await client.database
                .from(table)
                .update(data)
                .eq("id", value: id)
                .single()
                .execute()
            
            return try JSONDecoder().decode(T.self, from: response.data)
        } catch {
            throw handleError(error)
        }
    }
    
    public func delete(
        table: String,
        id: String
    ) async throws {
        do {
            try await client.database
                .from(table)
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Real-time Subscriptions
    public func subscribeToTable(
        table: String,
        callback: @escaping (RealtimeMessage) -> Void
    ) async throws -> RealtimeChannel {
        let channel = client.realtime.channel("public:\(table)")
        
        await channel.on(.all) { payload in
            callback(payload)
        }
        
        await channel.subscribe()
        return channel
    }
    
    public func unsubscribe(channel: RealtimeChannel) async {
        await channel.unsubscribe()
    }
    
    // MARK: - Batch Operations
    public func batchInsert<T: Codable>(
        table: String,
        data: [T]
    ) async throws -> [T] {
        do {
            let response = try await client.database
                .from(table)
                .insert(data)
                .execute()
            
            return try JSONDecoder().decode([T].self, from: response.data)
        } catch {
            throw handleError(error)
        }
    }
    
    public func batchUpdate(
        table: String,
        updates: [(id: String, data: [String: Any])]
    ) async throws {
        // Supabase doesn't support batch updates natively, so we'll do them sequentially
        for update in updates {
            try await client.database
                .from(table)
                .update(update.data)
                .eq("id", value: update.id)
                .execute()
        }
    }
    
    public func batchDelete(
        table: String,
        ids: [String]
    ) async throws {
        try await client.database
            .from(table)
            .delete()
            .in("id", values: ids)
            .execute()
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) -> SupabaseError {
        if let postgrestError = error as? PostgrestError {
            return .databaseError(postgrestError.localizedDescription)
        }
        
        if let authError = error as? AuthError {
            return .authenticationFailed
        }
        
        return .unknown(error.localizedDescription)
    }
    
    // MARK: - Sync Status Updates
    public func updateSyncStatus(_ status: SyncStatus) {
        syncStatus = status
        if status == .synced {
            lastSyncTime = Date()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        connectionMonitor?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Sync Status Enum
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

// MARK: - Supporting Models for Database Sync

public struct SyncLayout: Codable {
    let id: String
    let userId: String
    let name: String
    let layoutData: Data
    let isDefault: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, isDefault, createdAt, updatedAt
        case userId = "user_id"
        case layoutData = "layout_data"
    }
    
    init(from layout: Layout, userId: String) {
        self.id = layout.id
        self.userId = userId
        self.name = layout.name
        // Convert layout to JSON data
        if let dict = layout.toDictionary(),
           let jsonData = try? JSONSerialization.data(withJSONObject: dict) {
            self.layoutData = jsonData
        } else {
            self.layoutData = Data()
        }
        self.isDefault = layout.isDefault
        self.createdAt = layout.createdAt
        self.updatedAt = layout.updatedAt
    }
    
    func toLayout() -> Layout {
        let layout = Layout(name: name, type: .custom, configuration: LayoutConfiguration())
        layout.id = id
        layout.isDefault = isDefault
        layout.createdAt = createdAt
        layout.updatedAt = updatedAt
        return layout
    }
    
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

public struct SyncStream: Codable {
    let id: String
    let userId: String
    let url: String
    let platform: String
    let streamerName: String
    let isLive: Bool
    let viewerCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, url, platform, isLive, viewerCount, createdAt, updatedAt
        case userId = "user_id"
        case streamerName = "streamer_name"
    }
    
    init(from stream: Stream, userId: String) {
        self.id = stream.id
        self.userId = userId
        self.url = stream.url
        self.platform = stream.platform.rawValue
        self.streamerName = stream.streamerName ?? ""
        self.isLive = stream.isLive
        self.viewerCount = stream.viewerCount
        self.createdAt = stream.createdAt
        self.updatedAt = stream.updatedAt
    }
    
    func toStream() -> Stream {
        let stream = Stream(
            id: id,
            url: url,
            platform: Platform(rawValue: platform) ?? .twitch,
            title: streamerName
        )
        // Set additional properties
        stream.streamerName = streamerName
        stream.isLive = isLive
        stream.viewerCount = viewerCount
        stream.createdAt = createdAt
        stream.updatedAt = updatedAt
        return stream
    }
}

public struct SyncStreamSession: Codable {
    let id: String
    let userId: String
    let streamId: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let quality: String
    let deviceType: String
    
    enum CodingKeys: String, CodingKey {
        case id, duration, quality, startTime, endTime
        case userId = "user_id"
        case streamId = "stream_id"
        case deviceType = "device_type"
    }
    
    init(from session: StreamSession, userId: String) {
        self.id = session.id
        self.userId = userId
        self.streamId = session.streamId
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.duration = session.duration
        self.quality = session.quality.rawValue
        self.deviceType = "iOS"
    }
    
    func toStreamSession() -> StreamSession {
        return StreamSession(
            id: id,
            streamId: streamId,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            quality: StreamQuality(rawValue: quality) ?? .auto
        )
    }
    
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

public struct SyncStreamAnalytics: Codable {
    let id: String = UUID().uuidString
    let userId: String
    let streamId: String
    let event: String
    let timestamp: Date
    let metadata: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case id, event, timestamp, metadata
        case userId = "user_id"
        case streamId = "stream_id"
    }
    
    init(from analytics: StreamAnalytics, userId: String) {
        self.userId = userId
        self.streamId = analytics.streamId
        self.event = analytics.event
        self.timestamp = analytics.timestamp
        self.metadata = analytics.metadata
    }
    
    func toStreamAnalytics() -> StreamAnalytics {
        return StreamAnalytics(
            streamId: streamId,
            event: event,
            timestamp: timestamp,
            metadata: metadata
        )
    }
    
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

public struct SyncStreamBackup: Codable {
    let id: String
    let userId: String
    let name: String
    let data: Data
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, data, createdAt
        case userId = "user_id"
    }
    
    init(from backup: StreamBackup) {
        self.id = backup.id
        self.userId = backup.userId
        self.name = backup.name
        self.data = (try? JSONEncoder().encode(backup.data)) ?? Data()
        self.createdAt = backup.createdAt
    }
    
    func toStreamBackup() -> StreamBackup {
        let backupData = (try? JSONDecoder().decode(BackupData.self, from: data)) ?? BackupData(streams: [], layouts: [], sessions: [])
        return StreamBackup(
            id: id,
            userId: userId,
            name: name,
            data: backupData,
            createdAt: createdAt
        )
    }
}

public struct SyncStreamTemplate: Codable {
    let id: String
    let userId: String
    let name: String
    let description: String
    let category: String
    let isPublic: Bool
    let downloads: Int
    let templateData: Data
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, downloads, createdAt
        case userId = "user_id"
        case isPublic = "is_public"
        case templateData = "template_data"
    }
    
    init(from template: StreamTemplate, userId: String) {
        self.id = template.id
        self.userId = userId
        self.name = template.name
        self.description = template.description
        self.category = template.category
        self.isPublic = template.isPublic
        self.downloads = template.downloads
        self.templateData = (try? JSONEncoder().encode(template)) ?? Data()
        self.createdAt = template.createdAt
    }
    
    func toStreamTemplate() -> StreamTemplate {
        return StreamTemplate(
            id: id,
            name: name,
            description: description,
            category: category,
            isPublic: isPublic,
            downloads: downloads,
            createdAt: createdAt
        )
    }
}

// MARK: - Placeholder Models (need to be defined elsewhere in the project)

public struct StreamSession {
    let id: String
    let streamId: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let quality: StreamQuality
}

public struct StreamAnalytics {
    let streamId: String
    let event: String
    let timestamp: Date
    let metadata: [String: String]
}

public struct StreamBackup {
    let id: String
    let userId: String
    let name: String
    let data: BackupData
    let createdAt: Date
}

public struct BackupData: Codable {
    let streams: [Stream]
    let layouts: [Layout]
    let sessions: [StreamSession]
}

public struct StreamTemplate {
    let id: String
    let name: String
    let description: String
    let category: String
    let isPublic: Bool
    let downloads: Int
    let createdAt: Date
}

// MARK: - UserProfile Model (matching web app schema)

public struct UserProfile: Codable, Identifiable {
    public let id: String
    public let clerkUserId: String
    public let stripeCustomerId: String?
    public let email: String
    public let fullName: String?
    public let avatarUrl: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case clerkUserId = "clerk_user_id"
        case stripeCustomerId = "stripe_customer_id"
        case email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public var displayName: String {
        return fullName ?? email.components(separatedBy: "@").first ?? "User"
    }
    
    public var initials: String {
        if let fullName = fullName {
            let components = fullName.components(separatedBy: " ")
            if components.count >= 2 {
                return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
            } else {
                return String(fullName.prefix(1)).uppercased()
            }
        }
        return String(email.prefix(1)).uppercased()
    }
}

public enum SupabaseError: Error, LocalizedError {
    case configurationInvalid
    case authenticationRequired
    case authenticationFailed
    case networkError(String)
    case databaseError(String)
    case syncConflict
    case dataCorruption
    case profileNotFound
    case invalidClerkToken
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationInvalid:
            return "Supabase configuration is invalid"
        case .authenticationRequired:
            return "Authentication is required for this operation"
        case .authenticationFailed:
            return "Authentication failed"
        case .networkError(let message):
            return "Network error: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .syncConflict:
            return "Sync conflict detected"
        case .dataCorruption:
            return "Data corruption detected"
        case .profileNotFound:
            return "User profile not found"
        case .invalidClerkToken:
            return "Invalid Clerk authentication token"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .configurationInvalid:
            return "Please check your Supabase configuration in Config.swift"
        case .authenticationRequired, .authenticationFailed, .invalidClerkToken:
            return "Please sign in again"
        case .networkError:
            return "Please check your internet connection and try again"
        case .databaseError:
            return "Please try again later"
        case .syncConflict:
            return "Please resolve the sync conflict and try again"
        case .dataCorruption:
            return "Please restore from backup or contact support"
        case .profileNotFound:
            return "Your profile will be created automatically"
        case .unknown:
            return "Please try again or contact support"
        }
    }
}

// MARK: - Stream Persistence Methods
extension SupabaseService {
    
    // MARK: - Layout Persistence
    public func saveLayout(_ layout: Layout) async throws -> Layout {
        guard let userId = currentUser?.id.uuidString else {
            throw SupabaseError.authenticationFailed
        }
        
        let syncLayout = SyncLayout(from: layout, userId: userId)
        
        do {
            let existingLayout = try await getLayout(id: layout.id)
            
            if existingLayout != nil {
                // Update existing layout
                let data = try syncLayout.toDictionary()
                let updatedLayout: SyncLayout = try await update(
                    table: "layouts",
                    id: layout.id,
                    data: data
                )
                return updatedLayout.toLayout()
            } else {
                // Create new layout
                let createdLayout: SyncLayout = try await insert(
                    table: "layouts",
                    data: syncLayout
                )
                return createdLayout.toLayout()
            }
        } catch {
            throw handleError(error)
        }
    }
    
    public func getLayout(id: String) async throws -> Layout? {
        do {
            let query = client.database
                .from("layouts")
                .select("*")
                .eq("id", value: id)
                .single()
            
            let layouts: [SyncLayout] = try await executeQuery(
                table: "layouts",
                query: query,
                type: SyncLayout.self
            )
            
            return layouts.first?.toLayout()
        } catch {
            throw handleError(error)
        }
    }
    
    public func getUserLayouts(userId: String? = nil) async throws -> [Layout] {
        let targetUserId = userId ?? currentUser?.id.uuidString
        guard let targetUserId = targetUserId else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let query = client.database
                .from("layouts")
                .select("*")
                .eq("user_id", value: targetUserId)
                .order("updated_at", ascending: false)
            
            let layouts: [SyncLayout] = try await executeQuery(
                table: "layouts",
                query: query,
                type: SyncLayout.self
            )
            
            return layouts.map { $0.toLayout() }
        } catch {
            throw handleError(error)
        }
    }
    
    public func deleteLayout(id: String) async throws {
        do {
            try await delete(table: "layouts", id: id)
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Stream Session Management
    public func createStreamSession(_ session: StreamSession) async throws -> StreamSession {
        guard let userId = currentUser?.id.uuidString else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let syncSession = SyncStreamSession(from: session, userId: userId)
            let createdSession: SyncStreamSession = try await insert(
                table: "stream_sessions",
                data: syncSession
            )
            return createdSession.toStreamSession()
        } catch {
            throw handleError(error)
        }
    }
    
    public func updateStreamSession(_ session: StreamSession) async throws -> StreamSession {
        guard let userId = currentUser?.id.uuidString else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let syncSession = SyncStreamSession(from: session, userId: userId)
            let data = try syncSession.toDictionary()
            let updatedSession: SyncStreamSession = try await update(
                table: "stream_sessions",
                id: session.id,
                data: data
            )
            return updatedSession.toStreamSession()
        } catch {
            throw handleError(error)
        }
    }
    
    public func getStreamSession(id: String) async throws -> StreamSession? {
        do {
            let query = client.database
                .from("stream_sessions")
                .select("*")
                .eq("id", value: id)
                .single()
            
            let sessions: [SyncStreamSession] = try await executeQuery(
                table: "stream_sessions",
                query: query,
                type: SyncStreamSession.self
            )
            
            return sessions.first?.toStreamSession()
        } catch {
            throw handleError(error)
        }
    }
    
    public func getUserStreamSessions(userId: String? = nil) async throws -> [StreamSession] {
        let targetUserId = userId ?? currentUser?.id.uuidString
        guard let targetUserId = targetUserId else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let query = client.database
                .from("stream_sessions")
                .select("*")
                .eq("user_id", value: targetUserId)
                .order("created_at", ascending: false)
            
            let sessions: [SyncStreamSession] = try await executeQuery(
                table: "stream_sessions",
                query: query,
                type: SyncStreamSession.self
            )
            
            return sessions.map { $0.toStreamSession() }
        } catch {
            throw handleError(error)
        }
    }
    
    public func deleteStreamSession(id: String) async throws {
        do {
            try await delete(table: "stream_sessions", id: id)
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Stream Analytics
    public func recordStreamAnalytics(_ analytics: StreamAnalytics) async throws {
        guard let userId = currentUser?.id.uuidString else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let syncAnalytics = SyncStreamAnalytics(from: analytics, userId: userId)
            let _: SyncStreamAnalytics = try await insert(
                table: "stream_analytics",
                data: syncAnalytics
            )
        } catch {
            throw handleError(error)
        }
    }
    
    public func getStreamAnalytics(streamId: String, limit: Int = 100) async throws -> [StreamAnalytics] {
        do {
            let query = client.database
                .from("stream_analytics")
                .select("*")
                .eq("stream_id", value: streamId)
                .order("timestamp", ascending: false)
                .limit(limit)
            
            let analytics: [SyncStreamAnalytics] = try await executeQuery(
                table: "stream_analytics",
                query: query,
                type: SyncStreamAnalytics.self
            )
            
            return analytics.map { $0.toStreamAnalytics() }
        } catch {
            throw handleError(error)
        }
    }
    
    public func getUserAnalytics(userId: String? = nil, limit: Int = 100) async throws -> [StreamAnalytics] {
        let targetUserId = userId ?? currentUser?.id.uuidString
        guard let targetUserId = targetUserId else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let query = client.database
                .from("stream_analytics")
                .select("*")
                .eq("user_id", value: targetUserId)
                .order("timestamp", ascending: false)
                .limit(limit)
            
            let analytics: [SyncStreamAnalytics] = try await executeQuery(
                table: "stream_analytics",
                query: query,
                type: SyncStreamAnalytics.self
            )
            
            return analytics.map { $0.toStreamAnalytics() }
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Backup and Restore
    public func createBackup(name: String) async throws -> StreamBackup {
        guard let userId = currentUser?.id.uuidString else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            // Gather all user data
            let streams = try await getUserStreams(userId: userId)
            let layouts = try await getUserLayouts(userId: userId)
            let sessions = try await getUserStreamSessions(userId: userId)
            
            let backupData = BackupData(
                streams: streams,
                layouts: layouts,
                sessions: sessions
            )
            
            let backup = StreamBackup(
                id: UUID().uuidString,
                userId: userId,
                name: name,
                data: backupData,
                createdAt: Date()
            )
            
            let syncBackup = SyncStreamBackup(from: backup)
            let createdBackup: SyncStreamBackup = try await insert(
                table: "stream_backups",
                data: syncBackup
            )
            
            return createdBackup.toStreamBackup()
        } catch {
            throw handleError(error)
        }
    }
    
    public func restoreFromBackup(backupId: String) async throws {
        guard let userId = currentUser?.id.uuidString else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let query = client.database
                .from("stream_backups")
                .select("*")
                .eq("id", value: backupId)
                .eq("user_id", value: userId)
                .single()
            
            let backups: [SyncStreamBackup] = try await executeQuery(
                table: "stream_backups",
                query: query,
                type: SyncStreamBackup.self
            )
            
            guard let backup = backups.first?.toStreamBackup() else {
                throw SupabaseError.dataCorruption
            }
            
            // Restore streams
            for stream in backup.data.streams {
                let syncStream = SyncStream(from: stream, userId: userId)
                let _: SyncStream = try await insert(table: "streams", data: syncStream)
            }
            
            // Restore layouts
            for layout in backup.data.layouts {
                let syncLayout = SyncLayout(from: layout, userId: userId)
                let _: SyncLayout = try await insert(table: "layouts", data: syncLayout)
            }
            
            // Restore sessions
            for session in backup.data.sessions {
                let syncSession = SyncStreamSession(from: session, userId: userId)
                let _: SyncStreamSession = try await insert(table: "stream_sessions", data: syncSession)
            }
            
        } catch {
            throw handleError(error)
        }
    }
    
    public func getUserBackups(userId: String? = nil) async throws -> [StreamBackup] {
        let targetUserId = userId ?? currentUser?.id.uuidString
        guard let targetUserId = targetUserId else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let query = client.database
                .from("stream_backups")
                .select("*")
                .eq("user_id", value: targetUserId)
                .order("created_at", ascending: false)
            
            let backups: [SyncStreamBackup] = try await executeQuery(
                table: "stream_backups",
                query: query,
                type: SyncStreamBackup.self
            )
            
            return backups.map { $0.toStreamBackup() }
        } catch {
            throw handleError(error)
        }
    }
    
    public func deleteBackup(id: String) async throws {
        do {
            try await delete(table: "stream_backups", id: id)
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Stream Templates
    public func createStreamTemplate(_ template: StreamTemplate) async throws -> StreamTemplate {
        guard let userId = currentUser?.id.uuidString else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let syncTemplate = SyncStreamTemplate(from: template, userId: userId)
            let createdTemplate: SyncStreamTemplate = try await insert(
                table: "stream_templates",
                data: syncTemplate
            )
            return createdTemplate.toStreamTemplate()
        } catch {
            throw handleError(error)
        }
    }
    
    public func getStreamTemplate(id: String) async throws -> StreamTemplate? {
        do {
            let query = client.database
                .from("stream_templates")
                .select("*")
                .eq("id", value: id)
                .single()
            
            let templates: [SyncStreamTemplate] = try await executeQuery(
                table: "stream_templates",
                query: query,
                type: SyncStreamTemplate.self
            )
            
            return templates.first?.toStreamTemplate()
        } catch {
            throw handleError(error)
        }
    }
    
    public func getPublicStreamTemplates(category: String? = nil, limit: Int = 50) async throws -> [StreamTemplate] {
        do {
            var query = client.database
                .from("stream_templates")
                .select("*")
                .eq("is_public", value: true)
                .order("downloads", ascending: false)
                .limit(limit)
            
            if let category = category {
                query = query.eq("category", value: category)
            }
            
            let templates: [SyncStreamTemplate] = try await executeQuery(
                table: "stream_templates",
                query: query,
                type: SyncStreamTemplate.self
            )
            
            return templates.map { $0.toStreamTemplate() }
        } catch {
            throw handleError(error)
        }
    }
    
    public func getUserStreamTemplates(userId: String? = nil) async throws -> [StreamTemplate] {
        let targetUserId = userId ?? currentUser?.id.uuidString
        guard let targetUserId = targetUserId else {
            throw SupabaseError.authenticationFailed
        }
        
        do {
            let query = client.database
                .from("stream_templates")
                .select("*")
                .eq("user_id", value: targetUserId)
                .order("created_at", ascending: false)
            
            let templates: [SyncStreamTemplate] = try await executeQuery(
                table: "stream_templates",
                query: query,
                type: SyncStreamTemplate.self
            )
            
            return templates.map { $0.toStreamTemplate() }
        } catch {
            throw handleError(error)
        }
    }
    
    public func deleteStreamTemplate(id: String) async throws {
        do {
            try await delete(table: "stream_templates", id: id)
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Helper Methods
    private func getUserStreams(userId: String) async throws -> [Stream] {
        let query = client.database
            .from("streams")
            .select("*")
            .eq("user_id", value: userId)
        
        let streams: [SyncStream] = try await executeQuery(
            table: "streams",
            query: query,
            type: SyncStream.self
        )
        
        return streams.map { $0.toStream() }
    }
}

// MARK: - Computed Properties
extension SupabaseService {
    public var isAuthenticated: Bool {
        return currentUser != nil
    }
    
    public var canSync: Bool {
        return isAuthenticated && isConnected
    }
    
    public var healthStatus: String {
        if !isConnected {
            return "❌ Disconnected"
        } else if !isAuthenticated {
            return "⚠️ Not authenticated"
        } else {
            return "✅ Healthy"
        }
    }
}