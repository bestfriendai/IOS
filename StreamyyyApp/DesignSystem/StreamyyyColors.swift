//
//  StreamyyyColors.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Comprehensive color system with dark/light mode support
//

import SwiftUI

// MARK: - StreamyyyColors
struct StreamyyyColors {
    
    // MARK: - Primary Brand Colors
    static let primary = Color("StreamyyyPrimary", bundle: .main)
    static let primaryLight = Color("StreamyyyPrimaryLight", bundle: .main)
    static let primaryDark = Color("StreamyyyPrimaryDark", bundle: .main)
    
    // MARK: - Secondary Colors
    static let secondary = Color("StreamyyySecondary", bundle: .main)
    static let secondaryLight = Color("StreamyyySecondaryLight", bundle: .main)
    static let secondaryDark = Color("StreamyyySecondaryDark", bundle: .main)
    
    // MARK: - Accent Colors
    static let accent = Color("StreamyyyAccent", bundle: .main)
    static let accentLight = Color("StreamyyyAccentLight", bundle: .main)
    static let accentDark = Color("StreamyyyAccentDark", bundle: .main)
    
    // MARK: - Background Colors
    static let background = Color("StreamyyyBackground", bundle: .main)
    static let backgroundSecondary = Color("StreamyyyBackgroundSecondary", bundle: .main)
    static let backgroundTertiary = Color("StreamyyyBackgroundTertiary", bundle: .main)
    
    // MARK: - Surface Colors
    static let surface = Color("StreamyyySurface", bundle: .main)
    static let surfaceSecondary = Color("StreamyyySurfaceSecondary", bundle: .main)
    static let surfaceTertiary = Color("StreamyyySurfaceTertiary", bundle: .main)
    
    // MARK: - Text Colors
    static let textPrimary = Color("StreamyyyTextPrimary", bundle: .main)
    static let textSecondary = Color("StreamyyyTextSecondary", bundle: .main)
    static let textTertiary = Color("StreamyyyTextTertiary", bundle: .main)
    static let textInverse = Color("StreamyyyTextInverse", bundle: .main)
    
    // MARK: - Status Colors
    static let success = Color("StreamyyySuccess", bundle: .main)
    static let warning = Color("StreamyyyWarning", bundle: .main)
    static let error = Color("StreamyyyError", bundle: .main)
    static let info = Color("StreamyyyInfo", bundle: .main)
    
    // MARK: - Live Stream Colors
    static let liveIndicator = Color("StreamyyyLiveIndicator", bundle: .main)
    static let offlineIndicator = Color("StreamyyyOfflineIndicator", bundle: .main)
    
    // MARK: - Platform Colors
    static let twitch = Color("StreamyyyTwitch", bundle: .main)
    static let youtube = Color("StreamyyyYouTube", bundle: .main)
    static let kick = Color("StreamyyyKick", bundle: .main)
    static let discord = Color("StreamyyyDiscord", bundle: .main)
    
    // MARK: - Overlay Colors
    static let overlay = Color("StreamyyyOverlay", bundle: .main)
    static let overlayLight = Color("StreamyyyOverlayLight", bundle: .main)
    static let overlayDark = Color("StreamyyyOverlayDark", bundle: .main)
    
    // MARK: - Border Colors
    static let border = Color("StreamyyyBorder", bundle: .main)
    static let borderLight = Color("StreamyyyBorderLight", bundle: .main)
    static let borderDark = Color("StreamyyyBorderDark", bundle: .main)
    
    // MARK: - Gradient Colors
    static let gradientStart = Color("StreamyyyGradientStart", bundle: .main)
    static let gradientEnd = Color("StreamyyyGradientEnd", bundle: .main)
    
    // MARK: - Fallback Colors (if color assets are not available)
    static let fallbackPrimary = Color(.systemPurple)
    static let fallbackSecondary = Color(.systemBlue)
    static let fallbackAccent = Color(.systemTeal)
    static let fallbackBackground = Color(.systemBackground)
    static let fallbackSurface = Color(.secondarySystemBackground)
    static let fallbackText = Color(.label)
    static let fallbackTextSecondary = Color(.secondaryLabel)
    
    // MARK: - Dynamic Colors
    static var adaptivePrimary: Color {
        return primary
    }
    
    static var adaptiveBackground: Color {
        return background
    }
    
    static var adaptiveText: Color {
        return textPrimary
    }
    
    static var adaptiveSurface: Color {
        return surface
    }
    
    // MARK: - Semantic Colors
    static var cardBackground: Color {
        return surface
    }
    
    static var cardBorder: Color {
        return border
    }
    
    static var buttonPrimary: Color {
        return primary
    }
    
    static var buttonSecondary: Color {
        return secondary
    }
    
    static var buttonText: Color {
        return textInverse
    }
    
    static var navigationBackground: Color {
        return background
    }
    
    static var tabBarBackground: Color {
        return surface
    }
    
    static var separatorColor: Color {
        return border
    }
    
    // MARK: - Platform Specific Colors
    static func platformColor(for platform: String) -> Color {
        switch platform.lowercased() {
        case "twitch":
            return twitch
        case "youtube":
            return youtube
        case "kick":
            return kick
        case "discord":
            return discord
        default:
            return secondary
        }
    }
    
    // MARK: - Status Colors
    static func statusColor(isLive: Bool) -> Color {
        return isLive ? liveIndicator : offlineIndicator
    }
    
    // MARK: - Accessibility Colors
    static var highContrast: Bool {
        return UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    static func accessibleColor(_ color: Color) -> Color {
        return highContrast ? color : color.opacity(0.9)
    }
}

// MARK: - Color Extensions
extension Color {
    // MARK: - Hex Color Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - Opacity Variations
    var light: Color {
        return self.opacity(0.7)
    }
    
    var medium: Color {
        return self.opacity(0.5)
    }
    
    var subtle: Color {
        return self.opacity(0.3)
    }
    
    var ghost: Color {
        return self.opacity(0.1)
    }
    
    // MARK: - Brightness Variations
    func lighter(_ amount: Double = 0.1) -> Color {
        return self.opacity(1.0 - amount)
    }
    
    func darker(_ amount: Double = 0.1) -> Color {
        return self.opacity(1.0 + amount)
    }
}

// MARK: - SwiftUI Environment Key
private struct StreamyyyColorsKey: EnvironmentKey {
    static let defaultValue = StreamyyyColors.self
}

extension EnvironmentValues {
    var streamyyyColors: StreamyyyColors.Type {
        get { self[StreamyyyColorsKey.self] }
        set { self[StreamyyyColorsKey.self] = newValue }
    }
}

// MARK: - Color Scheme Detection
extension StreamyyyColors {
    static func color(for colorScheme: ColorScheme, light: Color, dark: Color) -> Color {
        return colorScheme == .dark ? dark : light
    }
    
    static func adaptiveColor(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}