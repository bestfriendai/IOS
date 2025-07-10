//
//  StreamyyyTheme.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Comprehensive theme management system with dark/light mode support
//

import SwiftUI

// Ensure all design system components are available
extension StreamyyyColors {}
extension StreamyyySpacing {}
extension StreamyyyTypography {}

// MARK: - Theme Protocol
protocol StreamyyyThemeProtocol {
    var colors: StreamyyyThemeColors { get }
    var typography: StreamyyyThemeTypography { get }
    var spacing: StreamyyyThemeSpacing { get }
    var name: String { get }
    var displayName: String { get }
}

// MARK: - Theme Colors
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

// MARK: - Theme Typography
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

// MARK: - Theme Spacing
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

// MARK: - Light Theme
struct StreamyyyLightTheme: StreamyyyThemeProtocol {
    let name = "light"
    let displayName = "Light"
    
    let colors = StreamyyyThemeColors(
        primary: Color(hex: "6366F1"),
        primaryLight: Color(hex: "818CF8"),
        primaryDark: Color(hex: "4338CA"),
        secondary: Color(hex: "64748B"),
        accent: Color(hex: "06B6D4"),
        background: Color(hex: "FFFFFF"),
        surface: Color(hex: "F8FAFC"),
        textPrimary: Color(hex: "0F172A"),
        textSecondary: Color(hex: "475569"),
        textTertiary: Color(hex: "94A3B8"),
        success: Color(hex: "10B981"),
        warning: Color(hex: "F59E0B"),
        error: Color(hex: "EF4444"),
        info: Color(hex: "3B82F6"),
        liveIndicator: Color(hex: "DC2626"),
        offlineIndicator: Color(hex: "6B7280"),
        border: Color(hex: "E2E8F0"),
        overlay: Color(hex: "000000"),
        shadow: Color(hex: "000000")
    )
    
    let typography = StreamyyyThemeTypography(
        displayLarge: StreamyyyTypography.displayLarge,
        displayMedium: StreamyyyTypography.displayMedium,
        displaySmall: StreamyyyTypography.displaySmall,
        headlineLarge: StreamyyyTypography.headlineLarge,
        headlineMedium: StreamyyyTypography.headlineMedium,
        headlineSmall: StreamyyyTypography.headlineSmall,
        titleLarge: StreamyyyTypography.titleLarge,
        titleMedium: StreamyyyTypography.titleMedium,
        titleSmall: StreamyyyTypography.titleSmall,
        bodyLarge: StreamyyyTypography.bodyLarge,
        bodyMedium: StreamyyyTypography.bodyMedium,
        bodySmall: StreamyyyTypography.bodySmall,
        labelLarge: StreamyyyTypography.labelLarge,
        labelMedium: StreamyyyTypography.labelMedium,
        labelSmall: StreamyyyTypography.labelSmall,
        captionLarge: StreamyyyTypography.captionLarge,
        captionMedium: StreamyyyTypography.captionMedium,
        captionSmall: StreamyyyTypography.captionSmall
    )
    
    let spacing = StreamyyyThemeSpacing(
        xs: StreamyyySpacing.xs,
        sm: StreamyyySpacing.sm,
        md: StreamyyySpacing.md,
        lg: StreamyyySpacing.lg,
        xl: StreamyyySpacing.xl,
        xxl: StreamyyySpacing.xxl,
        cornerRadiusSmall: StreamyyySpacing.cornerRadiusSM,
        cornerRadiusMedium: StreamyyySpacing.cornerRadiusMD,
        cornerRadiusLarge: StreamyyySpacing.cornerRadiusLG,
        shadowRadius: StreamyyySpacing.cardShadowRadius,
        borderWidth: StreamyyySpacing.borderWidthRegular
    )
}

// MARK: - Dark Theme
struct StreamyyyDarkTheme: StreamyyyThemeProtocol {
    let name = "dark"
    let displayName = "Dark"
    
    let colors = StreamyyyThemeColors(
        primary: Color(hex: "818CF8"),
        primaryLight: Color(hex: "A5B4FC"),
        primaryDark: Color(hex: "6366F1"),
        secondary: Color(hex: "94A3B8"),
        accent: Color(hex: "22D3EE"),
        background: Color(hex: "0F172A"),
        surface: Color(hex: "1E293B"),
        textPrimary: Color(hex: "F1F5F9"),
        textSecondary: Color(hex: "CBD5E1"),
        textTertiary: Color(hex: "64748B"),
        success: Color(hex: "34D399"),
        warning: Color(hex: "FBBF24"),
        error: Color(hex: "F87171"),
        info: Color(hex: "60A5FA"),
        liveIndicator: Color(hex: "F87171"),
        offlineIndicator: Color(hex: "94A3B8"),
        border: Color(hex: "334155"),
        overlay: Color(hex: "000000"),
        shadow: Color(hex: "000000")
    )
    
    let typography = StreamyyyThemeTypography(
        displayLarge: StreamyyyTypography.displayLarge,
        displayMedium: StreamyyyTypography.displayMedium,
        displaySmall: StreamyyyTypography.displaySmall,
        headlineLarge: StreamyyyTypography.headlineLarge,
        headlineMedium: StreamyyyTypography.headlineMedium,
        headlineSmall: StreamyyyTypography.headlineSmall,
        titleLarge: StreamyyyTypography.titleLarge,
        titleMedium: StreamyyyTypography.titleMedium,
        titleSmall: StreamyyyTypography.titleSmall,
        bodyLarge: StreamyyyTypography.bodyLarge,
        bodyMedium: StreamyyyTypography.bodyMedium,
        bodySmall: StreamyyyTypography.bodySmall,
        labelLarge: StreamyyyTypography.labelLarge,
        labelMedium: StreamyyyTypography.labelMedium,
        labelSmall: StreamyyyTypography.labelSmall,
        captionLarge: StreamyyyTypography.captionLarge,
        captionMedium: StreamyyyTypography.captionMedium,
        captionSmall: StreamyyyTypography.captionSmall
    )
    
    let spacing = StreamyyyThemeSpacing(
        xs: StreamyyySpacing.xs,
        sm: StreamyyySpacing.sm,
        md: StreamyyySpacing.md,
        lg: StreamyyySpacing.lg,
        xl: StreamyyySpacing.xl,
        xxl: StreamyyySpacing.xxl,
        cornerRadiusSmall: StreamyyySpacing.cornerRadiusSM,
        cornerRadiusMedium: StreamyyySpacing.cornerRadiusMD,
        cornerRadiusLarge: StreamyyySpacing.cornerRadiusLG,
        shadowRadius: StreamyyySpacing.cardShadowRadius,
        borderWidth: StreamyyySpacing.borderWidthRegular
    )
}

// MARK: - Purple Theme (Alternative)
struct StreamyyyPurpleTheme: StreamyyyThemeProtocol {
    let name = "purple"
    let displayName = "Purple"
    
    let colors = StreamyyyThemeColors(
        primary: Color(hex: "8B5CF6"),
        primaryLight: Color(hex: "A78BFA"),
        primaryDark: Color(hex: "7C3AED"),
        secondary: Color(hex: "6B7280"),
        accent: Color(hex: "EC4899"),
        background: Color(hex: "FAFAFA"),
        surface: Color(hex: "F3F4F6"),
        textPrimary: Color(hex: "111827"),
        textSecondary: Color(hex: "4B5563"),
        textTertiary: Color(hex: "9CA3AF"),
        success: Color(hex: "059669"),
        warning: Color(hex: "D97706"),
        error: Color(hex: "DC2626"),
        info: Color(hex: "2563EB"),
        liveIndicator: Color(hex: "DC2626"),
        offlineIndicator: Color(hex: "6B7280"),
        border: Color(hex: "D1D5DB"),
        overlay: Color(hex: "000000"),
        shadow: Color(hex: "000000")
    )
    
    let typography = StreamyyyThemeTypography(
        displayLarge: StreamyyyTypography.displayLarge,
        displayMedium: StreamyyyTypography.displayMedium,
        displaySmall: StreamyyyTypography.displaySmall,
        headlineLarge: StreamyyyTypography.headlineLarge,
        headlineMedium: StreamyyyTypography.headlineMedium,
        headlineSmall: StreamyyyTypography.headlineSmall,
        titleLarge: StreamyyyTypography.titleLarge,
        titleMedium: StreamyyyTypography.titleMedium,
        titleSmall: StreamyyyTypography.titleSmall,
        bodyLarge: StreamyyyTypography.bodyLarge,
        bodyMedium: StreamyyyTypography.bodyMedium,
        bodySmall: StreamyyyTypography.bodySmall,
        labelLarge: StreamyyyTypography.labelLarge,
        labelMedium: StreamyyyTypography.labelMedium,
        labelSmall: StreamyyyTypography.labelSmall,
        captionLarge: StreamyyyTypography.captionLarge,
        captionMedium: StreamyyyTypography.captionMedium,
        captionSmall: StreamyyyTypography.captionSmall
    )
    
    let spacing = StreamyyyThemeSpacing(
        xs: StreamyyySpacing.xs,
        sm: StreamyyySpacing.sm,
        md: StreamyyySpacing.md,
        lg: StreamyyySpacing.lg,
        xl: StreamyyySpacing.xl,
        xxl: StreamyyySpacing.xxl,
        cornerRadiusSmall: StreamyyySpacing.cornerRadiusSM,
        cornerRadiusMedium: StreamyyySpacing.cornerRadiusMD,
        cornerRadiusLarge: StreamyyySpacing.cornerRadiusLG,
        shadowRadius: StreamyyySpacing.cardShadowRadius,
        borderWidth: StreamyyySpacing.borderWidthRegular
    )
}

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
        if followSystemTheme {
            self.isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            self.currentTheme = isDarkMode ? StreamyyyDarkTheme() : StreamyyyLightTheme()
        } else {
            self.currentTheme = availableThemes.first(where: { $0.name == selectedThemeName }) ?? StreamyyyLightTheme()
            self.isDarkMode = currentTheme.name == "dark"
        }
        
        // Listen for system theme changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.updateThemeIfNeeded()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        let newTheme = isDarkMode ? StreamyyyLightTheme() : StreamyyyDarkTheme()
        setTheme(newTheme)
    }
    
    private func updateThemeIfNeeded() {
        guard followSystemTheme else { return }
        
        let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        if systemIsDark != isDarkMode {
            let newTheme = systemIsDark ? StreamyyyDarkTheme() : StreamyyyLightTheme()
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
    
    // MARK: - Typography Utilities
    func font(for keyPath: KeyPath<StreamyyyThemeTypography, Font>) -> Font {
        return currentTheme.typography[keyPath: keyPath]
    }
    
    // MARK: - Spacing Utilities
    func spacing(for keyPath: KeyPath<StreamyyyThemeSpacing, CGFloat>) -> CGFloat {
        return currentTheme.spacing[keyPath: keyPath]
    }
}

// MARK: - SwiftUI Environment Key
private struct StreamyyyThemeKey: EnvironmentKey {
    static let defaultValue = StreamyyyThemeManager()
}

extension EnvironmentValues {
    var streamyyyTheme: StreamyyyThemeManager {
        get { self[StreamyyyThemeKey.self] }
        set { self[StreamyyyThemeKey.self] = newValue }
    }
}

// MARK: - View Extensions
extension View {
    func streamyyyTheme(_ themeManager: StreamyyyThemeManager) -> some View {
        self.environment(\.streamyyyTheme, themeManager)
    }
    
    func themedBackground() -> some View {
        self.background(StreamyyyColors.background)
    }
    
    func themedSurface() -> some View {
        self.background(StreamyyyColors.surface)
    }
    
    func themedBorder() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: StreamyyySpacing.cornerRadiusMD)
                .stroke(StreamyyyColors.border, lineWidth: StreamyyySpacing.borderWidthRegular)
        )
    }
    
    func themedCard() -> some View {
        self
            .background(StreamyyyColors.surface)
            .cornerRadius(StreamyyySpacing.cardCornerRadius)
            .shadow(
                color: StreamyyyColors.overlay.opacity(0.1),
                radius: StreamyyySpacing.cardShadowRadius,
                x: 0,
                y: 2
            )
    }
    
    func themedButton(style: StreamyyyButtonStyle = .primary) -> some View {
        self.modifier(StreamyyyButtonModifier(style: style))
    }
}

// MARK: - Button Styles
enum StreamyyyButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
    case ghost
}

struct StreamyyyButtonModifier: ViewModifier {
    let style: StreamyyyButtonStyle
    
    func body(content: Content) -> some View {
        content
            .padding(StreamyyySpacing.buttonPadding)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(StreamyyySpacing.buttonCornerRadius)
            .shadow(
                color: shadowColor,
                radius: StreamyyySpacing.buttonShadowRadius,
                x: 0,
                y: 1
            )
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return StreamyyyColors.primary
        case .secondary:
            return StreamyyyColors.secondary
        case .tertiary:
            return StreamyyyColors.surface
        case .destructive:
            return StreamyyyColors.error
        case .ghost:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .secondary, .destructive:
            return StreamyyyColors.textInverse
        case .tertiary, .ghost:
            return StreamyyyColors.textPrimary
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .ghost:
            return Color.clear
        default:
            return StreamyyyColors.overlay.opacity(0.15)
        }
    }
}

// MARK: - Theme Preview
struct StreamyyyThemePreview: View {
    @StateObject private var themeManager = StreamyyyThemeManager()
    
    var body: some View {
        VStack(spacing: StreamyyySpacing.lg) {
            Text("Theme Preview")
                .font(themeManager.currentTheme.typography.headlineLarge)
                .foregroundColor(themeManager.currentTheme.colors.textPrimary)
            
            HStack {
                Button("Light") {
                    themeManager.setTheme(StreamyyyLightTheme())
                }
                .themedButton(style: .primary)
                
                Button("Dark") {
                    themeManager.setTheme(StreamyyyDarkTheme())
                }
                .themedButton(style: .secondary)
                
                Button("Purple") {
                    themeManager.setTheme(StreamyyyPurpleTheme())
                }
                .themedButton(style: .tertiary)
            }
            
            VStack(spacing: StreamyyySpacing.md) {
                Text("Sample Text")
                    .font(themeManager.currentTheme.typography.bodyLarge)
                    .foregroundColor(themeManager.currentTheme.colors.textPrimary)
                
                Text("Secondary Text")
                    .font(themeManager.currentTheme.typography.bodyMedium)
                    .foregroundColor(themeManager.currentTheme.colors.textSecondary)
                
                Text("Tertiary Text")
                    .font(themeManager.currentTheme.typography.bodySmall)
                    .foregroundColor(themeManager.currentTheme.colors.textTertiary)
            }
            .themedCard()
            .padding()
        }
        .padding()
        .themedBackground()
        .streamyyyTheme(themeManager)
    }
}

#Preview {
    StreamyyyThemePreview()
}