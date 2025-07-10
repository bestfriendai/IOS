//
//  LayoutSyncManager.swift
//  StreamyyyApp
//
//  Comprehensive layout synchronization manager for cross-device sync and collaboration
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Layout Sync Manager
@MainActor
public class LayoutSyncManager: ObservableObject {
    
    // MARK: - Properties
    public static let shared = LayoutSyncManager()
    
    @Published public var syncStatus: SyncStatus = .disconnected
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date?
    @Published public var pendingLayouts: [Layout] = []
    @Published public var sharedLayouts: [Layout] = []
    @Published public var templateLayouts: [Layout] = []
    
    private let supabaseService = SupabaseService.shared
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Real-time subscriptions
    private var layoutSubscription: RealtimeChannel?
    private var templateSubscription: RealtimeChannel?
    
    // MARK: - Initialization
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupObservers()
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
        
        // Subscribe to layouts table
        do {
            layoutSubscription = try supabaseService.subscribeToTable(table: "layouts") { [weak self] payload in
                Task {
                    await self?.handleLayoutRealtimeUpdate(payload: payload)
                }
            }
        } catch {
            print("❌ Failed to subscribe to layouts: \(error)")
        }
        
        // Subscribe to layout templates
        do {
            templateSubscription = try supabaseService.subscribeToTable(table: "stream_templates") { [weak self] payload in
                Task {
                    await self?.handleTemplateRealtimeUpdate(payload: payload)
                }
            }
        } catch {
            print("❌ Failed to subscribe to templates: \(error)")
        }
    }
    
    // MARK: - Layout Synchronization
    public func syncLayout(_ layout: Layout) async throws {
        guard supabaseService.canSync else {
            throw LayoutSyncError.notAuthenticated
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let syncedLayout = try await supabaseService.saveLayout(layout)
            try await updateLocalLayout(syncedLayout)
            
            // Update sync status
            layout.recordUsage()
            
            print("✅ Layout synced: \(layout.name)")
        } catch {
            print("❌ Failed to sync layout: \(error)")
            throw error
        }
    }
    
    public func syncAllLayouts() async throws {
        let layouts = try await fetchLocalLayouts()
        
        for layout in layouts {
            try await syncLayout(layout)
        }
        
        lastSyncTime = Date()
    }
    
    public func deleteLayout(_ layout: Layout) async throws {
        guard supabaseService.canSync else {
            throw LayoutSyncError.notAuthenticated
        }
        
        do {
            // Delete from remote
            try await supabaseService.deleteLayout(id: layout.id)
            
            // Delete from local
            try await deleteLocalLayout(layout)
            
            print("✅ Layout deleted: \(layout.name)")
        } catch {
            print("❌ Failed to delete layout: \(error)")
            throw error
        }
    }
    
    // MARK: - Layout Sharing
    public func shareLayout(_ layout: Layout, isPublic: Bool = false) async throws -> String {
        guard supabaseService.canSync else {
            throw LayoutSyncError.notAuthenticated
        }
        
        // Enable sharing on layout
        layout.enableSharing(authorName: supabaseService.currentUser?.email)
        
        // Save to remote
        try await syncLayout(layout)
        
        guard let shareCode = layout.shareCode else {
            throw LayoutSyncError.sharingFailed
        }
        
        print("✅ Layout shared: \(layout.name) - Code: \(shareCode)")
        return shareCode
    }
    
    public func importLayoutFromShareCode(_ shareCode: String) async throws -> Layout {
        guard supabaseService.canSync else {
            throw LayoutSyncError.notAuthenticated
        }
        
        do {
            let userLayouts = try await supabaseService.getUserLayouts()
            
            guard let sharedLayout = userLayouts.first(where: { $0.shareCode == shareCode }) else {
                throw LayoutSyncError.layoutNotFound
            }
            
            // Create a copy for the current user
            let importedLayout = Layout(
                name: "\(sharedLayout.name) (Imported)",
                type: sharedLayout.type,
                configuration: sharedLayout.configuration
            )
            
            // Disable sharing for the imported copy
            importedLayout.disableSharing()
            
            // Save locally and sync
            try await createLocalLayout(importedLayout)
            try await syncLayout(importedLayout)
            
            print("✅ Layout imported: \(importedLayout.name)")
            return importedLayout
            
        } catch {
            print("❌ Failed to import layout: \(error)")
            throw error
        }
    }
    
    // MARK: - Layout Templates
    public func saveAsTemplate(_ layout: Layout, category: String = "Custom") async throws -> StreamTemplate {
        guard supabaseService.canSync else {
            throw LayoutSyncError.notAuthenticated
        }
        
        let template = StreamTemplate(
            name: layout.name,
            description: layout.description,
            category: category,
            tags: layout.tags,
            layoutData: layout.configuration.export(),
            streamData: [:],
            isPublic: false
        )
        
        do {
            let savedTemplate = try await supabaseService.createStreamTemplate(template)
            
            // Add to local templates
            templateLayouts.append(layout)
            
            print("✅ Template created: \(template.name)")
            return savedTemplate
            
        } catch {
            print("❌ Failed to create template: \(error)")
            throw error
        }
    }
    
    public func loadTemplates(category: String? = nil) async throws -> [StreamTemplate] {
        guard supabaseService.canSync else {
            throw LayoutSyncError.notAuthenticated
        }
        
        do {
            let templates = try await supabaseService.getPublicStreamTemplates(category: category)
            
            // Convert templates to layouts for UI
            let layouts = templates.compactMap { template -> Layout? in
                guard let configuration = LayoutConfiguration.import(template.layoutData) else {
                    return nil
                }
                
                let layout = Layout(
                    name: template.name,
                    type: LayoutType(rawValue: template.category) ?? .custom,
                    configuration: configuration
                )
                
                layout.description = template.description
                layout.tags = template.tags
                layout.downloadCount = template.downloads
                layout.rating = template.rating
                layout.ratingCount = template.ratingCount
                
                return layout
            }
            
            templateLayouts = layouts
            
            print("✅ Templates loaded: \(templates.count)")
            return templates
            
        } catch {
            print("❌ Failed to load templates: \(error)")
            throw error
        }
    }
    
    public func createLayoutFromTemplate(_ template: StreamTemplate) async throws -> Layout {
        guard let configuration = LayoutConfiguration.import(template.layoutData) else {
            throw LayoutSyncError.invalidTemplate
        }
        
        let layout = Layout(
            name: template.name,
            type: LayoutType(rawValue: template.category) ?? .custom,
            configuration: configuration
        )
        
        layout.description = template.description
        layout.tags = template.tags
        
        // Save locally
        try await createLocalLayout(layout)
        
        // Sync to remote
        try await syncLayout(layout)
        
        print("✅ Layout created from template: \(layout.name)")
        return layout
    }
    
    // MARK: - Layout Backup and Restore
    public func backupLayouts(name: String) async throws -> StreamBackup {
        guard supabaseService.canSync else {
            throw LayoutSyncError.notAuthenticated
        }
        
        do {
            let layouts = try await fetchLocalLayouts()
            
            let backupData = BackupData(
                streams: [],
                layouts: layouts,
                sessions: []
            )
            
            let backup = StreamBackup(
                userId: supabaseService.currentUser?.id.uuidString ?? "",
                name: name,
                data: backupData
            )
            
            let syncBackup = SyncStreamBackup(from: backup)
            let savedBackup = try await supabaseService.insert(table: "stream_backups", data: syncBackup)
            
            print("✅ Layouts backed up: \(name)")
            return backup
            
        } catch {
            print("❌ Failed to backup layouts: \(error)")
            throw error
        }
    }
    
    public func restoreLayouts(from backup: StreamBackup) async throws {
        guard supabaseService.canSync else {
            throw LayoutSyncError.notAuthenticated
        }
        
        do {
            // Clear existing layouts
            let existingLayouts = try await fetchLocalLayouts()
            for layout in existingLayouts {
                try await deleteLocalLayout(layout)
            }
            
            // Restore layouts
            for layout in backup.data.layouts {
                try await createLocalLayout(layout)
                try await syncLayout(layout)
            }
            
            print("✅ Layouts restored: \(backup.data.layouts.count)")
            
        } catch {
            print("❌ Failed to restore layouts: \(error)")
            throw error
        }
    }
    
    // MARK: - Real-time Update Handlers
    private func handleLayoutRealtimeUpdate(payload: PostgrestResponse) async {
        guard let eventType = payload.eventType,
              let record = payload.record else { return }
        
        switch eventType {
        case "INSERT":
            await handleLayoutInsert(record: record)
        case "UPDATE":
            await handleLayoutUpdate(record: record)
        case "DELETE":
            await handleLayoutDelete(record: record)
        default:
            break
        }
    }
    
    private func handleLayoutInsert(record: [String: Any]) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            let syncLayout = try JSONDecoder().decode(SyncLayout.self, from: data)
            
            let existingLayout = try await fetchLocalLayout(id: syncLayout.id)
            
            if existingLayout == nil {
                let layout = syncLayout.toLayout()
                try await createLocalLayout(layout)
                
                print("✅ New layout created from remote: \(syncLayout.name)")
            }
            
        } catch {
            print("❌ Failed to handle layout insert: \(error)")
        }
    }
    
    private func handleLayoutUpdate(record: [String: Any]) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            let syncLayout = try JSONDecoder().decode(SyncLayout.self, from: data)
            
            if let localLayout = try await fetchLocalLayout(id: syncLayout.id) {
                // Check for conflicts
                if localLayout.updatedAt > syncLayout.updatedAt {
                    // Local is newer, sync local to remote
                    try await syncLayout(localLayout)
                } else {
                    // Remote is newer, update local
                    let updatedLayout = syncLayout.toLayout()
                    try await updateLocalLayout(updatedLayout)
                }
                
                print("✅ Layout updated from remote: \(syncLayout.name)")
            }
            
        } catch {
            print("❌ Failed to handle layout update: \(error)")
        }
    }
    
    private func handleLayoutDelete(record: [String: Any]) async {
        guard let id = record["id"] as? String else { return }
        
        do {
            if let layout = try await fetchLocalLayout(id: id) {
                try await deleteLocalLayout(layout)
                print("✅ Layout deleted from local: \(id)")
            }
            
        } catch {
            print("❌ Failed to handle layout delete: \(error)")
        }
    }
    
    private func handleTemplateRealtimeUpdate(payload: PostgrestResponse) async {
        // Handle template updates for refreshing template list
        await loadTemplatesIfNeeded()
    }
    
    private func loadTemplatesIfNeeded() async {
        if templateLayouts.isEmpty {
            do {
                let _ = try await loadTemplates()
            } catch {
                print("❌ Failed to load templates: \(error)")
            }
        }
    }
    
    // MARK: - Local Data Operations
    private func fetchLocalLayouts() async throws -> [Layout] {
        let descriptor = FetchDescriptor<Layout>()
        return try modelContext.fetch(descriptor)
    }
    
    private func fetchLocalLayout(id: String) async throws -> Layout? {
        let descriptor = FetchDescriptor<Layout>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func createLocalLayout(_ layout: Layout) async throws {
        modelContext.insert(layout)
        try modelContext.save()
    }
    
    private func updateLocalLayout(_ layout: Layout) async throws {
        try modelContext.save()
    }
    
    private func deleteLocalLayout(_ layout: Layout) async throws {
        modelContext.delete(layout)
        try modelContext.save()
    }
    
    // MARK: - Public Interface
    public func loadSharedLayouts() async throws {
        guard supabaseService.canSync else { return }
        
        do {
            let layouts = try await supabaseService.getUserLayouts()
            sharedLayouts = layouts.filter { $0.isShared }
            
            print("✅ Shared layouts loaded: \(sharedLayouts.count)")
        } catch {
            print("❌ Failed to load shared layouts: \(error)")
            throw error
        }
    }
    
    public func setDefaultLayout(_ layout: Layout) async throws {
        // Unset all other defaults
        let layouts = try await fetchLocalLayouts()
        for otherLayout in layouts {
            if otherLayout.id != layout.id {
                otherLayout.unsetAsDefault()
            }
        }
        
        // Set as default
        layout.setAsDefault()
        
        // Sync changes
        try await syncAllLayouts()
        
        print("✅ Default layout set: \(layout.name)")
    }
    
    public func getDefaultLayout() async throws -> Layout? {
        let layouts = try await fetchLocalLayouts()
        return layouts.first { $0.isDefault }
    }
    
    public func searchLayouts(query: String) async throws -> [Layout] {
        let layouts = try await fetchLocalLayouts()
        
        return layouts.filter { layout in
            layout.name.localizedCaseInsensitiveContains(query) ||
            layout.description?.localizedCaseInsensitiveContains(query) == true ||
            layout.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        layoutSubscription?.unsubscribe()
        templateSubscription?.unsubscribe()
        cancellables.removeAll()
    }
}

// MARK: - Layout Sync Errors
public enum LayoutSyncError: Error, LocalizedError {
    case notAuthenticated
    case layoutNotFound
    case sharingFailed
    case invalidTemplate
    case syncConflict
    case backupFailed
    case restoreFailed
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .layoutNotFound:
            return "Layout not found"
        case .sharingFailed:
            return "Failed to share layout"
        case .invalidTemplate:
            return "Invalid template data"
        case .syncConflict:
            return "Sync conflict detected"
        case .backupFailed:
            return "Backup failed"
        case .restoreFailed:
            return "Restore failed"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}