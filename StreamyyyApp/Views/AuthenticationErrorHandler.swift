//
//  AuthenticationErrorHandler.swift
//  StreamyyyApp
//
//  Centralized error handling for authentication flows
//

import Foundation
import SwiftUI
import ClerkSDK

// MARK: - Authentication Error Types

enum AuthenticationError: Error, LocalizedError {
    case invalidCredentials
    case userNotFound
    case networkError
    case invalidEmail
    case weakPassword
    case passwordMismatch
    case emailAlreadyExists
    case userAlreadyExists
    case accountDisabled
    case tooManyAttempts
    case verificationFailed
    case resetTokenExpired
    case resetTokenInvalid
    case oauthError(String)
    case serverError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please check your credentials and try again."
        case .userNotFound:
            return "No account found with this email address. Please check your email or create a new account."
        case .networkError:
            return "Network connection error. Please check your internet connection and try again."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters with uppercase, lowercase, numbers, and symbols."
        case .passwordMismatch:
            return "Passwords do not match. Please make sure both passwords are identical."
        case .emailAlreadyExists:
            return "An account with this email already exists. Please sign in or use a different email."
        case .userAlreadyExists:
            return "An account already exists. Please sign in instead."
        case .accountDisabled:
            return "This account has been disabled. Please contact support for assistance."
        case .tooManyAttempts:
            return "Too many failed attempts. Please wait a few minutes before trying again."
        case .verificationFailed:
            return "Verification failed. Please check the code and try again."
        case .resetTokenExpired:
            return "Password reset link has expired. Please request a new one."
        case .resetTokenInvalid:
            return "Invalid password reset link. Please request a new one."
        case .oauthError(let message):
            return "OAuth authentication failed: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoveryOption: RecoveryOption? {
        switch self {
        case .invalidCredentials:
            return .forgotPassword
        case .userNotFound:
            return .createAccount
        case .networkError:
            return .retry
        case .invalidEmail:
            return .none
        case .weakPassword:
            return .none
        case .passwordMismatch:
            return .none
        case .emailAlreadyExists:
            return .signIn
        case .userAlreadyExists:
            return .signIn
        case .accountDisabled:
            return .contactSupport
        case .tooManyAttempts:
            return .waitAndRetry
        case .verificationFailed:
            return .resendCode
        case .resetTokenExpired:
            return .requestNewReset
        case .resetTokenInvalid:
            return .requestNewReset
        case .oauthError:
            return .retry
        case .serverError:
            return .retry
        case .unknownError:
            return .retry
        }
    }
}

// MARK: - Recovery Options

enum RecoveryOption {
    case forgotPassword
    case createAccount
    case signIn
    case retry
    case contactSupport
    case waitAndRetry
    case resendCode
    case requestNewReset
    case none
    
    var title: String {
        switch self {
        case .forgotPassword:
            return "Forgot Password?"
        case .createAccount:
            return "Create Account"
        case .signIn:
            return "Sign In"
        case .retry:
            return "Try Again"
        case .contactSupport:
            return "Contact Support"
        case .waitAndRetry:
            return "Wait and Retry"
        case .resendCode:
            return "Resend Code"
        case .requestNewReset:
            return "Request New Reset"
        case .none:
            return ""
        }
    }
    
    var icon: String {
        switch self {
        case .forgotPassword:
            return "key.fill"
        case .createAccount:
            return "person.crop.circle.badge.plus"
        case .signIn:
            return "person.crop.circle"
        case .retry:
            return "arrow.clockwise"
        case .contactSupport:
            return "questionmark.circle"
        case .waitAndRetry:
            return "clock.fill"
        case .resendCode:
            return "envelope.fill"
        case .requestNewReset:
            return "key.fill"
        case .none:
            return ""
        }
    }
}

// MARK: - Authentication Error Handler

@MainActor
class AuthenticationErrorHandler: ObservableObject {
    @Published var currentError: AuthenticationError?
    @Published var showingError = false
    @Published var showingRecoveryOptions = false
    @Published var errorHistory: [AuthenticationError] = []
    
    private let maxErrorHistoryCount = 10
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        let authError = mapToAuthenticationError(error)
        
        // Add to history
        errorHistory.append(authError)
        if errorHistory.count > maxErrorHistoryCount {
            errorHistory.removeFirst()
        }
        
        // Set current error
        currentError = authError
        showingError = true
        
        // Log error for debugging
        logError(authError)
    }
    
    private func mapToAuthenticationError(_ error: Error) -> AuthenticationError {
        if let clerkError = error as? ClerkError {
            return mapClerkError(clerkError)
        }
        
        if let authError = error as? AuthenticationError {
            return authError
        }
        
        // Handle NSError
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut:
                return .networkError
            default:
                return .unknownError(nsError.localizedDescription)
            }
        }
        
        return .unknownError(error.localizedDescription)
    }
    
    private func mapClerkError(_ clerkError: ClerkError) -> AuthenticationError {
        switch clerkError {
        case .invalidCredentials:
            return .invalidCredentials
        case .userNotFound:
            return .userNotFound
        case .networkError:
            return .networkError
        default:
            return .unknownError(clerkError.localizedDescription)
        }
    }
    
    // MARK: - Recovery Actions
    
    func performRecoveryAction(_ option: RecoveryOption) {
        switch option {
        case .forgotPassword:
            NotificationCenter.default.post(name: .showForgotPassword, object: nil)
        case .createAccount:
            NotificationCenter.default.post(name: .showCreateAccount, object: nil)
        case .signIn:
            NotificationCenter.default.post(name: .showSignIn, object: nil)
        case .retry:
            NotificationCenter.default.post(name: .retryLastAction, object: nil)
        case .contactSupport:
            openSupportURL()
        case .waitAndRetry:
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                NotificationCenter.default.post(name: .retryLastAction, object: nil)
            }
        case .resendCode:
            NotificationCenter.default.post(name: .resendVerificationCode, object: nil)
        case .requestNewReset:
            NotificationCenter.default.post(name: .requestNewPasswordReset, object: nil)
        case .none:
            break
        }
        
        clearError()
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        currentError = nil
        showingError = false
        showingRecoveryOptions = false
    }
    
    func showRecoveryOptions() {
        showingRecoveryOptions = true
    }
    
    private func logError(_ error: AuthenticationError) {
        #if DEBUG
        print("🚨 Authentication Error: \(error.localizedDescription)")
        #endif
        
        // Send to analytics/crash reporting
        // SentryManager.shared.captureError(error)
    }
    
    private func openSupportURL() {
        guard let url = URL(string: Config.URLs.support) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Validation Helpers
    
    func validateEmail(_ email: String) -> AuthenticationError? {
        guard !email.isEmpty else { return .invalidEmail }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        return emailPredicate.evaluate(with: email) ? nil : .invalidEmail
    }
    
    func validatePassword(_ password: String) -> AuthenticationError? {
        guard !password.isEmpty else { return .weakPassword }
        guard password.count >= 8 else { return .weakPassword }
        
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialCharacters = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        
        guard hasUppercase && hasLowercase && hasNumbers && hasSpecialCharacters else {
            return .weakPassword
        }
        
        return nil
    }
    
    func validatePasswordConfirmation(_ password: String, _ confirmPassword: String) -> AuthenticationError? {
        guard password == confirmPassword else { return .passwordMismatch }
        return nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showForgotPassword = Notification.Name("showForgotPassword")
    static let showCreateAccount = Notification.Name("showCreateAccount")
    static let showSignIn = Notification.Name("showSignIn")
    static let retryLastAction = Notification.Name("retryLastAction")
    static let resendVerificationCode = Notification.Name("resendVerificationCode")
    static let requestNewPasswordReset = Notification.Name("requestNewPasswordReset")
}

// MARK: - Error Alert View

struct AuthenticationErrorAlert: View {
    @ObservedObject var errorHandler: AuthenticationErrorHandler
    
    var body: some View {
        Group {
            if let error = errorHandler.currentError {
                Text("Alert")
                    .alert(isPresented: $errorHandler.showingError) {
                        Alert(
                            title: Text("Authentication Error"),
                            message: Text(error.localizedDescription),
                            primaryButton: .default(Text("OK")) {
                                errorHandler.clearError()
                            },
                            secondaryButton: error.recoveryOption != nil ? .default(Text("Options")) {
                                errorHandler.showRecoveryOptions()
                            } : nil
                        )
                    }
                    .sheet(isPresented: $errorHandler.showingRecoveryOptions) {
                        if let error = errorHandler.currentError,
                           let recoveryOption = error.recoveryOption {
                            RecoveryOptionsView(
                                error: error,
                                recoveryOption: recoveryOption,
                                errorHandler: errorHandler
                            )
                        }
                    }
            }
        }
    }
}

// MARK: - Recovery Options View

struct RecoveryOptionsView: View {
    let error: AuthenticationError
    let recoveryOption: RecoveryOption
    let errorHandler: AuthenticationErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Error Icon
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                // Error Description
                VStack(spacing: 16) {
                    Text("We encountered an issue")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Recovery Action
                Button(action: {
                    errorHandler.performRecoveryAction(recoveryOption)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: recoveryOption.icon)
                            .font(.title3)
                        Text(recoveryOption.title)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Error Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Environment Key

struct AuthenticationErrorHandlerKey: EnvironmentKey {
    static let defaultValue = AuthenticationErrorHandler()
}

extension EnvironmentValues {
    var authenticationErrorHandler: AuthenticationErrorHandler {
        get { self[AuthenticationErrorHandlerKey.self] }
        set { self[AuthenticationErrorHandlerKey.self] = newValue }
    }
}