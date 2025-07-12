//
//  FlexibleAudioManager.swift
//  StreamyyyApp
//
//  Flexible audio manager that allows multiple streams to have audio simultaneously
//  Created by Claude Code on 2025-07-12
//

import Foundation
import Combine

/// Audio manager that allows users to control audio for each stream independently
@MainActor
public final class FlexibleAudioManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = FlexibleAudioManager()
    
    // MARK: - Published Properties
    @Published public var streamAudioStates: [String: Bool] = [:] // streamId -> isMuted
    @Published public var masterVolume: Float = 1.0
    @Published public var masterMuted: Bool = false
    
    // MARK: - Private Properties
    private var streamVolumes: [String: Float] = [:]
    
    // MARK: - Initialization
    private init() {
        print("🔊 FlexibleAudioManager initialized")
    }
    
    // MARK: - Public Interface
    
    /// Register a stream for audio management
    public func registerStream(_ streamId: String, startMuted: Bool = true) {
        print("🔊 Registering stream: \(streamId)")
        streamAudioStates[streamId] = startMuted
        streamVolumes[streamId] = 1.0
        notifyAudioChange(for: streamId)
    }
    
    /// Unregister a stream
    public func unregisterStream(_ streamId: String) {
        print("🔇 Unregistering stream: \(streamId)")
        streamAudioStates.removeValue(forKey: streamId)
        streamVolumes.removeValue(forKey: streamId)
    }
    
    /// Toggle mute for a specific stream
    public func toggleStreamMute(_ streamId: String) {
        guard streamAudioStates[streamId] != nil else { return }
        streamAudioStates[streamId]?.toggle()
        
        let isMuted = streamAudioStates[streamId] ?? true
        print("🔊 Stream \(streamId) is now \(isMuted ? "muted" : "unmuted")")
        
        notifyAudioChange(for: streamId)
    }
    
    /// Set mute state for a specific stream
    public func setStreamMuted(_ streamId: String, muted: Bool) {
        streamAudioStates[streamId] = muted
        notifyAudioChange(for: streamId)
    }
    
    /// Check if a stream is muted
    public func isStreamMuted(_ streamId: String) -> Bool {
        // A stream is muted if:
        // 1. Master is muted
        // 2. The stream itself is muted
        if masterMuted { return true }
        return streamAudioStates[streamId] ?? true
    }
    
    /// Get number of unmuted streams
    public func getUnmutedStreamCount() -> Int {
        if masterMuted { return 0 }
        return streamAudioStates.values.filter { !$0 }.count
    }
    
    /// Mute all streams
    public func muteAll() {
        for streamId in streamAudioStates.keys {
            streamAudioStates[streamId] = true
        }
        notifyAllAudioChanges()
    }
    
    /// Unmute all streams
    public func unmuteAll() {
        for streamId in streamAudioStates.keys {
            streamAudioStates[streamId] = false
        }
        notifyAllAudioChanges()
    }
    
    /// Toggle master mute
    public func toggleMasterMute() {
        masterMuted.toggle()
        notifyAllAudioChanges()
    }
    
    /// Quick action: Solo a stream (mute all others)
    public func soloStream(_ streamId: String) {
        for id in streamAudioStates.keys {
            streamAudioStates[id] = (id != streamId)
        }
        notifyAllAudioChanges()
    }
    
    // MARK: - Private Methods
    
    private func notifyAudioChange(for streamId: String) {
        let isMuted = isStreamMuted(streamId)
        
        // Post notification for this specific stream
        NotificationCenter.default.post(
            name: NSNotification.Name("StreamAudioStateChanged"),
            object: nil,
            userInfo: [
                "streamId": streamId,
                "isMuted": isMuted
            ]
        )
        
        // Also post a general audio change notification
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioStateChanged"),
            object: nil
        )
    }
    
    private func notifyAllAudioChanges() {
        for streamId in streamAudioStates.keys {
            notifyAudioChange(for: streamId)
        }
    }
}

// MARK: - Convenience Extensions
extension FlexibleAudioManager {
    
    /// Get a display string for audio status
    public func getAudioStatusDescription() -> String {
        let unmutedCount = getUnmutedStreamCount()
        if masterMuted {
            return "All Muted"
        } else if unmutedCount == 0 {
            return "All Streams Muted"
        } else if unmutedCount == 1 {
            return "1 Stream Playing"
        } else {
            return "\(unmutedCount) Streams Playing"
        }
    }
    
    /// Check if we should show a warning (too many unmuted streams)
    public func shouldShowAudioWarning() -> Bool {
        // Warn if more than 3 streams are unmuted (for performance)
        return getUnmutedStreamCount() > 3
    }
}