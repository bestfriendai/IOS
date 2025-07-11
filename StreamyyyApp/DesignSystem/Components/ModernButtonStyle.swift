//
//  ModernButtonStyle.swift
//  StreamyyyApp
//
//  Modern button style component for consistent styling across all app pages
//

import SwiftUI

// MARK: - Modern Button Style
struct ModernButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    let size: ButtonSize
    
    init(variant: ButtonVariant = .primary, size: ButtonSize = .medium) {
        self.variant = variant
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(variant.foregroundColor(isPressed: configuration.isPressed))
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.minHeight)
            .background(variant.backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(size.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(variant.borderColor, lineWidth: variant.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Variant
enum ButtonVariant {
    case primary
    case secondary
    case tertiary
    case destructive
    case ghost
    case outline
    case success
    case warning
    
    func backgroundColor(isPressed: Bool) -> some View {
        Group {
            switch self {
            case .primary:
                LinearGradient(
                    colors: isPressed ? 
                        [Color.purple.opacity(0.8), Color.cyan.opacity(0.8)] :
                        [Color.purple, Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .secondary:
                Color.white.opacity(isPressed ? 0.15 : 0.1)
            case .tertiary:
                Color.clear
            case .destructive:
                Color.red.opacity(isPressed ? 0.8 : 1.0)
            case .ghost:
                Color.clear
            case .outline:
                Color.clear
            case .success:
                Color.green.opacity(isPressed ? 0.8 : 1.0)
            case .warning:
                Color.orange.opacity(isPressed ? 0.8 : 1.0)
            }
        }
    }
    
    func foregroundColor(isPressed: Bool) -> Color {
        switch self {
        case .primary:
            return .white
        case .secondary:
            return .white
        case .tertiary:
            return isPressed ? .white.opacity(0.7) : .white
        case .destructive:
            return .white
        case .ghost:
            return isPressed ? .white.opacity(0.7) : .white.opacity(0.9)
        case .outline:
            return isPressed ? .white.opacity(0.7) : .white
        case .success:
            return .white
        case .warning:
            return .white
        }
    }
    
    var borderColor: Color {
        switch self {
        case .primary, .secondary, .destructive, .success, .warning:
            return .clear
        case .tertiary:
            return .white.opacity(0.3)
        case .ghost:
            return .clear
        case .outline:
            return .white.opacity(0.5)
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .primary, .secondary, .destructive, .ghost, .success, .warning:
            return 0
        case .tertiary, .outline:
            return 1
        }
    }
}

// MARK: - Button Size
enum ButtonSize {
    case small
    case medium
    case large
    case extraLarge
    
    var font: Font {
        switch self {
        case .small:
            return .caption
        case .medium:
            return .subheadline
        case .large:
            return .headline
        case .extraLarge:
            return .title3
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 12
        case .medium:
            return 16
        case .large:
            return 20
        case .extraLarge:
            return 24
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return 6
        case .medium:
            return 10
        case .large:
            return 14
        case .extraLarge:
            return 18
        }
    }
    
    var minHeight: CGFloat {
        switch self {
        case .small:
            return 32
        case .medium:
            return 44
        case .large:
            return 56
        case .extraLarge:
            return 64
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 12
        case .large:
            return 16
        case .extraLarge:
            return 20
        }
    }
}

// MARK: - Icon Button Style
struct IconButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    let size: IconButtonSize
    
    init(variant: ButtonVariant = .ghost, size: IconButtonSize = .medium) {
        self.variant = variant
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.iconSize, weight: .medium))
            .foregroundColor(variant.foregroundColor(isPressed: configuration.isPressed))
            .frame(width: size.frameSize, height: size.frameSize)
            .background(variant.backgroundColor(isPressed: configuration.isPressed))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(variant.borderColor, lineWidth: variant.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

enum IconButtonSize {
    case small
    case medium
    case large
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 24
        }
    }
    
    var frameSize: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 56
        }
    }
}

// MARK: - StreamyyyIconButton Component
struct StreamyyyIconButton: View {
    let icon: String
    let style: ButtonVariant
    let size: IconButtonSize
    let action: () -> Void
    
    init(
        icon: String,
        style: ButtonVariant = .ghost,
        size: IconButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(IconButtonStyle(variant: style, size: size))
    }
}

// MARK: - View Extensions for Easy Usage
extension View {
    func modernButtonStyle(
        variant: ButtonVariant = .primary,
        size: ButtonSize = .medium
    ) -> some View {
        self.buttonStyle(ModernButtonStyle(variant: variant, size: size))
    }
    
    func iconButtonStyle(
        variant: ButtonVariant = .ghost,
        size: IconButtonSize = .medium
    ) -> some View {
        self.buttonStyle(IconButtonStyle(variant: variant, size: size))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Group {
            Button("Primary") { }
                .modernButtonStyle(variant: .primary)
            
            Button("Secondary") { }
                .modernButtonStyle(variant: .secondary)
            
            Button("Tertiary") { }
                .modernButtonStyle(variant: .tertiary)
            
            Button("Destructive") { }
                .modernButtonStyle(variant: .destructive)
            
            Button("Ghost") { }
                .modernButtonStyle(variant: .ghost)
            
            Button("Outline") { }
                .modernButtonStyle(variant: .outline)
        }
        
        HStack(spacing: 16) {
            StreamyyyIconButton(icon: "heart.fill", style: .primary) { }
            StreamyyyIconButton(icon: "star.fill", style: .secondary) { }
            StreamyyyIconButton(icon: "plus", style: .ghost) { }
            StreamyyyIconButton(icon: "xmark", style: .destructive) { }
        }
    }
    .padding()
    .background(Color.black)
}