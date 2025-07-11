//
//  User.swift
//  StreamyyyApp
//
//  Comprehensive user model with Clerk integration
//

import Foundation
import SwiftUI
import SwiftData
// import ClerkSDK // Commented out until SDK is properly integrated

// ClerkUser is defined in ClerkManager.swift

// MARK: - User Model
@Model
public class User: Identifiable, Codable, ObservableObject {
    @Attribute(.unique) public var id: String
    @Attribute(.unique) public var clerkId: String?
    @Attribute(.unique) public var email: String
    public var username: String?
    public var firstName: String?
    public var lastName: String?
    public var profileImageURL: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var lastActiveAt: Date
    public var isEmailVerified: Bool
    public var phoneNumber: String?
    public var isPhoneVerified: Bool
    public var timezone: String
    public var locale: String
    public var preferences: UserPreferences
    public var subscriptionStatus: SubscriptionStatus
    public var subscriptionId: String?
    public var stripeCustomerId: String?
    public var isActive: Bool
    public var isBanned: Bool
    public var banReason: String?
    public var banExpiresAt: Date?
    public var metadata: [String: String]
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \Stream.owner)
    public var streams: [Stream] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Favorite.user)
    public var favorites: [Favorite] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Subscription.user)
    public var subscriptions: [Subscription] = []
    
    @Relationship(deleteRule: .cascade, inverse: \UserNotification.user)
    public var notifications: [UserNotification] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Layout.owner)
    public var layouts: [Layout] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ViewingHistory.user)
    public var viewingHistory: [ViewingHistory] = []
    
    @Relationship(deleteRule: .cascade, inverse: \StreamCollection.owner)
    public var streamCollections: [StreamCollection] = []
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        clerkId: String? = nil,
        email: String,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        profileImageURL: String? = nil,
        phoneNumber: String? = nil,
        timezone: String = TimeZone.current.identifier,
        locale: String = Locale.current.identifier
    ) {
        self.id = id
        self.clerkId = clerkId
        self.email = email
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.profileImageURL = profileImageURL
        self.phoneNumber = phoneNumber
        self.timezone = timezone
        self.locale = locale
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastActiveAt = Date()
        self.isEmailVerified = false
        self.isPhoneVerified = false
        self.preferences = UserPreferences()
        self.subscriptionStatus = .free
        self.isActive = true
        self.isBanned = false
        self.metadata = [:]
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, clerkId, email, username, firstName, lastName
        case profileImageURL, createdAt, updatedAt, lastActiveAt
        case isEmailVerified, phoneNumber, isPhoneVerified
        case timezone, locale, preferences, subscriptionStatus
        case subscriptionId, stripeCustomerId, isActive, isBanned
        case banReason, banExpiresAt, metadata
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        clerkId = try container.decodeIfPresent(String.self, forKey: .clerkId)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastActiveAt = try container.decode(Date.self, forKey: .lastActiveAt)
        isEmailVerified = try container.decode(Bool.self, forKey: .isEmailVerified)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        isPhoneVerified = try container.decode(Bool.self, forKey: .isPhoneVerified)
        timezone = try container.decode(String.self, forKey: .timezone)
        locale = try container.decode(String.self, forKey: .locale)
        preferences = try container.decode(UserPreferences.self, forKey: .preferences)
        subscriptionStatus = try container.decode(SubscriptionStatus.self, forKey: .subscriptionStatus)
        subscriptionId = try container.decodeIfPresent(String.self, forKey: .subscriptionId)
        stripeCustomerId = try container.decodeIfPresent(String.self, forKey: .stripeCustomerId)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isBanned = try container.decode(Bool.self, forKey: .isBanned)
        banReason = try container.decodeIfPresent(String.self, forKey: .banReason)
        banExpiresAt = try container.decodeIfPresent(Date.self, forKey: .banExpiresAt)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(clerkId, forKey: .clerkId)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(lastActiveAt, forKey: .lastActiveAt)
        try container.encode(isEmailVerified, forKey: .isEmailVerified)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encode(isPhoneVerified, forKey: .isPhoneVerified)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(locale, forKey: .locale)
        try container.encode(preferences, forKey: .preferences)
        try container.encode(subscriptionStatus, forKey: .subscriptionStatus)
        try container.encodeIfPresent(subscriptionId, forKey: .subscriptionId)
        try container.encodeIfPresent(stripeCustomerId, forKey: .stripeCustomerId)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isBanned, forKey: .isBanned)
        try container.encodeIfPresent(banReason, forKey: .banReason)
        try container.encodeIfPresent(banExpiresAt, forKey: .banExpiresAt)
        try container.encode(metadata, forKey: .metadata)
    }
}

// MARK: - User Extensions
extension User {
    
    // MARK: - Computed Properties
    public var displayName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let username = username {
            return username
        } else {
            return email.components(separatedBy: "@").first ?? "User"
        }
    }
    
    public var initials: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName.prefix(1))\(lastName.prefix(1))".uppercased()
        } else if let firstName = firstName {
            return String(firstName.prefix(1)).uppercased()
        } else if let username = username {
            return String(username.prefix(1)).uppercased()
        } else {
            return String(email.prefix(1)).uppercased()
        }
    }
    
    public var isPremium: Bool {
        return subscriptionStatus == .premium || subscriptionStatus == .pro
    }
    
    public var isProUser: Bool {
        return subscriptionStatus == .pro
    }
    
    public var isFreeUser: Bool {
        return subscriptionStatus == .free
    }
    
    public var maxStreams: Int {
        switch subscriptionStatus {
        case .free:
            return Config.App.maxStreamsForFreeUsers
        case .premium, .pro:
            return Config.App.maxStreamsForProUsers
        }
    }
    
    public var canAddMoreStreams: Bool {
        return streams.count < maxStreams
    }
    
    public var isValidated: Bool {
        return isEmailVerified && isActive && !isBanned
    }
    
    public var accountAge: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
    
    public var lastSeenFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastActiveAt, relativeTo: Date())
    }
    
    // MARK: - Validation Methods
    public func validateEmail() -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    public func validateUsername() -> Bool {
        guard let username = username else { return false }
        let usernameRegex = "^[A-Za-z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    public func validatePhoneNumber() -> Bool {
        guard let phoneNumber = phoneNumber else { return false }
        let phoneRegex = "^\\+?[1-9]\\d{1,14}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phoneNumber)
    }
    
    // MARK: - Update Methods
    public func updateLastActive() {
        lastActiveAt = Date()
        updatedAt = Date()
    }
    
    public func updateFromClerk(_ clerkUser: ClerkUser) {
        clerkId = clerkUser.id
        email = clerkUser.primaryEmailAddress?.emailAddress ?? email
        firstName = clerkUser.firstName
        lastName = clerkUser.lastName
        if let imageURL = clerkUser.imageURL {
            profileImageURL = imageURL.absoluteString
        }
        isEmailVerified = clerkUser.isEmailVerified
        phoneNumber = clerkUser.primaryPhoneNumber?.phoneNumber
        isPhoneVerified = clerkUser.isPhoneVerified
        updatedAt = Date()
    }
    
    public func updatePreferences(_ newPreferences: UserPreferences) {
        preferences = newPreferences
        updatedAt = Date()
    }
    
    public func updateSubscriptionStatus(_ status: SubscriptionStatus) {
        subscriptionStatus = status
        updatedAt = Date()
    }
    
    // MARK: - Ban Methods
    public func ban(reason: String, until: Date? = nil) {
        isBanned = true
        banReason = reason
        banExpiresAt = until
        updatedAt = Date()
    }
    
    public func unban() {
        isBanned = false
        banReason = nil
        banExpiresAt = nil
        updatedAt = Date()
    }
    
    public func checkBanExpiration() {
        if let banExpiresAt = banExpiresAt, banExpiresAt <= Date() {
            unban()
        }
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
}

// MARK: - User Preferences
public struct UserPreferences: Codable {
    public var theme: AppTheme
    public var autoPlayStreams: Bool
    public var enableNotifications: Bool
    public var enableAnalytics: Bool
    public var defaultQuality: StreamQuality
    public var enablePictureInPicture: Bool
    public var enableHapticFeedback: Bool
    public var enableSoundEffects: Bool
    public var chatSettings: ChatSettings
    public var privacySettings: PrivacySettings
    public var layoutSettings: LayoutSettings
    
    public init() {
        self.theme = .system
        self.autoPlayStreams = true
        self.enableNotifications = true
        self.enableAnalytics = true
        self.defaultQuality = .high
        self.enablePictureInPicture = true
        self.enableHapticFeedback = true
        self.enableSoundEffects = true
        self.chatSettings = ChatSettings()
        self.privacySettings = PrivacySettings()
        self.layoutSettings = LayoutSettings()
    }
}

// MARK: - Supporting Enums and Structs
public enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

public enum SubscriptionStatus: String, Codable, CaseIterable {
    case free = "free"
    case premium = "premium"
    case pro = "pro"
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .pro: return "Pro"
        }
    }
    
    public var color: Color {
        switch self {
        case .free: return .gray
        case .premium: return .blue
        case .pro: return .purple
        }
    }
}

public struct ChatSettings: Codable {
    public var enableChat: Bool
    public var enableEmotes: Bool
    public var enableMentions: Bool
    public var fontSize: ChatFontSize
    public var autoHideDelay: TimeInterval
    public var enableProfanityFilter: Bool
    public var enableSpamProtection: Bool
    
    public init() {
        self.enableChat = true
        self.enableEmotes = true
        self.enableMentions = true
        self.fontSize = .medium
        self.autoHideDelay = 5.0
        self.enableProfanityFilter = true
        self.enableSpamProtection = true
    }
}

public enum ChatFontSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    public var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        }
    }
}

public struct PrivacySettings: Codable {
    public var allowAnalytics: Bool
    public var allowCrashReporting: Bool
    public var allowPersonalizedAds: Bool
    public var shareUsageData: Bool
    public var allowLocationAccess: Bool
    
    public init() {
        self.allowAnalytics = true
        self.allowCrashReporting = true
        self.allowPersonalizedAds = false
        self.shareUsageData = true
        self.allowLocationAccess = false
    }
}

public struct LayoutSettings: Codable {
    public var defaultLayout: String
    public var enableGridLines: Bool
    public var enableLabels: Bool
    public var compactMode: Bool
    public var animationsEnabled: Bool
    
    public init() {
        self.defaultLayout = "grid2x2"
        self.enableGridLines = true
        self.enableLabels = true
        self.compactMode = false
        self.animationsEnabled = true
    }
}

// MARK: - User Errors
public enum UserError: Error, LocalizedError {
    case invalidEmail
    case invalidUsername
    case invalidPhoneNumber
    case userBanned(reason: String)
    case subscriptionRequired
    case streamLimitReached
    case accountNotVerified
    case clerkIntegrationFailed
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Invalid email address"
        case .invalidUsername:
            return "Invalid username"
        case .invalidPhoneNumber:
            return "Invalid phone number"
        case .userBanned(let reason):
            return "Account banned: \(reason)"
        case .subscriptionRequired:
            return "Premium subscription required"
        case .streamLimitReached:
            return "Stream limit reached"
        case .accountNotVerified:
            return "Account not verified"
        case .clerkIntegrationFailed:
            return "Authentication failed"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}