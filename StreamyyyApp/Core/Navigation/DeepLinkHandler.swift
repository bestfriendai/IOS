//
//  DeepLinkHandler.swift
//  StreamyyyApp
//
//  Deep linking support for the app
//

import SwiftUI
import Foundation

// MARK: - Deep Link Handler
@MainActor
class DeepLinkHandler: ObservableObject {
    @Published var pendingDeepLink: URL?
    
    private weak var navigationCoordinator: NavigationCoordinator?
    
    func setNavigationCoordinator(_ coordinator: NavigationCoordinator) {
        self.navigationCoordinator = coordinator
        
        // Process any pending deep links
        if let pendingURL = pendingDeepLink {
            handleDeepLink(pendingURL)
            pendingDeepLink = nil
        }
    }
    
    func handleDeepLink(_ url: URL) {
        guard let coordinator = navigationCoordinator else {
            // Store for later processing
            pendingDeepLink = url
            return
        }
        
        coordinator.handleDeepLink(url)
    }
    
    // MARK: - URL Scheme Parsing
    
    /// Parse streamyyy:// URLs
    /// Examples:
    /// - streamyyy://multistream
    /// - streamyyy://multistream?streams=stream1,stream2
    /// - streamyyy://discover?search=gaming
    /// - streamyyy://stream/123
    func parseURL(_ url: URL) -> DeepLinkDestination? {
        guard url.scheme == "streamyyy" else { return nil }
        
        let host = url.host
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        switch host {
        case "multistream":
            return parseMultiStreamLink(pathComponents: pathComponents, queryItems: queryItems)
            
        case "discover":
            return parseDiscoverLink(pathComponents: pathComponents, queryItems: queryItems)
            
        case "stream":
            return parseStreamLink(pathComponents: pathComponents, queryItems: queryItems)
            
        case "settings":
            return .settings
            
        case "favorites":
            return .favorites
            
        case "profile":
            return .profile
            
        default:
            return .home
        }
    }
    
    private func parseMultiStreamLink(pathComponents: [String], queryItems: [URLQueryItem]) -> DeepLinkDestination {
        let streamIds = queryItems.first(where: { $0.name == "streams" })?.value?.components(separatedBy: ",") ?? []
        let layout = queryItems.first(where: { $0.name == "layout" })?.value
        
        return .multiStream(streamIds: streamIds, layout: layout)
    }
    
    private func parseDiscoverLink(pathComponents: [String], queryItems: [URLQueryItem]) -> DeepLinkDestination {
        let searchQuery = queryItems.first(where: { $0.name == "search" })?.value
        let category = queryItems.first(where: { $0.name == "category" })?.value
        
        return .discover(searchQuery: searchQuery, category: category)
    }
    
    private func parseStreamLink(pathComponents: [String], queryItems: [URLQueryItem]) -> DeepLinkDestination {
        guard let streamId = pathComponents.first else { return .home }
        
        let action = queryItems.first(where: { $0.name == "action" })?.value
        
        return .streamDetail(streamId: streamId, action: action)
    }
}

// MARK: - Deep Link Destinations
enum DeepLinkDestination {
    case home
    case multiStream(streamIds: [String], layout: String?)
    case discover(searchQuery: String?, category: String?)
    case streamDetail(streamId: String, action: String?)
    case settings
    case favorites
    case profile
    
    var description: String {
        switch self {
        case .home:
            return "Home"
        case .multiStream(let streamIds, let layout):
            return "MultiStream (streams: \(streamIds.count), layout: \(layout ?? "default"))"
        case .discover(let query, let category):
            return "Discover (query: \(query ?? "none"), category: \(category ?? "none"))"
        case .streamDetail(let streamId, let action):
            return "Stream \(streamId) (action: \(action ?? "view"))"
        case .settings:
            return "Settings"
        case .favorites:
            return "Favorites"
        case .profile:
            return "Profile"
        }
    }
}

// MARK: - Deep Link URL Builder
struct DeepLinkURLBuilder {
    private static let scheme = "streamyyy"
    
    static func multiStreamURL(streamIds: [String], layout: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "multistream"
        
        var queryItems: [URLQueryItem] = []
        
        if !streamIds.isEmpty {
            queryItems.append(URLQueryItem(name: "streams", value: streamIds.joined(separator: ",")))
        }
        
        if let layout = layout {
            queryItems.append(URLQueryItem(name: "layout", value: layout))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        return components.url
    }
    
    static func discoverURL(searchQuery: String? = nil, category: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "discover"
        
        var queryItems: [URLQueryItem] = []
        
        if let searchQuery = searchQuery {
            queryItems.append(URLQueryItem(name: "search", value: searchQuery))
        }
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        return components.url
    }
    
    static func streamDetailURL(streamId: String, action: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "stream"
        components.path = "/\(streamId)"
        
        if let action = action {
            components.queryItems = [URLQueryItem(name: "action", value: action)]
        }
        
        return components.url
    }
    
    static func settingsURL() -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "settings"
        return components.url
    }
    
    static func favoritesURL() -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "favorites"
        return components.url
    }
    
    static func profileURL() -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "profile"
        return components.url
    }
}

// MARK: - App State Integration
extension NavigationCoordinator {
    func processDeepLink(_ destination: DeepLinkDestination) {
        switch destination {
        case .home:
            navigateToTab(.streams, animated: true)
            
        case .multiStream(let streamIds, let layout):
            navigateToMultiStream(animated: true)
            // TODO: Load specific streams and layout
            
        case .discover(let searchQuery, let category):
            navigateToDiscovery(searchQuery: searchQuery, animated: true)
            
        case .streamDetail(let streamId, let action):
            navigateToTab(.streams, animated: false)
            push(.streamDetail(streamId: streamId))
            
        case .settings:
            push(.settings)
            
        case .favorites:
            navigateToTab(.favorites, animated: true)
            
        case .profile:
            navigateToTab(.profile, animated: true)
        }
    }
}

// MARK: - URL Scheme Registration
extension DeepLinkHandler {
    static func registerURLSchemes() {
        // This would be called during app setup
        // URL schemes are typically registered in Info.plist
        print("Deep link URL schemes registered: streamyyy://")
    }
    
    /// Generate a shareable URL for current app state
    static func shareableURL(for coordinator: NavigationCoordinator) -> URL? {
        let currentTab = NavigationCoordinator.Tab(rawValue: coordinator.selectedTab)
        
        switch currentTab {
        case .multiStream:
            // Create URL for current multistream setup
            return DeepLinkURLBuilder.multiStreamURL(streamIds: [])
            
        case .discover:
            return DeepLinkURLBuilder.discoverURL()
            
        case .favorites:
            return DeepLinkURLBuilder.favoritesURL()
            
        case .profile:
            return DeepLinkURLBuilder.profileURL()
            
        default:
            return nil
        }
    }
}

// MARK: - View Modifier for Deep Linking
struct DeepLinkHandler_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Deep Link Handler")
                .font(.title)
            
            Text("Supports streamyyy:// URLs")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}