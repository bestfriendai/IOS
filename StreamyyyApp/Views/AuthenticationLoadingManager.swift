//
//  AuthenticationLoadingManager.swift
//  StreamyyyApp
//
//  Loading state management for authentication flows
//

import Foundation
import SwiftUI
import Combine

// MARK: - Loading States

enum LoadingState {
    case idle
    case loading(String)
    case success(String)
    case error(Error)
    
    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }
    
    var message: String {
        switch self {
        case .idle:
            return ""
        case .loading(let message):
            return message
        case .success(let message):
            return message
        case .error(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Authentication Loading Manager

@MainActor
class AuthenticationLoadingManager: ObservableObject {
    @Published var signInState: LoadingState = .idle
    @Published var signUpState: LoadingState = .idle
    @Published var passwordResetState: LoadingState = .idle
    @Published var oauthState: LoadingState = .idle
    @Published var profileUpdateState: LoadingState = .idle
    @Published var globalLoadingState: LoadingState = .idle
    
    private var loadingQueue: [LoadingOperation] = []
    private var currentOperation: LoadingOperation?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Loading Operations
    
    struct LoadingOperation: Identifiable {
        let id = UUID()
        let type: LoadingType
        let message: String
        let action: () async throws -> Void
        let onSuccess: (() -> Void)?
        let onError: ((Error) -> Void)?
        
        init(
            type: LoadingType,
            message: String,
            action: @escaping () async throws -> Void,
            onSuccess: (() -> Void)? = nil,
            onError: ((Error) -> Void)? = nil
        ) {
            self.type = type
            self.message = message
            self.action = action
            self.onSuccess = onSuccess
            self.onError = onError
        }
    }
    
    enum LoadingType {
        case signIn
        case signUp
        case passwordReset
        case oauth
        case profileUpdate
        case global
    }
    
    // MARK: - Public Methods
    
    func performSignIn(
        message: String = "Signing in...",
        action: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let operation = LoadingOperation(
            type: .signIn,
            message: message,
            action: action,
            onSuccess: onSuccess,
            onError: onError
        )
        
        executeOperation(operation)
    }
    
    func performSignUp(
        message: String = "Creating account...",
        action: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let operation = LoadingOperation(
            type: .signUp,
            message: message,
            action: action,
            onSuccess: onSuccess,
            onError: onError
        )
        
        executeOperation(operation)
    }
    
    func performPasswordReset(
        message: String = "Resetting password...",
        action: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let operation = LoadingOperation(
            type: .passwordReset,
            message: message,
            action: action,
            onSuccess: onSuccess,
            onError: onError
        )
        
        executeOperation(operation)
    }
    
    func performOAuth(
        provider: String,
        message: String? = nil,
        action: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let operation = LoadingOperation(
            type: .oauth,
            message: message ?? "Connecting with \(provider)...",
            action: action,
            onSuccess: onSuccess,
            onError: onError
        )
        
        executeOperation(operation)
    }
    
    func performProfileUpdate(
        message: String = "Updating profile...",
        action: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let operation = LoadingOperation(
            type: .profileUpdate,
            message: message,
            action: action,
            onSuccess: onSuccess,
            onError: onError
        )
        
        executeOperation(operation)
    }
    
    func performGlobalOperation(
        message: String,
        action: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let operation = LoadingOperation(
            type: .global,
            message: message,
            action: action,
            onSuccess: onSuccess,
            onError: onError
        )
        
        executeOperation(operation)
    }
    
    // MARK: - Private Methods
    
    private func executeOperation(_ operation: LoadingOperation) {
        // Cancel any existing operation of the same type
        cancelOperation(of: operation.type)
        
        // Set loading state
        setLoadingState(for: operation.type, state: .loading(operation.message))
        
        // Execute operation
        Task {
            do {
                try await operation.action()
                
                await MainActor.run {
                    setLoadingState(for: operation.type, state: .success("Success"))
                    operation.onSuccess?()
                    
                    // Clear success state after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.setLoadingState(for: operation.type, state: .idle)
                    }
                }
            } catch {
                await MainActor.run {
                    setLoadingState(for: operation.type, state: .error(error))
                    operation.onError?(error)
                    
                    // Clear error state after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.setLoadingState(for: operation.type, state: .idle)
                    }
                }
            }
        }
    }
    
    private func setLoadingState(for type: LoadingType, state: LoadingState) {
        switch type {
        case .signIn:
            signInState = state
        case .signUp:
            signUpState = state
        case .passwordReset:
            passwordResetState = state
        case .oauth:
            oauthState = state
        case .profileUpdate:
            profileUpdateState = state
        case .global:
            globalLoadingState = state
        }
    }
    
    private func cancelOperation(of type: LoadingType) {
        setLoadingState(for: type, state: .idle)
    }
    
    // MARK: - Utility Methods
    
    func clearAllStates() {
        signInState = .idle
        signUpState = .idle
        passwordResetState = .idle
        oauthState = .idle
        profileUpdateState = .idle
        globalLoadingState = .idle
    }
    
    func isAnyLoading() -> Bool {
        return signInState.isLoading ||
               signUpState.isLoading ||
               passwordResetState.isLoading ||
               oauthState.isLoading ||
               profileUpdateState.isLoading ||
               globalLoadingState.isLoading
    }
    
    func getCurrentLoadingMessage() -> String? {
        if signInState.isLoading { return signInState.message }
        if signUpState.isLoading { return signUpState.message }
        if passwordResetState.isLoading { return passwordResetState.message }
        if oauthState.isLoading { return oauthState.message }
        if profileUpdateState.isLoading { return profileUpdateState.message }
        if globalLoadingState.isLoading { return globalLoadingState.message }
        return nil
    }
}

// MARK: - Loading Views

struct LoadingButton: View {
    let title: String
    let loadingTitle: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    init(
        title: String,
        loadingTitle: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.loadingTitle = loadingTitle ?? "Loading..."
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isLoading ? loadingTitle : title)
                    .fontWeight(.semibold)
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
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

struct LoadingOverlay: View {
    let message: String
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text(message)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
        }
    }
}

struct LoadingState: View {
    let state: LoadingState
    let successIcon: String
    let errorIcon: String
    
    init(
        state: LoadingState,
        successIcon: String = "checkmark.circle.fill",
        errorIcon: String = "xmark.circle.fill"
    ) {
        self.state = state
        self.successIcon = successIcon
        self.errorIcon = errorIcon
    }
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
                
            case .loading(let message):
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(0.8)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
            case .success(let message):
                HStack(spacing: 12) {
                    Image(systemName: successIcon)
                        .foregroundColor(.green)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
            case .error(let error):
                HStack(spacing: 12) {
                    Image(systemName: errorIcon)
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state.isLoading)
    }
}

// MARK: - Environment Key

struct AuthenticationLoadingManagerKey: EnvironmentKey {
    static let defaultValue = AuthenticationLoadingManager()
}

extension EnvironmentValues {
    var authenticationLoadingManager: AuthenticationLoadingManager {
        get { self[AuthenticationLoadingManagerKey.self] }
        set { self[AuthenticationLoadingManagerKey.self] = newValue }
    }
}