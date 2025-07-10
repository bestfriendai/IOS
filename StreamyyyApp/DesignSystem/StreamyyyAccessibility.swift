//
//  StreamyyyAccessibility.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Comprehensive accessibility support for VoiceOver, Dynamic Type, and more
//

import SwiftUI
import UIKit

// MARK: - StreamyyyAccessibility
struct StreamyyyAccessibility {
    
    // MARK: - Accessibility Settings
    static var isVoiceOverEnabled: Bool {
        return UIAccessibility.isVoiceOverRunning
    }
    
    static var isReduceMotionEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }
    
    static var isReduceTransparencyEnabled: Bool {
        return UIAccessibility.isReduceTransparencyEnabled
    }
    
    static var isInvertColorsEnabled: Bool {
        return UIAccessibility.isInvertColorsEnabled
    }
    
    static var isDarkerSystemColorsEnabled: Bool {
        return UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    static var isBoldTextEnabled: Bool {
        return UIAccessibility.isBoldTextEnabled
    }
    
    static var isButtonShapesEnabled: Bool {
        return UIAccessibility.isButtonShapesEnabled
    }
    
    static var isOnOffSwitchLabelsEnabled: Bool {
        return UIAccessibility.isOnOffSwitchLabelsEnabled
    }
    
    static var isClosedCaptioningEnabled: Bool {
        return UIAccessibility.isClosedCaptioningEnabled
    }
    
    static var prefersCrossFadeTransitions: Bool {
        return UIAccessibility.prefersCrossFadeTransitions
    }
    
    static var isVideoAutoplayEnabled: Bool {
        return UIAccessibility.isVideoAutoplayEnabled
    }
    
    // MARK: - Dynamic Type
    static var preferredContentSizeCategory: UIContentSizeCategory {
        return UIApplication.shared.preferredContentSizeCategory
    }
    
    static var isAccessibilitySize: Bool {
        return preferredContentSizeCategory.isAccessibilityCategory
    }
    
    static var dynamicTypeSize: DynamicTypeSize {
        switch preferredContentSizeCategory {
        case .extraSmall: return .xSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .xLarge
        case .extraExtraLarge: return .xxLarge
        case .extraExtraExtraLarge: return .xxxLarge
        case .accessibilityMedium: return .accessibility1
        case .accessibilityLarge: return .accessibility2
        case .accessibilityExtraLarge: return .accessibility3
        case .accessibilityExtraExtraLarge: return .accessibility4
        case .accessibilityExtraExtraExtraLarge: return .accessibility5
        default: return .large
        }
    }
    
    // MARK: - Font Scaling
    static func scaledFont(_ font: Font, category: UIContentSizeCategory? = nil) -> Font {
        let category = category ?? preferredContentSizeCategory
        let scaleFactor = fontScaleFactor(for: category)
        return font
    }
    
    static func fontScaleFactor(for category: UIContentSizeCategory) -> CGFloat {
        switch category {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.0
        case .extraLarge: return 1.1
        case .extraExtraLarge: return 1.2
        case .extraExtraExtraLarge: return 1.3
        case .accessibilityMedium: return 1.4
        case .accessibilityLarge: return 1.5
        case .accessibilityExtraLarge: return 1.6
        case .accessibilityExtraExtraLarge: return 1.7
        case .accessibilityExtraExtraExtraLarge: return 1.8
        default: return 1.0
        }
    }
    
    // MARK: - Color Adjustments
    static func accessibleColor(_ color: Color, for category: UIContentSizeCategory? = nil) -> Color {
        let category = category ?? preferredContentSizeCategory
        
        if isDarkerSystemColorsEnabled {
            return color.opacity(0.9)
        }
        
        return color
    }
    
    static func contrastAdjustedColor(_ color: Color, background: Color) -> Color {
        if isDarkerSystemColorsEnabled {
            return color
        }
        
        return color
    }
    
    // MARK: - Touch Target Adjustments
    static func minimumTouchTarget(for category: UIContentSizeCategory? = nil) -> CGFloat {
        let category = category ?? preferredContentSizeCategory
        
        switch category {
        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return 54
        default:
            return StreamyyySpacing.minimumTouchTarget
        }
    }
    
    // MARK: - Animation Adjustments
    static func accessibleAnimation(_ animation: Animation) -> Animation {
        if isReduceMotionEnabled {
            return Animation.easeInOut(duration: 0.1)
        }
        return animation
    }
    
    static func accessibleTransition(_ transition: AnyTransition) -> AnyTransition {
        if isReduceMotionEnabled {
            return AnyTransition.opacity
        }
        return transition
    }
    
    // MARK: - Haptic Feedback
    static func accessibleHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        if !isReduceMotionEnabled {
            StreamyyyDesignSystem.hapticFeedback(style)
        }
    }
    
    // MARK: - Utility Functions
    static func announceForAccessibility(_ message: String) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    static func screenChangedNotification() {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
    
    static func layoutChangedNotification() {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }
}

// MARK: - StreamyyyAccessibilityModifier
struct StreamyyyAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits
    let isButton: Bool
    let isHeader: Bool
    let sortPriority: Double
    
    init(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        isButton: Bool = false,
        isHeader: Bool = false,
        sortPriority: Double = 0
    ) {
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
        self.isButton = isButton
        self.isHeader = isHeader
        self.sortPriority = sortPriority
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(accessibilityTraits)
            .accessibilitySortPriority(sortPriority)
    }
    
    private var accessibilityTraits: AccessibilityTraits {
        var combinedTraits = traits
        
        if isButton {
            combinedTraits.insert(.isButton)
        }
        
        if isHeader {
            combinedTraits.insert(.isHeader)
        }
        
        return combinedTraits
    }
}

// MARK: - StreamyyyDynamicTypeModifier
struct StreamyyyDynamicTypeModifier: ViewModifier {
    let font: Font
    let lineLimit: Int?
    let minimumScaleFactor: CGFloat
    
    init(
        font: Font,
        lineLimit: Int? = nil,
        minimumScaleFactor: CGFloat = 0.8
    ) {
        self.font = font
        self.lineLimit = lineLimit
        self.minimumScaleFactor = minimumScaleFactor
    }
    
    func body(content: Content) -> some View {
        content
            .font(dynamicFont)
            .lineLimit(adjustedLineLimit)
            .minimumScaleFactor(minimumScaleFactor)
    }
    
    private var dynamicFont: Font {
        if StreamyyyAccessibility.isBoldTextEnabled {
            return font.bold()
        }
        
        return StreamyyyAccessibility.scaledFont(font)
    }
    
    private var adjustedLineLimit: Int? {
        if StreamyyyAccessibility.isAccessibilitySize {
            return nil // Allow unlimited lines for accessibility sizes
        }
        
        return lineLimit
    }
}

// MARK: - StreamyyyAccessibleButton
struct StreamyyyAccessibleButton: View {
    let title: String
    let action: () -> Void
    let style: StreamyyyButtonStyle
    let size: StreamyyyButtonSize
    let icon: String?
    let isDestructive: Bool
    let isEnabled: Bool
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    init(
        title: String,
        action: @escaping () -> Void,
        style: StreamyyyButtonStyle = .primary,
        size: StreamyyyButtonSize = .medium,
        icon: String? = nil,
        isDestructive: Bool = false,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.action = action
        self.style = style
        self.size = size
        self.icon = icon
        self.isDestructive = isDestructive
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        Button(action: {
            StreamyyyAccessibility.accessibleHaptic(.light)
            action()
        }) {
            HStack(spacing: StreamyyySpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundColor(foregroundColor)
                }
                
                Text(title)
                    .font(buttonFont)
                    .fontWeight(.semibold)
                    .foregroundColor(foregroundColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minimumHeight)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: 1
            )
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityRole(.button)
        .accessibilityAddTraits(accessibilityTraits)
        .frame(minWidth: minimumTouchTarget, minHeight: minimumTouchTarget)
    }
    
    // MARK: - Computed Properties
    private var buttonFont: Font {
        let baseFont = size.font
        
        if StreamyyyAccessibility.isBoldTextEnabled {
            return baseFont.bold()
        }
        
        return baseFont
    }
    
    private var iconSize: CGFloat {
        let baseSize = StreamyyySpacing.iconSizeSM
        let scaleFactor = StreamyyyAccessibility.fontScaleFactor(for: StreamyyyAccessibility.preferredContentSizeCategory)
        return baseSize * scaleFactor
    }
    
    private var horizontalPadding: CGFloat {
        let basePadding = size.padding
        
        if dynamicTypeSize.isAccessibilitySize {
            return basePadding * 1.5
        }
        
        return basePadding
    }
    
    private var verticalPadding: CGFloat {
        let basePadding = size.padding * 0.5
        
        if dynamicTypeSize.isAccessibilitySize {
            return basePadding * 1.5
        }
        
        return basePadding
    }
    
    private var minimumHeight: CGFloat {
        return StreamyyyAccessibility.minimumTouchTarget()
    }
    
    private var minimumTouchTarget: CGFloat {
        return StreamyyyAccessibility.minimumTouchTarget()
    }
    
    private var backgroundColor: Color {
        let baseColor: Color
        
        switch style {
        case .primary:
            baseColor = StreamyyyColors.primary
        case .secondary:
            baseColor = StreamyyyColors.secondary
        case .tertiary:
            baseColor = StreamyyyColors.surface
        case .destructive:
            baseColor = StreamyyyColors.error
        case .ghost:
            baseColor = Color.clear
        }
        
        return StreamyyyAccessibility.accessibleColor(baseColor)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .secondary, .destructive:
            return StreamyyyColors.textInverse
        case .tertiary, .ghost:
            return StreamyyyColors.textPrimary
        }
    }
    
    private var borderColor: Color {
        if StreamyyyAccessibility.isButtonShapesEnabled {
            return StreamyyyColors.border
        }
        
        switch style {
        case .primary, .secondary, .destructive:
            return Color.clear
        case .tertiary:
            return StreamyyyColors.border
        case .ghost:
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        if StreamyyyAccessibility.isButtonShapesEnabled {
            return StreamyyySpacing.borderWidthMedium
        }
        
        switch style {
        case .primary, .secondary, .destructive, .ghost:
            return 0
        case .tertiary:
            return StreamyyySpacing.borderWidthRegular
        }
    }
    
    private var shadowColor: Color {
        if StreamyyyAccessibility.isReduceTransparencyEnabled {
            return Color.clear
        }
        
        return StreamyyyColors.overlay.opacity(0.1)
    }
    
    private var shadowRadius: CGFloat {
        if StreamyyyAccessibility.isReduceTransparencyEnabled {
            return 0
        }
        
        return StreamyyySpacing.shadowRadiusXS
    }
    
    private var cornerRadius: CGFloat {
        return StreamyyySpacing.cornerRadiusSM
    }
    
    private var accessibilityLabel: String {
        return title
    }
    
    private var accessibilityHint: String {
        if isDestructive {
            return "This action cannot be undone"
        }
        
        switch style {
        case .primary:
            return "Primary action"
        case .secondary:
            return "Secondary action"
        case .tertiary:
            return "Tertiary action"
        case .destructive:
            return "Destructive action"
        case .ghost:
            return "Ghost button"
        }
    }
    
    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = []
        
        if !isEnabled {
            traits.insert(.notEnabled)
        }
        
        if isDestructive {
            traits.insert(.isButton)
        }
        
        return traits
    }
}

// MARK: - StreamyyyAccessibleCard
struct StreamyyyAccessibleCard<Content: View>: View {
    let content: Content
    let title: String
    let subtitle: String?
    let isInteractive: Bool
    let onTap: (() -> Void)?
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    init(
        title: String,
        subtitle: String? = nil,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isInteractive = isInteractive
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isInteractive, let onTap = onTap {
                Button(action: {
                    StreamyyyAccessibility.accessibleHaptic(.light)
                    onTap()
                }) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
        .accessibilityAddTraits(isInteractive ? .isButton : [])
        .frame(minHeight: minimumTouchTarget)
    }
    
    private var cardContent: some View {
        content
            .padding(cardPadding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: 2
            )
    }
    
    private var cardPadding: CGFloat {
        let basePadding = StreamyyySpacing.cardPadding
        
        if dynamicTypeSize.isAccessibilitySize {
            return basePadding * 1.5
        }
        
        return basePadding
    }
    
    private var backgroundColor: Color {
        return StreamyyyAccessibility.accessibleColor(StreamyyyColors.surface)
    }
    
    private var borderColor: Color {
        return StreamyyyColors.border
    }
    
    private var borderWidth: CGFloat {
        return StreamyyySpacing.borderWidthThin
    }
    
    private var shadowColor: Color {
        if StreamyyyAccessibility.isReduceTransparencyEnabled {
            return Color.clear
        }
        
        return StreamyyyColors.overlay.opacity(0.1)
    }
    
    private var shadowRadius: CGFloat {
        if StreamyyyAccessibility.isReduceTransparencyEnabled {
            return 0
        }
        
        return StreamyyySpacing.shadowRadiusSM
    }
    
    private var cornerRadius: CGFloat {
        return StreamyyySpacing.cornerRadiusMD
    }
    
    private var minimumTouchTarget: CGFloat {
        if isInteractive {
            return StreamyyyAccessibility.minimumTouchTarget()
        }
        
        return 0
    }
}

// MARK: - View Extensions
extension View {
    // MARK: - Accessibility Modifiers
    func streamyyyAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        isButton: Bool = false,
        isHeader: Bool = false,
        sortPriority: Double = 0
    ) -> some View {
        self.modifier(StreamyyyAccessibilityModifier(
            label: label,
            hint: hint,
            value: value,
            traits: traits,
            isButton: isButton,
            isHeader: isHeader,
            sortPriority: sortPriority
        ))
    }
    
    // MARK: - Dynamic Type Modifiers
    func streamyyyDynamicType(
        font: Font,
        lineLimit: Int? = nil,
        minimumScaleFactor: CGFloat = 0.8
    ) -> some View {
        self.modifier(StreamyyyDynamicTypeModifier(
            font: font,
            lineLimit: lineLimit,
            minimumScaleFactor: minimumScaleFactor
        ))
    }
    
    // MARK: - Accessibility Animations
    func accessibilityReducedMotion<T: Equatable>(value: T) -> some View {
        self.animation(StreamyyyAccessibility.accessibleAnimation(StreamyyyAnimations.standard), value: value)
    }
    
    // MARK: - Accessibility Touch Target
    func accessibilityTouchTarget() -> some View {
        self.frame(
            minWidth: StreamyyyAccessibility.minimumTouchTarget(),
            minHeight: StreamyyyAccessibility.minimumTouchTarget()
        )
    }
    
    // MARK: - Accessibility Announcements
    func accessibilityAnnouncement(_ message: String, delay: Double = 0) -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                StreamyyyAccessibility.announceForAccessibility(message)
            }
        }
    }
}

// MARK: - Accessibility Preview
struct StreamyyyAccessibilityPreview: View {
    @State private var showModal = false
    
    var body: some View {
        StreamyyyScreenContainer {
            StreamyyyScrollView {
                VStack(spacing: StreamyyySpacing.lg) {
                    Text("Accessibility Components")
                        .streamyyyAccessibility(
                            label: "Accessibility Components",
                            isHeader: true,
                            sortPriority: 1
                        )
                        .headlineLarge()
                    
                    StreamyyyAccessibleCard(
                        title: "Accessible Card",
                        subtitle: "This card supports dynamic type and accessibility features",
                        isInteractive: true,
                        onTap: {
                            print("Card tapped")
                        }
                    ) {
                        VStack(alignment: .leading, spacing: StreamyyySpacing.sm) {
                            Text("Card Content")
                                .streamyyyDynamicType(font: StreamyyyTypography.titleMedium)
                            
                            Text("This content adapts to user preferences")
                                .streamyyyDynamicType(font: StreamyyyTypography.bodyMedium)
                                .foregroundColor(StreamyyyColors.textSecondary)
                        }
                    }
                    
                    VStack(spacing: StreamyyySpacing.md) {
                        Text("Accessible Buttons")
                            .streamyyyAccessibility(
                                label: "Accessible Buttons Section",
                                isHeader: true
                            )
                            .titleMedium()
                        
                        StreamyyyAccessibleButton(
                            title: "Primary Action",
                            action: {
                                print("Primary action")
                            },
                            style: .primary,
                            icon: "star.fill"
                        )
                        
                        StreamyyyAccessibleButton(
                            title: "Secondary Action",
                            action: {
                                print("Secondary action")
                            },
                            style: .secondary,
                            icon: "heart.fill"
                        )
                        
                        StreamyyyAccessibleButton(
                            title: "Destructive Action",
                            action: {
                                print("Destructive action")
                            },
                            style: .destructive,
                            icon: "trash.fill",
                            isDestructive: true
                        )
                    }
                    
                    VStack(spacing: StreamyyySpacing.md) {
                        Text("Accessibility Information")
                            .streamyyyAccessibility(
                                label: "Accessibility Information Section",
                                isHeader: true
                            )
                            .titleMedium()
                        
                        StreamyyyAccessibleCard(
                            title: "VoiceOver Status",
                            subtitle: StreamyyyAccessibility.isVoiceOverEnabled ? "Enabled" : "Disabled"
                        ) {
                            HStack {
                                Image(systemName: "accessibility")
                                    .foregroundColor(StreamyyyColors.primary)
                                
                                Text("VoiceOver: \(StreamyyyAccessibility.isVoiceOverEnabled ? "On" : "Off")")
                                    .streamyyyDynamicType(font: StreamyyyTypography.bodyMedium)
                            }
                        }
                        
                        StreamyyyAccessibleCard(
                            title: "Dynamic Type Size",
                            subtitle: "Current text size preference"
                        ) {
                            HStack {
                                Image(systemName: "textformat.size")
                                    .foregroundColor(StreamyyyColors.primary)
                                
                                Text("Size: \(StreamyyyAccessibility.preferredContentSizeCategory.rawValue)")
                                    .streamyyyDynamicType(font: StreamyyyTypography.bodyMedium)
                            }
                        }
                        
                        StreamyyyAccessibleCard(
                            title: "Reduce Motion",
                            subtitle: StreamyyyAccessibility.isReduceMotionEnabled ? "Enabled" : "Disabled"
                        ) {
                            HStack {
                                Image(systemName: "motion.badge.questionmark")
                                    .foregroundColor(StreamyyyColors.primary)
                                
                                Text("Reduce Motion: \(StreamyyyAccessibility.isReduceMotionEnabled ? "On" : "Off")")
                                    .streamyyyDynamicType(font: StreamyyyTypography.bodyMedium)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityAnnouncement("Accessibility preview loaded")
    }
}

#Preview {
    StreamyyyAccessibilityPreview()
}