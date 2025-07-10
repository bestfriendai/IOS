//
//  StreamSessionManager.swift
//  StreamyyyApp
//
//  Comprehensive stream session management with persistence and cross-device sync
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Stream Session Manager
@MainActor
public class StreamSessionManager: ObservableObject {
    
    // MARK: - Properties
    public static let shared = StreamSessionManager()
    
    @Published public var currentSession: StreamSession?
    @Published public var activeSessions: [StreamSession] = []
    @Published public var sessionHistory: [StreamSession] = []
    @Published public var isRecording: Bool = false
    @Published public var syncStatus: SyncStatus = .disconnected
    
    private let supabaseService = SupabaseService.shared
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Real-time subscriptions
    private var sessionSubscription: RealtimeChannel?
    
    // Session tracking
    private var sessionTimer: Timer?
    private var autoSaveTimer: Timer?
    
    // MARK: - Initialization
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupObservers()
        loadActiveSessions()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        supabaseService.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
                if status == .connected {
                    self?.setupRealtimeSubscriptions()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupRealtimeSubscriptions() {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        // Subscribe to stream sessions
        do {
            sessionSubscription = try supabaseService.subscribeToTable(table: "stream_sessions") { [weak self] payload in
                Task {
                    await self?.handleSessionRealtimeUpdate(payload: payload)
                }
            }
        } catch {
            print("❌ Failed to subscribe to stream sessions: \(error)")
        }
    }
    
    private func loadActiveSessions() {
        Task {
            do {
                let sessions = try await fetchLocalSessions()
                activeSessions = sessions.filter { $0.isActive }
                sessionHistory = sessions.filter { !$0.isActive }
                
                // Resume the most recent active session if exists
                if let mostRecentSession = activeSessions.first {
                    currentSession = mostRecentSession
                }
                
                print("✅ Sessions loaded: \(activeSessions.count) active, \(sessionHistory.count) history")
            } catch {
                print("❌ Failed to load sessions: \(error)")
            }
        }
    }
    
    // MARK: - Session Management
    public func startNewSession(name: String, streamIds: [String] = [], layoutId: String? = nil) async throws -> StreamSession {
        // End current session if active
        if let current = currentSession, current.isActive {
            try await endSession(current)
        }
        
        let session = StreamSession(
            name: name,
            streamIds: streamIds,
            layoutId: layoutId,
            isActive: true
        )
        
        // Save locally
        try await createLocalSession(session)
        
        // Sync to remote if connected
        if supabaseService.canSync {
            try await syncSession(session)
        }
        
        // Set as current
        currentSession = session
        activeSessions.insert(session, at: 0)
        
        // Start auto-save timer
        startAutoSave()
        
        // Start recording if enabled
        if isRecording {
            startSessionRecording()
        }
        
        print("✅ New session started: \(name)")
        return session
    }
    
    public func endSession(_ session: StreamSession) async throws {
        session.end()
        
        // Update locally
        try await updateLocalSession(session)
        
        // Sync to remote if connected
        if supabaseService.canSync {
            try await syncSession(session)
        }
        
        // Update UI state
        activeSessions.removeAll { $0.id == session.id }
        sessionHistory.insert(session, at: 0)
        
        // Clear current session if this was it
        if currentSession?.id == session.id {
            currentSession = nil
        }
        
        // Stop auto-save timer
        stopAutoSave()
        
        // Stop recording
        if isRecording {
            stopSessionRecording()
        }
        
        print("✅ Session ended: \(session.name)")
    }
    
    public func resumeSession(_ session: StreamSession) async throws {
        // End current session first
        if let current = currentSession, current.isActive {
            try await endSession(current)
        }
        
        // Reactivate session
        session.isActive = true
        session.startedAt = Date()
        session.endedAt = nil
        session.updatedAt = Date()
        
        // Update locally
        try await updateLocalSession(session)
        
        // Sync to remote
        if supabaseService.canSync {
            try await syncSession(session)
        }
        
        // Update UI state
        currentSession = session
        activeSessions.insert(session, at: 0)
        sessionHistory.removeAll { $0.id == session.id }
        
        // Start auto-save
        startAutoSave()
        
        print("✅ Session resumed: \(session.name)")
    }
    
    public func addStreamToSession(_ streamId: String, session: StreamSession? = nil) async throws {
        let targetSession = session ?? currentSession
        
        guard let targetSession = targetSession else {
            throw SessionError.noActiveSession
        }
        
        targetSession.addStream(streamId)
        
        // Update locally
        try await updateLocalSession(targetSession)
        
        // Sync to remote
        if supabaseService.canSync {
            try await syncSession(targetSession)
        }
        
        print("✅ Stream added to session: \(streamId)")
    }
    
    public func removeStreamFromSession(_ streamId: String, session: StreamSession? = nil) async throws {
        let targetSession = session ?? currentSession
        
        guard let targetSession = targetSession else {
            throw SessionError.noActiveSession
        }
        
        targetSession.removeStream(streamId)
        
        // Update locally
        try await updateLocalSession(targetSession)
        
        // Sync to remote
        if supabaseService.canSync {
            try await syncSession(targetSession)
        }
        
        print("✅ Stream removed from session: \(streamId)")
    }
    
    public func updateSessionLayout(_ layoutId: String, session: StreamSession? = nil) async throws {
        let targetSession = session ?? currentSession
        
        guard let targetSession = targetSession else {
            throw SessionError.noActiveSession
        }
        
        targetSession.layoutId = layoutId
        targetSession.updatedAt = Date()
        
        // Update locally
        try await updateLocalSession(targetSession)
        
        // Sync to remote
        if supabaseService.canSync {
            try await syncSession(targetSession)
        }
        
        print("✅ Session layout updated: \(layoutId)")
    }
    
    public func updateSessionMetadata(_ metadata: [String: String], session: StreamSession? = nil) async throws {
        let targetSession = session ?? currentSession
        
        guard let targetSession = targetSession else {
            throw SessionError.noActiveSession
        }
        
        targetSession.metadata = metadata
        targetSession.updatedAt = Date()
        
        // Update locally
        try await updateLocalSession(targetSession)
        
        // Sync to remote
        if supabaseService.canSync {
            try await syncSession(targetSession)
        }
        
        print("✅ Session metadata updated")
    }
    
    // MARK: - Session Synchronization
    private func syncSession(_ session: StreamSession) async throws {
        guard supabaseService.canSync else {
            throw SessionError.syncNotAvailable
        }
        
        do {
            let existingSession = try await supabaseService.getStreamSession(id: session.id)
            
            if existingSession != nil {
                // Update existing
                let _ = try await supabaseService.updateStreamSession(session)
            } else {
                // Create new
                let _ = try await supabaseService.createStreamSession(session)
            }
            
            print("✅ Session synced: \(session.name)")
        } catch {
            print("❌ Failed to sync session: \(error)")
            throw error
        }
    }
    
    public func syncAllSessions() async throws {
        guard supabaseService.canSync else {
            throw SessionError.syncNotAvailable
        }
        
        let sessions = try await fetchLocalSessions()
        
        for session in sessions {
            try await syncSession(session)
        }
        
        print("✅ All sessions synced: \(sessions.count)")
    }
    
    // MARK: - Session Recording
    private func startSessionRecording() {
        guard let session = currentSession else { return }
        
        // Record session start analytics
        let analytics = StreamAnalytics(
            event: .streamStart,
            value: 1.0,
            metadata: [
                "session_id": session.id,
                "stream_count": "\(session.streamIds.count)"
            ]
        )
        
        Task {
            try await supabaseService.recordStreamAnalytics(analytics)
        }
        
        print("✅ Session recording started")
    }
    
    private func stopSessionRecording() {
        guard let session = currentSession else { return }
        
        // Record session end analytics
        let analytics = StreamAnalytics(
            event: .streamEnd,
            value: session.duration,
            metadata: [
                "session_id": session.id,
                "stream_count": "\(session.streamIds.count)",
                "duration": "\(session.duration)"
            ]
        )
        
        Task {
            try await supabaseService.recordStreamAnalytics(analytics)
        }
        
        print("✅ Session recording stopped")
    }
    
    // MARK: - Auto Save
    private func startAutoSave() {
        stopAutoSave() // Stop any existing timer
        
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.autoSaveCurrentSession()
            }
        }
    }
    
    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    private func autoSaveCurrentSession() async {
        guard let session = currentSession, session.isActive else { return }
        
        do {
            session.updateDuration()
            try await updateLocalSession(session)
            
            if supabaseService.canSync {
                try await syncSession(session)
            }
            
            print("✅ Session auto-saved: \(session.name)")
        } catch {
            print("❌ Failed to auto-save session: \(error)")
        }
    }
    
    // MARK: - Session History
    public func deleteSession(_ session: StreamSession) async throws {
        // Remove from remote
        if supabaseService.canSync {
            try await supabaseService.deleteStreamSession(id: session.id)
        }
        
        // Remove from local
        try await deleteLocalSession(session)
        
        // Update UI state
        activeSessions.removeAll { $0.id == session.id }
        sessionHistory.removeAll { $0.id == session.id }
        
        if currentSession?.id == session.id {
            currentSession = nil
        }
        
        print("✅ Session deleted: \(session.name)")
    }
    
    public func getSessionAnalytics(_ session: StreamSession) async throws -> [StreamAnalytics] {
        guard supabaseService.canSync else {
            throw SessionError.syncNotAvailable
        }
        
        var allAnalytics: [StreamAnalytics] = []
        
        // Get analytics for each stream in the session
        for streamId in session.streamIds {
            let streamAnalytics = try await supabaseService.getStreamAnalytics(streamId: streamId)
            allAnalytics.append(contentsOf: streamAnalytics)
        }
        
        // Filter analytics by session timeframe
        let sessionAnalytics = allAnalytics.filter { analytics in
            analytics.timestamp >= session.startedAt &&
            (session.endedAt == nil || analytics.timestamp <= session.endedAt!)
        }
        
        return sessionAnalytics
    }
    
    // MARK: - Session Templates
    public func saveAsTemplate(_ session: StreamSession, name: String) async throws -> StreamTemplate {
        guard supabaseService.canSync else {
            throw SessionError.syncNotAvailable
        }
        
        let template = StreamTemplate(
            name: name,
            description: session.description,
            category: "Sessions",
            tags: ["session", "template"],
            layoutData: session.layoutId != nil ? ["layout_id": session.layoutId!] : [:],
            streamData: [
                "stream_ids": session.streamIds,
                "stream_count": session.streamIds.count
            ]
        )
        
        let savedTemplate = try await supabaseService.createStreamTemplate(template)
        
        print("✅ Session template created: \(name)")
        return savedTemplate
    }
    
    public func createSessionFromTemplate(_ template: StreamTemplate) async throws -> StreamSession {
        let streamIds = template.streamData["stream_ids"] as? [String] ?? []
        let layoutId = template.layoutData["layout_id"] as? String
        
        let session = try await startNewSession(
            name: template.name,
            streamIds: streamIds,
            layoutId: layoutId
        )
        
        session.description = template.description
        
        try await updateLocalSession(session)
        
        print("✅ Session created from template: \(template.name)")
        return session
    }
    
    // MARK: - Real-time Update Handlers
    private func handleSessionRealtimeUpdate(payload: PostgrestResponse) async {
        guard let eventType = payload.eventType,
              let record = payload.record else { return }
        
        switch eventType {
        case "INSERT":
            await handleSessionInsert(record: record)
        case "UPDATE":
            await handleSessionUpdate(record: record)
        case "DELETE":
            await handleSessionDelete(record: record)
        default:
            break
        }
    }
    
    private func handleSessionInsert(record: [String: Any]) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            let syncSession = try JSONDecoder().decode(SyncStreamSession.self, from: data)
            
            let existingSession = try await fetchLocalSession(id: syncSession.id)
            
            if existingSession == nil {
                let session = syncSession.toStreamSession()
                try await createLocalSession(session)
                
                if session.isActive {
                    activeSessions.insert(session, at: 0)
                } else {
                    sessionHistory.insert(session, at: 0)
                }
                
                print("✅ New session created from remote: \(syncSession.name)")
            }
            
        } catch {
            print("❌ Failed to handle session insert: \(error)")
        }
    }
    
    private func handleSessionUpdate(record: [String: Any]) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            let syncSession = try JSONDecoder().decode(SyncStreamSession.self, from: data)
            
            if let localSession = try await fetchLocalSession(id: syncSession.id) {
                // Update local session with remote data
                let updatedSession = syncSession.toStreamSession()
                try await updateLocalSession(updatedSession)
                
                // Update UI state
                if let index = activeSessions.firstIndex(where: { $0.id == syncSession.id }) {
                    activeSessions[index] = updatedSession
                }
                
                if let index = sessionHistory.firstIndex(where: { $0.id == syncSession.id }) {
                    sessionHistory[index] = updatedSession
                }
                
                if currentSession?.id == syncSession.id {
                    currentSession = updatedSession
                }
                
                print("✅ Session updated from remote: \(syncSession.name)")
            }
            
        } catch {
            print("❌ Failed to handle session update: \(error)")
        }
    }
    
    private func handleSessionDelete(record: [String: Any]) async {
        guard let id = record["id"] as? String else { return }
        
        do {
            if let session = try await fetchLocalSession(id: id) {
                try await deleteLocalSession(session)
                
                // Update UI state
                activeSessions.removeAll { $0.id == id }
                sessionHistory.removeAll { $0.id == id }
                
                if currentSession?.id == id {
                    currentSession = nil
                }
                
                print("✅ Session deleted from local: \(id)")
            }
            
        } catch {
            print("❌ Failed to handle session delete: \(error)")
        }
    }
    
    // MARK: - Local Data Operations
    private func fetchLocalSessions() async throws -> [StreamSession] {
        let descriptor = FetchDescriptor<StreamSession>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    private func fetchLocalSession(id: String) async throws -> StreamSession? {
        let descriptor = FetchDescriptor<StreamSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func createLocalSession(_ session: StreamSession) async throws {
        modelContext.insert(session)
        try modelContext.save()
    }
    
    private func updateLocalSession(_ session: StreamSession) async throws {
        try modelContext.save()
    }
    
    private func deleteLocalSession(_ session: StreamSession) async throws {
        modelContext.delete(session)
        try modelContext.save()
    }
    
    // MARK: - Public Interface
    public func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            startSessionRecording()
        } else {
            stopSessionRecording()
        }
    }
    
    public func getCurrentSessionDuration() -> TimeInterval {
        return currentSession?.duration ?? 0
    }
    
    public func getSessionStats() -> (active: Int, total: Int, totalDuration: TimeInterval) {
        let totalDuration = sessionHistory.reduce(0) { $0 + $1.duration }
        return (
            active: activeSessions.count,
            total: sessionHistory.count,
            totalDuration: totalDuration
        )
    }
    
    // MARK: - Cleanup
    deinit {
        stopAutoSave()
        sessionTimer?.invalidate()
        sessionSubscription?.unsubscribe()
        cancellables.removeAll()
    }
}

// MARK: - Session Errors
public enum SessionError: Error, LocalizedError {
    case noActiveSession
    case syncNotAvailable
    case sessionNotFound
    case invalidTemplate
    case recordingFailed
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active session"
        case .syncNotAvailable:
            return "Sync not available"
        case .sessionNotFound:
            return "Session not found"
        case .invalidTemplate:
            return "Invalid template"
        case .recordingFailed:
            return "Recording failed"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}