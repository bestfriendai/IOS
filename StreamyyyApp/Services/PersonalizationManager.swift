//
//  PersonalizationManager.swift
//  StreamyyyApp
//
//  Comprehensive personalization and customization system
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import Combine
import UserNotifications

// MARK: - Personalization Manager
@MainActor
class PersonalizationManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentTheme: AppTheme = .dynamic
    @Published var customThemes: [CustomTheme] = []
    @Published var dashboardLayout: DashboardLayout = .default
    @Published var widgetConfigurations: [WidgetConfiguration] = []
    @Published var notificationSettings: NotificationSettings = NotificationSettings()
    @Published var userSettings: UserSettings = UserSettings()
    @Published var accessibilitySettings: AccessibilitySettings = AccessibilitySettings()
    @Published var layoutPreferences: LayoutPreferences = LayoutPreferences()
    @Published var contentPreferences: ContentPreferences = ContentPreferences()
    @Published var privacySettings: PrivacySettings = PrivacySettings()
    @Published var experienceLevel: ExperienceLevel = .intermediate
    @Published var customizations: [String: Any] = [:]
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let themeEngine = ThemeEngine()
    private let notificationManager = SmartNotificationManager()
    private let analyticsTracker = PersonalizationAnalytics()
    
    // MARK: - Initialization
    init() {
        loadPersonalizationSettings()
        setupThemeEngine()
        setupNotifications()
        applyDefaultCustomizations()
    }
    
    // MARK: - Theme Management
    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        themeEngine.applyTheme(theme)
        savePersonalizationSettings()
        
        // Notify UI components of theme change
        NotificationCenter.default.post(
            name: .themeDidChange,
            object: theme
        )
    }
    
    func createCustomTheme(name: String, colors: ThemeColors, typography: ThemeTypography? = nil) {
        let customTheme = CustomTheme(
            id: UUID().uuidString,
            name: name,
            colors: colors,
            typography: typography ?? ThemeTypography.default,
            effects: ThemeEffects.default,
            createdAt: Date()
        )
        
        customThemes.append(customTheme)
        savePersonalizationSettings()
        
        // Automatically apply the new theme
        applyTheme(.custom(customTheme))
    }
    
    func updateCustomTheme(_ themeId: String, colors: ThemeColors) {
        if let index = customThemes.firstIndex(where: { $0.id == themeId }) {
            customThemes[index].colors = colors
            customThemes[index].updatedAt = Date()
            savePersonalizationSettings()
            
            // Reapply theme if it's currently active
            if case .custom(let activeTheme) = currentTheme, activeTheme.id == themeId {
                applyTheme(.custom(customThemes[index]))
            }
        }
    }
    
    func deleteCustomTheme(_ themeId: String) {
        customThemes.removeAll { $0.id == themeId }
        
        // Switch to default theme if deleted theme was active
        if case .custom(let activeTheme) = currentTheme, activeTheme.id == themeId {
            applyTheme(.dynamic)
        }
        
        savePersonalizationSettings()
    }
    
    func importTheme(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let importedTheme = try JSONDecoder().decode(CustomTheme.self, from: data)
        
        // Assign new ID to avoid conflicts
        var newTheme = importedTheme
        newTheme.id = UUID().uuidString
        newTheme.createdAt = Date()
        
        customThemes.append(newTheme)
        savePersonalizationSettings()
    }
    
    func exportTheme(_ themeId: String) throws -> URL {
        guard let theme = customThemes.first(where: { $0.id == themeId }) else {
            throw PersonalizationError.themeNotFound
        }
        
        let data = try JSONEncoder().encode(theme)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(theme.name).streamyyy-theme")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Dashboard Customization
    func updateDashboardLayout(_ layout: DashboardLayout) {
        dashboardLayout = layout
        savePersonalizationSettings()
        
        NotificationCenter.default.post(
            name: .dashboardLayoutDidChange,
            object: layout
        )
    }
    
    func addWidget(_ widget: WidgetConfiguration) {
        widgetConfigurations.append(widget)
        savePersonalizationSettings()
    }
    
    func removeWidget(_ widgetId: String) {
        widgetConfigurations.removeAll { $0.id == widgetId }
        savePersonalizationSettings()
    }
    
    func updateWidgetPosition(_ widgetId: String, position: WidgetPosition) {
        if let index = widgetConfigurations.firstIndex(where: { $0.id == widgetId }) {
            widgetConfigurations[index].position = position
            savePersonalizationSettings()
        }
    }
    
    func updateWidgetSize(_ widgetId: String, size: WidgetSize) {
        if let index = widgetConfigurations.firstIndex(where: { $0.id == widgetId }) {
            widgetConfigurations[index].size = size
            savePersonalizationSettings()
        }
    }
    
    func getAvailableWidgets() -> [AvailableWidget] {
        return [
            AvailableWidget(type: .streamGrid, name: "Stream Grid", description: "Display multiple streams in a grid"),
            AvailableWidget(type: .trendingStreams, name: "Trending", description: "Shows trending streams"),
            AvailableWidget(type: .friendsActivity, name: "Friends Activity", description: "What your friends are watching"),
            AvailableWidget(type: .recommendations, name: "Recommendations", description: "AI-powered recommendations"),
            AvailableWidget(type: .quickActions, name: "Quick Actions", description: "Shortcuts for common actions"),
            AvailableWidget(type: .watchHistory, name: "Watch History", description: "Recent viewing history"),
            AvailableWidget(type: .analytics, name: "Analytics", description: "Your viewing statistics"),
            AvailableWidget(type: .notifications, name: "Notifications", description: "Recent notifications")
        ]
    }
    
    // MARK: - Smart Notifications
    func updateNotificationSettings(_ settings: NotificationSettings) {
        notificationSettings = settings
        notificationManager.updateSettings(settings)
        savePersonalizationSettings()
    }
    
    func scheduleSmartNotification(for event: NotificationEvent) {
        let notification = SmartNotification(
            id: UUID().uuidString,
            event: event,
            timestamp: Date(),
            priority: calculateNotificationPriority(for: event),
            personalized: true
        )
        
        notificationManager.scheduleNotification(notification)
    }
    
    func getNotificationHistory() -> [SmartNotification] {
        return notificationManager.getNotificationHistory()
    }
    
    func updateNotificationFrequency(for type: NotificationType, frequency: NotificationFrequency) {
        notificationSettings.frequencies[type] = frequency
        notificationManager.updateFrequency(for: type, frequency: frequency)
        savePersonalizationSettings()
    }
    
    // MARK: - User Experience Customization
    func updateExperienceLevel(_ level: ExperienceLevel) {
        experienceLevel = level
        adjustUIComplexity(for: level)
        savePersonalizationSettings()
    }
    
    func customizeGestures(_ gestures: GestureConfiguration) {
        userSettings.gestureConfiguration = gestures
        savePersonalizationSettings()
        
        NotificationCenter.default.post(
            name: .gestureConfigurationDidChange,
            object: gestures
        )
    }
    
    func updateContentPreferences(_ preferences: ContentPreferences) {
        contentPreferences = preferences
        savePersonalizationSettings()
        
        // Update AI recommendations based on new preferences
        NotificationCenter.default.post(
            name: .contentPreferencesDidChange,
            object: preferences
        )
    }
    
    func setLayoutPreferences(_ preferences: LayoutPreferences) {
        layoutPreferences = preferences
        savePersonalizationSettings()
        
        NotificationCenter.default.post(
            name: .layoutPreferencesDidChange,
            object: preferences
        )
    }
    
    // MARK: - Accessibility Features
    func updateAccessibilitySettings(_ settings: AccessibilitySettings) {
        accessibilitySettings = settings
        applyAccessibilitySettings(settings)
        savePersonalizationSettings()
    }
    
    func enableHighContrast(_ enabled: Bool) {
        accessibilitySettings.highContrast = enabled
        updateAccessibilitySettings(accessibilitySettings)
    }
    
    func updateFontSize(_ size: AccessibilityFontSize) {
        accessibilitySettings.fontSize = size
        updateAccessibilitySettings(accessibilitySettings)
    }
    
    func enableVoiceOver(_ enabled: Bool) {
        accessibilitySettings.voiceOverEnabled = enabled
        updateAccessibilitySettings(accessibilitySettings)
    }
    
    func enableReducedMotion(_ enabled: Bool) {
        accessibilitySettings.reducedMotion = enabled
        updateAccessibilitySettings(accessibilitySettings)
    }
    
    // MARK: - Advanced Customization
    func setCustomValue<T>(_ value: T, forKey key: String) {
        customizations[key] = value
        savePersonalizationSettings()
    }
    
    func getCustomValue<T>(forKey key: String, type: T.Type) -> T? {
        return customizations[key] as? T
    }
    
    func createPersonalizedPreset(name: String) -> PersonalizationPreset {
        let preset = PersonalizationPreset(
            id: UUID().uuidString,
            name: name,
            theme: currentTheme,
            dashboardLayout: dashboardLayout,
            widgets: widgetConfigurations,
            notifications: notificationSettings,
            userSettings: userSettings,
            accessibility: accessibilitySettings,
            layoutPreferences: layoutPreferences,
            contentPreferences: contentPreferences,
            createdAt: Date()
        )
        
        savePreset(preset)
        return preset
    }
    
    func applyPersonalizationPreset(_ preset: PersonalizationPreset) {
        applyTheme(preset.theme)
        updateDashboardLayout(preset.dashboardLayout)
        widgetConfigurations = preset.widgets
        updateNotificationSettings(preset.notifications)
        userSettings = preset.userSettings
        updateAccessibilitySettings(preset.accessibility)
        setLayoutPreferences(preset.layoutPreferences)
        updateContentPreferences(preset.contentPreferences)
        
        savePersonalizationSettings()
        
        NotificationCenter.default.post(
            name: .personalizationPresetApplied,
            object: preset
        )
    }
    
    // MARK: - Analytics & Insights
    func getPersonalizationInsights() -> PersonalizationInsights {
        return PersonalizationInsights(
            mostUsedTheme: getMostUsedTheme(),
            averageSessionCustomizations: getAverageCustomizations(),
            preferredWidgets: getPreferredWidgets(),
            notificationEngagement: getNotificationEngagement(),
            accessibilityUsage: getAccessibilityUsage(),
            customizationFrequency: getCustomizationFrequency()
        )
    }
    
    func trackPersonalizationAction(_ action: PersonalizationAction) {
        analyticsTracker.trackAction(action)
    }
    
    // MARK: - Import/Export
    func exportPersonalizationProfile() throws -> URL {
        let profile = PersonalizationProfile(
            theme: currentTheme,
            customThemes: customThemes,
            dashboardLayout: dashboardLayout,
            widgets: widgetConfigurations,
            notifications: notificationSettings,
            userSettings: userSettings,
            accessibility: accessibilitySettings,
            layoutPreferences: layoutPreferences,
            contentPreferences: contentPreferences,
            experienceLevel: experienceLevel,
            customizations: customizations,
            exportedAt: Date()
        )
        
        let data = try JSONEncoder().encode(profile)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("streamyyy-profile.json")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    func importPersonalizationProfile(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let profile = try JSONDecoder().decode(PersonalizationProfile.self, from: data)
        
        // Apply imported settings
        applyTheme(profile.theme)
        customThemes = profile.customThemes
        updateDashboardLayout(profile.dashboardLayout)
        widgetConfigurations = profile.widgets
        updateNotificationSettings(profile.notifications)
        userSettings = profile.userSettings
        updateAccessibilitySettings(profile.accessibility)
        setLayoutPreferences(profile.layoutPreferences)
        updateContentPreferences(profile.contentPreferences)
        updateExperienceLevel(profile.experienceLevel)
        customizations = profile.customizations
        
        savePersonalizationSettings()
        
        NotificationCenter.default.post(
            name: .personalizationProfileImported,
            object: profile
        )
    }
    
    // MARK: - Private Methods
    private func setupThemeEngine() {
        themeEngine.delegate = self
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func applyDefaultCustomizations() {
        // Apply default customizations based on device and user context
        if UIDevice.current.userInterfaceIdiom == .pad {
            dashboardLayout = .wideGrid
        }
        
        // Add default widgets
        if widgetConfigurations.isEmpty {
            addDefaultWidgets()
        }
    }
    
    private func addDefaultWidgets() {
        let defaultWidgets = [
            WidgetConfiguration(
                id: UUID().uuidString,
                type: .streamGrid,
                position: WidgetPosition(x: 0, y: 0),
                size: .large,
                isEnabled: true
            ),
            WidgetConfiguration(
                id: UUID().uuidString,
                type: .recommendations,
                position: WidgetPosition(x: 0, y: 200),
                size: .medium,
                isEnabled: true
            ),
            WidgetConfiguration(
                id: UUID().uuidString,
                type: .friendsActivity,
                position: WidgetPosition(x: 200, y: 200),
                size: .medium,
                isEnabled: true
            )
        ]
        
        widgetConfigurations = defaultWidgets
    }
    
    private func adjustUIComplexity(for level: ExperienceLevel) {
        switch level {
        case .beginner:
            userSettings.showAdvancedFeatures = false
            userSettings.simplifiedUI = true
            userSettings.tooltipsEnabled = true
            
        case .intermediate:
            userSettings.showAdvancedFeatures = true
            userSettings.simplifiedUI = false
            userSettings.tooltipsEnabled = false
            
        case .expert:
            userSettings.showAdvancedFeatures = true
            userSettings.simplifiedUI = false
            userSettings.tooltipsEnabled = false
            userSettings.expertModeEnabled = true
        }
    }
    
    private func applyAccessibilitySettings(_ settings: AccessibilitySettings) {
        // Apply accessibility settings to the app
        if settings.highContrast {
            themeEngine.enableHighContrast()
        }
        
        if settings.reducedMotion {
            themeEngine.disableAnimations()
        }
        
        // Update font sizes
        themeEngine.updateFontSize(settings.fontSize)
    }
    
    private func calculateNotificationPriority(for event: NotificationEvent) -> NotificationPriority {
        switch event {
        case .friendGoesLive:
            return .high
        case .streamEnded:
            return .medium
        case .newRecommendation:
            return .low
        case .watchPartyInvite:
            return .high
        case .highlightDetected:
            return .medium
        default:
            return .low
        }
    }
    
    private func getMostUsedTheme() -> AppTheme {
        return analyticsTracker.getMostUsedTheme()
    }
    
    private func getAverageCustomizations() -> Double {
        return analyticsTracker.getAverageCustomizations()
    }
    
    private func getPreferredWidgets() -> [WidgetType] {
        return analyticsTracker.getPreferredWidgets()
    }
    
    private func getNotificationEngagement() -> Double {
        return analyticsTracker.getNotificationEngagement()
    }
    
    private func getAccessibilityUsage() -> [String: Bool] {
        return analyticsTracker.getAccessibilityUsage()
    }
    
    private func getCustomizationFrequency() -> Double {
        return analyticsTracker.getCustomizationFrequency()
    }
    
    private func savePreset(_ preset: PersonalizationPreset) {
        var presets = getPersonalizationPresets()
        presets.append(preset)
        
        if let data = try? JSONEncoder().encode(presets) {
            userDefaults.set(data, forKey: "personalization_presets")
        }
    }
    
    private func getPersonalizationPresets() -> [PersonalizationPreset] {
        guard let data = userDefaults.data(forKey: "personalization_presets"),
              let presets = try? JSONDecoder().decode([PersonalizationPreset].self, from: data) else {
            return []
        }
        return presets
    }
    
    private func loadPersonalizationSettings() {
        // Load theme
        if let themeData = userDefaults.data(forKey: "current_theme"),
           let theme = try? JSONDecoder().decode(AppTheme.self, from: themeData) {
            currentTheme = theme
        }
        
        // Load custom themes
        if let themesData = userDefaults.data(forKey: "custom_themes"),
           let themes = try? JSONDecoder().decode([CustomTheme].self, from: themesData) {
            customThemes = themes
        }
        
        // Load dashboard layout
        if let layoutData = userDefaults.data(forKey: "dashboard_layout"),
           let layout = try? JSONDecoder().decode(DashboardLayout.self, from: layoutData) {
            dashboardLayout = layout
        }
        
        // Load widget configurations
        if let widgetsData = userDefaults.data(forKey: "widget_configurations"),
           let widgets = try? JSONDecoder().decode([WidgetConfiguration].self, from: widgetsData) {
            widgetConfigurations = widgets
        }
        
        // Load notification settings
        if let notificationData = userDefaults.data(forKey: "notification_settings"),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: notificationData) {
            notificationSettings = settings
        }
        
        // Load user settings
        if let userSettingsData = userDefaults.data(forKey: "user_settings"),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: userSettingsData) {
            userSettings = settings
        }
        
        // Load accessibility settings
        if let accessibilityData = userDefaults.data(forKey: "accessibility_settings"),
           let settings = try? JSONDecoder().decode(AccessibilitySettings.self, from: accessibilityData) {
            accessibilitySettings = settings
        }
        
        // Load layout preferences
        if let layoutPrefData = userDefaults.data(forKey: "layout_preferences"),
           let preferences = try? JSONDecoder().decode(LayoutPreferences.self, from: layoutPrefData) {
            layoutPreferences = preferences
        }
        
        // Load content preferences
        if let contentPrefData = userDefaults.data(forKey: "content_preferences"),
           let preferences = try? JSONDecoder().decode(ContentPreferences.self, from: contentPrefData) {
            contentPreferences = preferences
        }
        
        // Load experience level
        if let levelRaw = userDefaults.object(forKey: "experience_level") as? String,
           let level = ExperienceLevel(rawValue: levelRaw) {
            experienceLevel = level
        }
        
        // Load customizations
        if let customizationsData = userDefaults.data(forKey: "customizations"),
           let custom = try? JSONSerialization.jsonObject(with: customizationsData) as? [String: Any] {
            customizations = custom
        }
    }
    
    private func savePersonalizationSettings() {
        // Save theme
        if let themeData = try? JSONEncoder().encode(currentTheme) {
            userDefaults.set(themeData, forKey: "current_theme")
        }
        
        // Save custom themes
        if let themesData = try? JSONEncoder().encode(customThemes) {
            userDefaults.set(themesData, forKey: "custom_themes")
        }
        
        // Save dashboard layout
        if let layoutData = try? JSONEncoder().encode(dashboardLayout) {
            userDefaults.set(layoutData, forKey: "dashboard_layout")
        }
        
        // Save widget configurations
        if let widgetsData = try? JSONEncoder().encode(widgetConfigurations) {
            userDefaults.set(widgetsData, forKey: "widget_configurations")
        }
        
        // Save notification settings
        if let notificationData = try? JSONEncoder().encode(notificationSettings) {
            userDefaults.set(notificationData, forKey: "notification_settings")
        }
        
        // Save user settings
        if let userSettingsData = try? JSONEncoder().encode(userSettings) {
            userDefaults.set(userSettingsData, forKey: "user_settings")
        }
        
        // Save accessibility settings
        if let accessibilityData = try? JSONEncoder().encode(accessibilitySettings) {
            userDefaults.set(accessibilityData, forKey: "accessibility_settings")
        }
        
        // Save layout preferences
        if let layoutPrefData = try? JSONEncoder().encode(layoutPreferences) {
            userDefaults.set(layoutPrefData, forKey: "layout_preferences")
        }
        
        // Save content preferences
        if let contentPrefData = try? JSONEncoder().encode(contentPreferences) {
            userDefaults.set(contentPrefData, forKey: "content_preferences")
        }
        
        // Save experience level
        userDefaults.set(experienceLevel.rawValue, forKey: "experience_level")
        
        // Save customizations
        if let customizationsData = try? JSONSerialization.data(withJSONObject: customizations) {
            userDefaults.set(customizationsData, forKey: "customizations")
        }
    }
}

// MARK: - Theme Engine Delegate
extension PersonalizationManager: ThemeEngineDelegate {
    func themeDidApply(_ theme: AppTheme) {
        trackPersonalizationAction(.themeChanged(theme))
    }
    
    func themeApplicationFailed(_ error: Error) {
        print("Theme application failed: \(error)")
    }
}

// MARK: - Data Models

public struct CustomTheme: Identifiable, Codable {
    public var id: String
    public var name: String
    public var colors: ThemeColors
    public var typography: ThemeTypography
    public var effects: ThemeEffects
    public let createdAt: Date
    public var updatedAt: Date?
    
    public init(
        id: String,
        name: String,
        colors: ThemeColors,
        typography: ThemeTypography,
        effects: ThemeEffects,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.colors = colors
        self.typography = typography
        self.effects = effects
        self.createdAt = createdAt
    }
}

public struct ThemeColors: Codable {
    public var primary: Color
    public var secondary: Color
    public var accent: Color
    public var background: Color
    public var surface: Color
    public var text: Color
    public var textSecondary: Color
    public var success: Color
    public var warning: Color
    public var error: Color
    
    public static let `default` = ThemeColors(
        primary: .purple,
        secondary: .blue,
        accent: .orange,
        background: .black,
        surface: .gray.opacity(0.2),
        text: .white,
        textSecondary: .gray,
        success: .green,
        warning: .orange,
        error: .red
    )
    
    public init(
        primary: Color,
        secondary: Color,
        accent: Color,
        background: Color,
        surface: Color,
        text: Color,
        textSecondary: Color,
        success: Color,
        warning: Color,
        error: Color
    ) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.background = background
        self.surface = surface
        self.text = text
        self.textSecondary = textSecondary
        self.success = success
        self.warning = warning
        self.error = error
    }
}

public struct ThemeTypography: Codable {
    public var fontFamily: String
    public var headingFont: String
    public var bodyFont: String
    public var captionFont: String
    public var fontSizeScale: Double
    
    public static let `default` = ThemeTypography(
        fontFamily: "SF Pro",
        headingFont: "SF Pro Display",
        bodyFont: "SF Pro Text",
        captionFont: "SF Pro Text",
        fontSizeScale: 1.0
    )
    
    public init(
        fontFamily: String,
        headingFont: String,
        bodyFont: String,
        captionFont: String,
        fontSizeScale: Double
    ) {
        self.fontFamily = fontFamily
        self.headingFont = headingFont
        self.bodyFont = bodyFont
        self.captionFont = captionFont
        self.fontSizeScale = fontSizeScale
    }
}

public struct ThemeEffects: Codable {
    public var cornerRadius: Double
    public var shadowOpacity: Double
    public var blurRadius: Double
    public var animationDuration: Double
    public var animationCurve: String
    
    public static let `default` = ThemeEffects(
        cornerRadius: 12.0,
        shadowOpacity: 0.2,
        blurRadius: 8.0,
        animationDuration: 0.3,
        animationCurve: "easeInOut"
    )
    
    public init(
        cornerRadius: Double,
        shadowOpacity: Double,
        blurRadius: Double,
        animationDuration: Double,
        animationCurve: String
    ) {
        self.cornerRadius = cornerRadius
        self.shadowOpacity = shadowOpacity
        self.blurRadius = blurRadius
        self.animationDuration = animationDuration
        self.animationCurve = animationCurve
    }
}

public struct WidgetConfiguration: Identifiable, Codable {
    public let id: String
    public let type: WidgetType
    public var position: WidgetPosition
    public var size: WidgetSize
    public var isEnabled: Bool
    public var settings: [String: String] = [:]
    
    public init(
        id: String,
        type: WidgetType,
        position: WidgetPosition,
        size: WidgetSize,
        isEnabled: Bool
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.isEnabled = isEnabled
    }
}

public struct WidgetPosition: Codable {
    public var x: Double
    public var y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct NotificationSettings: Codable {
    public var enabled: Bool = true
    public var frequencies: [NotificationType: NotificationFrequency] = [:]
    public var quietHours: QuietHours = QuietHours()
    public var soundEnabled: Bool = true
    public var vibrationEnabled: Bool = true
    public var badgeEnabled: Bool = true
    public var locationBasedNotifications: Bool = false
    public var smartTiming: Bool = true
    
    public init() {
        // Set default frequencies
        frequencies = [
            .friendGoesLive: .immediate,
            .streamEnded: .never,
            .newRecommendation: .daily,
            .watchPartyInvite: .immediate,
            .highlightDetected: .immediate
        ]
    }
}

public struct QuietHours: Codable {
    public var enabled: Bool = false
    public var startTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    public var endTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    public var weekendsOnly: Bool = false
    
    public init() {}
}

public struct UserSettings: Codable {
    public var showAdvancedFeatures: Bool = false
    public var simplifiedUI: Bool = false
    public var tooltipsEnabled: Bool = true
    public var expertModeEnabled: Bool = false
    public var gestureConfiguration: GestureConfiguration = GestureConfiguration()
    public var autoPlayEnabled: Bool = true
    public var dataUsageMode: DataUsageMode = .balanced
    public var cacheSize: CacheSize = .medium
    
    public init() {}
}

public struct GestureConfiguration: Codable {
    public var swipeToSkip: Bool = true
    public var pinchToZoom: Bool = true
    public var doubleTapToFullscreen: Bool = true
    public var longPressForOptions: Bool = true
    public var swipeGestureSensitivity: Double = 1.0
    
    public init() {}
}

public struct AccessibilitySettings: Codable {
    public var highContrast: Bool = false
    public var fontSize: AccessibilityFontSize = .medium
    public var voiceOverEnabled: Bool = false
    public var reducedMotion: Bool = false
    public var audioDescriptions: Bool = false
    public var closedCaptions: Bool = false
    public var colorBlindnessSupport: ColorBlindnessType = .none
    
    public init() {}
}

public struct LayoutPreferences: Codable {
    public var preferredGridSize: GridSize = .twoByTwo
    public var streamSpacing: Double = 8.0
    public var showStreamLabels: Bool = true
    public var showViewerCounts: Bool = true
    public var compactMode: Bool = false
    public var animationsEnabled: Bool = true
    
    public init() {}
}

public struct ContentPreferences: Codable {
    public var preferredLanguages: [String] = ["en"]
    public var contentFilters: [String] = []
    public var matureContentEnabled: Bool = false
    public var qualityPreference: StreamQuality = .auto
    public var autoSkipIntros: Bool = false
    public var preferredCategories: [String] = []
    
    public init() {}
}

public struct SmartNotification: Identifiable {
    public let id: String
    public let event: NotificationEvent
    public let timestamp: Date
    public let priority: NotificationPriority
    public let personalized: Bool
    public var delivered: Bool = false
    public var opened: Bool = false
    
    public init(
        id: String,
        event: NotificationEvent,
        timestamp: Date,
        priority: NotificationPriority,
        personalized: Bool
    ) {
        self.id = id
        self.event = event
        self.timestamp = timestamp
        self.priority = priority
        self.personalized = personalized
    }
}

public struct AvailableWidget {
    public let type: WidgetType
    public let name: String
    public let description: String
    
    public init(type: WidgetType, name: String, description: String) {
        self.type = type
        self.name = name
        self.description = description
    }
}

public struct PersonalizationPreset: Identifiable, Codable {
    public let id: String
    public let name: String
    public let theme: AppTheme
    public let dashboardLayout: DashboardLayout
    public let widgets: [WidgetConfiguration]
    public let notifications: NotificationSettings
    public let userSettings: UserSettings
    public let accessibility: AccessibilitySettings
    public let layoutPreferences: LayoutPreferences
    public let contentPreferences: ContentPreferences
    public let createdAt: Date
    
    public init(
        id: String,
        name: String,
        theme: AppTheme,
        dashboardLayout: DashboardLayout,
        widgets: [WidgetConfiguration],
        notifications: NotificationSettings,
        userSettings: UserSettings,
        accessibility: AccessibilitySettings,
        layoutPreferences: LayoutPreferences,
        contentPreferences: ContentPreferences,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.theme = theme
        self.dashboardLayout = dashboardLayout
        self.widgets = widgets
        self.notifications = notifications
        self.userSettings = userSettings
        self.accessibility = accessibility
        self.layoutPreferences = layoutPreferences
        self.contentPreferences = contentPreferences
        self.createdAt = createdAt
    }
}

public struct PersonalizationProfile: Codable {
    public let theme: AppTheme
    public let customThemes: [CustomTheme]
    public let dashboardLayout: DashboardLayout
    public let widgets: [WidgetConfiguration]
    public let notifications: NotificationSettings
    public let userSettings: UserSettings
    public let accessibility: AccessibilitySettings
    public let layoutPreferences: LayoutPreferences
    public let contentPreferences: ContentPreferences
    public let experienceLevel: ExperienceLevel
    public let customizations: [String: Any]
    public let exportedAt: Date
    
    public init(
        theme: AppTheme,
        customThemes: [CustomTheme],
        dashboardLayout: DashboardLayout,
        widgets: [WidgetConfiguration],
        notifications: NotificationSettings,
        userSettings: UserSettings,
        accessibility: AccessibilitySettings,
        layoutPreferences: LayoutPreferences,
        contentPreferences: ContentPreferences,
        experienceLevel: ExperienceLevel,
        customizations: [String: Any],
        exportedAt: Date
    ) {
        self.theme = theme
        self.customThemes = customThemes
        self.dashboardLayout = dashboardLayout
        self.widgets = widgets
        self.notifications = notifications
        self.userSettings = userSettings
        self.accessibility = accessibility
        self.layoutPreferences = layoutPreferences
        self.contentPreferences = contentPreferences
        self.experienceLevel = experienceLevel
        self.customizations = customizations
        self.exportedAt = exportedAt
    }
}

public struct PersonalizationInsights {
    public let mostUsedTheme: AppTheme
    public let averageSessionCustomizations: Double
    public let preferredWidgets: [WidgetType]
    public let notificationEngagement: Double
    public let accessibilityUsage: [String: Bool]
    public let customizationFrequency: Double
}

// MARK: - Enums

public enum AppTheme: Codable {
    case light
    case dark
    case dynamic
    case custom(CustomTheme)
    
    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .dynamic: return "Dynamic"
        case .custom(let theme): return theme.name
        }
    }
}

public enum DashboardLayout: String, CaseIterable, Codable {
    case `default` = "default"
    case compact = "compact"
    case wideGrid = "wideGrid"
    case list = "list"
    case customizable = "customizable"
    
    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .compact: return "Compact"
        case .wideGrid: return "Wide Grid"
        case .list: return "List"
        case .customizable: return "Customizable"
        }
    }
}

public enum WidgetType: String, CaseIterable, Codable {
    case streamGrid = "streamGrid"
    case trendingStreams = "trendingStreams"
    case friendsActivity = "friendsActivity"
    case recommendations = "recommendations"
    case quickActions = "quickActions"
    case watchHistory = "watchHistory"
    case analytics = "analytics"
    case notifications = "notifications"
    
    public var displayName: String {
        switch self {
        case .streamGrid: return "Stream Grid"
        case .trendingStreams: return "Trending Streams"
        case .friendsActivity: return "Friends Activity"
        case .recommendations: return "Recommendations"
        case .quickActions: return "Quick Actions"
        case .watchHistory: return "Watch History"
        case .analytics: return "Analytics"
        case .notifications: return "Notifications"
        }
    }
}

public enum WidgetSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    public var dimensions: CGSize {
        switch self {
        case .small: return CGSize(width: 150, height: 150)
        case .medium: return CGSize(width: 320, height: 150)
        case .large: return CGSize(width: 320, height: 320)
        case .extraLarge: return CGSize(width: 670, height: 320)
        }
    }
}

public enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case expert = "expert"
    
    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .expert: return "Expert"
        }
    }
}

public enum NotificationType: String, CaseIterable, Codable {
    case friendGoesLive = "friendGoesLive"
    case streamEnded = "streamEnded"
    case newRecommendation = "newRecommendation"
    case watchPartyInvite = "watchPartyInvite"
    case highlightDetected = "highlightDetected"
    case systemUpdate = "systemUpdate"
    
    public var displayName: String {
        switch self {
        case .friendGoesLive: return "Friend Goes Live"
        case .streamEnded: return "Stream Ended"
        case .newRecommendation: return "New Recommendation"
        case .watchPartyInvite: return "Watch Party Invite"
        case .highlightDetected: return "Highlight Detected"
        case .systemUpdate: return "System Update"
        }
    }
}

public enum NotificationFrequency: String, CaseIterable, Codable {
    case immediate = "immediate"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case never = "never"
    
    public var displayName: String {
        switch self {
        case .immediate: return "Immediate"
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .never: return "Never"
        }
    }
}

public enum NotificationPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

public enum NotificationEvent {
    case friendGoesLive(String)
    case streamEnded(String)
    case newRecommendation([TwitchStream])
    case watchPartyInvite(String)
    case highlightDetected(String, TimeInterval)
    case systemUpdate(String)
}

public enum AccessibilityFontSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    public var scale: Double {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.5
        }
    }
}

public enum ColorBlindnessType: String, CaseIterable, Codable {
    case none = "none"
    case protanopia = "protanopia"
    case deuteranopia = "deuteranopia"
    case tritanopia = "tritanopia"
    
    public var displayName: String {
        switch self {
        case .none: return "None"
        case .protanopia: return "Protanopia"
        case .deuteranopia: return "Deuteranopia"
        case .tritanopia: return "Tritanopia"
        }
    }
}

public enum DataUsageMode: String, CaseIterable, Codable {
    case conservative = "conservative"
    case balanced = "balanced"
    case performance = "performance"
    
    public var displayName: String {
        switch self {
        case .conservative: return "Data Saver"
        case .balanced: return "Balanced"
        case .performance: return "High Performance"
        }
    }
}

public enum CacheSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    public var sizeInMB: Int {
        switch self {
        case .small: return 100
        case .medium: return 500
        case .large: return 1000
        }
    }
}

public enum GridSize: String, CaseIterable, Codable {
    case oneByOne = "1x1"
    case twoByTwo = "2x2"
    case threeByThree = "3x3"
    case fourByFour = "4x4"
    
    public var dimensions: (Int, Int) {
        switch self {
        case .oneByOne: return (1, 1)
        case .twoByTwo: return (2, 2)
        case .threeByThree: return (3, 3)
        case .fourByFour: return (4, 4)
        }
    }
}

public enum StreamQuality: String, CaseIterable, Codable {
    case auto = "auto"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
    
    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .low: return "Low (480p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        case .ultra: return "Ultra (4K)"
        }
    }
}

public enum PersonalizationAction {
    case themeChanged(AppTheme)
    case widgetAdded(WidgetType)
    case widgetRemoved(String)
    case layoutChanged(DashboardLayout)
    case settingToggled(String, Bool)
    case customizationApplied(String)
}

// MARK: - Errors

public enum PersonalizationError: Error, LocalizedError {
    case themeNotFound
    case invalidConfiguration
    case exportFailed
    case importFailed
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .themeNotFound:
            return "Theme not found"
        case .invalidConfiguration:
            return "Invalid configuration"
        case .exportFailed:
            return "Failed to export settings"
        case .importFailed:
            return "Failed to import settings"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - Supporting Classes

protocol ThemeEngineDelegate: AnyObject {
    func themeDidApply(_ theme: AppTheme)
    func themeApplicationFailed(_ error: Error)
}

class ThemeEngine {
    weak var delegate: ThemeEngineDelegate?
    
    func applyTheme(_ theme: AppTheme) {
        // Apply theme to the app
        delegate?.themeDidApply(theme)
    }
    
    func enableHighContrast() {
        // Enable high contrast mode
    }
    
    func disableAnimations() {
        // Disable animations for reduced motion
    }
    
    func updateFontSize(_ size: AccessibilityFontSize) {
        // Update app font sizes
    }
}

class SmartNotificationManager {
    private var scheduledNotifications: [SmartNotification] = []
    private var notificationHistory: [SmartNotification] = []
    
    func updateSettings(_ settings: NotificationSettings) {
        // Update notification settings
    }
    
    func scheduleNotification(_ notification: SmartNotification) {
        scheduledNotifications.append(notification)
        
        // Schedule with UNUserNotificationCenter
        let content = UNMutableNotificationContent()
        content.title = getNotificationTitle(for: notification.event)
        content.body = getNotificationBody(for: notification.event)
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func getNotificationHistory() -> [SmartNotification] {
        return notificationHistory
    }
    
    func updateFrequency(for type: NotificationType, frequency: NotificationFrequency) {
        // Update notification frequency for specific type
    }
    
    private func getNotificationTitle(for event: NotificationEvent) -> String {
        switch event {
        case .friendGoesLive(let friend):
            return "\(friend) is now live!"
        case .streamEnded:
            return "Stream ended"
        case .newRecommendation:
            return "New recommendations"
        case .watchPartyInvite:
            return "Watch party invitation"
        case .highlightDetected:
            return "Highlight detected!"
        case .systemUpdate:
            return "System update"
        }
    }
    
    private func getNotificationBody(for event: NotificationEvent) -> String {
        switch event {
        case .friendGoesLive(let friend):
            return "Your friend \(friend) just started streaming. Join them now!"
        case .streamEnded(let stream):
            return "The stream '\(stream)' has ended."
        case .newRecommendation(let streams):
            return "We found \(streams.count) new streams you might like."
        case .watchPartyInvite(let party):
            return "You've been invited to watch party '\(party)'"
        case .highlightDetected(let stream, let timestamp):
            return "An exciting moment was detected in \(stream) at \(Int(timestamp))s"
        case .systemUpdate(let message):
            return message
        }
    }
}

class PersonalizationAnalytics {
    private var actions: [PersonalizationAction] = []
    
    func trackAction(_ action: PersonalizationAction) {
        actions.append(action)
    }
    
    func getMostUsedTheme() -> AppTheme {
        return .dynamic // Simplified
    }
    
    func getAverageCustomizations() -> Double {
        return Double(actions.count) / 30.0 // Actions per month
    }
    
    func getPreferredWidgets() -> [WidgetType] {
        return [.streamGrid, .recommendations, .friendsActivity]
    }
    
    func getNotificationEngagement() -> Double {
        return 0.75 // 75% engagement rate
    }
    
    func getAccessibilityUsage() -> [String: Bool] {
        return [
            "highContrast": false,
            "voiceOver": false,
            "reducedMotion": false
        ]
    }
    
    func getCustomizationFrequency() -> Double {
        return 2.5 // Times per week
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
    static let dashboardLayoutDidChange = Notification.Name("dashboardLayoutDidChange")
    static let gestureConfigurationDidChange = Notification.Name("gestureConfigurationDidChange")
    static let contentPreferencesDidChange = Notification.Name("contentPreferencesDidChange")
    static let layoutPreferencesDidChange = Notification.Name("layoutPreferencesDidChange")
    static let personalizationPresetApplied = Notification.Name("personalizationPresetApplied")
    static let personalizationProfileImported = Notification.Name("personalizationProfileImported")
}