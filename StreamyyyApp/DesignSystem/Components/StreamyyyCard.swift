//
//  StreamyyyCard.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Modern card component with accessibility and animations
//

import SwiftUI

// MARK: - StreamyyyCard
struct StreamyyyCard<Content: View>: View {
    let content: Content
    let style: StreamyyyCardStyle
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadowStyle: StreamyyyCardShadowStyle
    let borderStyle: StreamyyyCardBorderStyle
    let isInteractive: Bool
    let onTap: (() -> Void)?
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(
        style: StreamyyyCardStyle = .default,
        padding: CGFloat = StreamyyySpacing.md,
        cornerRadius: CGFloat = StreamyyySpacing.cardCornerRadius,
        shadowStyle: StreamyyyCardShadowStyle = .default,
        borderStyle: StreamyyyCardBorderStyle = .none,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowStyle = shadowStyle
        self.borderStyle = borderStyle
        self.isInteractive = isInteractive
        self.onTap = onTap
    }
    
    var body: some View {
        Group {
            if isInteractive, let onTap = onTap {
                Button(action: {
                    StreamyyyDesignSystem.hapticFeedback(.light)
                    onTap()
                }) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }, perform: {})
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovered = hovering
                    }
                }
            } else {
                cardContent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isInteractive ? .isButton : [])
    }
    
    private var cardContent: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: shadowOffset.x,
                y: shadowOffset.y
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        switch style {
        case .default:
            return isHovered ? StreamyyyColors.surfaceSecondary : StreamyyyColors.surface
        case .primary:
            return isHovered ? StreamyyyColors.primaryLight : StreamyyyColors.primary
        case .secondary:
            return isHovered ? StreamyyyColors.secondaryLight : StreamyyyColors.secondary
        case .success:
            return isHovered ? StreamyyyColors.success.opacity(0.8) : StreamyyyColors.success.opacity(0.1)
        case .warning:
            return isHovered ? StreamyyyColors.warning.opacity(0.8) : StreamyyyColors.warning.opacity(0.1)
        case .error:
            return isHovered ? StreamyyyColors.error.opacity(0.8) : StreamyyyColors.error.opacity(0.1)
        case .transparent:
            return Color.clear
        case .glass:
            return StreamyyyColors.surface.opacity(0.8)
        }
    }
    
    private var borderColor: Color {
        switch borderStyle {
        case .none:
            return Color.clear
        case .default:
            return StreamyyyColors.border
        case .primary:
            return StreamyyyColors.primary
        case .secondary:
            return StreamyyyColors.secondary
        case .success:
            return StreamyyyColors.success
        case .warning:
            return StreamyyyColors.warning
        case .error:
            return StreamyyyColors.error
        }
    }
    
    private var borderWidth: CGFloat {
        switch borderStyle {
        case .none:
            return 0
        default:
            return StreamyyySpacing.borderWidthRegular
        }
    }
    
    private var shadowColor: Color {
        switch shadowStyle {
        case .none:
            return Color.clear
        case .default:
            return StreamyyyColors.overlay.opacity(0.1)
        case .elevated:
            return StreamyyyColors.overlay.opacity(0.2)
        case .floating:
            return StreamyyyColors.overlay.opacity(0.3)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch shadowStyle {
        case .none:
            return 0
        case .default:
            return StreamyyySpacing.shadowRadiusSM
        case .elevated:
            return StreamyyySpacing.shadowRadiusMD
        case .floating:
            return StreamyyySpacing.shadowRadiusLG
        }
    }
    
    private var shadowOffset: CGPoint {
        switch shadowStyle {
        case .none:
            return CGPoint(x: 0, y: 0)
        case .default:
            return CGPoint(x: 0, y: 2)
        case .elevated:
            return CGPoint(x: 0, y: 4)
        case .floating:
            return CGPoint(x: 0, y: 8)
        }
    }
}

// MARK: - StreamyyyCard Styles
enum StreamyyyCardStyle {
    case `default`
    case primary
    case secondary
    case success
    case warning
    case error
    case transparent
    case glass
}

enum StreamyyyCardShadowStyle {
    case none
    case `default`
    case elevated
    case floating
}

enum StreamyyyCardBorderStyle {
    case none
    case `default`
    case primary
    case secondary
    case success
    case warning
    case error
}

// MARK: - StreamCard (Stream-specific card)
struct StreamCard<Content: View>: View {
    let content: Content
    let stream: AppStream?
    let isLive: Bool
    let onTap: (() -> Void)?
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(
        stream: AppStream? = nil,
        isLive: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.stream = stream
        self.isLive = isLive
        self.onTap = onTap
    }
    
    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: {
                    StreamyyyDesignSystem.hapticFeedback(.light)
                    onTap()
                }) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }, perform: {})
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovered = hovering
                    }
                }
            } else {
                cardContent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private var cardContent: some View {
        content
            .padding(StreamyyySpacing.streamCardPadding)
            .background(backgroundColor)
            .cornerRadius(StreamyyySpacing.streamCardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: StreamyyySpacing.streamCardCornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: 2
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        return isHovered ? StreamyyyColors.surfaceSecondary : StreamyyyColors.surface
    }
    
    private var borderColor: Color {
        if isLive {
            return StreamyyyColors.liveIndicator.opacity(0.3)
        }
        return StreamyyyColors.border
    }
    
    private var borderWidth: CGFloat {
        return isLive ? StreamyyySpacing.borderWidthMedium : StreamyyySpacing.borderWidthThin
    }
    
    private var shadowColor: Color {
        return StreamyyyColors.overlay.opacity(0.1)
    }
    
    private var shadowRadius: CGFloat {
        return isHovered ? StreamyyySpacing.shadowRadiusMD : StreamyyySpacing.shadowRadiusSM
    }
    
    private var accessibilityLabel: String {
        if let stream = stream {
            return "Stream: \(stream.streamerName) - \(stream.title)"
        }
        return "Stream card"
    }
    
    private var accessibilityHint: String {
        if isLive {
            return "Live stream, tap to watch"
        }
        return "Stream card, tap to view details"
    }
}

// MARK: - StreamyyyInfoCard
struct StreamyyyInfoCard: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let style: StreamyyyCardStyle
    let onTap: (() -> Void)?
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        style: StreamyyyCardStyle = .default,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.style = style
        self.onTap = onTap
    }
    
    var body: some View {
        StreamyyyCard(
            style: style,
            isInteractive: onTap != nil,
            onTap: onTap
        ) {
            HStack(spacing: StreamyyySpacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: StreamyyySpacing.iconSizeLG, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
                    Text(title)
                        .titleMedium()
                        .foregroundColor(titleColor)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .bodySmall()
                            .foregroundColor(subtitleColor)
                    }
                }
                
                Spacer()
                
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: StreamyyySpacing.iconSizeSM, weight: .medium))
                        .foregroundColor(StreamyyyColors.textTertiary)
                }
            }
        }
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }
    
    private var iconColor: Color {
        switch style {
        case .default, .transparent, .glass:
            return StreamyyyColors.primary
        case .primary:
            return StreamyyyColors.textInverse
        case .secondary:
            return StreamyyyColors.textInverse
        case .success:
            return StreamyyyColors.success
        case .warning:
            return StreamyyyColors.warning
        case .error:
            return StreamyyyColors.error
        }
    }
    
    private var titleColor: Color {
        switch style {
        case .default, .transparent, .glass, .success, .warning, .error:
            return StreamyyyColors.textPrimary
        case .primary, .secondary:
            return StreamyyyColors.textInverse
        }
    }
    
    private var subtitleColor: Color {
        switch style {
        case .default, .transparent, .glass, .success, .warning, .error:
            return StreamyyyColors.textSecondary
        case .primary, .secondary:
            return StreamyyyColors.textInverse.opacity(0.8)
        }
    }
}

// MARK: - StreamyyyStatsCard
struct StreamyyyStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: StreamyyyStatsTrend?
    
    init(
        title: String,
        value: String,
        icon: String,
        color: Color = StreamyyyColors.primary,
        trend: StreamyyyStatsTrend? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.trend = trend
    }
    
    var body: some View {
        StreamyyyCard {
            VStack(alignment: .leading, spacing: StreamyyySpacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    if let trend = trend {
                        HStack(spacing: StreamyyySpacing.xs) {
                            Image(systemName: trend.icon)
                                .font(.system(size: StreamyyySpacing.iconSizeXS, weight: .medium))
                                .foregroundColor(trend.color)
                            
                            Text(trend.value)
                                .captionMedium()
                                .foregroundColor(trend.color)
                        }
                    }
                }
                
                Text(value)
                    .headlineMedium()
                    .foregroundColor(StreamyyyColors.textPrimary)
                
                Text(title)
                    .captionLarge()
                    .foregroundColor(StreamyyyColors.textSecondary)
            }
        }
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(trend?.accessibilityHint ?? "")
    }
}

// MARK: - StreamyyyStatsTrend
struct StreamyyyStatsTrend {
    let value: String
    let isPositive: Bool
    
    var icon: String {
        return isPositive ? "arrow.up" : "arrow.down"
    }
    
    var color: Color {
        return isPositive ? StreamyyyColors.success : StreamyyyColors.error
    }
    
    var accessibilityHint: String {
        return isPositive ? "Trending up" : "Trending down"
    }
}

// MARK: - Card Previews
struct StreamyyyCardPreviews: View {
    var body: some View {
        ScrollView {
            VStack(spacing: StreamyyySpacing.lg) {
                Text("Card Components")
                    .headlineLarge()
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Basic Cards")
                        .titleMedium()
                    
                    StreamyyyCard {
                        Text("Default Card")
                            .bodyLarge()
                    }
                    
                    StreamyyyCard(style: .primary) {
                        Text("Primary Card")
                            .bodyLarge()
                            .foregroundColor(StreamyyyColors.textInverse)
                    }
                    
                    StreamyyyCard(style: .secondary) {
                        Text("Secondary Card")
                            .bodyLarge()
                            .foregroundColor(StreamyyyColors.textInverse)
                    }
                    
                    StreamyyyCard(style: .success, borderStyle: .success) {
                        Text("Success Card")
                            .bodyLarge()
                    }
                    
                    StreamyyyCard(style: .warning, borderStyle: .warning) {
                        Text("Warning Card")
                            .bodyLarge()
                    }
                    
                    StreamyyyCard(style: .error, borderStyle: .error) {
                        Text("Error Card")
                            .bodyLarge()
                    }
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Interactive Cards")
                        .titleMedium()
                    
                    StreamyyyCard(isInteractive: true, onTap: {}) {
                        Text("Tap me!")
                            .bodyLarge()
                    }
                    
                    StreamyyyInfoCard(
                        title: "Settings",
                        subtitle: "Configure your preferences",
                        icon: "gear",
                        onTap: {}
                    )
                    
                    StreamyyyInfoCard(
                        title: "Live Stream",
                        subtitle: "Currently streaming",
                        icon: "video.fill",
                        style: .success
                    )
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Stats Cards")
                        .titleMedium()
                    
                    HStack(spacing: StreamyyySpacing.md) {
                        StreamyyyStatsCard(
                            title: "Views",
                            value: "1,234",
                            icon: "eye.fill",
                            color: StreamyyyColors.primary,
                            trend: StreamyyyStatsTrend(value: "+12%", isPositive: true)
                        )
                        
                        StreamyyyStatsCard(
                            title: "Followers",
                            value: "856",
                            icon: "person.fill",
                            color: StreamyyyColors.secondary,
                            trend: StreamyyyStatsTrend(value: "-3%", isPositive: false)
                        )
                    }
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Shadow Styles")
                        .titleMedium()
                    
                    StreamyyyCard(shadowStyle: .none) {
                        Text("No Shadow")
                            .bodyLarge()
                    }
                    
                    StreamyyyCard(shadowStyle: .default) {
                        Text("Default Shadow")
                            .bodyLarge()
                    }
                    
                    StreamyyyCard(shadowStyle: .elevated) {
                        Text("Elevated Shadow")
                            .bodyLarge()
                    }
                    
                    StreamyyyCard(shadowStyle: .floating) {
                        Text("Floating Shadow")
                            .bodyLarge()
                    }
                }
            }
            .screenPadding()
        }
        .themedBackground()
    }
}

#Preview {
    StreamyyyCardPreviews()
}