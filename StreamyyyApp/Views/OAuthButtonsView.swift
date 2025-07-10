//
//  OAuthButtonsView.swift
//  StreamyyyApp
//
//  Social login buttons for OAuth authentication
//

import SwiftUI
import ClerkSDK

struct OAuthButtonsView: View {
    @EnvironmentObject var clerkManager: ClerkManager
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var loadingProvider: OAuthProvider?
    
    let onSuccess: () -> Void
    let onError: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Divider with "or" text
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("or")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
            
            // Social Login Buttons
            VStack(spacing: 12) {
                // Apple Sign In
                OAuthButton(
                    provider: .apple,
                    title: "Continue with Apple",
                    icon: "applelogo",
                    backgroundColor: .black,
                    foregroundColor: .white,
                    isLoading: loadingProvider == .apple,
                    action: { signInWithApple() }
                )
                .accessibilityLabel("Sign in with Apple")
                .accessibilityHint("Authenticate using your Apple ID")
                
                // Google Sign In
                OAuthButton(
                    provider: .google,
                    title: "Continue with Google",
                    icon: "globe",
                    backgroundColor: .white,
                    foregroundColor: .black,
                    borderColor: .gray.opacity(0.3),
                    isLoading: loadingProvider == .google,
                    action: { signInWithGoogle() }
                )
                .accessibilityLabel("Sign in with Google")
                .accessibilityHint("Authenticate using your Google account")
                
                // GitHub Sign In
                OAuthButton(
                    provider: .github,
                    title: "Continue with GitHub",
                    icon: "globe",
                    backgroundColor: .black,
                    foregroundColor: .white,
                    isLoading: loadingProvider == .github,
                    action: { signInWithGitHub() }
                )
                .accessibilityLabel("Sign in with GitHub")
                .accessibilityHint("Authenticate using your GitHub account")
            }
            
            // Privacy Notice
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        openURL(Config.URLs.termsOfService)
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                    
                    Text("and")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Privacy Policy") {
                        openURL(Config.URLs.privacyPolicy)
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, 16)
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - OAuth Authentication Methods
    
    private func signInWithApple() {
        guard Config.Clerk.enabledProviders.contains("oauth_apple") else {
            onError("Apple Sign In is not configured")
            return
        }
        
        authenticateWithProvider(.apple) {
            Task {
                do {
                    loadingProvider = .apple
                    try await clerkManager.signInWithApple()
                    await MainActor.run {
                        loadingProvider = nil
                        onSuccess()
                    }
                } catch {
                    await MainActor.run {
                        loadingProvider = nil
                        let errorMsg = clerkManager.handleError(error)
                        onError(errorMsg)
                    }
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        guard Config.Clerk.enabledProviders.contains("oauth_google") else {
            onError("Google Sign In is not configured")
            return
        }
        
        authenticateWithProvider(.google) {
            Task {
                do {
                    loadingProvider = .google
                    try await clerkManager.signInWithGoogle()
                    await MainActor.run {
                        loadingProvider = nil
                        onSuccess()
                    }
                } catch {
                    await MainActor.run {
                        loadingProvider = nil
                        let errorMsg = clerkManager.handleError(error)
                        onError(errorMsg)
                    }
                }
            }
        }
    }
    
    private func signInWithGitHub() {
        guard Config.Clerk.enabledProviders.contains("oauth_github") else {
            onError("GitHub Sign In is not configured")
            return
        }
        
        authenticateWithProvider(.github) {
            Task {
                do {
                    loadingProvider = .github
                    try await clerkManager.signInWithGitHub()
                    await MainActor.run {
                        loadingProvider = nil
                        onSuccess()
                    }
                } catch {
                    await MainActor.run {
                        loadingProvider = nil
                        let errorMsg = clerkManager.handleError(error)
                        onError(errorMsg)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func authenticateWithProvider(_ provider: OAuthProvider, action: @escaping () -> Void) {
        guard !isLoading else { return }
        
        isLoading = true
        action()
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - OAuth Button Component

struct OAuthButton: View {
    let provider: OAuthProvider
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    var borderColor: Color?
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Loading indicator or icon
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    // Custom icon based on provider
                    if provider == .apple {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(foregroundColor)
                    } else {
                        // For Google and GitHub, use a custom icon or system icon
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(foregroundColor)
                    }
                }
                
                Text(isLoading ? "Connecting..." : title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(foregroundColor)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .padding(.horizontal, 16)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor ?? Color.clear, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLoading)
    }
}

// MARK: - OAuth Provider Enum

enum OAuthProvider: String, CaseIterable {
    case apple = "oauth_apple"
    case google = "oauth_google"
    case github = "oauth_github"
    
    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .github: return "GitHub"
        }
    }
    
    var iconName: String {
        switch self {
        case .apple: return "applelogo"
        case .google: return "globe"
        case .github: return "globe"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .apple: return .black
        case .google: return .white
        case .github: return .black
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .apple: return .white
        case .google: return .black
        case .github: return .white
        }
    }
}

// MARK: - Preview

#Preview {
    OAuthButtonsView(
        onSuccess: { print("OAuth Success") },
        onError: { error in print("OAuth Error: \(error)") }
    )
    .environmentObject(ClerkManager())
    .padding()
}