//
//  ProductionUIComponents.swift
//  StreamyyyApp
//
//  Production-ready UI components with proper loading states, error handling, and accessibility
//

import SwiftUI

// MARK: - Loading State Component
public struct LoadingStateView: View {
    let message: String
    let showProgress: Bool
    let progress: Double?
    
    public init(message: String = "Loading...", showProgress: Bool = false, progress: Double? = nil) {
        self.message = message
        self.showProgress = showProgress
        self.progress = progress
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            if showProgress, let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .scaleEffect(1.2)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading: \(message)")
    }
}

// MARK: - Error State Component
public struct ErrorStateView: View {
    let error: Error
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    
    public init(error: Error, retryAction: (() -> Void)? = nil, dismissAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                if let dismissAction = dismissAction {
                    Button("Dismiss") {
                        dismissAction()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Dismiss error")
                }
                
                if let retryAction = retryAction {
                    Button("Try Again") {
                        retryAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Retry action")
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.localizedDescription)")
    }
}

// MARK: - Empty State Component
public struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    public init(
        title: String,
        subtitle: String,
        iconName: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(actionTitle)
            }
        }
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Shimmer Loading Component
public struct ShimmerView: View {
    @State private var isAnimating = false
    
    public init() {}
    
    public var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(70))
                    .offset(x: isAnimating ? 200 : -200)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Stream Card Shimmer
public struct StreamCardShimmer: View {
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ShimmerView()
                .frame(height: 120)
                .cornerRadius(8)
            
            // Title
            ShimmerView()
                .frame(height: 16)
                .cornerRadius(4)
            
            // Subtitle
            ShimmerView()
                .frame(height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cornerRadius(4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Floating Action Button
public struct FloatingActionButton: View {
    let action: () -> Void
    let iconName: String
    let backgroundColor: Color
    
    public init(
        action: @escaping () -> Void,
        iconName: String = "plus",
        backgroundColor: Color = .accentColor
    ) {
        self.action = action
        self.iconName = iconName
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(backgroundColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add new item")
    }
}

// MARK: - Success Banner
public struct SuccessBanner: View {
    let message: String
    let action: (() -> Void)?
    
    public init(message: String, action: (() -> Void)? = nil) {
        self.message = message
        self.action = action
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(.title3)
            
            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            if let action = action {
                Button("Dismiss") {
                    action()
                }
                .foregroundColor(.white)
                .font(.caption)
                .fontWeight(.semibold)
            }
        }
        .padding(16)
        .background(Color.green)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Success: \(message)")
    }
}

// MARK: - Info Banner
public struct InfoBanner: View {
    let message: String
    let iconName: String
    let backgroundColor: Color
    let action: (() -> Void)?
    
    public init(
        message: String,
        iconName: String = "info.circle.fill",
        backgroundColor: Color = .blue,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        self.action = action
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(.white)
                .font(.title3)
            
            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            if let action = action {
                Button("Dismiss") {
                    action()
                }
                .foregroundColor(.white)
                .font(.caption)
                .fontWeight(.semibold)
            }
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Information: \(message)")
    }
}

// MARK: - Subscription Upgrade Prompt
public struct SubscriptionUpgradePrompt: View {
    let currentPlan: String
    let suggestedPlan: String
    let feature: String
    let upgradeAction: () -> Void
    let dismissAction: () -> Void
    
    public init(
        currentPlan: String,
        suggestedPlan: String,
        feature: String,
        upgradeAction: @escaping () -> Void,
        dismissAction: @escaping () -> Void
    ) {
        self.currentPlan = currentPlan
        self.suggestedPlan = suggestedPlan
        self.feature = feature
        self.upgradeAction = upgradeAction
        self.dismissAction = dismissAction
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade Required")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(feature) requires \(suggestedPlan)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("×") {
                    dismissAction()
                }
                .font(.title2)
                .foregroundColor(.secondary)
                .accessibilityLabel("Dismiss upgrade prompt")
            }
            
            HStack(spacing: 12) {
                Button("Maybe Later") {
                    dismissAction()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Dismiss upgrade prompt")
                
                Button("Upgrade Now") {
                    upgradeAction()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Upgrade to \(suggestedPlan)")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Stream Quality Indicator
public struct StreamQualityIndicator: View {
    let quality: StreamQuality
    let isLive: Bool
    
    public init(quality: StreamQuality, isLive: Bool = true) {
        self.quality = quality
        self.isLive = isLive
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? .red : .gray)
                .frame(width: 8, height: 8)
                .opacity(isLive ? 1 : 0.5)
            
            Text(quality.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.7))
        )
        .accessibilityLabel("\(isLive ? "Live" : "Offline") stream at \(quality.displayName) quality")
    }
}

// MARK: - Viewer Count Badge
public struct ViewerCountBadge: View {
    let count: Int
    let isLive: Bool
    
    public init(count: Int, isLive: Bool = true) {
        self.count = count
        self.isLive = isLive
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.fill")
                .font(.caption2)
            
            Text(formatViewerCount(count))
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.7))
        )
        .opacity(isLive ? 1 : 0.7)
        .accessibilityLabel("\(count) viewers")
    }
    
    private func formatViewerCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - App Store Compliance Views
public struct AppStoreComplianceView: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            // Privacy Notice
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy Notice")
                    .font(.headline)
                
                Text("This app collects usage data to improve your experience. All data is processed according to our Privacy Policy.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("View Privacy Policy") {
                    // Open privacy policy
                    if let url = URL(string: Config.URLs.privacyPolicy) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            // Terms of Service
            VStack(alignment: .leading, spacing: 12) {
                Text("Terms of Service")
                    .font(.headline)
                
                Text("By using this app, you agree to our Terms of Service.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("View Terms") {
                    // Open terms of service
                    if let url = URL(string: Config.URLs.termsOfService) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .navigationTitle("Legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Production Error Handling
public class ProductionErrorHandler: ObservableObject {
    @Published public var showingError = false
    @Published public var currentError: Error?
    @Published public var errorContext: String = ""
    
    public static let shared = ProductionErrorHandler()
    
    private init() {}
    
    public func handle(_ error: Error, context: String = "") {
        DispatchQueue.main.async {
            self.currentError = error
            self.errorContext = context
            self.showingError = true
            
            // Track error analytics
            AnalyticsManager.shared.trackError(error: error, context: context)
        }
    }
    
    public func clearError() {
        currentError = nil
        errorContext = ""
        showingError = false
    }
}

// MARK: - Loading State Manager
public class LoadingStateManager: ObservableObject {
    @Published public var isLoading = false
    @Published public var loadingMessage = "Loading..."
    @Published public var progress: Double?
    
    public static let shared = LoadingStateManager()
    
    private init() {}
    
    public func startLoading(message: String = "Loading...", showProgress: Bool = false) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.loadingMessage = message
            self.progress = showProgress ? 0.0 : nil
        }
    }
    
    public func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.progress = progress
        }
    }
    
    public func stopLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.progress = nil
        }
    }
}

// MARK: - Accessibility Extensions
extension View {
    public func accessibilityStreamCard(
        title: String,
        streamer: String,
        viewerCount: Int,
        isLive: Bool
    ) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) by \(streamer)")
            .accessibilityValue("\(viewerCount) viewers, \(isLive ? "live" : "offline")")
            .accessibilityHint("Double tap to open stream")
    }
    
    public func accessibilitySubscriptionButton(plan: String, price: String) -> some View {
        self.accessibilityLabel("Subscribe to \(plan) plan")
            .accessibilityValue("Price: \(price)")
            .accessibilityHint("Double tap to start subscription")
    }
}