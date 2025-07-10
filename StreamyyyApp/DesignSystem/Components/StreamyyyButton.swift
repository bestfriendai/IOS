//
//  StreamyyyButton.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Modern, accessible button component with animations
//

import SwiftUI

// MARK: - StreamyyyButton
struct StreamyyyButton: View {
    let title: String
    let style: StreamyyyButtonStyle
    let size: StreamyyyButtonSize
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    
    init(
        title: String,
        style: StreamyyyButtonStyle = .primary,
        size: StreamyyyButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            StreamyyyDesignSystem.hapticFeedback(.light)
            action()
        }) {
            HStack(spacing: StreamyyySpacing.sm) {
                Text(title)
                    .font(size.font)
                    .fontWeight(.semibold)
                    .foregroundColor(foregroundColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: size.height)
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
                y: shadowOffset
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
        .accessibilityRole(.button)
        .accessibilityAddTraits(isEnabled ? [] : .notEnabled)
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        if !isEnabled {
            return StreamyyyColors.surface
        }
        
        switch style {
        case .primary:
            return isHovered ? StreamyyyColors.primaryDark : StreamyyyColors.primary
        case .secondary:
            return isHovered ? StreamyyyColors.secondaryDark : StreamyyyColors.secondary
        case .tertiary:
            return isHovered ? StreamyyyColors.surfaceSecondary : StreamyyyColors.surface
        case .destructive:
            return isHovered ? StreamyyyColors.error.opacity(0.8) : StreamyyyColors.error
        case .ghost:
            return isHovered ? StreamyyyColors.surface : Color.clear
        }
    }
    
    private var foregroundColor: Color {
        if !isEnabled {
            return StreamyyyColors.textTertiary
        }
        
        switch style {
        case .primary, .secondary, .destructive:
            return StreamyyyColors.textInverse
        case .tertiary, .ghost:
            return StreamyyyColors.textPrimary
        }
    }
    
    private var borderColor: Color {
        if !isEnabled {
            return StreamyyyColors.border
        }
        
        switch style {
        case .primary, .secondary, .destructive:
            return Color.clear
        case .tertiary:
            return StreamyyyColors.border
        case .ghost:
            return isHovered ? StreamyyyColors.border : Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary, .secondary, .destructive:
            return 0
        case .tertiary, .ghost:
            return StreamyyySpacing.borderWidthRegular
        }
    }
    
    private var shadowColor: Color {
        if !isEnabled || style == .ghost {
            return Color.clear
        }
        
        return StreamyyyColors.overlay.opacity(0.15)
    }
    
    private var shadowRadius: CGFloat {
        if !isEnabled || style == .ghost {
            return 0
        }
        
        return isPressed ? 1 : StreamyyySpacing.shadowRadiusXS
    }
    
    private var shadowOffset: CGFloat {
        if !isEnabled || style == .ghost {
            return 0
        }
        
        return isPressed ? 0 : 1
    }
    
    private var opacity: Double {
        if !isEnabled {
            return 0.5
        }
        
        return 1.0
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.sm
        case .medium: return StreamyyySpacing.md
        case .large: return StreamyyySpacing.lg
        case .extraLarge: return StreamyyySpacing.xl
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.xs
        case .medium: return StreamyyySpacing.sm
        case .large: return StreamyyySpacing.md
        case .extraLarge: return StreamyyySpacing.lg
        }
    }
    
    private var cornerRadius: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.cornerRadiusXS
        case .medium: return StreamyyySpacing.cornerRadiusSM
        case .large: return StreamyyySpacing.cornerRadiusMD
        case .extraLarge: return StreamyyySpacing.cornerRadiusLG
        }
    }
    
    private var accessibilityHint: String {
        switch style {
        case .primary: return "Primary action button"
        case .secondary: return "Secondary action button"
        case .tertiary: return "Tertiary action button"
        case .destructive: return "Destructive action button"
        case .ghost: return "Ghost button"
        }
    }
}

// MARK: - StreamyyyIconButton
struct StreamyyyIconButton: View {
    let icon: String
    let title: String?
    let style: StreamyyyButtonStyle
    let size: StreamyyyButtonSize
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    
    init(
        icon: String,
        title: String? = nil,
        style: StreamyyyButtonStyle = .primary,
        size: StreamyyyButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            StreamyyyDesignSystem.hapticFeedback(.light)
            action()
        }) {
            HStack(spacing: StreamyyySpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(foregroundColor)
                
                if let title = title {
                    Text(title)
                        .font(size.font)
                        .fontWeight(.semibold)
                        .foregroundColor(foregroundColor)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: size.height)
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
                y: shadowOffset
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(title ?? icon)
        .accessibilityHint("Button with icon \(icon)")
        .accessibilityRole(.button)
        .accessibilityAddTraits(isEnabled ? [] : .notEnabled)
    }
    
    // MARK: - Computed Properties (similar to StreamyyyButton)
    private var backgroundColor: Color {
        if !isEnabled {
            return StreamyyyColors.surface
        }
        
        switch style {
        case .primary:
            return isHovered ? StreamyyyColors.primaryDark : StreamyyyColors.primary
        case .secondary:
            return isHovered ? StreamyyyColors.secondaryDark : StreamyyyColors.secondary
        case .tertiary:
            return isHovered ? StreamyyyColors.surfaceSecondary : StreamyyyColors.surface
        case .destructive:
            return isHovered ? StreamyyyColors.error.opacity(0.8) : StreamyyyColors.error
        case .ghost:
            return isHovered ? StreamyyyColors.surface : Color.clear
        }
    }
    
    private var foregroundColor: Color {
        if !isEnabled {
            return StreamyyyColors.textTertiary
        }
        
        switch style {
        case .primary, .secondary, .destructive:
            return StreamyyyColors.textInverse
        case .tertiary, .ghost:
            return StreamyyyColors.textPrimary
        }
    }
    
    private var borderColor: Color {
        if !isEnabled {
            return StreamyyyColors.border
        }
        
        switch style {
        case .primary, .secondary, .destructive:
            return Color.clear
        case .tertiary:
            return StreamyyyColors.border
        case .ghost:
            return isHovered ? StreamyyyColors.border : Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary, .secondary, .destructive:
            return 0
        case .tertiary, .ghost:
            return StreamyyySpacing.borderWidthRegular
        }
    }
    
    private var shadowColor: Color {
        if !isEnabled || style == .ghost {
            return Color.clear
        }
        
        return StreamyyyColors.overlay.opacity(0.15)
    }
    
    private var shadowRadius: CGFloat {
        if !isEnabled || style == .ghost {
            return 0
        }
        
        return isPressed ? 1 : StreamyyySpacing.shadowRadiusXS
    }
    
    private var shadowOffset: CGFloat {
        if !isEnabled || style == .ghost {
            return 0
        }
        
        return isPressed ? 0 : 1
    }
    
    private var opacity: Double {
        if !isEnabled {
            return 0.5
        }
        
        return 1.0
    }
    
    private var horizontalPadding: CGFloat {
        let basePadding: CGFloat
        switch size {
        case .small: basePadding = StreamyyySpacing.sm
        case .medium: basePadding = StreamyyySpacing.md
        case .large: basePadding = StreamyyySpacing.lg
        case .extraLarge: basePadding = StreamyyySpacing.xl
        }
        
        // Adjust padding for icon-only buttons
        return title == nil ? basePadding * 0.75 : basePadding
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.xs
        case .medium: return StreamyyySpacing.sm
        case .large: return StreamyyySpacing.md
        case .extraLarge: return StreamyyySpacing.lg
        }
    }
    
    private var cornerRadius: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.cornerRadiusXS
        case .medium: return StreamyyySpacing.cornerRadiusSM
        case .large: return StreamyyySpacing.cornerRadiusMD
        case .extraLarge: return StreamyyySpacing.cornerRadiusLG
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.iconSizeXS
        case .medium: return StreamyyySpacing.iconSizeSM
        case .large: return StreamyyySpacing.iconSizeMD
        case .extraLarge: return StreamyyySpacing.iconSizeLG
        }
    }
}

// MARK: - StreamyyyToggleButton
struct StreamyyyToggleButton: View {
    let title: String
    let icon: String?
    @Binding var isOn: Bool
    let style: StreamyyyButtonStyle
    let size: StreamyyyButtonSize
    
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    
    init(
        title: String,
        icon: String? = nil,
        isOn: Binding<Bool>,
        style: StreamyyyButtonStyle = .tertiary,
        size: StreamyyyButtonSize = .medium
    ) {
        self.title = title
        self.icon = icon
        self._isOn = isOn
        self.style = style
        self.size = size
    }
    
    var body: some View {
        Button(action: {
            StreamyyyDesignSystem.hapticFeedback(.light)
            isOn.toggle()
        }) {
            HStack(spacing: StreamyyySpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundColor(foregroundColor)
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.semibold)
                    .foregroundColor(foregroundColor)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: size.height)
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
                y: shadowOffset
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isOn)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(title)
        .accessibilityHint("Toggle button, currently \(isOn ? "on" : "off")")
        .accessibilityRole(.button)
        .accessibilityAddTraits(isEnabled ? [] : .notEnabled)
        .accessibilityValue(isOn ? "On" : "Off")
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        if !isEnabled {
            return StreamyyyColors.surface
        }
        
        if isOn {
            return StreamyyyColors.primary
        }
        
        switch style {
        case .primary:
            return isHovered ? StreamyyyColors.primaryDark : StreamyyyColors.surface
        case .secondary:
            return isHovered ? StreamyyyColors.secondaryDark : StreamyyyColors.surface
        case .tertiary:
            return isHovered ? StreamyyyColors.surfaceSecondary : StreamyyyColors.surface
        case .destructive:
            return isHovered ? StreamyyyColors.error.opacity(0.8) : StreamyyyColors.surface
        case .ghost:
            return isHovered ? StreamyyyColors.surface : Color.clear
        }
    }
    
    private var foregroundColor: Color {
        if !isEnabled {
            return StreamyyyColors.textTertiary
        }
        
        if isOn {
            return StreamyyyColors.textInverse
        }
        
        return StreamyyyColors.textPrimary
    }
    
    private var borderColor: Color {
        if !isEnabled {
            return StreamyyyColors.border
        }
        
        if isOn {
            return StreamyyyColors.primary
        }
        
        return StreamyyyColors.border
    }
    
    private var borderWidth: CGFloat {
        return StreamyyySpacing.borderWidthRegular
    }
    
    private var shadowColor: Color {
        if !isEnabled || style == .ghost {
            return Color.clear
        }
        
        return StreamyyyColors.overlay.opacity(0.15)
    }
    
    private var shadowRadius: CGFloat {
        if !isEnabled || style == .ghost {
            return 0
        }
        
        return isPressed ? 1 : StreamyyySpacing.shadowRadiusXS
    }
    
    private var shadowOffset: CGFloat {
        if !isEnabled || style == .ghost {
            return 0
        }
        
        return isPressed ? 0 : 1
    }
    
    private var opacity: Double {
        if !isEnabled {
            return 0.5
        }
        
        return 1.0
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.sm
        case .medium: return StreamyyySpacing.md
        case .large: return StreamyyySpacing.lg
        case .extraLarge: return StreamyyySpacing.xl
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.xs
        case .medium: return StreamyyySpacing.sm
        case .large: return StreamyyySpacing.md
        case .extraLarge: return StreamyyySpacing.lg
        }
    }
    
    private var cornerRadius: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.cornerRadiusXS
        case .medium: return StreamyyySpacing.cornerRadiusSM
        case .large: return StreamyyySpacing.cornerRadiusMD
        case .extraLarge: return StreamyyySpacing.cornerRadiusLG
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small: return StreamyyySpacing.iconSizeXS
        case .medium: return StreamyyySpacing.iconSizeSM
        case .large: return StreamyyySpacing.iconSizeMD
        case .extraLarge: return StreamyyySpacing.iconSizeLG
        }
    }
}

// MARK: - Button Previews
struct StreamyyyButtonPreviews: View {
    @State private var isToggled = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: StreamyyySpacing.lg) {
                Text("Button Components")
                    .headlineLarge()
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Regular Buttons")
                        .titleMedium()
                    
                    StreamyyyButton(title: "Primary", style: .primary) { }
                    StreamyyyButton(title: "Secondary", style: .secondary) { }
                    StreamyyyButton(title: "Tertiary", style: .tertiary) { }
                    StreamyyyButton(title: "Destructive", style: .destructive) { }
                    StreamyyyButton(title: "Ghost", style: .ghost) { }
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Icon Buttons")
                        .titleMedium()
                    
                    StreamyyyIconButton(icon: "play.fill", title: "Play", style: .primary) { }
                    StreamyyyIconButton(icon: "heart.fill", title: "Like", style: .secondary) { }
                    StreamyyyIconButton(icon: "share", style: .tertiary) { }
                    StreamyyyIconButton(icon: "trash", style: .destructive) { }
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Toggle Buttons")
                        .titleMedium()
                    
                    StreamyyyToggleButton(title: "Toggle", isOn: $isToggled)
                    StreamyyyToggleButton(title: "With Icon", icon: "heart.fill", isOn: $isToggled)
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Button Sizes")
                        .titleMedium()
                    
                    StreamyyyButton(title: "Small", size: .small) { }
                    StreamyyyButton(title: "Medium", size: .medium) { }
                    StreamyyyButton(title: "Large", size: .large) { }
                    StreamyyyButton(title: "Extra Large", size: .extraLarge) { }
                }
            }
            .screenPadding()
        }
        .themedBackground()
    }
}

#Preview {
    StreamyyyButtonPreviews()
}