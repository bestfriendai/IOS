//
//  MultiStreamAudioManager.swift
//  StreamyyyApp
//
//  Advanced audio management system for handling multiple simultaneous streams
//  Provides intelligent audio mixing, ducking, and focus management
//  Created by Claude Code on 2025-07-11
//

import Foundation
import AVFAudio
import Combine

/// Advanced audio manager for multi-stream environments
/// Handles audio mixing, ducking, focus management, and hardware controls
@MainActor
public final class MultiStreamAudioManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    public static let shared = MultiStreamAudioManager()
    
    // MARK: - Published Properties
    @Published public var masterVolume: Float = 1.0
    @Published public var isDuckingEnabled = true
    @Published public var focusedStreamId: String?
    @Published public var audioRouteDescription = ""
    @Published public var isUsingBluetoothAudio = false
    @Published public var isUsingAirPlay = false
    
    // MARK: - Private Properties
    private var audioSession: AVAudioSession = .sharedInstance()
    private var streamVolumes: [String: Float] = [:]
    private var streamMutedStates: [String: Bool] = [:]
    private var activeStreams: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    
    // Audio mixing settings
    private let maxSimultaneousStreams = 4
    private let focusedStreamVolumeBoost: Float = 0.2
    private let backgroundStreamVolumeReduction: Float = 0.3
    private let duckingVolumeReduction: Float = 0.5
    
    // Timers and state
    private var volumeUpdateTimer: Timer?
    private var audioRouteMonitorTimer: Timer?
    private var isDucking = false
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
        startMonitoring()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Interface
    
    /// Register a new stream for audio management
    public func registerStream(_ streamId: String, initialVolume: Float = 1.0) {
        print("🔊 Registering stream for audio management: \(streamId)")
        
        activeStreams.insert(streamId)
        streamVolumes[streamId] = initialVolume
        streamMutedStates[streamId] = false
        
        // Adjust volumes for existing streams
        rebalanceAudioLevels()
        
        // Set focus to first stream if none focused
        if focusedStreamId == nil {
            setFocusedStream(streamId)
        }
    }
    
    /// Unregister a stream from audio management
    public func unregisterStream(_ streamId: String) {
        print("🔇 Unregistering stream from audio management: \(streamId)")
        
        activeStreams.remove(streamId)
        streamVolumes.removeValue(forKey: streamId)
        streamMutedStates.removeValue(forKey: streamId)
        
        // Clear focus if this was the focused stream
        if focusedStreamId == streamId {
            focusedStreamId = activeStreams.first
        }
        
        // Rebalance remaining streams
        rebalanceAudioLevels()
    }
    
    /// Set the volume for a specific stream
    public func setStreamVolume(_ streamId: String, volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        streamVolumes[streamId] = clampedVolume
        
        // Apply the volume with current mixing rules
        applyStreamVolume(streamId)
    }
    
    /// Get the current volume for a stream
    public func getStreamVolume(_ streamId: String) -> Float {
        return streamVolumes[streamId] ?? 1.0
    }
    
    /// Mute or unmute a specific stream
    public func setStreamMuted(_ streamId: String, muted: Bool) {
        streamMutedStates[streamId] = muted
        applyStreamVolume(streamId)
        
        print("🔊 Stream \(streamId) \(muted ? "muted" : "unmuted")")
    }
    
    /// Check if a stream is muted
    public func isStreamMuted(_ streamId: String) -> Bool {
        return streamMutedStates[streamId] ?? false
    }
    
    /// Set which stream should have audio focus
    public func setFocusedStream(_ streamId: String?) {
        guard activeStreams.contains(streamId ?? "") || streamId == nil else { return }
        
        let previousFocus = focusedStreamId
        focusedStreamId = streamId
        
        print("🎯 Audio focus changed from \(previousFocus ?? "none") to \(streamId ?? "none")")
        
        // Rebalance all stream volumes
        rebalanceAudioLevels()
    }
    
    /// Set master volume for all streams
    public func setMasterVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        masterVolume = clampedVolume
        
        // Apply to all active streams
        rebalanceAudioLevels()
    }
    
    /// Mute all streams
    public func muteAllStreams() {
        for streamId in activeStreams {
            setStreamMuted(streamId, muted: true)
        }
    }
    
    /// Unmute all streams
    public func unmuteAllStreams() {
        for streamId in activeStreams {
            setStreamMuted(streamId, muted: false)
        }
    }
    
    /// Get optimal volume for a new stream based on current load
    public func getOptimalVolumeForNewStream() -> Float {
        let streamCount = activeStreams.count
        
        switch streamCount {
        case 0: return 1.0
        case 1: return 0.8
        case 2: return 0.6
        case 3: return 0.5
        default: return 0.4
        }
    }
    
    /// Toggle audio ducking when switching apps or receiving calls
    public func setDuckingEnabled(_ enabled: Bool) {
        isDuckingEnabled = enabled
        
        if !enabled && isDucking {
            // Restore volumes if ducking is disabled
            restoreFromDucking()
        }
    }
    
    /// Handle hardware volume controls
    public func handleVolumeButtonPress(increase: Bool) {
        if let focusedStreamId = focusedStreamId {
            // Adjust focused stream volume
            let currentVolume = getStreamVolume(focusedStreamId)
            let newVolume = increase ? 
                min(1.0, currentVolume + 0.1) : 
                max(0.0, currentVolume - 0.1)
            setStreamVolume(focusedStreamId, volume: newVolume)
        } else {
            // Adjust master volume
            let newVolume = increase ? 
                min(1.0, masterVolume + 0.1) : 
                max(0.0, masterVolume - 0.1)
            setMasterVolume(newVolume)
        }
    }
    
    /// Get current audio route information
    public func getAudioRouteInfo() -> AudioRouteInfo {
        let route = audioSession.currentRoute
        let outputs = route.outputs.map { $0.portName }.joined(separator: ", ")
        let inputs = route.inputs.map { $0.portName }.joined(separator: ", ")
        
        return AudioRouteInfo(
            outputs: outputs,
            inputs: inputs,
            isBluetoothOutput: route.outputs.contains { $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP },
            isAirPlayOutput: route.outputs.contains { $0.portType == .airPlay },
            isWiredHeadphones: route.outputs.contains { $0.portType == .headphones },
            isSpeaker: route.outputs.contains { $0.portType == .builtInSpeaker }
        )
    }
}

// MARK: - Private Implementation
extension MultiStreamAudioManager {
    
    private func setupAudioSession() {
        do {
            // Configure audio session for multi-stream playback
            try audioSession.setCategory(.playback, mode: .default, options: [
                .allowBluetooth,
                .allowBluetoothA2DP,
                .allowAirPlay,
                .defaultToSpeaker,
                .mixWithOthers // Allow multiple audio sources
            ])
            
            try audioSession.setActive(true)
            
            print("✅ Audio session configured for multi-stream playback")
            
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        // Audio session interruption handling
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
            .store(in: &cancellables)
        
        // Audio route change handling
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)
        
        // App lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func startMonitoring() {
        // Monitor volume levels periodically
        volumeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateVolumeDisplay()
        }
        
        // Monitor audio route changes
        audioRouteMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAudioRouteInfo()
        }
    }
    
    private func rebalanceAudioLevels() {
        let streamCount = activeStreams.count
        guard streamCount > 0 else { return }
        
        print("🎚️ Rebalancing audio levels for \(streamCount) streams")
        
        for streamId in activeStreams {
            applyStreamVolume(streamId)
        }
    }
    
    private func applyStreamVolume(_ streamId: String) {
        guard let baseVolume = streamVolumes[streamId] else { return }
        let isMuted = streamMutedStates[streamId] ?? false
        
        // Start with base volume
        var finalVolume: Float = baseVolume * masterVolume
        
        // Apply mute
        if isMuted {
            finalVolume = 0.0
        } else {
            // Apply focus boost/reduction
            if let focusedStreamId = focusedStreamId {
                if streamId == focusedStreamId {
                    // Boost focused stream
                    finalVolume = min(1.0, finalVolume + focusedStreamVolumeBoost)
                } else {
                    // Reduce background streams
                    finalVolume *= (1.0 - backgroundStreamVolumeReduction)
                }
            }
            
            // Apply multi-stream volume reduction
            let streamCount = activeStreams.count
            if streamCount > 1 {
                let reductionFactor = 1.0 / sqrt(Float(streamCount))
                finalVolume *= reductionFactor
            }
            
            // Apply ducking if active
            if isDucking && isDuckingEnabled {
                finalVolume *= (1.0 - duckingVolumeReduction)
            }
        }
        
        // Notify the stream player to update its volume
        NotificationCenter.default.post(
            name: .streamVolumeChanged,
            object: nil,
            userInfo: [
                "streamId": streamId,
                "volume": finalVolume
            ]
        )
    }
    
    private func updateVolumeDisplay() {
        // Update UI-related volume information
        DispatchQueue.main.async { [weak self] in
            // Trigger UI updates if needed
            self?.objectWillChange.send()
        }
    }
    
    private func updateAudioRouteInfo() {
        let routeInfo = getAudioRouteInfo()
        
        DispatchQueue.main.async { [weak self] in
            self?.audioRouteDescription = routeInfo.outputs
            self?.isUsingBluetoothAudio = routeInfo.isBluetoothOutput
            self?.isUsingAirPlay = routeInfo.isAirPlayOutput
        }
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔇 Audio interruption began - ducking streams")
            startDucking()
            
        case .ended:
            print("🔊 Audio interruption ended - restoring streams")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    restoreFromDucking()
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🎧 Audio route changed: \(reason)")
        
        switch reason {
        case .newDeviceAvailable:
            print("📱 New audio device connected")
            
        case .oldDeviceUnavailable:
            print("📱 Audio device disconnected - pausing streams")
            // Optionally pause streams when headphones are disconnected
            pauseAllStreamsForRouteChange()
            
        case .categoryChange, .override:
            // Reconfigure session if needed
            setupAudioSession()
            
        default:
            break
        }
        
        // Update route information
        updateAudioRouteInfo()
    }
    
    private func handleAppDidEnterBackground() {
        print("📱 App entered background - enabling audio ducking")
        
        // Allow background audio playback
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [
                .allowBluetooth,
                .allowBluetoothA2DP,
                .allowAirPlay,
                .mixWithOthers
            ])
        } catch {
            print("❌ Failed to update audio session for background: \(error)")
        }
    }
    
    private func handleAppWillEnterForeground() {
        print("📱 App entering foreground - restoring audio settings")
        setupAudioSession()
        rebalanceAudioLevels()
    }
    
    private func startDucking() {
        guard isDuckingEnabled && !isDucking else { return }
        
        isDucking = true
        rebalanceAudioLevels()
    }
    
    private func restoreFromDucking() {
        guard isDucking else { return }
        
        isDucking = false
        rebalanceAudioLevels()
    }
    
    private func pauseAllStreamsForRouteChange() {
        // Notify all streams to pause
        NotificationCenter.default.post(
            name: .pauseAllStreamsForRouteChange,
            object: nil
        )
    }
    
    private func cleanup() {
        volumeUpdateTimer?.invalidate()
        audioRouteMonitorTimer?.invalidate()
        cancellables.removeAll()
        
        // Deactivate audio session
        try? audioSession.setActive(false)
    }
}

// MARK: - Supporting Types
public struct AudioRouteInfo {
    public let outputs: String
    public let inputs: String
    public let isBluetoothOutput: Bool
    public let isAirPlayOutput: Bool
    public let isWiredHeadphones: Bool
    public let isSpeaker: Bool
}

// MARK: - Notification Names
extension Notification.Name {
    static let streamVolumeChanged = Notification.Name("streamVolumeChanged")
    static let pauseAllStreamsForRouteChange = Notification.Name("pauseAllStreamsForRouteChange")
}

// MARK: - Audio Session Extensions
extension AVAudioSession.RouteChangeReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .newDeviceAvailable: return "New Device Available"
        case .oldDeviceUnavailable: return "Old Device Unavailable"
        case .categoryChange: return "Category Change"
        case .override: return "Override"
        case .wakeFromSleep: return "Wake From Sleep"
        case .noSuitableRouteForCategory: return "No Suitable Route"
        case .routeConfigurationChange: return "Route Configuration Change"
        @unknown default: return "Unknown Reason"
        }
    }
}