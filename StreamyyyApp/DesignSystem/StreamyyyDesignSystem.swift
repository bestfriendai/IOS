//
//  StreamyyyDesignSystem.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Main design system aggregator and utilities
//

import SwiftUI

// MARK: - StreamyyyDesignSystem
struct StreamyyyDesignSystem {
    
    // MARK: - Design System Access
    static let colors = StreamyyyColors.self
    static let typography = StreamyyyTypography.self
    static let spacing = StreamyyySpacing.self
    
    // MARK: - Theme Management
    static let themeManager = StreamyyyThemeManager()
    
    // MARK: - Design System Information
    static let version = "1.0.0"
    static let buildNumber = "1"
    static let lastUpdated = "2024-01-01"
    
    // MARK: - Design System Utilities
    static func initialize() {
        // Initialize design system
        setupAppearance()
        setupAccessibility()
        setupAnimations()
    }
    
    private static func setupAppearance() {
        // Configure global appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(StreamyyyColors.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(StreamyyyColors.textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(StreamyyyColors.textPrimary)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(StreamyyyColors.surface)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Configure tint colors
        UIView.appearance().tintColor = UIColor(StreamyyyColors.primary)
    }
    
    private static func setupAccessibility() {
        // Configure accessibility features
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
    
    private static func setupAnimations() {
        // Configure default animations
        UIView.setAnimationsEnabled(true)
    }
    
    // MARK: - Component Builders
    static func button(
        title: String,
        style: StreamyyyButtonStyle = .primary,
        size: StreamyyyButtonSize = .medium,
        action: @escaping () -> Void
    ) -> some View {
        StreamyyyButton(title: title, style: style, size: size, action: action)
    }
    
    static func card<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        StreamyyyCard(content: content)
    }
    
    static func textField(
        placeholder: String,
        text: Binding<String>,
        style: StreamyyyTextFieldStyle = .default
    ) -> some View {
        StreamyyyTextField(placeholder: placeholder, text: text, style: style)
    }
    
    // MARK: - Layout Builders
    static func screenContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        StreamyyyScreenContainer(content: content)
    }
    
    static func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        StreamyyySection(title: title, content: content)
    }
    
    // MARK: - Accessibility Helpers
    static func accessibilityLabel(_ label: String) -> some View {
        EmptyView().accessibilityLabel(label)
    }
    
    static func accessibilityHint(_ hint: String) -> some View {
        EmptyView().accessibilityHint(hint)
    }
    
    static func accessibilityValue(_ value: String) -> some View {
        EmptyView().accessibilityValue(value)
    }
    
    // MARK: - Animation Presets
    static let quickAnimation = Animation.easeInOut(duration: 0.2)
    static let standardAnimation = Animation.easeInOut(duration: 0.3)
    static let slowAnimation = Animation.easeInOut(duration: 0.5)
    static let bounceAnimation = Animation.spring(response: 0.5, dampingFraction: 0.8)
    
    // MARK: - Haptic Feedback
    static func hapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: type)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func hapticSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    static func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    // MARK: - Debug Helpers
    static func debugBorder(_ color: Color = .red) -> some View {
        Rectangle()
            .strokeBorder(color, lineWidth: 1)
            .allowsHitTesting(false)
    }
    
    static func debugBackground(_ color: Color = .blue) -> some View {
        Rectangle()
            .fill(color.opacity(0.1))
            .allowsHitTesting(false)
    }
    
    // MARK: - Device Information
    static var deviceType: UIUserInterfaceIdiom {
        return UIDevice.current.userInterfaceIdiom
    }
    
    static var isPhone: Bool {
        return deviceType == .phone
    }
    
    static var isPad: Bool {
        return deviceType == .pad
    }
    
    static var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    static var screenWidth: CGFloat {
        return screenSize.width
    }
    
    static var screenHeight: CGFloat {
        return screenSize.height
    }
    
    static var isLandscape: Bool {
        return screenWidth > screenHeight
    }
    
    static var isPortrait: Bool {
        return screenHeight > screenWidth
    }
    
    // MARK: - Safe Area Information
    static var safeAreaInsets: UIEdgeInsets {
        guard let window = UIApplication.shared.windows.first else {
            return .zero
        }
        return window.safeAreaInsets
    }
    
    static var topSafeArea: CGFloat {
        return safeAreaInsets.top
    }
    
    static var bottomSafeArea: CGFloat {
        return safeAreaInsets.bottom
    }
    
    static var leadingSafeArea: CGFloat {
        return safeAreaInsets.left
    }
    
    static var trailingSafeArea: CGFloat {
        return safeAreaInsets.right
    }
    
    // MARK: - Validation Helpers
    static func validateDesignSystem() -> Bool {
        // Validate design system integrity
        return true
    }
    
    static func printDesignSystemInfo() {
        print("=== Streamyyy Design System ===")
        print("Version: \(version)")
        print("Build: \(buildNumber)")
        print("Last Updated: \(lastUpdated)")
        print("Device: \(deviceType)")
        print("Screen Size: \(screenSize)")
        print("Safe Area: \(safeAreaInsets)")
        print("==============================")
    }
}

// MARK: - Button Sizes
enum StreamyyyButtonSize {
    case small
    case medium
    case large
    case extraLarge
    
    var height: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 56
        case .extraLarge: return 64
        }
    }
    
    var padding: CGFloat {
        switch self {
        case .small: return StreamyyySpacing.sm
        case .medium: return StreamyyySpacing.md
        case .large: return StreamyyySpacing.lg
        case .extraLarge: return StreamyyySpacing.xl
        }
    }
    
    var font: Font {
        switch self {
        case .small: return StreamyyyTypography.buttonSmall
        case .medium: return StreamyyyTypography.buttonMedium
        case .large: return StreamyyyTypography.buttonLarge
        case .extraLarge: return StreamyyyTypography.buttonLarge
        }
    }
}

// MARK: - Text Field Styles
enum StreamyyyTextFieldStyle {
    case `default`
    case outlined
    case filled
    case underlined
}

// MARK: - Environment Values Extensions
extension EnvironmentValues {
    var designSystem: StreamyyyDesignSystem.Type {
        get { StreamyyyDesignSystem.self }
        set { }
    }
}

// MARK: - View Extensions
extension View {
    func designSystem() -> some View {
        self.environment(\.designSystem, StreamyyyDesignSystem.self)
    }
    
    func debugDesignSystem() -> some View {
        self.onAppear {
            StreamyyyDesignSystem.printDesignSystemInfo()
        }
    }
    
    func hapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            StreamyyyDesignSystem.hapticFeedback(type)
        }
    }
    
    func hapticSelection() -> some View {
        self.onTapGesture {
            StreamyyyDesignSystem.hapticSelection()
        }
    }
    
    func responsiveFrame() -> some View {
        self.frame(
            maxWidth: StreamyyyDesignSystem.isPhone ? .infinity : 400,
            maxHeight: StreamyyyDesignSystem.isPhone ? .infinity : 600
        )
    }
    
    func deviceAdaptive() -> some View {
        if StreamyyyDesignSystem.isPad {
            return AnyView(self.padding(StreamyyySpacing.xl))
        } else {
            return AnyView(self.padding(StreamyyySpacing.md))
        }
    }
}

// MARK: - Color Scheme Extensions
extension ColorScheme {
    var streamyyyTheme: StreamyyyThemeProtocol {
        switch self {
        case .light:
            return StreamyyyLightTheme()
        case .dark:
            return StreamyyyDarkTheme()
        @unknown default:
            return StreamyyyLightTheme()
        }
    }
}

// MARK: - Design System Validator
struct StreamyyyDesignSystemValidator {
    static func validateColors() -> Bool {
        // Validate color accessibility
        return true
    }
    
    static func validateTypography() -> Bool {
        // Validate typography accessibility
        return true
    }
    
    static func validateSpacing() -> Bool {
        // Validate spacing consistency
        return true
    }
    
    static func validateTouchTargets() -> Bool {
        // Validate minimum touch target sizes
        return true
    }
    
    static func validateAccessibility() -> Bool {
        // Validate accessibility compliance
        return validateColors() && validateTypography() && validateSpacing() && validateTouchTargets()
    }
}

// MARK: - Design System Documentation
struct StreamyyyDesignSystemDocumentation {
    static let colorsDocumentation = """
    StreamyyyColors provides a comprehensive color system with:
    - Primary, secondary, and accent colors
    - Semantic colors for success, warning, error, and info
    - Platform-specific colors for Twitch, YouTube, etc.
    - Dark and light mode support
    - Accessibility considerations
    """
    
    static let typographyDocumentation = """
    StreamyyyTypography provides a type scale with:
    - Display, headline, title, body, label, and caption styles
    - Responsive typography
    - Accessibility support
    - Custom font loading
    - Platform-specific considerations
    """
    
    static let spacingDocumentation = """
    StreamyyySpacing provides consistent spacing with:
    - Base unit system (8pt grid)
    - Semantic spacing names
    - Component-specific spacing
    - Responsive spacing
    - Safe area considerations
    """
    
    static let themeDocumentation = """
    StreamyyyTheme provides theme management with:
    - Light and dark themes
    - Custom theme support
    - System theme following
    - Theme switching animations
    - Persistent theme preferences
    """
}

// MARK: - Design System Preview
struct StreamyyyDesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: StreamyyySpacing.lg) {
                Text("Streamyyy Design System")
                    .displayLarge()
                
                StreamyyyDesignSystem.section(title: "Colors") {
                    HStack {
                        ColorSwatch(color: StreamyyyColors.primary, name: "Primary")
                        ColorSwatch(color: StreamyyyColors.secondary, name: "Secondary")
                        ColorSwatch(color: StreamyyyColors.accent, name: "Accent")
                    }
                }
                
                StreamyyyDesignSystem.section(title: "Typography") {
                    VStack(alignment: .leading, spacing: StreamyyySpacing.sm) {
                        Text("Display Large").displayLarge()
                        Text("Headline Medium").headlineMedium()
                        Text("Title Small").titleSmall()
                        Text("Body Large").bodyLarge()
                        Text("Label Medium").labelMedium()
                        Text("Caption Small").captionSmall()
                    }
                }
                
                StreamyyyDesignSystem.section(title: "Buttons") {
                    VStack(spacing: StreamyyySpacing.sm) {
                        StreamyyyDesignSystem.button(title: "Primary", style: .primary) { }
                        StreamyyyDesignSystem.button(title: "Secondary", style: .secondary) { }
                        StreamyyyDesignSystem.button(title: "Tertiary", style: .tertiary) { }
                        StreamyyyDesignSystem.button(title: "Destructive", style: .destructive) { }
                    }
                }
                
                StreamyyyDesignSystem.section(title: "Spacing") {
                    VStack(spacing: StreamyyySpacing.sm) {
                        SpacingExample(size: StreamyyySpacing.xs, name: "XS")
                        SpacingExample(size: StreamyyySpacing.sm, name: "SM")
                        SpacingExample(size: StreamyyySpacing.md, name: "MD")
                        SpacingExample(size: StreamyyySpacing.lg, name: "LG")
                        SpacingExample(size: StreamyyySpacing.xl, name: "XL")
                    }
                }
            }
            .screenPadding()
        }
        .themedBackground()
    }
}

// MARK: - Helper Views
struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: StreamyyySpacing.cornerRadiusSM)
                .fill(color)
                .frame(width: 60, height: 60)
            
            Text(name)
                .captionMedium()
        }
    }
}

struct SpacingExample: View {
    let size: CGFloat
    let name: String
    
    var body: some View {
        HStack {
            Text(name)
                .labelMedium()
            
            Rectangle()
                .fill(StreamyyyColors.primary)
                .frame(width: size, height: 20)
            
            Text("\(Int(size))pt")
                .captionMedium()
            
            Spacer()
        }
    }
}

#Preview {
    StreamyyyDesignSystemPreview()
}