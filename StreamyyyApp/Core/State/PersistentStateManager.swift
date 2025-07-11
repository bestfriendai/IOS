//
//  PersistentStateManager.swift
//  StreamyyyApp
//
//  Enhanced state management with automatic persistence
//  Provides robust state management across app launches with intelligent caching
//

import Foundation
import SwiftUI
import Combine
import SwiftData

// MARK: - Persistent State Manager
@MainActor
public class PersistentStateManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = PersistentStateManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isReady: Bool = false
    @Published public private(set) var lastStateLoad: Date?
    @Published public private(set) var lastStateSave: Date?
    @Published public private(set) var stateLoadError: StateError?
    
    // MARK: - App State Properties
    @Published public var isAuthenticated: Bool = false {
        didSet { persistStateIfNeeded(\.isAuthenticated) }
    }
    
    @Published public var currentUser: User? {
        didSet { persistStateIfNeeded(\.currentUser) }
    }
    
    @Published public var selectedTab: MainTab = .discover {
        didSet { persistStateIfNeeded(\.selectedTab) }
    }
    
    @Published public var selectedTheme: AppTheme = .dark {
        didSet { persistStateIfNeeded(\.selectedTheme) }
    }
    
    @Published public var networkStatus: NetworkStatus = .connected {
        didSet { persistStateIfNeeded(\.networkStatus) }
    }
    
    @Published public var isOfflineMode: Bool = false {
        didSet { persistStateIfNeeded(\.isOfflineMode) }
    }
    
    @Published public var lastSyncTime: Date? {
        didSet { persistStateIfNeeded(\.lastSyncTime) }
    }
    
    @Published public var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0" {
        didSet { persistStateIfNeeded(\.appVersion) }
    }
    
    // MARK: - Stream State
    @Published public var currentStreamLayout: Layout? {
        didSet { persistStateIfNeeded(\.currentStreamLayout) }
    }
    
    @Published public var activeStreams: [String] = [] {
        didSet { persistStateIfNeeded(\.activeStreams) }
    }
    
    @Published public var recentlyViewedStreams: [String] = [] {
        didSet { persistStateIfNeeded(\.recentlyViewedStreams) }
    }
    
    @Published public var favoriteStreams: [String] = [] {
        didSet { persistStateIfNeeded(\.favoriteStreams) }
    }
    
    // MARK: - UI State
    @Published public var windowSize: CGSize = .zero {
        didSet { persistStateIfNeeded(\.windowSize) }
    }
    
    @Published public var orientation: UIDeviceOrientation = .portrait {
        didSet { persistStateIfNeeded(\.orientation) }
    }
    
    @Published public var isFullScreenMode: Bool = false {
        didSet { persistStateIfNeeded(\.isFullScreenMode) }
    }
    
    @Published public var sidebarVisible: Bool = true {
        didSet { persistStateIfNeeded(\.sidebarVisible) }
    }
    
    // MARK: - User Preferences
    @Published public var userPreferences: PersistentUserPreferences = PersistentUserPreferences() {
        didSet { persistStateIfNeeded(\.userPreferences) }
    }
    
    // MARK: - Session State
    @Published public var sessionStartTime: Date = Date() {
        didSet { persistStateIfNeeded(\.sessionStartTime) }
    }
    
    @Published public var totalSessionTime: TimeInterval = 0 {
        didSet { persistStateIfNeeded(\.totalSessionTime) }
    }
    
    @Published public var backgroundTime: TimeInterval = 0 {
        didSet { persistStateIfNeeded(\.backgroundTime) }
    }
    
    // MARK: - Services
    private let dataService: DataService
    private let cacheService: CacheService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Persistence Configuration
    private let persistenceDelay: TimeInterval = 2.0 // Debounce saves
    private var persistenceTimer: Timer?
    private var needsPersistence: Set<String> = []
    
    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let stateKey = "PersistentAppState"
    private let preferencesKey = "UserPreferences"
    private let sessionKey = "SessionState"
    
    // MARK: - State Validation
    private var lastValidState: PersistentAppState?
    private var stateVersion: Int = 1
    
    // MARK: - Background State Management
    private var applicationDidEnterBackground: Date?
    private var applicationWillEnterForeground: Date?
    
    // MARK: - Initialization
    private init() {
        self.dataService = DataService.shared
        self.cacheService = CacheService.shared
        
        setupStateManager()
        loadPersistedState()
        setupNotificationObservers()
        startStateMonitoring()
    }
    
    // MARK: - Setup
    private func setupStateManager() {
        // Monitor data service readiness
        dataService.$isReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                if isReady {
                    self?.syncWithDataService()
                }
            }
            .store(in: &cancellables)
        
        // Monitor cache service state
        cacheService.$isOfflineModeEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: \.isOfflineMode, on: self)
            .store(in: &cancellables)
        
        // Monitor authentication state
        dataService.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncStatus in
                self?.isAuthenticated = syncStatus != .offline
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationObservers() {
        // App lifecycle notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillTerminate()
        }
        
        // Memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        // Device orientation
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.orientation = UIDevice.current.orientation
        }
    }
    
    private func startStateMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateSessionTime()
        }
    }
    
    // MARK: - State Persistence
    private func persistStateIfNeeded<T>(_ keyPath: KeyPath<PersistentStateManager, T>) {
        let key = String(describing: keyPath)
        needsPersistence.insert(key)
        
        // Debounce rapid changes
        persistenceTimer?.invalidate()
        persistenceTimer = Timer.scheduledTimer(withTimeInterval: persistenceDelay, repeats: false) { [weak self] _ in
            self?.persistState()
        }
    }
    
    private func persistState() {
        let currentState = createCurrentState()
        
        do {
            let data = try JSONEncoder().encode(currentState)
            userDefaults.set(data, forKey: stateKey)
            userDefaults.set(Date(), forKey: "\(stateKey)_lastSave")
            
            lastStateSave = Date()
            needsPersistence.removeAll()
            
            // Validate state after save
            validatePersistedState(currentState)
            
        } catch {
            stateLoadError = .persistenceFailed(error)
            print("❌ Failed to persist state: \(error)")
        }
    }
    
    private func loadPersistedState() {
        guard let data = userDefaults.data(forKey: stateKey) else {
            // No persisted state, use defaults
            isReady = true
            return
        }
        
        do {
            let persistedState = try JSONDecoder().decode(PersistentAppState.self, from: data)
            
            // Validate state version
            if persistedState.version < stateVersion {
                migrateState(from: persistedState)
            } else {
                applyPersistedState(persistedState)
            }
            
            lastStateLoad = userDefaults.object(forKey: "\(stateKey)_lastSave") as? Date
            isReady = true
            
        } catch {
            stateLoadError = .loadFailed(error)
            print("❌ Failed to load persisted state: \(error)")
            
            // Use defaults on failure
            isReady = true
        }
    }
    
    private func applyPersistedState(_ state: PersistentAppState) {
        // Apply state without triggering persistence
        withoutPersistence {
            selectedTab = state.selectedTab
            selectedTheme = state.selectedTheme
            isOfflineMode = state.isOfflineMode
            lastSyncTime = state.lastSyncTime
            appVersion = state.appVersion
            activeStreams = state.activeStreams
            recentlyViewedStreams = state.recentlyViewedStreams
            favoriteStreams = state.favoriteStreams
            windowSize = state.windowSize
            orientation = state.orientation
            isFullScreenMode = state.isFullScreenMode
            sidebarVisible = state.sidebarVisible
            userPreferences = state.userPreferences
            sessionStartTime = state.sessionStartTime
            totalSessionTime = state.totalSessionTime
            backgroundTime = state.backgroundTime
        }
        
        lastValidState = state
    }
    
    private func withoutPersistence<T>(_ block: () throws -> T) rethrows -> T {
        let timer = persistenceTimer
        persistenceTimer = nil
        defer { persistenceTimer = timer }
        return try block()
    }
    
    // MARK: - State Creation
    private func createCurrentState() -> PersistentAppState {
        return PersistentAppState(
            version: stateVersion,
            selectedTab: selectedTab,
            selectedTheme: selectedTheme,
            isOfflineMode: isOfflineMode,
            lastSyncTime: lastSyncTime,
            appVersion: appVersion,
            activeStreams: activeStreams,
            recentlyViewedStreams: recentlyViewedStreams,
            favoriteStreams: favoriteStreams,
            windowSize: windowSize,
            orientation: orientation,
            isFullScreenMode: isFullScreenMode,
            sidebarVisible: sidebarVisible,
            userPreferences: userPreferences,
            sessionStartTime: sessionStartTime,
            totalSessionTime: totalSessionTime,
            backgroundTime: backgroundTime,
            lastSaved: Date()
        )
    }
    
    // MARK: - State Migration
    private func migrateState(from oldState: PersistentAppState) {
        print("🔄 Migrating state from version \(oldState.version) to \(stateVersion)")
        
        // Apply migration logic here
        var migratedState = oldState
        migratedState.version = stateVersion
        
        // Example migration logic
        if oldState.version < 1 {
            // Migrate from version 0 to 1
            migratedState.userPreferences = PersistentUserPreferences()
        }
        
        applyPersistedState(migratedState)
        persistState() // Save migrated state
    }
    
    // MARK: - State Validation
    private func validatePersistedState(_ state: PersistentAppState) {
        // Validate state integrity
        var isValid = true
        
        // Validate arrays
        if state.activeStreams.count > 50 {
            print("⚠️ Active streams count seems unusually high: \(state.activeStreams.count)")
            isValid = false
        }
        
        if state.recentlyViewedStreams.count > 1000 {
            print("⚠️ Recently viewed streams count is very high: \(state.recentlyViewedStreams.count)")
            isValid = false
        }
        
        // Validate dates
        if state.sessionStartTime > Date() {
            print("⚠️ Session start time is in the future")
            isValid = false
        }
        
        if !isValid {
            print("⚠️ State validation failed, may need recovery")
        }
        
        lastValidState = isValid ? state : lastValidState
    }
    
    // MARK: - Recovery
    public func recoverState() {
        guard let validState = lastValidState else {
            resetToDefaults()
            return
        }
        
        applyPersistedState(validState)
        persistState()
        stateLoadError = nil
    }
    
    public func resetToDefaults() {
        withoutPersistence {
            selectedTab = .discover
            selectedTheme = .dark
            isOfflineMode = false
            lastSyncTime = nil
            activeStreams = []
            recentlyViewedStreams = []
            favoriteStreams = []
            windowSize = .zero
            orientation = .portrait
            isFullScreenMode = false
            sidebarVisible = true
            userPreferences = PersistentUserPreferences()
            sessionStartTime = Date()
            totalSessionTime = 0
            backgroundTime = 0
        }
        
        persistState()
        stateLoadError = nil
    }
    
    // MARK: - Data Service Integration
    private func syncWithDataService() {
        Task {
            // Sync user state
            if let user = dataService.getCurrentUser() {
                currentUser = user
            }
            
            // Sync favorites
            let favorites = dataService.getFavorites()
            favoriteStreams = favorites.map { $0.id }
            
            // Sync layouts
            if let defaultLayout = dataService.getDefaultLayout() {
                currentStreamLayout = defaultLayout
            }
        }
    }
    
    // MARK: - Public State Management Methods
    public func updateRecentlyViewed(_ streamId: String) {
        var updated = recentlyViewedStreams.filter { $0 != streamId }
        updated.insert(streamId, at: 0)
        
        // Keep only the most recent 100 streams
        if updated.count > 100 {
            updated = Array(updated.prefix(100))
        }
        
        recentlyViewedStreams = updated
    }
    
    public func addFavoriteStream(_ streamId: String) {
        if !favoriteStreams.contains(streamId) {
            favoriteStreams.append(streamId)
        }
    }
    
    public func removeFavoriteStream(_ streamId: String) {
        favoriteStreams.removeAll { $0 == streamId }
    }
    
    public func addActiveStream(_ streamId: String) {
        if !activeStreams.contains(streamId) {
            activeStreams.append(streamId)
        }
    }
    
    public func removeActiveStream(_ streamId: String) {
        activeStreams.removeAll { $0 == streamId }
    }
    
    public func updateUserPreference<T>(_ keyPath: WritableKeyPath<PersistentUserPreferences, T>, value: T) {
        userPreferences[keyPath: keyPath] = value
    }
    
    // MARK: - Session Management
    private func updateSessionTime() {
        let currentTime = Date()
        let sessionInterval = currentTime.timeIntervalSince(sessionStartTime)
        totalSessionTime = sessionInterval
    }
    
    private func handleDidEnterBackground() {
        applicationDidEnterBackground = Date()
        updateSessionTime()
        persistState() // Force immediate save
    }
    
    private func handleWillEnterForeground() {
        applicationWillEnterForeground = Date()
        
        if let backgroundTime = applicationDidEnterBackground {
            let backgroundDuration = Date().timeIntervalSince(backgroundTime)
            self.backgroundTime += backgroundDuration
        }
        
        // Check if we need to refresh data
        if let lastSync = lastSyncTime,
           Date().timeIntervalSince(lastSync) > 300 { // 5 minutes
            Task {
                await dataService.performIncrementalSync()
            }
        }
    }
    
    private func handleWillTerminate() {
        updateSessionTime()
        persistState()
    }
    
    private func handleMemoryWarning() {
        // Trim non-essential state
        if recentlyViewedStreams.count > 50 {
            recentlyViewedStreams = Array(recentlyViewedStreams.prefix(50))
        }
        
        persistState()
    }
    
    // MARK: - Analytics
    public func getSessionAnalytics() -> SessionAnalytics {
        return SessionAnalytics(
            sessionStartTime: sessionStartTime,
            totalSessionTime: totalSessionTime,
            backgroundTime: backgroundTime,
            activeStreamsCount: activeStreams.count,
            favoritesCount: favoriteStreams.count,
            recentlyViewedCount: recentlyViewedStreams.count,
            currentTheme: selectedTheme,
            isOfflineMode: isOfflineMode
        )
    }
    
    // MARK: - Export/Import
    public func exportState() -> Data? {
        let currentState = createCurrentState()
        return try? JSONEncoder().encode(currentState)
    }
    
    public func importState(from data: Data) throws {
        let importedState = try JSONDecoder().decode(PersistentAppState.self, from: data)
        
        // Validate imported state
        if importedState.version <= stateVersion {
            applyPersistedState(importedState)
            persistState()
        } else {
            throw StateError.incompatibleVersion
        }
    }
    
    // MARK: - Cleanup
    deinit {
        persistenceTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

public struct PersistentAppState: Codable {
    public var version: Int
    public var selectedTab: MainTab
    public var selectedTheme: AppTheme
    public var isOfflineMode: Bool
    public var lastSyncTime: Date?
    public var appVersion: String
    public var activeStreams: [String]
    public var recentlyViewedStreams: [String]
    public var favoriteStreams: [String]
    public var windowSize: CGSize
    public var orientation: UIDeviceOrientation
    public var isFullScreenMode: Bool
    public var sidebarVisible: Bool
    public var userPreferences: PersistentUserPreferences
    public var sessionStartTime: Date
    public var totalSessionTime: TimeInterval
    public var backgroundTime: TimeInterval
    public var lastSaved: Date
}

public struct PersistentUserPreferences: Codable {
    public var autoPlayStreams: Bool = true
    public var enableNotifications: Bool = true
    public var enableHapticFeedback: Bool = true
    public var defaultStreamQuality: StreamQuality = .high
    public var enablePictureInPicture: Bool = true
    public var enableSoundEffects: Bool = true
    public var maxSimultaneousStreams: Int = 4
    public var autoHideControls: Bool = true
    public var controlsTimeout: TimeInterval = 3.0
    public var enableAnalytics: Bool = true
    public var dataUsageMode: DataUsageMode = .normal
    public var preferredLanguage: String = "en"
    public var accessibilityEnabled: Bool = false
    public var fontSize: AppFontSize = .medium
    public var enableDarkModeSchedule: Bool = false
    public var darkModeStartTime: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    public var darkModeEndTime: Date = Calendar.current.date(from: DateComponents(hour: 6)) ?? Date()
    
    public enum DataUsageMode: String, CaseIterable, Codable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        
        public var displayName: String {
            switch self {
            case .low: return "Low Data"
            case .normal: return "Normal"
            case .high: return "High Quality"
            }
        }
    }
    
    public enum AppFontSize: String, CaseIterable, Codable {
        case small = "small"
        case medium = "medium"
        case large = "large"
        case extraLarge = "extraLarge"
        
        public var displayName: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
        
        public var scaleFactor: CGFloat {
            switch self {
            case .small: return 0.85
            case .medium: return 1.0
            case .large: return 1.15
            case .extraLarge: return 1.3
            }
        }
    }
}

public struct SessionAnalytics: Codable {
    public let sessionStartTime: Date
    public let totalSessionTime: TimeInterval
    public let backgroundTime: TimeInterval
    public let activeStreamsCount: Int
    public let favoritesCount: Int
    public let recentlyViewedCount: Int
    public let currentTheme: AppTheme
    public let isOfflineMode: Bool
    
    public var activeTime: TimeInterval {
        return totalSessionTime - backgroundTime
    }
    
    public var activePercentage: Double {
        guard totalSessionTime > 0 else { return 0 }
        return (activeTime / totalSessionTime) * 100
    }
}

public enum StateError: Error, LocalizedError {
    case loadFailed(Error)
    case persistenceFailed(Error)
    case incompatibleVersion
    case corruptedData
    case migrationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load app state: \(error.localizedDescription)"
        case .persistenceFailed(let error):
            return "Failed to save app state: \(error.localizedDescription)"
        case .incompatibleVersion:
            return "Incompatible state version"
        case .corruptedData:
            return "App state data is corrupted"
        case .migrationFailed(let error):
            return "State migration failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Codable Extensions

extension CGSize: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
    
    private enum CodingKeys: String, CodingKey {
        case width, height
    }
}

extension UIDeviceOrientation: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = UIDeviceOrientation(rawValue: rawValue) ?? .portrait
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - SwiftUI Integration

extension View {
    public func withPersistentState() -> some View {
        self.environmentObject(PersistentStateManager.shared)
    }
}

// MARK: - Property Wrapper for Persisted Values

@propertyWrapper
public struct Persisted<T: Codable> {
    private let key: String
    private let defaultValue: T
    private let stateManager = PersistentStateManager.shared
    
    public init(wrappedValue: T, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
    
    public var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}