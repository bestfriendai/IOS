//
//  StreamCollection.swift
//  StreamyyyApp
//
//  Stream collection/playlist model for organizing streams into user-created groups
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Stream Collection Model
@Model
public class StreamCollection: Identifiable, Codable, ObservableObject {
    @Attribute(.unique) public var id: String
    public var name: String
    public var description: String?
    public var icon: String
    public var color: String
    public var isPrivate: Bool
    public var isDefault: Bool
    public var isFavorite: Bool
    public var sortOrder: Int
    public var tags: [String]
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    public var lastAccessedAt: Date?
    public var accessCount: Int
    public var shareCode: String?
    public var isShared: Bool
    public var authorName: String?
    public var downloadCount: Int
    public var rating: Double
    public var ratingCount: Int
    
    // MARK: - Auto-generated properties
    public var totalDuration: TimeInterval
    public var totalStreams: Int
    public var liveStreamsCount: Int
    public var lastUpdatedStreamAt: Date?
    
    // MARK: - Relationships
    @Relationship(inverse: \User.streamCollections)
    public var owner: User?
    
    @Relationship(deleteRule: .cascade, inverse: \CollectionStream.collection)
    public var streams: [CollectionStream] = []
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        icon: String = "folder",
        color: String = "blue",
        isPrivate: Bool = false,
        owner: User? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.isPrivate = isPrivate
        self.isDefault = false
        self.isFavorite = false
        self.sortOrder = 0
        self.tags = []
        self.metadata = [:]
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastAccessedAt = nil
        self.accessCount = 0
        self.shareCode = nil
        self.isShared = false
        self.authorName = nil
        self.downloadCount = 0
        self.rating = 0.0
        self.ratingCount = 0
        self.totalDuration = 0
        self.totalStreams = 0
        self.liveStreamsCount = 0
        self.lastUpdatedStreamAt = nil
        self.owner = owner
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, color, isPrivate, isDefault, isFavorite
        case sortOrder, tags, metadata, createdAt, updatedAt, lastAccessedAt, accessCount
        case shareCode, isShared, authorName, downloadCount, rating, ratingCount
        case totalDuration, totalStreams, liveStreamsCount, lastUpdatedStreamAt
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        isPrivate = try container.decode(Bool.self, forKey: .isPrivate)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        tags = try container.decode([String].self, forKey: .tags)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastAccessedAt = try container.decodeIfPresent(Date.self, forKey: .lastAccessedAt)
        accessCount = try container.decode(Int.self, forKey: .accessCount)
        shareCode = try container.decodeIfPresent(String.self, forKey: .shareCode)
        isShared = try container.decode(Bool.self, forKey: .isShared)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        downloadCount = try container.decode(Int.self, forKey: .downloadCount)
        rating = try container.decode(Double.self, forKey: .rating)
        ratingCount = try container.decode(Int.self, forKey: .ratingCount)
        totalDuration = try container.decode(TimeInterval.self, forKey: .totalDuration)
        totalStreams = try container.decode(Int.self, forKey: .totalStreams)
        liveStreamsCount = try container.decode(Int.self, forKey: .liveStreamsCount)
        lastUpdatedStreamAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedStreamAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(isPrivate, forKey: .isPrivate)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(tags, forKey: .tags)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastAccessedAt, forKey: .lastAccessedAt)
        try container.encode(accessCount, forKey: .accessCount)
        try container.encodeIfPresent(shareCode, forKey: .shareCode)
        try container.encode(isShared, forKey: .isShared)
        try container.encodeIfPresent(authorName, forKey: .authorName)
        try container.encode(downloadCount, forKey: .downloadCount)
        try container.encode(rating, forKey: .rating)
        try container.encode(ratingCount, forKey: .ratingCount)
        try container.encode(totalDuration, forKey: .totalDuration)
        try container.encode(totalStreams, forKey: .totalStreams)
        try container.encode(liveStreamsCount, forKey: .liveStreamsCount)
        try container.encodeIfPresent(lastUpdatedStreamAt, forKey: .lastUpdatedStreamAt)
    }
}

// MARK: - Stream Collection Extensions
extension StreamCollection {
    
    // MARK: - Computed Properties
    public var displayName: String {
        return name.isEmpty ? "Untitled Collection" : name
    }
    
    public var colorValue: Color {
        switch color.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "cyan": return .cyan
        case "gray": return .gray
        case "brown": return .brown
        default: return .blue
        }
    }
    
    public var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    public var isEmpty: Bool {
        return streams.isEmpty
    }
    
    public var isRecentlyAccessed: Bool {
        guard let lastAccessed = lastAccessedAt else { return false }
        let daysSince = Calendar.current.dateComponents([.day], from: lastAccessed, to: Date()).day ?? 0
        return daysSince <= 7
    }
    
    public var isPopular: Bool {
        return accessCount >= 50 || downloadCount >= 100
    }
    
    public var isHighlyRated: Bool {
        return rating >= 4.5 && ratingCount >= 10
    }
    
    public var statusIcon: String {
        if isShared {
            return "square.and.arrow.up"
        } else if isPrivate {
            return "lock"
        } else if isDefault {
            return "star.fill"
        } else {
            return icon
        }
    }
    
    public var statusColor: Color {
        if isShared {
            return .blue
        } else if isPrivate {
            return .orange
        } else if isDefault {
            return .yellow
        } else {
            return colorValue
        }
    }
    
    public var ratingStars: String {
        let fullStars = Int(rating)
        let hasHalfStar = rating - Double(fullStars) >= 0.5
        let emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
        
        return String(repeating: "★", count: fullStars) +
               (hasHalfStar ? "☆" : "") +
               String(repeating: "☆", count: emptyStars)
    }
    
    public var platformBreakdown: [Platform: Int] {
        var breakdown: [Platform: Int] = [:]
        
        for stream in streams {
            if let streamData = stream.streamData {
                let platform = streamData.platform
                breakdown[platform, default: 0] += 1
            }
        }
        
        return breakdown
    }
    
    public var timeSinceCreated: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    public var timeSinceUpdated: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
    
    // MARK: - Update Methods
    public func updateName(_ newName: String) {
        name = newName
        updatedAt = Date()
    }
    
    public func updateDescription(_ newDescription: String?) {
        description = newDescription
        updatedAt = Date()
    }
    
    public func updateIcon(_ newIcon: String) {
        icon = newIcon
        updatedAt = Date()
    }
    
    public func updateColor(_ newColor: String) {
        color = newColor
        updatedAt = Date()
    }
    
    public func recordAccess() {
        accessCount += 1
        lastAccessedAt = Date()
        updatedAt = Date()
    }
    
    public func toggleFavorite() {
        isFavorite.toggle()
        updatedAt = Date()
    }
    
    public func togglePrivacy() {
        isPrivate.toggle()
        
        // If making private, disable sharing
        if isPrivate {
            isShared = false
            shareCode = nil
        }
        
        updatedAt = Date()
    }
    
    public func setAsDefault() {
        isDefault = true
        updatedAt = Date()
    }
    
    public func unsetAsDefault() {
        isDefault = false
        updatedAt = Date()
    }
    
    // MARK: - Stream Management
    public func addStream(_ streamData: StreamData, order: Int? = nil) {
        let collectionStream = CollectionStream(
            collectionId: id,
            streamData: streamData,
            order: order ?? streams.count
        )
        
        streams.append(collectionStream)
        updateStatistics()
        updatedAt = Date()
    }
    
    public func removeStream(_ streamId: String) {
        streams.removeAll { $0.streamId == streamId }
        
        // Reorder remaining streams
        for (index, stream) in streams.enumerated() {
            stream.order = index
        }
        
        updateStatistics()
        updatedAt = Date()
    }
    
    public func moveStream(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < streams.count, destinationIndex < streams.count else { return }
        
        let stream = streams.remove(at: sourceIndex)
        streams.insert(stream, at: destinationIndex)
        
        // Update order for all streams
        for (index, stream) in streams.enumerated() {
            stream.order = index
        }
        
        updatedAt = Date()
    }
    
    public func reorderStreams(by sortOption: StreamSortOption) {
        streams.sort { lhs, rhs in
            guard let lhsData = lhs.streamData, let rhsData = rhs.streamData else {
                return false
            }
            
            switch sortOption {
            case .recentlyAdded:
                return lhs.addedAt > rhs.addedAt
            case .alphabetical:
                return lhsData.title.localizedCaseInsensitiveCompare(rhsData.title) == .orderedAscending
            case .viewerCount:
                return lhsData.viewerCount > rhsData.viewerCount
            case .platform:
                return lhsData.platform.displayName.localizedCaseInsensitiveCompare(rhsData.platform.displayName) == .orderedAscending
            case .lastViewed:
                return lhs.lastViewedAt ?? Date.distantPast > rhs.lastViewedAt ?? Date.distantPast
            }
        }
        
        // Update order for all streams
        for (index, stream) in streams.enumerated() {
            stream.order = index
        }
        
        updatedAt = Date()
    }
    
    // MARK: - Sharing Methods
    public func generateShareCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let code = String((0..<8).map { _ in characters.randomElement()! })
        shareCode = code
        isShared = true
        updatedAt = Date()
        return code
    }
    
    public func enableSharing(authorName: String? = nil) {
        guard !isPrivate else { return }
        
        isShared = true
        self.authorName = authorName
        if shareCode == nil {
            _ = generateShareCode()
        }
        updatedAt = Date()
    }
    
    public func disableSharing() {
        isShared = false
        shareCode = nil
        updatedAt = Date()
    }
    
    public func incrementDownloadCount() {
        downloadCount += 1
        updatedAt = Date()
    }
    
    // MARK: - Rating Methods
    public func addRating(_ newRating: Double) {
        let totalRating = rating * Double(ratingCount) + newRating
        ratingCount += 1
        rating = totalRating / Double(ratingCount)
        updatedAt = Date()
    }
    
    public func updateRating(_ newRating: Double, count: Int) {
        rating = newRating
        ratingCount = count
        updatedAt = Date()
    }
    
    // MARK: - Tag Methods
    public func addTag(_ tag: String) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
        updatedAt = Date()
    }
    
    public func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updatedAt = Date()
    }
    
    public func hasTag(_ tag: String) -> Bool {
        return tags.contains(tag)
    }
    
    // MARK: - Metadata Methods
    public func setMetadata(key: String, value: String) {
        metadata[key] = value
        updatedAt = Date()
    }
    
    public func getMetadata(key: String) -> String? {
        return metadata[key]
    }
    
    public func removeMetadata(key: String) {
        metadata.removeValue(forKey: key)
        updatedAt = Date()
    }
    
    // MARK: - Statistics Methods
    private func updateStatistics() {
        totalStreams = streams.count
        
        var duration: TimeInterval = 0
        var liveCount = 0
        var latestUpdate: Date?
        
        for stream in streams {
            if let streamData = stream.streamData {
                if let streamDuration = streamData.duration {
                    duration += streamDuration
                }
                
                if streamData.isLive {
                    liveCount += 1
                }
                
                if let updateTime = stream.lastUpdatedAt {
                    if latestUpdate == nil || updateTime > latestUpdate! {
                        latestUpdate = updateTime
                    }
                }
            }
        }
        
        totalDuration = duration
        liveStreamsCount = liveCount
        lastUpdatedStreamAt = latestUpdate
    }
    
    // MARK: - Export/Import Methods
    public func exportConfiguration() -> [String: Any] {
        let streamsData = streams.map { stream in
            [
                "streamId": stream.streamId,
                "order": stream.order,
                "addedAt": stream.addedAt.timeIntervalSince1970,
                "notes": stream.notes ?? ""
            ]
        }
        
        return [
            "id": id,
            "name": name,
            "description": description ?? "",
            "icon": icon,
            "color": color,
            "tags": tags,
            "metadata": metadata,
            "streams": streamsData,
            "createdAt": createdAt.timeIntervalSince1970,
            "isPrivate": isPrivate
        ]
    }
    
    public static func importConfiguration(_ data: [String: Any]) -> StreamCollection? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String else {
            return nil
        }
        
        let collection = StreamCollection(
            id: id,
            name: name,
            description: data["description"] as? String,
            icon: data["icon"] as? String ?? "folder",
            color: data["color"] as? String ?? "blue",
            isPrivate: data["isPrivate"] as? Bool ?? false
        )
        
        collection.tags = data["tags"] as? [String] ?? []
        collection.metadata = data["metadata"] as? [String: String] ?? [:]
        
        if let timestamp = data["createdAt"] as? TimeInterval {
            collection.createdAt = Date(timeIntervalSince1970: timestamp)
        }
        
        // Note: Stream data would need to be handled separately
        // since it requires existing Stream objects
        
        return collection
    }
    
    // MARK: - Validation Methods
    public func validateName() -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public func validateIcon() -> Bool {
        return !icon.isEmpty
    }
    
    public func validateColor() -> Bool {
        let validColors = ["red", "blue", "green", "yellow", "purple", "orange", "pink", "cyan", "gray", "brown"]
        return validColors.contains(color.lowercased())
    }
}

// MARK: - Collection Stream Model
@Model
public class CollectionStream: Identifiable, Codable {
    @Attribute(.unique) public var id: String
    public var collectionId: String
    public var streamId: String
    public var order: Int
    public var addedAt: Date
    public var lastViewedAt: Date?
    public var viewCount: Int
    public var notes: String?
    public var tags: [String]
    public var isHidden: Bool
    public var customTitle: String?
    public var lastUpdatedAt: Date?
    
    // MARK: - Relationships
    @Relationship(inverse: \StreamCollection.streams)
    public var collection: StreamCollection?
    
    // Note: In a real implementation, this would be a relationship to Stream
    // For now, we'll store the stream data directly
    public var streamData: StreamData?
    
    public init(
        id: String = UUID().uuidString,
        collectionId: String,
        streamData: StreamData,
        order: Int = 0
    ) {
        self.id = id
        self.collectionId = collectionId
        self.streamId = streamData.id
        self.streamData = streamData
        self.order = order
        self.addedAt = Date()
        self.lastViewedAt = nil
        self.viewCount = 0
        self.notes = nil
        self.tags = []
        self.isHidden = false
        self.customTitle = nil
        self.lastUpdatedAt = Date()
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, collectionId, streamId, order, addedAt, lastViewedAt, viewCount
        case notes, tags, isHidden, customTitle, lastUpdatedAt
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        collectionId = try container.decode(String.self, forKey: .collectionId)
        streamId = try container.decode(String.self, forKey: .streamId)
        order = try container.decode(Int.self, forKey: .order)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        lastViewedAt = try container.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decode([String].self, forKey: .tags)
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(collectionId, forKey: .collectionId)
        try container.encode(streamId, forKey: .streamId)
        try container.encode(order, forKey: .order)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encodeIfPresent(lastViewedAt, forKey: .lastViewedAt)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encodeIfPresent(customTitle, forKey: .customTitle)
        try container.encodeIfPresent(lastUpdatedAt, forKey: .lastUpdatedAt)
    }
    
    // MARK: - Computed Properties
    public var displayTitle: String {
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
        return streamData?.title ?? "Unknown Stream"
    }
    
    public var timeSinceAdded: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: addedAt, relativeTo: Date())
    }
    
    // MARK: - Update Methods
    public func recordView() {
        viewCount += 1
        lastViewedAt = Date()
        lastUpdatedAt = Date()
    }
    
    public func updateNotes(_ newNotes: String?) {
        notes = newNotes
        lastUpdatedAt = Date()
    }
    
    public func updateCustomTitle(_ newTitle: String?) {
        customTitle = newTitle
        lastUpdatedAt = Date()
    }
    
    public func toggleHidden() {
        isHidden.toggle()
        lastUpdatedAt = Date()
    }
}

// MARK: - Stream Data (Simplified)
public struct StreamData: Codable, Identifiable {
    public let id: String
    public let title: String
    public let url: String
    public let platform: Platform
    public let streamerName: String?
    public let thumbnailURL: String?
    public let isLive: Bool
    public let viewerCount: Int
    public let duration: TimeInterval?
    public let category: String?
    public let tags: [String]
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        url: String,
        platform: Platform,
        streamerName: String? = nil,
        thumbnailURL: String? = nil,
        isLive: Bool = true,
        viewerCount: Int = 0,
        duration: TimeInterval? = nil,
        category: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.platform = platform
        self.streamerName = streamerName
        self.thumbnailURL = thumbnailURL
        self.isLive = isLive
        self.viewerCount = viewerCount
        self.duration = duration
        self.category = category
        self.tags = tags
    }
}

// MARK: - Collection Category
public enum CollectionCategory: String, CaseIterable, Codable {
    case gaming = "gaming"
    case music = "music"
    case entertainment = "entertainment"
    case education = "education"
    case sports = "sports"
    case news = "news"
    case lifestyle = "lifestyle"
    case art = "art"
    case technology = "technology"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .gaming: return "Gaming"
        case .music: return "Music"
        case .entertainment: return "Entertainment"
        case .education: return "Education"
        case .sports: return "Sports"
        case .news: return "News"
        case .lifestyle: return "Lifestyle"
        case .art: return "Art"
        case .technology: return "Technology"
        case .other: return "Other"
        }
    }
    
    public var icon: String {
        switch self {
        case .gaming: return "gamecontroller"
        case .music: return "music.note"
        case .entertainment: return "tv"
        case .education: return "book"
        case .sports: return "sportscourt"
        case .news: return "newspaper"
        case .lifestyle: return "heart"
        case .art: return "paintbrush"
        case .technology: return "gear"
        case .other: return "star"
        }
    }
    
    public var color: Color {
        switch self {
        case .gaming: return .purple
        case .music: return .pink
        case .entertainment: return .red
        case .education: return .blue
        case .sports: return .green
        case .news: return .orange
        case .lifestyle: return .cyan
        case .art: return .yellow
        case .technology: return .gray
        case .other: return .brown
        }
    }
}

// MARK: - Collection Sort Options
public enum CollectionSortOption: String, CaseIterable {
    case name = "name"
    case dateCreated = "date_created"
    case dateUpdated = "date_updated"
    case lastAccessed = "last_accessed"
    case streamCount = "stream_count"
    case duration = "duration"
    case rating = "rating"
    case accessCount = "access_count"
    
    public var displayName: String {
        switch self {
        case .name: return "Name"
        case .dateCreated: return "Date Created"
        case .dateUpdated: return "Date Updated"
        case .lastAccessed: return "Last Accessed"
        case .streamCount: return "Stream Count"
        case .duration: return "Duration"
        case .rating: return "Rating"
        case .accessCount: return "Access Count"
        }
    }
}

