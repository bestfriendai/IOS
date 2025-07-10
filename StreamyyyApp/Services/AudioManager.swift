//
//  AudioManager.swift
//  StreamyyyApp
//
//  Centralized audio control system to ensure only one stream plays audio at a time
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

@MainActor
public class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published public var currentAudioStream: Stream?
    @Published public var globalVolume: Float = 1.0
    @Published public var isGloballyMuted: Bool = false
    @Published public var audioSwitchingEnabled: Bool = true
    @Published public var crossfadeEnabled: Bool = true
    @Published public var duckingEnabled: Bool = true
    @Published public var audioFocusMode: AudioFocusMode = .automatic
    
    // MARK: - Private Properties
    private var audioStreams: [String: StreamAudioController] = [:]
    private var crossfadeTimer: Timer?
    private var duckingTimer: Timer?
    private let crossfadeDuration: TimeInterval = 0.5
    private let duckingDuration: TimeInterval = 0.3
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Audio Session
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Initialization
    public init() {
        setupAudioSession()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Switch audio to a specific stream
    public func switchAudioTo(_ stream: Stream) {
        guard audioSwitchingEnabled else { return }
        
        // Don't switch if already playing
        if currentAudioStream?.id == stream.id {
            return
        }
        
        let previousStream = currentAudioStream
        currentAudioStream = stream
        
        // Handle audio switching with crossfade or instant switch
        if crossfadeEnabled && previousStream != nil {
            performCrossfade(from: previousStream, to: stream)
        } else {
            performInstantSwitch(from: previousStream, to: stream)
        }
        
        // Update stream audio states
        updateStreamAudioStates()
    }
    
    /// Mute/unmute all audio
    public func toggleGlobalMute() {
        isGloballyMuted.toggle()
        updateAllStreamVolumes()
    }
    
    /// Set global volume
    public func setGlobalVolume(_ volume: Float) {
        globalVolume = max(0.0, min(1.0, volume))
        updateAllStreamVolumes()
    }
    
    /// Enable/disable audio for a specific stream
    public func setStreamAudioEnabled(_ stream: Stream, enabled: Bool) {
        guard let audioController = audioStreams[stream.id] else { return }
        
        if enabled && currentAudioStream?.id != stream.id {
            switchAudioTo(stream)
        } else if !enabled && currentAudioStream?.id == stream.id {
            currentAudioStream = nil
            audioController.setMuted(true)
        }
        
        updateStreamAudioStates()
    }
    
    /// Set volume for a specific stream
    public func setStreamVolume(_ stream: Stream, volume: Float) {
        guard let audioController = audioStreams[stream.id] else { return }
        
        let finalVolume = calculateFinalVolume(baseVolume: volume, for: stream)
        audioController.setVolume(finalVolume)
        
        // Update stream model
        stream.setVolume(Double(volume))
    }
    
    /// Get current volume for a stream
    public func getStreamVolume(_ stream: Stream) -> Float {
        return audioStreams[stream.id]?.volume ?? Float(stream.volume)
    }
    
    /// Check if a stream has audio enabled
    public func isStreamAudioEnabled(_ stream: Stream) -> Bool {
        return currentAudioStream?.id == stream.id
    }
    
    /// Register a new stream for audio management
    public func registerStream(_ stream: Stream) {
        let audioController = StreamAudioController(stream: stream)
        audioStreams[stream.id] = audioController
        
        // Set initial state
        let isAudioEnabled = currentAudioStream?.id == stream.id
        audioController.setMuted(!isAudioEnabled || isGloballyMuted)
        
        let finalVolume = calculateFinalVolume(baseVolume: Float(stream.volume), for: stream)
        audioController.setVolume(finalVolume)
        
        // Setup audio monitoring
        setupAudioMonitoring(for: audioController)
    }
    
    /// Unregister a stream from audio management
    public func unregisterStream(_ stream: Stream) {
        audioStreams.removeValue(forKey: stream.id)
        
        // If this was the current audio stream, clear it
        if currentAudioStream?.id == stream.id {
            currentAudioStream = nil
        }
    }
    
    /// Handle focus mode change
    public func enterFocusMode(_ stream: Stream) {
        audioFocusMode = .focus
        
        if duckingEnabled {
            performDucking(focusStream: stream)
        } else {
            switchAudioTo(stream)
        }
    }
    
    /// Exit focus mode
    public func exitFocusMode() {
        audioFocusMode = .automatic
        
        if duckingEnabled {
            restoreFromDucking()
        }
    }
    
    /// Handle picture-in-picture mode
    public func enterPictureInPicture(_ stream: Stream) {
        // Ensure PiP stream has audio
        switchAudioTo(stream)
    }
    
    /// Exit picture-in-picture mode
    public func exitPictureInPicture() {
        // Return to normal audio management
        audioFocusMode = .automatic
    }
    
    /// Handle fullscreen mode
    public func enterFullscreen(_ stream: Stream) {
        audioFocusMode = .fullscreen
        switchAudioTo(stream)
    }
    
    /// Exit fullscreen mode
    public func exitFullscreen() {
        audioFocusMode = .automatic
    }
    
    /// Handle layout change
    public func layoutDidChange(_ layout: Layout) {
        // Adjust audio behavior based on layout type
        switch layout.type {
        case .focus:
            audioFocusMode = .focus
        case .theater:
            audioFocusMode = .theater
        default:
            audioFocusMode = .automatic
        }
        
        updateStreamAudioStates()
    }
    
    /// Handle stream added
    public func streamAdded(_ stream: Stream) {
        registerStream(stream)
        
        // Auto-switch to new stream in certain modes
        if audioFocusMode == .automatic && currentAudioStream == nil {
            switchAudioTo(stream)
        }
    }
    
    /// Handle stream removed
    public func streamRemoved(_ stream: Stream) {
        unregisterStream(stream)
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupBindings() {
        // Monitor global mute changes
        $isGloballyMuted
            .sink { [weak self] _ in
                self?.updateAllStreamVolumes()
            }
            .store(in: &cancellables)
        
        // Monitor global volume changes
        $globalVolume
            .sink { [weak self] _ in
                self?.updateAllStreamVolumes()
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioMonitoring(for audioController: StreamAudioController) {
        // Monitor audio level changes, playback state, etc.
        audioController.onAudioLevelChanged = { [weak self] level in
            // Handle audio level changes for visualizations
        }
        
        audioController.onPlaybackStateChanged = { [weak self] isPlaying in
            // Handle playback state changes
        }
    }
    
    private func performCrossfade(from previousStream: Stream?, to newStream: Stream) {
        guard let previousStream = previousStream,
              let previousController = audioStreams[previousStream.id],
              let newController = audioStreams[newStream.id] else {
            performInstantSwitch(from: previousStream, to: newStream)
            return
        }
        
        // Cancel any existing crossfade
        crossfadeTimer?.invalidate()
        
        // Start new stream at 0 volume
        newController.setMuted(false)
        newController.setVolume(0.0)
        
        // Crossfade animation
        let steps = 20
        let stepDuration = crossfadeDuration / Double(steps)
        var currentStep = 0
        
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            
            // Fade out previous stream
            let previousVolume = self?.calculateFinalVolume(baseVolume: Float(previousStream.volume), for: previousStream) ?? 1.0
            previousController.setVolume(previousVolume * (1.0 - progress))
            
            // Fade in new stream
            let newVolume = self?.calculateFinalVolume(baseVolume: Float(newStream.volume), for: newStream) ?? 1.0
            newController.setVolume(newVolume * progress)
            
            if currentStep >= steps {
                timer.invalidate()
                
                // Mute previous stream
                previousController.setMuted(true)
                
                // Ensure new stream is at full volume
                newController.setVolume(newVolume)
            }
        }
    }
    
    private func performInstantSwitch(from previousStream: Stream?, to newStream: Stream) {
        // Mute previous stream
        if let previousStream = previousStream,
           let previousController = audioStreams[previousStream.id] {
            previousController.setMuted(true)
        }
        
        // Unmute and set volume for new stream
        if let newController = audioStreams[newStream.id] {
            newController.setMuted(false)
            let finalVolume = calculateFinalVolume(baseVolume: Float(newStream.volume), for: newStream)
            newController.setVolume(finalVolume)
        }
    }
    
    private func performDucking(focusStream: Stream) {
        guard let focusController = audioStreams[focusStream.id] else { return }
        
        // Duck all other streams
        for (streamId, audioController) in audioStreams {
            if streamId != focusStream.id {
                let duckingVolume = audioController.volume * 0.3 // Duck to 30%
                audioController.setVolume(duckingVolume)
            }
        }
        
        // Boost focus stream
        let focusVolume = calculateFinalVolume(baseVolume: Float(focusStream.volume), for: focusStream)
        focusController.setVolume(focusVolume)
        focusController.setMuted(false)
    }
    
    private func restoreFromDucking() {
        // Restore all streams to their original volumes
        for (streamId, audioController) in audioStreams {
            if let stream = getStreamById(streamId) {
                let originalVolume = calculateFinalVolume(baseVolume: Float(stream.volume), for: stream)
                audioController.setVolume(originalVolume)
            }
        }
        
        updateStreamAudioStates()
    }
    
    private func updateStreamAudioStates() {
        for (streamId, audioController) in audioStreams {
            guard let stream = getStreamById(streamId) else { continue }
            
            let isAudioEnabled = currentAudioStream?.id == streamId
            audioController.setMuted(!isAudioEnabled || isGloballyMuted)
            
            if isAudioEnabled {
                let finalVolume = calculateFinalVolume(baseVolume: Float(stream.volume), for: stream)
                audioController.setVolume(finalVolume)
            }
        }
    }
    
    private func updateAllStreamVolumes() {
        for (streamId, audioController) in audioStreams {
            guard let stream = getStreamById(streamId) else { continue }
            
            let finalVolume = calculateFinalVolume(baseVolume: Float(stream.volume), for: stream)
            audioController.setVolume(finalVolume)
            audioController.setMuted(isGloballyMuted)
        }
    }
    
    private func calculateFinalVolume(baseVolume: Float, for stream: Stream) -> Float {
        var finalVolume = baseVolume * globalVolume
        
        // Apply focus mode adjustments
        if audioFocusMode == .focus && currentAudioStream?.id == stream.id {
            finalVolume = min(1.0, finalVolume * 1.2) // Boost focused stream
        }
        
        return max(0.0, min(1.0, finalVolume))
    }
    
    private func getStreamById(_ streamId: String) -> Stream? {
        // This would typically come from a stream manager or be passed in
        // For now, we'll need to get it from the audio controller
        return audioStreams[streamId]?.stream
    }
}

// MARK: - Stream Audio Controller
private class StreamAudioController: ObservableObject {
    let stream: Stream
    @Published var volume: Float = 1.0
    @Published var isMuted: Bool = false
    @Published var isPlaying: Bool = false
    @Published var audioLevel: Float = 0.0
    
    var onAudioLevelChanged: ((Float) -> Void)?
    var onPlaybackStateChanged: ((Bool) -> Void)?
    
    init(stream: Stream) {
        self.stream = stream
        self.volume = Float(stream.volume)
        self.isMuted = stream.isMuted
    }
    
    func setVolume(_ volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
        
        // Update the actual WebView or player volume
        updateWebViewVolume()
    }
    
    func setMuted(_ muted: Bool) {
        self.isMuted = muted
        
        // Update the actual WebView or player mute state
        updateWebViewMute()
    }
    
    func setPlaying(_ playing: Bool) {
        self.isPlaying = playing
        onPlaybackStateChanged?(playing)
    }
    
    private func updateWebViewVolume() {
        // This would interact with the WebView to update volume
        // Implementation depends on the WebView setup
    }
    
    private func updateWebViewMute() {
        // This would interact with the WebView to update mute state
        // Implementation depends on the WebView setup
    }
}

// MARK: - Audio Focus Mode
public enum AudioFocusMode {
    case automatic
    case focus
    case theater
    case fullscreen
    case manual
}

// MARK: - Audio Manager Protocol Implementation
extension AudioManager: AudioManagerProtocol {
    public func layoutDidChange(_ layout: Layout) {
        layoutDidChange(layout)
    }
    
    public func streamAdded(_ stream: Stream) {
        streamAdded(stream)
    }
    
    public func streamRemoved(_ stream: Stream) {
        streamRemoved(stream)
    }
    
    public func switchAudioTo(_ stream: Stream) {
        switchAudioTo(stream)
    }
    
    public func exitFullscreen() {
        exitFullscreen()
    }
}

// MARK: - Audio Extensions
extension AudioManager {
    
    /// Get audio info for UI display
    public func getAudioInfo() -> AudioInfo {
        return AudioInfo(
            currentStreamId: currentAudioStream?.id,
            globalVolume: globalVolume,
            isGloballyMuted: isGloballyMuted,
            activeStreamsCount: audioStreams.count,
            focusMode: audioFocusMode
        )
    }
    
    /// Check if audio ducking is active
    public var isDuckingActive: Bool {
        return audioFocusMode == .focus && duckingEnabled
    }
    
    /// Check if crossfading is in progress
    public var isCrossfading: Bool {
        return crossfadeTimer?.isValid ?? false
    }
}

// MARK: - Audio Info
public struct AudioInfo {
    public let currentStreamId: String?
    public let globalVolume: Float
    public let isGloballyMuted: Bool
    public let activeStreamsCount: Int
    public let focusMode: AudioFocusMode
}