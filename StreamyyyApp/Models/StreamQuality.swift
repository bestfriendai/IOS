//
//  StreamQuality.swift
//  StreamyyyApp
//
//  Comprehensive stream quality definitions with platform-specific mapping
//  Created by Claude Code on 2025-07-09
//

import Foundation
import SwiftUI

// MARK: - StreamQuality Enum

/// Represents all possible stream quality levels with comprehensive platform support
public enum StreamQuality: String, CaseIterable, Codable, Identifiable, Hashable, Comparable {
    case auto = "auto"
    case source = "source"
    case hd2160p = "2160p"           // 4K
    case hd1440p = "1440p"           // 2K
    case hd1080p60 = "1080p60"       // 1080p at 60fps
    case hd1080p = "1080p"           // 1080p at 30fps
    case hd720p60 = "720p60"         // 720p at 60fps
    case hd720p = "720p"             // 720p at 30fps
    case medium = "480p"             // 480p
    case low = "360p"                // 360p
    case mobile = "160p"             // 160p
    case audio = "audio"             // Audio only
    
    public var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .source: return "Source"
        case .hd2160p: return "4K (2160p)"
        case .hd1440p: return "2K (1440p)"
        case .hd1080p60: return "1080p60"
        case .hd1080p: return "1080p"
        case .hd720p60: return "720p60"
        case .hd720p: return "720p"
        case .medium: return "480p"
        case .low: return "360p"
        case .mobile: return "160p"
        case .audio: return "Audio Only"
        }
    }
    
    /// Short display name for compact UI
    public var shortDisplayName: String {
        switch self {
        case .auto: return "Auto"
        case .source: return "Source"
        case .hd2160p: return "4K"
        case .hd1440p: return "2K"
        case .hd1080p60: return "1080p60"
        case .hd1080p: return "1080p"
        case .hd720p60: return "720p60"
        case .hd720p: return "720p"
        case .medium: return "480p"
        case .low: return "360p"
        case .mobile: return "160p"
        case .audio: return "Audio"
        }
    }
    
    /// Description of the quality level
    public var description: String {
        switch self {
        case .auto: return "Automatically select best quality based on connection"
        case .source: return "Original broadcast quality"
        case .hd2160p: return "Ultra HD 4K resolution"
        case .hd1440p: return "Quad HD 2K resolution"
        case .hd1080p60: return "Full HD 1080p at 60 frames per second"
        case .hd1080p: return "Full HD 1080p at 30 frames per second"
        case .hd720p60: return "HD 720p at 60 frames per second"
        case .hd720p: return "HD 720p at 30 frames per second"
        case .medium: return "Standard definition 480p"
        case .low: return "Low definition 360p"
        case .mobile: return "Mobile optimized 160p"
        case .audio: return "Audio only, no video"
        }
    }
    
    /// Resolution string (width x height)
    public var resolution: String {
        switch self {
        case .auto: return "Auto"
        case .source: return "Source"
        case .hd2160p: return "3840x2160"
        case .hd1440p: return "2560x1440"
        case .hd1080p60: return "1920x1080@60"
        case .hd1080p: return "1920x1080@30"
        case .hd720p60: return "1280x720@60"
        case .hd720p: return "1280x720@30"
        case .medium: return "854x480"
        case .low: return "640x360"
        case .mobile: return "284x160"
        case .audio: return "Audio"
        }
    }
    
    /// Frame rate (fps)
    public var frameRate: Int {
        switch self {
        case .auto: return 0 // Variable
        case .source: return 0 // Variable
        case .hd2160p: return 30
        case .hd1440p: return 30
        case .hd1080p60: return 60
        case .hd1080p: return 30
        case .hd720p60: return 60
        case .hd720p: return 30
        case .medium: return 30
        case .low: return 30
        case .mobile: return 30
        case .audio: return 0 // No video
        }
    }
    
    /// Estimated bitrate in kbps
    public var bitrate: Int {
        switch self {
        case .auto: return 0 // Variable
        case .source: return 8000
        case .hd2160p: return 12000
        case .hd1440p: return 8000
        case .hd1080p60: return 6000
        case .hd1080p: return 4500
        case .hd720p60: return 3500
        case .hd720p: return 2500
        case .medium: return 1000
        case .low: return 500
        case .mobile: return 250
        case .audio: return 128
        }
    }
    
    /// Estimated data usage per hour in MB
    public var dataUsagePerHour: Double {
        return Double(bitrate) * 60 * 60 / 8 / 1024 // Convert kbps to MB/hour
    }
    
    /// Quality level for comparison (higher is better)
    public var qualityLevel: Int {
        switch self {
        case .auto: return 1000 // Special case - highest priority
        case .source: return 900
        case .hd2160p: return 800
        case .hd1440p: return 700
        case .hd1080p60: return 600
        case .hd1080p: return 500
        case .hd720p60: return 400
        case .hd720p: return 300
        case .medium: return 200
        case .low: return 100
        case .mobile: return 50
        case .audio: return 25
        }
    }
    
    /// Whether this quality includes video
    public var hasVideo: Bool {
        return self != .audio
    }
    
    /// Whether this quality is considered HD
    public var isHD: Bool {
        switch self {
        case .hd2160p, .hd1440p, .hd1080p60, .hd1080p, .hd720p60, .hd720p:
            return true
        default:
            return false
        }
    }
    
    /// Whether this quality is considered 4K/UHD
    public var is4K: Bool {
        return self == .hd2160p
    }
    
    /// Whether this quality supports high frame rate (60fps)
    public var isHighFrameRate: Bool {
        switch self {
        case .hd1080p60, .hd720p60:
            return true
        default:
            return false
        }
    }
    
    /// Color for UI representation
    public var color: Color {
        switch self {
        case .auto: return .blue
        case .source: return .purple
        case .hd2160p: return .red
        case .hd1440p: return .orange
        case .hd1080p60, .hd1080p: return .green
        case .hd720p60, .hd720p: return .yellow
        case .medium: return .orange
        case .low: return .red
        case .mobile: return .gray
        case .audio: return .cyan
        }
    }
    
    /// SF Symbol icon for the quality
    public var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .source: return "crown"
        case .hd2160p: return "4k.tv"
        case .hd1440p: return "tv.fill"
        case .hd1080p60, .hd1080p: return "tv"
        case .hd720p60, .hd720p: return "display"
        case .medium: return "rectangle.on.rectangle"
        case .low: return "rectangle"
        case .mobile: return "iphone"
        case .audio: return "speaker.wave.2"
        }
    }
    
    // MARK: - Platform-Specific Values
    
    /// Twitch-specific quality value
    public var twitchValue: String {
        switch self {
        case .auto: return "auto"
        case .source: return "source"
        case .hd2160p: return "source" // Twitch doesn't have 4K
        case .hd1440p: return "source" // Twitch doesn't have 1440p
        case .hd1080p60: return "720p60" // Twitch's best quality
        case .hd1080p: return "720p"
        case .hd720p60: return "720p60"
        case .hd720p: return "720p"
        case .medium: return "480p"
        case .low: return "360p"
        case .mobile: return "160p"
        case .audio: return "audio_only"
        }
    }
    
    /// YouTube-specific quality value
    public var youTubeValue: String {
        switch self {
        case .auto: return "auto"
        case .source: return "source"
        case .hd2160p: return "2160p"
        case .hd1440p: return "1440p"
        case .hd1080p60: return "1080p60"
        case .hd1080p: return "1080p"
        case .hd720p60: return "720p60"
        case .hd720p: return "720p"
        case .medium: return "480p"
        case .low: return "360p"
        case .mobile: return "240p"
        case .audio: return "audio"
        }
    }
    
    /// Kick-specific quality value
    public var kickValue: String {
        switch self {
        case .auto: return "auto"
        case .source: return "source"
        case .hd2160p: return "source" // Kick doesn't have 4K
        case .hd1440p: return "source" // Kick doesn't have 1440p
        case .hd1080p60: return "1080p"
        case .hd1080p: return "1080p"
        case .hd720p60: return "720p"
        case .hd720p: return "720p"
        case .medium: return "480p"
        case .low: return "360p"
        case .mobile: return "160p"
        case .audio: return "audio"
        }
    }
    
    /// Generic platform quality value
    public var genericValue: String {
        return rawValue
    }
    
    // MARK: - Quality Selection Logic
    
    /// Recommends quality based on connection speed (Mbps)
    public static func recommendedQuality(for connectionSpeed: Double) -> StreamQuality {
        switch connectionSpeed {
        case 0..<0.5: return .mobile
        case 0.5..<1.0: return .low
        case 1.0..<2.0: return .medium
        case 2.0..<4.0: return .hd720p
        case 4.0..<6.0: return .hd720p60
        case 6.0..<8.0: return .hd1080p
        case 8.0..<12.0: return .hd1080p60
        case 12.0..<16.0: return .hd1440p
        case 16.0...: return .hd2160p
        default: return .auto
        }
    }
    
    /// Recommends quality based on device capabilities
    public static func recommendedQuality(for deviceType: DeviceType) -> StreamQuality {
        switch deviceType {
        case .iPhone:
            return .hd1080p
        case .iPad:
            return .hd1080p60
        case .iPadPro:
            return .hd1440p
        case .appleTV:
            return .hd2160p
        case .mac:
            return .hd1440p
        case .unknown:
            return .auto
        }
    }
    
    /// Recommends quality based on battery level
    public static func recommendedQuality(for batteryLevel: Float) -> StreamQuality {
        switch batteryLevel {
        case 0..<0.2: return .mobile
        case 0.2..<0.4: return .low
        case 0.4..<0.6: return .medium
        case 0.6..<0.8: return .hd720p
        case 0.8...1.0: return .hd1080p
        default: return .auto
        }
    }
    
    /// Returns the best quality available from a list
    public static func bestQuality(from qualities: [StreamQuality]) -> StreamQuality? {
        return qualities.max { $0.qualityLevel < $1.qualityLevel }
    }
    
    /// Returns the worst quality available from a list
    public static func worstQuality(from qualities: [StreamQuality]) -> StreamQuality? {
        return qualities.min { $0.qualityLevel < $1.qualityLevel }
    }
    
    /// Filters qualities based on maximum bitrate
    public static func qualities(maxBitrate: Int) -> [StreamQuality] {
        return StreamQuality.allCases.filter { $0.bitrate <= maxBitrate }
    }
    
    /// Filters qualities that support video
    public static var videoQualities: [StreamQuality] {
        return StreamQuality.allCases.filter { $0.hasVideo }
    }
    
    /// Filters qualities that are HD
    public static var hdQualities: [StreamQuality] {
        return StreamQuality.allCases.filter { $0.isHD }
    }
    
    /// Filters qualities that support high frame rate
    public static var highFrameRateQualities: [StreamQuality] {
        return StreamQuality.allCases.filter { $0.isHighFrameRate }
    }
    
    // MARK: - Platform-Specific Quality Mapping
    
    /// Maps platform-specific quality string to StreamQuality
    public static func from(platformValue: String, platform: Platform) -> StreamQuality? {
        switch platform {
        case .twitch:
            return fromTwitchValue(platformValue)
        case .youtube:
            return fromYouTubeValue(platformValue)
        case .kick:
            return fromKickValue(platformValue)
        default:
            return StreamQuality(rawValue: platformValue)
        }
    }
    
    /// Maps Twitch quality string to StreamQuality
    public static func fromTwitchValue(_ value: String) -> StreamQuality? {
        switch value {
        case "auto": return .auto
        case "source": return .source
        case "720p60": return .hd720p60
        case "720p": return .hd720p
        case "480p": return .medium
        case "360p": return .low
        case "160p": return .mobile
        case "audio_only": return .audio
        default: return nil
        }
    }
    
    /// Maps YouTube quality string to StreamQuality
    public static func fromYouTubeValue(_ value: String) -> StreamQuality? {
        switch value {
        case "auto": return .auto
        case "source": return .source
        case "2160p": return .hd2160p
        case "1440p": return .hd1440p
        case "1080p60": return .hd1080p60
        case "1080p": return .hd1080p
        case "720p60": return .hd720p60
        case "720p": return .hd720p
        case "480p": return .medium
        case "360p": return .low
        case "240p": return .mobile
        case "audio": return .audio
        default: return nil
        }
    }
    
    /// Maps Kick quality string to StreamQuality
    public static func fromKickValue(_ value: String) -> StreamQuality? {
        switch value {
        case "auto": return .auto
        case "source": return .source
        case "1080p": return .hd1080p
        case "720p": return .hd720p
        case "480p": return .medium
        case "360p": return .low
        case "160p": return .mobile
        case "audio": return .audio
        default: return nil
        }
    }
    
    /// Gets platform-specific quality value
    public func value(for platform: Platform) -> String {
        switch platform {
        case .twitch: return twitchValue
        case .youtube: return youTubeValue
        case .kick: return kickValue
        default: return genericValue
        }
    }
    
    // MARK: - Quality Comparison
    
    /// Compares two quality levels
    public static func < (lhs: StreamQuality, rhs: StreamQuality) -> Bool {
        return lhs.qualityLevel < rhs.qualityLevel
    }
    
    /// Checks if quality is better than another
    public func isBetterThan(_ other: StreamQuality) -> Bool {
        return self.qualityLevel > other.qualityLevel
    }
    
    /// Checks if quality is worse than another
    public func isWorseThan(_ other: StreamQuality) -> Bool {
        return self.qualityLevel < other.qualityLevel
    }
    
    /// Checks if quality is equivalent to another
    public func isEquivalentTo(_ other: StreamQuality) -> Bool {
        return self.qualityLevel == other.qualityLevel
    }
    
    // MARK: - Quality Adaptation
    
    /// Adapts quality for specific network conditions
    public func adaptForNetwork(bandwidth: Double, latency: Double, packetLoss: Double) -> StreamQuality {
        var adaptedQuality = self
        
        // Reduce quality for low bandwidth
        if bandwidth < 1.0 {
            adaptedQuality = .mobile
        } else if bandwidth < 2.0 {
            adaptedQuality = .low
        } else if bandwidth < 4.0 {
            adaptedQuality = .medium
        } else if bandwidth < 6.0 {
            adaptedQuality = .hd720p
        }
        
        // Reduce quality for high latency
        if latency > 200 {
            adaptedQuality = StreamQuality(rawValue: adaptedQuality.rawValue) ?? .low
        }
        
        // Reduce quality for high packet loss
        if packetLoss > 0.05 {
            adaptedQuality = StreamQuality(rawValue: adaptedQuality.rawValue) ?? .low
        }
        
        return adaptedQuality
    }
    
    /// Adapts quality for device performance
    public func adaptForDevice(cpuUsage: Double, memoryUsage: Double, batteryLevel: Float) -> StreamQuality {
        var adaptedQuality = self
        
        // Reduce quality for high CPU usage
        if cpuUsage > 0.8 {
            adaptedQuality = .medium
        } else if cpuUsage > 0.6 {
            adaptedQuality = .hd720p
        }
        
        // Reduce quality for high memory usage
        if memoryUsage > 0.8 {
            adaptedQuality = .low
        } else if memoryUsage > 0.6 {
            adaptedQuality = .medium
        }
        
        // Reduce quality for low battery
        if batteryLevel < 0.2 {
            adaptedQuality = .mobile
        } else if batteryLevel < 0.4 {
            adaptedQuality = .low
        }
        
        return adaptedQuality
    }
}

// MARK: - Supporting Types

/// Device type for quality recommendations
public enum DeviceType {
    case iPhone
    case iPad
    case iPadPro
    case appleTV
    case mac
    case unknown
}

// MARK: - Quality Preset

/// Predefined quality presets for different use cases
public struct QualityPreset {
    public let name: String
    public let qualities: [StreamQuality]
    public let description: String
    
    public init(name: String, qualities: [StreamQuality], description: String) {
        self.name = name
        self.qualities = qualities
        self.description = description
    }
    
    /// Data saver preset
    public static let dataSaver = QualityPreset(
        name: "Data Saver",
        qualities: [.mobile, .low, .medium],
        description: "Optimized for minimal data usage"
    )
    
    /// Balanced preset
    public static let balanced = QualityPreset(
        name: "Balanced",
        qualities: [.auto, .hd720p, .hd1080p, .medium, .low],
        description: "Good balance of quality and performance"
    )
    
    /// High quality preset
    public static let highQuality = QualityPreset(
        name: "High Quality",
        qualities: [.auto, .source, .hd1080p60, .hd1080p, .hd720p60],
        description: "Best possible quality"
    )
    
    /// Gaming preset
    public static let gaming = QualityPreset(
        name: "Gaming",
        qualities: [.auto, .hd1080p60, .hd720p60, .hd720p],
        description: "Optimized for gaming streams with high frame rate"
    )
    
    /// Mobile preset
    public static let mobile = QualityPreset(
        name: "Mobile",
        qualities: [.auto, .hd720p, .medium, .low, .mobile],
        description: "Optimized for mobile viewing"
    )
    
    /// Audio only preset
    public static let audioOnly = QualityPreset(
        name: "Audio Only",
        qualities: [.audio],
        description: "Audio only for background listening"
    )
    
    /// All presets
    public static let allPresets: [QualityPreset] = [
        .dataSaver, .balanced, .highQuality, .gaming, .mobile, .audioOnly
    ]
}

// MARK: - Quality Manager

/// Manages quality selection and adaptation
public class QualityManager: ObservableObject {
    @Published public var currentQuality: StreamQuality = .auto
    @Published public var availableQualities: [StreamQuality] = []
    @Published public var isAdaptive: Bool = true
    
    public init() {}
    
    /// Sets available qualities for a platform
    public func setAvailableQualities(for platform: Platform) {
        availableQualities = platform.availableQualities
    }
    
    /// Selects best quality for current conditions
    public func selectBestQuality(
        bandwidth: Double,
        deviceType: DeviceType,
        batteryLevel: Float,
        isOnCellular: Bool
    ) -> StreamQuality {
        var selectedQuality = StreamQuality.recommendedQuality(for: bandwidth)
        
        // Adapt for device
        selectedQuality = StreamQuality.recommendedQuality(for: deviceType)
        
        // Adapt for battery
        if batteryLevel < 0.5 {
            selectedQuality = StreamQuality.recommendedQuality(for: batteryLevel)
        }
        
        // Adapt for cellular connection
        if isOnCellular {
            selectedQuality = min(selectedQuality, .hd720p)
        }
        
        // Ensure selected quality is available
        if !availableQualities.contains(selectedQuality) {
            selectedQuality = StreamQuality.bestQuality(from: availableQualities) ?? .auto
        }
        
        return selectedQuality
    }
    
    /// Adapts quality based on performance metrics
    public func adaptQuality(
        cpuUsage: Double,
        memoryUsage: Double,
        droppedFrames: Int,
        bandwidth: Double
    ) {
        guard isAdaptive else { return }
        
        var newQuality = currentQuality
        
        // Downgrade for high CPU usage
        if cpuUsage > 0.8 && currentQuality.qualityLevel > StreamQuality.medium.qualityLevel {
            newQuality = StreamQuality.allCases.first {
                $0.qualityLevel < currentQuality.qualityLevel
            } ?? .medium
        }
        
        // Downgrade for high memory usage
        if memoryUsage > 0.8 && currentQuality.qualityLevel > StreamQuality.low.qualityLevel {
            newQuality = StreamQuality.allCases.first {
                $0.qualityLevel < currentQuality.qualityLevel
            } ?? .low
        }
        
        // Downgrade for dropped frames
        if droppedFrames > 10 && currentQuality.qualityLevel > StreamQuality.medium.qualityLevel {
            newQuality = StreamQuality.allCases.first {
                $0.qualityLevel < currentQuality.qualityLevel
            } ?? .medium
        }
        
        // Upgrade for improved conditions
        if cpuUsage < 0.5 && memoryUsage < 0.5 && droppedFrames == 0 {
            if let betterQuality = StreamQuality.allCases.first(where: {
                $0.qualityLevel > currentQuality.qualityLevel && availableQualities.contains($0)
            }) {
                newQuality = betterQuality
            }
        }
        
        if newQuality != currentQuality {
            currentQuality = newQuality
        }
    }
}