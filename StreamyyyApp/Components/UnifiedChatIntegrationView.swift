//
//  UnifiedChatIntegrationView.swift
//  StreamyyyApp
//
//  Unified chat integration supporting multiple platforms
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import Combine

// MARK: - Unified Chat Integration View

struct UnifiedChatIntegrationView: View {
    let platform: Platform
    let channelIdentifier: String
    @Binding var isVisible: Bool
    
    // Configuration
    let showEmotes: Bool
    let showBadges: Bool
    let showTimestamps: Bool
    let showPlatformIndicators: Bool
    
    // Chat service
    @StateObject private var chatService = UnifiedChatService()
    @State private var messageInput = ""
    @State private var isInputFocused = false
    
    // UI State
    @State private var scrollProxy: ScrollViewReader?
    
    init(
        platform: Platform,
        channelIdentifier: String,
        isVisible: Binding<Bool>,
        showEmotes: Bool = true,
        showBadges: Bool = true,
        showTimestamps: Bool = true,
        showPlatformIndicators: Bool = true
    ) {
        self.platform = platform
        self.channelIdentifier = channelIdentifier
        self._isVisible = isVisible
        self.showEmotes = showEmotes
        self.showBadges = showBadges
        self.showTimestamps = showTimestamps
        self.showPlatformIndicators = showPlatformIndicators
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader
            
            // Messages area
            chatMessagesView
            
            // Message input (if supported)
            if platform.supportsChat && chatService.connectionStatus == .connected {
                messageInputView
            }
        }
        .background(chatBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .onAppear {
            connectToChat()
        }
        .onDisappear {
            Task {
                await chatService.disconnect()
            }
        }
        .onChange(of: channelIdentifier) { _, newIdentifier in
            if !newIdentifier.isEmpty {
                connectToChat()
            }
        }
    }
    
    // MARK: - Chat Header
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Platform icon and info
            HStack(spacing: 8) {
                Image(systemName: platform.systemImage)
                    .font(.title2)
                    .foregroundColor(platform.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(platform.displayName) Chat")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(channelIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Viewer count (if available)
            if chatService.viewerCount > 0 {
                viewerCountView
            }
            
            // Connection status
            connectionStatusView
            
            // Close button
            Button(action: { isVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
    
    private var viewerCountView: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.fill")
                .font(.caption)
            Text("\(chatService.viewerCount.formatted())")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
    
    private var connectionStatusView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(chatService.connectionStatus.color)
                .frame(width: 8, height: 8)
            
            Text(chatService.connectionStatus.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.6), in: Capsule())
    }
    
    // MARK: - Messages View
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if chatService.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(chatService.messages) { message in
                            UnifiedChatMessageView(
                                message: message,
                                showEmotes: showEmotes,
                                showBadges: showBadges,
                                showTimestamps: showTimestamps,
                                showPlatformIndicator: showPlatformIndicators
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: chatService.messages.count) { _, _ in
                scrollToBottom()
            }
        }
        .frame(maxHeight: 300)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("No messages yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if chatService.connectionStatus == .connecting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: platform.color))
                    .scaleEffect(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Message Input
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(messageInput.isEmpty ? .secondary : platform.color)
                }
                .disabled(messageInput.isEmpty)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }
    
    // MARK: - Background
    
    private var chatBackgroundView: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(platform.color.opacity(0.3), lineWidth: 1)
            )
    }
    
    // MARK: - Actions
    
    private func connectToChat() {
        let config = UnifiedChatService.ChatConfiguration(
            platform: platform,
            channelIdentifier: channelIdentifier,
            showEmotes: showEmotes,
            showBadges: showBadges,
            showTimestamps: showTimestamps
        )
        
        Task {
            do {
                try await chatService.connect(with: config)
            } catch {
                print("Failed to connect to chat: \(error)")
            }
        }
    }
    
    private func sendMessage() {
        guard !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = messageInput
        messageInput = ""
        
        Task {
            do {
                try await chatService.sendMessage(message)
            } catch {
                print("Failed to send message: \(error)")
                // Could show error alert here
            }
        }
    }
    
    private func scrollToBottom() {
        guard let lastMessage = chatService.messages.last else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Unified Chat Message View

struct UnifiedChatMessageView: View {
    let message: UnifiedChatMessage
    let showEmotes: Bool
    let showBadges: Bool
    let showTimestamps: Bool
    let showPlatformIndicator: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Message header
            HStack(spacing: 6) {
                // Platform indicator
                if showPlatformIndicator {
                    platformIndicator
                }
                
                // Badges
                if showBadges && !message.badges.isEmpty {
                    badgesView
                }
                
                // Username
                usernameView
                
                // Timestamp
                if showTimestamps {
                    timestampView
                }
                
                Spacer()
            }
            
            // Message content
            messageContentView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(messageBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var platformIndicator: some View {
        Image(systemName: message.platform.icon)
            .font(.caption2)
            .foregroundColor(message.platform.color)
            .frame(width: 12, height: 12)
    }
    
    private var badgesView: some View {
        HStack(spacing: 2) {
            ForEach(message.badges) { badge in
                AsyncImage(url: URL(string: badge.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
    }
    
    private var usernameView: some View {
        Text(message.displayName ?? message.username)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(userColor)
    }
    
    private var userColor: Color {
        if let colorString = message.userColor {
            return Color(hex: colorString) ?? message.platform.color
        }
        return message.platform.color
    }
    
    private var timestampView: some View {
        Text(message.timestamp.formatted(.dateTime.hour().minute()))
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    
    private var messageContentView: some View {
        Text(message.content)
            .font(.caption)
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var messageBackgroundColor: Color {
        switch message.messageType {
        case .regular:
            return .black.opacity(0.1)
        case .subscription:
            return message.platform.color.opacity(0.1)
        case .donation:
            return .yellow.opacity(0.1)
        case .raid:
            return .purple.opacity(0.1)
        case .systemMessage:
            return .gray.opacity(0.1)
        }
    }
}

// MARK: - Enhanced Multi-Stream View with Unified Chat

struct EnhancedMultiStreamView: View {
    let streams: [Stream]
    @State private var selectedStreamForChat: Stream?
    @State private var showChat = false
    @State private var chatPlatform: Platform = .twitch
    @State private var chatIdentifier = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Stream grid
                StreamGridLayout(streams: streams, geometry: geometry)
                    .onTapGesture { location in
                        if let stream = getStreamAt(location: location, geometry: geometry) {
                            selectedStreamForChat = stream
                            configureChatForStream(stream)
                        }
                    }
                
                // Chat overlay
                if showChat && !chatIdentifier.isEmpty {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            UnifiedChatIntegrationView(
                                platform: chatPlatform,
                                channelIdentifier: chatIdentifier,
                                isVisible: $showChat
                            )
                            .frame(width: 350, height: 450)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        .padding()
                    }
                }
                
                // Chat controls
                VStack {
                    HStack {
                        Spacer()
                        
                        if selectedStreamForChat != nil {
                            Button(action: {
                                withAnimation(.spring()) {
                                    showChat.toggle()
                                }
                            }) {
                                Label("Chat", systemImage: showChat ? "bubble.left.fill" : "bubble.left")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(chatPlatform.color.opacity(0.8))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
        }
    }
    
    private func configureChatForStream(_ stream: Stream) {
        chatPlatform = stream.platform
        
        // Extract chat identifier based on platform
        switch stream.platform {
        case .twitch:
            chatIdentifier = stream.channelName ?? ""
        case .youtube:
            chatIdentifier = stream.streamID ?? ""
        case .rumble:
            chatIdentifier = stream.channelName ?? ""
        default:
            chatIdentifier = stream.channelName ?? ""
        }
    }
    
    private func getStreamAt(location: CGPoint, geometry: GeometryProxy) -> Stream? {
        // Implementation would depend on grid layout
        // This is a simplified example
        return streams.first
    }
}

// MARK: - Stream Grid Layout Helper

struct StreamGridLayout: View {
    let streams: [Stream]
    let geometry: GeometryProxy
    
    var body: some View {
        // Simplified grid layout
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(streams) { stream in
                StreamThumbnailView(stream: stream)
                    .aspectRatio(16/9, contentMode: .fit)
            }
        }
        .padding()
    }
    
    private var gridColumns: [GridItem] {
        let count = min(streams.count, 4)
        return Array(repeating: GridItem(.flexible()), count: count)
    }
}

// MARK: - Stream Thumbnail View

struct StreamThumbnailView: View {
    let stream: Stream
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(stream.platform.color.opacity(0.3))
            .overlay(
                VStack {
                    Image(systemName: stream.platform.systemImage)
                        .font(.title)
                        .foregroundColor(stream.platform.color)
                    
                    Text(stream.title ?? "Stream")
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding()
            )
    }
}

// MARK: - Preview

#Preview {
    UnifiedChatIntegrationView(
        platform: .twitch,
        channelIdentifier: "shroud",
        isVisible: .constant(true)
    )
    .frame(width: 350, height: 450)
    .padding()
}