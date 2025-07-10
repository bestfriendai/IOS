//
//  StreamyyyFullDesignSystem.swift
//  StreamyyyApp
//
//  Complete design system including all components for build fix
//

import SwiftUI

// MARK: - StreamyyyButton
struct StreamyyyButton: View {
    let title: String
    let style: ButtonStyle
    let size: ButtonSize
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        title: String,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(size.font)
                        .fontWeight(.semibold)
                }
            }
            .frame(minWidth: size.minWidth, minHeight: size.height)
            .background(isDisabled ? style.disabledBackgroundColor : style.backgroundColor)
            .foregroundColor(isDisabled ? style.disabledForegroundColor : style.foregroundColor)
            .cornerRadius(size.cornerRadius)
        }
        .disabled(isDisabled || isLoading)
    }
}

extension StreamyyyButton {
    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
        case destructive
        case ghost
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return .purple
            case .secondary:
                return Color(.systemGray6)
            case .tertiary:
                return .clear
            case .destructive:
                return .red
            case .ghost:
                return .clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary:
                return .white
            case .secondary:
                return .primary
            case .tertiary:
                return .purple
            case .destructive:
                return .white
            case .ghost:
                return .purple
            }
        }
        
        var disabledBackgroundColor: Color {
            return Color(.systemGray4)
        }
        
        var disabledForegroundColor: Color {
            return Color(.systemGray2)
        }
    }
    
    enum ButtonSize {
        case small
        case medium
        case large
        
        var height: CGFloat {
            switch self {
            case .small:
                return 32
            case .medium:
                return 44
            case .large:
                return 56
            }
        }
        
        var minWidth: CGFloat {
            switch self {
            case .small:
                return 80
            case .medium:
                return 120
            case .large:
                return 160
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small:
                return 6
            case .medium:
                return 8
            case .large:
                return 12
            }
        }
        
        var font: Font {
            switch self {
            case .small:
                return .caption
            case .medium:
                return .body
            case .large:
                return .headline
            }
        }
    }
}

// MARK: - StreamyyyTextField
struct StreamyyyTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let style: TextFieldStyle
    let isSecure: Bool
    let isDisabled: Bool
    let errorMessage: String?
    
    init(
        title: String = "",
        placeholder: String,
        text: Binding<String>,
        style: TextFieldStyle = .default,
        isSecure: Bool = false,
        isDisabled: Bool = false,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.style = style
        self.isSecure = isSecure
        self.isDisabled = isDisabled
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.6 : 1.0)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

extension StreamyyyTextField {
    enum TextFieldStyle {
        case `default`
        case rounded
        case underlined
        
        var backgroundColor: Color {
            switch self {
            case .default:
                return Color(.systemGray6)
            case .rounded:
                return Color(.systemGray6)
            case .underlined:
                return .clear
            }
        }
        
        var borderColor: Color {
            switch self {
            case .default:
                return .clear
            case .rounded:
                return Color(.systemGray4)
            case .underlined:
                return Color(.systemGray4)
            }
        }
    }
}

// MARK: - StreamyyyTabView
struct StreamyyyTabView<Content: View>: View {
    let content: Content
    let streamyyyTheme: StreamyyyTheme
    
    init(streamyyyTheme: StreamyyyTheme = .default, @ViewBuilder content: () -> Content) {
        self.streamyyyTheme = streamyyyTheme
        self.content = content()
    }
    
    var body: some View {
        TabView {
            content
        }
        .accentColor(streamyyyTheme.primaryColor)
    }
}

// MARK: - StreamyyyTheme
struct StreamyyyTheme {
    let primaryColor: Color
    let secondaryColor: Color
    let backgroundColor: Color
    let surfaceColor: Color
    let textColor: Color
    let isDark: Bool
    
    static let `default` = StreamyyyTheme(
        primaryColor: .purple,
        secondaryColor: .blue,
        backgroundColor: Color(.systemBackground),
        surfaceColor: Color(.systemGray6),
        textColor: Color(.label),
        isDark: false
    )
    
    static let dark = StreamyyyTheme(
        primaryColor: .purple,
        secondaryColor: .blue,
        backgroundColor: Color(.systemBackground),
        surfaceColor: Color(.systemGray6),
        textColor: Color(.label),
        isDark: true
    )
}

// MARK: - Typography Extensions
extension Text {
    func displayLarge() -> some View {
        self.font(.largeTitle)
            .fontWeight(.bold)
    }
    
    func displayMedium() -> some View {
        self.font(.title)
            .fontWeight(.semibold)
    }
    
    func titleLarge() -> some View {
        self.font(.title2)
            .fontWeight(.semibold)
    }
    
    func titleMedium() -> some View {
        self.font(.headline)
            .fontWeight(.medium)
    }
    
    func bodyLarge() -> some View {
        self.font(.body)
    }
    
    func bodyMedium() -> some View {
        self.font(.callout)
    }
    
    func labelLarge() -> some View {
        self.font(.footnote)
            .fontWeight(.medium)
    }
    
    func labelMedium() -> some View {
        self.font(.caption)
            .fontWeight(.medium)
    }
}