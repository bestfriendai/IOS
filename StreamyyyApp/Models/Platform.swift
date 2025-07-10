//
//  Platform.swift
//  StreamyyyApp
//
//  Comprehensive streaming platform definitions with full feature support
//  Created by Claude Code on 2025-07-09
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Platform Enum
/// Represents all supported streaming platforms with their capabilities and configurations
public enum Platform: String, CaseIterable, Codable, Identifiable, Hashable {
    case twitch = "twitch"
    case youtube = "youtube"
    case rumble = "rumble"
    case kick = "kick"
    case tiktok = "tiktok"
    case instagram = "instagram"
    case facebook = "facebook"
    case discord = "discord"
    case mixer = "mixer"
    case dlive = "dlive"
    case trovo = "trovo"
    case nimo = "nimo"
    case bigo = "bigo"
    case other = "other"
    
    public var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Human-readable display name for the platform
    public var displayName: String {
        switch self {
        case .twitch: return "Twitch"
        case .youtube: return "YouTube"
        case .rumble: return "Rumble"
        case .kick: return "Kick"
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .facebook: return "Facebook"
        case .discord: return "Discord"
        case .mixer: return "Mixer"
        case .dlive: return "DLive"
        case .trovo: return "Trovo"
        case .nimo: return "Nimo TV"
        case .bigo: return "Bigo Live"
        case .other: return "Other"
        }
    }
    
    /// Platform brand color for UI theming
    public var color: Color {
        switch self {
        case .twitch: return Color(red: 0.58, green: 0.27, blue: 0.88) // Purple
        case .youtube: return Color(red: 1.0, green: 0.0, blue: 0.0) // Red
        case .rumble: return Color(red: 0.13, green: 0.55, blue: 0.13) // Dark Green
        case .kick: return Color(red: 0.33, green: 0.87, blue: 0.29) // Green
        case .tiktok: return Color(red: 0.0, green: 0.0, blue: 0.0) // Black
        case .instagram: return Color(red: 0.91, green: 0.26, blue: 0.71) // Pink/Purple gradient
        case .facebook: return Color(red: 0.26, green: 0.40, blue: 0.70) // Blue
        case .discord: return Color(red: 0.35, green: 0.39, blue: 0.84) // Blurple
        case .mixer: return Color(red: 0.0, green: 0.47, blue: 0.84) // Blue
        case .dlive: return Color(red: 0.98, green: 0.73, blue: 0.13) // Yellow
        case .trovo: return Color(red: 0.0, green: 0.70, blue: 0.42) // Green
        case .nimo: return Color(red: 0.93, green: 0.16, blue: 0.49) // Pink
        case .bigo: return Color(red: 0.25, green: 0.71, blue: 0.96) // Light Blue
        case .other: return Color.gray
        }
    }
    
    /// UIKit color for compatibility
    public var uiColor: UIColor {
        UIColor(color)
    }
    
    /// SF Symbol icon name for the platform
    public var icon: String {
        switch self {
        case .twitch: return "tv"
        case .youtube: return "play.rectangle"
        case .rumble: return "video.circle"
        case .kick: return "sportscourt"
        case .tiktok: return "music.note"
        case .instagram: return "camera"
        case .facebook: return "person.2"
        case .discord: return "message"
        case .mixer: return "waveform.path.ecg"
        case .dlive: return "dot.radiowaves.left.and.right"
        case .trovo: return "gamecontroller"
        case .nimo: return "tv.badge.wifi"
        case .bigo: return "video.badge.plus"
        case .other: return "globe"
        }
    }
    
    /// Filled version of the SF Symbol icon
    public var systemImage: String {
        switch self {
        case .twitch: return "tv.fill"
        case .youtube: return "play.rectangle.fill"
        case .rumble: return "video.circle.fill"
        case .kick: return "sportscourt.fill"
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .facebook: return "person.2.fill"
        case .discord: return "message.fill"
        case .mixer: return "waveform.path.ecg.rectangle.fill"
        case .dlive: return "dot.radiowaves.left.and.right"
        case .trovo: return "gamecontroller.fill"
        case .nimo: return "tv.badge.wifi.fill"
        case .bigo: return "video.badge.plus.fill"
        case .other: return "globe"
        }
    }
    
    /// Platform description for UI
    public var description: String {
        switch self {
        case .twitch: return "Live streaming platform for gamers"
        case .youtube: return "Video sharing and live streaming"
        case .rumble: return "Video platform focused on free speech"
        case .kick: return "Live streaming platform with low latency"
        case .tiktok: return "Short-form video and live streaming"
        case .instagram: return "Social media with live streaming"
        case .facebook: return "Social network with live video"
        case .discord: return "Voice and video chat platform"
        case .mixer: return "Interactive live streaming (deprecated)"
        case .dlive: return "Blockchain-based streaming platform"
        case .trovo: return "Live streaming platform by Tencent"
        case .nimo: return "Live streaming platform by Huya"
        case .bigo: return "Live streaming and video chat"
        case .other: return "Generic streaming platform"
        }
    }
    
    // MARK: - URL Properties
    
    /// Base URL for the platform
    public var baseURL: String {
        switch self {
        case .twitch: return "https://www.twitch.tv"
        case .youtube: return "https://www.youtube.com"
        case .rumble: return "https://rumble.com"
        case .kick: return "https://kick.com"
        case .tiktok: return "https://www.tiktok.com"
        case .instagram: return "https://www.instagram.com"
        case .facebook: return "https://www.facebook.com"
        case .discord: return "https://discord.com"
        case .mixer: return "https://mixer.com"
        case .dlive: return "https://dlive.tv"
        case .trovo: return "https://trovo.live"
        case .nimo: return "https://www.nimo.tv"
        case .bigo: return "https://www.bigo.tv"
        case .other: return ""
        }
    }
    
    /// Embed URL for iframe embedding
    public var embedURL: String {
        switch self {
        case .twitch: return "https://player.twitch.tv"
        case .youtube: return "https://www.youtube.com/embed"
        case .rumble: return "https://rumble.com/embed"
        case .kick: return "https://player.kick.com"
        case .tiktok: return "https://www.tiktok.com/embed"
        case .instagram: return "https://www.instagram.com/embed"
        case .facebook: return "https://www.facebook.com/plugins/video.php"
        case .discord: return ""
        case .mixer: return ""
        case .dlive: return "https://dlive.tv/embed"
        case .trovo: return "https://trovo.live/embed"
        case .nimo: return "https://www.nimo.tv/embed"
        case .bigo: return "https://www.bigo.tv/embed"
        case .other: return ""
        }
    }
    
    /// API endpoint for the platform
    public var apiURL: String {
        switch self {
        case .twitch: return "https://api.twitch.tv/helix"
        case .youtube: return "https://www.googleapis.com/youtube/v3"
        case .rumble: return "https://rumble.com/api"
        case .kick: return "https://kick.com/api/v1"
        case .tiktok: return "https://open-api.tiktok.com"
        case .instagram: return "https://graph.instagram.com"
        case .facebook: return "https://graph.facebook.com"
        case .discord: return "https://discord.com/api/v10"
        case .mixer: return ""
        case .dlive: return "https://graphigo.prd.dlive.tv"
        case .trovo: return "https://open-api.trovo.live"
        case .nimo: return "https://www.nimo.tv/api"
        case .bigo: return "https://api.bigo.tv"
        case .other: return ""
        }
    }
    
    /// WebSocket URL for real-time data
    public var websocketURL: String {
        switch self {
        case .twitch: return "wss://irc-ws.chat.twitch.tv:443"
        case .youtube: return ""
        case .rumble: return ""
        case .kick: return "wss://ws-us2.pusher.app"
        case .tiktok: return ""
        case .instagram: return ""
        case .facebook: return ""
        case .discord: return "wss://gateway.discord.gg"
        case .mixer: return ""
        case .dlive: return "wss://graphigostream.prd.dlive.tv"
        case .trovo: return "wss://open-chat.trovo.live"
        case .nimo: return "wss://ws.nimo.tv"
        case .bigo: return "wss://ws.bigo.tv"
        case .other: return ""
        }
    }
    
    // MARK: - Platform Capabilities
    
    /// Whether the platform supports iframe embedding
    public var supportsEmbedding: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick: return true
        case .tiktok, .instagram, .facebook: return true
        case .dlive, .trovo, .nimo, .bigo: return true
        case .discord, .mixer, .other: return false
        }
    }
    
    /// Whether the platform supports live chat
    public var supportsChat: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick, .discord: return true
        case .dlive, .trovo, .nimo, .bigo: return true
        case .tiktok, .instagram, .facebook: return true
        case .mixer, .other: return false
        }
    }
    
    /// Whether the platform provides viewer count
    public var supportsViewerCount: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick: return true
        case .dlive, .trovo, .nimo, .bigo: return true
        case .tiktok, .instagram, .facebook: return false
        case .discord, .mixer, .other: return false
        }
    }
    
    /// Whether the platform supports quality settings
    public var supportsQualitySettings: Bool {
        switch self {
        case .twitch, .youtube, .rumble: return true
        case .kick, .dlive, .trovo: return true
        case .tiktok, .instagram, .facebook: return false
        case .discord, .mixer, .nimo, .bigo, .other: return false
        }
    }
    
    /// Whether the platform requires user authentication
    public var requiresAuthentication: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick: return false
        case .tiktok, .instagram, .facebook: return true
        case .discord: return true
        case .mixer, .dlive, .trovo, .nimo, .bigo: return false
        case .other: return false
        }
    }
    
    /// Whether the platform supports low latency streaming
    public var supportsLowLatency: Bool {
        switch self {
        case .twitch, .kick: return true
        case .youtube, .rumble: return true
        case .dlive, .trovo: return true
        case .tiktok, .instagram, .facebook: return false
        case .discord, .mixer, .nimo, .bigo, .other: return false
        }
    }
    
    /// Whether the platform supports mobile streaming
    public var supportsMobileStreaming: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick: return true
        case .tiktok, .instagram, .facebook: return true
        case .discord, .bigo: return true
        case .mixer, .dlive, .trovo, .nimo, .other: return false
        }
    }
    
    /// Whether the platform supports VOD (Video on Demand)
    public var supportsVOD: Bool {
        switch self {
        case .twitch, .youtube, .rumble: return true
        case .kick: return true
        case .facebook: return true
        case .tiktok, .instagram, .discord: return false
        case .mixer, .dlive, .trovo, .nimo, .bigo, .other: return false
        }
    }
    
    /// Whether the platform supports clips
    public var supportsClips: Bool {
        switch self {
        case .twitch, .youtube, .rumble: return true
        case .kick: return true
        case .tiktok: return true
        case .instagram, .facebook, .discord: return false
        case .mixer, .dlive, .trovo, .nimo, .bigo, .other: return false
        }
    }
    
    /// Whether the platform supports donations/tips
    public var supportsDonations: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick: return true
        case .dlive, .trovo, .nimo, .bigo: return true
        case .tiktok, .instagram, .facebook: return false
        case .discord, .mixer, .other: return false
        }
    }
    
    /// Whether the platform supports subscriptions
    public var supportsSubscriptions: Bool {
        switch self {
        case .twitch, .youtube, .rumble: return true
        case .kick: return true
        case .dlive, .trovo: return true
        case .tiktok, .instagram, .facebook: return false
        case .discord, .mixer, .nimo, .bigo, .other: return false
        }
    }
    
    // MARK: - Quality and Performance
    
    /// Available quality levels for this platform
    public var availableQualities: [StreamQuality] {
        switch self {
        case .twitch:
            return [.auto, .source, .hd1080p60, .hd1080p, .hd720p60, .hd720p, .medium, .low, .mobile]
        case .youtube:
            return [.auto, .source, .hd1440p, .hd1080p60, .hd1080p, .hd720p60, .hd720p, .medium, .low]
        case .rumble:
            return [.auto, .source, .hd1080p, .hd720p, .medium, .low]
        case .kick:
            return [.auto, .source, .hd1080p, .hd720p, .medium, .low]
        case .dlive, .trovo:
            return [.auto, .source, .hd1080p, .hd720p, .medium, .low]
        case .tiktok, .instagram, .facebook:
            return [.auto, .source, .medium, .low]
        case .nimo, .bigo:
            return [.auto, .source, .hd720p, .medium, .low]
        case .discord, .mixer, .other:
            return [.auto, .source]
        }
    }
    
    /// Default quality level for this platform
    public var defaultQuality: StreamQuality {
        switch self {
        case .twitch, .youtube, .rumble, .kick:
            return .auto
        case .dlive, .trovo:
            return .auto
        case .tiktok, .instagram, .facebook:
            return .medium
        case .nimo, .bigo:
            return .hd720p
        case .discord, .mixer, .other:
            return .source
        }
    }
    
    /// Maximum concurrent streams allowed
    public var maxConcurrentStreams: Int {
        switch self {
        case .twitch: return 1
        case .youtube: return 5
        case .rumble: return 3
        case .kick: return 1
        case .tiktok: return 1
        case .instagram: return 4
        case .facebook: return 4
        case .discord: return 50
        case .mixer: return 1
        case .dlive: return 1
        case .trovo: return 1
        case .nimo: return 1
        case .bigo: return 1
        case .other: return 1
        }
    }
    
    /// API rate limit (requests per minute)
    public var apiRateLimit: Int {
        switch self {
        case .twitch: return 120
        case .youtube: return 100
        case .rumble: return 60
        case .kick: return 60
        case .tiktok: return 300
        case .instagram: return 200
        case .facebook: return 200
        case .discord: return 50
        case .mixer: return 0
        case .dlive: return 60
        case .trovo: return 120
        case .nimo: return 60
        case .bigo: return 60
        case .other: return 60
        }
    }
    
    // MARK: - URL Validation and Parsing
    
    /// Validates if a URL belongs to this platform
    public func isValidURL(_ url: String) -> Bool {
        guard let url = URL(string: url) else { return false }
        let host = url.host?.lowercased() ?? ""
        
        switch self {
        case .twitch:
            return host.contains("twitch.tv")
        case .youtube:
            return host.contains("youtube.com") || host.contains("youtu.be")
        case .rumble:
            return host.contains("rumble.com")
        case .kick:
            return host.contains("kick.com")
        case .tiktok:
            return host.contains("tiktok.com")
        case .instagram:
            return host.contains("instagram.com")
        case .facebook:
            return host.contains("facebook.com") || host.contains("fb.watch")
        case .discord:
            return host.contains("discord.com") || host.contains("discord.gg")
        case .mixer:
            return host.contains("mixer.com")
        case .dlive:
            return host.contains("dlive.tv")
        case .trovo:
            return host.contains("trovo.live")
        case .nimo:
            return host.contains("nimo.tv")
        case .bigo:
            return host.contains("bigo.tv")
        case .other:
            return true
        }
    }
    
    /// Extracts stream identifier from URL
    public func extractStreamIdentifier(from url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        
        switch self {
        case .twitch:
            return url.pathComponents.last
        case .youtube:
            if url.absoluteString.contains("watch?v=") {
                return url.query?.components(separatedBy: "&")
                    .first(where: { $0.hasPrefix("v=") })?
                    .replacingOccurrences(of: "v=", with: "")
            } else if url.absoluteString.contains("live/") {
                return url.pathComponents.last
            }
            return url.pathComponents.last
        case .rumble:
            // Rumble URLs: rumble.com/c/{channel} or rumble.com/v{videoId}
            let pathComponents = url.pathComponents
            if let lastComponent = pathComponents.last {
                if lastComponent.hasPrefix("v") {
                    return String(lastComponent.dropFirst()) // Remove 'v' prefix
                }
                return lastComponent
            }
            return nil
        case .kick:
            return url.pathComponents.last
        case .tiktok:
            return url.pathComponents.last
        case .instagram:
            return url.pathComponents.contains("p") ? url.pathComponents.last : nil
        case .facebook:
            return url.pathComponents.last
        case .discord:
            return url.pathComponents.last
        case .mixer:
            return url.pathComponents.last
        case .dlive:
            return url.pathComponents.last
        case .trovo:
            return url.pathComponents.last
        case .nimo:
            return url.pathComponents.last
        case .bigo:
            return url.pathComponents.last
        case .other:
            return url.absoluteString
        }
    }
    
    /// Generates embed URL for stream
    public func generateEmbedURL(for identifier: String, options: EmbedOptions = EmbedOptions()) -> String? {
        guard supportsEmbedding else { return nil }
        
        switch self {
        case .twitch:
            var params = [
                "channel=\(identifier)",
                "parent=\(options.parentDomain ?? "streamyyy.com")",
                "autoplay=\(options.autoplay ? "true" : "false")",
                "muted=\(options.muted ? "true" : "false")"
            ]
            if let quality = options.quality {
                params.append("quality=\(quality.twitchValue)")
            }
            if options.chatEnabled {
                params.append("chat=true")
            }
            return "\(embedURL)?\(params.joined(separator: "&"))"
            
        case .youtube:
            var params = [
                "autoplay=\(options.autoplay ? "1" : "0")",
                "mute=\(options.muted ? "1" : "0")",
                "controls=\(options.showControls ? "1" : "0")",
                "modestbranding=1",
                "rel=0"
            ]
            if let startTime = options.startTime {
                params.append("start=\(Int(startTime))")
            }
            return "\(embedURL)/\(identifier)?\(params.joined(separator: "&"))"
            
        case .rumble:
            var params = [
                "autoplay=\(options.autoplay ? "1" : "0")",
                "muted=\(options.muted ? "1" : "0")"
            ]
            return "\(embedURL)/\(identifier)?\(params.joined(separator: "&"))"
            
        case .kick:
            var params = [
                "autoplay=\(options.autoplay ? "true" : "false")",
                "muted=\(options.muted ? "true" : "false")"
            ]
            return "\(embedURL)/\(identifier)?\(params.joined(separator: "&"))"
            
        case .tiktok:
            return "\(embedURL)/\(identifier)"
            
        case .instagram:
            return "\(embedURL)/\(identifier)"
            
        case .facebook:
            var params = [
                "href=\(baseURL)/\(identifier)",
                "autoplay=\(options.autoplay ? "true" : "false")",
                "muted=\(options.muted ? "true" : "false")"
            ]
            return "\(embedURL)?\(params.joined(separator: "&"))"
            
        case .dlive:
            return "\(embedURL)/\(identifier)"
            
        case .trovo:
            return "\(embedURL)/\(identifier)"
            
        case .nimo:
            return "\(embedURL)/\(identifier)"
            
        case .bigo:
            return "\(embedURL)/\(identifier)"
            
        case .discord, .mixer, .other:
            return nil
        }
    }
    
    /// Generates chat URL for stream
    public func generateChatURL(for identifier: String) -> String? {
        guard supportsChat else { return nil }
        
        switch self {
        case .twitch:
            return "https://www.twitch.tv/embed/\(identifier)/chat?parent=streamyyy.com"
        case .youtube:
            return "https://www.youtube.com/live_chat?v=\(identifier)"
        case .rumble:
            return "https://rumble.com/c/\(identifier)"
        case .kick:
            return "https://kick.com/\(identifier)/chatroom"
        case .discord:
            return "https://discord.com/channels/\(identifier)"
        case .dlive:
            return "https://dlive.tv/\(identifier)"
        case .trovo:
            return "https://trovo.live/\(identifier)"
        case .nimo:
            return "https://www.nimo.tv/\(identifier)"
        case .bigo:
            return "https://www.bigo.tv/\(identifier)"
        default:
            return nil
        }
    }
    
    // MARK: - Static Methods
    
    /// Detects platform from URL
    public static func detect(from url: String) -> Platform {
        guard let url = URL(string: url) else { return .other }
        let host = url.host?.lowercased() ?? ""
        
        for platform in Platform.allCases {
            if platform.isValidURL(url.absoluteString) {
                return platform
            }
        }
        
        return .other
    }
    
    /// Returns popular platforms for UI display
    public static var popularPlatforms: [Platform] {
        return [.twitch, .youtube, .rumble, .kick, .tiktok, .instagram, .facebook]
    }
    
    /// Returns platforms that support embedding
    public static var supportedPlatforms: [Platform] {
        return allCases.filter { $0.supportsEmbedding }
    }
    
    /// Returns platforms that support live streaming
    public static var liveStreamingPlatforms: [Platform] {
        return allCases.filter { $0.supportsLiveStreaming }
    }
    
    /// Returns platforms that support mobile streaming
    public static var mobileStreamingPlatforms: [Platform] {
        return allCases.filter { $0.supportsMobileStreaming }
    }
}

// MARK: - Platform Extensions

extension Platform {
    /// Whether platform supports live streaming
    public var supportsLiveStreaming: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick, .tiktok, .instagram, .facebook, .discord:
            return true
        case .dlive, .trovo, .nimo, .bigo:
            return true
        case .mixer, .other:
            return false
        }
    }
    
    /// Whether platform supports picture-in-picture
    public var supportsPictureInPicture: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick:
            return true
        case .dlive, .trovo:
            return true
        case .tiktok, .instagram, .facebook:
            return false
        case .discord, .mixer, .nimo, .bigo, .other:
            return false
        }
    }
    
    /// Whether platform supports fullscreen mode
    public var supportsFullscreen: Bool {
        switch self {
        case .twitch, .youtube, .rumble, .kick:
            return true
        case .dlive, .trovo, .nimo, .bigo:
            return true
        case .tiktok, .instagram, .facebook:
            return true
        case .discord, .mixer, .other:
            return false
        }
    }
    
    /// Whether platform supports audio-only mode
    public var supportsAudioOnly: Bool {
        switch self {
        case .twitch, .youtube, .rumble:
            return true
        case .discord:
            return true
        case .kick, .tiktok, .instagram, .facebook:
            return false
        case .mixer, .dlive, .trovo, .nimo, .bigo, .other:
            return false
        }
    }
    
    /// Whether platform supports theater mode
    public var supportsTheaterMode: Bool {
        switch self {
        case .twitch, .youtube, .rumble:
            return true
        case .kick, .dlive, .trovo:
            return true
        case .tiktok, .instagram, .facebook:
            return false
        case .discord, .mixer, .nimo, .bigo, .other:
            return false
        }
    }
    
    /// Platform-specific user agent string
    public var userAgent: String {
        let baseUserAgent = "StreamyyyApp/1.0.0 (iOS)"
        switch self {
        case .twitch:
            return "\(baseUserAgent) TwitchPlayer/1.0"
        case .youtube:
            return "\(baseUserAgent) YouTubePlayer/1.0"
        case .rumble:
            return "\(baseUserAgent) RumblePlayer/1.0"
        case .kick:
            return "\(baseUserAgent) KickPlayer/1.0"
        default:
            return baseUserAgent
        }
    }
    
    /// Platform-specific headers for API requests
    public var apiHeaders: [String: String] {
        var headers = [
            "User-Agent": userAgent,
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        
        switch self {
        case .twitch:
            headers["Client-ID"] = "YOUR_TWITCH_CLIENT_ID"
        case .youtube:
            headers["X-YouTube-Client-Name"] = "1"
            headers["X-YouTube-Client-Version"] = "2.0"
        case .kick:
            headers["Accept"] = "application/json"
        default:
            break
        }
        
        return headers
    }
    
    /// Platform-specific embed security policies
    public var embedSecurityPolicy: String {
        switch self {
        case .twitch:
            return "frame-ancestors 'self' streamyyy.com *.streamyyy.com"
        case .youtube:
            return "frame-ancestors 'self' streamyyy.com *.streamyyy.com youtube.com *.youtube.com"
        case .rumble:
            return "frame-ancestors 'self' streamyyy.com *.streamyyy.com rumble.com *.rumble.com"
        case .kick:
            return "frame-ancestors 'self' streamyyy.com *.streamyyy.com"
        default:
            return "frame-ancestors 'self'"
        }
    }
}

// MARK: - Embed Options

/// Configuration options for embedding streams
public struct EmbedOptions {
    public var autoplay: Bool = true
    public var muted: Bool = false
    public var showControls: Bool = true
    public var chatEnabled: Bool = false
    public var quality: StreamQuality?
    public var startTime: TimeInterval?
    public var parentDomain: String?
    public var theme: String = "dark"
    public var language: String = "en"
    
    public init(
        autoplay: Bool = true,
        muted: Bool = false,
        showControls: Bool = true,
        chatEnabled: Bool = false,
        quality: StreamQuality? = nil,
        startTime: TimeInterval? = nil,
        parentDomain: String? = nil,
        theme: String = "dark",
        language: String = "en"
    ) {
        self.autoplay = autoplay
        self.muted = muted
        self.showControls = showControls
        self.chatEnabled = chatEnabled
        self.quality = quality
        self.startTime = startTime
        self.parentDomain = parentDomain
        self.theme = theme
        self.language = language
    }
}

// MARK: - Platform Statistics

/// Platform usage statistics and metrics
public struct PlatformStatistics {
    public let platform: Platform
    public let totalUsers: Int
    public let activeStreams: Int
    public let averageViewers: Int
    public let peakViewers: Int
    public let lastUpdated: Date
    
    public init(platform: Platform, totalUsers: Int, activeStreams: Int, averageViewers: Int, peakViewers: Int, lastUpdated: Date = Date()) {
        self.platform = platform
        self.totalUsers = totalUsers
        self.activeStreams = activeStreams
        self.averageViewers = averageViewers
        self.peakViewers = peakViewers
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Platform Errors

/// Platform-specific error types
public enum PlatformError: Error, LocalizedError {
    case unsupportedPlatform
    case invalidURL
    case embedNotSupported
    case authenticationRequired
    case rateLimitExceeded
    case streamNotFound
    case streamOffline
    case regionBlocked
    case ageRestricted
    case privacyRestricted
    case apiError(String)
    case networkError(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Platform is not supported"
        case .invalidURL:
            return "Invalid stream URL"
        case .embedNotSupported:
            return "Embedding not supported for this platform"
        case .authenticationRequired:
            return "Authentication required"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .streamNotFound:
            return "Stream not found"
        case .streamOffline:
            return "Stream is offline"
        case .regionBlocked:
            return "Stream is blocked in your region"
        case .ageRestricted:
            return "Stream is age restricted"
        case .privacyRestricted:
            return "Stream is private"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown Error: \(error.localizedDescription)"
        }
    }
}