//
//  NavigationCoordinator.swift
//  StreamyyyApp
//
//  Navigation state management and coordination
//

import SwiftUI
import Combine

// MARK: - Navigation Coordinator
@MainActor
class NavigationCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
    @Published var isShowingMultiStream = false
    @Published var isShowingFullscreenStream = false
    @Published var selectedStreamForFullscreen: Stream?
    @Published var isShowingAddStreamSheet = false
    @Published var isShowingStreamPicker = false
    @Published var deepLinkPendingAction: (() -> Void)?
    
    // MARK: - Navigation History
    @Published private(set) var navigationHistory: [NavigationItem] = []
    private let maxHistoryItems = 20
    
    // MARK: - Animation States
    @Published var isNavigating = false
    @Published var transitionStyle: TransitionStyle = .slide
    
    // MARK: - Tab Management
    enum Tab: Int, CaseIterable {
        case streams = 0
        case discover = 1
        case multiStream = 2
        case favorites = 3
        case profile = 4
        
        var title: String {
            switch self {
            case .streams: return "Streams"
            case .discover: return "Discover"
            case .multiStream: return "MultiStream"
            case .favorites: return "Favorites"
            case .profile: return "Profile"
            }
        }
        
        var icon: String {
            switch self {
            case .streams: return "tv"
            case .discover: return "magnifyingglass.circle"
            case .multiStream: return "rectangle.3.group"
            case .favorites: return "heart"
            case .profile: return "person"
            }
        }
        
        var filledIcon: String {
            switch self {
            case .streams: return "tv.fill"
            case .discover: return "magnifyingglass.circle.fill"
            case .multiStream: return "rectangle.3.group.fill"
            case .favorites: return "heart.fill"
            case .profile: return "person.fill"
            }
        }
    }
    
    // MARK: - Navigation Destinations
    enum NavigationDestination: Hashable {
        case streamDetail(streamId: String)
        case addStream
        case streamPicker
        case layoutCustomization
        case settings
        case profile
        case subscription
        case favorites
        case multiStreamFocus(streamId: String)
        case searchResults(query: String)
        
        var title: String {
            switch self {
            case .streamDetail: return "Stream Details"
            case .addStream: return "Add Stream"
            case .streamPicker: return "Choose Stream"
            case .layoutCustomization: return "Customize Layout"
            case .settings: return "Settings"
            case .profile: return "Profile"
            case .subscription: return "Subscription"
            case .favorites: return "Favorites"
            case .multiStreamFocus: return "Focus Stream"
            case .searchResults: return "Search Results"
            }
        }
    }
    
    // MARK: - Transition Styles
    enum TransitionStyle {
        case slide
        case fade
        case scale
        case push
        case modal
        
        var animation: Animation {
            switch self {
            case .slide: return .easeInOut(duration: 0.3)
            case .fade: return .easeInOut(duration: 0.25)
            case .scale: return .spring(response: 0.4, dampingFraction: 0.8)
            case .push: return .easeInOut(duration: 0.35)
            case .modal: return .spring(response: 0.5, dampingFraction: 0.9)
            }
        }
    }
    
    // MARK: - Navigation Item
    struct NavigationItem: Identifiable, Hashable {
        let id = UUID()
        let tab: Tab
        let destination: NavigationDestination?
        let timestamp: Date
        let context: [String: String]
        
        init(tab: Tab, destination: NavigationDestination? = nil, context: [String: String] = [:]) {
            self.tab = tab
            self.destination = destination
            self.timestamp = Date()
            self.context = context
        }
    }
    
    // MARK: - Public Navigation Methods
    
    /// Navigate to a specific tab with optional animation
    func navigateToTab(_ tab: Tab, animated: Bool = true, completion: (() -> Void)? = nil) {
        if animated && selectedTab != tab.rawValue {
            withAnimation(transitionStyle.animation) {
                selectedTab = tab.rawValue
                isNavigating = true
            }
            
            // Reset navigation flag after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isNavigating = false
                completion?()
            }
        } else {
            selectedTab = tab.rawValue
            completion?()
        }
        
        addToHistory(NavigationItem(tab: tab))
    }
    
    /// Navigate to MultiStream view with context
    func navigateToMultiStream(with streams: [Stream] = [], animated: Bool = true) {
        let context = streams.isEmpty ? [:] : ["streamCount": "\(streams.count)"]
        
        navigateToTab(.multiStream, animated: animated) {
            // Any additional setup for MultiStream view
        }
        
        addToHistory(NavigationItem(tab: .multiStream, context: context))
    }
    
    /// Navigate to Discovery tab and optionally search
    func navigateToDiscovery(searchQuery: String? = nil, animated: Bool = true) {
        navigateToTab(.discover, animated: animated)
        
        if let query = searchQuery {
            let context = ["searchQuery": query]
            addToHistory(NavigationItem(tab: .discover, context: context))
        }
    }
    
    /// Push a new destination onto the navigation stack
    func push(_ destination: NavigationDestination, animated: Bool = true) {
        if animated {
            withAnimation(transitionStyle.animation) {
                navigationPath.append(destination)
            }
        } else {
            navigationPath.append(destination)
        }
        
        addToHistory(NavigationItem(tab: Tab(rawValue: selectedTab) ?? .streams, destination: destination))
    }
    
    /// Pop back to previous view
    func pop(animated: Bool = true) {
        if animated {
            withAnimation(transitionStyle.animation) {
                if !navigationPath.isEmpty {
                    navigationPath.removeLast()
                }
            }
        } else {
            if !navigationPath.isEmpty {
                navigationPath.removeLast()
            }
        }
    }
    
    /// Pop to root of current tab
    func popToRoot(animated: Bool = true) {
        if animated {
            withAnimation(transitionStyle.animation) {
                navigationPath = NavigationPath()
            }
        } else {
            navigationPath = NavigationPath()
        }
    }
    
    /// Show fullscreen stream
    func showFullscreenStream(_ stream: Stream) {
        selectedStreamForFullscreen = stream
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isShowingFullscreenStream = true
        }
        
        addToHistory(NavigationItem(
            tab: Tab(rawValue: selectedTab) ?? .streams,
            destination: .multiStreamFocus(streamId: stream.id?.uuidString ?? ""),
            context: ["streamTitle": stream.displayTitle]
        ))
    }
    
    /// Dismiss fullscreen stream
    func dismissFullscreenStream() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowingFullscreenStream = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.selectedStreamForFullscreen = nil
        }
    }
    
    /// Show Add Stream sheet
    func showAddStreamSheet() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            isShowingAddStreamSheet = true
        }
        
        addToHistory(NavigationItem(
            tab: Tab(rawValue: selectedTab) ?? .streams,
            destination: .addStream
        ))
    }
    
    /// Dismiss Add Stream sheet
    func dismissAddStreamSheet() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowingAddStreamSheet = false
        }
    }
    
    /// Show Stream Picker
    func showStreamPicker() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            isShowingStreamPicker = true
        }
        
        addToHistory(NavigationItem(
            tab: Tab(rawValue: selectedTab) ?? .streams,
            destination: .streamPicker
        ))
    }
    
    /// Dismiss Stream Picker
    func dismissStreamPicker() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowingStreamPicker = false
        }
    }
    
    // MARK: - Deep Linking Support
    
    /// Handle deep link navigation
    func handleDeepLink(_ url: URL) {
        guard let scheme = url.scheme, scheme == "streamyyy" else { return }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch pathComponents.first {
        case "multistream":
            handleMultiStreamDeepLink(pathComponents: pathComponents, queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            
        case "discover":
            handleDiscoveryDeepLink(pathComponents: pathComponents, queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            
        case "stream":
            handleStreamDeepLink(pathComponents: pathComponents, queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            
        default:
            // Navigate to home if unrecognized
            navigateToTab(.streams)
        }
    }
    
    private func handleMultiStreamDeepLink(pathComponents: [String], queryItems: [URLQueryItem]?) {
        navigateToTab(.multiStream) {
            // Handle any specific multistream configuration
            if let streamIds = queryItems?.first(where: { $0.name == "streams" })?.value {
                let ids = streamIds.components(separatedBy: ",")
                // Load specific streams based on IDs
                self.deepLinkPendingAction = {
                    // This would be handled by the MultiStreamView
                    print("Loading streams with IDs: \(ids)")
                }
            }
        }
    }
    
    private func handleDiscoveryDeepLink(pathComponents: [String], queryItems: [URLQueryItem]?) {
        let searchQuery = queryItems?.first(where: { $0.name == "search" })?.value
        navigateToDiscovery(searchQuery: searchQuery)
    }
    
    private func handleStreamDeepLink(pathComponents: [String], queryItems: [URLQueryItem]?) {
        if pathComponents.count > 1 {
            let streamId = pathComponents[1]
            push(.streamDetail(streamId: streamId))
        }
    }
    
    // MARK: - Navigation History Management
    
    private func addToHistory(_ item: NavigationItem) {
        navigationHistory.append(item)
        
        // Keep history size manageable
        if navigationHistory.count > maxHistoryItems {
            navigationHistory.removeFirst()
        }
    }
    
    /// Get navigation history for current session
    func getNavigationHistory() -> [NavigationItem] {
        return navigationHistory
    }
    
    /// Clear navigation history
    func clearHistory() {
        navigationHistory.removeAll()
    }
    
    /// Go back to previous navigation item
    func goBack() {
        guard navigationHistory.count > 1 else { return }
        
        let previousItem = navigationHistory[navigationHistory.count - 2]
        
        if let destination = previousItem.destination {
            // If previous item had a destination, push it
            navigateToTab(previousItem.tab) {
                self.push(destination)
            }
        } else {
            // Just navigate to the tab
            navigateToTab(previousItem.tab)
        }
        
        // Remove current item from history
        if !navigationHistory.isEmpty {
            navigationHistory.removeLast()
        }
    }
    
    // MARK: - Animation and Transition Helpers
    
    /// Set transition style for next navigation
    func setTransitionStyle(_ style: TransitionStyle) {
        transitionStyle = style
    }
    
    /// Get transition animation for current style
    var currentTransitionAnimation: Animation {
        return transitionStyle.animation
    }
    
    // MARK: - State Restoration
    
    /// Save current navigation state
    func saveNavigationState() {
        let state = NavigationState(
            selectedTab: selectedTab,
            navigationHistory: navigationHistory
        )
        
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "NavigationState")
        }
    }
    
    /// Restore navigation state
    func restoreNavigationState() {
        guard let data = UserDefaults.standard.data(forKey: "NavigationState"),
              let state = try? JSONDecoder().decode(NavigationState.self, from: data) else {
            return
        }
        
        selectedTab = state.selectedTab
        navigationHistory = state.navigationHistory
    }
}

// MARK: - Navigation State for Persistence
private struct NavigationState: Codable {
    let selectedTab: Int
    let navigationHistory: [NavigationCoordinator.NavigationItem]
}

// MARK: - NavigationCoordinator Extensions
extension NavigationCoordinator.NavigationItem: Codable {
    enum CodingKeys: CodingKey {
        case tab, destination, timestamp, context
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tab = try container.decode(NavigationCoordinator.Tab.self, from: .tab)
        destination = try container.decodeIfPresent(NavigationCoordinator.NavigationDestination.self, forKey: .destination)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        context = try container.decode([String: String].self, forKey: .context)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tab, forKey: .tab)
        try container.encodeIfPresent(destination, forKey: .destination)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(context, forKey: .context)
    }
}

extension NavigationCoordinator.Tab: Codable {}
extension NavigationCoordinator.NavigationDestination: Codable {}

// MARK: - Button Styles for Navigation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Navigation View Modifiers
struct NavigationCoordinatorEnvironment: ViewModifier {
    @StateObject private var coordinator = NavigationCoordinator()
    @EnvironmentObject var deepLinkHandler: DeepLinkHandler
    
    func body(content: Content) -> some View {
        content
            .environmentObject(coordinator)
            .onAppear {
                coordinator.restoreNavigationState()
                deepLinkHandler.setNavigationCoordinator(coordinator)
            }
            .onDisappear {
                coordinator.saveNavigationState()
            }
    }
}

extension View {
    func withNavigationCoordinator() -> some View {
        modifier(NavigationCoordinatorEnvironment())
    }
}