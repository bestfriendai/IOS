//
//  StreamyyyTypography.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Comprehensive typography system with accessibility support
//

import SwiftUI

// MARK: - StreamyyyTypography
struct StreamyyyTypography {
    
    // MARK: - Font Families
    static let primaryFontFamily = "SF Pro Display"
    static let secondaryFontFamily = "SF Pro Text"
    static let monospaceFontFamily = "SF Mono"
    
    // MARK: - Font Weights
    enum FontWeight {
        case ultraLight
        case thin
        case light
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black
        
        var systemWeight: Font.Weight {
            switch self {
            case .ultraLight: return .ultraLight
            case .thin: return .thin
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
            }
        }
    }
    
    // MARK: - Display Styles
    static let displayLarge = Font.system(size: 64, weight: .black, design: .default)
    static let displayMedium = Font.system(size: 48, weight: .bold, design: .default)
    static let displaySmall = Font.system(size: 36, weight: .bold, design: .default)
    
    // MARK: - Headline Styles
    static let headlineLarge = Font.system(size: 32, weight: .bold, design: .default)
    static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .default)
    static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .default)
    
    // MARK: - Title Styles
    static let titleLarge = Font.system(size: 22, weight: .medium, design: .default)
    static let titleMedium = Font.system(size: 20, weight: .medium, design: .default)
    static let titleSmall = Font.system(size: 18, weight: .medium, design: .default)
    
    // MARK: - Body Styles
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    
    // MARK: - Label Styles
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 10, weight: .medium, design: .default)
    
    // MARK: - Caption Styles
    static let captionLarge = Font.system(size: 12, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 11, weight: .regular, design: .default)
    static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)
    
    // MARK: - Overline Styles
    static let overlineLarge = Font.system(size: 12, weight: .semibold, design: .default).uppercaseSmallCaps()
    static let overlineMedium = Font.system(size: 11, weight: .semibold, design: .default).uppercaseSmallCaps()
    static let overlineSmall = Font.system(size: 10, weight: .semibold, design: .default).uppercaseSmallCaps()
    
    // MARK: - Monospace Styles
    static let monospaceLarge = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let monospaceMedium = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let monospaceSmall = Font.system(size: 10, weight: .regular, design: .monospaced)
    
    // MARK: - Specialized Styles
    static let streamTitle = Font.system(size: 18, weight: .semibold, design: .default)
    static let streamerName = Font.system(size: 16, weight: .medium, design: .default)
    static let gameTitle = Font.system(size: 14, weight: .regular, design: .default)
    static let viewerCount = Font.system(size: 12, weight: .medium, design: .default)
    static let liveIndicator = Font.system(size: 10, weight: .bold, design: .default)
    static let platformBadge = Font.system(size: 9, weight: .semibold, design: .default)
    
    // MARK: - Navigation Styles
    static let navigationTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let navigationSubtitle = Font.system(size: 20, weight: .medium, design: .default)
    static let tabBarItem = Font.system(size: 10, weight: .medium, design: .default)
    
    // MARK: - Button Styles
    static let buttonLarge = Font.system(size: 18, weight: .semibold, design: .default)
    static let buttonMedium = Font.system(size: 16, weight: .semibold, design: .default)
    static let buttonSmall = Font.system(size: 14, weight: .semibold, design: .default)
    
    // MARK: - Custom Font Creator
    static func customFont(size: CGFloat, weight: FontWeight = .regular, design: Font.Design = .default) -> Font {
        return Font.system(size: size, weight: weight.systemWeight, design: design)
    }
    
    // MARK: - Accessibility Support
    static func accessibleFont(_ font: Font) -> Font {
        return UIAccessibility.isBoldTextEnabled ? font.bold() : font
    }
    
    static func dynamicFont(_ font: Font, category: Font.TextStyle) -> Font {
        return font
            .weight(UIAccessibility.isBoldTextEnabled ? .bold : .regular)
    }
    
    // MARK: - Line Height and Spacing
    static func lineHeight(for fontSize: CGFloat) -> CGFloat {
        return fontSize * 1.2
    }
    
    static func letterSpacing(for fontSize: CGFloat) -> CGFloat {
        return fontSize * 0.02
    }
    
    // MARK: - Responsive Typography
    static func responsiveSize(base: CGFloat, scale: CGFloat = 1.0) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let referenceWidth: CGFloat = 375 // iPhone 12 mini width
        let scaleFactor = screenWidth / referenceWidth
        return base * scaleFactor * scale
    }
    
    static func responsiveFont(base: CGFloat, weight: FontWeight = .regular, design: Font.Design = .default, scale: CGFloat = 1.0) -> Font {
        let responsiveSize = responsiveSize(base: base, scale: scale)
        return Font.system(size: responsiveSize, weight: weight.systemWeight, design: design)
    }
}

// MARK: - Font Style Modifiers
extension Font {
    // MARK: - Weight Modifiers
    func weight(_ weight: StreamyyyTypography.FontWeight) -> Font {
        return self.weight(weight.systemWeight)
    }
    
    // MARK: - Accessibility Modifiers
    func accessible() -> Font {
        return StreamyyyTypography.accessibleFont(self)
    }
    
    // MARK: - Responsive Modifiers
    func responsive(scale: CGFloat = 1.0) -> Font {
        // This is a simplified implementation
        return self
    }
}

// MARK: - Text Style Modifiers
struct StreamyyyTextStyle: ViewModifier {
    let font: Font
    let color: Color
    let lineSpacing: CGFloat
    let kerning: CGFloat
    
    init(font: Font, color: Color = StreamyyyColors.textPrimary, lineSpacing: CGFloat = 0, kerning: CGFloat = 0) {
        self.font = font
        self.color = color
        self.lineSpacing = lineSpacing
        self.kerning = kerning
    }
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
            .lineSpacing(lineSpacing)
            .kerning(kerning)
    }
}

// MARK: - Text Extensions
extension Text {
    // MARK: - Display Styles
    func displayLarge() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.displayLarge,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 8,
            kerning: -0.5
        ))
    }
    
    func displayMedium() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.displayMedium,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 6,
            kerning: -0.3
        ))
    }
    
    func displaySmall() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.displaySmall,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 4,
            kerning: -0.2
        ))
    }
    
    // MARK: - Headline Styles
    func headlineLarge() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.headlineLarge,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 2
        ))
    }
    
    func headlineMedium() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.headlineMedium,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 2
        ))
    }
    
    func headlineSmall() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.headlineSmall,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 1
        ))
    }
    
    // MARK: - Title Styles
    func titleLarge() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.titleLarge,
            color: StreamyyyColors.textPrimary
        ))
    }
    
    func titleMedium() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.titleMedium,
            color: StreamyyyColors.textPrimary
        ))
    }
    
    func titleSmall() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.titleSmall,
            color: StreamyyyColors.textPrimary
        ))
    }
    
    // MARK: - Body Styles
    func bodyLarge() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.bodyLarge,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 2
        ))
    }
    
    func bodyMedium() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.bodyMedium,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 1
        ))
    }
    
    func bodySmall() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.bodySmall,
            color: StreamyyyColors.textPrimary,
            lineSpacing: 1
        ))
    }
    
    // MARK: - Label Styles
    func labelLarge() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.labelLarge,
            color: StreamyyyColors.textSecondary
        ))
    }
    
    func labelMedium() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.labelMedium,
            color: StreamyyyColors.textSecondary
        ))
    }
    
    func labelSmall() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.labelSmall,
            color: StreamyyyColors.textSecondary
        ))
    }
    
    // MARK: - Caption Styles
    func captionLarge() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.captionLarge,
            color: StreamyyyColors.textTertiary
        ))
    }
    
    func captionMedium() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.captionMedium,
            color: StreamyyyColors.textTertiary
        ))
    }
    
    func captionSmall() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.captionSmall,
            color: StreamyyyColors.textTertiary
        ))
    }
    
    // MARK: - Specialized Styles
    func streamTitle() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.streamTitle,
            color: StreamyyyColors.textPrimary
        ))
    }
    
    func streamerName() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.streamerName,
            color: StreamyyyColors.textPrimary
        ))
    }
    
    func gameTitle() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.gameTitle,
            color: StreamyyyColors.textSecondary
        ))
    }
    
    func viewerCount() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.viewerCount,
            color: StreamyyyColors.textSecondary
        ))
    }
    
    func liveIndicator() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.liveIndicator,
            color: StreamyyyColors.liveIndicator
        ))
    }
    
    func platformBadge() -> some View {
        self.modifier(StreamyyyTextStyle(
            font: StreamyyyTypography.platformBadge,
            color: StreamyyyColors.textInverse
        ))
    }
}

// MARK: - SwiftUI Environment Key
private struct StreamyyyTypographyKey: EnvironmentKey {
    static let defaultValue = StreamyyyTypography.self
}

extension EnvironmentValues {
    var streamyyyTypography: StreamyyyTypography.Type {
        get { self[StreamyyyTypographyKey.self] }
        set { self[StreamyyyTypographyKey.self] = newValue }
    }
}