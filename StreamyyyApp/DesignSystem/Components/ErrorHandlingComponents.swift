//
//  ErrorHandlingComponents.swift
//  StreamyyyApp
//
//  Comprehensive error handling and loading state components
//

import SwiftUI

// MARK: - Error View Component
struct ErrorView: View {
    let error: AppError
    let retryAction: (() -> Void)?
    
    init(error: AppError, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon
            ZStack {
                Circle()
                    .fill(errorColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: errorIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(errorColor)
            }
            
            // Error Content
            VStack(spacing: 12) {
                Text(error.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(error.message)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 20)
            
            // Action Buttons
            if let retryAction = retryAction {
                VStack(spacing: 12) {
                    Button(action: retryAction) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                            Text("Try Again")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                        )
                    }
                    .modernButtonStyle(variant: .primary, size: .medium)
                    
                    Button("Dismiss") {
                        AppStateManager.shared.clearError()
                    }
                    .modernButtonStyle(variant: .ghost, size: .medium)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(errorColor.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private var errorColor: Color {
        switch error {
        case .authentication: return .red
        case .network: return .orange
        case .data: return .yellow
        case .general: return .gray
        }
    }
    
    private var errorIcon: String {
        switch error {
        case .authentication: return "person.crop.circle.badge.exclamationmark"
        case .network: return "wifi.exclamationmark"
        case .data: return "externaldrive.badge.exclamationmark"
        case .general: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Loading View Component
struct LoadingView: View {
    let message: String
    let showProgress: Bool
    @State private var animationOffset: CGFloat = 0
    
    init(message: String = "Loading...", showProgress: Bool = true) {
        self.message = message
        self.showProgress = showProgress
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Loading Animation
            ZStack {
                if showProgress {
                    // Circular progress indicator
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .scaleEffect(1.5)
                } else {
                    // Custom animated dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 8, height: 8)
                                .offset(y: animationOffset)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                    value: animationOffset
                                )
                        }
                    }
                    .onAppear {
                        animationOffset = -10
                    }
                }
            }
            
            // Loading Message
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Empty State Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Empty State Content
            VStack(spacing: 12) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 20)
            
            // Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cyan.opacity(0.8))
                        )
                }
                .modernButtonStyle(variant: .primary, size: .medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Network Status Banner
struct NetworkStatusBanner: View {
    let status: NetworkStatus
    @State private var showBanner = true
    
    var body: some View {
        if status != .connected && showBanner {
            HStack(spacing: 12) {
                Image(systemName: networkIcon)
                    .font(.subheadline)
                    .foregroundColor(status.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(networkMessage)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showBanner = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(status.color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(status.color.opacity(0.4), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    private var networkIcon: String {
        switch status {
        case .connected: return "wifi"
        case .disconnected: return "wifi.slash"
        case .limited: return "wifi.exclamationmark"
        }
    }
    
    private var networkMessage: String {
        switch status {
        case .connected: return "Connected to internet"
        case .disconnected: return "No internet connection"
        case .limited: return "Limited connectivity"
        }
    }
}

// MARK: - Global Error Overlay
struct GlobalErrorOverlay: View {
    @ObservedObject var appState = AppStateManager.shared
    
    var body: some View {
        ZStack {
            if let error = appState.globalError {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                ErrorView(error: error) {
                    Task {
                        await appState.refreshAllData()
                    }
                }
                .padding(.horizontal, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.globalError != nil)
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    @ObservedObject var appState = AppStateManager.shared
    
    var body: some View {
        ZStack {
            if appState.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                LoadingView(message: "Loading data...")
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isLoading)
    }
}

// MARK: - View Extensions
extension View {
    func withErrorHandling() -> some View {
        self.overlay(GlobalErrorOverlay())
    }
    
    func withLoadingOverlay() -> some View {
        self.overlay(LoadingOverlay())
    }
    
    func withNetworkStatus() -> some View {
        VStack(spacing: 0) {
            NetworkStatusBanner(status: AppStateManager.shared.networkStatus)
            self
        }
    }
    
    func errorState(
        _ error: AppError?,
        retryAction: @escaping () -> Void
    ) -> some View {
        Group {
            if let error = error {
                ErrorView(error: error, retryAction: retryAction)
            } else {
                self
            }
        }
    }
    
    func loadingState(
        _ isLoading: Bool,
        message: String = "Loading..."
    ) -> some View {
        Group {
            if isLoading {
                LoadingView(message: message)
            } else {
                self
            }
        }
    }
    
    func emptyState(
        when condition: Bool,
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        Group {
            if condition {
                EmptyStateView(
                    icon: icon,
                    title: title,
                    message: message,
                    actionTitle: actionTitle,
                    action: action
                )
            } else {
                self
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        ErrorView(
            error: .network("Unable to connect to streaming services"),
            retryAction: { print("Retry tapped") }
        )
        
        LoadingView(message: "Loading streams...")
        
        EmptyStateView(
            icon: "heart",
            title: "No Favorites",
            message: "Add streams to your favorites to see them here",
            actionTitle: "Browse Streams",
            action: { print("Browse tapped") }
        )
    }
    .padding()
    .background(Color.black)
}