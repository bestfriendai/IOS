//
//  AppShortcutsManager.swift
//  StreamyyyApp
//
//  Created by Claude on 2025-07-09.
//  Copyright © 2025 Streamyyy. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

/// Manager for handling app shortcuts (3D Touch / Haptic Touch quick actions)
@MainActor
final class AppShortcutsManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var availableShortcuts: [UIApplicationShortcutItem] = []
    @Published var isShortcutsEnabled = true
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let shortcutsKey = "app_shortcuts_enabled"
    
    // MARK: - Initialization
    init() {
        loadShortcutsPreference()
        setupDefaultShortcuts()
    }
    
    // MARK: - Public Methods
    
    /// Setup default app shortcuts
    func setupDefaultShortcuts() {
        guard isShortcutsEnabled else {
            clearShortcuts()
            return
        }
        
        var shortcuts: [UIApplicationShortcutItem] = []
        
        // Quick Browse - Browse live streams
        shortcuts.append(UIApplicationShortcutItem(
            type: "com.streamyyy.quickbrowse",
            localizedTitle: "Browse Live Streams",
            localizedSubtitle: "Discover trending streams",
            icon: UIApplicationShortcutIcon(systemImageName: "play.circle"),
            userInfo: [
                "action": "browse_live" as NSSecureCoding,
                "category": "all" as NSSecureCoding
            ]
        ))
        
        // Search - Quick search functionality
        shortcuts.append(UIApplicationShortcutItem(
            type: "com.streamyyy.search",
            localizedTitle: "Search Streams",
            localizedSubtitle: "Find specific streamers or content",
            icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
            userInfo: [
                "action": "search" as NSSecureCoding
            ]
        ))
        
        // Favorites - Quick access to favorite streams
        shortcuts.append(UIApplicationShortcutItem(
            type: "com.streamyyy.favorites",
            localizedTitle: "My Favorites",
            localizedSubtitle: "View saved streams",
            icon: UIApplicationShortcutIcon(systemImageName: "heart.fill"),
            userInfo: [
                "action": "favorites" as NSSecureCoding
            ]
        ))
        
        // Add Stream - Quick add new stream
        shortcuts.append(UIApplicationShortcutItem(
            type: "com.streamyyy.addstream",
            localizedTitle: "Add Stream",
            localizedSubtitle: "Add a new stream to watch",
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle"),
            userInfo: [
                "action": "add_stream" as NSSecureCoding
            ]
        ))
        
        availableShortcuts = shortcuts
        UIApplication.shared.shortcutItems = shortcuts
    }
    
    /// Setup dynamic shortcuts based on user activity
    func setupDynamicShortcuts() {
        guard isShortcutsEnabled else { return }
        
        var shortcuts: [UIApplicationShortcutItem] = []
        
        // Get recent streams from user defaults or core data
        let recentStreams = getRecentStreams()
        
        // Add recently watched streams as shortcuts
        for (index, stream) in recentStreams.prefix(2).enumerated() {
            let shortcut = UIApplicationShortcutItem(
                type: "com.streamyyy.recentstream.\(stream.id)",
                localizedTitle: stream.title,
                localizedSubtitle: "Continue watching • \(stream.platform)",
                icon: UIApplicationShortcutIcon(systemImageName: "play.rectangle"),
                userInfo: [
                    "action": "open_stream" as NSSecureCoding,
                    "stream_id": stream.id as NSSecureCoding,
                    "stream_url": stream.url as NSSecureCoding
                ]
            )
            shortcuts.append(shortcut)
        }
        
        // Add static shortcuts
        shortcuts.append(contentsOf: getStaticShortcuts())
        
        // Limit to 4 shortcuts (iOS limit)
        shortcuts = Array(shortcuts.prefix(4))
        
        availableShortcuts = shortcuts
        UIApplication.shared.shortcutItems = shortcuts
    }
    
    /// Handle shortcut item selection
    func handleShortcut(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = shortcutItem.userInfo?["action"] as? String else {
            return false
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        switch action {
        case "browse_live":
            return handleBrowseLive(shortcutItem)
        case "search":
            return handleSearch(shortcutItem)
        case "favorites":
            return handleFavorites(shortcutItem)
        case "add_stream":
            return handleAddStream(shortcutItem)
        case "open_stream":
            return handleOpenStream(shortcutItem)
        default:
            return false
        }
    }
    
    /// Enable or disable shortcuts
    func toggleShortcuts(_ enabled: Bool) {
        isShortcutsEnabled = enabled
        userDefaults.set(enabled, forKey: shortcutsKey)
        
        if enabled {
            setupDynamicShortcuts()
        } else {
            clearShortcuts()
        }
    }
    
    /// Clear all shortcuts
    func clearShortcuts() {
        availableShortcuts = []
        UIApplication.shared.shortcutItems = []
    }
    
    /// Update shortcuts when user performs actions
    func updateShortcutsForUserActivity(_ activity: UserActivity) {
        switch activity {
        case .watchedStream(let stream):
            addRecentStream(stream)
            setupDynamicShortcuts()
        case .favoriteAdded(let stream):
            updateFavoriteShortcut(stream)
        case .searchPerformed(let query):
            updateSearchShortcut(query)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadShortcutsPreference() {
        isShortcutsEnabled = userDefaults.bool(forKey: shortcutsKey)
        if !userDefaults.object(forKey: shortcutsKey) != nil {
            // First time, enable by default
            isShortcutsEnabled = true
            userDefaults.set(true, forKey: shortcutsKey)
        }
    }
    
    private func getStaticShortcuts() -> [UIApplicationShortcutItem] {
        return [
            UIApplicationShortcutItem(
                type: "com.streamyyy.browse",
                localizedTitle: "Browse Streams",
                localizedSubtitle: "Discover new content",
                icon: UIApplicationShortcutIcon(systemImageName: "play.circle"),
                userInfo: ["action": "browse_live" as NSSecureCoding]
            ),
            UIApplicationShortcutItem(
                type: "com.streamyyy.search",
                localizedTitle: "Search",
                localizedSubtitle: "Find streams",
                icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
                userInfo: ["action": "search" as NSSecureCoding]
            )
        ]
    }
    
    private func getRecentStreams() -> [RecentStream] {
        // Load from UserDefaults for demo purposes
        // In a real app, this would come from Core Data or other persistence layer
        guard let data = userDefaults.data(forKey: "recent_streams"),
              let streams = try? JSONDecoder().decode([RecentStream].self, from: data) else {
            return []
        }
        return streams
    }
    
    private func addRecentStream(_ stream: RecentStream) {
        var recentStreams = getRecentStreams()
        
        // Remove if already exists
        recentStreams.removeAll { $0.id == stream.id }
        
        // Add to beginning
        recentStreams.insert(stream, at: 0)
        
        // Keep only last 5
        recentStreams = Array(recentStreams.prefix(5))
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(recentStreams) {
            userDefaults.set(data, forKey: "recent_streams")
        }
    }
    
    private func updateFavoriteShortcut(_ stream: RecentStream) {
        // Update shortcuts to reflect new favorite
        setupDynamicShortcuts()
    }
    
    private func updateSearchShortcut(_ query: String) {
        // Could store recent searches and update shortcuts
        // For now, just refresh shortcuts
        setupDynamicShortcuts()
    }
    
    // MARK: - Shortcut Handlers
    
    private func handleBrowseLive(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        // Navigate to browse/discover view
        NotificationCenter.default.post(
            name: .navigateToView,
            object: nil,
            userInfo: ["destination": "browse"]
        )
        
        // Track analytics
        trackShortcutUsage("browse_live")
        
        return true
    }
    
    private func handleSearch(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        // Navigate to search view
        NotificationCenter.default.post(
            name: .navigateToView,
            object: nil,
            userInfo: ["destination": "search"]
        )
        
        // Track analytics
        trackShortcutUsage("search")
        
        return true
    }
    
    private func handleFavorites(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        // Navigate to favorites view
        NotificationCenter.default.post(
            name: .navigateToView,
            object: nil,
            userInfo: ["destination": "favorites"]
        )
        
        // Track analytics
        trackShortcutUsage("favorites")
        
        return true
    }
    
    private func handleAddStream(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        // Navigate to add stream view
        NotificationCenter.default.post(
            name: .navigateToView,
            object: nil,
            userInfo: ["destination": "add_stream"]
        )
        
        // Track analytics
        trackShortcutUsage("add_stream")
        
        return true
    }
    
    private func handleOpenStream(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let streamId = shortcutItem.userInfo?["stream_id"] as? String,
              let streamUrl = shortcutItem.userInfo?["stream_url"] as? String else {
            return false
        }
        
        // Navigate to specific stream
        NotificationCenter.default.post(
            name: .navigateToView,
            object: nil,
            userInfo: [
                "destination": "stream",
                "stream_id": streamId,
                "stream_url": streamUrl
            ]
        )
        
        // Track analytics
        trackShortcutUsage("open_stream")
        
        return true
    }
    
    private func trackShortcutUsage(_ shortcutType: String) {
        // Implement analytics tracking
        print("Shortcut used: \(shortcutType)")
    }
}

// MARK: - Supporting Types

struct RecentStream: Codable, Identifiable {
    let id: String
    let title: String
    let platform: String
    let url: String
    let thumbnailUrl: String?
    let lastWatched: Date
    
    init(id: String, title: String, platform: String, url: String, thumbnailUrl: String? = nil) {
        self.id = id
        self.title = title
        self.platform = platform
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.lastWatched = Date()
    }
}

enum UserActivity {
    case watchedStream(RecentStream)
    case favoriteAdded(RecentStream)
    case searchPerformed(String)
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToView = Notification.Name("navigateToView")
    static let shortcutSelected = Notification.Name("shortcutSelected")
}

// MARK: - SwiftUI Integration

struct AppShortcutsView: View {
    @ObservedObject var shortcutsManager: AppShortcutsManager
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("Enable App Shortcuts", isOn: $shortcutsManager.isShortcutsEnabled)
                        .onChange(of: shortcutsManager.isShortcutsEnabled) { enabled in
                            shortcutsManager.toggleShortcuts(enabled)
                        }
                } header: {
                    Text("Quick Actions")
                } footer: {
                    Text("Enable quick actions that appear when you force touch the app icon")
                }
                
                if shortcutsManager.isShortcutsEnabled {
                    Section {
                        ForEach(shortcutsManager.availableShortcuts, id: \.type) { shortcut in
                            HStack {
                                Image(systemName: getSystemImageName(for: shortcut))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(shortcut.localizedTitle)
                                        .font(.headline)
                                    
                                    if let subtitle = shortcut.localizedSubtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Available Shortcuts")
                    } footer: {
                        Text("These shortcuts will appear when you force touch the app icon on your home screen")
                    }
                }
            }
            .navigationTitle("App Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func getSystemImageName(for shortcut: UIApplicationShortcutItem) -> String {
        switch shortcut.type {
        case "com.streamyyy.quickbrowse", "com.streamyyy.browse":
            return "play.circle"
        case "com.streamyyy.search":
            return "magnifyingglass"
        case "com.streamyyy.favorites":
            return "heart.fill"
        case "com.streamyyy.addstream":
            return "plus.circle"
        default:
            if shortcut.type.contains("recentstream") {
                return "play.rectangle"
            }
            return "app"
        }
    }
}

// MARK: - App Delegate Integration

extension AppShortcutsManager {
    
    /// Handle shortcut from SceneDelegate
    func handleShortcutFromScene(_ shortcutItem: UIApplicationShortcutItem) {
        _ = handleShortcut(shortcutItem)
    }
    
    /// Setup shortcuts when app becomes active
    func setupShortcutsOnAppActivation() {
        setupDynamicShortcuts()
    }
}

// MARK: - Accessibility Support

extension AppShortcutsManager {
    
    /// Configure accessibility for shortcuts
    func configureAccessibilityForShortcuts() {
        // Ensure shortcuts are accessible to VoiceOver users
        // This would be implemented in the UI layer
    }
    
    /// Create accessible shortcut descriptions
    private func createAccessibleShortcut(
        type: String,
        title: String,
        subtitle: String?,
        icon: UIApplicationShortcutIcon,
        userInfo: [String: NSSecureCoding]
    ) -> UIApplicationShortcutItem {
        
        let shortcut = UIApplicationShortcutItem(
            type: type,
            localizedTitle: title,
            localizedSubtitle: subtitle,
            icon: icon,
            userInfo: userInfo
        )
        
        return shortcut
    }
}

// MARK: - Error Handling

enum ShortcutError: Error, LocalizedError {
    case shortcutNotFound
    case invalidShortcutData
    case navigationFailed
    
    var errorDescription: String? {
        switch self {
        case .shortcutNotFound:
            return "Shortcut not found"
        case .invalidShortcutData:
            return "Invalid shortcut data"
        case .navigationFailed:
            return "Failed to navigate to destination"
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension AppShortcutsManager {
    
    /// Test shortcut functionality
    func testShortcuts() {
        let testShortcut = UIApplicationShortcutItem(
            type: "com.streamyyy.test",
            localizedTitle: "Test Shortcut",
            localizedSubtitle: "Testing purposes",
            icon: UIApplicationShortcutIcon(systemImageName: "hammer"),
            userInfo: ["action": "test" as NSSecureCoding]
        )
        
        _ = handleShortcut(testShortcut)
    }
    
    /// Mock recent streams for testing
    func mockRecentStreams() {
        let mockStreams = [
            RecentStream(id: "1", title: "Test Stream 1", platform: "Twitch", url: "https://twitch.tv/test1"),
            RecentStream(id: "2", title: "Test Stream 2", platform: "YouTube", url: "https://youtube.com/test2")
        ]
        
        if let data = try? JSONEncoder().encode(mockStreams) {
            userDefaults.set(data, forKey: "recent_streams")
        }
        
        setupDynamicShortcuts()
    }
}
#endif