//
//  StreamValidationService.swift
//  StreamyyyApp
//
//  URL validation and stream detection service with metadata extraction
//

import Foundation
import SwiftUI
import Combine
import Network

// MARK: - Stream Validation Service
@MainActor
public class StreamValidationService: ObservableObject {
    
    // MARK: - Properties
    public static let shared = StreamValidationService()
    
    @Published public var isValidating: Bool = false
    @Published public var validationProgress: Double = 0.0
    @Published public var lastValidationResult: ValidationResult?
    
    // Network session for validation
    private let urlSession: URLSession
    
    // API clients for different platforms
    private let twitchClient: TwitchAPIClient
    private let youtubeClient: YouTubeAPIClient
    private let kickClient: KickAPIClient
    
    // Validation configuration
    private let validationTimeout: TimeInterval = 10.0
    private let maxRedirects: Int = 5
    
    // Cache for validation results
    private var validationCache: [String: ValidationResult] = [:]
    private let cacheExpiry: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    public init() {
        // Configure URL session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = validationTimeout
        configuration.timeoutIntervalForResource = validationTimeout
        configuration.httpMaximumConnectionsPerHost = 5
        
        self.urlSession = URLSession(configuration: configuration)
        
        // Initialize API clients
        self.twitchClient = TwitchAPIClient()
        self.youtubeClient = YouTubeAPIClient()
        self.kickClient = KickAPIClient()
    }
    
    // MARK: - Main Validation Method
    public func validateAndExtractMetadata(url: String) async throws -> ValidationResult {
        isValidating = true
        validationProgress = 0.0
        defer { 
            isValidating = false 
            validationProgress = 1.0
        }
        
        // Check cache first
        if let cachedResult = getCachedValidation(url: url) {
            lastValidationResult = cachedResult
            return cachedResult
        }
        
        do {
            // Step 1: Basic URL validation
            validationProgress = 0.1
            try validateBasicURL(url)
            
            // Step 2: Platform detection
            validationProgress = 0.2
            let platform = detectPlatform(from: url)
            
            // Step 3: URL normalization
            validationProgress = 0.3
            let normalizedURL = try normalizeURL(url, platform: platform)
            
            // Step 4: Accessibility check
            validationProgress = 0.4
            try await checkURLAccessibility(normalizedURL)
            
            // Step 5: Extract metadata
            validationProgress = 0.5
            let metadata = try await extractMetadata(url: normalizedURL, platform: platform)
            
            // Step 6: Validate stream availability
            validationProgress = 0.7
            let availability = try await checkStreamAvailability(url: normalizedURL, platform: platform)
            
            // Step 7: Create validation result
            validationProgress = 0.9
            let result = ValidationResult(
                originalURL: url,
                url: normalizedURL,
                platform: platform,
                isValid: true,
                isAccessible: true,
                isLive: availability.isLive,
                title: metadata.title,
                description: metadata.description,
                thumbnailURL: metadata.thumbnailURL,
                streamerName: metadata.streamerName,
                streamerAvatarURL: metadata.streamerAvatarURL,
                category: metadata.category,
                tags: metadata.tags,
                viewerCount: availability.viewerCount,
                validationDate: Date(),
                error: nil
            )
            
            // Cache the result
            cacheValidationResult(url: url, result: result)
            
            lastValidationResult = result
            return result
            
        } catch {
            let errorResult = ValidationResult(
                originalURL: url,
                url: url,
                platform: .other,
                isValid: false,
                isAccessible: false,
                isLive: false,
                title: "Invalid Stream",
                description: nil,
                thumbnailURL: nil,
                streamerName: nil,
                streamerAvatarURL: nil,
                category: nil,
                tags: [],
                viewerCount: 0,
                validationDate: Date(),
                error: error as? ValidationError ?? .unknown(error)
            )
            
            lastValidationResult = errorResult
            throw error
        }
    }
    
    // MARK: - Basic URL Validation
    private func validateBasicURL(_ url: String) throws {
        // Check if URL is empty
        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyURL
        }
        
        // Check if URL is valid
        guard URL(string: url) != nil else {
            throw ValidationError.invalidURL
        }
        
        // Check if URL has valid scheme
        guard let urlObj = URL(string: url), 
              let scheme = urlObj.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            throw ValidationError.invalidScheme
        }
        
        // Check if URL has valid host
        guard urlObj.host != nil else {
            throw ValidationError.invalidHost
        }
    }
    
    // MARK: - Platform Detection
    private func detectPlatform(from url: String) -> Platform {
        return Platform.detect(from: url)
    }
    
    // MARK: - URL Normalization
    private func normalizeURL(_ url: String, platform: Platform) throws -> String {
        guard let urlObj = URL(string: url) else {
            throw ValidationError.invalidURL
        }
        
        var components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false)
        
        switch platform {
        case .twitch:
            return normalizeTwitchURL(components: components)
        case .youtube:
            return normalizeYouTubeURL(components: components)
        case .kick:
            return normalizeKickURL(components: components)
        default:
            return url
        }
    }
    
    private func normalizeTwitchURL(components: URLComponents?) -> String {
        guard let components = components else { return "" }
        
        // Ensure proper scheme and host
        var normalizedComponents = components
        normalizedComponents.scheme = "https"
        normalizedComponents.host = "www.twitch.tv"
        
        // Remove unnecessary query parameters
        if let queryItems = normalizedComponents.queryItems {
            normalizedComponents.queryItems = queryItems.filter { item in
                !["t", "tt", "sr", "referrer"].contains(item.name)
            }
        }
        
        return normalizedComponents.url?.absoluteString ?? ""
    }
    
    private func normalizeYouTubeURL(components: URLComponents?) -> String {
        guard let components = components else { return "" }
        
        var normalizedComponents = components
        normalizedComponents.scheme = "https"
        
        // Handle different YouTube URL formats
        if components.host?.contains("youtu.be") == true {
            // Convert youtu.be to youtube.com
            normalizedComponents.host = "www.youtube.com"
            if let videoId = components.path.components(separatedBy: "/").last {
                normalizedComponents.path = "/watch"
                normalizedComponents.queryItems = [URLQueryItem(name: "v", value: videoId)]
            }
        } else {
            normalizedComponents.host = "www.youtube.com"
        }
        
        return normalizedComponents.url?.absoluteString ?? ""
    }
    
    private func normalizeKickURL(components: URLComponents?) -> String {
        guard let components = components else { return "" }
        
        var normalizedComponents = components
        normalizedComponents.scheme = "https"
        normalizedComponents.host = "kick.com"
        
        return normalizedComponents.url?.absoluteString ?? ""
    }
    
    // MARK: - URL Accessibility Check
    private func checkURLAccessibility(_ url: String) async throws {
        guard let urlObj = URL(string: url) else {
            throw ValidationError.invalidURL
        }
        
        var request = URLRequest(url: urlObj)
        request.httpMethod = "HEAD"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ValidationError.invalidResponse
            }
            
            // Check if response indicates success or acceptable redirect
            guard httpResponse.statusCode < 400 else {
                throw ValidationError.httpError(httpResponse.statusCode)
            }
            
        } catch {
            if let validationError = error as? ValidationError {
                throw validationError
            }
            throw ValidationError.networkError(error)
        }
    }
    
    // MARK: - Metadata Extraction
    private func extractMetadata(url: String, platform: Platform) async throws -> StreamMetadata {
        switch platform {
        case .twitch:
            return try await extractTwitchMetadata(url: url)
        case .youtube:
            return try await extractYouTubeMetadata(url: url)
        case .kick:
            return try await extractKickMetadata(url: url)
        default:
            return try await extractGenericMetadata(url: url)
        }
    }
    
    private func extractTwitchMetadata(url: String) async throws -> StreamMetadata {
        guard let channelName = extractTwitchChannelName(from: url) else {
            throw ValidationError.invalidStreamIdentifier
        }
        
        return try await twitchClient.getChannelMetadata(channelName: channelName)
    }
    
    private func extractYouTubeMetadata(url: String) async throws -> StreamMetadata {
        guard let videoId = extractYouTubeVideoId(from: url) else {
            throw ValidationError.invalidStreamIdentifier
        }
        
        return try await youtubeClient.getVideoMetadata(videoId: videoId)
    }
    
    private func extractKickMetadata(url: String) async throws -> StreamMetadata {
        guard let channelName = extractKickChannelName(from: url) else {
            throw ValidationError.invalidStreamIdentifier
        }
        
        return try await kickClient.getChannelMetadata(channelName: channelName)
    }
    
    private func extractGenericMetadata(url: String) async throws -> StreamMetadata {
        // For generic URLs, try to extract metadata from HTML
        guard let urlObj = URL(string: url) else {
            throw ValidationError.invalidURL
        }
        
        do {
            let (data, _) = try await urlSession.data(from: urlObj)
            let html = String(data: data, encoding: .utf8) ?? ""
            
            return parseHTMLMetadata(html: html, url: url)
        } catch {
            throw ValidationError.metadataExtractionFailed(error)
        }
    }
    
    // MARK: - Stream Availability Check
    private func checkStreamAvailability(url: String, platform: Platform) async throws -> StreamAvailability {
        switch platform {
        case .twitch:
            return try await checkTwitchAvailability(url: url)
        case .youtube:
            return try await checkYouTubeAvailability(url: url)
        case .kick:
            return try await checkKickAvailability(url: url)
        default:
            return StreamAvailability(isLive: false, viewerCount: 0)
        }
    }
    
    private func checkTwitchAvailability(url: String) async throws -> StreamAvailability {
        guard let channelName = extractTwitchChannelName(from: url) else {
            throw ValidationError.invalidStreamIdentifier
        }
        
        return try await twitchClient.getStreamAvailability(channelName: channelName)
    }
    
    private func checkYouTubeAvailability(url: String) async throws -> StreamAvailability {
        guard let videoId = extractYouTubeVideoId(from: url) else {
            throw ValidationError.invalidStreamIdentifier
        }
        
        return try await youtubeClient.getVideoAvailability(videoId: videoId)
    }
    
    private func checkKickAvailability(url: String) async throws -> StreamAvailability {
        guard let channelName = extractKickChannelName(from: url) else {
            throw ValidationError.invalidStreamIdentifier
        }
        
        return try await kickClient.getChannelAvailability(channelName: channelName)
    }
    
    // MARK: - URL Parsing Helpers
    private func extractTwitchChannelName(from url: String) -> String? {
        guard let urlObj = URL(string: url) else { return nil }
        let pathComponents = urlObj.pathComponents
        return pathComponents.count > 1 ? pathComponents[1] : nil
    }
    
    private func extractYouTubeVideoId(from url: String) -> String? {
        guard let urlObj = URL(string: url) else { return nil }
        
        if urlObj.absoluteString.contains("watch?v=") {
            return urlObj.query?.components(separatedBy: "&")
                .first(where: { $0.hasPrefix("v=") })?
                .replacingOccurrences(of: "v=", with: "")
        }
        
        if urlObj.host?.contains("youtu.be") == true {
            return urlObj.pathComponents.last
        }
        
        return nil
    }
    
    private func extractKickChannelName(from url: String) -> String? {
        guard let urlObj = URL(string: url) else { return nil }
        return urlObj.pathComponents.last
    }
    
    // MARK: - HTML Parsing
    private func parseHTMLMetadata(html: String, url: String) -> StreamMetadata {
        var title = "Unknown Stream"
        var description: String? = nil
        var thumbnailURL: String? = nil
        
        // Extract title
        if let titleMatch = html.range(of: "<title>(.*?)</title>", options: .regularExpression) {
            title = String(html[titleMatch]).replacingOccurrences(of: "<title>", with: "").replacingOccurrences(of: "</title>", with: "")
        }
        
        // Extract description from meta tags
        if let descMatch = html.range(of: "<meta name=\"description\" content=\"(.*?)\"", options: .regularExpression) {
            description = String(html[descMatch]).components(separatedBy: "content=\"")[1].components(separatedBy: "\"")[0]
        }
        
        // Extract thumbnail from og:image
        if let imageMatch = html.range(of: "<meta property=\"og:image\" content=\"(.*?)\"", options: .regularExpression) {
            thumbnailURL = String(html[imageMatch]).components(separatedBy: "content=\"")[1].components(separatedBy: "\"")[0]
        }
        
        return StreamMetadata(
            title: title,
            description: description,
            thumbnailURL: thumbnailURL,
            streamerName: nil,
            streamerAvatarURL: nil,
            category: nil,
            tags: [],
            viewerCount: 0,
            isLive: false
        )
    }
    
    // MARK: - Validation Cache
    private func getCachedValidation(url: String) -> ValidationResult? {
        guard let cachedResult = validationCache[url] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cachedResult.validationDate) < cacheExpiry {
            return cachedResult
        }
        
        // Remove expired cache
        validationCache.removeValue(forKey: url)
        return nil
    }
    
    private func cacheValidationResult(url: String, result: ValidationResult) {
        validationCache[url] = result
        
        // Limit cache size
        if validationCache.count > 100 {
            // Remove oldest entries
            let sortedEntries = validationCache.sorted { $0.value.validationDate < $1.value.validationDate }
            let entriesToRemove = sortedEntries.prefix(20)
            
            for (key, _) in entriesToRemove {
                validationCache.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Batch Validation
    public func validateMultipleURLs(_ urls: [String]) async throws -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        for (index, url) in urls.enumerated() {
            do {
                let result = try await validateAndExtractMetadata(url: url)
                results.append(result)
            } catch {
                let errorResult = ValidationResult(
                    originalURL: url,
                    url: url,
                    platform: .other,
                    isValid: false,
                    isAccessible: false,
                    isLive: false,
                    title: "Invalid Stream",
                    description: nil,
                    thumbnailURL: nil,
                    streamerName: nil,
                    streamerAvatarURL: nil,
                    category: nil,
                    tags: [],
                    viewerCount: 0,
                    validationDate: Date(),
                    error: error as? ValidationError ?? .unknown(error)
                )
                results.append(errorResult)
            }
            
            validationProgress = Double(index + 1) / Double(urls.count)
        }
        
        return results
    }
    
    // MARK: - URL Suggestions
    public func suggestURLCorrections(for url: String) -> [String] {
        var suggestions: [String] = []
        
        // Common typos and corrections
        let corrections = [
            "twitch.tv": "www.twitch.tv",
            "youtube.com": "www.youtube.com",
            "kick.com": "kick.com"
        ]
        
        for (typo, correction) in corrections {
            if url.contains(typo) && !url.contains(correction) {
                suggestions.append(url.replacingOccurrences(of: typo, with: correction))
            }
        }
        
        // Add https if missing
        if !url.hasPrefix("http") {
            suggestions.append("https://\(url)")
        }
        
        return suggestions
    }
    
    // MARK: - Clear Cache
    public func clearValidationCache() {
        validationCache.removeAll()
    }
}

// MARK: - Validation Result
public struct ValidationResult {
    public let originalURL: String
    public let url: String
    public let platform: Platform
    public let isValid: Bool
    public let isAccessible: Bool
    public let isLive: Bool
    public let title: String
    public let description: String?
    public let thumbnailURL: String?
    public let streamerName: String?
    public let streamerAvatarURL: String?
    public let category: String?
    public let tags: [String]
    public let viewerCount: Int
    public let validationDate: Date
    public let error: ValidationError?
}

// MARK: - Stream Metadata
public struct StreamMetadata {
    public let title: String
    public let description: String?
    public let thumbnailURL: String?
    public let streamerName: String?
    public let streamerAvatarURL: String?
    public let category: String?
    public let tags: [String]
    public let viewerCount: Int
    public let isLive: Bool
}

// MARK: - Stream Availability
public struct StreamAvailability {
    public let isLive: Bool
    public let viewerCount: Int
}

// MARK: - Validation Errors
public enum ValidationError: Error, LocalizedError {
    case emptyURL
    case invalidURL
    case invalidScheme
    case invalidHost
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    case invalidStreamIdentifier
    case metadataExtractionFailed(Error)
    case platformNotSupported
    case streamNotFound
    case streamPrivate
    case streamOffline
    case rateLimitExceeded
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .emptyURL:
            return "URL cannot be empty"
        case .invalidURL:
            return "Invalid URL format"
        case .invalidScheme:
            return "URL must use http or https"
        case .invalidHost:
            return "Invalid host in URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidStreamIdentifier:
            return "Could not extract stream identifier"
        case .metadataExtractionFailed(let error):
            return "Failed to extract metadata: \(error.localizedDescription)"
        case .platformNotSupported:
            return "Platform not supported"
        case .streamNotFound:
            return "Stream not found"
        case .streamPrivate:
            return "Stream is private"
        case .streamOffline:
            return "Stream is offline"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .emptyURL:
            return "Please enter a valid stream URL"
        case .invalidURL:
            return "Please check the URL format and try again"
        case .invalidScheme:
            return "Please use a URL starting with http:// or https://"
        case .invalidHost:
            return "Please check the domain name in the URL"
        case .httpError(let code):
            return code == 404 ? "Stream not found" : "Please try again later"
        case .networkError:
            return "Please check your internet connection"
        case .streamNotFound:
            return "Please verify the stream URL"
        case .streamPrivate:
            return "This stream is private and cannot be accessed"
        case .streamOffline:
            return "This stream is currently offline"
        case .rateLimitExceeded:
            return "Please wait a moment and try again"
        default:
            return "Please try again or contact support"
        }
    }
}

// MARK: - API Clients (Placeholder implementations)
private class TwitchAPIClient {
    func getChannelMetadata(channelName: String) async throws -> StreamMetadata {
        // Placeholder implementation
        return StreamMetadata(
            title: "Twitch Stream - \(channelName)",
            description: nil,
            thumbnailURL: nil,
            streamerName: channelName,
            streamerAvatarURL: nil,
            category: nil,
            tags: [],
            viewerCount: 0,
            isLive: false
        )
    }
    
    func getStreamAvailability(channelName: String) async throws -> StreamAvailability {
        // Placeholder implementation
        return StreamAvailability(isLive: false, viewerCount: 0)
    }
}

private class YouTubeAPIClient {
    func getVideoMetadata(videoId: String) async throws -> StreamMetadata {
        // Placeholder implementation
        return StreamMetadata(
            title: "YouTube Video - \(videoId)",
            description: nil,
            thumbnailURL: nil,
            streamerName: nil,
            streamerAvatarURL: nil,
            category: nil,
            tags: [],
            viewerCount: 0,
            isLive: false
        )
    }
    
    func getVideoAvailability(videoId: String) async throws -> StreamAvailability {
        // Placeholder implementation
        return StreamAvailability(isLive: false, viewerCount: 0)
    }
}

private class KickAPIClient {
    func getChannelMetadata(channelName: String) async throws -> StreamMetadata {
        // Placeholder implementation
        return StreamMetadata(
            title: "Kick Stream - \(channelName)",
            description: nil,
            thumbnailURL: nil,
            streamerName: channelName,
            streamerAvatarURL: nil,
            category: nil,
            tags: [],
            viewerCount: 0,
            isLive: false
        )
    }
    
    func getChannelAvailability(channelName: String) async throws -> StreamAvailability {
        // Placeholder implementation
        return StreamAvailability(isLive: false, viewerCount: 0)
    }
}

// MARK: - Enhanced Validation Methods for Stream Model

extension StreamValidationService {
    
    /// Enhanced validation method that works with the Stream model
    public func validateStream(_ stream: Stream) async -> StreamValidationResult {
        let startTime = Date()
        totalValidations += 1
        
        // Check cache first
        if cacheEnabled,
           let cachedResult = getCachedResult(for: stream.id),
           !cachedResult.isExpired {
            cacheHits += 1
            return cachedResult.result
        }
        
        let request = ValidationRequest(
            streamId: stream.id,
            platform: stream.platform,
            url: stream.url,
            timestamp: Date()
        )
        
        validationQueue.append(request)
        isValidating = true
        
        do {
            let result = try await performStreamValidation(stream)
            
            // Cache the result
            if cacheEnabled {
                cacheStreamValidationResult(result, for: stream.id)
            }
            
            // Add to recent validations
            addToRecentValidations(result)
            
            // Update statistics
            if result.isValid {
                successfulValidations += 1
            } else {
                failedValidations += 1
            }
            
            validationTime = Date().timeIntervalSince(startTime)
            
            // Remove from queue
            validationQueue.removeAll { $0.id == request.id }
            
            if validationQueue.isEmpty {
                isValidating = false
            }
            
            return result
            
        } catch {
            failedValidations += 1
            validationTime = Date().timeIntervalSince(startTime)
            
            // Remove from queue
            validationQueue.removeAll { $0.id == request.id }
            
            if validationQueue.isEmpty {
                isValidating = false
            }
            
            return StreamValidationResult(
                streamId: stream.id,
                isValid: false,
                errors: [error.localizedDescription],
                warnings: [],
                platform: stream.platform,
                timestamp: Date(),
                validationDetails: ValidationDetails(error: error)
            )
        }
    }
    
    /// Quick validation without network calls
    public func quickValidateStream(_ stream: Stream) -> QuickValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // URL validation
        if stream.url.isEmpty {
            errors.append("Stream URL is empty")
        } else if !isValidURL(stream.url) {
            errors.append("Invalid URL format")
        }
        
        // Platform validation
        if !stream.platform.isValidURL(stream.url) {
            errors.append("URL doesn't match platform \(stream.platform.displayName)")
        }
        
        // Title validation
        if stream.title.isEmpty {
            warnings.append("Stream title is empty")
        }
        
        // Platform-specific quick validation
        let platformResult = getValidator(for: stream.platform).quickValidate(stream)
        errors.append(contentsOf: platformResult.errors)
        warnings.append(contentsOf: platformResult.warnings)
        
        return QuickValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            canProceed: errors.count <= 1,
            confidence: calculateConfidence(errors: errors, warnings: warnings)
        )
    }
    
    /// Validate multiple streams concurrently
    public func validateMultipleStreams(_ streams: [Stream]) async -> [StreamValidationResult] {
        return await withTaskGroup(of: StreamValidationResult.self) { group in
            var results: [StreamValidationResult] = []
            
            for stream in streams {
                group.addTask {
                    await self.validateStream(stream)
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.timestamp < $1.timestamp }
        }
    }
    
    // MARK: - Private Enhanced Methods
    
    private func performStreamValidation(_ stream: Stream) async throws -> StreamValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        var details = ValidationDetails()
        
        // Basic URL validation
        do {
            try validateBasicURL(stream.url)
        } catch let error as ValidationError {
            errors.append(error.localizedDescription)
        }
        
        // Platform-specific validation
        let validator = getValidator(for: stream.platform)
        let platformResult = await validator.validateStream(stream)
        
        return platformResult
    }
    
    private func getValidator(for platform: Platform) -> StreamValidator {
        switch platform {
        case .twitch:
            return TwitchStreamValidator()
        case .youtube:
            return YouTubeStreamValidator()
        case .kick:
            return KickStreamValidator()
        case .rumble:
            return RumbleStreamValidator()
        default:
            return GenericStreamValidator()
        }
    }
    
    private func getCachedResult(for streamId: String) -> CachedValidationResult? {
        return validationCache[streamId]
    }
    
    private func cacheStreamValidationResult(_ result: StreamValidationResult, for streamId: String) {
        let cachedResult = CachedValidationResult(
            result: result,
            cachedAt: Date(),
            expiresAt: Date().addingTimeInterval(cacheExpiration)
        )
        validationCache[streamId] = cachedResult
    }
    
    private func addToRecentValidations(_ result: StreamValidationResult) {
        recentValidations.insert(result, at: 0)
        
        // Keep only recent 20 validations
        if recentValidations.count > 20 {
            recentValidations = Array(recentValidations.prefix(20))
        }
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    private func calculateConfidence(errors: [String], warnings: [String]) -> Double {
        let errorWeight = 0.5
        let warningWeight = 0.1
        let maxPenalty = 1.0
        
        let penalty = Double(errors.count) * errorWeight + Double(warnings.count) * warningWeight
        return max(0.0, 1.0 - min(penalty, maxPenalty))
    }
    
    private func cleanupCache() async {
        let now = Date()
        validationCache = validationCache.filter { _, cachedResult in
            now < cachedResult.expiresAt
        }
        
        // Keep recent validations list manageable
        if recentValidations.count > 50 {
            recentValidations = Array(recentValidations.suffix(50))
        }
    }
    
    // MARK: - Statistics and Analytics
    
    public var validationSuccessRate: Double {
        guard totalValidations > 0 else { return 0.0 }
        return Double(successfulValidations) / Double(totalValidations)
    }
    
    public var cacheHitRate: Double {
        guard totalValidations > 0 else { return 0.0 }
        return Double(cacheHits) / Double(totalValidations)
    }
    
    public var averageValidationTime: TimeInterval {
        guard totalValidations > 0 else { return 0.0 }
        return validationTime / Double(totalValidations)
    }
    
    public func getValidationHistory(for streamId: String) -> [StreamValidationResult] {
        return recentValidations.filter { $0.streamId == streamId }
    }
    
    public func getValidationStatistics() -> ValidationStatistics {
        return ValidationStatistics(
            totalValidations: totalValidations,
            successfulValidations: successfulValidations,
            failedValidations: failedValidations,
            successRate: validationSuccessRate,
            cacheHits: cacheHits,
            cacheHitRate: cacheHitRate,
            averageValidationTime: averageValidationTime,
            queueLength: validationQueue.count,
            cacheSize: validationCache.count
        )
    }
}

// MARK: - Enhanced Supporting Types

public struct StreamValidationResult {
    public let streamId: String
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let platform: Platform
    public let timestamp: Date
    public let validationDetails: ValidationDetails
}

public struct URLValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let platform: Platform
    public let extractedData: [String: String]
}

public struct QuickValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let canProceed: Bool
    public let confidence: Double
}

public struct ValidationDetails {
    public var extractedData: [String: String] = [:]
    public var platformData: Any?
    public var liveStatus: Bool?
    public var viewerCount: Int?
    public var networkError: Error?
    public var responseTime: TimeInterval?
    
    public init(error: Error? = nil) {
        self.networkError = error
    }
}

public struct ValidationRequest: Identifiable {
    public let id = UUID()
    public let streamId: String
    public let platform: Platform
    public let url: String
    public let timestamp: Date
}

public struct CachedValidationResult {
    public let result: StreamValidationResult
    public let cachedAt: Date
    public let expiresAt: Date
    
    public var isExpired: Bool {
        Date() > expiresAt
    }
}

public struct ValidationStatistics {
    public let totalValidations: Int
    public let successfulValidations: Int
    public let failedValidations: Int
    public let successRate: Double
    public let cacheHits: Int
    public let cacheHitRate: Double
    public let averageValidationTime: TimeInterval
    public let queueLength: Int
    public let cacheSize: Int
}

public enum NetworkReachability {
    case unknown
    case connected
    case disconnected
}

// MARK: - Stream Validator Protocol
public protocol StreamValidator {
    func validateStream(_ stream: Stream) async -> StreamValidationResult
    func validateURL(_ url: String) async -> URLValidationResult
    func quickValidate(_ stream: Stream) -> QuickValidationResult
}

// MARK: - Platform-Specific Validators

public class TwitchStreamValidator: StreamValidator {
    public func validateStream(_ stream: Stream) async -> StreamValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        var details = ValidationDetails()
        
        // URL format validation
        if !stream.url.contains("twitch.tv") {
            errors.append("Invalid Twitch URL format")
        }
        
        // Extract channel name
        guard let channelName = extractTwitchChannelName(from: stream.url) else {
            errors.append("Cannot extract channel name from URL")
            return createResult(stream: stream, errors: errors, warnings: warnings, details: details)
        }
        
        details.extractedData["channelName"] = channelName
        
        return createResult(stream: stream, errors: errors, warnings: warnings, details: details)
    }
    
    public func validateURL(_ url: String) async -> URLValidationResult {
        let isValid = url.contains("twitch.tv") && extractTwitchChannelName(from: url) != nil
        let errors = isValid ? [] : ["Invalid Twitch URL format"]
        
        return URLValidationResult(
            isValid: isValid,
            errors: errors,
            warnings: [],
            platform: .twitch,
            extractedData: extractTwitchChannelName(from: url).map { ["channelName": $0] } ?? [:]
        )
    }
    
    public func quickValidate(_ stream: Stream) -> QuickValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        if !stream.url.contains("twitch.tv") {
            errors.append("Not a Twitch URL")
        }
        
        if extractTwitchChannelName(from: stream.url) == nil {
            errors.append("Invalid Twitch channel URL")
        }
        
        return QuickValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            canProceed: errors.count <= 1,
            confidence: errors.isEmpty ? 0.9 : 0.3
        )
    }
    
    private func extractTwitchChannelName(from url: String) -> String? {
        let patterns = [
            #"twitch\.tv/([a-zA-Z0-9_]+)"#,
            #"www\.twitch\.tv/([a-zA-Z0-9_]+)"#,
            #"player\.twitch\.tv/\?channel=([a-zA-Z0-9_]+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.count)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        
        return nil
    }
    
    private func createResult(stream: Stream, errors: [String], warnings: [String], details: ValidationDetails) -> StreamValidationResult {
        return StreamValidationResult(
            streamId: stream.id,
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            platform: stream.platform,
            timestamp: Date(),
            validationDetails: details
        )
    }
}

public class YouTubeStreamValidator: StreamValidator {
    public func validateStream(_ stream: Stream) async -> StreamValidationResult {
        return StreamValidationResult(
            streamId: stream.id,
            isValid: stream.url.contains("youtube.com") || stream.url.contains("youtu.be"),
            errors: stream.url.contains("youtube.com") || stream.url.contains("youtu.be") ? [] : ["Invalid YouTube URL"],
            warnings: [],
            platform: stream.platform,
            timestamp: Date(),
            validationDetails: ValidationDetails()
        )
    }
    
    public func validateURL(_ url: String) async -> URLValidationResult {
        let isValid = url.contains("youtube.com") || url.contains("youtu.be")
        return URLValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Invalid YouTube URL"],
            warnings: [],
            platform: .youtube,
            extractedData: [:]
        )
    }
    
    public func quickValidate(_ stream: Stream) -> QuickValidationResult {
        let isValid = stream.url.contains("youtube.com") || stream.url.contains("youtu.be")
        return QuickValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Not a YouTube URL"],
            warnings: [],
            canProceed: isValid,
            confidence: isValid ? 0.8 : 0.2
        )
    }
}

public class KickStreamValidator: StreamValidator {
    public func validateStream(_ stream: Stream) async -> StreamValidationResult {
        return StreamValidationResult(
            streamId: stream.id,
            isValid: stream.url.contains("kick.com"),
            errors: stream.url.contains("kick.com") ? [] : ["Invalid Kick URL"],
            warnings: [],
            platform: stream.platform,
            timestamp: Date(),
            validationDetails: ValidationDetails()
        )
    }
    
    public func validateURL(_ url: String) async -> URLValidationResult {
        let isValid = url.contains("kick.com")
        return URLValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Invalid Kick URL"],
            warnings: [],
            platform: .kick,
            extractedData: [:]
        )
    }
    
    public func quickValidate(_ stream: Stream) -> QuickValidationResult {
        let isValid = stream.url.contains("kick.com")
        return QuickValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Not a Kick URL"],
            warnings: [],
            canProceed: isValid,
            confidence: isValid ? 0.8 : 0.2
        )
    }
}

public class RumbleStreamValidator: StreamValidator {
    public func validateStream(_ stream: Stream) async -> StreamValidationResult {
        return StreamValidationResult(
            streamId: stream.id,
            isValid: stream.url.contains("rumble.com"),
            errors: stream.url.contains("rumble.com") ? [] : ["Invalid Rumble URL"],
            warnings: [],
            platform: stream.platform,
            timestamp: Date(),
            validationDetails: ValidationDetails()
        )
    }
    
    public func validateURL(_ url: String) async -> URLValidationResult {
        let isValid = url.contains("rumble.com")
        return URLValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Invalid Rumble URL"],
            warnings: [],
            platform: .rumble,
            extractedData: [:]
        )
    }
    
    public func quickValidate(_ stream: Stream) -> QuickValidationResult {
        let isValid = stream.url.contains("rumble.com")
        return QuickValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Not a Rumble URL"],
            warnings: [],
            canProceed: isValid,
            confidence: isValid ? 0.8 : 0.2
        )
    }
}

public class GenericStreamValidator: StreamValidator {
    public func validateStream(_ stream: Stream) async -> StreamValidationResult {
        let isValidURL = URL(string: stream.url) != nil
        return StreamValidationResult(
            streamId: stream.id,
            isValid: isValidURL,
            errors: isValidURL ? [] : ["Invalid URL format"],
            warnings: ["Using generic validator - platform-specific validation unavailable"],
            platform: stream.platform,
            timestamp: Date(),
            validationDetails: ValidationDetails()
        )
    }
    
    public func validateURL(_ url: String) async -> URLValidationResult {
        let isValid = URL(string: url) != nil
        return URLValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Invalid URL format"],
            warnings: ["Generic validation only"],
            platform: .other,
            extractedData: [:]
        )
    }
    
    public func quickValidate(_ stream: Stream) -> QuickValidationResult {
        let isValid = URL(string: stream.url) != nil
        return QuickValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Invalid URL"],
            warnings: ["Limited validation"],
            canProceed: isValid,
            confidence: isValid ? 0.5 : 0.1
        )
    }
}