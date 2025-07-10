//
//  StreamPersistenceModels.swift
//  StreamyyyApp
//
//  Enhanced models for stream persistence, session management, and analytics
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Stream Session Model
@Model
public class StreamSession: Identifiable, Codable {
    @Attribute(.unique) public var id: String
    public var name: String
    public var description: String?
    public var streamIds: [String]
    public var layoutId: String?
    public var isActive: Bool
    public var startedAt: Date
    public var endedAt: Date?
    public var duration: TimeInterval
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Relationships
    @Relationship(inverse: \User.streamSessions)
    public var owner: User?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        streamIds: [String] = [],
        layoutId: String? = nil,
        isActive: Bool = true,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        duration: TimeInterval = 0,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.streamIds = streamIds
        self.layoutId = layoutId
        self.isActive = isActive
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, description, streamIds, layoutId, isActive
        case startedAt, endedAt, duration, metadata, createdAt, updatedAt
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        streamIds = try container.decode([String].self, forKey: .streamIds)
        layoutId = try container.decodeIfPresent(String.self, forKey: .layoutId)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(streamIds, forKey: .streamIds)
        try container.encodeIfPresent(layoutId, forKey: .layoutId)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(duration, forKey: .duration)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Stream Session Extensions
extension StreamSession {
    
    public func addStream(_ streamId: String) {
        guard !streamIds.contains(streamId) else { return }
        streamIds.append(streamId)
        updatedAt = Date()
    }
    
    public func removeStream(_ streamId: String) {
        streamIds.removeAll { $0 == streamId }
        updatedAt = Date()
    }
    
    public func updateDuration() {
        if let endedAt = endedAt {
            duration = endedAt.timeIntervalSince(startedAt)
        } else {
            duration = Date().timeIntervalSince(startedAt)
        }
        updatedAt = Date()
    }
    
    public func end() {
        endedAt = Date()
        isActive = false
        updateDuration()
    }
    
    public var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

// MARK: - Stream Backup Model
public struct StreamBackup: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let name: String
    public let description: String?
    public let data: BackupData
    public let size: Int64
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        description: String? = nil,
        data: BackupData,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.description = description
        self.data = data
        self.size = data.estimatedSize
        self.createdAt = createdAt
    }
}

// MARK: - Backup Data Model
public struct BackupData: Codable {
    public let streams: [Stream]
    public let layouts: [Layout]
    public let sessions: [StreamSession]
    public let version: Int
    public let createdAt: Date
    
    public init(
        streams: [Stream],
        layouts: [Layout],
        sessions: [StreamSession],
        version: Int = 1
    ) {
        self.streams = streams
        self.layouts = layouts
        self.sessions = sessions
        self.version = version
        self.createdAt = Date()
    }
    
    public var estimatedSize: Int64 {
        // Rough estimate of serialized size
        let streamsSize = streams.count * 1024 // ~1KB per stream
        let layoutsSize = layouts.count * 512  // ~512B per layout
        let sessionsSize = sessions.count * 256 // ~256B per session
        return Int64(streamsSize + layoutsSize + sessionsSize)
    }
    
    public func toDictionary() -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(self)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try decoder.decode(BackupData.self, from: data)
        } catch {
            // Return empty backup data if decoding fails
            return BackupData(streams: [], layouts: [], sessions: [])
        }
    }
}

// MARK: - Stream Template Model
public struct StreamTemplate: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let category: String
    public let tags: [String]
    public let layoutData: [String: Any]
    public let streamData: [String: Any]
    public let thumbnailURL: String?
    public let isPublic: Bool
    public let downloads: Int
    public let rating: Double
    public let ratingCount: Int
    public let version: Int
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        category: String,
        tags: [String] = [],
        layoutData: [String: Any] = [:],
        streamData: [String: Any] = [:],
        thumbnailURL: String? = nil,
        isPublic: Bool = false,
        downloads: Int = 0,
        rating: Double = 0.0,
        ratingCount: Int = 0,
        version: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.tags = tags
        self.layoutData = layoutData
        self.streamData = streamData
        self.thumbnailURL = thumbnailURL
        self.isPublic = isPublic
        self.downloads = downloads
        self.rating = rating
        self.ratingCount = ratingCount
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, tags
        case layoutData, streamData, thumbnailURL, isPublic
        case downloads, rating, ratingCount, version
        case createdAt, updatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        tags = try container.decode([String].self, forKey: .tags)
        
        // Handle [String: Any] decoding
        if let layoutDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .layoutData) {
            layoutData = layoutDict.mapValues { $0.value }
        } else {
            layoutData = [:]
        }
        
        if let streamDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .streamData) {
            streamData = streamDict.mapValues { $0.value }
        } else {
            streamData = [:]
        }
        
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        downloads = try container.decode(Int.self, forKey: .downloads)
        rating = try container.decode(Double.self, forKey: .rating)
        ratingCount = try container.decode(Int.self, forKey: .ratingCount)
        version = try container.decode(Int.self, forKey: .version)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        
        // Handle [String: Any] encoding
        let layoutCodable = layoutData.mapValues { AnyCodable($0) }
        try container.encode(layoutCodable, forKey: .layoutData)
        
        let streamCodable = streamData.mapValues { AnyCodable($0) }
        try container.encode(streamCodable, forKey: .streamData)
        
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(downloads, forKey: .downloads)
        try container.encode(rating, forKey: .rating)
        try container.encode(ratingCount, forKey: .ratingCount)
        try container.encode(version, forKey: .version)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Stream Template Extensions
extension StreamTemplate {
    
    public var displayRating: String {
        return String(format: "%.1f", rating)
    }
    
    public var formattedDownloads: String {
        if downloads >= 1000000 {
            return String(format: "%.1fM", Double(downloads) / 1000000.0)
        } else if downloads >= 1000 {
            return String(format: "%.1fK", Double(downloads) / 1000.0)
        } else {
            return "\(downloads)"
        }
    }
    
    public var categoryColor: Color {
        switch category.lowercased() {
        case "gaming": return .purple
        case "entertainment": return .pink
        case "education": return .blue
        case "news": return .red
        case "sports": return .green
        case "music": return .orange
        default: return .gray
        }
    }
}

// MARK: - AnyCodable Helper
fileprivate struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let stringValue as String:
            try container.encode(stringValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}

// MARK: - User Extension for Stream Sessions
extension User {
    public var streamSessions: [StreamSession] {
        get { [] } // This will be populated by the relationship
        set { }
    }
}