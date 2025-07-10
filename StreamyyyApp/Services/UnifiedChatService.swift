//
//  UnifiedChatService.swift
//  StreamyyyApp
//
//  Unified chat service supporting multiple platforms
//  Created by Claude Code on 2025-07-10
//

import Foundation
import Combine
import SwiftUI
import Network

// MARK: - Unified Chat Service

@MainActor
public class UnifiedChatService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var messages: [UnifiedChatMessage] = []
    @Published private(set) var connectionStatus: ChatConnectionStatus = .disconnected
    @Published private(set) var viewerCount: Int = 0
    @Published private(set) var isEnabled: Bool = true
    
    // MARK: - Private Properties
    
    private var twitchChatManager: TwitchChatManager?
    private var youtubeChatManager: YouTubeChatManager?
    private var rumbleChatManager: RumbleChatManager?
    
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    
    private let maxMessages = 200
    
    // MARK: - Configuration
    
    public struct ChatConfiguration {
        public let platform: Platform
        public let channelIdentifier: String
        public let showEmotes: Bool
        public let showBadges: Bool
        public let showTimestamps: Bool
        public let autoReconnect: Bool
        public let moderationEnabled: Bool
        
        public init(
            platform: Platform,
            channelIdentifier: String,
            showEmotes: Bool = true,
            showBadges: Bool = true,
            showTimestamps: Bool = true,
            autoReconnect: Bool = true,
            moderationEnabled: Bool = true
        ) {
            self.platform = platform
            self.channelIdentifier = channelIdentifier
            self.showEmotes = showEmotes
            self.showBadges = showBadges
            self.showTimestamps = showTimestamps
            self.autoReconnect = autoReconnect
            self.moderationEnabled = moderationEnabled
        }
    }
    
    private var currentConfiguration: ChatConfiguration?
    
    // MARK: - Initialization
    
    public init() {
        setupNetworkMonitoring()
    }
    
    deinit {
        disconnectFromAll()
        networkMonitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Connect to chat for the specified platform
    public func connect(with configuration: ChatConfiguration) async throws {
        currentConfiguration = configuration
        await disconnect()
        
        connectionStatus = .connecting
        
        do {
            switch configuration.platform {
            case .twitch:
                try await connectToTwitch(configuration)
            case .youtube:
                try await connectToYouTube(configuration)
            case .rumble:
                try await connectToRumble(configuration)
            default:
                throw ChatServiceError.platformNotSupported(configuration.platform)
            }
            
            connectionStatus = .connected
        } catch {
            connectionStatus = .error(error)
            throw error
        }
    }
    
    /// Disconnect from current chat
    public func disconnect() async {
        connectionStatus = .disconnecting
        
        twitchChatManager?.disconnect()
        youtubeChatManager?.disconnect()
        rumbleChatManager?.disconnect()
        
        twitchChatManager = nil
        youtubeChatManager = nil
        rumbleChatManager = nil
        
        connectionStatus = .disconnected
        messages.removeAll()
    }
    
    /// Send a message to the current chat
    public func sendMessage(_ content: String) async throws {
        guard let config = currentConfiguration else {
            throw ChatServiceError.notConnected
        }
        
        switch config.platform {
        case .twitch:
            try await twitchChatManager?.sendMessage(content)
        case .youtube:
            try await youtubeChatManager?.sendMessage(content)
        case .rumble:
            try await rumbleChatManager?.sendMessage(content)
        default:
            throw ChatServiceError.platformNotSupported(config.platform)
        }
    }
    
    /// Clear all chat messages
    public func clearMessages() {
        messages.removeAll()
    }
    
    /// Toggle chat enabled state
    public func toggleEnabled() {
        isEnabled.toggle()
        
        if !isEnabled {
            Task {
                await disconnect()
            }
        } else if let config = currentConfiguration {
            Task {
                try await connect(with: config)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status != .satisfied && self?.connectionStatus == .connected {
                    self?.connectionStatus = .error(ChatServiceError.networkUnavailable)
                }
            }
        }
        
        let queue = DispatchQueue(label: "ChatNetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func connectToTwitch(_ config: ChatConfiguration) async throws {
        twitchChatManager = TwitchChatManager()
        
        twitchChatManager?.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.addMessage(message.toUnified(platform: .twitch))
            }
        }
        
        twitchChatManager?.onViewerCountUpdated = { [weak self] count in
            Task { @MainActor in
                self?.viewerCount = count
            }
        }
        
        try await twitchChatManager?.connect(to: config.channelIdentifier)
    }
    
    private func connectToYouTube(_ config: ChatConfiguration) async throws {
        youtubeChatManager = YouTubeChatManager()
        
        youtubeChatManager?.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.addMessage(message.toUnified(platform: .youtube))
            }
        }
        
        youtubeChatManager?.onViewerCountUpdated = { [weak self] count in
            Task { @MainActor in
                self?.viewerCount = count
            }
        }
        
        try await youtubeChatManager?.connect(to: config.channelIdentifier)
    }
    
    private func connectToRumble(_ config: ChatConfiguration) async throws {
        rumbleChatManager = RumbleChatManager()
        
        rumbleChatManager?.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.addMessage(message.toUnified(platform: .rumble))
            }
        }
        
        try await rumbleChatManager?.connect(to: config.channelIdentifier)
    }
    
    private func addMessage(_ message: UnifiedChatMessage) {
        messages.append(message)
        
        // Limit messages to prevent memory issues
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
    }
    
    private func disconnectFromAll() {
        twitchChatManager?.disconnect()
        youtubeChatManager?.disconnect()
        rumbleChatManager?.disconnect()
    }
}

// MARK: - Chat Connection Status

public enum ChatConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(Error)
    
    public static func == (lhs: ChatConnectionStatus, rhs: ChatConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected),
             (.disconnecting, .disconnecting):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
    public var displayName: String {
        switch self {
        case .disconnected: return "Offline"
        case .connecting: return "Connecting"
        case .connected: return "Live"
        case .disconnecting: return "Disconnecting"
        case .error: return "Error"
        }
    }
    
    public var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .disconnecting: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Unified Chat Message

public struct UnifiedChatMessage: Identifiable, Hashable {
    public let id: String
    public let platform: Platform
    public let username: String
    public let displayName: String?
    public let userColor: String?
    public let content: String
    public let timestamp: Date
    public let badges: [UnifiedChatBadge]
    public let emotes: [UnifiedChatEmote]
    public let isSubscriber: Bool
    public let isModerator: Bool
    public let isVIP: Bool
    public let isOwner: Bool
    public let messageType: MessageType
    
    public enum MessageType {
        case regular
        case subscription
        case donation
        case raid
        case systemMessage
    }
    
    public init(
        id: String = UUID().uuidString,
        platform: Platform,
        username: String,
        displayName: String? = nil,
        userColor: String? = nil,
        content: String,
        timestamp: Date = Date(),
        badges: [UnifiedChatBadge] = [],
        emotes: [UnifiedChatEmote] = [],
        isSubscriber: Bool = false,
        isModerator: Bool = false,
        isVIP: Bool = false,
        isOwner: Bool = false,
        messageType: MessageType = .regular
    ) {
        self.id = id
        self.platform = platform
        self.username = username
        self.displayName = displayName
        self.userColor = userColor
        self.content = content
        self.timestamp = timestamp
        self.badges = badges
        self.emotes = emotes
        self.isSubscriber = isSubscriber
        self.isModerator = isModerator
        self.isVIP = isVIP
        self.isOwner = isOwner
        self.messageType = messageType
    }
}

// MARK: - Unified Chat Badge

public struct UnifiedChatBadge: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let imageURL: String
    public let platform: Platform
    
    public init(id: String, name: String, imageURL: String, platform: Platform) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.platform = platform
    }
}

// MARK: - Unified Chat Emote

public struct UnifiedChatEmote: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let imageURL: String
    public let platform: Platform
    public let range: NSRange
    
    public init(id: String, name: String, imageURL: String, platform: Platform, range: NSRange) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.platform = platform
        self.range = range
    }
}

// MARK: - Chat Service Errors

public enum ChatServiceError: Error, LocalizedError {
    case platformNotSupported(Platform)
    case notConnected
    case networkUnavailable
    case authenticationFailed
    case rateLimitExceeded
    case invalidChannel
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .platformNotSupported(let platform):
            return "Chat not supported for \(platform.displayName)"
        case .notConnected:
            return "Not connected to chat"
        case .networkUnavailable:
            return "Network unavailable"
        case .authenticationFailed:
            return "Authentication failed"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .invalidChannel:
            return "Invalid channel"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Platform-specific Chat Managers

// MARK: YouTube Chat Manager
class YouTubeChatManager {
    var onMessageReceived: ((YouTubeChatMessage) -> Void)?
    var onViewerCountUpdated: ((Int) -> Void)?
    
    func connect(to videoId: String) async throws {
        // Implementation for YouTube Live Chat API
        // This would require YouTube Data API v3 integration
        print("Connecting to YouTube chat for video: \(videoId)")
        
        // Simulate connection
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Start mock message generation for demo
        startMockMessages()
    }
    
    func disconnect() {
        print("Disconnecting from YouTube chat")
    }
    
    func sendMessage(_ content: String) async throws {
        // Implementation for sending messages via YouTube API
        print("Sending YouTube message: \(content)")
    }
    
    private func startMockMessages() {
        let mockMessages = [
            "Great video! 👍",
            "First!",
            "Amazing content",
            "Subscribe!",
            "Love this channel ❤️"
        ]
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            let message = YouTubeChatMessage(
                id: UUID().uuidString,
                authorName: "YouTubeViewer\(Int.random(in: 1...100))",
                message: mockMessages.randomElement()!,
                timestamp: Date()
            )
            self.onMessageReceived?(message)
        }
    }
}

struct YouTubeChatMessage {
    let id: String
    let authorName: String
    let message: String
    let timestamp: Date
    
    func toUnified(platform: Platform) -> UnifiedChatMessage {
        return UnifiedChatMessage(
            id: id,
            platform: platform,
            username: authorName,
            content: message,
            timestamp: timestamp
        )
    }
}

// MARK: Rumble Chat Manager
class RumbleChatManager {
    var onMessageReceived: ((RumbleChatMessage) -> Void)?
    
    func connect(to channelId: String) async throws {
        // Implementation for Rumble chat (likely WebSocket or polling)
        print("Connecting to Rumble chat for channel: \(channelId)")
        
        // Simulate connection
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Start mock message generation for demo
        startMockMessages()
    }
    
    func disconnect() {
        print("Disconnecting from Rumble chat")
    }
    
    func sendMessage(_ content: String) async throws {
        // Implementation for sending messages to Rumble
        print("Sending Rumble message: \(content)")
    }
    
    private func startMockMessages() {
        let mockMessages = [
            "Rumble rocks! 🚀",
            "Free speech platform!",
            "Great content here",
            "Supporting creators",
            "Rumble family! 💪"
        ]
        
        Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            let message = RumbleChatMessage(
                id: UUID().uuidString,
                username: "RumbleUser\(Int.random(in: 1...100))",
                content: mockMessages.randomElement()!,
                timestamp: Date()
            )
            self.onMessageReceived?(message)
        }
    }
}

struct RumbleChatMessage {
    let id: String
    let username: String
    let content: String
    let timestamp: Date
    
    func toUnified(platform: Platform) -> UnifiedChatMessage {
        return UnifiedChatMessage(
            id: id,
            platform: platform,
            username: username,
            content: content,
            timestamp: timestamp
        )
    }
}

// MARK: - Extensions

extension ChatMessage {
    func toUnified(platform: Platform) -> UnifiedChatMessage {
        return UnifiedChatMessage(
            id: id,
            platform: platform,
            username: username,
            userColor: userColor,
            content: content,
            timestamp: timestamp,
            badges: badges.map { badge in
                UnifiedChatBadge(
                    id: badge.id,
                    name: badge.name,
                    imageURL: badge.imageURL,
                    platform: platform
                )
            },
            emotes: emotes.map { emote in
                UnifiedChatEmote(
                    id: emote.id,
                    name: emote.name,
                    imageURL: emote.imageURL,
                    platform: platform,
                    range: emote.range
                )
            },
            isSubscriber: isSubscriber,
            isModerator: isModerator,
            isVIP: isVIP
        )
    }
}

// MARK: - Enhanced TwitchChatManager Extension

extension TwitchChatManager {
    var onViewerCountUpdated: ((Int) -> Void)?
    
    func connect(to channelName: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.connect(to: channelName) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func sendMessage(_ content: String) async throws {
        // Implementation for sending Twitch messages
        print("Sending Twitch message: \(content)")
    }
}