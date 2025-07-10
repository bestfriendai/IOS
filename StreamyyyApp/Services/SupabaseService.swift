//
//  SupabaseService.swift
//  StreamyyyApp
//
//  Core Supabase service for database operations and authentication
//

import Foundation
import Supabase
import Combine
import SwiftUI

// MARK: - Supabase Service
@MainActor
public class SupabaseService: ObservableObject {
    
    // MARK: - Properties
    public static let shared = SupabaseService()
    
    private let client: SupabaseClient
    @Published public var isConnected: Bool = false
    @Published public var currentUser: User?
    @Published public var syncStatus: SyncStatus = .disconnected
    @Published public var lastSyncTime: Date?
    
    private var cancellables = Set<AnyCancellable>()
    private var connectionMonitor: Timer?
    private var retryAttempts: Int = 0
    private let maxRetryAttempts: Int = 3
    
    // MARK: - Initialization
    private init() {
        // Initialize Supabase client
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.Supabase.url)!,
            supabaseKey: Config.Supabase.anonKey
        )
        
        setupConnectionMonitoring()
        setupAuthStateListener()
    }
    
    // MARK: - Authentication
    public func signUp(email: String, password: String) async throws -> User {
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if let user = response.user {
                await createUserProfile(user: user)
                return user
            }
            throw SupabaseError.authenticationFailed
        } catch {
            throw handleError(error)
        }
    }
    
    public func signIn(email: String, password: String) async throws -> User {
        do {
            let response = try await client.auth.signIn(email: email, password: password)
            if let user = response.user {
                await syncUserData(user: user)
                return user
            }
            throw SupabaseError.authenticationFailed
        } catch {
            throw handleError(error)
        }
    }
    
    public func signOut() async throws {
        do {
            try await client.auth.signOut()
            currentUser = nil
            syncStatus = .disconnected
        } catch {
            throw handleError(error)
        }
    }
    
    public func getCurrentUser() async throws -> User? {
        do {
            return try await client.auth.user
        } catch {
            throw handleError(error)
        }
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
    private func createUserProfile(user: User) async {
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
    
    private func syncUserData(user: User) async {
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
            return try response.decoded(as: [T].self)
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
            
            return try response.decoded(as: T.self)
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
            
            return try response.decoded(as: T.self)
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
        callback: @escaping (PostgrestResponse) -> Void
    ) throws -> RealtimeChannel {
        let channel = client.realtime.channel("public:\(table)")
        
        channel.on(.all) { payload in
            callback(payload)
        }
        
        try channel.subscribe()
        return channel
    }
    
    public func unsubscribe(channel: RealtimeChannel) {
        channel.unsubscribe()
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
            
            return try response.decoded(as: [T].self)
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
            switch postgrestError {
            case .api(let apiError):
                return .databaseError(apiError.message)
            case .network(let networkError):
                return .networkError(networkError.localizedDescription)
            case .unknown(let message):
                return .unknown(message)
            }
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

// MARK: - Supabase Errors
public enum SupabaseError: Error, LocalizedError {
    case configurationInvalid
    case authenticationFailed
    case networkError(String)
    case databaseError(String)
    case syncConflict
    case dataCorruption
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationInvalid:
            return "Supabase configuration is invalid"
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
        case .networkError:
            return "Please check your internet connection and try again"
        case .databaseError:
            return "Please try again later"
        case .syncConflict:
            return "Please resolve the sync conflict and try again"
        case .dataCorruption:
            return "Please restore from backup or contact support"
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