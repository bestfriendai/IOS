//
//  Favorite.swift
//  StreamyyyApp
//
//  User favorites model with relationships
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Favorite Model
@Model
public class Favorite: Identifiable, Codable, ObservableObject {
    @Attribute(.unique) public var id: String
    public var createdAt: Date
    public var updatedAt: Date
    public var addedFromSearch: Bool
    public var tags: [String]
    public var notes: String?
    public var lastViewedAt: Date?
    public var viewCount: Int
    public var rating: Int // 1-5 stars
    public var isNotificationEnabled: Bool
    public var customTitle: String?
    public var sortOrder: Int
    public var isArchived: Bool
    public var archivedAt: Date?
    public var metadata: [String: String]
    
    // MARK: - Relationships
    @Relationship(inverse: \User.favorites)
    public var user: User?
    
    @Relationship(inverse: \Stream.favoritedBy)
    public var stream: Stream?
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        user: User? = nil,
        stream: Stream? = nil,
        addedFromSearch: Bool = false
    ) {
        self.id = id
        self.createdAt = Date()
        self.updatedAt = Date()
        self.addedFromSearch = addedFromSearch
        self.tags = []
        self.notes = nil
        self.lastViewedAt = nil
        self.viewCount = 0
        self.rating = 0
        self.isNotificationEnabled = true
        self.customTitle = nil
        self.sortOrder = 0
        self.isArchived = false
        self.archivedAt = nil
        self.metadata = [:]
        self.user = user
        self.stream = stream
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, addedFromSearch, tags, notes
        case lastViewedAt, viewCount, rating, isNotificationEnabled
        case customTitle, sortOrder, isArchived, archivedAt, metadata
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        addedFromSearch = try container.decode(Bool.self, forKey: .addedFromSearch)
        tags = try container.decode([String].self, forKey: .tags)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        lastViewedAt = try container.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        rating = try container.decode(Int.self, forKey: .rating)
        isNotificationEnabled = try container.decode(Bool.self, forKey: .isNotificationEnabled)
        customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(addedFromSearch, forKey: .addedFromSearch)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(lastViewedAt, forKey: .lastViewedAt)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(rating, forKey: .rating)
        try container.encode(isNotificationEnabled, forKey: .isNotificationEnabled)
        try container.encodeIfPresent(customTitle, forKey: .customTitle)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try container.encode(metadata, forKey: .metadata)
    }
}

// MARK: - Favorite Extensions
extension Favorite {
    
    // MARK: - Computed Properties
    public var displayTitle: String {
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
        return stream?.displayTitle ?? "Favorite Stream"
    }
    
    public var displaySubtitle: String {
        if let stream = stream {
            return "\(stream.platform.displayName) • \(stream.streamerName ?? "Unknown")"
        }
        return "Stream"
    }
    
    public var isRated: Bool {
        return rating > 0
    }
    
    public var ratingStars: String {
        return String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
    }
    
    public var ratingColor: Color {
        switch rating {
        case 1...2: return .red
        case 3: return .orange
        case 4: return .yellow
        case 5: return .green
        default: return .gray
        }
    }
    
    public var timeSinceAdded: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    public var timeSinceLastViewed: String {
        guard let lastViewedAt = lastViewedAt else { return "Never viewed" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastViewedAt, relativeTo: Date())
    }
    
    public var isRecentlyViewed: Bool {
        guard let lastViewedAt = lastViewedAt else { return false }
        let daysSinceViewed = Calendar.current.dateComponents([.day], from: lastViewedAt, to: Date()).day ?? 0
        return daysSinceViewed <= 7
    }
    
    public var isFrequentlyViewed: Bool {
        return viewCount >= 10
    }
    
    public var viewFrequency: FavoriteViewFrequency {
        if viewCount >= 20 {
            return .veryHigh
        } else if viewCount >= 10 {
            return .high
        } else if viewCount >= 5 {
            return .medium
        } else if viewCount >= 1 {
            return .low
        } else {
            return .none
        }
    }
    
    public var categoryColor: Color {
        guard let stream = stream else { return .gray }
        return stream.platform.color
    }
    
    public var statusIcon: String {
        if isArchived {
            return "archivebox.fill"
        } else if isNotificationEnabled {
            return "bell.fill"
        } else {
            return "heart.fill"
        }
    }
    
    public var statusColor: Color {
        if isArchived {
            return .gray
        } else if isNotificationEnabled {
            return .blue
        } else {
            return .red
        }
    }
    
    // MARK: - Update Methods
    public func updateRating(_ newRating: Int) {
        rating = max(0, min(5, newRating))
        updatedAt = Date()
    }
    
    public func updateNotes(_ newNotes: String?) {
        notes = newNotes
        updatedAt = Date()
    }
    
    public func updateCustomTitle(_ newTitle: String?) {
        customTitle = newTitle
        updatedAt = Date()
    }
    
    public func recordView() {
        viewCount += 1
        lastViewedAt = Date()
        updatedAt = Date()
    }
    
    public func toggleNotifications() {
        isNotificationEnabled.toggle()
        updatedAt = Date()
    }
    
    public func updateSortOrder(_ newOrder: Int) {
        sortOrder = newOrder
        updatedAt = Date()
    }
    
    // MARK: - Archive Methods
    public func archive() {
        isArchived = true
        archivedAt = Date()
        updatedAt = Date()
    }
    
    public func unarchive() {
        isArchived = false
        archivedAt = nil
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
    
    public func clearTags() {
        tags.removeAll()
        updatedAt = Date()
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
    
    // MARK: - Validation Methods
    public func validateRating() -> Bool {
        return rating >= 0 && rating <= 5
    }
    
    public func validateTags() -> Bool {
        return tags.count <= 10 && tags.allSatisfy { $0.count <= 50 }
    }
    
    public func validateNotes() -> Bool {
        return notes?.count ?? 0 <= 500
    }
    
    // MARK: - Export Methods
    public func exportData() -> [String: Any] {
        return [
            "id": id,
            "streamTitle": displayTitle,
            "streamURL": stream?.url ?? "",
            "platform": stream?.platform.displayName ?? "",
            "rating": rating,
            "notes": notes ?? "",
            "tags": tags,
            "viewCount": viewCount,
            "createdAt": createdAt,
            "lastViewedAt": lastViewedAt ?? Date.distantPast,
            "isNotificationEnabled": isNotificationEnabled
        ]
    }
}

// MARK: - Favorite View Frequency
public enum FavoriteViewFrequency: String, CaseIterable, Codable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    public var displayName: String {
        switch self {
        case .none: return "Not viewed"
        case .low: return "Rarely viewed"
        case .medium: return "Sometimes viewed"
        case .high: return "Often viewed"
        case .veryHigh: return "Frequently viewed"
        }
    }
    
    public var color: Color {
        switch self {
        case .none: return .gray
        case .low: return .blue
        case .medium: return .green
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
    
    public var icon: String {
        switch self {
        case .none: return "eye.slash"
        case .low: return "eye"
        case .medium: return "eye.fill"
        case .high: return "eyes"
        case .veryHigh: return "eyes.inverse"
        }
    }
}

// MARK: - Favorite Category
public enum FavoriteCategory: String, CaseIterable, Codable {
    case gaming = "gaming"
    case justChatting = "just_chatting"
    case music = "music"
    case sports = "sports"
    case art = "art"
    case technology = "technology"
    case education = "education"
    case entertainment = "entertainment"
    case news = "news"
    case lifestyle = "lifestyle"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .gaming: return "Gaming"
        case .justChatting: return "Just Chatting"
        case .music: return "Music"
        case .sports: return "Sports"
        case .art: return "Art"
        case .technology: return "Technology"
        case .education: return "Education"
        case .entertainment: return "Entertainment"
        case .news: return "News"
        case .lifestyle: return "Lifestyle"
        case .other: return "Other"
        }
    }
    
    public var color: Color {
        switch self {
        case .gaming: return .purple
        case .justChatting: return .blue
        case .music: return .pink
        case .sports: return .green
        case .art: return .orange
        case .technology: return .gray
        case .education: return .yellow
        case .entertainment: return .red
        case .news: return .black
        case .lifestyle: return .brown
        case .other: return .gray
        }
    }
    
    public var icon: String {
        switch self {
        case .gaming: return "gamecontroller"
        case .justChatting: return "message"
        case .music: return "music.note"
        case .sports: return "sportscourt"
        case .art: return "paintbrush"
        case .technology: return "gear"
        case .education: return "book"
        case .entertainment: return "tv"
        case .news: return "newspaper"
        case .lifestyle: return "heart"
        case .other: return "star"
        }
    }
}

// MARK: - Favorite Sort Options
public enum FavoriteSortOption: String, CaseIterable, Codable {
    case dateAdded = "date_added"
    case lastViewed = "last_viewed"
    case viewCount = "view_count"
    case rating = "rating"
    case title = "title"
    case platform = "platform"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .dateAdded: return "Date Added"
        case .lastViewed: return "Last Viewed"
        case .viewCount: return "View Count"
        case .rating: return "Rating"
        case .title: return "Title"
        case .platform: return "Platform"
        case .custom: return "Custom Order"
        }
    }
    
    public var icon: String {
        switch self {
        case .dateAdded: return "calendar"
        case .lastViewed: return "clock"
        case .viewCount: return "eye"
        case .rating: return "star"
        case .title: return "textformat"
        case .platform: return "tv"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Favorite Collection
public class FavoriteCollection: ObservableObject {
    @Published public var favorites: [Favorite] = []
    @Published public var sortOption: FavoriteSortOption = .dateAdded
    @Published public var isAscending: Bool = false
    @Published public var filterTags: [String] = []
    @Published public var filterPlatforms: [Platform] = []
    @Published public var showArchivedOnly: Bool = false
    @Published public var searchText: String = ""
    
    public var filteredFavorites: [Favorite] {
        var filtered = favorites
        
        // Filter by archived status
        if showArchivedOnly {
            filtered = filtered.filter { $0.isArchived }
        } else {
            filtered = filtered.filter { !$0.isArchived }
        }
        
        // Filter by tags
        if !filterTags.isEmpty {
            filtered = filtered.filter { favorite in
                !Set(favorite.tags).isDisjoint(with: Set(filterTags))
            }
        }
        
        // Filter by platforms
        if !filterPlatforms.isEmpty {
            filtered = filtered.filter { favorite in
                guard let stream = favorite.stream else { return false }
                return filterPlatforms.contains(stream.platform)
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { favorite in
                favorite.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                favorite.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                favorite.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        filtered.sort { lhs, rhs in
            let result: Bool
            switch sortOption {
            case .dateAdded:
                result = lhs.createdAt < rhs.createdAt
            case .lastViewed:
                result = (lhs.lastViewedAt ?? Date.distantPast) < (rhs.lastViewedAt ?? Date.distantPast)
            case .viewCount:
                result = lhs.viewCount < rhs.viewCount
            case .rating:
                result = lhs.rating < rhs.rating
            case .title:
                result = lhs.displayTitle < rhs.displayTitle
            case .platform:
                result = (lhs.stream?.platform.displayName ?? "") < (rhs.stream?.platform.displayName ?? "")
            case .custom:
                result = lhs.sortOrder < rhs.sortOrder
            }
            return isAscending ? result : !result
        }
        
        return filtered
    }
    
    public var groupedFavorites: [String: [Favorite]] {
        Dictionary(grouping: filteredFavorites) { favorite in
            switch sortOption {
            case .platform:
                return favorite.stream?.platform.displayName ?? "Unknown"
            case .rating:
                return "\(favorite.rating) Stars"
            case .viewCount:
                return favorite.viewFrequency.displayName
            default:
                return "All Favorites"
            }
        }
    }
    
    public func addFavorite(_ favorite: Favorite) {
        favorites.append(favorite)
    }
    
    public func removeFavorite(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
    }
    
    public func toggleSort(by option: FavoriteSortOption) {
        if sortOption == option {
            isAscending.toggle()
        } else {
            sortOption = option
            isAscending = false
        }
    }
    
    public func clearFilters() {
        filterTags.removeAll()
        filterPlatforms.removeAll()
        searchText = ""
    }
}

// MARK: - Favorite Errors
public enum FavoriteError: Error, LocalizedError {
    case alreadyFavorited
    case notFound
    case streamNotFound
    case userNotFound
    case invalidRating
    case tooManyTags
    case tagTooLong
    case notesTooLong
    case archiveError
    case exportError
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .alreadyFavorited:
            return "Stream already favorited"
        case .notFound:
            return "Favorite not found"
        case .streamNotFound:
            return "Stream not found"
        case .userNotFound:
            return "User not found"
        case .invalidRating:
            return "Invalid rating (must be 0-5)"
        case .tooManyTags:
            return "Too many tags (maximum 10)"
        case .tagTooLong:
            return "Tag too long (maximum 50 characters)"
        case .notesTooLong:
            return "Notes too long (maximum 500 characters)"
        case .archiveError:
            return "Failed to archive favorite"
        case .exportError:
            return "Failed to export favorites"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}