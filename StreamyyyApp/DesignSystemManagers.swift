//
//  DesignSystemManagers.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Centralized access to design system managers
//

import SwiftUI
import Combine

// MARK: - Theme Manager
class StreamyyyThemeManager: ObservableObject {
    @Published var currentTheme: StreamyyyThemeProtocol
    @Published var isDarkMode: Bool = false
    
    // Available themes
    let availableThemes: [StreamyyyThemeProtocol] = [
        StreamyyyLightTheme(),
        StreamyyyDarkTheme(),
        StreamyyyPurpleTheme()
    ]
    
    // User preferences
    @AppStorage("selectedTheme") private var selectedThemeName: String = "light"
    @AppStorage("followSystemTheme") private var followSystemTheme: Bool = true
    
    init() {
        // Initialize with system theme or user preference
        let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        let savedFollowSystemTheme = UserDefaults.standard.bool(forKey: "followSystemTheme")
        let savedThemeName = UserDefaults.standard.string(forKey: "selectedTheme") ?? "light"
        
        if savedFollowSystemTheme {
            self.isDarkMode = systemIsDark
            self.currentTheme = systemIsDark ? StreamyyyDarkTheme() : StreamyyyLightTheme()
        } else {
            // Find theme by name from available themes
            let lightTheme = StreamyyyLightTheme()
            let darkTheme = StreamyyyDarkTheme()
            let purpleTheme = StreamyyyPurpleTheme()
            
            if savedThemeName == "dark" {
                self.currentTheme = darkTheme
                self.isDarkMode = true
            } else if savedThemeName == "purple" {
                self.currentTheme = purpleTheme
                self.isDarkMode = false
            } else {
                self.currentTheme = lightTheme
                self.isDarkMode = false
            }
        }
    }
    
    // MARK: - Theme Management
    func setTheme(_ theme: StreamyyyThemeProtocol) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentTheme = theme
            self.isDarkMode = theme.name == "dark"
            self.selectedThemeName = theme.name
            self.followSystemTheme = false
        }
    }
    
    func setFollowSystemTheme(_ follow: Bool) {
        self.followSystemTheme = follow
        if follow {
            updateThemeIfNeeded()
        }
    }
    
    func toggleTheme() {
        let newTheme: StreamyyyThemeProtocol = isDarkMode ? StreamyyyLightTheme() : StreamyyyDarkTheme()
        setTheme(newTheme)
    }
    
    private func updateThemeIfNeeded() {
        guard followSystemTheme else { return }
        
        let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        if systemIsDark != isDarkMode {
            let newTheme: StreamyyyThemeProtocol = systemIsDark ? StreamyyyDarkTheme() : StreamyyyLightTheme()
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentTheme = newTheme
                self.isDarkMode = systemIsDark
            }
        }
    }
    
    // MARK: - Theme Utilities
    func getTheme(by name: String) -> StreamyyyThemeProtocol? {
        return availableThemes.first(where: { $0.name == name })
    }
    
    func getThemeDisplayName(for name: String) -> String {
        return getTheme(by: name)?.displayName ?? name.capitalized
    }
    
    // MARK: - Color Utilities
    func color(for keyPath: KeyPath<StreamyyyThemeColors, Color>) -> Color {
        return currentTheme.colors[keyPath: keyPath]
    }
}

// MARK: - Onboarding Manager
class StreamyyyOnboardingManager: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var currentOnboardingStep = 0
    @Published var isOnboardingActive = false
    
    @AppStorage("hasCompletedOnboarding") private var persistedOnboardingStatus: Bool = false
    
    init() {
        self.hasCompletedOnboarding = persistedOnboardingStatus
        self.isOnboardingActive = !persistedOnboardingStatus
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        persistedOnboardingStatus = true
        isOnboardingActive = false
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        persistedOnboardingStatus = false
        isOnboardingActive = true
        currentOnboardingStep = 0
    }
    
    func nextStep() {
        currentOnboardingStep += 1
    }
    
    func previousStep() {
        currentOnboardingStep = max(0, currentOnboardingStep - 1)
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
}

// MARK: - Theme Protocol and Implementations
protocol StreamyyyThemeProtocol {
    var colors: StreamyyyThemeColors { get }
    var typography: StreamyyyThemeTypography { get }
    var spacing: StreamyyyThemeSpacing { get }
    var name: String { get }
    var displayName: String { get }
}

struct StreamyyyThemeColors {
    let primary: Color
    let primaryLight: Color
    let primaryDark: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let success: Color
    let warning: Color
    let error: Color
    let info: Color
    let liveIndicator: Color
    let offlineIndicator: Color
    let border: Color
    let overlay: Color
    let shadow: Color
}

struct StreamyyyThemeTypography {
    let displayLarge: Font
    let displayMedium: Font
    let displaySmall: Font
    let headlineLarge: Font
    let headlineMedium: Font
    let headlineSmall: Font
    let titleLarge: Font
    let titleMedium: Font
    let titleSmall: Font
    let bodyLarge: Font
    let bodyMedium: Font
    let bodySmall: Font
    let labelLarge: Font
    let labelMedium: Font
    let labelSmall: Font
    let captionLarge: Font
    let captionMedium: Font
    let captionSmall: Font
}

struct StreamyyyThemeSpacing {
    let xs: CGFloat
    let sm: CGFloat
    let md: CGFloat
    let lg: CGFloat
    let xl: CGFloat
    let xxl: CGFloat
    let cornerRadiusSmall: CGFloat
    let cornerRadiusMedium: CGFloat
    let cornerRadiusLarge: CGFloat
    let shadowRadius: CGFloat
    let borderWidth: CGFloat
}

// MARK: - Theme Implementations
struct StreamyyyLightTheme: StreamyyyThemeProtocol {
    let name = "light"
    let displayName = "Light"
    
    let colors = StreamyyyThemeColors(
        primary: Color(red: 0.39, green: 0.4, blue: 0.95),
        primaryLight: Color(red: 0.51, green: 0.55, blue: 0.97),
        primaryDark: Color(red: 0.26, green: 0.22, blue: 0.79),
        secondary: Color(red: 0.39, green: 0.45, blue: 0.55),
        accent: Color(red: 0.02, green: 0.71, blue: 0.83),
        background: Color.white,
        surface: Color(red: 0.97, green: 0.98, blue: 0.99),
        textPrimary: Color(red: 0.06, green: 0.09, blue: 0.16),
        textSecondary: Color(red: 0.28, green: 0.34, blue: 0.41),
        textTertiary: Color(red: 0.58, green: 0.64, blue: 0.72),
        success: Color(red: 0.06, green: 0.73, blue: 0.51),
        warning: Color(red: 0.96, green: 0.62, blue: 0.04),
        error: Color(red: 0.94, green: 0.27, blue: 0.27),
        info: Color(red: 0.23, green: 0.51, blue: 0.96),
        liveIndicator: Color(red: 0.86, green: 0.15, blue: 0.15),
        offlineIndicator: Color(red: 0.42, green: 0.45, blue: 0.5),
        border: Color(red: 0.89, green: 0.91, blue: 0.94),
        overlay: Color.black,
        shadow: Color.black
    )
    
    let typography = StreamyyyThemeTypography(
        displayLarge: .largeTitle,
        displayMedium: .title,
        displaySmall: .title2,
        headlineLarge: .headline,
        headlineMedium: .headline,
        headlineSmall: .subheadline,
        titleLarge: .title2,
        titleMedium: .title3,
        titleSmall: .headline,
        bodyLarge: .body,
        bodyMedium: .body,
        bodySmall: .callout,
        labelLarge: .headline,
        labelMedium: .subheadline,
        labelSmall: .caption,
        captionLarge: .caption,
        captionMedium: .caption2,
        captionSmall: .caption2
    )
    
    let spacing = StreamyyyThemeSpacing(
        xs: 8,
        sm: 12,
        md: 16,
        lg: 24,
        xl: 32,
        xxl: 40,
        cornerRadiusSmall: 8,
        cornerRadiusMedium: 12,
        cornerRadiusLarge: 16,
        shadowRadius: 4,
        borderWidth: 1
    )
}

struct StreamyyyDarkTheme: StreamyyyThemeProtocol {
    let name = "dark"
    let displayName = "Dark"
    
    let colors = StreamyyyThemeColors(
        primary: Color(red: 0.51, green: 0.55, blue: 0.97),
        primaryLight: Color(red: 0.65, green: 0.71, blue: 0.99),
        primaryDark: Color(red: 0.39, green: 0.4, blue: 0.95),
        secondary: Color(red: 0.58, green: 0.64, blue: 0.72),
        accent: Color(red: 0.13, green: 0.83, blue: 0.93),
        background: Color(red: 0.06, green: 0.09, blue: 0.16),
        surface: Color(red: 0.12, green: 0.16, blue: 0.23),
        textPrimary: Color(red: 0.95, green: 0.96, blue: 0.97),
        textSecondary: Color(red: 0.8, green: 0.84, blue: 0.88),
        textTertiary: Color(red: 0.39, green: 0.45, blue: 0.55),
        success: Color(red: 0.2, green: 0.83, blue: 0.6),
        warning: Color(red: 0.98, green: 0.75, blue: 0.14),
        error: Color(red: 0.97, green: 0.44, blue: 0.44),
        info: Color(red: 0.38, green: 0.65, blue: 0.98),
        liveIndicator: Color(red: 0.97, green: 0.44, blue: 0.44),
        offlineIndicator: Color(red: 0.58, green: 0.64, blue: 0.72),
        border: Color(red: 0.2, green: 0.26, blue: 0.33),
        overlay: Color.black,
        shadow: Color.black
    )
    
    let typography = StreamyyyThemeTypography(
        displayLarge: .largeTitle,
        displayMedium: .title,
        displaySmall: .title2,
        headlineLarge: .headline,
        headlineMedium: .headline,
        headlineSmall: .subheadline,
        titleLarge: .title2,
        titleMedium: .title3,
        titleSmall: .headline,
        bodyLarge: .body,
        bodyMedium: .body,
        bodySmall: .callout,
        labelLarge: .headline,
        labelMedium: .subheadline,
        labelSmall: .caption,
        captionLarge: .caption,
        captionMedium: .caption2,
        captionSmall: .caption2
    )
    
    let spacing = StreamyyyThemeSpacing(
        xs: 8,
        sm: 12,
        md: 16,
        lg: 24,
        xl: 32,
        xxl: 40,
        cornerRadiusSmall: 8,
        cornerRadiusMedium: 12,
        cornerRadiusLarge: 16,
        shadowRadius: 4,
        borderWidth: 1
    )
}

struct StreamyyyPurpleTheme: StreamyyyThemeProtocol {
    let name = "purple"
    let displayName = "Purple"
    
    let colors = StreamyyyThemeColors(
        primary: Color(red: 0.55, green: 0.36, blue: 0.96),
        primaryLight: Color(red: 0.66, green: 0.55, blue: 0.98),
        primaryDark: Color(red: 0.49, green: 0.23, blue: 0.93),
        secondary: Color(red: 0.42, green: 0.45, blue: 0.5),
        accent: Color(red: 0.93, green: 0.28, blue: 0.6),
        background: Color(red: 0.98, green: 0.98, blue: 0.98),
        surface: Color(red: 0.95, green: 0.96, blue: 0.96),
        textPrimary: Color(red: 0.07, green: 0.09, blue: 0.15),
        textSecondary: Color(red: 0.29, green: 0.34, blue: 0.39),
        textTertiary: Color(red: 0.61, green: 0.64, blue: 0.69),
        success: Color(red: 0.02, green: 0.59, blue: 0.41),
        warning: Color(red: 0.85, green: 0.47, blue: 0.02),
        error: Color(red: 0.86, green: 0.15, blue: 0.15),
        info: Color(red: 0.15, green: 0.39, blue: 0.92),
        liveIndicator: Color(red: 0.86, green: 0.15, blue: 0.15),
        offlineIndicator: Color(red: 0.42, green: 0.45, blue: 0.5),
        border: Color(red: 0.82, green: 0.84, blue: 0.86),
        overlay: Color.black,
        shadow: Color.black
    )
    
    let typography = StreamyyyThemeTypography(
        displayLarge: .largeTitle,
        displayMedium: .title,
        displaySmall: .title2,
        headlineLarge: .headline,
        headlineMedium: .headline,
        headlineSmall: .subheadline,
        titleLarge: .title2,
        titleMedium: .title3,
        titleSmall: .headline,
        bodyLarge: .body,
        bodyMedium: .body,
        bodySmall: .callout,
        labelLarge: .headline,
        labelMedium: .subheadline,
        labelSmall: .caption,
        captionLarge: .caption,
        captionMedium: .caption2,
        captionSmall: .caption2
    )
    
    let spacing = StreamyyyThemeSpacing(
        xs: 8,
        sm: 12,
        md: 16,
        lg: 24,
        xl: 32,
        xxl: 40,
        cornerRadiusSmall: 8,
        cornerRadiusMedium: 12,
        cornerRadiusLarge: 16,
        shadowRadius: 4,
        borderWidth: 1
    )
}