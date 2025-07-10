//
//  AudioManager.swift
//  StreamyyyApp
//
//  Audio management for multi-stream viewing
//

import Foundation
import Combine

@MainActor
class MultiStreamAudioManager: ObservableObject {
    static let shared = MultiStreamAudioManager()
    
    @Published var activeAudioStreamId: String? = nil
    
    private init() {}
    
    func setActiveAudioStream(_ streamId: String) {
        if activeAudioStreamId == streamId {
            // If tapping the same stream, mute it
            activeAudioStreamId = nil
        } else {
            // Set new active stream
            activeAudioStreamId = streamId
        }
        
        // Post notification for all streams to update their audio state
        NotificationCenter.default.post(
            name: Notification.Name("AudioStreamChanged"),
            object: activeAudioStreamId
        )
    }
    
    func isStreamAudioActive(_ streamId: String) -> Bool {
        return activeAudioStreamId == streamId
    }
    
    func muteAll() {
        activeAudioStreamId = nil
        NotificationCenter.default.post(
            name: Notification.Name("AudioStreamChanged"),
            object: nil
        )
    }
}