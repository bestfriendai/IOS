//
//  WatchPartyManager.swift
//  StreamyyyApp
//
//  Watch party and synchronized viewing system
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import Combine
import Network

// MARK: - Watch Party Manager
@MainActor
class WatchPartyManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentParty: WatchParty?
    @Published var availableParties: [WatchParty] = []
    @Published var partyInvitations: [PartyInvitation] = []
    @Published var isHosting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var syncStatus: SyncStatus = .synced
    @Published var partyMembers: [PartyMember] = []
    @Published var chatMessages: [PartyChatMessage] = []
    @Published var streamQueue: [TwitchStream] = []
    @Published var currentStreamIndex: Int = 0
    @Published var playbackState: PlaybackState = .stopped
    @Published var syncOffset: TimeInterval = 0
    
    // MARK: - Private Properties
    private var webSocketManager: WebSocketManager
    private var heartbeatTimer: Timer?
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private var currentUserId: String {
        return userDefaults.string(forKey: "user_id") ?? UUID().uuidString
    }
    
    // MARK: - Initialization
    init() {
        self.webSocketManager = WebSocketManager()
        setupWebSocketConnection()
        setupSyncTimer()
    }
    
    // MARK: - Party Management
    func createWatchParty(name: String, streams: [TwitchStream], isPrivate: Bool = false) {
        let party = WatchParty(
            id: UUID().uuidString,
            name: name,
            hostId: currentUserId,
            streams: streams,
            isPrivate: isPrivate,
            createdAt: Date()
        )
        
        currentParty = party
        isHosting = true
        streamQueue = streams
        currentStreamIndex = 0
        
        // Create party on server
        webSocketManager.send(.createParty(party))
        
        // Start heartbeat
        startHeartbeat()
        
        // Notify party created
        NotificationCenter.default.post(
            name: .watchPartyCreated,
            object: party
        )
    }
    
    func joinWatchParty(_ party: WatchParty, password: String? = nil) {
        let joinRequest = JoinPartyRequest(
            partyId: party.id,
            userId: currentUserId,
            password: password
        )
        
        webSocketManager.send(.joinParty(joinRequest))
        currentParty = party
        isHosting = false
    }
    
    func leaveWatchParty() {
        guard let party = currentParty else { return }
        
        let leaveRequest = LeavePartyRequest(
            partyId: party.id,
            userId: currentUserId
        )
        
        webSocketManager.send(.leaveParty(leaveRequest))
        
        // Clean up
        currentParty = nil
        isHosting = false
        partyMembers.removeAll()
        chatMessages.removeAll()
        streamQueue.removeAll()
        stopHeartbeat()
        
        // Notify party left
        NotificationCenter.default.post(
            name: .watchPartyLeft,
            object: party
        )
    }
    
    func inviteToWatchParty(userIds: [String]) {
        guard let party = currentParty, isHosting else { return }
        
        let invitation = PartyInvitation(
            id: UUID().uuidString,
            partyId: party.id,
            fromUserId: currentUserId,
            toUserIds: userIds,
            message: "Join me for a watch party!",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour
        )
        
        webSocketManager.send(.sendInvitation(invitation))
    }
    
    func respondToInvitation(_ invitation: PartyInvitation, accept: Bool) {
        let response = InvitationResponse(
            invitationId: invitation.id,
            userId: currentUserId,
            accepted: accept
        )
        
        webSocketManager.send(.respondToInvitation(response))
        
        // Remove invitation from list
        partyInvitations.removeAll { $0.id == invitation.id }
        
        if accept {
            // Join the party
            if let party = availableParties.first(where: { $0.id == invitation.partyId }) {
                joinWatchParty(party)
            }
        }
    }
    
    // MARK: - Stream Queue Management
    func addStreamToQueue(_ stream: TwitchStream) {
        guard isHosting else { return }
        
        streamQueue.append(stream)
        
        let queueUpdate = QueueUpdate(
            partyId: currentParty?.id ?? "",
            streams: streamQueue,
            currentIndex: currentStreamIndex
        )
        
        webSocketManager.send(.updateQueue(queueUpdate))
    }
    
    func removeStreamFromQueue(at index: Int) {
        guard isHosting, index < streamQueue.count else { return }
        
        streamQueue.remove(at: index)
        
        // Adjust current index if necessary
        if index <= currentStreamIndex && currentStreamIndex > 0 {
            currentStreamIndex -= 1
        }
        
        let queueUpdate = QueueUpdate(
            partyId: currentParty?.id ?? "",
            streams: streamQueue,
            currentIndex: currentStreamIndex
        )
        
        webSocketManager.send(.updateQueue(queueUpdate))
    }
    
    func playNextStream() {
        guard isHosting, currentStreamIndex < streamQueue.count - 1 else { return }
        
        currentStreamIndex += 1
        syncStreamChange()
    }
    
    func playPreviousStream() {
        guard isHosting, currentStreamIndex > 0 else { return }
        
        currentStreamIndex -= 1
        syncStreamChange()
    }
    
    func skipToStream(at index: Int) {
        guard isHosting, index >= 0, index < streamQueue.count else { return }
        
        currentStreamIndex = index
        syncStreamChange()
    }
    
    // MARK: - Playback Synchronization
    func syncPlay() {
        guard isHosting else { return }
        
        playbackState = .playing
        
        let syncCommand = SyncCommand(
            partyId: currentParty?.id ?? "",
            action: .play,
            timestamp: Date(),
            streamIndex: currentStreamIndex,
            playbackPosition: 0 // Would be actual position in real implementation
        )
        
        webSocketManager.send(.syncCommand(syncCommand))
    }
    
    func syncPause() {
        guard isHosting else { return }
        
        playbackState = .paused
        
        let syncCommand = SyncCommand(
            partyId: currentParty?.id ?? "",
            action: .pause,
            timestamp: Date(),
            streamIndex: currentStreamIndex,
            playbackPosition: 0 // Would be actual position in real implementation
        )
        
        webSocketManager.send(.syncCommand(syncCommand))
    }
    
    func syncSeek(to position: TimeInterval) {
        guard isHosting else { return }
        
        let syncCommand = SyncCommand(
            partyId: currentParty?.id ?? "",
            action: .seek,
            timestamp: Date(),
            streamIndex: currentStreamIndex,
            playbackPosition: position
        )
        
        webSocketManager.send(.syncCommand(syncCommand))
    }
    
    private func syncStreamChange() {
        let syncCommand = SyncCommand(
            partyId: currentParty?.id ?? "",
            action: .changeStream,
            timestamp: Date(),
            streamIndex: currentStreamIndex,
            playbackPosition: 0
        )
        
        webSocketManager.send(.syncCommand(syncCommand))
    }
    
    // MARK: - Chat Management
    func sendChatMessage(_ text: String, type: MessageType = .text) {
        guard let party = currentParty else { return }
        
        let message = PartyChatMessage(
            id: UUID().uuidString,
            partyId: party.id,
            userId: currentUserId,
            username: getUserDisplayName(),
            text: text,
            type: type,
            timestamp: Date()
        )
        
        chatMessages.append(message)
        webSocketManager.send(.chatMessage(message))
    }
    
    func sendReaction(_ reaction: ReactionType) {
        sendChatMessage(reaction.emoji, type: .reaction)
    }
    
    func sendStreamHighlight(timestamp: TimeInterval, description: String) {
        let highlightText = "🎯 Highlight at \(formatTime(timestamp)): \(description)"
        sendChatMessage(highlightText, type: .highlight)
    }
    
    // MARK: - Party Discovery
    func discoverPublicParties() {
        webSocketManager.send(.discoverParties)
    }
    
    func searchParties(query: String) {
        let searchRequest = PartySearchRequest(
            query: query,
            userId: currentUserId
        )
        
        webSocketManager.send(.searchParties(searchRequest))
    }
    
    // MARK: - Private Methods
    private func setupWebSocketConnection() {
        webSocketManager.delegate = self
        
        webSocketManager.connectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
    }
    
    private func setupSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkSyncStatus()
        }
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() {
        guard let party = currentParty else { return }
        
        let heartbeat = PartyHeartbeat(
            partyId: party.id,
            userId: currentUserId,
            timestamp: Date()
        )
        
        webSocketManager.send(.heartbeat(heartbeat))
    }
    
    private func checkSyncStatus() {
        // Check if we're in sync with other party members
        // This would compare local playback state with server state
        // For now, we'll just update the sync status periodically
        
        if let _ = currentParty {
            syncStatus = .synced // Would be calculated based on actual sync
        }
    }
    
    private func getUserDisplayName() -> String {
        return userDefaults.string(forKey: "user_display_name") ?? "Anonymous"
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        return formatter.string(from: seconds) ?? "00:00"
    }
}

// MARK: - WebSocket Manager Delegate
extension WatchPartyManager: WebSocketManagerDelegate {
    func webSocketDidConnect() {
        connectionStatus = .connected
    }
    
    func webSocketDidDisconnect() {
        connectionStatus = .disconnected
    }
    
    func webSocketDidReceiveMessage(_ message: WebSocketMessage) {
        handleWebSocketMessage(message)
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message {
        case .partyCreated(let party):
            if party.hostId == currentUserId {
                currentParty = party
            }
            
        case .partyJoined(let party, let members):
            currentParty = party
            partyMembers = members
            
        case .memberJoined(let member):
            partyMembers.append(member)
            
        case .memberLeft(let memberId):
            partyMembers.removeAll { $0.userId == memberId }
            
        case .queueUpdated(let queueUpdate):
            streamQueue = queueUpdate.streams
            currentStreamIndex = queueUpdate.currentIndex
            
        case .syncCommand(let command):
            handleSyncCommand(command)
            
        case .chatMessage(let message):
            chatMessages.append(message)
            
        case .invitation(let invitation):
            partyInvitations.append(invitation)
            
        case .partiesDiscovered(let parties):
            availableParties = parties
            
        case .error(let error):
            print("Watch party error: \(error)")
        }
    }
    
    private func handleSyncCommand(_ command: SyncCommand) {
        guard !isHosting else { return } // Hosts don't receive sync commands
        
        switch command.action {
        case .play:
            playbackState = .playing
        case .pause:
            playbackState = .paused
        case .seek:
            // Seek to specific position
            break
        case .changeStream:
            currentStreamIndex = command.streamIndex
        }
        
        // Calculate sync offset
        let latency = Date().timeIntervalSince(command.timestamp)
        syncOffset = latency
        
        // Update sync status
        syncStatus = syncOffset < 2.0 ? .synced : .outOfSync
    }
}

// MARK: - Data Models

public struct WatchParty: Identifiable, Codable {
    public let id: String
    public let name: String
    public let hostId: String
    public let streams: [TwitchStream]
    public let isPrivate: Bool
    public let password: String?
    public let maxMembers: Int
    public let createdAt: Date
    public var memberCount: Int = 1
    public var currentStreamIndex: Int = 0
    public var description: String?
    public var tags: [String] = []
    
    public init(
        id: String,
        name: String,
        hostId: String,
        streams: [TwitchStream],
        isPrivate: Bool,
        password: String? = nil,
        maxMembers: Int = 50,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.hostId = hostId
        self.streams = streams
        self.isPrivate = isPrivate
        self.password = password
        self.maxMembers = maxMembers
        self.createdAt = createdAt
    }
}

public struct PartyMember: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let username: String
    public let avatarURL: String?
    public let joinedAt: Date
    public let isHost: Bool
    public let isModerator: Bool
    public var isOnline: Bool = true
    public var lastSeen: Date = Date()
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        username: String,
        avatarURL: String? = nil,
        joinedAt: Date = Date(),
        isHost: Bool = false,
        isModerator: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.avatarURL = avatarURL
        self.joinedAt = joinedAt
        self.isHost = isHost
        self.isModerator = isModerator
    }
}

public struct PartyChatMessage: Identifiable, Codable {
    public let id: String
    public let partyId: String
    public let userId: String
    public let username: String
    public let text: String
    public let type: MessageType
    public let timestamp: Date
    public var reactions: [MessageReaction] = []
    public var isSystem: Bool = false
    
    public init(
        id: String,
        partyId: String,
        userId: String,
        username: String,
        text: String,
        type: MessageType,
        timestamp: Date
    ) {
        self.id = id
        self.partyId = partyId
        self.userId = userId
        self.username = username
        self.text = text
        self.type = type
        self.timestamp = timestamp
    }
}

public struct PartyInvitation: Identifiable, Codable {
    public let id: String
    public let partyId: String
    public let fromUserId: String
    public let toUserIds: [String]
    public let message: String
    public let expiresAt: Date
    public let createdAt: Date = Date()
    
    public init(
        id: String,
        partyId: String,
        fromUserId: String,
        toUserIds: [String],
        message: String,
        expiresAt: Date
    ) {
        self.id = id
        self.partyId = partyId
        self.fromUserId = fromUserId
        self.toUserIds = toUserIds
        self.message = message
        self.expiresAt = expiresAt
    }
}

// MARK: - Enums

public enum ConnectionStatus {
    case connected
    case connecting
    case disconnected
    case error(String)
}

public enum SyncStatus {
    case synced
    case syncing
    case outOfSync
    case error
}

public enum PlaybackState {
    case playing
    case paused
    case stopped
    case buffering
}

public enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case reaction = "reaction"
    case highlight = "highlight"
    case system = "system"
    case join = "join"
    case leave = "leave"
}

public enum ReactionType: String, CaseIterable {
    case love = "❤️"
    case laugh = "😂"
    case wow = "😮"
    case sad = "😢"
    case angry = "😠"
    case fire = "🔥"
    case clap = "👏"
    case thumbsUp = "👍"
    
    var emoji: String {
        return rawValue
    }
}

public enum SyncAction: String, Codable {
    case play = "play"
    case pause = "pause"
    case seek = "seek"
    case changeStream = "changeStream"
}

// MARK: - Supporting Models

public struct JoinPartyRequest: Codable {
    public let partyId: String
    public let userId: String
    public let password: String?
}

public struct LeavePartyRequest: Codable {
    public let partyId: String
    public let userId: String
}

public struct InvitationResponse: Codable {
    public let invitationId: String
    public let userId: String
    public let accepted: Bool
}

public struct QueueUpdate: Codable {
    public let partyId: String
    public let streams: [TwitchStream]
    public let currentIndex: Int
}

public struct SyncCommand: Codable {
    public let partyId: String
    public let action: SyncAction
    public let timestamp: Date
    public let streamIndex: Int
    public let playbackPosition: TimeInterval
}

public struct PartyHeartbeat: Codable {
    public let partyId: String
    public let userId: String
    public let timestamp: Date
}

public struct PartySearchRequest: Codable {
    public let query: String
    public let userId: String
}

public struct MessageReaction: Codable {
    public let userId: String
    public let reaction: ReactionType
    public let timestamp: Date
}

// MARK: - WebSocket Messages

public enum WebSocketMessage: Codable {
    case createParty(WatchParty)
    case joinParty(JoinPartyRequest)
    case leaveParty(LeavePartyRequest)
    case updateQueue(QueueUpdate)
    case syncCommand(SyncCommand)
    case chatMessage(PartyChatMessage)
    case sendInvitation(PartyInvitation)
    case respondToInvitation(InvitationResponse)
    case discoverParties
    case searchParties(PartySearchRequest)
    case heartbeat(PartyHeartbeat)
    
    // Server responses
    case partyCreated(WatchParty)
    case partyJoined(WatchParty, [PartyMember])
    case memberJoined(PartyMember)
    case memberLeft(String)
    case queueUpdated(QueueUpdate)
    case invitation(PartyInvitation)
    case partiesDiscovered([WatchParty])
    case error(String)
}

// MARK: - WebSocket Manager Protocol

protocol WebSocketManagerDelegate: AnyObject {
    func webSocketDidConnect()
    func webSocketDidDisconnect()
    func webSocketDidReceiveMessage(_ message: WebSocketMessage)
}

// MARK: - WebSocket Manager Implementation

class WebSocketManager: ObservableObject {
    weak var delegate: WebSocketManagerDelegate?
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    var connectionStatusPublisher: Published<ConnectionStatus>.Publisher {
        $connectionStatus
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession.shared
    
    init() {
        connect()
    }
    
    func connect() {
        guard let url = URL(string: "wss://api.streamyyy.com/watchparty") else { return }
        
        connectionStatus = .connecting
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        
        // Simulate connection success for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.connectionStatus = .connected
            self.delegate?.webSocketDidConnect()
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        connectionStatus = .disconnected
        delegate?.webSocketDidDisconnect()
    }
    
    func send(_ message: WebSocketMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let string = String(data: data, encoding: .utf8) else { return }
        
        let webSocketMessage = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(webSocketMessage) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let webSocketMessage = try? JSONDecoder().decode(WebSocketMessage.self, from: data) {
                        DispatchQueue.main.async {
                            self?.delegate?.webSocketDidReceiveMessage(webSocketMessage)
                        }
                    }
                case .data(let data):
                    if let webSocketMessage = try? JSONDecoder().decode(WebSocketMessage.self, from: data) {
                        DispatchQueue.main.async {
                            self?.delegate?.webSocketDidReceiveMessage(webSocketMessage)
                        }
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self?.receiveMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionStatus = .error(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let watchPartyCreated = Notification.Name("watchPartyCreated")
    static let watchPartyJoined = Notification.Name("watchPartyJoined")
    static let watchPartyLeft = Notification.Name("watchPartyLeft")
    static let watchPartyInvitationReceived = Notification.Name("watchPartyInvitationReceived")
}