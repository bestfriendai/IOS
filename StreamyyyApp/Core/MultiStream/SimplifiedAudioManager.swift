//
//  SimplifiedAudioManager.swift
//  StreamyyyApp
//
//  Simplified audio manager for single active stream audio control
//  Created by Claude Code on 2025-07-12
//

import Foundation
import Combine

/// Simplified audio manager that ensures only one stream has audio at a time
@MainActor
public final class SimplifiedAudioManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = SimplifiedAudioManager()
    
    // MARK: - Published Properties
    @Published public var activeAudioStreamId: String? = nil
    @Published public var masterVolume: Float = 1.0
    @Published public var isMuted: Bool = false
    
    // MARK: - Private Properties
    private var streamVolumes: [String: Float] = [:]
    private var registeredStreams: Set<String> = []
    
    // MARK: - Initialization
    private init() {
        print("🔊 SimplifiedAudioManager initialized")
    }
    
    // MARK: - Public Interface
    
    /// Register a stream for audio management
    public func registerStream(_ streamId: String) {
        print("🔊 Registering stream: \(streamId)")
        registeredStreams.insert(streamId)
        streamVolumes[streamId] = 1.0
        
        // If this is the first stream, make it active
        if activeAudioStreamId == nil {
            setActiveAudioStream(streamId)
        }
    }
    
    /// Unregister a stream
    public func unregisterStream(_ streamId: String) {
        print("🔇 Unregistering stream: \(streamId)")
        registeredStreams.remove(streamId)
        streamVolumes.removeValue(forKey: streamId)
        
        // If this was the active stream, select another
        if activeAudioStreamId == streamId {
            activeAudioStreamId = registeredStreams.first
            notifyAudioChange()
        }
    }
    
    /// Set which stream should have audio (mutes all others)
    public func setActiveAudioStream(_ streamId: String?) {
        guard streamId == nil || registeredStreams.contains(streamId!) else { 
            print("⚠️ Attempted to set audio for unregistered stream: \(streamId ?? "nil")")
            return 
        }
        
        let previousActive = activeAudioStreamId
        activeAudioStreamId = streamId
        
        print("🎯 Audio switched from \(previousActive ?? "none") to \(streamId ?? "none")")
        
        // Notify all streams about the change
        notifyAudioChange()
    }
    
    /// Check if a stream should be muted
    public func isStreamMuted(_ streamId: String) -> Bool {
        // A stream is muted if:
        // 1. Master is muted
        // 2. It's not the active audio stream
        return isMuted || (activeAudioStreamId != streamId)
    }
    
    /// Toggle master mute
    public func toggleMasterMute() {
        isMuted.toggle()
        notifyAudioChange()
    }
    
    /// Set master volume
    public func setMasterVolume(_ volume: Float) {
        masterVolume = max(0.0, min(1.0, volume))
        notifyAudioChange()
    }
    
    /// Get effective volume for a stream
    public func getEffectiveVolume(for streamId: String) -> Float {
        if isStreamMuted(streamId) {
            return 0.0
        }
        let streamVolume = streamVolumes[streamId] ?? 1.0
        return streamVolume * masterVolume
    }
    
    /// Clear all audio (mute all)
    public func muteAll() {
        activeAudioStreamId = nil
        notifyAudioChange()
    }
    
    // MARK: - Private Methods
    
    private func notifyAudioChange() {
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioStreamChanged"),
            object: activeAudioStreamId
        )
        
        // Post individual stream notifications
        for streamId in registeredStreams {
            let isMuted = isStreamMuted(streamId)
            NotificationCenter.default.post(
                name: NSNotification.Name("StreamAudioStateChanged"),
                object: nil,
                userInfo: [
                    "streamId": streamId,
                    "isMuted": isMuted,
                    "volume": getEffectiveVolume(for: streamId)
                ]
            )
        }
    }
}

// MARK: - Convenience Extensions
extension SimplifiedAudioManager {
    
    /// Switch to next stream in the list
    public func switchToNextStream() {
        let sortedStreams = Array(registeredStreams).sorted()
        guard let currentId = activeAudioStreamId,
              let currentIndex = sortedStreams.firstIndex(of: currentId) else {
            // No current stream or not found, select first
            activeAudioStreamId = sortedStreams.first
            notifyAudioChange()
            return
        }
        
        let nextIndex = (currentIndex + 1) % sortedStreams.count
        activeAudioStreamId = sortedStreams[nextIndex]
        notifyAudioChange()
    }
    
    /// Switch to previous stream in the list
    public func switchToPreviousStream() {
        let sortedStreams = Array(registeredStreams).sorted()
        guard let currentId = activeAudioStreamId,
              let currentIndex = sortedStreams.firstIndex(of: currentId) else {
            // No current stream or not found, select last
            activeAudioStreamId = sortedStreams.last
            notifyAudioChange()
            return
        }
        
        let previousIndex = currentIndex == 0 ? sortedStreams.count - 1 : currentIndex - 1
        activeAudioStreamId = sortedStreams[previousIndex]
        notifyAudioChange()
    }
}