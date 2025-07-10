//
//  TwitchModels.swift
//  StreamyyyApp
//
//  Twitch API response models
//

import Foundation

// MARK: - Twitch API Response Models

struct TwitchStreamsResponse: Codable {
    let data: [TwitchStream]
    let pagination: TwitchPagination?
}

struct TwitchStream: Codable, Identifiable {
    let id: String
    let userId: String
    let userLogin: String
    let userName: String
    let gameId: String
    let gameName: String
    let type: String
    let title: String
    let viewerCount: Int
    let startedAt: String
    let language: String
    let thumbnailUrl: String
    let tagIds: [String]?
    let tags: [String]?
    let isMature: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userLogin = "user_login"
        case userName = "user_name"
        case gameId = "game_id"
        case gameName = "game_name"
        case type
        case title
        case viewerCount = "viewer_count"
        case startedAt = "started_at"
        case language
        case thumbnailUrl = "thumbnail_url"
        case tagIds = "tag_ids"
        case tags = "tags"
        case isMature = "is_mature"
    }
    
    // Convert to our app's stream model
    func toAppStream() -> AppStream {
        return AppStream(
            id: id,
            title: title,
            url: "https://twitch.tv/\(userLogin)",
            platform: "Twitch",
            isLive: type == "live",
            viewerCount: viewerCount,
            streamerName: userName,
            gameName: gameName,
            thumbnailURL: thumbnailUrl.replacingOccurrences(of: "{width}", with: "320").replacingOccurrences(of: "{height}", with: "180"),
            language: language,
            startedAt: ISO8601DateFormatter().date(from: startedAt) ?? Date()
        )
    }
    
    // Formatted viewer count for display
    var formattedViewerCount: String {
        if viewerCount >= 1000000 {
            return String(format: "%.1fM", Double(viewerCount) / 1000000.0)
        } else if viewerCount >= 1000 {
            return String(format: "%.1fK", Double(viewerCount) / 1000.0)
        } else {
            return "\(viewerCount)"
        }
    }
    
    // Formatted thumbnail URLs for different sizes
    var thumbnailUrlSmall: String {
        return thumbnailUrl.replacingOccurrences(of: "{width}", with: "160").replacingOccurrences(of: "{height}", with: "90")
    }
    
    var thumbnailUrlMedium: String {
        return thumbnailUrl.replacingOccurrences(of: "{width}", with: "320").replacingOccurrences(of: "{height}", with: "180")
    }
    
    var thumbnailUrlLarge: String {
        return thumbnailUrl.replacingOccurrences(of: "{width}", with: "640").replacingOccurrences(of: "{height}", with: "360")
    }
}

struct TwitchPagination: Codable {
    let cursor: String?
}

struct TwitchUsersResponse: Codable {
    let data: [TwitchUser]
}

struct TwitchUser: Codable {
    let id: String
    let login: String
    let displayName: String
    let type: String
    let broadcasterType: String
    let description: String
    let profileImageUrl: String
    let offlineImageUrl: String
    let viewCount: Int
    let email: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case displayName = "display_name"
        case type
        case broadcasterType = "broadcaster_type"
        case description
        case profileImageUrl = "profile_image_url"
        case offlineImageUrl = "offline_image_url"
        case viewCount = "view_count"
        case email
        case createdAt = "created_at"
    }
}

struct TwitchGamesResponse: Codable {
    let data: [TwitchGame]
}

struct TwitchGame: Codable, Identifiable {
    let id: String
    let name: String
    let boxArtUrl: String
    let igdbId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case boxArtUrl = "box_art_url"
        case igdbId = "igdb_id"
    }
    
    // Formatted box art URLs for different sizes
    var boxArtUrlSmall: String {
        return boxArtUrl.replacingOccurrences(of: "{width}", with: "52").replacingOccurrences(of: "{height}", with: "72")
    }
    
    var boxArtUrlMedium: String {
        return boxArtUrl.replacingOccurrences(of: "{width}", with: "120").replacingOccurrences(of: "{height}", with: "160")
    }
    
    var boxArtUrlLarge: String {
        return boxArtUrl.replacingOccurrences(of: "{width}", with: "188").replacingOccurrences(of: "{height}", with: "250")
    }
}

struct TwitchFollowsResponse: Codable {
    let data: [TwitchFollow]
    let pagination: TwitchPagination?
    let total: Int?
}

struct TwitchFollow: Codable {
    let fromId: String
    let fromLogin: String
    let fromName: String
    let toId: String
    let toLogin: String
    let toName: String
    let followedAt: String
    
    enum CodingKeys: String, CodingKey {
        case fromId = "from_id"
        case fromLogin = "from_login"
        case fromName = "from_name"
        case toId = "to_id"
        case toLogin = "to_login"
        case toName = "to_name"
        case followedAt = "followed_at"
    }
}

// MARK: - App Stream Model (simplified for UI)

struct AppStream: Identifiable, Codable {
    let id: String
    let title: String
    let url: String
    let platform: String
    let isLive: Bool
    let viewerCount: Int
    let streamerName: String
    let gameName: String
    let thumbnailURL: String
    let language: String
    let startedAt: Date
    var isMuted: Bool = false
    var isFavorite: Bool = false
    
    var platformColor: Color {
        switch platform.lowercased() {
        case "twitch": return .purple
        case "youtube": return .red
        case "kick": return .green
        default: return .gray
        }
    }
    
    var formattedViewerCount: String {
        if viewerCount >= 1000000 {
            return String(format: "%.1fM", Double(viewerCount) / 1000000.0)
        } else if viewerCount >= 1000 {
            return String(format: "%.1fK", Double(viewerCount) / 1000.0)
        } else {
            return "\(viewerCount)"
        }
    }
    
    var formattedStartTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: startedAt, relativeTo: Date())
    }
}

// MARK: - Twitch Authentication Models

struct TwitchAuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let scope: [String]
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

struct TwitchTokenValidationResponse: Codable {
    let clientId: String
    let login: String?
    let scopes: [String]
    let userId: String?
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case login
        case scopes
        case userId = "user_id"
        case expiresIn = "expires_in"
    }
}

// MARK: - Error Models

struct TwitchError: Codable, Error {
    let error: String
    let status: Int
    let message: String
}

struct TwitchAPIError: Error {
    let message: String
    let statusCode: Int?
    
    static let invalidToken = TwitchAPIError(message: "Invalid or expired token", statusCode: 401)
    static let rateLimited = TwitchAPIError(message: "Rate limit exceeded", statusCode: 429)
    static let notFound = TwitchAPIError(message: "Resource not found", statusCode: 404)
    static let serverError = TwitchAPIError(message: "Server error", statusCode: 500)
    static let networkError = TwitchAPIError(message: "Network connection error", statusCode: nil)
}

// MARK: - Stream Categories

enum TwitchStreamCategory: String, CaseIterable {
    case justChatting = "509658"
    case grandTheftAutoV = "32982"
    case leagueOfLegends = "21779"
    case fortnite = "33214"
    case callOfDutyWarzone = "512710"
    case sports = "518203"
    case minecraft = "27471"
    case dota2 = "29595"
    case apexLegends = "511224"
    case worldOfWarcraft = "18122"
    
    var displayName: String {
        switch self {
        case .justChatting: return "Just Chatting"
        case .grandTheftAutoV: return "Grand Theft Auto V"
        case .leagueOfLegends: return "League of Legends"
        case .fortnite: return "Fortnite"
        case .callOfDutyWarzone: return "Call of Duty: Warzone"
        case .sports: return "Sports"
        case .minecraft: return "Minecraft"
        case .dota2: return "Dota 2"
        case .apexLegends: return "Apex Legends"
        case .worldOfWarcraft: return "World of Warcraft"
        }
    }
    
    var icon: String {
        switch self {
        case .justChatting: return "bubble.left.and.bubble.right"
        case .grandTheftAutoV: return "car"
        case .leagueOfLegends: return "gamecontroller"
        case .fortnite: return "gamecontroller.fill"
        case .callOfDutyWarzone: return "scope"
        case .sports: return "sportscourt"
        case .minecraft: return "cube"
        case .dota2: return "shield"
        case .apexLegends: return "target"
        case .worldOfWarcraft: return "sword"
        }
    }
}

import SwiftUI

extension Color {
    static let twitchPurple = Color(red: 0.58, green: 0.27, blue: 0.98)
}