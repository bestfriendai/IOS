//
//  SignUpView.swift
//  StreamyyyApp
//
//  Real authentication sign up view
//

import SwiftUI

struct SignUpView: View {
    @Binding var isPresented: Bool
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var clerkManager = ClerkManager.shared
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingPassword = false
    @State private var showingConfirmPassword = false
    @State private var agreeToTerms = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.cyan)
                            
                            Text("Create Account")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Join StreamHub and start your streaming journey")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Sign Up Form
                        VStack(spacing: 20) {
                            // Name Fields
                            HStack(spacing: 12) {
                                // First Name
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("First Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    TextField("John", text: $firstName)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .autocapitalization(.words)
                                }
                                
                                // Last Name
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    TextField("Doe", text: $lastName)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .autocapitalization(.words)
                                }
                            }
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 20)
                                    
                                    TextField("Enter your email", text: $email)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .foregroundColor(.white)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .keyboardType(.emailAddress)
                                    
                                    if !email.isEmpty {
                                        Image(systemName: isValidEmail ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(isValidEmail ? .green : .red)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    email.isEmpty ? Color.white.opacity(0.2) :
                                                    isValidEmail ? Color.green.opacity(0.5) : Color.red.opacity(0.5),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 20)
                                    
                                    Group {
                                        if showingPassword {
                                            TextField("Create a password", text: $password)
                                        } else {
                                            SecureField("Create a password", text: $password)
                                        }
                                    }
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(.white)
                                    
                                    Button(action: {
                                        showingPassword.toggle()
                                    }) {
                                        Image(systemName: showingPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    password.isEmpty ? Color.white.opacity(0.2) :
                                                    isPasswordValid ? Color.green.opacity(0.5) : Color.red.opacity(0.5),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                
                                // Password Requirements
                                if !password.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        PasswordRequirement(text: "At least 6 characters", isValid: password.count >= 6)
                                        PasswordRequirement(text: "Contains a number", isValid: password.rangeOfCharacter(from: .decimalDigits) != nil)
                                        PasswordRequirement(text: "Contains a letter", isValid: password.rangeOfCharacter(from: .letters) != nil)
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                            
                            // Confirm Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 20)
                                    
                                    Group {
                                        if showingConfirmPassword {
                                            TextField("Confirm your password", text: $confirmPassword)
                                        } else {
                                            SecureField("Confirm your password", text: $confirmPassword)
                                        }
                                    }
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(.white)
                                    
                                    Button(action: {
                                        showingConfirmPassword.toggle()
                                    }) {
                                        Image(systemName: showingConfirmPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    confirmPassword.isEmpty ? Color.white.opacity(0.2) :
                                                    passwordsMatch ? Color.green.opacity(0.5) : Color.red.opacity(0.5),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                
                                if !confirmPassword.isEmpty && !passwordsMatch {
                                    Text("Passwords do not match")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.leading, 8)
                                }
                            }
                            
                            // Terms and Conditions
                            HStack(alignment: .top, spacing: 12) {
                                Button(action: {
                                    agreeToTerms.toggle()
                                }) {
                                    Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(agreeToTerms ? .cyan : .white.opacity(0.6))
                                        .font(.title3)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("I agree to the Terms of Service and Privacy Policy")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    HStack(spacing: 16) {
                                        Link("Terms of Service", destination: URL(string: Config.URLs.termsOfService)!)
                                            .font(.caption)
                                            .foregroundColor(.cyan)
                                        
                                        Link("Privacy Policy", destination: URL(string: Config.URLs.privacyPolicy)!)
                                            .font(.caption)
                                            .foregroundColor(.cyan)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        
                        // Sign Up Button
                        VStack(spacing: 16) {
                            Button(action: signUp) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isLoading ? "Creating Account..." : "Create Account")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.purple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading || !isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.6)
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                                
                                Text("or")"
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                            }
                            
                            // Social Sign Up
                            VStack(spacing: 12) {
                                SocialSignInButton(
                                    title: "Continue with Apple",
                                    icon: "apple.logo",
                                    backgroundColor: .black,
                                    action: signUpWithApple
                                )
                                
                                SocialSignInButton(
                                    title: "Continue with Google",
                                    icon: "globe",
                                    backgroundColor: .blue,
                                    action: signUpWithGoogle
                                )
                            }
                        }
                        
                        // Sign In Link
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.white.opacity(0.7))
                            
                            Button("Sign In") {
                                isPresented = false
                                // Open sign in (handled by parent)
                            }
                            .foregroundColor(.cyan)
                            .fontWeight(.semibold)
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button("Close") {
                    isPresented = false
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .padding()
            }
        }
        .alert("Error", isPresented: .constant(!showingError.isEmpty)) {
            Button("OK") {
                showingError = ""
            }
        } message: {
            Text(showingError)
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
    
    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }
    
    private var isPasswordValid: Bool {
        password.count >= 6 &&
        password.rangeOfCharacter(from: .decimalDigits) != nil &&
        password.rangeOfCharacter(from: .letters) != nil
    }
    
    private var passwordsMatch: Bool {
        password == confirmPassword && !password.isEmpty
    }
    
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        isValidEmail &&
        isPasswordValid &&
        passwordsMatch &&
        agreeToTerms
    }
    
    private func signUp() {
        guard isFormValid else { return }
        
        isLoading = true
        
        Task {
            do {
                try await clerkManager.signUp(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName
                )
                await MainActor.run {
                    isPresented = false
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    showingError = clerkManager.handleError(error)
                    isLoading = false
                }
            }
        }
    }
    
    private func signUpWithApple() {
        isLoading = true
        
        Task {
            do {
                try await clerkManager.signInWithApple()
                await MainActor.run {
                    isPresented = false
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    showingError = clerkManager.handleError(error)
                    isLoading = false
                }
            }
        }
    }
    
    private func signUpWithGoogle() {
        isLoading = true
        
        Task {
            do {
                try await clerkManager.signInWithGoogle()
                await MainActor.run {
                    isPresented = false
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    showingError = clerkManager.handleError(error)
                    isLoading = false
                }
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
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

struct PasswordRequirement: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : .white.opacity(0.4))
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .green : .white.opacity(0.6))
        }
    }
}

#Preview {
    SignUpView(isPresented: .constant(true))
}"