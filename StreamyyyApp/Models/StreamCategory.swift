//
//  StreamCategory.swift
//  StreamyyyApp
//
//  Comprehensive stream category model
//  Created by Claude Code on 2025-07-10
//

import Foundation

// MARK: - Stream Category
public struct StreamCategory: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let platform: Platform
    public let viewerCount: Int
    public let streamCount: Int
    public let thumbnailURL: String?
    public let platforms: Set<Platform>?
    
    public init(
        id: String,
        name: String,
        platform: Platform,
        viewerCount: Int,
        streamCount: Int,
        thumbnailURL: String? = nil,
        platforms: Set<Platform>? = nil
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.viewerCount = viewerCount
        self.streamCount = streamCount
        self.thumbnailURL = thumbnailURL
        self.platforms = platforms
    }
    
    // MARK: - Computed Properties
    
    public var displayName: String {
        return name.isEmpty ? "Unknown Category" : name
    }
    
    public var formattedViewerCount: String {
        if viewerCount >= 1_000_000 {
            return String(format: "%.1fM", Double(viewerCount) / 1_000_000)
        } else if viewerCount >= 1_000 {
            return String(format: "%.1fK", Double(viewerCount) / 1_000)
        } else {
            return "\(viewerCount)"
        }
    }
    
    public var formattedStreamCount: String {
        if streamCount >= 1_000_000 {
            return String(format: "%.1fM", Double(streamCount) / 1_000_000)
        } else if streamCount >= 1_000 {
            return String(format: "%.1fK", Double(streamCount) / 1_000)
        } else {
            return "\(streamCount)"
        }
    }
    
    public var isPopular: Bool {
        return viewerCount > 10_000 || streamCount > 100
    }
    
    public var platformNames: String {
        if let platforms = platforms, !platforms.isEmpty {
            return platforms.map { $0.displayName }.joined(separator: ", ")
        } else {
            return platform.displayName
        }
    }
    
    // MARK: - Static Categories
    
    public static let gaming = StreamCategory(
        id: "gaming",
        name: "Gaming",
        platform: .twitch,
        viewerCount: 500_000,
        streamCount: 15_000,
        thumbnailURL: nil
    )
    
    public static let justChatting = StreamCategory(
        id: "just-chatting",
        name: "Just Chatting",
        platform: .twitch,
        viewerCount: 300_000,
        streamCount: 8_000,
        thumbnailURL: nil
    )
    
    public static let music = StreamCategory(
        id: "music",
        name: "Music & Performing Arts",
        platform: .twitch,
        viewerCount: 50_000,
        streamCount: 2_000,
        thumbnailURL: nil
    )
    
    public static let creative = StreamCategory(
        id: "creative",
        name: "Art & Creative",
        platform: .twitch,
        viewerCount: 25_000,
        streamCount: 1_500,
        thumbnailURL: nil
    )
    
    public static let irl = StreamCategory(
        id: "irl",
        name: "IRL",
        platform: .twitch,
        viewerCount: 75_000,
        streamCount: 3_000,
        thumbnailURL: nil
    )
    
    public static let allCategories: [StreamCategory] = [
        .gaming, .justChatting, .music, .creative, .irl
    ]
}

// MARK: - Extensions

extension StreamCategory {
    // Helper for converting from TwitchGame
    public static func from(twitchGame: TwitchGame) -> StreamCategory {
        return StreamCategory(
            id: twitchGame.id,
            name: twitchGame.name,
            platform: .twitch,
            viewerCount: 0,
            streamCount: 0,
            thumbnailURL: twitchGame.boxArtUrlLarge
        )
    }
}

// MARK: - Preview Data

extension StreamCategory {
    public static let sampleData: [StreamCategory] = [
        StreamCategory(
            id: "1",
            name: "League of Legends",
            platform: .twitch,
            viewerCount: 150_000,
            streamCount: 2_500,
            thumbnailURL: "https://static-cdn.jtvnw.net/ttv-boxart/21779-285x380.jpg"
        ),
        StreamCategory(
            id: "2",
            name: "Fortnite",
            platform: .twitch,
            viewerCount: 120_000,
            streamCount: 3_200,
            thumbnailURL: "https://static-cdn.jtvnw.net/ttv-boxart/33214-285x380.jpg"
        ),
        StreamCategory(
            id: "3",
            name: "Valorant",
            platform: .twitch,
            viewerCount: 80_000,
            streamCount: 1_800,
            thumbnailURL: "https://static-cdn.jtvnw.net/ttv-boxart/516575-285x380.jpg"
        ),
        StreamCategory(
            id: "4",
            name: "Minecraft",
            platform: .twitch,
            viewerCount: 60_000,
            streamCount: 4_500,
            thumbnailURL: "https://static-cdn.jtvnw.net/ttv-boxart/27471_IGDB-285x380.jpg"
        ),
        StreamCategory(
            id: "5",
            name: "Grand Theft Auto V",
            platform: .twitch,
            viewerCount: 45_000,
            streamCount: 1_200,
            thumbnailURL: "https://static-cdn.jtvnw.net/ttv-boxart/32982_IGDB-285x380.jpg"
        )
    ]
}