//
//  ValidationModels.swift
//  StreamyyyApp
//
//  Enhanced data models with comprehensive validation and type safety
//  Created by Claude Code on 2025-07-10
//

import Foundation
import SwiftUI

// MARK: - Validation Framework

/// Protocol for validatable data models
public protocol Validatable {
    func validate() throws
    var isValid: Bool { get }
    var validationErrors: [ValidationError] { get }
}

/// Validation error structure
public struct ValidationError: Error, Identifiable, LocalizedError {
    public let id = UUID()
    public let field: String
    public let message: String
    public let code: ValidationErrorCode
    
    public init(field: String, message: String, code: ValidationErrorCode) {
        self.field = field
        self.message = message
        self.code = code
    }
    
    public var errorDescription: String? {
        return "\\(field): \\(message)"
    }
}

/// Validation error codes
public enum ValidationErrorCode: String, CaseIterable {
    case required = "required"
    case invalidFormat = "invalid_format"
    case outOfRange = "out_of_range"
    case tooShort = "too_short"
    case tooLong = "too_long"
    case invalidURL = "invalid_url"
    case invalidEmail = "invalid_email"
    case duplicateValue = "duplicate_value"
    case unsupportedValue = "unsupported_value"
    case inconsistentData = "inconsistent_data"
}

// MARK: - Enhanced Stream Model

/// Enhanced stream model with comprehensive validation
public struct ValidatedStream: Identifiable, Codable, Validatable {
    public let id: String
    public let url: URL
    public let platform: Platform
    public let title: String
    public let description: String?
    public let thumbnailURL: URL?
    public let streamerName: String?
    public let streamerAvatarURL: URL?
    public let category: StreamCategory?
    public let language: LanguageCode
    public let tags: Set<String>
    public let isLive: Bool
    public let viewerCount: UInt
    public let startedAt: Date?
    public let endedAt: Date?
    public let duration: TimeInterval
    public let quality: StreamQuality
    public let availableQualities: Set<StreamQuality>
    public let metadata: [String: ValidatedMetadata]
    public let createdAt: Date
    public let updatedAt: Date
    
    // MARK: - Validation
    
    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
    
    public var validationErrors: [ValidationError] {
        var errors: [ValidationError] = []
        
        // URL validation
        if !platform.isValidURL(url.absoluteString) {
            errors.append(ValidationError(
                field: "url",
                message: "URL is not valid for platform \\(platform.displayName)",
                code: .invalidFormat
            ))
        }
        
        // Title validation
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                field: "title",
                message: "Title cannot be empty",
                code: .required
            ))
        }
        
        if title.count > 200 {
            errors.append(ValidationError(
                field: "title",
                message: "Title cannot exceed 200 characters",
                code: .tooLong
            ))
        }
        
        // Description validation
        if let description = description, description.count > 1000 {
            errors.append(ValidationError(
                field: "description",
                message: "Description cannot exceed 1000 characters",
                code: .tooLong
            ))
        }
        
        // Streamer name validation
        if let streamerName = streamerName {
            if streamerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(ValidationError(
                    field: "streamerName",
                    message: "Streamer name cannot be empty",
                    code: .required
                ))
            }
            
            if streamerName.count > 50 {
                errors.append(ValidationError(
                    field: "streamerName",
                    message: "Streamer name cannot exceed 50 characters",
                    code: .tooLong
                ))
            }
        }
        
        // Viewer count validation
        if viewerCount > 10_000_000 {
            errors.append(ValidationError(
                field: "viewerCount",
                message: "Viewer count seems unrealistic",
                code: .outOfRange
            ))
        }
        
        // Date validation
        if let startedAt = startedAt, let endedAt = endedAt {
            if startedAt > endedAt {
                errors.append(ValidationError(
                    field: "startedAt",
                    message: "Start time cannot be after end time",
                    code: .inconsistentData
                ))
            }
        }
        
        if let startedAt = startedAt, startedAt > Date() {
            errors.append(ValidationError(
                field: "startedAt",
                message: "Start time cannot be in the future",
                code: .outOfRange
            ))
        }
        
        // Duration validation
        if duration < 0 {
            errors.append(ValidationError(
                field: "duration",
                message: "Duration cannot be negative",
                code: .outOfRange
            ))
        }
        
        if duration > 86400 { // 24 hours
            errors.append(ValidationError(
                field: "duration",
                message: "Duration cannot exceed 24 hours",
                code: .outOfRange
            ))
        }
        
        // Quality validation
        if !availableQualities.contains(quality) {
            errors.append(ValidationError(
                field: "quality",
                message: "Selected quality is not available",
                code: .inconsistentData
            ))
        }
        
        // Tags validation
        if tags.count > 20 {
            errors.append(ValidationError(
                field: "tags",
                message: "Cannot have more than 20 tags",
                code: .outOfRange
            ))
        }
        
        for tag in tags {
            if tag.count > 30 {
                errors.append(ValidationError(
                    field: "tags",
                    message: "Tag '\\(tag)' exceeds 30 characters",
                    code: .tooLong
                ))
            }
        }
        
        // Metadata validation
        for (key, value) in metadata {
            do {
                try value.validate()
            } catch let validationError as ValidationError {
                errors.append(ValidationError(
                    field: "metadata.\\(key)",
                    message: validationError.message,
                    code: validationError.code
                ))
            } catch {
                errors.append(ValidationError(
                    field: "metadata.\\(key)",
                    message: "Invalid metadata value",
                    code: .invalidFormat
                ))
            }
        }
        
        return errors
    }
    
    public func validate() throws {
        let errors = validationErrors
        if !errors.isEmpty {
            throw ValidationAggregateError(errors: errors)
        }
    }
}

// MARK: - Enhanced User Model

/// Enhanced user model with validation
public struct ValidatedUser: Identifiable, Codable, Validatable {
    public let id: String
    public let username: String
    public let email: EmailAddress
    public let displayName: String?
    public let avatarURL: URL?
    public let preferences: UserPreferences
    public let subscription: SubscriptionInfo?
    public let createdAt: Date
    public let lastActiveAt: Date
    public let isVerified: Bool
    public let accountStatus: AccountStatus
    
    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
    
    public var validationErrors: [ValidationError] {
        var errors: [ValidationError] = []
        
        // Username validation
        if username.count < 3 {
            errors.append(ValidationError(
                field: "username",
                message: "Username must be at least 3 characters",
                code: .tooShort
            ))
        }
        
        if username.count > 30 {
            errors.append(ValidationError(
                field: "username",
                message: "Username cannot exceed 30 characters",
                code: .tooLong
            ))
        }
        
        let usernamePattern = "^[a-zA-Z0-9_-]+$"
        if !username.range(of: usernamePattern, options: .regularExpression) != nil {
            errors.append(ValidationError(
                field: "username",
                message: "Username can only contain letters, numbers, underscores, and hyphens",
                code: .invalidFormat
            ))
        }
        
        // Email validation
        do {
            try email.validate()
        } catch let validationError as ValidationError {
            errors.append(validationError)
        } catch {
            errors.append(ValidationError(
                field: "email",
                message: "Invalid email address",
                code: .invalidEmail
            ))
        }
        
        // Display name validation
        if let displayName = displayName {
            if displayName.count > 50 {
                errors.append(ValidationError(
                    field: "displayName",
                    message: "Display name cannot exceed 50 characters",
                    code: .tooLong
                ))
            }
        }
        
        // Preferences validation
        do {
            try preferences.validate()
        } catch let validationError as ValidationError {
            errors.append(validationError)
        } catch {
            // Handle other validation errors
        }
        
        return errors
    }
    
    public func validate() throws {
        let errors = validationErrors
        if !errors.isEmpty {
            throw ValidationAggregateError(errors: errors)
        }
    }
}

// MARK: - Supporting Types

/// Language code with validation
public struct LanguageCode: Codable, Validatable {
    public let code: String
    
    public init(_ code: String) throws {
        self.code = code
        try validate()
    }
    
    public var isValid: Bool {
        return Locale.isoLanguageCodes.contains(code)
    }
    
    public var validationErrors: [ValidationError] {
        var errors: [ValidationError] = []
        
        if !Locale.isoLanguageCodes.contains(code) {
            errors.append(ValidationError(
                field: "languageCode",
                message: "Invalid ISO language code",
                code: .invalidFormat
            ))
        }
        
        return errors
    }
    
    public func validate() throws {
        let errors = validationErrors
        if !errors.isEmpty {
            throw ValidationAggregateError(errors: errors)
        }
    }
}

/// Email address with validation
public struct EmailAddress: Codable, Validatable {
    public let address: String
    
    public init(_ address: String) throws {
        self.address = address
        try validate()
    }
    
    public var isValid: Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"#
        return address.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    public var validationErrors: [ValidationError] {
        var errors: [ValidationError] = []
        
        if address.isEmpty {
            errors.append(ValidationError(
                field: "email",
                message: "Email address is required",
                code: .required
            ))
        } else if !isValid {
            errors.append(ValidationError(
                field: "email",
                message: "Invalid email address format",
                code: .invalidEmail
            ))
        }
        
        return errors
    }
    
    public func validate() throws {
        let errors = validationErrors
        if !errors.isEmpty {
            throw ValidationAggregateError(errors: errors)
        }
    }
}

/// Validated metadata value
public enum ValidatedMetadata: Codable, Validatable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case url(URL)
    case date(Date)
    
    public var isValid: Bool {
        switch self {
        case .string(let value):
            return !value.isEmpty && value.count <= 500
        case .number(let value):
            return value.isFinite
        case .boolean:
            return true
        case .url(let value):
            return value.absoluteString.count <= 2048
        case .date:
            return true
        }
    }
    
    public var validationErrors: [ValidationError] {
        var errors: [ValidationError] = []
        
        switch self {
        case .string(let value):
            if value.isEmpty {
                errors.append(ValidationError(
                    field: "metadata",
                    message: "String value cannot be empty",
                    code: .required
                ))
            }
            if value.count > 500 {
                errors.append(ValidationError(
                    field: "metadata",
                    message: "String value too long",
                    code: .tooLong
                ))
            }
        case .number(let value):
            if !value.isFinite {
                errors.append(ValidationError(
                    field: "metadata",
                    message: "Number must be finite",
                    code: .invalidFormat
                ))
            }
        case .url(let value):
            if value.absoluteString.count > 2048 {
                errors.append(ValidationError(
                    field: "metadata",
                    message: "URL too long",
                    code: .tooLong
                ))
            }
        case .boolean, .date:
            break
        }
        
        return errors
    }
    
    public func validate() throws {
        let errors = validationErrors
        if !errors.isEmpty {
            throw ValidationAggregateError(errors: errors)
        }
    }
}

/// User preferences with validation
public struct UserPreferences: Codable, Validatable {
    public let preferredLanguages: Set<LanguageCode>
    public let preferredPlatforms: Set<Platform>
    public let defaultQuality: StreamQuality
    public let autoPlay: Bool
    public let notifications: NotificationPreferences
    public let privacy: PrivacySettings
    
    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
    
    public var validationErrors: [ValidationError] {
        var errors: [ValidationError] = []
        
        // Language validation
        if preferredLanguages.isEmpty {
            errors.append(ValidationError(
                field: "preferredLanguages",
                message: "At least one preferred language is required",
                code: .required
            ))
        }
        
        if preferredLanguages.count > 10 {
            errors.append(ValidationError(
                field: "preferredLanguages",
                message: "Too many preferred languages",
                code: .outOfRange
            ))
        }
        
        // Platform validation
        if preferredPlatforms.count > Platform.allCases.count {
            errors.append(ValidationError(
                field: "preferredPlatforms",
                message: "Invalid platform selection",
                code: .invalidFormat
            ))
        }
        
        // Validate nested objects
        for language in preferredLanguages {
            do {
                try language.validate()
            } catch let validationError as ValidationError {
                errors.append(validationError)
            } catch {
                // Handle other errors
            }
        }
        
        return errors
    }
    
    public func validate() throws {
        let errors = validationErrors
        if !errors.isEmpty {
            throw ValidationAggregateError(errors: errors)
        }
    }
}

/// Notification preferences
public struct NotificationPreferences: Codable {
    public let streamStarted: Bool
    public let streamEnded: Bool
    public let newFollower: Bool
    public let mentions: Bool
    public let systemUpdates: Bool
    public let marketingEmails: Bool
}

/// Privacy settings
public struct PrivacySettings: Codable {
    public let profileVisible: Bool
    public let showWatchHistory: Bool
    public let allowDataCollection: Bool
    public let shareUsageAnalytics: Bool
}

/// Subscription information
public struct SubscriptionInfo: Codable {
    public let tier: SubscriptionTier
    public let startDate: Date
    public let endDate: Date?
    public let isActive: Bool
    public let autoRenew: Bool
    public let paymentMethod: PaymentMethod?
}

/// Subscription tiers
public enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case basic = "basic"
    case premium = "premium"
    case pro = "pro"
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .basic: return "Basic"
        case .premium: return "Premium"
        case .pro: return "Pro"
        }
    }
}

/// Payment method information
public struct PaymentMethod: Codable {
    public let type: PaymentType
    public let lastFourDigits: String?
    public let expiryDate: Date?
    public let isDefault: Bool
}

/// Payment types
public enum PaymentType: String, Codable, CaseIterable {
    case creditCard = "credit_card"
    case debitCard = "debit_card"
    case paypal = "paypal"
    case applePay = "apple_pay"
    case googlePay = "google_pay"
    
    public var displayName: String {
        switch self {
        case .creditCard: return "Credit Card"
        case .debitCard: return "Debit Card"
        case .paypal: return "PayPal"
        case .applePay: return "Apple Pay"
        case .googlePay: return "Google Pay"
        }
    }
}

/// Account status
public enum AccountStatus: String, Codable, CaseIterable {
    case active = "active"
    case suspended = "suspended"
    case banned = "banned"
    case pending = "pending"
    case deleted = "deleted"
    
    public var displayName: String {
        switch self {
        case .active: return "Active"
        case .suspended: return "Suspended"
        case .banned: return "Banned"
        case .pending: return "Pending Verification"
        case .deleted: return "Deleted"
        }
    }
    
    public var color: Color {
        switch self {
        case .active: return .green
        case .suspended: return .orange
        case .banned: return .red
        case .pending: return .yellow
        case .deleted: return .gray
        }
    }
}

// MARK: - Validation Utilities

/// Aggregate validation error for multiple validation failures
public struct ValidationAggregateError: Error, LocalizedError {
    public let errors: [ValidationError]
    
    public var errorDescription: String? {
        return "Multiple validation errors: \\(errors.map { $0.errorDescription ?? "Unknown error" }.joined(separator: ", "))"
    }
    
    public var failedFields: [String] {
        return errors.map { $0.field }
    }
    
    public var criticalErrors: [ValidationError] {
        return errors.filter {
            $0.code == .required || $0.code == .invalidFormat
        }
    }
}

/// Validation utility functions
public struct ValidationUtils {
    
    /// Validate URL format and accessibility
    public static func validateURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme else { return false }
        return ["http", "https"].contains(scheme.lowercased())
    }
    
    /// Validate string length
    public static func validateLength(_ string: String, min: Int, max: Int) -> Bool {
        let length = string.count
        return length >= min && length <= max
    }
    
    /// Validate numeric range
    public static func validateRange<T: Comparable>(_ value: T, min: T, max: T) -> Bool {
        return value >= min && value <= max
    }
    
    /// Validate date range
    public static func validateDateRange(_ date: Date, from: Date?, to: Date?) -> Bool {
        if let from = from, date < from {
            return false
        }
        if let to = to, date > to {
            return false
        }
        return true
    }
    
    /// Sanitize string input
    public static func sanitizeString(_ string: String) -> String {
        return string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\n+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    /// Validate collection size
    public static func validateCollectionSize<T: Collection>(_ collection: T, min: Int, max: Int) -> Bool {
        let count = collection.count
        return count >= min && count <= max
    }
}

// MARK: - Data Transformation

/// Protocol for transformable data models
public protocol DataTransformable {
    associatedtype TransformedType
    func transform() -> TransformedType
}

/// Stream transformation utilities
public extension ValidatedStream {
    
    /// Transform to legacy Stream model for backward compatibility
    func toLegacyStream() -> Stream {
        return Stream(
            id: id,
            url: url.absoluteString,
            platform: platform,
            title: title
        )
    }
    
    /// Create from legacy Stream model
    static func fromLegacyStream(_ stream: Stream) throws -> ValidatedStream {
        guard let url = URL(string: stream.url) else {
            throw ValidationError(field: "url", message: "Invalid URL", code: .invalidURL)
        }
        
        let languageCode = try LanguageCode(stream.language ?? "en")
        
        return ValidatedStream(
            id: stream.id,
            url: url,
            platform: stream.platform,
            title: stream.title,
            description: stream.description,
            thumbnailURL: stream.thumbnailURL.flatMap { URL(string: $0) },
            streamerName: stream.streamerName,
            streamerAvatarURL: stream.streamerAvatarURL.flatMap { URL(string: $0) },
            category: nil, // Would need to be mapped from string
            language: languageCode,
            tags: Set(stream.tags),
            isLive: stream.isLive,
            viewerCount: UInt(max(0, stream.viewerCount)),
            startedAt: stream.startedAt,
            endedAt: stream.endedAt,
            duration: stream.duration,
            quality: stream.quality,
            availableQualities: Set(stream.availableQualities),
            metadata: [:], // Would need to be converted
            createdAt: stream.createdAt,
            updatedAt: stream.updatedAt
        )
    }
}

// MARK: - JSON Schema Generation

/// Protocol for JSON schema generation
public protocol JSONSchemaGeneratable {
    static func generateJSONSchema() -> [String: Any]
}

/// Implementation for ValidatedStream
extension ValidatedStream: JSONSchemaGeneratable {
    public static func generateJSONSchema() -> [String: Any] {
        return [
            "type": "object",
            "properties": [
                "id": ["type": "string"],
                "url": ["type": "string", "format": "uri"],
                "platform": ["type": "string", "enum": Platform.allCases.map { $0.rawValue }],
                "title": ["type": "string", "minLength": 1, "maxLength": 200],
                "description": ["type": "string", "maxLength": 1000],
                "thumbnailURL": ["type": "string", "format": "uri"],
                "streamerName": ["type": "string", "maxLength": 50],
                "language": ["type": "string", "pattern": "^[a-z]{2}$"],
                "tags": ["type": "array", "items": ["type": "string"], "maxItems": 20],
                "isLive": ["type": "boolean"],
                "viewerCount": ["type": "integer", "minimum": 0, "maximum": 10000000],
                "duration": ["type": "number", "minimum": 0, "maximum": 86400]
            ],
            "required": ["id", "url", "platform", "title", "language", "isLive", "viewerCount"]
        ]
    }
}