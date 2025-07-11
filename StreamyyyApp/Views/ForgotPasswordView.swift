//
//  ForgotPasswordView.swift
//  StreamyyyApp
//
//  Password reset functionality
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var clerkManager = ClerkManager.shared
    
    @State private var email = ""
    @State private var resetCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var currentStep: ResetStep = .email
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingSuccess = false
    
    enum ResetStep {
        case email, verification, newPassword, success
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundColor(.cyan)
                        
                        Text("Reset Password")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(stepDescription)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Step Content
                    Group {
                        switch currentStep {
                        case .email:
                            emailStep
                        case .verification:
                            verificationStep
                        case .newPassword:
                            newPasswordStep
                        case .success:
                            successStep
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button("Close") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .padding()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var stepDescription: String {
        switch currentStep {
        case .email:
            return "Enter your email address and we'll send you a reset code"
        case .verification:
            return "Enter the 6-digit code we sent to your email"
        case .newPassword:
            return "Create a new secure password for your account"
        case .success:
            return "Your password has been successfully reset"
        }
    }
    
    // MARK: - Email Step
    private var emailStep: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(ResetTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            Button(action: sendResetCode) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Sending..." : "Send Reset Code")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.cyan, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading || !isValidEmail)
            .opacity(isValidEmail ? 1.0 : 0.6)
        }
    }
    
    // MARK: - Verification Step
    private var verificationStep: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Code")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                TextField("000000", text: $resetCode)
                    .textFieldStyle(ResetTextFieldStyle())
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title3)
                    .onChange(of: resetCode) { _, newValue in
                        // Limit to 6 digits
                        if newValue.count > 6 {
                            resetCode = String(newValue.prefix(6))
                        }
                    }
                
                Text("Code sent to \\(email)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(spacing: 12) {
                Button(action: verifyResetCode) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Verifying..." : "Verify Code")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading || resetCode.count != 6)
                .opacity(resetCode.count == 6 ? 1.0 : 0.6)
                
                Button("Didn't receive code? Resend") {
                    sendResetCode()
                }
                .font(.subheadline)
                .foregroundColor(.cyan)
            }
        }
    }
    
    // MARK: - New Password Step
    private var newPasswordStep: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Password")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    SecureField("Enter new password", text: $newPassword)
                        .textFieldStyle(ResetTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    SecureField("Confirm new password", text: $confirmPassword)
                        .textFieldStyle(ResetTextFieldStyle())
                }
                
                // Password Requirements
                if !newPassword.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        PasswordRequirement(text: "At least 6 characters", isValid: newPassword.count >= 6)
                        PasswordRequirement(text: "Contains a number", isValid: newPassword.rangeOfCharacter(from: .decimalDigits) != nil)
                        PasswordRequirement(text: "Passwords match", isValid: newPassword == confirmPassword && !newPassword.isEmpty)
                    }
                }
            }
            
            Button(action: resetPassword) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Resetting..." : "Reset Password")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.cyan, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading || !isPasswordValid)
            .opacity(isPasswordValid ? 1.0 : 0.6)
        }
    }
    
    // MARK: - Success Step
    private var successStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Password Reset Complete")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("You can now sign in with your new password")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Button("Continue to Sign In") {
                dismiss()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.green, Color.green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }
    
    private var isPasswordValid: Bool {
        newPassword.count >= 6 &&
        newPassword.rangeOfCharacter(from: .decimalDigits) != nil &&
        newPassword == confirmPassword &&
        !newPassword.isEmpty
    }
    
    // MARK: - Methods
    private func sendResetCode() {
        guard isValidEmail else { return }
        
        isLoading = true
        
        Task {
            do {
                try await clerkManager.resetPassword(email: email)
                await MainActor.run {
                    currentStep = .verification
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send reset code. Please check your email address."
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func verifyResetCode() {
        guard resetCode.count == 6 else { return }
        
        isLoading = true
        
        Task {
            do {
                try await clerkManager.verifyResetCode(code: resetCode)
                await MainActor.run {
                    currentStep = .newPassword
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid or expired code. Please try again."
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func resetPassword() {
        guard isPasswordValid else { return }
        
        isLoading = true
        
        Task {
            do {
                try await clerkManager.completePasswordReset(newPassword: newPassword)
                await MainActor.run {
                    currentStep = .success
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to reset password. Please try again."
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

struct ResetTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
    }
}

#Preview {
    ForgotPasswordView()
}"