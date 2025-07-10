//
//  StreamyyyAppApp.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI

@main
struct StreamyyyAppApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var streamManager = StreamManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(streamManager)
                .environmentObject(subscriptionManager)
        }
    }
}

// MARK: - Authentication Manager
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        // Start with authenticated state for testing
        isAuthenticated = true
        user = User(id: "test", firstName: "Test", lastName: "User", email: "test@example.com", profileImageURL: nil, createdAt: Date())
    }
    
    func signIn(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.isAuthenticated = true
            self.user = User(id: "test", firstName: "Test", lastName: "User", email: email, profileImageURL: nil, createdAt: Date())
            self.isLoading = false
        }
    }
    
    func signUp(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.isAuthenticated = true
            self.user = User(id: "test", firstName: "Test", lastName: "User", email: email, profileImageURL: nil, createdAt: Date())
            self.isLoading = false
        }
    }
    
    func signOut() async {
        await MainActor.run {
            self.isAuthenticated = false
            self.user = nil
        }
    }
}

// MARK: - Stream Manager
class StreamManager: ObservableObject {
    @Published var streams: [StreamModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedLayout: LayoutType = .stack
    
    init() {
        // Add real Twitch streams for testing
        addRealStreams()
    }
    
    private func addRealStreams() {
        // Add real popular Twitch streams
        let realStreams = [
            StreamModel(
                id: "real-twitch-1",
                url: "https://twitch.tv/shroud",
                type: .twitch,
                title: "shroud - Just Chatting",
                isLive: true,
                viewerCount: 45000,
                isMuted: false,
                isFavorite: false,
                thumbnailURL: nil,
                channelName: "shroud",
                gameName: "Just Chatting"
            ),
            StreamModel(
                id: "real-twitch-2",
                url: "https://twitch.tv/ninja",
                type: .twitch,
                title: "Ninja - Fortnite Battle Royale",
                isLive: true,
                viewerCount: 38000,
                isMuted: false,
                isFavorite: false,
                thumbnailURL: nil,
                channelName: "ninja",
                gameName: "Fortnite"
            ),
            StreamModel(
                id: "real-twitch-3",
                url: "https://twitch.tv/xqc",
                type: .twitch,
                title: "xQc - Variety Gaming",
                isLive: true,
                viewerCount: 62000,
                isMuted: false,
                isFavorite: false,
                thumbnailURL: nil,
                channelName: "xQcOW",
                gameName: "Variety"
            ),
            StreamModel(
                id: "real-twitch-4",
                url: "https://twitch.tv/pokimane",
                type: .twitch,
                title: "Pokimane - Just Chatting",
                isLive: true,
                viewerCount: 25000,
                isMuted: false,
                isFavorite: false,
                thumbnailURL: nil,
                channelName: "pokimane",
                gameName: "Just Chatting"
            ),
            StreamModel(
                id: "real-twitch-5",
                url: "https://twitch.tv/asmongold",
                type: .twitch,
                title: "Asmongold - World of Warcraft",
                isLive: true,
                viewerCount: 34000,
                isMuted: false,
                isFavorite: false,
                thumbnailURL: nil,
                channelName: "asmongold",
                gameName: "World of Warcraft"
            ),
            StreamModel(
                id: "real-twitch-6",
                url: "https://twitch.tv/summit1g",
                type: .twitch,
                title: "summit1g - Grand Theft Auto V",
                isLive: true,
                viewerCount: 28000,
                isMuted: false,
                isFavorite: false,
                thumbnailURL: nil,
                channelName: "summit1g",
                gameName: "Grand Theft Auto V"
            )
        ]
        
        streams = realStreams
    }
    
    enum LayoutType: String, CaseIterable {
        case stack = "Stack"
        case grid2x2 = "2x2 Grid"
        case grid3x3 = "3x3 Grid"
        case carousel = "Carousel"
        case focus = "Focus"
        
        var icon: String {
            switch self {
            case .stack: return "rectangle.stack"
            case .grid2x2: return "grid"
            case .grid3x3: return "square.grid.3x3"
            case .carousel: return "rectangle.3.group"
            case .focus: return "viewfinder"
            }
        }
    }
    
    func addStream(url: String) {
        guard !url.isEmpty else { return }
        
        let streamType = determineStreamType(from: url)
        let newStream = StreamModel(
            id: UUID().uuidString,
            url: url,
            type: streamType,
            title: extractStreamTitle(from: url),
            isLive: true,
            viewerCount: Int.random(in: 100...50000),
            isMuted: false,
            isFavorite: false,
            thumbnailURL: nil,
            channelName: extractChannelName(from: url),
            gameName: nil
        )
        
        streams.append(newStream)
    }
    
    func removeStream(_ stream: StreamModel) {
        streams.removeAll { $0.id == stream.id }
    }
    
    func clearAllStreams() {
        streams.removeAll()
    }
    
    func toggleMute(for stream: StreamModel) {
        if let index = streams.firstIndex(where: { $0.id == stream.id }) {
            streams[index].isMuted.toggle()
        }
    }
    
    private func determineStreamType(from url: String) -> StreamType {
        if url.contains("twitch.tv") {
            return .twitch
        } else if url.contains("youtube.com") || url.contains("youtu.be") {
            return .youtube
        } else {
            return .other
        }
    }
    
    private func extractStreamTitle(from url: String) -> String {
        // Extract stream title from URL
        if url.contains("twitch.tv") {
            return url.components(separatedBy: "/").last ?? "Twitch Stream"
        } else if url.contains("youtube.com") {
            return "YouTube Stream"
        } else {
            return "Live Stream"
        }
    }
    
    private func extractChannelName(from url: String) -> String {
        if let url = URL(string: url) {
            let pathComponents = url.pathComponents
            if pathComponents.count > 1 {
                return pathComponents[1]
            }
        }
        return "Unknown"
    }
}

// MARK: - Subscription Manager
class SubscriptionManager: ObservableObject {
    @Published var isSubscribed = false
    @Published var subscriptionType: SubscriptionType?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    enum SubscriptionType: String, CaseIterable {
        case monthly = "Monthly Pro"
        case yearly = "Yearly Pro"
        
        var price: String {
            switch self {
            case .monthly: return "$9.99/month"
            case .yearly: return "$99.99/year"
            }
        }
        
        var features: [String] {
            return [
                "Unlimited streams",
                "Premium layouts",
                "Advanced controls",
                "Priority support",
                "No ads"
            ]
        }
    }
    
    func checkSubscriptionStatus() {
        // Check subscription status with Stripe
        // This would integrate with your existing Stripe setup
    }
    
    func subscribe(to type: SubscriptionType) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Integrate with Stripe for subscription
        // This would use your existing Stripe configuration
        
        await MainActor.run {
            self.isSubscribed = true
            self.subscriptionType = type
            self.isLoading = false
        }
    }
    
    func cancelSubscription() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Cancel subscription with Stripe
        
        await MainActor.run {
            self.isSubscribed = false
            self.subscriptionType = nil
            self.isLoading = false
        }
    }
}

// MARK: - Models
struct StreamModel: Identifiable, Codable {
    let id: String
    let url: String
    let type: StreamType
    let title: String
    var isLive: Bool
    var viewerCount: Int
    var isMuted: Bool = false
    var isFavorite: Bool = false
    var thumbnailURL: String?
    var channelName: String?
    var gameName: String?
}

enum StreamType: String, Codable, CaseIterable {
    case twitch = "twitch"
    case youtube = "youtube"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .twitch: return "Twitch"
        case .youtube: return "YouTube"
        case .other: return "Other"
        }
    }
    
    var color: Color {
        switch self {
        case .twitch: return .purple
        case .youtube: return .red
        case .other: return .blue
        }
    }
}

struct User: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let profileImageURL: String?
    let createdAt: Date
}