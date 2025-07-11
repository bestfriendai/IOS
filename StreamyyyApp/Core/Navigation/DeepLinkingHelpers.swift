//
//  DeepLinkingHelpers.swift
//  StreamyyyApp
//
//  Simple deep linking and navigation helpers for production readiness
//

import SwiftUI
import Foundation

// MARK: - Deep Link URL Handler
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    @Published var pendingDeepLink: DeepLink?
    
    private init() {}
    
    func handleURL(_ url: URL) {
        guard let deepLink = parseURL(url) else { return }
        pendingDeepLink = deepLink
    }
    
    private func parseURL(_ url: URL) -> DeepLink? {
        guard url.scheme == "streamhub" else { return nil }
        
        switch url.host {
        case "stream":
            if let streamId = url.pathComponents.dropFirst().first {
                return .stream(id: streamId)
            }
        case "discover":
            return .discover
        case "library":
            return .library
        case "profile":
            return .profile
        case "multistream":
            return .multistream
        default:
            break
        }
        
        return nil
    }
    
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }
}

// MARK: - Deep Link Types
enum DeepLink: Equatable {
    case stream(id: String)
    case discover
    case library
    case profile
    case multistream
}

// MARK: - Navigation Coordinator
class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()
    
    @Published var presentedSheet: AppSheet?
    @Published var alertMessage: AlertMessage?
    
    private init() {}
    
    func presentSheet(_ sheet: AppSheet) {
        presentedSheet = sheet
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
    
    func showAlert(_ alert: AlertMessage) {
        alertMessage = alert
    }
    
    func dismissAlert() {
        alertMessage = nil
    }
}

// MARK: - Sheet Types
enum AppSheet: Identifiable {
    case streamPicker
    case settings
    case profile
    case authentication
    case subscription
    
    var id: String {
        switch self {
        case .streamPicker: return "streamPicker"
        case .settings: return "settings"
        case .profile: return "profile"
        case .authentication: return "authentication"
        case .subscription: return "subscription"
        }
    }
}

// MARK: - Alert Message
struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: AlertButton?
    let secondaryButton: AlertButton?
    
    init(title: String, message: String, primaryButton: AlertButton? = nil, secondaryButton: AlertButton? = nil) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }
}

struct AlertButton {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    
    enum ButtonStyle {
        case `default`
        case destructive
        case cancel
    }
}

// MARK: - View Extensions
extension View {
    func handleDeepLinks() -> some View {
        self
            .onReceive(DeepLinkHandler.shared.$pendingDeepLink.compactMap { $0 }) { deepLink in
                handleDeepLink(deepLink)
            }
            .onOpenURL { url in
                DeepLinkHandler.shared.handleURL(url)
            }
    }
    
    private func handleDeepLink(_ deepLink: DeepLink) {
        let appState = AppStateManager.shared
        
        switch deepLink {
        case .discover:
            appState.navigateToTab(.discover)
        case .library:
            appState.navigateToTab(.library)
        case .profile:
            appState.navigateToTab(.profile)
        case .multistream:
            appState.navigateToTab(.watch)
        case .stream(let id):
            // Handle specific stream navigation
            appState.navigateToTab(.watch)
            // Additional logic to load specific stream
        }
        
        DeepLinkHandler.shared.clearPendingDeepLink()
    }
    
    func withNavigation() -> some View {
        self
            .environmentObject(NavigationCoordinator.shared)
            .sheet(item: NavigationCoordinator.shared.binding(\.presentedSheet)) { sheet in
                sheetContent(for: sheet)
            }
            .alert(item: NavigationCoordinator.shared.binding(\.alertMessage)) { alert in
                alertContent(for: alert)
            }
    }
    
    private func sheetContent(for sheet: AppSheet) -> some View {
        Group {
            switch sheet {
            case .streamPicker:
                Text("Stream Picker")
            case .settings:
                Text("Settings")
            case .profile:
                Text("Profile")
            case .authentication:
                Text("Authentication")
            case .subscription:
                Text("Subscription")
            }
        }
    }
    
    private func alertContent(for alert: AlertMessage) -> Alert {
        if let primaryButton = alert.primaryButton,
           let secondaryButton = alert.secondaryButton {
            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: alertButtonType(primaryButton),
                secondaryButton: alertButtonType(secondaryButton)
            )
        } else if let primaryButton = alert.primaryButton {
            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: alertButtonType(primaryButton)
            )
        } else {
            return Alert(
                title: Text(alert.title),
                message: Text(alert.message)
            )
        }
    }
    
    private func alertButtonType(_ button: AlertButton) -> Alert.Button {
        switch button.style {
        case .default:
            return .default(Text(button.title), action: button.action)
        case .destructive:
            return .destructive(Text(button.title), action: button.action)
        case .cancel:
            return .cancel(Text(button.title), action: button.action)
        }
    }
}

// MARK: - NavigationCoordinator Binding Extension
extension NavigationCoordinator {
    func binding<T>(_ keyPath: WritableKeyPath<NavigationCoordinator, T>) -> Binding<T> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }
}

#Preview {
    Text("Deep Link Testing")
        .handleDeepLinks()
        .withNavigation()
}