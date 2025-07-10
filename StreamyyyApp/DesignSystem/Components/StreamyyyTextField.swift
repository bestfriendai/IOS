//
//  StreamyyyTextField.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Modern text field component with validation and accessibility
//

import SwiftUI

// MARK: - StreamyyyTextField
struct StreamyyyTextField: View {
    let placeholder: String
    @Binding var text: String
    let style: StreamyyyTextFieldStyle
    let validation: StreamyyyTextFieldValidation?
    let icon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let autocapitalization: UITextAutocapitalizationType
    let onCommit: (() -> Void)?
    
    @State private var isFocused = false
    @State private var isValid = true
    @State private var validationMessage = ""
    @State private var showPassword = false
    @FocusState private var fieldIsFocused: Bool
    
    init(
        placeholder: String,
        text: Binding<String>,
        style: StreamyyyTextFieldStyle = .default,
        validation: StreamyyyTextFieldValidation? = nil,
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: UITextAutocapitalizationType = .sentences,
        onCommit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
        self.validation = validation
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.onCommit = onCommit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
            HStack(spacing: StreamyyySpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: StreamyyySpacing.iconSizeSM, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: StreamyyySpacing.iconSizeSM)
                }
                
                Group {
                    if isSecure && !showPassword {
                        SecureField(placeholder, text: $text)
                            .focused($fieldIsFocused)
                    } else {
                        TextField(placeholder, text: $text)
                            .focused($fieldIsFocused)
                    }
                }
                .font(StreamyyyTypography.bodyMedium)
                .foregroundColor(textColor)
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization)
                .disableAutocorrection(false)
                .onSubmit {
                    validateInput()
                    onCommit?()
                }
                .onChange(of: text) { _ in
                    if validation != nil {
                        validateInput()
                    }
                }
                .onChange(of: fieldIsFocused) { focused in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFocused = focused
                    }
                    
                    if !focused && validation != nil {
                        validateInput()
                    }
                }
                
                if isSecure {
                    Button(action: {
                        showPassword.toggle()
                        StreamyyyDesignSystem.hapticFeedback(.light)
                    }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: StreamyyySpacing.iconSizeSM, weight: .medium))
                            .foregroundColor(StreamyyyColors.textTertiary)
                    }
                }
            }
            .padding(fieldPadding)
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
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.2), value: isValid)
            
            if !isValid && !validationMessage.isEmpty {
                Text(validationMessage)
                    .captionMedium()
                    .foregroundColor(StreamyyyColors.error)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(placeholder)
        .accessibilityHint(isSecure ? "Secure text field" : "Text field")
        .accessibilityValue(text)
    }
    
    // MARK: - Validation
    private func validateInput() {
        guard let validation = validation else {
            isValid = true
            validationMessage = ""
            return
        }
        
        let result = validation.validate(text)
        withAnimation(.easeInOut(duration: 0.2)) {
            isValid = result.isValid
            validationMessage = result.message
        }
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        switch style {
        case .default:
            return StreamyyyColors.surface
        case .outlined:
            return StreamyyyColors.background
        case .filled:
            return StreamyyyColors.surfaceSecondary
        case .underlined:
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if !isValid {
            return StreamyyyColors.error
        }
        
        if isFocused {
            return StreamyyyColors.primary
        }
        
        switch style {
        case .default, .outlined:
            return StreamyyyColors.border
        case .filled:
            return Color.clear
        case .underlined:
            return StreamyyyColors.border
        }
    }
    
    private var borderWidth: CGFloat {
        if !isValid || isFocused {
            return StreamyyySpacing.borderWidthMedium
        }
        
        switch style {
        case .default, .outlined:
            return StreamyyySpacing.borderWidthRegular
        case .filled:
            return 0
        case .underlined:
            return StreamyyySpacing.borderWidthRegular
        }
    }
    
    private var shadowColor: Color {
        if !isValid {
            return StreamyyyColors.error.opacity(0.1)
        }
        
        if isFocused {
            return StreamyyyColors.primary.opacity(0.1)
        }
        
        return StreamyyyColors.overlay.opacity(0.05)
    }
    
    private var shadowRadius: CGFloat {
        if !isValid || isFocused {
            return StreamyyySpacing.shadowRadiusSM
        }
        
        return StreamyyySpacing.shadowRadiusXS
    }
    
    private var textColor: Color {
        return StreamyyyColors.textPrimary
    }
    
    private var iconColor: Color {
        if !isValid {
            return StreamyyyColors.error
        }
        
        if isFocused {
            return StreamyyyColors.primary
        }
        
        return StreamyyyColors.textTertiary
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .default, .outlined, .filled:
            return StreamyyySpacing.cornerRadiusSM
        case .underlined:
            return 0
        }
    }
    
    private var fieldPadding: CGFloat {
        switch style {
        case .default, .outlined, .filled:
            return StreamyyySpacing.fieldPadding
        case .underlined:
            return StreamyyySpacing.xs
        }
    }
}

// MARK: - StreamyyyTextFieldStyle
enum StreamyyyTextFieldStyle {
    case `default`
    case outlined
    case filled
    case underlined
}

// MARK: - StreamyyyTextFieldValidation
struct StreamyyyTextFieldValidation {
    let validate: (String) -> ValidationResult
    
    struct ValidationResult {
        let isValid: Bool
        let message: String
    }
    
    // MARK: - Common Validations
    static let email = StreamyyyTextFieldValidation { text in
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        let isValid = emailPredicate.evaluate(with: text)
        return ValidationResult(
            isValid: isValid,
            message: isValid ? "" : "Please enter a valid email address"
        )
    }
    
    static let password = StreamyyyTextFieldValidation { text in
        let isValid = text.count >= 8
        return ValidationResult(
            isValid: isValid,
            message: isValid ? "" : "Password must be at least 8 characters"
        )
    }
    
    static let required = StreamyyyTextFieldValidation { text in
        let isValid = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return ValidationResult(
            isValid: isValid,
            message: isValid ? "" : "This field is required"
        )
    }
    
    static let url = StreamyyyTextFieldValidation { text in
        guard let url = URL(string: text) else {
            return ValidationResult(isValid: false, message: "Please enter a valid URL")
        }
        
        let isValid = url.scheme != nil && url.host != nil
        return ValidationResult(
            isValid: isValid,
            message: isValid ? "" : "Please enter a valid URL"
        )
    }
    
    static func minLength(_ length: Int) -> StreamyyyTextFieldValidation {
        return StreamyyyTextFieldValidation { text in
            let isValid = text.count >= length
            return ValidationResult(
                isValid: isValid,
                message: isValid ? "" : "Must be at least \(length) characters"
            )
        }
    }
    
    static func maxLength(_ length: Int) -> StreamyyyTextFieldValidation {
        return StreamyyyTextFieldValidation { text in
            let isValid = text.count <= length
            return ValidationResult(
                isValid: isValid,
                message: isValid ? "" : "Must be no more than \(length) characters"
            )
        }
    }
}

// MARK: - StreamyyySearchField
struct StreamyyySearchField: View {
    let placeholder: String
    @Binding var text: String
    let onSearchTap: (() -> Void)?
    let onClearTap: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    init(
        placeholder: String = "Search...",
        text: Binding<String>,
        onSearchTap: (() -> Void)? = nil,
        onClearTap: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.onSearchTap = onSearchTap
        self.onClearTap = onClearTap
    }
    
    var body: some View {
        HStack(spacing: StreamyyySpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: StreamyyySpacing.iconSizeSM, weight: .medium))
                .foregroundColor(StreamyyyColors.textTertiary)
            
            TextField(placeholder, text: $text)
                .font(StreamyyyTypography.bodyMedium)
                .foregroundColor(StreamyyyColors.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    onSearchTap?()
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClearTap?()
                    StreamyyyDesignSystem.hapticFeedback(.light)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: StreamyyySpacing.iconSizeSM, weight: .medium))
                        .foregroundColor(StreamyyyColors.textTertiary)
                }
            }
        }
        .padding(StreamyyySpacing.fieldPadding)
        .background(StreamyyyColors.surface)
        .cornerRadius(StreamyyySpacing.cornerRadiusSM)
        .overlay(
            RoundedRectangle(cornerRadius: StreamyyySpacing.cornerRadiusSM)
                .stroke(isFocused ? StreamyyyColors.primary : StreamyyyColors.border, lineWidth: isFocused ? 2 : 1)
        )
        .shadow(
            color: isFocused ? StreamyyyColors.primary.opacity(0.1) : StreamyyyColors.overlay.opacity(0.05),
            radius: isFocused ? StreamyyySpacing.shadowRadiusSM : StreamyyySpacing.shadowRadiusXS,
            x: 0,
            y: 1
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .accessibilityLabel("Search field")
        .accessibilityHint("Enter search terms")
        .accessibilityValue(text)
    }
}

// MARK: - StreamyyyTextArea
struct StreamyyyTextArea: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let style: StreamyyyTextFieldStyle
    
    @FocusState private var isFocused: Bool
    
    init(
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 100,
        maxHeight: CGFloat = 200,
        style: StreamyyyTextFieldStyle = .default
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.style = style
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(StreamyyyTypography.bodyMedium)
                        .foregroundColor(StreamyyyColors.textTertiary)
                        .padding(.top, StreamyyySpacing.xs)
                        .padding(.leading, StreamyyySpacing.xs)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $text)
                    .font(StreamyyyTypography.bodyMedium)
                    .foregroundColor(StreamyyyColors.textPrimary)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .padding(StreamyyySpacing.fieldPadding)
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
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .accessibilityLabel(placeholder)
        .accessibilityHint("Text area")
        .accessibilityValue(text)
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        switch style {
        case .default:
            return StreamyyyColors.surface
        case .outlined:
            return StreamyyyColors.background
        case .filled:
            return StreamyyyColors.surfaceSecondary
        case .underlined:
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isFocused {
            return StreamyyyColors.primary
        }
        
        switch style {
        case .default, .outlined:
            return StreamyyyColors.border
        case .filled:
            return Color.clear
        case .underlined:
            return StreamyyyColors.border
        }
    }
    
    private var borderWidth: CGFloat {
        if isFocused {
            return StreamyyySpacing.borderWidthMedium
        }
        
        switch style {
        case .default, .outlined:
            return StreamyyySpacing.borderWidthRegular
        case .filled:
            return 0
        case .underlined:
            return StreamyyySpacing.borderWidthRegular
        }
    }
    
    private var shadowColor: Color {
        if isFocused {
            return StreamyyyColors.primary.opacity(0.1)
        }
        
        return StreamyyyColors.overlay.opacity(0.05)
    }
    
    private var shadowRadius: CGFloat {
        if isFocused {
            return StreamyyySpacing.shadowRadiusSM
        }
        
        return StreamyyySpacing.shadowRadiusXS
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .default, .outlined, .filled:
            return StreamyyySpacing.cornerRadiusSM
        case .underlined:
            return 0
        }
    }
}

// MARK: - Text Field Previews
struct StreamyyyTextFieldPreviews: View {
    @State private var text1 = ""
    @State private var text2 = ""
    @State private var text3 = ""
    @State private var text4 = ""
    @State private var text5 = ""
    @State private var searchText = ""
    @State private var textAreaText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: StreamyyySpacing.lg) {
                Text("Text Field Components")
                    .headlineLarge()
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Text Field Styles")
                        .titleMedium()
                    
                    StreamyyyTextField(
                        placeholder: "Default Style",
                        text: $text1,
                        style: .default
                    )
                    
                    StreamyyyTextField(
                        placeholder: "Outlined Style",
                        text: $text2,
                        style: .outlined
                    )
                    
                    StreamyyyTextField(
                        placeholder: "Filled Style",
                        text: $text3,
                        style: .filled
                    )
                    
                    StreamyyyTextField(
                        placeholder: "Underlined Style",
                        text: $text4,
                        style: .underlined
                    )
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Text Fields with Icons")
                        .titleMedium()
                    
                    StreamyyyTextField(
                        placeholder: "Email",
                        text: $text5,
                        validation: .email,
                        icon: "envelope",
                        keyboardType: .emailAddress,
                        autocapitalization: .none
                    )
                    
                    StreamyyyTextField(
                        placeholder: "Password",
                        text: $text1,
                        validation: .password,
                        icon: "lock",
                        isSecure: true
                    )
                    
                    StreamyyyTextField(
                        placeholder: "Search URL",
                        text: $text2,
                        validation: .url,
                        icon: "link",
                        keyboardType: .URL,
                        autocapitalization: .none
                    )
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Specialized Fields")
                        .titleMedium()
                    
                    StreamyyySearchField(
                        placeholder: "Search streams...",
                        text: $searchText,
                        onSearchTap: {
                            print("Search tapped")
                        },
                        onClearTap: {
                            print("Clear tapped")
                        }
                    )
                    
                    StreamyyyTextArea(
                        placeholder: "Enter your message...",
                        text: $textAreaText,
                        minHeight: 100,
                        maxHeight: 200
                    )
                }
            }
            .screenPadding()
        }
        .themedBackground()
    }
}

#Preview {
    StreamyyyTextFieldPreviews()
}