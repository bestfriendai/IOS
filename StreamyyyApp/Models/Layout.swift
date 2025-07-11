//
//  Layout.swift
//  StreamyyyApp
//
//  Stream layout configuration model
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Layout Model
@Model
public class Layout: Identifiable, Codable, ObservableObject {
    @Attribute(.unique) public var id: String
    public var name: String
    public var description: String?
    public var type: LayoutType
    public var configuration: LayoutConfiguration
    public var isDefault: Bool
    public var isCustom: Bool
    public var isPremium: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?
    public var useCount: Int
    public var thumbnailURL: String?
    public var tags: [String]
    public var metadata: [String: String]
    public var version: Int
    public var isShared: Bool
    public var shareCode: String?
    public var authorName: String?
    public var downloadCount: Int
    public var rating: Double
    public var ratingCount: Int
    
    // MARK: - Relationships
    @Relationship(inverse: \User.layouts)
    public var owner: User?
    
    @Relationship(deleteRule: .cascade, inverse: \LayoutStream.layout)
    public var streams: [LayoutStream] = []
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        name: String,
        type: LayoutType,
        configuration: LayoutConfiguration? = nil,
        owner: User? = nil
    ) {
        self.id = id
        self.name = name
        self.description = nil
        self.type = type
        self.configuration = configuration ?? LayoutConfiguration.default(for: type)
        self.isDefault = false
        self.isCustom = true
        self.isPremium = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastUsedAt = nil
        self.useCount = 0
        self.thumbnailURL = nil
        self.tags = []
        self.metadata = [:]
        self.version = 1
        self.isShared = false
        self.shareCode = nil
        self.authorName = nil
        self.downloadCount = 0
        self.rating = 0.0
        self.ratingCount = 0
        self.owner = owner
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, description, type, configuration, isDefault, isCustom, isPremium
        case createdAt, updatedAt, lastUsedAt, useCount, thumbnailURL, tags, metadata
        case version, isShared, shareCode, authorName, downloadCount, rating, ratingCount
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        type = try container.decode(LayoutType.self, forKey: .type)
        configuration = try container.decode(LayoutConfiguration.self, forKey: .configuration)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        isCustom = try container.decode(Bool.self, forKey: .isCustom)
        isPremium = try container.decode(Bool.self, forKey: .isPremium)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        useCount = try container.decode(Int.self, forKey: .useCount)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        tags = try container.decode([String].self, forKey: .tags)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        version = try container.decode(Int.self, forKey: .version)
        isShared = try container.decode(Bool.self, forKey: .isShared)
        shareCode = try container.decodeIfPresent(String.self, forKey: .shareCode)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        downloadCount = try container.decode(Int.self, forKey: .downloadCount)
        rating = try container.decode(Double.self, forKey: .rating)
        ratingCount = try container.decode(Int.self, forKey: .ratingCount)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(type, forKey: .type)
        try container.encode(configuration, forKey: .configuration)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encode(useCount, forKey: .useCount)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(tags, forKey: .tags)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(version, forKey: .version)
        try container.encode(isShared, forKey: .isShared)
        try container.encodeIfPresent(shareCode, forKey: .shareCode)
        try container.encodeIfPresent(authorName, forKey: .authorName)
        try container.encode(downloadCount, forKey: .downloadCount)
        try container.encode(rating, forKey: .rating)
        try container.encode(ratingCount, forKey: .ratingCount)
    }
}

// MARK: - Layout Extensions
extension Layout {
    
    // MARK: - Computed Properties
    public var displayName: String {
        return name.isEmpty ? type.displayName : name
    }
    
    public var isPopular: Bool {
        return downloadCount > 100 || rating > 4.0
    }
    
    public var isHighlyRated: Bool {
        return rating >= 4.5 && ratingCount >= 10
    }
    
    public var isRecentlyUsed: Bool {
        guard let lastUsedAt = lastUsedAt else { return false }
        let daysSinceUsed = Calendar.current.dateComponents([.day], from: lastUsedAt, to: Date()).day ?? 0
        return daysSinceUsed <= 7
    }
    
    public var isFrequentlyUsed: Bool {
        return useCount >= 10
    }
    
    public var maxStreams: Int {
        return configuration.maxStreams
    }
    
    public var canAddMoreStreams: Bool {
        return streams.count < maxStreams
    }
    
    public var displayRating: String {
        return String(format: "%.1f", rating)
    }
    
    public var ratingStars: String {
        let fullStars = Int(rating)
        let hasHalfStar = rating - Double(fullStars) >= 0.5
        let emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
        
        return String(repeating: "★", count: fullStars) +
               (hasHalfStar ? "☆" : "") +
               String(repeating: "☆", count: emptyStars)
    }
    
    public var typeColor: Color {
        return type.color
    }
    
    public var typeIcon: String {
        return type.icon
    }
    
    public var statusColor: Color {
        if isPremium {
            return .purple
        } else if isShared {
            return .blue
        } else if isDefault {
            return .green
        } else {
            return .gray
        }
    }
    
    public var statusIcon: String {
        if isPremium {
            return "crown.fill"
        } else if isShared {
            return "square.and.arrow.up"
        } else if isDefault {
            return "checkmark.circle.fill"
        } else {
            return "person.fill"
        }
    }
    
    // MARK: - Update Methods
    public func updateConfiguration(_ newConfiguration: LayoutConfiguration) {
        configuration = newConfiguration
        version += 1
        updatedAt = Date()
    }
    
    public func recordUsage() {
        useCount += 1
        lastUsedAt = Date()
        updatedAt = Date()
    }
    
    public func updateName(_ newName: String) {
        name = newName
        updatedAt = Date()
    }
    
    public func updateDescription(_ newDescription: String?) {
        description = newDescription
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
    
    // MARK: - Stream Management
    public func addStream(position: StreamPosition, streamId: String) {
        guard canAddMoreStreams else { return }
        let layoutStream = LayoutStream(
            layoutId: id,
            streamId: streamId,
            position: position,
            order: streams.count
        )
        streams.append(layoutStream)
        updatedAt = Date()
    }
    
    public func removeStream(streamId: String) {
        streams.removeAll { $0.streamId == streamId }
        // Reorder remaining streams
        for (index, stream) in streams.enumerated() {
            stream.order = index
        }
        updatedAt = Date()
    }
    
    public func updateStreamPosition(streamId: String, position: StreamPosition) {
        if let stream = streams.first(where: { $0.streamId == streamId }) {
            stream.position = position
            updatedAt = Date()
        }
    }
    
    // MARK: - Validation
    public func validateConfiguration() -> Bool {
        return configuration.validate()
    }
    
    public func validateName() -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Export/Import
    public func exportConfiguration() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "description": description ?? "",
            "type": type.rawValue,
            "configuration": configuration.export(),
            "version": version,
            "createdAt": createdAt.timeIntervalSince1970,
            "tags": tags,
            "metadata": metadata
        ]
    }
    
    public static func importConfiguration(_ data: [String: Any]) -> Layout? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let typeRaw = data["type"] as? String,
              let type = LayoutType(rawValue: typeRaw),
              let configData = data["configuration"] as? [String: Any],
              let configuration = LayoutConfiguration.import(configData) else {
            return nil
        }
        
        let layout = Layout(id: id, name: name, type: type, configuration: configuration)
        layout.description = data["description"] as? String
        layout.version = data["version"] as? Int ?? 1
        layout.tags = data["tags"] as? [String] ?? []
        layout.metadata = data["metadata"] as? [String: String] ?? [:]
        
        if let timestamp = data["createdAt"] as? TimeInterval {
            layout.createdAt = Date(timeIntervalSince1970: timestamp)
        }
        
        return layout
    }
    
    // MARK: - Export/Import Methods
    public func toDictionary() -> [String: Any]? {
        do {
            let data = try JSONEncoder().encode(self)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return dictionary
        } catch {
            print("Error converting layout to dictionary: \(error)")
            return nil
        }
    }
    
    public func exportConfiguration() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "description": description ?? "",
            "type": type.rawValue,
            "configuration": [
                "maxStreams": configuration.maxStreams,
                "gridColumns": configuration.gridColumns,
                "gridRows": configuration.gridRows,
                "spacing": configuration.spacing,
                "aspectRatio": configuration.aspectRatio
            ],
            "version": version,
            "tags": tags,
            "metadata": metadata,
            "exportedAt": ISO8601DateFormatter().string(from: Date())
        ]
    }
    
    public static func importConfiguration(_ data: [String: Any]) -> Layout? {
        guard let name = data["name"] as? String,
              let typeString = data["type"] as? String,
              let type = LayoutType(rawValue: typeString) else {
            return nil
        }
        
        let layout = Layout(name: name, type: type, configuration: LayoutConfiguration())
        
        if let id = data["id"] as? String {
            layout.id = id
        }
        
        if let description = data["description"] as? String {
            layout.description = description
        }
        
        if let tags = data["tags"] as? [String] {
            layout.tags = tags
        }
        
        if let metadata = data["metadata"] as? [String: String] {
            layout.metadata = metadata
        }
        
        return layout
    }
}

// MARK: - Layout Type
public enum LayoutType: String, CaseIterable, Codable {
    case stack = "stack"
    case grid2x2 = "grid2x2"
    case grid3x3 = "grid3x3"
    case grid4x4 = "grid4x4"
    case carousel = "carousel"
    case focus = "focus"
    case splitView = "split_view"
    case mosaic = "mosaic"
    case theater = "theater"
    case dashboard = "dashboard"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .stack: return "Stack"
        case .grid2x2: return "2x2 Grid"
        case .grid3x3: return "3x3 Grid"
        case .grid4x4: return "4x4 Grid"
        case .carousel: return "Carousel"
        case .focus: return "Focus"
        case .splitView: return "Split View"
        case .mosaic: return "Mosaic"
        case .theater: return "Theater"
        case .dashboard: return "Dashboard"
        case .custom: return "Custom"
        }
    }
    
    public var description: String {
        switch self {
        case .stack: return "Vertical stack of streams"
        case .grid2x2: return "2x2 grid layout"
        case .grid3x3: return "3x3 grid layout"
        case .grid4x4: return "4x4 grid layout"
        case .carousel: return "Horizontal carousel"
        case .focus: return "One main stream with thumbnails"
        case .splitView: return "Split screen layout"
        case .mosaic: return "Flexible mosaic layout"
        case .theater: return "Theater-style layout"
        case .dashboard: return "Dashboard with widgets"
        case .custom: return "Custom layout"
        }
    }
    
    public var icon: String {
        switch self {
        case .stack: return "rectangle.stack"
        case .grid2x2: return "grid"
        case .grid3x3: return "square.grid.3x3"
        case .grid4x4: return "square.grid.4x4"
        case .carousel: return "rectangle.3.group"
        case .focus: return "viewfinder"
        case .splitView: return "rectangle.split.2x1"
        case .mosaic: return "square.on.square"
        case .theater: return "tv"
        case .dashboard: return "rectangle.3.offgrid"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    public var color: Color {
        switch self {
        case .stack: return .blue
        case .grid2x2: return .green
        case .grid3x3: return .orange
        case .grid4x4: return .red
        case .carousel: return .purple
        case .focus: return .yellow
        case .splitView: return .pink
        case .mosaic: return .teal
        case .theater: return .indigo
        case .dashboard: return .brown
        case .custom: return .gray
        }
    }
    
    public var maxStreams: Int {
        switch self {
        case .stack: return 10
        case .grid2x2: return 4
        case .grid3x3: return 9
        case .grid4x4: return 16
        case .carousel: return 20
        case .focus: return 5
        case .splitView: return 2
        case .mosaic: return 12
        case .theater: return 1
        case .dashboard: return 8
        case .custom: return 50
        }
    }
    
    public var isPremium: Bool {
        switch self {
        case .stack, .grid2x2, .carousel, .focus:
            return false
        case .grid3x3, .grid4x4, .splitView, .mosaic, .theater, .dashboard, .custom:
            return true
        }
    }
    
    public var defaultConfiguration: LayoutConfiguration {
        return LayoutConfiguration.default(for: self)
    }
}

// MARK: - Layout Configuration
public struct LayoutConfiguration: Codable {
    public var spacing: Double
    public var padding: EdgeInsets
    public var backgroundColor: String
    public var borderWidth: Double
    public var borderColor: String
    public var cornerRadius: Double
    public var shadowRadius: Double
    public var shadowOpacity: Double
    public var shadowOffset: CGSize
    public var aspectRatio: Double?
    public var animationDuration: Double
    public var enableAnimations: Bool
    public var showLabels: Bool
    public var labelPosition: LabelPosition
    public var labelFontSize: Double
    public var labelColor: String
    public var showControls: Bool
    public var controlsPosition: ControlsPosition
    public var autoHideControls: Bool
    public var controlsTimeout: Double
    public var enableGestures: Bool
    public var enableDragAndDrop: Bool
    public var snapToGrid: Bool
    public var gridSize: Double
    public var minStreamSize: CGSize
    public var maxStreamSize: CGSize
    public var customProperties: [String: Any]
    
    public init() {
        self.spacing = 8.0
        self.padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        self.backgroundColor = "systemBackground"
        self.borderWidth = 1.0
        self.borderColor = "separator"
        self.cornerRadius = 8.0
        self.shadowRadius = 4.0
        self.shadowOpacity = 0.1
        self.shadowOffset = CGSize(width: 0, height: 2)
        self.aspectRatio = nil
        self.animationDuration = 0.3
        self.enableAnimations = true
        self.showLabels = true
        self.labelPosition = .bottom
        self.labelFontSize = 14.0
        self.labelColor = "label"
        self.showControls = true
        self.controlsPosition = .overlay
        self.autoHideControls = true
        self.controlsTimeout = 3.0
        self.enableGestures = true
        self.enableDragAndDrop = true
        self.snapToGrid = true
        self.gridSize = 20.0
        self.minStreamSize = CGSize(width: 100, height: 75)
        self.maxStreamSize = CGSize(width: 800, height: 600)
        self.customProperties = [:]
    }
    
    public static func `default`(for type: LayoutType) -> LayoutConfiguration {
        var config = LayoutConfiguration()
        
        switch type {
        case .stack:
            config.spacing = 12.0
            config.aspectRatio = 16.0/9.0
        case .grid2x2, .grid3x3, .grid4x4:
            config.spacing = 8.0
            config.aspectRatio = 16.0/9.0
        case .carousel:
            config.spacing = 16.0
            config.aspectRatio = 16.0/9.0
            config.minStreamSize = CGSize(width: 200, height: 112)
        case .focus:
            config.spacing = 12.0
            config.aspectRatio = 16.0/9.0
        case .splitView:
            config.spacing = 4.0
            config.aspectRatio = 16.0/9.0
        case .mosaic:
            config.spacing = 6.0
            config.snapToGrid = false
        case .theater:
            config.spacing = 0.0
            config.showControls = false
            config.showLabels = false
        case .dashboard:
            config.spacing = 16.0
            config.showLabels = true
            config.labelPosition = .top
        case .custom:
            config.enableDragAndDrop = true
            config.snapToGrid = false
        }
        
        return config
    }
    
    public var maxStreams: Int {
        if let aspectRatio = aspectRatio {
            // Calculate based on aspect ratio and screen size
            return Int(aspectRatio * 10)
        }
        return 20
    }
    
    public func validate() -> Bool {
        return spacing >= 0 &&
               borderWidth >= 0 &&
               cornerRadius >= 0 &&
               shadowRadius >= 0 &&
               shadowOpacity >= 0 && shadowOpacity <= 1 &&
               animationDuration >= 0 &&
               labelFontSize > 0 &&
               controlsTimeout > 0 &&
               gridSize > 0 &&
               minStreamSize.width > 0 && minStreamSize.height > 0 &&
               maxStreamSize.width > minStreamSize.width &&
               maxStreamSize.height > minStreamSize.height
    }
    
    public func export() -> [String: Any] {
        return [
            "spacing": spacing,
            "padding": [
                "top": padding.top,
                "leading": padding.leading,
                "bottom": padding.bottom,
                "trailing": padding.trailing
            ],
            "backgroundColor": backgroundColor,
            "borderWidth": borderWidth,
            "borderColor": borderColor,
            "cornerRadius": cornerRadius,
            "shadowRadius": shadowRadius,
            "shadowOpacity": shadowOpacity,
            "shadowOffset": [
                "width": shadowOffset.width,
                "height": shadowOffset.height
            ],
            "aspectRatio": aspectRatio as Any,
            "animationDuration": animationDuration,
            "enableAnimations": enableAnimations,
            "showLabels": showLabels,
            "labelPosition": labelPosition.rawValue,
            "labelFontSize": labelFontSize,
            "labelColor": labelColor,
            "showControls": showControls,
            "controlsPosition": controlsPosition.rawValue,
            "autoHideControls": autoHideControls,
            "controlsTimeout": controlsTimeout,
            "enableGestures": enableGestures,
            "enableDragAndDrop": enableDragAndDrop,
            "snapToGrid": snapToGrid,
            "gridSize": gridSize,
            "minStreamSize": [
                "width": minStreamSize.width,
                "height": minStreamSize.height
            ],
            "maxStreamSize": [
                "width": maxStreamSize.width,
                "height": maxStreamSize.height
            ],
            "customProperties": customProperties
        ]
    }
    
    public static func `import`(_ data: [String: Any]) -> LayoutConfiguration? {
        var config = LayoutConfiguration()
        
        config.spacing = data["spacing"] as? Double ?? config.spacing
        config.backgroundColor = data["backgroundColor"] as? String ?? config.backgroundColor
        config.borderWidth = data["borderWidth"] as? Double ?? config.borderWidth
        config.borderColor = data["borderColor"] as? String ?? config.borderColor
        config.cornerRadius = data["cornerRadius"] as? Double ?? config.cornerRadius
        config.shadowRadius = data["shadowRadius"] as? Double ?? config.shadowRadius
        config.shadowOpacity = data["shadowOpacity"] as? Double ?? config.shadowOpacity
        config.aspectRatio = data["aspectRatio"] as? Double
        config.animationDuration = data["animationDuration"] as? Double ?? config.animationDuration
        config.enableAnimations = data["enableAnimations"] as? Bool ?? config.enableAnimations
        config.showLabels = data["showLabels"] as? Bool ?? config.showLabels
        config.labelFontSize = data["labelFontSize"] as? Double ?? config.labelFontSize
        config.labelColor = data["labelColor"] as? String ?? config.labelColor
        config.showControls = data["showControls"] as? Bool ?? config.showControls
        config.autoHideControls = data["autoHideControls"] as? Bool ?? config.autoHideControls
        config.controlsTimeout = data["controlsTimeout"] as? Double ?? config.controlsTimeout
        config.enableGestures = data["enableGestures"] as? Bool ?? config.enableGestures
        config.enableDragAndDrop = data["enableDragAndDrop"] as? Bool ?? config.enableDragAndDrop
        config.snapToGrid = data["snapToGrid"] as? Bool ?? config.snapToGrid
        config.gridSize = data["gridSize"] as? Double ?? config.gridSize
        config.customProperties = data["customProperties"] as? [String: Any] ?? config.customProperties
        
        if let paddingData = data["padding"] as? [String: Double] {
            config.padding = EdgeInsets(
                top: paddingData["top"] ?? config.padding.top,
                leading: paddingData["leading"] ?? config.padding.leading,
                bottom: paddingData["bottom"] ?? config.padding.bottom,
                trailing: paddingData["trailing"] ?? config.padding.trailing
            )
        }
        
        if let shadowOffsetData = data["shadowOffset"] as? [String: Double] {
            config.shadowOffset = CGSize(
                width: shadowOffsetData["width"] ?? config.shadowOffset.width,
                height: shadowOffsetData["height"] ?? config.shadowOffset.height
            )
        }
        
        if let labelPositionRaw = data["labelPosition"] as? String {
            config.labelPosition = LabelPosition(rawValue: labelPositionRaw) ?? config.labelPosition
        }
        
        if let controlsPositionRaw = data["controlsPosition"] as? String {
            config.controlsPosition = ControlsPosition(rawValue: controlsPositionRaw) ?? config.controlsPosition
        }
        
        if let minSizeData = data["minStreamSize"] as? [String: Double] {
            config.minStreamSize = CGSize(
                width: minSizeData["width"] ?? config.minStreamSize.width,
                height: minSizeData["height"] ?? config.minStreamSize.height
            )
        }
        
        if let maxSizeData = data["maxStreamSize"] as? [String: Double] {
            config.maxStreamSize = CGSize(
                width: maxSizeData["width"] ?? config.maxStreamSize.width,
                height: maxSizeData["height"] ?? config.maxStreamSize.height
            )
        }
        
        return config.validate() ? config : nil
    }
}

// MARK: - Layout Stream
@Model
public class LayoutStream: Identifiable, Codable {
    @Attribute(.unique) public var id: String
    public var layoutId: String
    public var streamId: String
    public var position: StreamPosition
    public var order: Int
    public var isVisible: Bool
    public var isLocked: Bool
    public var customProperties: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    
    @Relationship(inverse: \Layout.streams)
    public var layout: Layout?
    
    public init(
        id: String = UUID().uuidString,
        layoutId: String,
        streamId: String,
        position: StreamPosition,
        order: Int = 0
    ) {
        self.id = id
        self.layoutId = layoutId
        self.streamId = streamId
        self.position = position
        self.order = order
        self.isVisible = true
        self.isLocked = false
        self.customProperties = [:]
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, layoutId, streamId, position, order, isVisible, isLocked
        case customProperties, createdAt, updatedAt
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        layoutId = try container.decode(String.self, forKey: .layoutId)
        streamId = try container.decode(String.self, forKey: .streamId)
        position = try container.decode(StreamPosition.self, forKey: .position)
        order = try container.decode(Int.self, forKey: .order)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        customProperties = try container.decode([String: String].self, forKey: .customProperties)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(layoutId, forKey: .layoutId)
        try container.encode(streamId, forKey: .streamId)
        try container.encode(position, forKey: .position)
        try container.encode(order, forKey: .order)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(customProperties, forKey: .customProperties)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Supporting Enums
public enum LabelPosition: String, CaseIterable, Codable {
    case top = "top"
    case bottom = "bottom"
    case overlay = "overlay"
    case hidden = "hidden"
    
    public var displayName: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .overlay: return "Overlay"
        case .hidden: return "Hidden"
        }
    }
}

public enum ControlsPosition: String, CaseIterable, Codable {
    case overlay = "overlay"
    case bottom = "bottom"
    case side = "side"
    case hidden = "hidden"
    
    public var displayName: String {
        switch self {
        case .overlay: return "Overlay"
        case .bottom: return "Bottom"
        case .side: return "Side"
        case .hidden: return "Hidden"
        }
    }
}

// MARK: - Layout Errors
public enum LayoutError: Error, LocalizedError {
    case invalidConfiguration
    case maxStreamsExceeded
    case streamNotFound
    case layoutNotFound
    case premiumRequired
    case sharingNotAllowed
    case importFailed
    case exportFailed
    case validationFailed
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid layout configuration"
        case .maxStreamsExceeded:
            return "Maximum number of streams exceeded"
        case .streamNotFound:
            return "Stream not found"
        case .layoutNotFound:
            return "Layout not found"
        case .premiumRequired:
            return "Premium subscription required"
        case .sharingNotAllowed:
            return "Sharing not allowed"
        case .importFailed:
            return "Failed to import layout"
        case .exportFailed:
            return "Failed to export layout"
        case .validationFailed:
            return "Layout validation failed"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

