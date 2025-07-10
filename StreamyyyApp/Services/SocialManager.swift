//
//  SocialManager.swift
//  StreamyyyApp
//
//  Comprehensive social system with friends, discovery, and collaboration
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import Combine

// MARK: - Social Manager
@MainActor
class SocialManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentUser: SocialUser?
    @Published var friends: [SocialUser] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var suggestedFriends: [SocialUser] = []
    @Published var onlineFriends: [SocialUser] = []
    @Published var recentActivity: [SocialActivity] = []
    @Published var userPresence: UserPresence = .offline
    @Published var socialFeed: [SocialFeedItem] = []
    @Published var collaborativePlaylists: [CollaborativePlaylist] = []
    @Published var followedStreamers: [StreamerProfile] = []
    @Published var isDiscoverable: Bool = true
    @Published var socialSettings: SocialSettings = SocialSettings()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let socialAPI = SocialAPIService()
    private var presenceTimer: Timer?
    private var activityUpdateTimer: Timer?
    
    // MARK: - Initialization
    init() {
        loadSocialSettings()
        setupPresenceUpdates()
        loadUserProfile()
        fetchFriends()
        fetchSocialFeed()
    }
    
    // MARK: - User Profile Management
    func updateUserProfile(_ profile: SocialUserProfile) {
        currentUser?.profile = profile
        socialAPI.updateProfile(profile) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.saveUserProfile()
                case .failure(let error):
                    print("Failed to update profile: \(error)")
                }
            }
        }
    }
    
    func updatePresence(_ presence: UserPresence) {
        userPresence = presence
        
        let presenceUpdate = PresenceUpdate(
            userId: currentUser?.id ?? "",
            presence: presence,
            timestamp: Date()
        )
        
        socialAPI.updatePresence(presenceUpdate) { result in
            switch result {
            case .success:
                print("Presence updated to: \(presence)")
            case .failure(let error):
                print("Failed to update presence: \(error)")
            }
        }
    }
    
    func setCurrentlyWatching(_ streams: [TwitchStream]) {
        let activity = WatchingActivity(
            streams: streams,
            startTime: Date(),
            isPublic: socialSettings.shareWatchingActivity
        )
        
        updateUserActivity(.watching(activity))
    }
    
    func setInWatchParty(_ partyId: String, partyName: String) {
        let activity = WatchPartyActivity(
            partyId: partyId,
            partyName: partyName,
            joinedAt: Date()
        )
        
        updateUserActivity(.watchParty(activity))
    }
    
    // MARK: - Friend Management
    func sendFriendRequest(to userId: String, message: String? = nil) {
        let request = FriendRequest(
            id: UUID().uuidString,
            fromUserId: currentUser?.id ?? "",
            toUserId: userId,
            message: message,
            status: .pending,
            sentAt: Date()
        )
        
        socialAPI.sendFriendRequest(request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Friend request sent to: \(userId)")
                case .failure(let error):
                    print("Failed to send friend request: \(error)")
                }
            }
        }
    }
    
    func respondToFriendRequest(_ request: FriendRequest, accept: Bool) {
        let response = FriendRequestResponse(
            requestId: request.id,
            accepted: accept,
            respondedAt: Date()
        )
        
        socialAPI.respondToFriendRequest(response) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.friendRequests.removeAll { $0.id == request.id }
                    
                    if accept {
                        // Add to friends list
                        self?.addFriendFromRequest(request)
                    }
                    
                case .failure(let error):
                    print("Failed to respond to friend request: \(error)")
                }
            }
        }
    }
    
    func removeFriend(_ userId: String) {
        friends.removeAll { $0.id == userId }
        
        socialAPI.removeFriend(userId) { result in
            switch result {
            case .success:
                print("Friend removed: \(userId)")
            case .failure(let error):
                print("Failed to remove friend: \(error)")
            }
        }
    }
    
    func blockUser(_ userId: String) {
        socialAPI.blockUser(userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.friends.removeAll { $0.id == userId }
                    self?.suggestedFriends.removeAll { $0.id == userId }
                    print("User blocked: \(userId)")
                    
                case .failure(let error):
                    print("Failed to block user: \(error)")
                }
            }
        }
    }
    
    // MARK: - Social Discovery
    func discoverUsers(by criteria: DiscoveryCriteria) {
        socialAPI.discoverUsers(criteria) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    self?.suggestedFriends = users
                case .failure(let error):
                    print("Failed to discover users: \(error)")
                }
            }
        }
    }
    
    func searchUsers(query: String) {
        socialAPI.searchUsers(query) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    self?.suggestedFriends = users
                case .failure(let error):
                    print("Failed to search users: \(error)")
                }
            }
        }
    }
    
    func findFriendsByContacts(_ contacts: [ContactInfo]) {
        socialAPI.findFriendsByContacts(contacts) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    self?.suggestedFriends.append(contentsOf: users)
                case .failure(let error):
                    print("Failed to find friends by contacts: \(error)")
                }
            }
        }
    }
    
    // MARK: - Collaborative Playlists
    func createCollaborativePlaylist(name: String, description: String, isPublic: Bool = false) {
        let playlist = CollaborativePlaylist(
            id: UUID().uuidString,
            name: name,
            description: description,
            creatorId: currentUser?.id ?? "",
            isPublic: isPublic,
            createdAt: Date()
        )
        
        collaborativePlaylists.append(playlist)
        
        socialAPI.createPlaylist(playlist) { result in
            switch result {
            case .success:
                print("Collaborative playlist created: \(name)")
            case .failure(let error):
                print("Failed to create playlist: \(error)")
            }
        }
    }
    
    func addStreamToPlaylist(_ stream: TwitchStream, playlistId: String) {
        guard let playlistIndex = collaborativePlaylists.firstIndex(where: { $0.id == playlistId }) else { return }
        
        let playlistItem = PlaylistItem(
            id: UUID().uuidString,
            stream: stream,
            addedBy: currentUser?.id ?? "",
            addedAt: Date()
        )
        
        collaborativePlaylists[playlistIndex].items.append(playlistItem)
        
        socialAPI.addToPlaylist(playlistItem, playlistId: playlistId) { result in
            switch result {
            case .success:
                print("Stream added to playlist: \(stream.title)")
            case .failure(let error):
                print("Failed to add stream to playlist: \(error)")
            }
        }
    }
    
    func inviteToPlaylist(_ playlistId: String, userIds: [String]) {
        let invitation = PlaylistInvitation(
            id: UUID().uuidString,
            playlistId: playlistId,
            fromUserId: currentUser?.id ?? "",
            toUserIds: userIds,
            sentAt: Date()
        )
        
        socialAPI.inviteToPlaylist(invitation) { result in
            switch result {
            case .success:
                print("Playlist invitations sent")
            case .failure(let error):
                print("Failed to send playlist invitations: \(error)")
            }
        }
    }
    
    func voteOnPlaylistItem(_ itemId: String, playlistId: String, vote: PlaylistVote) {
        socialAPI.voteOnPlaylistItem(itemId, playlistId: playlistId, vote: vote) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.updatePlaylistItemVote(itemId, playlistId: playlistId, vote: vote)
                case .failure(let error):
                    print("Failed to vote on playlist item: \(error)")
                }
            }
        }
    }
    
    // MARK: - Streamer Following
    func followStreamer(_ streamer: StreamerProfile) {
        followedStreamers.append(streamer)
        
        socialAPI.followStreamer(streamer.id) { result in
            switch result {
            case .success:
                print("Following streamer: \(streamer.username)")
            case .failure(let error):
                print("Failed to follow streamer: \(error)")
            }
        }
    }
    
    func unfollowStreamer(_ streamerId: String) {
        followedStreamers.removeAll { $0.id == streamerId }
        
        socialAPI.unfollowStreamer(streamerId) { result in
            switch result {
            case .success:
                print("Unfollowed streamer: \(streamerId)")
            case .failure(let error):
                print("Failed to unfollow streamer: \(error)")
            }
        }
    }
    
    func getStreamerNotifications() -> [StreamerNotification] {
        // Get notifications for followed streamers going live
        return followedStreamers.compactMap { streamer in
            if streamer.isLive && !streamer.notificationSent {
                return StreamerNotification(
                    id: UUID().uuidString,
                    streamerId: streamer.id,
                    streamerName: streamer.username,
                    message: "\(streamer.username) is now live!",
                    timestamp: Date()
                )
            }
            return nil
        }
    }
    
    // MARK: - Social Feed
    func postToFeed(_ content: FeedContent) {
        let feedItem = SocialFeedItem(
            id: UUID().uuidString,
            userId: currentUser?.id ?? "",
            username: currentUser?.profile.displayName ?? "",
            content: content,
            timestamp: Date()
        )
        
        socialFeed.insert(feedItem, at: 0)
        
        socialAPI.postToFeed(feedItem) { result in
            switch result {
            case .success:
                print("Posted to social feed")
            case .failure(let error):
                print("Failed to post to social feed: \(error)")
            }
        }
    }
    
    func likePost(_ postId: String) {
        socialAPI.likePost(postId, userId: currentUser?.id ?? "") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.updatePostLike(postId, liked: true)
                case .failure(let error):
                    print("Failed to like post: \(error)")
                }
            }
        }
    }
    
    func commentOnPost(_ postId: String, text: String) {
        let comment = FeedComment(
            id: UUID().uuidString,
            userId: currentUser?.id ?? "",
            username: currentUser?.profile.displayName ?? "",
            text: text,
            timestamp: Date()
        )
        
        socialAPI.commentOnPost(postId, comment: comment) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.addCommentToPost(postId, comment: comment)
                case .failure(let error):
                    print("Failed to comment on post: \(error)")
                }
            }
        }
    }
    
    // MARK: - Privacy & Settings
    func updateSocialSettings(_ settings: SocialSettings) {
        socialSettings = settings
        saveSocialSettings()
        
        socialAPI.updateSocialSettings(settings) { result in
            switch result {
            case .success:
                print("Social settings updated")
            case .failure(let error):
                print("Failed to update social settings: \(error)")
            }
        }
    }
    
    func updatePrivacySettings(_ privacy: PrivacySettings) {
        socialSettings.privacy = privacy
        saveSocialSettings()
        
        socialAPI.updatePrivacySettings(privacy) { result in
            switch result {
            case .success:
                print("Privacy settings updated")
            case .failure(let error):
                print("Failed to update privacy settings: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadUserProfile() {
        if let data = userDefaults.data(forKey: "social_user_profile"),
           let user = try? JSONDecoder().decode(SocialUser.self, from: data) {
            currentUser = user
        } else {
            // Create default user profile
            createDefaultUserProfile()
        }
    }
    
    private func saveUserProfile() {
        if let user = currentUser,
           let data = try? JSONEncoder().encode(user) {
            userDefaults.set(data, forKey: "social_user_profile")
        }
    }
    
    private func createDefaultUserProfile() {
        let profile = SocialUserProfile(
            displayName: "User",
            bio: "",
            avatarURL: nil,
            interests: [],
            favoriteGenres: [],
            location: nil,
            isPublic: true
        )
        
        let user = SocialUser(
            id: UUID().uuidString,
            profile: profile,
            joinedAt: Date()
        )
        
        currentUser = user
        saveUserProfile()
    }
    
    private func fetchFriends() {
        guard let userId = currentUser?.id else { return }
        
        socialAPI.getFriends(userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let friends):
                    self?.friends = friends
                    self?.updateOnlineFriends()
                case .failure(let error):
                    print("Failed to fetch friends: \(error)")
                }
            }
        }
    }
    
    private func fetchSocialFeed() {
        guard let userId = currentUser?.id else { return }
        
        socialAPI.getSocialFeed(userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let feed):
                    self?.socialFeed = feed
                case .failure(let error):
                    print("Failed to fetch social feed: \(error)")
                }
            }
        }
    }
    
    private func setupPresenceUpdates() {
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updatePresence(self?.userPresence ?? .offline)
        }
        
        activityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateRecentActivity()
        }
    }
    
    private func updateOnlineFriends() {
        onlineFriends = friends.filter { friend in
            friend.presence == .online || friend.presence == .watching
        }
    }
    
    private func updateUserActivity(_ activity: UserActivity) {
        let activityItem = SocialActivity(
            id: UUID().uuidString,
            userId: currentUser?.id ?? "",
            activity: activity,
            timestamp: Date()
        )
        
        recentActivity.insert(activityItem, at: 0)
        
        // Keep only recent activities (last 50)
        if recentActivity.count > 50 {
            recentActivity = Array(recentActivity.prefix(50))
        }
        
        socialAPI.updateActivity(activityItem) { result in
            switch result {
            case .success:
                print("Activity updated")
            case .failure(let error):
                print("Failed to update activity: \(error)")
            }
        }
    }
    
    private func updateRecentActivity() {
        // Fetch recent activity for friends
        socialAPI.getRecentActivity(userIds: friends.map { $0.id }) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let activities):
                    self?.recentActivity = activities
                case .failure(let error):
                    print("Failed to fetch recent activity: \(error)")
                }
            }
        }
    }
    
    private func addFriendFromRequest(_ request: FriendRequest) {
        // In a real implementation, you'd fetch the user profile
        // For now, create a basic friend entry
        let friend = SocialUser(
            id: request.fromUserId,
            profile: SocialUserProfile(
                displayName: "Friend",
                bio: "",
                avatarURL: nil,
                interests: [],
                favoriteGenres: [],
                location: nil,
                isPublic: true
            ),
            joinedAt: Date()
        )
        
        friends.append(friend)
        updateOnlineFriends()
    }
    
    private func updatePlaylistItemVote(_ itemId: String, playlistId: String, vote: PlaylistVote) {
        guard let playlistIndex = collaborativePlaylists.firstIndex(where: { $0.id == playlistId }),
              let itemIndex = collaborativePlaylists[playlistIndex].items.firstIndex(where: { $0.id == itemId }) else { return }
        
        switch vote {
        case .up:
            collaborativePlaylists[playlistIndex].items[itemIndex].upvotes += 1
        case .down:
            collaborativePlaylists[playlistIndex].items[itemIndex].downvotes += 1
        }
    }
    
    private func updatePostLike(_ postId: String, liked: Bool) {
        if let index = socialFeed.firstIndex(where: { $0.id == postId }) {
            if liked {
                socialFeed[index].likes += 1
            } else {
                socialFeed[index].likes = max(0, socialFeed[index].likes - 1)
            }
        }
    }
    
    private func addCommentToPost(_ postId: String, comment: FeedComment) {
        if let index = socialFeed.firstIndex(where: { $0.id == postId }) {
            socialFeed[index].comments.append(comment)
        }
    }
    
    private func loadSocialSettings() {
        if let data = userDefaults.data(forKey: "social_settings"),
           let settings = try? JSONDecoder().decode(SocialSettings.self, from: data) {
            socialSettings = settings
        }
    }
    
    private func saveSocialSettings() {
        if let data = try? JSONEncoder().encode(socialSettings) {
            userDefaults.set(data, forKey: "social_settings")
        }
    }
}

// MARK: - Data Models

public struct SocialUser: Identifiable, Codable {
    public let id: String
    public var profile: SocialUserProfile
    public let joinedAt: Date
    public var lastSeen: Date = Date()
    public var presence: UserPresence = .offline
    public var isOnline: Bool { presence != .offline }
    public var friendsSince: Date?
    public var mutualFriends: Int = 0
    
    public init(id: String, profile: SocialUserProfile, joinedAt: Date) {
        self.id = id
        self.profile = profile
        self.joinedAt = joinedAt
    }
}

public struct SocialUserProfile: Codable {
    public var displayName: String
    public var bio: String
    public var avatarURL: String?
    public var interests: [String]
    public var favoriteGenres: [String]
    public var location: String?
    public var isPublic: Bool
    public var stats: UserStats = UserStats()
    
    public init(
        displayName: String,
        bio: String,
        avatarURL: String?,
        interests: [String],
        favoriteGenres: [String],
        location: String?,
        isPublic: Bool
    ) {
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.interests = interests
        self.favoriteGenres = favoriteGenres
        self.location = location
        self.isPublic = isPublic
    }
}

public struct UserStats: Codable {
    public var totalWatchTime: TimeInterval = 0
    public var streamsWatched: Int = 0
    public var watchPartiesJoined: Int = 0
    public var highlightsCreated: Int = 0
    public var playlistsCreated: Int = 0
    public var friendsCount: Int = 0
}

public struct FriendRequest: Identifiable, Codable {
    public let id: String
    public let fromUserId: String
    public let toUserId: String
    public let message: String?
    public var status: FriendRequestStatus
    public let sentAt: Date
    public var respondedAt: Date?
    
    public init(
        id: String,
        fromUserId: String,
        toUserId: String,
        message: String?,
        status: FriendRequestStatus,
        sentAt: Date
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.message = message
        self.status = status
        self.sentAt = sentAt
    }
}

public struct CollaborativePlaylist: Identifiable, Codable {
    public let id: String
    public var name: String
    public var description: String
    public let creatorId: String
    public var collaborators: [String] = []
    public var items: [PlaylistItem] = []
    public let isPublic: Bool
    public let createdAt: Date
    public var updatedAt: Date = Date()
    public var totalDuration: TimeInterval {
        return items.reduce(0) { $0 + ($1.stream.viewerCount > 0 ? 3600 : 0) } // Estimate
    }
    
    public init(
        id: String,
        name: String,
        description: String,
        creatorId: String,
        isPublic: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.creatorId = creatorId
        self.isPublic = isPublic
        self.createdAt = createdAt
    }
}

public struct PlaylistItem: Identifiable, Codable {
    public let id: String
    public let stream: TwitchStream
    public let addedBy: String
    public let addedAt: Date
    public var upvotes: Int = 0
    public var downvotes: Int = 0
    public var position: Int = 0
    
    public var score: Int {
        return upvotes - downvotes
    }
    
    public init(id: String, stream: TwitchStream, addedBy: String, addedAt: Date) {
        self.id = id
        self.stream = stream
        self.addedBy = addedBy
        self.addedAt = addedAt
    }
}

public struct SocialActivity: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let activity: UserActivity
    public let timestamp: Date
    
    public init(id: String, userId: String, activity: UserActivity, timestamp: Date) {
        self.id = id
        self.userId = userId
        self.activity = activity
        self.timestamp = timestamp
    }
}

public struct SocialFeedItem: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let username: String
    public let content: FeedContent
    public let timestamp: Date
    public var likes: Int = 0
    public var comments: [FeedComment] = []
    public var isLiked: Bool = false
    
    public init(
        id: String,
        userId: String,
        username: String,
        content: FeedContent,
        timestamp: Date
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.content = content
        self.timestamp = timestamp
    }
}

public struct StreamerProfile: Identifiable, Codable {
    public let id: String
    public let username: String
    public let displayName: String
    public let avatarURL: String?
    public let bio: String?
    public let followerCount: Int
    public let isLive: Bool
    public let lastSeenAt: Date?
    public var notificationSent: Bool = false
    
    public init(
        id: String,
        username: String,
        displayName: String,
        avatarURL: String?,
        bio: String?,
        followerCount: Int,
        isLive: Bool,
        lastSeenAt: Date?
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.bio = bio
        self.followerCount = followerCount
        self.isLive = isLive
        self.lastSeenAt = lastSeenAt
    }
}

// MARK: - Enums

public enum UserPresence: String, Codable, CaseIterable {
    case online = "online"
    case away = "away"
    case watching = "watching"
    case inParty = "inParty"
    case offline = "offline"
    
    public var displayName: String {
        switch self {
        case .online: return "Online"
        case .away: return "Away"
        case .watching: return "Watching"
        case .inParty: return "In Party"
        case .offline: return "Offline"
        }
    }
    
    public var color: Color {
        switch self {
        case .online: return .green
        case .away: return .orange
        case .watching: return .blue
        case .inParty: return .purple
        case .offline: return .gray
        }
    }
}

public enum FriendRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case blocked = "blocked"
}

public enum UserActivity: Codable {
    case watching(WatchingActivity)
    case watchParty(WatchPartyActivity)
    case playlist(PlaylistActivity)
    case social(SocialInteraction)
    
    public var displayText: String {
        switch self {
        case .watching(let activity):
            return "Watching \(activity.streams.first?.title ?? "streams")"
        case .watchParty(let activity):
            return "In watch party: \(activity.partyName)"
        case .playlist(let activity):
            return "Updated playlist: \(activity.playlistName)"
        case .social(let interaction):
            return interaction.description
        }
    }
}

public enum FeedContent: Codable {
    case text(String)
    case streamHighlight(StreamHighlight)
    case playlistShare(String) // Playlist ID
    case achievement(Achievement)
    case watchPartyInvite(String) // Party ID
    
    public var displayText: String {
        switch self {
        case .text(let text):
            return text
        case .streamHighlight(let highlight):
            return "Shared a highlight from \(highlight.streamTitle)"
        case .playlistShare:
            return "Shared a playlist"
        case .achievement(let achievement):
            return "Unlocked achievement: \(achievement.title)"
        case .watchPartyInvite:
            return "Invited friends to a watch party"
        }
    }
}

public enum PlaylistVote: String, Codable {
    case up = "up"
    case down = "down"
}

// MARK: - Supporting Models

public struct WatchingActivity: Codable {
    public let streams: [TwitchStream]
    public let startTime: Date
    public let isPublic: Bool
}

public struct WatchPartyActivity: Codable {
    public let partyId: String
    public let partyName: String
    public let joinedAt: Date
}

public struct PlaylistActivity: Codable {
    public let playlistId: String
    public let playlistName: String
    public let action: String // "created", "updated", "shared"
}

public struct SocialInteraction: Codable {
    public let type: String // "liked", "commented", "shared"
    public let targetId: String
    public let description: String
}

public struct StreamHighlight: Codable {
    public let streamId: String
    public let streamTitle: String
    public let timestamp: TimeInterval
    public let description: String
    public let thumbnailURL: String?
}

public struct Achievement: Codable {
    public let id: String
    public let title: String
    public let description: String
    public let iconName: String
    public let unlockedAt: Date
}

public struct FeedComment: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let username: String
    public let text: String
    public let timestamp: Date
    
    public init(id: String, userId: String, username: String, text: String, timestamp: Date) {
        self.id = id
        self.userId = userId
        self.username = username
        self.text = text
        self.timestamp = timestamp
    }
}

public struct DiscoveryCriteria: Codable {
    public let interests: [String]
    public let location: String?
    public let ageRange: ClosedRange<Int>?
    public let mutualFriends: Bool
    public let similarTastes: Bool
    
    public init(
        interests: [String] = [],
        location: String? = nil,
        ageRange: ClosedRange<Int>? = nil,
        mutualFriends: Bool = false,
        similarTastes: Bool = true
    ) {
        self.interests = interests
        self.location = location
        self.ageRange = ageRange
        self.mutualFriends = mutualFriends
        self.similarTastes = similarTastes
    }
}

public struct ContactInfo: Codable {
    public let email: String?
    public let phoneNumber: String?
    public let name: String
    
    public init(email: String?, phoneNumber: String?, name: String) {
        self.email = email
        self.phoneNumber = phoneNumber
        self.name = name
    }
}

public struct SocialSettings: Codable {
    public var shareWatchingActivity: Bool = true
    public var allowFriendRequests: Bool = true
    public var showOnlineStatus: Bool = true
    public var allowWatchPartyInvites: Bool = true
    public var notifyWhenFriendsGoLive: Bool = true
    public var privacy: PrivacySettings = PrivacySettings()
    
    public init() {}
}

public struct PrivacySettings: Codable {
    public var profileVisibility: ProfileVisibility = .friends
    public var activityVisibility: ActivityVisibility = .friends
    public var allowDiscovery: Bool = true
    public var blockList: [String] = []
    
    public init() {}
}

public enum ProfileVisibility: String, Codable, CaseIterable {
    case public = "public"
    case friends = "friends"
    case private = "private"
    
    public var displayName: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        case .private: return "Private"
        }
    }
}

public enum ActivityVisibility: String, Codable, CaseIterable {
    case public = "public"
    case friends = "friends"
    case nobody = "nobody"
    
    public var displayName: String {
        switch self {
        case .public: return "Everyone"
        case .friends: return "Friends Only"
        case .nobody: return "Nobody"
        }
    }
}

public struct PresenceUpdate: Codable {
    public let userId: String
    public let presence: UserPresence
    public let timestamp: Date
}

public struct FriendRequestResponse: Codable {
    public let requestId: String
    public let accepted: Bool
    public let respondedAt: Date
}

public struct PlaylistInvitation: Codable {
    public let id: String
    public let playlistId: String
    public let fromUserId: String
    public let toUserIds: [String]
    public let sentAt: Date
}

public struct StreamerNotification: Identifiable {
    public let id: String
    public let streamerId: String
    public let streamerName: String
    public let message: String
    public let timestamp: Date
}

// MARK: - Social API Service

class SocialAPIService {
    // Mock implementation - in real app this would make HTTP requests
    
    func updateProfile(_ profile: SocialUserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func updatePresence(_ update: PresenceUpdate, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(.success(()))
        }
    }
    
    func sendFriendRequest(_ request: FriendRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func respondToFriendRequest(_ response: FriendRequestResponse, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func removeFriend(_ userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func blockUser(_ userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func getFriends(_ userId: String, completion: @escaping (Result<[SocialUser], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success([]))
        }
    }
    
    func discoverUsers(_ criteria: DiscoveryCriteria, completion: @escaping (Result<[SocialUser], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success([]))
        }
    }
    
    func searchUsers(_ query: String, completion: @escaping (Result<[SocialUser], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success([]))
        }
    }
    
    func findFriendsByContacts(_ contacts: [ContactInfo], completion: @escaping (Result<[SocialUser], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success([]))
        }
    }
    
    func createPlaylist(_ playlist: CollaborativePlaylist, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func addToPlaylist(_ item: PlaylistItem, playlistId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func inviteToPlaylist(_ invitation: PlaylistInvitation, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func voteOnPlaylistItem(_ itemId: String, playlistId: String, vote: PlaylistVote, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func followStreamer(_ streamerId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func unfollowStreamer(_ streamerId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func getSocialFeed(_ userId: String, completion: @escaping (Result<[SocialFeedItem], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success([]))
        }
    }
    
    func postToFeed(_ feedItem: SocialFeedItem, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func likePost(_ postId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion(.success(()))
        }
    }
    
    func commentOnPost(_ postId: String, comment: FeedComment, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func updateActivity(_ activity: SocialActivity, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion(.success(()))
        }
    }
    
    func getRecentActivity(userIds: [String], completion: @escaping (Result<[SocialActivity], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success([]))
        }
    }
    
    func updateSocialSettings(_ settings: SocialSettings, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    
    func updatePrivacySettings(_ settings: PrivacySettings, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
}