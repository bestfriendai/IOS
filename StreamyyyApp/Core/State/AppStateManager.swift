//
//  AppStateManager.swift
//  StreamyyyApp
//
//  Centralized app state management for cross-page integration
//

import SwiftUI
import Combine

// MARK: - App State Manager
@MainActor
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    // MARK: - Published State
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var selectedTab: MainTab = .discover
    @Published var selectedTheme: AppTheme = .dark
    @Published var networkStatus: NetworkStatus = .connected
    @Published var isLoading = false
    @Published var globalError: AppError?
    
    // MARK: - Service References
    @Published var streamManager = MultiStreamManager.shared
    @Published var authService = AuthenticationService.shared
    @Published var favoritesService = UserFavoritesService.shared
    @Published var historyService = ViewingHistoryService.shared
    @Published var collectionsService = StreamCollectionsService.shared
    @Published var profileManager = ProfileManager.shared
    @Published var subscriptionManager = SubscriptionManager.shared
    
    // MARK: - Cross-Page Communication
    @Published var pendingStreamToAdd: TwitchStream?
    @Published var shouldNavigateToMultiStream = false
    @Published var shouldNavigateToLibrary = false
    @Published var shouldNavigateToProfile = false
    
    // MARK: - App Settings
    @Published var appSettings = AppSettings()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupStateObservers()
        loadAppSettings()
        setupNetworkMonitoring()
    }
    
    // MARK: - State Management
    private func setupStateObservers() {
        // Monitor authentication state
        authService.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        authService.$currentUser
            .assign(to: &$currentUser)
        
        // Monitor theme changes
        $selectedTheme
            .sink { [weak self] theme in
                self?.appSettings.selectedTheme = theme
                self?.saveAppSettings()
            }
            .store(in: &cancellables)
        
        // Monitor error states from all services
        Publishers.CombineLatest4(
            authService.$lastError,
            streamManager.$errorMessage,
            favoritesService.$lastError,
            historyService.$lastError
        )
        .compactMap { authError, streamError, favError, histError in
            authError ?? streamError.map(AppError.general) ?? favError ?? histError
        }
        .assign(to: &$globalError)
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network connectivity
        NetworkMonitor.shared.$isConnected
            .map { $0 ? NetworkStatus.connected : NetworkStatus.disconnected }
            .assign(to: &$networkStatus)
    }
    
    // MARK: - Cross-Page Actions
    func addStreamFromDiscover(_ stream: TwitchStream) {
        // Add stream to multi-stream manager
        if let availableSlot = streamManager.activeStreams.firstIndex(where: { $0.stream == nil }) {
            streamManager.addStream(stream, to: availableSlot)
        } else {
            // If no slots available, store for later and navigate to multi-stream
            pendingStreamToAdd = stream
            shouldNavigateToMultiStream = true
        }
        
        // Add to viewing history
        Task {
            await historyService.addToHistory(
                streamId: stream.id,
                title: stream.title,
                streamerName: stream.userName,
                platform: .twitch,
                thumbnailURL: stream.thumbnailUrl,
                category: stream.gameName
            )
        }
    }
    
    func addToFavoritesFromDiscover(_ stream: TwitchStream) {
        Task {
            await favoritesService.addFavorite(
                streamId: stream.id,
                title: stream.title,
                streamerName: stream.userName,
                platform: "Twitch",
                url: "https://twitch.tv/\(stream.userLogin)",
                gameName: stream.gameName ?? "Unknown",
                thumbnailURL: stream.thumbnailUrl
            )
        }
    }
    
    func navigateToTab(_ tab: MainTab) {
        selectedTab = tab
    }
    
    func showStreamInMultiView(_ stream: TwitchStream) {
        addStreamFromDiscover(stream)
        navigateToTab(.watch)
    }
    
    func clearPendingActions() {
        pendingStreamToAdd = nil
        shouldNavigateToMultiStream = false
        shouldNavigateToLibrary = false
        shouldNavigateToProfile = false
    }
    
    // MARK: - Settings Management
    private func loadAppSettings() {
        if let data = UserDefaults.standard.data(forKey: "AppSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            appSettings = settings
            selectedTheme = settings.selectedTheme
        }
    }
    
    private func saveAppSettings() {
        if let data = try? JSONEncoder().encode(appSettings) {
            UserDefaults.standard.set(data, forKey: "AppSettings")
        }
    }
    
    func updateAppSettings(_ newSettings: AppSettings) {
        appSettings = newSettings
        selectedTheme = newSettings.selectedTheme
        saveAppSettings()
    }
    
    // MARK: - Error Handling
    func clearError() {
        globalError = nil
    }
    
    func showError(_ error: AppError) {
        globalError = error
    }
    
    // MARK: - Loading States
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    // MARK: - Data Refresh
    func refreshAllData() async {
        setLoading(true)
        
        await withTaskGroup(of: Void.self) { group in
            if isAuthenticated {
                group.addTask { [weak self] in
                    await self?.favoritesService.syncFavorites()
                }
                group.addTask { [weak self] in
                    await self?.historyService.refreshHistory()
                }
                group.addTask { [weak self] in
                    await self?.collectionsService.syncCollections()
                }
                group.addTask { [weak self] in
                    await self?.profileManager.refreshProfile()
                }
                group.addTask { [weak self] in
                    await self?.subscriptionManager.refreshSubscription()
                }
            }
        }
        
        setLoading(false)
    }
    
    // MARK: - Theme Management
    func setTheme(_ theme: AppTheme) {
        selectedTheme = theme
        appSettings.selectedTheme = theme
        saveAppSettings()
    }
    
    func toggleTheme() {
        let newTheme: AppTheme = selectedTheme == .dark ? .light : .dark
        setTheme(newTheme)
    }
}

// MARK: - Supporting Types

enum MainTab: Int, CaseIterable {
    case discover = 0
    case watch = 1
    case library = 2
    case profile = 3
    
    var title: String {
        switch self {
        case .discover: return "Discover"
        case .watch: return "Watch"
        case .library: return "Library"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .discover: return "safari"
        case .watch: return "rectangle.3.offgrid"
        case .library: return "books.vertical"
        case .profile: return "person.circle"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .discover: return "safari.fill"
        case .watch: return "rectangle.3.offgrid.fill"
        case .library: return "books.vertical.fill"
        case .profile: return "person.circle.fill"
        }
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

enum NetworkStatus {
    case connected
    case disconnected
    case limited
    
    var displayName: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .limited: return "Limited Connection"
        }
    }
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .red
        case .limited: return .orange
        }
    }
}

enum AppError: Error, Identifiable {
    case authentication(String)
    case network(String)
    case data(String)
    case general(String)
    
    var id: String {
        switch self {
        case .authentication(let message): return "auth_\(message)"
        case .network(let message): return "network_\(message)"
        case .data(let message): return "data_\(message)"
        case .general(let message): return "general_\(message)"
        }
    }
    
    var title: String {
        switch self {
        case .authentication: return "Authentication Error"
        case .network: return "Network Error"
        case .data: return "Data Error"
        case .general: return "Error"
        }
    }
    
    var message: String {
        switch self {
        case .authentication(let message): return message
        case .network(let message): return message
        case .data(let message): return message
        case .general(let message): return message
        }
    }
}

struct AppSettings: Codable {
    var selectedTheme: AppTheme = .dark
    var autoPlayStreams = true
    var defaultStreamQuality: StreamQuality = .medium
    var enableNotifications = true
    var enableHapticFeedback = true
    var autoSyncData = true
    var cacheSize: Double = 500 // MB
    var preferredLanguage = "en"
    var accessibilityEnabled = false
    var dataUsageMode: DataUsageMode = .normal
    
    enum DataUsageMode: String, CaseIterable, Codable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        
        var displayName: String {
            switch self {
            case .low: return "Low Data"
            case .normal: return "Normal"
            case .high: return "High Quality"
            }
        }
    }
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    
    private init() {
        // Simple network monitoring
        // In a real app, you'd use Network framework
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        // Placeholder implementation
        // Real implementation would use NWPathMonitor
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Simulate network check
            self?.isConnected = true
        }
    }
}

// MARK: - View Extensions
extension View {
    func withAppState() -> some View {
        self.environmentObject(AppStateManager.shared)
    }
    
    func onStreamAdd(_ action: @escaping (TwitchStream) -> Void) -> some View {
        self.environmentObject(AppStateManager.shared)
            .onReceive(AppStateManager.shared.$pendingStreamToAdd.compactMap { $0 }) { stream in
                action(stream)
                AppStateManager.shared.clearPendingActions()
            }
    }
}