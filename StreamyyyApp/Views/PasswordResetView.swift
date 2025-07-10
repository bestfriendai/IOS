//
//  PasswordResetView.swift
//  StreamyyyApp
//
//  Complete password reset flow with email verification
//

import SwiftUI
import ClerkSDK

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var clerkManager: ClerkManager
    @State private var currentStep: ResetStep = .requestReset
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
    enum ResetStep {
        case requestReset
        case verifyCode
        case setNewPassword
        case completed
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        // Progress indicator
                        ProgressIndicator(currentStep: currentStep)
                        
                        // Icon and title
                        Group {
                            switch currentStep {
                            case .requestReset:
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.purple)
                                Text("Reset Password")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Enter your email address and we'll send you a verification code")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                            case .verifyCode:
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text("Verify Code")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Enter the verification code sent to \(email)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                            case .setNewPassword:
                                Image(systemName: "lock.rotation")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                                Text("New Password")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Create a strong password for your account")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                            case .completed:
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.green)
                                Text("Success!")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Your password has been reset successfully")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .animation(.easeInOut(duration: 0.5), value: currentStep)
                    }
                    .padding(.top, 40)
                    
                    // Form Content
                    VStack(spacing: 24) {
                        switch currentStep {
                        case .requestReset:
                            EmailInputView(email: $email, isLoading: isLoading)
                            
                        case .verifyCode:
                            VerificationCodeInputView(code: $code, isLoading: isLoading)
                            
                        case .setNewPassword:
                            NewPasswordInputView(
                                newPassword: $newPassword,
                                confirmPassword: $confirmPassword,
                                isLoading: isLoading
                            )
                            
                        case .completed:
                            CompletedView()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        switch currentStep {
                        case .requestReset:
                            ActionButton(
                                title: "Send Reset Code",
                                isLoading: isLoading,
                                isEnabled: !email.isEmpty && isValidEmail(email)
                            ) {
                                sendResetCode()
                            }
                            .accessibilityLabel("Send Reset Code")
                            .accessibilityHint("Send password reset code to your email")
                            
                        case .verifyCode:
                            ActionButton(
                                title: "Verify Code",
                                isLoading: isLoading,
                                isEnabled: code.count == 6
                            ) {
                                verifyCode()
                            }
                            .accessibilityLabel("Verify Code")
                            .accessibilityHint("Verify the code sent to your email")
                            
                            Button("Resend Code") {
                                sendResetCode()
                            }
                            .font(.subheadline)
                            .foregroundColor(.purple)
                            .disabled(isLoading)
                            
                        case .setNewPassword:
                            ActionButton(
                                title: "Reset Password",
                                isLoading: isLoading,
                                isEnabled: isNewPasswordValid
                            ) {
                                resetPassword()
                            }
                            .accessibilityLabel("Reset Password")
                            .accessibilityHint("Set your new password")
                            
                        case .completed:
                            ActionButton(
                                title: "Sign In",
                                isLoading: false,
                                isEnabled: true
                            ) {
                                dismiss()
                            }
                            .accessibilityLabel("Sign In")
                            .accessibilityHint("Return to sign in with your new password")
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Password Reset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text("Password reset code has been sent to your email")
            }
        }
    }
    
    // MARK: - Validation
    
    private var isNewPasswordValid: Bool {
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8 &&
        containsRequiredCharacters(newPassword)
    }
    
    private func containsRequiredCharacters(_ password: String) -> Bool {
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialCharacters = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        
        return hasUppercase && hasLowercase && hasNumbers && hasSpecialCharacters
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Actions
    
    private func sendResetCode() {
        isLoading = true
        
        Task {
            do {
                try await clerkManager.resetPassword(email: email)
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        currentStep = .verifyCode
                    }
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = clerkManager.handleError(error)
                    showingError = true
                }
            }
        }
    }
    
    private func verifyCode() {
        isLoading = true
        
        Task {
            do {
                // Verify the code with Clerk
                // This would need to be implemented in ClerkManager
                try await clerkManager.verifyResetCode(code: code)
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        currentStep = .setNewPassword
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = clerkManager.handleError(error)
                    showingError = true
                }
            }
        }
    }
    
    private func resetPassword() {
        isLoading = true
        
        Task {
            do {
                // Complete password reset with Clerk
                // This would need to be implemented in ClerkManager
                try await clerkManager.completePasswordReset(newPassword: newPassword)
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        currentStep = .completed
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = clerkManager.handleError(error)
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let currentStep: PasswordResetView.ResetStep
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                Circle()
                    .fill(stepColor(for: step))
                    .frame(width: 12, height: 12)
                    .scaleEffect(currentStep == step ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(stepColor(for: step).opacity(0.3))
                        .frame(width: 20, height: 2)
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    private var steps: [PasswordResetView.ResetStep] {
        [.requestReset, .verifyCode, .setNewPassword, .completed]
    }
    
    private func stepColor(for step: PasswordResetView.ResetStep) -> Color {
        let currentIndex = steps.firstIndex(of: currentStep) ?? 0
        let stepIndex = steps.firstIndex(of: step) ?? 0
        
        if stepIndex <= currentIndex {
            return .purple
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Input Views

struct EmailInputView: View {
    @Binding var email: String
    let isLoading: Bool
    
    var body: some View {
        CustomTextField(
            title: "Email Address",
            text: $email,
            icon: "envelope.fill",
            keyboardType: .emailAddress
        )
        .accessibilityLabel("Email Address")
        .accessibilityHint("Enter your email address to receive reset code")
        .disabled(isLoading)
    }
}

struct VerificationCodeInputView: View {
    @Binding var code: String
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verification Code")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: "number.circle.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                TextField("Enter 6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .onChange(of: code) { newValue in
                        if newValue.count > 6 {
                            code = String(newValue.prefix(6))
                        }
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel("Verification Code")
        .accessibilityHint("Enter the 6-digit code sent to your email")
        .disabled(isLoading)
    }
}

struct NewPasswordInputView: View {
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            CustomSecureField(
                title: "New Password",
                text: $newPassword,
                icon: "lock.fill"
            )
            .accessibilityLabel("New Password")
            .accessibilityHint("Enter your new password")
            .disabled(isLoading)
            
            CustomSecureField(
                title: "Confirm Password",
                text: $confirmPassword,
                icon: "lock.fill"
            )
            .accessibilityLabel("Confirm Password")
            .accessibilityHint("Re-enter your new password to confirm")
            .disabled(isLoading)
            
            // Password requirements
            PasswordRequirements(password: newPassword)
        }
    }
}

struct PasswordRequirements: View {
    let password: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password Requirements:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                RequirementRow(
                    text: "At least 8 characters",
                    isValid: password.count >= 8
                )
                RequirementRow(
                    text: "Contains uppercase letter",
                    isValid: password.range(of: "[A-Z]", options: .regularExpression) != nil
                )
                RequirementRow(
                    text: "Contains lowercase letter",
                    isValid: password.range(of: "[a-z]", options: .regularExpression) != nil
                )
                RequirementRow(
                    text: "Contains number",
                    isValid: password.range(of: "[0-9]", options: .regularExpression) != nil
                )
                RequirementRow(
                    text: "Contains special character",
                    isValid: password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RequirementRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : .gray)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .primary : .secondary)
        }
    }
}

struct CompletedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("You can now sign in with your new password")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Password successfully reset")
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.blue)
                    Text("Account security updated")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isLoading ? "Please wait..." : title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

#Preview {
    PasswordResetView()
        .environmentObject(ClerkManager())
}