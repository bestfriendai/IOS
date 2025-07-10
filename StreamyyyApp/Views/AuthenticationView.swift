//
//  AuthenticationView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI
import ClerkSDK

struct AuthenticationView: View {
    @EnvironmentObject var clerkManager: ClerkManager
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingForgotPassword = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Header
                    VStack(spacing: 24) {
                        // Logo
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                            
                            Text("S")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Welcome to Streamyyy")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(isSignUp ? "Create your account to get started" : "Sign in to continue")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        if isSignUp {
                            CustomTextField(
                                title: "Full Name",
                                text: $fullName,
                                icon: "person.fill"
                            )
                            .accessibilityLabel("Full Name")
                            .accessibilityHint("Enter your full name for account creation")
                        }
                        
                        CustomTextField(
                            title: "Email",
                            text: $email,
                            icon: "envelope.fill",
                            keyboardType: .emailAddress
                        )
                        .accessibilityLabel("Email Address")
                        .accessibilityHint("Enter your email address")
                        
                        CustomSecureField(
                            title: "Password",
                            text: $password,
                            icon: "lock.fill"
                        )
                        .accessibilityLabel("Password")
                        .accessibilityHint("Enter your password")
                        
                        if isSignUp {
                            CustomSecureField(
                                title: "Confirm Password",
                                text: $confirmPassword,
                                icon: "lock.fill"
                            )
                            .accessibilityLabel("Confirm Password")
                            .accessibilityHint("Re-enter your password to confirm")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Forgot Password (Sign In only)
                    if !isSignUp {
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.purple)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Action Button
                    VStack(spacing: 16) {
                        Button(action: authenticate) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isLoading ? "Please wait..." : (isSignUp ? "Create Account" : "Sign In"))
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
                        .disabled(isLoading || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        .accessibilityLabel(isSignUp ? "Create Account" : "Sign In")
                        .accessibilityHint(isSignUp ? "Create your new account" : "Sign in to your existing account")
                        
                        // Social Sign In
                        if !isSignUp {
                            OAuthButtonsView(
                                onSuccess: {
                                    // Authentication successful, handled by environment
                                },
                                onError: { error in
                                    errorMessage = error
                                    showingError = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Toggle Sign In/Sign Up
                    HStack {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(isSignUp ? "Sign In" : "Sign Up") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUp.toggle()
                                clearForm()
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    }
                    
                    // Terms and Privacy (Sign Up only)
                    if isSignUp {
                        VStack(spacing: 8) {
                            Text("By creating an account, you agree to our")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Button("Terms of Service") {
                                    // Open terms
                                }
                                .font(.caption)
                                .foregroundColor(.purple)
                                
                                Text("and")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("Privacy Policy") {
                                    // Open privacy policy
                                }
                                .font(.caption)
                                .foregroundColor(.purple)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    }
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.purple.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingForgotPassword) {
            PasswordResetView()
        }
    }
    
    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty &&
                   !password.isEmpty &&
                   !confirmPassword.isEmpty &&
                   !fullName.isEmpty &&
                   password == confirmPassword &&
                   isValidEmail(email) &&
                   password.count >= 6
        } else {
            return !email.isEmpty &&
                   !password.isEmpty &&
                   isValidEmail(email)
        }
    }
    
    private func authenticate() {
        isLoading = true
        
        Task {
            do {
                if isSignUp {
                    let names = fullName.components(separatedBy: " ")
                    let firstName = names.first ?? ""
                    let lastName = names.dropFirst().joined(separator: " ")
                    
                    try await clerkManager.signUp(
                        email: email,
                        password: password,
                        firstName: firstName,
                        lastName: lastName
                    )
                } else {
                    try await clerkManager.signIn(email: email, password: password)
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = clerkManager.handleError(error)
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
    
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        fullName = ""
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                TextField(title, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Custom Secure Field
struct CustomSecureField: View {
    let title: String
    @Binding var text: String
    let icon: String
    @State private var isSecure = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
                
                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .font(.title3)
                        .foregroundColor(.gray)
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
    }
}



#Preview {
    AuthenticationView()
        .environmentObject(ClerkManager())
}