//
//  StreamExtensions.swift
//  StreamyyyApp
//
//  Stream model extensions for UI, validation, and API
//

import Foundation
import SwiftUI
import AVKit

// MARK: - Stream UI Extensions
extension Stream {
    
    // MARK: - Preview Views
    public var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Image(systemName: "tv")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            .cornerRadius(8)
            .overlay(
                // Live indicator
                HStack {
                    if isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Viewer count
                    if viewerCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                            Text(formattedViewerCount)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                }
                .padding(8),
                alignment: .topTrailing
            )
            
            // Stream info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let streamerName = streamerName {
                    Text(streamerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    // Platform badge
                    platformBadge
                    
                    Spacer()
                    
                    // Health status
                    healthIndicator
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    public var platformBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: platform.icon)
                .font(.caption)
            Text(platform.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(platform.color)
        .cornerRadius(6)
    }
    
    public var healthIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: healthStatus.icon)
                .font(.caption)
            Text(healthStatus.displayName)
                .font(.caption)
        }
        .foregroundColor(healthStatus.color)
    }
    
    // MARK: - Control Views
    public var controlsOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                // Mute button
                Button(action: { toggleMute() }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Quality selector
                qualitySelector
                
                Spacer()
                
                // Fullscreen button
                Button(action: { toggleFullscreen() }) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    public var qualitySelector: some View {
        Menu {
            ForEach(availableQualities, id: \.self) { quality in
                Button(quality.displayName) {
                    updateQuality(quality)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(quality.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.5))
            .cornerRadius(6)
        }
    }
    
    public var volumeSlider: some View {
        HStack {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundColor(.white)
            
            Slider(value: Binding(
                get: { volume },
                set: { setVolume($0) }
            ), in: 0...1)
            .accentColor(.white)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }
    
    // MARK: - Detail Views
    public var detailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                AsyncImage(url: URL(string: streamerAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let streamerName = streamerName {
                        Text(streamerName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    platformBadge
                    
                    if isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // Stats
            statisticsView
            
            // Description
            if let description = description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // Tags
            if !tags.isEmpty {
                tagsView
            }
            
            // Analytics
            if let owner = owner, owner.hasFeature(.analytics) {
                analyticsView
            }
        }
        .padding()
    }
    
    public var statisticsView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            StatCard(title: "Viewers", value: formattedViewerCount, icon: "eye.fill", color: .blue)
            StatCard(title: "Duration", value: formattedDuration, icon: "clock.fill", color: .green)
            StatCard(title: "Views", value: "\(viewCount)", icon: "play.fill", color: .purple)
            StatCard(title: "Quality", value: quality.displayName, icon: "tv.fill", color: .orange)
        }
    }
    
    public var tagsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
            }
        }
    }
    
    public var analyticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(.headline)
            
            // Connection health
            HStack {
                Text("Connection Health")
                    .font(.subheadline)
                Spacer()
                healthIndicator
            }
            
            // Connection attempts
            HStack {
                Text("Connection Attempts")
                    .font(.subheadline)
                Spacer()
                Text("\(connectionAttempts)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // View history
            if let lastViewedAt = lastViewedAt {
                HStack {
                    Text("Last Viewed")
                        .font(.subheadline)
                    Spacer()
                    Text(lastViewedAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    public func favoriteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .foregroundColor(isFavorited ? .red : .gray)
                Text(isFavorited ? "Favorited" : "Add to Favorites")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
    }
    
    public func shareButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
    }
    
    public func pipButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "pip.enter")
                Text("Picture in Picture")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .disabled(!canPlayPictureInPicture)
    }
}

// MARK: - Stream API Extensions
extension Stream {
    
    // MARK: - API Serialization
    public func toAPIDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "url": url,
            "original_url": originalURL,
            "platform": platform.rawValue,
            "title": title,
            "is_live": isLive,
            "viewer_count": viewerCount,
            "duration": duration,
            "quality": quality.rawValue,
            "is_muted": isMuted,
            "volume": volume,
            "is_fullscreen": isFullscreen,
            "is_picture_in_picture": isPictureInPicture,
            "is_auto_play": isAutoPlay,
            "is_visible": isVisible,
            "position": [
                "x": position.x,
                "y": position.y,
                "width": position.width,
                "height": position.height,
                "z_index": position.zIndex
            ],
            "metadata": metadata,
            "created_at": createdAt.timeIntervalSince1970,
            "updated_at": updatedAt.timeIntervalSince1970,
            "view_count": viewCount,
            "is_archived": isArchived,
            "health_status": healthStatus.rawValue,
            "connection_attempts": connectionAttempts,
            "tags": tags,
            "available_qualities": availableQualities.map { $0.rawValue }
        ]
        
        if let embedURL = embedURL {
            dict["embed_url"] = embedURL
        }
        
        if let description = description {
            dict["description"] = description
        }
        
        if let thumbnailURL = thumbnailURL {
            dict["thumbnail_url"] = thumbnailURL
        }
        
        if let streamerName = streamerName {
            dict["streamer_name"] = streamerName
        }
        
        if let streamerAvatarURL = streamerAvatarURL {
            dict["streamer_avatar_url"] = streamerAvatarURL
        }
        
        if let category = category {
            dict["category"] = category
        }
        
        if let language = language {
            dict["language"] = language
        }
        
        if let startedAt = startedAt {
            dict["started_at"] = startedAt.timeIntervalSince1970
        }
        
        if let endedAt = endedAt {
            dict["ended_at"] = endedAt.timeIntervalSince1970
        }
        
        if let lastViewedAt = lastViewedAt {
            dict["last_viewed_at"] = lastViewedAt.timeIntervalSince1970
        }
        
        if let archiveReason = archiveReason {
            dict["archive_reason"] = archiveReason
        }
        
        if let lastConnectionAttempt = lastConnectionAttempt {
            dict["last_connection_attempt"] = lastConnectionAttempt.timeIntervalSince1970
        }
        
        if let owner = owner {
            dict["owner_id"] = owner.id
        }
        
        return dict
    }
    
    public static func fromAPIDict(_ dict: [String: Any]) -> Stream? {
        guard let id = dict["id"] as? String,
              let url = dict["url"] as? String,
              let platformRaw = dict["platform"] as? String,
              let platform = Platform(rawValue: platformRaw),
              let title = dict["title"] as? String else {
            return nil
        }
        
        let stream = Stream(
            id: id,
            url: url,
            platform: platform,
            title: title
        )
        
        stream.originalURL = dict["original_url"] as? String ?? url
        stream.embedURL = dict["embed_url"] as? String
        stream.description = dict["description"] as? String
        stream.thumbnailURL = dict["thumbnail_url"] as? String
        stream.streamerName = dict["streamer_name"] as? String
        stream.streamerAvatarURL = dict["streamer_avatar_url"] as? String
        stream.category = dict["category"] as? String
        stream.language = dict["language"] as? String
        stream.isLive = dict["is_live"] as? Bool ?? false
        stream.viewerCount = dict["viewer_count"] as? Int ?? 0
        stream.duration = dict["duration"] as? TimeInterval ?? 0
        stream.isMuted = dict["is_muted"] as? Bool ?? false
        stream.volume = dict["volume"] as? Double ?? 1.0
        stream.isFullscreen = dict["is_fullscreen"] as? Bool ?? false
        stream.isPictureInPicture = dict["is_picture_in_picture"] as? Bool ?? false
        stream.isAutoPlay = dict["is_auto_play"] as? Bool ?? true
        stream.isVisible = dict["is_visible"] as? Bool ?? true
        stream.metadata = dict["metadata"] as? [String: String] ?? [:]
        stream.viewCount = dict["view_count"] as? Int ?? 0
        stream.isArchived = dict["is_archived"] as? Bool ?? false
        stream.connectionAttempts = dict["connection_attempts"] as? Int ?? 0
        stream.tags = dict["tags"] as? [String] ?? []
        
        if let createdAtTimestamp = dict["created_at"] as? TimeInterval {
            stream.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        }
        
        if let updatedAtTimestamp = dict["updated_at"] as? TimeInterval {
            stream.updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        }
        
        if let qualityRaw = dict["quality"] as? String {
            stream.quality = StreamQuality(rawValue: qualityRaw) ?? platform.defaultQuality
        }
        
        if let availableQualitiesRaw = dict["available_qualities"] as? [String] {
            stream.availableQualities = availableQualitiesRaw.compactMap { StreamQuality(rawValue: $0) }
        }
        
        if let healthStatusRaw = dict["health_status"] as? String {
            stream.healthStatus = StreamHealthStatus(rawValue: healthStatusRaw) ?? .unknown
        }
        
        if let positionDict = dict["position"] as? [String: Any] {
            stream.position = StreamPosition(
                x: positionDict["x"] as? Double ?? 0,
                y: positionDict["y"] as? Double ?? 0,
                width: positionDict["width"] as? Double ?? 300,
                height: positionDict["height"] as? Double ?? 200,
                zIndex: positionDict["z_index"] as? Int ?? 0
            )
        }
        
        if let startedAtTimestamp = dict["started_at"] as? TimeInterval {
            stream.startedAt = Date(timeIntervalSince1970: startedAtTimestamp)
        }
        
        if let endedAtTimestamp = dict["ended_at"] as? TimeInterval {
            stream.endedAt = Date(timeIntervalSince1970: endedAtTimestamp)
        }
        
        if let lastViewedAtTimestamp = dict["last_viewed_at"] as? TimeInterval {
            stream.lastViewedAt = Date(timeIntervalSince1970: lastViewedAtTimestamp)
        }
        
        if let lastConnectionAttemptTimestamp = dict["last_connection_attempt"] as? TimeInterval {
            stream.lastConnectionAttempt = Date(timeIntervalSince1970: lastConnectionAttemptTimestamp)
        }
        
        stream.archiveReason = dict["archive_reason"] as? String
        
        return stream
    }
    
    // MARK: - Platform API Integration
    public func fetchMetadataFromPlatform() async throws {
        switch platform {
        case .twitch:
            try await fetchTwitchMetadata()
        case .youtube:
            try await fetchYouTubeMetadata()
        case .kick:
            try await fetchKickMetadata()
        default:
            throw StreamError.unsupportedPlatform
        }
    }
    
    private func fetchTwitchMetadata() async throws {
        guard let identifier = platform.extractStreamIdentifier(from: url) else {
            throw StreamError.invalidURL
        }
        
        // Twitch API call would go here
        // This is a placeholder implementation
        print("Fetching Twitch metadata for: \(identifier)")
    }
    
    private func fetchYouTubeMetadata() async throws {
        guard let identifier = platform.extractStreamIdentifier(from: url) else {
            throw StreamError.invalidURL
        }
        
        // YouTube API call would go here
        print("Fetching YouTube metadata for: \(identifier)")
    }
    
    private func fetchKickMetadata() async throws {
        guard let identifier = platform.extractStreamIdentifier(from: url) else {
            throw StreamError.invalidURL
        }
        
        // Kick API call would go here
        print("Fetching Kick metadata for: \(identifier)")
    }
    
    // MARK: - Analytics
    public func trackEvent(_ event: StreamAnalyticsEvent, value: Double = 1.0, metadata: [String: String] = [:]) {
        let analytics = StreamAnalytics(
            event: event,
            value: value,
            metadata: metadata,
            stream: self
        )
        
        self.analytics.append(analytics)
        
        // Also track in global analytics
        var eventMetadata = metadata
        eventMetadata["stream_id"] = id
        eventMetadata["platform"] = platform.rawValue
        eventMetadata["is_live"] = String(isLive)
        
        AnalyticsManager.shared.track(event.rawValue, properties: eventMetadata)
    }
    
    // MARK: - Health Monitoring
    public func checkHealth() async {
        do {
            // Perform health check based on platform
            let isHealthy = try await performHealthCheck()
            
            if isHealthy {
                updateHealthStatus(.healthy)
            } else {
                updateHealthStatus(.error)
            }
            
            trackEvent(.connectionError, value: isHealthy ? 0 : 1)
            
        } catch {
            updateHealthStatus(.error)
            trackEvent(.connectionError, value: 1, metadata: ["error": error.localizedDescription])
        }
    }
    
    private func performHealthCheck() async throws -> Bool {
        // Implement health check logic
        // This would involve checking if the stream URL is accessible
        guard let url = URL(string: url) else {
            throw StreamError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        
        return false
    }
}

// MARK: - Supporting Views
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Stream Validation Extensions
extension Stream {
    
    // MARK: - Validation Rules
    public var validationErrors: [String] {
        var errors: [String] = []
        
        if !validateURL() {
            errors.append("Invalid stream URL")
        }
        
        if title.isEmpty {
            errors.append("Stream title is required")
        }
        
        if !platform.supportsEmbedding && embedURL != nil {
            errors.append("Platform does not support embedding")
        }
        
        if volume < 0 || volume > 1 {
            errors.append("Volume must be between 0 and 1")
        }
        
        if position.width <= 0 || position.height <= 0 {
            errors.append("Stream dimensions must be positive")
        }
        
        return errors
    }
    
    public var isValidForCreation: Bool {
        return validationErrors.isEmpty
    }
    
    public var isReadyForPlayback: Bool {
        return isValidForCreation && !isArchived && isVisible
    }
    
    // MARK: - Quality Validation
    public func canUseQuality(_ quality: StreamQuality) -> Bool {
        return availableQualities.contains(quality)
    }
    
    public func validateQualityChange(_ newQuality: StreamQuality) -> Bool {
        return canUseQuality(newQuality) && newQuality != quality
    }
    
    // MARK: - Position Validation
    public func validatePosition(_ newPosition: StreamPosition) -> Bool {
        return newPosition.width > 0 && 
               newPosition.height > 0 && 
               newPosition.x >= 0 && 
               newPosition.y >= 0
    }
    
    // MARK: - Content Validation
    public func validateContent() -> Bool {
        // Check for inappropriate content, blocked URLs, etc.
        // This is a placeholder implementation
        return !url.contains("blocked") && !title.contains("inappropriate")
    }
}