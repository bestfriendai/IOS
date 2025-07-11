//
//  ViewingHistory.swift
//  StreamyyyApp
//
//  Viewing history model with detailed tracking and analytics
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Viewing History Model
@Model
public class ViewingHistory: Identifiable, Codable, ObservableObject {
    @Attribute(.unique) public var id: String
    public var streamId: String
    public var streamTitle: String
    public var streamURL: String
    public var platform: Platform
    public var streamerName: String?
    public var thumbnailURL: String?
    public var category: String?
    public var viewedAt: Date
    public var viewDuration: TimeInterval // in seconds
    public var totalStreamDuration: TimeInterval? // total stream length if known
    public var watchPercentage: Double // percentage of stream watched
    public var watchQuality: StreamQuality
    public var deviceType: String // iPhone, iPad, etc.
    public var sessionId: String // to group continuous viewing sessions
    public var exitReason: ViewingExitReason
    public var rating: Int? // 1-5 stars, optional user rating
    public var notes: String?
    public var tags: [String]
    public var isCompleted: Bool // watched to the end
    public var wasLive: Bool // was the stream live when watched
    public var viewerCountAtView: Int?
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Relationships
    @Relationship(inverse: \User.viewingHistory)
    public var user: User?
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        streamId: String,
        streamTitle: String,
        streamURL: String,
        platform: Platform,
        streamerName: String? = nil,
        thumbnailURL: String? = nil,
        category: String? = nil,
        viewedAt: Date = Date(),
        viewDuration: TimeInterval = 0,
        watchQuality: StreamQuality = .medium,
        sessionId: String = UUID().uuidString,
        wasLive: Bool = true,
        user: User? = nil
    ) {
        self.id = id
        self.streamId = streamId
        self.streamTitle = streamTitle
        self.streamURL = streamURL
        self.platform = platform
        self.streamerName = streamerName
        self.thumbnailURL = thumbnailURL
        self.category = category
        self.viewedAt = viewedAt
        self.viewDuration = viewDuration
        self.totalStreamDuration = nil
        self.watchPercentage = 0.0
        self.watchQuality = watchQuality
        self.deviceType = UIDevice.current.model
        self.sessionId = sessionId
        self.exitReason = .unknown
        self.rating = nil
        self.notes = nil
        self.tags = []
        self.isCompleted = false
        self.wasLive = wasLive
        self.viewerCountAtView = nil
        self.metadata = [:]
        self.createdAt = Date()
        self.updatedAt = Date()
        self.user = user
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, streamId, streamTitle, streamURL, platform, streamerName, thumbnailURL, category
        case viewedAt, viewDuration, totalStreamDuration, watchPercentage, watchQuality
        case deviceType, sessionId, exitReason, rating, notes, tags
        case isCompleted, wasLive, viewerCountAtView, metadata, createdAt, updatedAt
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        streamId = try container.decode(String.self, forKey: .streamId)
        streamTitle = try container.decode(String.self, forKey: .streamTitle)
        streamURL = try container.decode(String.self, forKey: .streamURL)
        platform = try container.decode(Platform.self, forKey: .platform)
        streamerName = try container.decodeIfPresent(String.self, forKey: .streamerName)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        viewedAt = try container.decode(Date.self, forKey: .viewedAt)
        viewDuration = try container.decode(TimeInterval.self, forKey: .viewDuration)
        totalStreamDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .totalStreamDuration)
        watchPercentage = try container.decode(Double.self, forKey: .watchPercentage)
        watchQuality = try container.decode(StreamQuality.self, forKey: .watchQuality)
        deviceType = try container.decode(String.self, forKey: .deviceType)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        exitReason = try container.decode(ViewingExitReason.self, forKey: .exitReason)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decode([String].self, forKey: .tags)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        wasLive = try container.decode(Bool.self, forKey: .wasLive)
        viewerCountAtView = try container.decodeIfPresent(Int.self, forKey: .viewerCountAtView)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(streamId, forKey: .streamId)
        try container.encode(streamTitle, forKey: .streamTitle)
        try container.encode(streamURL, forKey: .streamURL)
        try container.encode(platform, forKey: .platform)
        try container.encodeIfPresent(streamerName, forKey: .streamerName)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(viewedAt, forKey: .viewedAt)
        try container.encode(viewDuration, forKey: .viewDuration)
        try container.encodeIfPresent(totalStreamDuration, forKey: .totalStreamDuration)
        try container.encode(watchPercentage, forKey: .watchPercentage)
        try container.encode(watchQuality, forKey: .watchQuality)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(exitReason, forKey: .exitReason)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(wasLive, forKey: .wasLive)
        try container.encodeIfPresent(viewerCountAtView, forKey: .viewerCountAtView)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Viewing History Extensions
extension ViewingHistory {
    
    // MARK: - Computed Properties
    public var displayTitle: String {
        return streamTitle.isEmpty ? "Unknown Stream" : streamTitle
    }
    
    public var displayStreamer: String {
        return streamerName ?? "Unknown Streamer"
    }
    
    public var displayDuration: String {
        return formatDuration(viewDuration)
    }
    
    public var displayWatchPercentage: String {
        return String(format: "%.1f%%", watchPercentage)
    }
    
    public var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: viewedAt, relativeTo: Date())
    }
    
    public var exactTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: viewedAt)
    }
    
    public var isRecentlyWatched: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: viewedAt, to: Date()).day ?? 0
        return daysSince <= 7
    }
    
    public var wasLongSession: Bool {
        return viewDuration >= 1800 // 30+ minutes
    }
    
    public var watchQualityColor: Color {
        switch watchQuality {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        case .source: return .blue
        }
    }
    
    public var platformColor: Color {
        return platform.color
    }
    
    public var exitReasonColor: Color {
        switch exitReason {
        case .completed: return .green
        case .userChoice: return .blue
        case .streamEnded: return .purple
        case .error, .networkIssue: return .red
        case .unknown: return .gray
        }
    }
    
    public var ratingStars: String {
        guard let rating = rating else { return "Not rated" }
        return String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
    }
    
    public var categoryIcon: String {
        switch category?.lowercased() {
        case "gaming", "games": return "gamecontroller"
        case "just chatting", "chat": return "message"
        case "music": return "music.note"
        case "sports": return "sportscourt"
        case "art": return "paintbrush"
        case "education": return "book"
        default: return "tv"
        }
    }
    
    // MARK: - Update Methods
    public func updateViewDuration(_ duration: TimeInterval) {
        viewDuration = duration
        
        if let totalDuration = totalStreamDuration, totalDuration > 0 {
            watchPercentage = min(100.0, (duration / totalDuration) * 100.0)
            isCompleted = watchPercentage >= 95.0
        }
        
        updatedAt = Date()
    }
    
    public func setTotalDuration(_ duration: TimeInterval) {
        totalStreamDuration = duration
        
        if duration > 0 {
            watchPercentage = min(100.0, (viewDuration / duration) * 100.0)
            isCompleted = watchPercentage >= 95.0
        }
        
        updatedAt = Date()
    }
    
    public func updateExitReason(_ reason: ViewingExitReason) {
        exitReason = reason
        updatedAt = Date()
    }
    
    public func addRating(_ rating: Int) {
        self.rating = max(1, min(5, rating))
        updatedAt = Date()
    }
    
    public func updateNotes(_ notes: String?) {
        self.notes = notes
        updatedAt = Date()
    }
    
    public func addTag(_ tag: String) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
        updatedAt = Date()
    }
    
    public func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updatedAt = Date()
    }
    
    public func setMetadata(key: String, value: String) {
        metadata[key] = value
        updatedAt = Date()
    }
    
    // MARK: - Analytics Methods
    public func getViewingScore() -> Double {
        var score = 0.0
        
        // Duration score (0-40 points)
        let durationScore = min(40.0, viewDuration / 60.0) // 1 point per minute, max 40
        score += durationScore
        
        // Completion score (0-30 points)
        score += watchPercentage * 0.3
        
        // Rating score (0-20 points)
        if let rating = rating {
            score += Double(rating) * 4.0
        }
        
        // Recency score (0-10 points)
        let daysSince = Calendar.current.dateComponents([.day], from: viewedAt, to: Date()).day ?? 0
        let recencyScore = max(0, 10 - Double(daysSince) * 0.5)
        score += recencyScore
        
        return min(100.0, score)
    }
    
    public func export() -> [String: Any] {
        return [
            "id": id,
            "streamTitle": streamTitle,
            "streamerName": streamerName ?? "",
            "platform": platform.displayName,
            "viewedAt": viewedAt.timeIntervalSince1970,
            "viewDuration": viewDuration,
            "watchPercentage": watchPercentage,
            "rating": rating ?? 0,
            "notes": notes ?? "",
            "tags": tags,
            "isCompleted": isCompleted,
            "wasLive": wasLive
        ]
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Viewing Exit Reason
public enum ViewingExitReason: String, CaseIterable, Codable {
    case completed = "completed"
    case userChoice = "user_choice"
    case streamEnded = "stream_ended"
    case error = "error"
    case networkIssue = "network_issue"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .completed: return "Completed"
        case .userChoice: return "User Left"
        case .streamEnded: return "Stream Ended"
        case .error: return "Error"
        case .networkIssue: return "Network Issue"
        case .unknown: return "Unknown"
        }
    }
    
    public var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .userChoice: return "person.fill.xmark"
        case .streamEnded: return "stop.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .networkIssue: return "wifi.exclamationmark"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Viewing History Filter Options
public enum ViewingHistoryFilter: String, CaseIterable {
    case all = "all"
    case today = "today"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case completed = "completed"
    case rated = "rated"
    case longSessions = "long_sessions"
    case live = "live"
    case byPlatform = "by_platform"
    
    public var displayName: String {
        switch self {
        case .all: return "All History"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .completed: return "Completed"
        case .rated: return "Rated"
        case .longSessions: return "Long Sessions"
        case .live: return "Live Streams"
        case .byPlatform: return "By Platform"
        }
    }
    
    public var icon: String {
        switch self {
        case .all: return "clock"
        case .today: return "sun.max"
        case .thisWeek: return "calendar.badge.clock"
        case .thisMonth: return "calendar"
        case .completed: return "checkmark.circle"
        case .rated: return "star"
        case .longSessions: return "timer"
        case .live: return "dot.radiowaves.up.forward"
        case .byPlatform: return "tv"
        }
    }
}

// MARK: - Viewing History Sort Options
public enum ViewingHistorySortOption: String, CaseIterable {
    case recentFirst = "recent_first"
    case oldestFirst = "oldest_first"
    case longestDuration = "longest_duration"
    case shortestDuration = "shortest_duration"
    case highestRated = "highest_rated"
    case mostCompleted = "most_completed"
    case byPlatform = "by_platform"
    case byStreamer = "by_streamer"
    
    public var displayName: String {
        switch self {
        case .recentFirst: return "Most Recent"
        case .oldestFirst: return "Oldest First"
        case .longestDuration: return "Longest Duration"
        case .shortestDuration: return "Shortest Duration"
        case .highestRated: return "Highest Rated"
        case .mostCompleted: return "Most Completed"
        case .byPlatform: return "By Platform"
        case .byStreamer: return "By Streamer"
        }
    }
}

