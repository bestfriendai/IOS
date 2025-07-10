//
//  StreamStateManager.swift
//  StreamyyyApp
//
//  Centralized stream state management for lifecycle control
//  Created by Claude Code on 2025-07-09
//

import Foundation
import SwiftUI
import Combine
import WebKit

/// Centralized stream state management
@MainActor
public class StreamStateManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = StreamStateManager()
    
    // MARK: - Published Properties
    @Published public private(set) var streamStates: [String: StreamState] = [:]
    @Published public private(set) var activeStreamId: String?
    @Published public private(set) var audioMixingEnabled: Bool = true
    @Published public private(set) var globalVolume: Double = 1.0
    @Published public private(set) var globalMuted: Bool = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var audioSessionActive = false
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Initialization
    private init() {
        setupObservers()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    /// Registers a new stream
    public func registerStream(_ stream: Stream, webView: WKWebView) {
        let state = StreamState(
            stream: stream,
            webView: webView,
            playbackState: .idle,
            isVisible: true,
            isMuted: false,
            volume: 1.0,
            lastUpdated: Date()
        )
        
        streamStates[stream.id] = state
        
        // If this is the first stream, make it active
        if activeStreamId == nil {
            setActiveStream(stream.id)
        }
        
        // Setup WebView observation
        setupWebViewObservation(for: stream.id)
    }
    
    /// Unregisters a stream
    public func unregisterStream(_ streamId: String) {
        streamStates.removeValue(forKey: streamId)
        
        // If this was the active stream, find a new active stream
        if activeStreamId == streamId {
            activeStreamId = streamStates.keys.first
        }
        
        // Clean up WebView
        SharedWebViewProcessPool.shared.unregisterWebView(streamStates[streamId]?.webView)
    }
    
    /// Sets the active stream for audio mixing
    public func setActiveStream(_ streamId: String) {
        guard streamStates[streamId] != nil else { return }
        
        let previousActiveId = activeStreamId
        activeStreamId = streamId
        
        // Handle audio mixing
        if audioMixingEnabled {
            // Mute all other streams
            for (id, state) in streamStates {
                if id != streamId {
                    muteStream(id, muted: true)
                }
            }
            
            // Unmute the active stream
            muteStream(streamId, muted: false)
        }
        
        // Suspend other WebViews for performance
        if let activeWebView = streamStates[streamId]?.webView {
            SharedWebViewProcessPool.shared.suspendAllWebViewsExcept(activeWebView)
        }
        
        // Update states
        if let previousId = previousActiveId {
            updateStreamState(previousId) { state in
                state.isActive = false
                state.lastUpdated = Date()
            }
        }
        
        updateStreamState(streamId) { state in
            state.isActive = true
            state.lastUpdated = Date()
        }
    }
    
    /// Updates playback state for a stream
    public func updatePlaybackState(_ streamId: String, state: StreamPlaybackState) {
        updateStreamState(streamId) { streamState in
            streamState.playbackState = state
            streamState.lastUpdated = Date()
        }
    }
    
    /// Updates visibility state for a stream
    public func updateVisibility(_ streamId: String, isVisible: Bool) {
        updateStreamState(streamId) { state in
            state.isVisible = isVisible
            state.lastUpdated = Date()
        }
        
        // If stream becomes invisible, pause it to save resources
        if !isVisible {
            pauseStream(streamId)
        }
    }
    
    /// Mutes or unmutes a specific stream
    public func muteStream(_ streamId: String, muted: Bool) {
        updateStreamState(streamId) { state in
            state.isMuted = muted
            state.lastUpdated = Date()
        }
        
        // Apply mute to WebView
        if let webView = streamStates[streamId]?.webView {
            if muted {
                webView.evaluateJavaScript("if (window.StreamyyyControl) window.StreamyyyControl.mute();")
            } else {
                webView.evaluateJavaScript("if (window.StreamyyyControl) window.StreamyyyControl.unmute();")
            }
        }
    }
    
    /// Sets volume for a specific stream
    public func setStreamVolume(_ streamId: String, volume: Double) {
        let clampedVolume = max(0.0, min(1.0, volume))
        
        updateStreamState(streamId) { state in
            state.volume = clampedVolume
            state.lastUpdated = Date()
        }
        
        // Apply volume to WebView
        if let webView = streamStates[streamId]?.webView {
            webView.evaluateJavaScript("if (window.StreamyyyControl) window.StreamyyyControl.setVolume(\(clampedVolume));")
        }
    }
    
    /// Pauses a specific stream
    public func pauseStream(_ streamId: String) {
        updateStreamState(streamId) { state in
            state.playbackState = .paused
            state.lastUpdated = Date()
        }
        
        // Apply pause to WebView
        if let webView = streamStates[streamId]?.webView {
            webView.evaluateJavaScript("if (window.StreamyyyControl) window.StreamyyyControl.pause();")
        }
    }
    
    /// Resumes a specific stream
    public func resumeStream(_ streamId: String) {
        updateStreamState(streamId) { state in
            state.playbackState = .playing
            state.lastUpdated = Date()
        }
        
        // Apply resume to WebView
        if let webView = streamStates[streamId]?.webView {
            webView.evaluateJavaScript("if (window.StreamyyyControl) window.StreamyyyControl.play();")
        }
    }
    
    /// Pauses all streams
    public func pauseAllStreams() {
        for streamId in streamStates.keys {
            pauseStream(streamId)
        }
    }
    
    /// Resumes all streams
    public func resumeAllStreams() {
        for streamId in streamStates.keys {
            resumeStream(streamId)
        }
    }
    
    /// Toggles global mute state
    public func toggleGlobalMute() {
        globalMuted.toggle()
        
        for streamId in streamStates.keys {
            muteStream(streamId, muted: globalMuted)
        }
    }
    
    /// Sets global volume
    public func setGlobalVolume(_ volume: Double) {
        globalVolume = max(0.0, min(1.0, volume))
        
        for streamId in streamStates.keys {
            setStreamVolume(streamId, volume: globalVolume)
        }
    }
    
    /// Enables or disables audio mixing
    public func setAudioMixing(enabled: Bool) {
        audioMixingEnabled = enabled
        
        if enabled {
            // If audio mixing is enabled, mute all but active stream
            for (id, _) in streamStates {
                muteStream(id, muted: id != activeStreamId)
            }
        } else {
            // If audio mixing is disabled, unmute all streams
            for streamId in streamStates.keys {
                muteStream(streamId, muted: false)
            }
        }
    }
    
    /// Gets the current state of a stream
    public func getStreamState(_ streamId: String) -> StreamState? {
        return streamStates[streamId]
    }
    
    /// Gets all active streams
    public func getActiveStreams() -> [StreamState] {
        return streamStates.values.filter { $0.playbackState == .playing }
    }
    
    /// Gets all visible streams
    public func getVisibleStreams() -> [StreamState] {
        return streamStates.values.filter { $0.isVisible }
    }
    
    /// Cleanup all streams
    public func cleanup() {
        for streamId in streamStates.keys {
            unregisterStream(streamId)
        }
        
        activeStreamId = nil
        deactivateAudioSession()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe app state changes
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                Task { @MainActor in
                    self.handleAppWillResignActive()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                Task { @MainActor in
                    self.handleAppDidBecomeActive()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                Task { @MainActor in
                    self.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in
                Task { @MainActor in
                    self.handleAppWillEnterForeground()
                }
            }
            .store(in: &cancellables)
        
        // Observe memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { _ in
                Task { @MainActor in
                    self.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioSession() {
        // Configure audio session for streaming
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try audioSession.setActive(true)
            audioSessionActive = true
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func deactivateAudioSession() {
        if audioSessionActive {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
                audioSessionActive = false
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        }
    }
    
    private func setupWebViewObservation(for streamId: String) {
        // Additional WebView observation setup can be added here
    }
    
    private func updateStreamState(_ streamId: String, update: (inout StreamState) -> Void) {
        guard var state = streamStates[streamId] else { return }
        update(&state)
        streamStates[streamId] = state
    }
    
    private func handleAppWillResignActive() {
        // Pause all streams when app becomes inactive
        for streamId in streamStates.keys {
            pauseStream(streamId)
        }
    }
    
    private func handleAppDidBecomeActive() {
        // Resume active stream when app becomes active
        if let activeId = activeStreamId {
            resumeStream(activeId)
        }
    }
    
    private func handleAppDidEnterBackground() {
        // Start background task to maintain stream state
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Pause all streams to save resources
        pauseAllStreams()
    }
    
    private func handleAppWillEnterForeground() {
        // End background task
        endBackgroundTask()
        
        // Resume visible streams
        for (streamId, state) in streamStates {
            if state.isVisible {
                resumeStream(streamId)
            }
        }
    }
    
    private func handleMemoryWarning() {
        // Pause invisible streams to free memory
        for (streamId, state) in streamStates {
            if !state.isVisible {
                pauseStream(streamId)
            }
        }
        
        // Clean up process pool
        SharedWebViewProcessPool.shared.clearAllWebsiteData()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
}

// MARK: - StreamState Model

/// Represents the current state of a stream
public struct StreamState {
    public let stream: Stream
    public weak var webView: WKWebView?
    public var playbackState: StreamPlaybackState
    public var isVisible: Bool
    public var isActive: Bool
    public var isMuted: Bool
    public var volume: Double
    public var lastUpdated: Date
    
    public init(
        stream: Stream,
        webView: WKWebView,
        playbackState: StreamPlaybackState,
        isVisible: Bool,
        isMuted: Bool,
        volume: Double,
        lastUpdated: Date
    ) {
        self.stream = stream
        self.webView = webView
        self.playbackState = playbackState
        self.isVisible = isVisible
        self.isActive = false
        self.isMuted = isMuted
        self.volume = volume
        self.lastUpdated = lastUpdated
    }
    
    public var isPlaying: Bool {
        return playbackState == .playing
    }
    
    public var isPaused: Bool {
        return playbackState == .paused
    }
    
    public var isBuffering: Bool {
        return playbackState == .buffering
    }
    
    public var hasError: Bool {
        return playbackState == .error
    }
}

// MARK: - Extensions

extension StreamStateManager {
    /// Debug description of current state
    public var debugDescription: String {
        var description = "StreamStateManager:\n"
        description += "  Active Stream: \(activeStreamId ?? "None")\n"
        description += "  Audio Mixing: \(audioMixingEnabled)\n"
        description += "  Global Volume: \(globalVolume)\n"
        description += "  Global Muted: \(globalMuted)\n"
        description += "  Streams:\n"
        
        for (id, state) in streamStates {
            description += "    \(id): \(state.playbackState.displayName) "
            description += "(visible: \(state.isVisible), active: \(state.isActive), "
            description += "muted: \(state.isMuted), volume: \(state.volume))\n"
        }
        
        return description
    }
}

// MARK: - Import AVFoundation
import AVFoundation