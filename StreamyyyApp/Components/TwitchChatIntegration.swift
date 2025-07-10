//
//  TwitchChatIntegration.swift
//  StreamyyyApp
//
//  Real-time Twitch chat integration with emotes and messaging
//  Created by Streamyyy Team
//

import SwiftUI
import WebKit
import Combine
import Network

// MARK: - Twitch Chat Integration View
struct TwitchChatIntegrationView: View {
    let channelName: String
    @Binding var isVisible: Bool
    @Binding var chatMessages: [ChatMessage]
    
    // Chat configuration
    let showEmotes: Bool
    let showBadges: Bool
    let showTimestamps: Bool
    let maxMessages: Int
    
    // Chat manager
    @StateObject private var chatManager = TwitchChatManager()
    @State private var isLoading = false
    @State private var hasError = false
    @State private var connectionStatus: ConnectionStatus = .disconnected
    
    init(
        channelName: String,
        isVisible: Binding<Bool>,
        chatMessages: Binding<[ChatMessage]>,
        showEmotes: Bool = true,
        showBadges: Bool = true,
        showTimestamps: Bool = true,
        maxMessages: Int = 100
    ) {
        self.channelName = channelName
        self._isVisible = isVisible
        self._chatMessages = chatMessages
        self.showEmotes = showEmotes
        self.showBadges = showBadges
        self.showTimestamps = showTimestamps
        self.maxMessages = maxMessages
    }
    
    var body: some View {
        ZStack {
            if isVisible {
                VStack {
                    // Chat header
                    chatHeader
                    
                    // Chat messages
                    chatMessagesView
                    
                    // Connection status
                    if connectionStatus != .connected {
                        connectionStatusView
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.9))
                        .backdrop(BlurEffect(style: .dark))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
            }
        }
        .onAppear {
            connectToChat()
        }
        .onDisappear {
            chatManager.disconnect()
        }
        .onChange(of: channelName) { _, newChannel in
            if !newChannel.isEmpty {
                connectToChat()
            }
        }
    }
    
    private var chatHeader: some View {
        HStack {
            // Twitch logo
            Image(systemName: "tv.circle.fill")
                .foregroundColor(.purple)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Twitch Chat")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(channelName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Connection indicator
            connectionIndicator
            
            // Close button
            Button(action: { isVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
        }
        .padding()
    }
    
    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionStatus.color)
                .frame(width: 8, height: 8)
            
            Text(connectionStatus.displayName)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    private var chatMessagesView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(chatMessages) { message in
                    ChatMessageView(
                        message: message,
                        showEmotes: showEmotes,
                        showBadges: showBadges,
                        showTimestamps: showTimestamps
                    )
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 400)
    }
    
    private var connectionStatusView: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                Text("Connecting to chat...")
            } else if hasError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Failed to connect to chat")
                Button("Retry") {
                    connectToChat()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .font(.caption)
        .foregroundColor(.white)
        .padding()
    }
    
    private func connectToChat() {
        isLoading = true
        hasError = false
        connectionStatus = .connecting
        
        chatManager.connect(to: channelName) { [self] result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    connectionStatus = .connected
                    hasError = false
                    
                    // Start receiving messages
                    chatManager.onMessageReceived = { message in
                        DispatchQueue.main.async {
                            chatMessages.append(message)
                            
                            // Limit messages to prevent memory issues
                            if chatMessages.count > maxMessages {
                                chatMessages.removeFirst(chatMessages.count - maxMessages)
                            }
                        }
                    }
                    
                case .failure(let error):
                    connectionStatus = .disconnected
                    hasError = true
                    print("Chat connection failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Chat Message View
struct ChatMessageView: View {
    let message: ChatMessage
    let showEmotes: Bool
    let showBadges: Bool
    let showTimestamps: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Message header (badges, username, timestamp)
            HStack(spacing: 6) {
                // Badges
                if showBadges && !message.badges.isEmpty {
                    ForEach(message.badges, id: \.self) { badge in
                        BadgeView(badge: badge)
                    }
                }
                
                // Username
                Text(message.username)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: message.userColor) ?? .purple)
                
                // Timestamp
                if showTimestamps {
                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // Message content
            MessageContentView(
                content: message.content,
                emotes: message.emotes,
                showEmotes: showEmotes
            )
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Badge View
struct BadgeView: View {
    let badge: ChatBadge
    
    var body: some View {
        AsyncImage(url: URL(string: badge.imageURL)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
        }
        .frame(width: 16, height: 16)
        .cornerRadius(2)
    }
}

// MARK: - Message Content View
struct MessageContentView: View {
    let content: String
    let emotes: [ChatEmote]
    let showEmotes: Bool
    
    var body: some View {
        if showEmotes && !emotes.isEmpty {
            // Process content with emotes
            EmoteProcessedText(content: content, emotes: emotes)
        } else {
            Text(content)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(nil)
        }
    }
}

// MARK: - Emote Processed Text
struct EmoteProcessedText: View {
    let content: String
    let emotes: [ChatEmote]
    
    var body: some View {
        // This would need to be implemented with attributed text
        // For now, showing simple text
        Text(content)
            .font(.caption)
            .foregroundColor(.white)
            .lineLimit(nil)
    }
}

// MARK: - Twitch Chat Manager
class TwitchChatManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private let networkMonitor = NWPathMonitor()
    
    var onMessageReceived: ((ChatMessage) -> Void)?
    
    init() {
        self.urlSession = URLSession.shared
        
        // Monitor network connectivity
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                // Network is available
            } else {
                // Network is unavailable
                self?.disconnect()
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    func connect(to channelName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // For real implementation, this would connect to Twitch IRC WebSocket
        // For demo purposes, we'll simulate connection and generate mock messages
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success(()))
            
            // Start generating mock messages
            self.startMockMessageGeneration(for: channelName)
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    private func startMockMessageGeneration(for channelName: String) {
        // Generate mock chat messages for demo
        let mockUsers = [
            ("StreamFan123", "#FF6B6B"),
            ("GameMaster", "#4ECDC4"),
            ("ChatModerator", "#45B7D1"),
            ("ViewerPro", "#96CEB4"),
            ("StreamLover", "#FFEAA7")
        ]
        
        let mockMessages = [
            "Great stream! 🎮",
            "PogChamp",
            "This is amazing!",
            "Kappa",
            "Good play!",
            "HYPE!",
            "LUL",
            "Nice job!",
            "Kreygasm",
            "Ez Clap"
        ]
        
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            let randomUser = mockUsers.randomElement()!
            let randomMessage = mockMessages.randomElement()!
            
            let message = ChatMessage(
                id: UUID().uuidString,
                username: randomUser.0,
                userColor: randomUser.1,
                content: randomMessage,
                timestamp: Date(),
                badges: [],
                emotes: [],
                isSubscriber: Bool.random(),
                isModerator: false,
                isVIP: false
            )
            
            self.onMessageReceived?(message)
        }
    }
}

// MARK: - Data Models

struct ChatMessage: Identifiable {
    let id: String
    let username: String
    let userColor: String
    let content: String
    let timestamp: Date
    let badges: [ChatBadge]
    let emotes: [ChatEmote]
    let isSubscriber: Bool
    let isModerator: Bool
    let isVIP: Bool
}

struct ChatBadge: Hashable {
    let id: String
    let name: String
    let imageURL: String
}

struct ChatEmote: Identifiable {
    let id: String
    let name: String
    let imageURL: String
    let range: NSRange
}

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error
    
    var displayName: String {
        switch self {
        case .disconnected: return "Offline"
        case .connecting: return "Connecting"
        case .connected: return "Live"
        case .error: return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

// MARK: - Backdrop Effect
struct BlurEffect: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Enhanced Twitch Stream View with Chat
struct TwitchStreamWithChatView: View {
    let channelName: String
    @State private var isLoading = false
    @State private var hasError = false
    @State private var currentQuality = StreamQuality.auto
    @State private var isLive = false
    @State private var viewerCount = 0
    @State private var isMuted = false
    @State private var showChat = true
    @State private var chatMessages: [ChatMessage] = []
    
    var body: some View {
        ZStack {
            // Main stream view
            TwitchEmbedWebView(
                channelName: channelName,
                chatEnabled: false, // We handle chat separately
                quality: currentQuality,
                isLoading: $isLoading,
                hasError: $hasError,
                isLive: $isLive,
                viewerCount: $viewerCount,
                currentQuality: $currentQuality
            )
            
            // Chat overlay
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    if showChat {
                        TwitchChatIntegrationView(
                            channelName: channelName,
                            isVisible: $showChat,
                            chatMessages: $chatMessages
                        )
                        .frame(width: 300, height: 400)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding()
            }
            
            // Chat toggle button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { 
                        withAnimation(.spring()) {
                            showChat.toggle()
                        }
                    }) {
                        Image(systemName: showChat ? "bubble.left.fill" : "bubble.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.purple.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
            }
            
            // Stream controls
            VStack {
                HStack {
                    // Live indicator
                    if isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Quality indicator
                    Text(currentQuality.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    
                    // Mute button
                    Button(action: { isMuted.toggle() }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .cornerRadius(12)
        .clipped()
    }
}

// MARK: - Preview
#Preview {
    TwitchStreamWithChatView(channelName: "shroud")
        .frame(height: 400)
        .padding()
}