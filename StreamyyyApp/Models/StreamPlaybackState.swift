//
//  StreamPlaybackState.swift
//  StreamyyyApp
//
//  Defines playback states for multi-stream Twitch players
//

import Foundation

/// Represents the current playback state of a stream in multi-stream view
public enum StreamPlaybackState: String, CaseIterable {
    case loading = "loading"
    case ready = "ready"
    case playing = "playing"
    case paused = "paused"
    case buffering = "buffering"
    case error = "error"
    case offline = "offline"
    case ended = "ended"
    
    /// Human-readable display name for the state
    public var displayName: String {
        switch self {
        case .loading:
            return "Loading"
        case .ready:
            return "Ready"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .buffering:
            return "Buffering"
        case .error:
            return "Error"
        case .offline:
            return "Offline"
        case .ended:
            return "Ended"
        }
    }
    
    /// Whether the stream is actively playing content
    public var isActive: Bool {
        switch self {
        case .playing, .buffering:
            return true
        case .loading, .ready, .paused, .error, .offline, .ended:
            return false
        }
    }
    
    /// Whether the stream has encountered an issue
    public var hasIssue: Bool {
        switch self {
        case .error, .offline:
            return true
        case .loading, .ready, .playing, .paused, .buffering, .ended:
            return false
        }
    }
    
    /// Whether the stream can be interacted with (play/pause)
    public var isInteractable: Bool {
        switch self {
        case .ready, .playing, .paused:
            return true
        case .loading, .buffering, .error, .offline, .ended:
            return false
        }
    }
    
    /// Color representation for UI indicators
    public var indicatorColor: String {
        switch self {
        case .loading, .buffering:
            return "yellow"
        case .ready, .paused:
            return "gray"
        case .playing:
            return "green"
        case .error, .offline:
            return "red"
        case .ended:
            return "blue"
        }
    }
}

/// Extension for multi-stream specific functionality
extension StreamPlaybackState {
    /// States that should show a loading indicator in multi-stream view
    public var shouldShowLoadingIndicator: Bool {
        switch self {
        case .loading, .buffering:
            return true
        case .ready, .playing, .paused, .error, .offline, .ended:
            return false
        }
    }
    
    /// States that should allow stream interaction in multi-stream view
    public var allowsMultiStreamInteraction: Bool {
        switch self {
        case .ready, .playing, .paused:
            return true
        case .loading, .buffering, .error, .offline, .ended:
            return false
        }
    }
    
    /// Priority for resource allocation in multi-stream (higher = more resources)
    public var resourcePriority: Int {
        switch self {
        case .playing:
            return 3
        case .ready, .paused:
            return 2
        case .loading, .buffering:
            return 1
        case .error, .offline, .ended:
            return 0
        }
    }
}