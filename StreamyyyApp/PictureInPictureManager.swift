//
//  PictureInPictureManager.swift
//  StreamyyyApp
//
//  Created by Claude on 2025-07-09.
//  Copyright © 2025 Streamyyy. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation
import UIKit
import SwiftUI
import Combine

/// Manager for Picture-in-Picture functionality using AVKit
@MainActor
final class PictureInPictureManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isPictureInPictureActive = false
    @Published var isPictureInPictureSupported = false
    @Published var isPictureInPicturePossible = false
    @Published var isStreamPlaying = false
    @Published var currentStreamTitle = ""
    @Published var error: PiPError?
    
    // MARK: - Private Properties
    private var pipController: AVPictureInPictureController?
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var contentSourceView: UIView?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupPictureInPicture()
        setupNotifications()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup Methods
    private func setupPictureInPicture() {
        // Check if PiP is supported on the device
        isPictureInPictureSupported = AVPictureInPictureController.isPictureInPictureSupported()
        
        guard isPictureInPictureSupported else {
            error = .notSupported
            return
        }
        
        // Configure audio session for PiP
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            self.error = .audioSessionError(error)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Configure PiP for a stream with URL
    func configureForStream(url: URL, title: String, in containerView: UIView) {
        currentStreamTitle = title
        
        // Clean up previous setup
        cleanup()
        
        // Create player
        player = AVPlayer(url: url)
        
        // Create player layer
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = containerView.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        containerView.layer.addSublayer(playerLayer!)
        
        // Store reference to container view
        contentSourceView = containerView
        
        // Create PiP controller
        setupPiPController()
        
        // Start playing
        player?.play()
        isStreamPlaying = true
        
        // Monitor player status
        monitorPlayerStatus()
    }
    
    /// Configure PiP for a stream with AVPlayerItem
    func configureForStream(playerItem: AVPlayerItem, title: String, in containerView: UIView) {
        currentStreamTitle = title
        
        // Clean up previous setup
        cleanup()
        
        // Create player
        player = AVPlayer(playerItem: playerItem)
        
        // Create player layer
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = containerView.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        containerView.layer.addSublayer(playerLayer!)
        
        // Store reference to container view
        contentSourceView = containerView
        
        // Create PiP controller
        setupPiPController()
        
        // Start playing
        player?.play()
        isStreamPlaying = true
        
        // Monitor player status
        monitorPlayerStatus()
    }
    
    /// Start Picture-in-Picture
    func startPictureInPicture() {
        guard isPictureInPictureSupported,
              let pipController = pipController,
              pipController.isPictureInPicturePossible else {
            error = .notPossible
            return
        }
        
        // Start background task to keep app alive during PiP
        startBackgroundTask()
        
        pipController.startPictureInPicture()
    }
    
    /// Stop Picture-in-Picture
    func stopPictureInPicture() {
        guard let pipController = pipController else { return }
        
        pipController.stopPictureInPicture()
        endBackgroundTask()
    }
    
    /// Pause the stream
    func pauseStream() {
        player?.pause()
        isStreamPlaying = false
    }
    
    /// Resume the stream
    func resumeStream() {
        player?.play()
        isStreamPlaying = true
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        if isStreamPlaying {
            pauseStream()
        } else {
            resumeStream()
        }
    }
    
    /// Get current stream time
    func getCurrentTime() -> CMTime {
        return player?.currentTime() ?? .zero
    }
    
    /// Seek to specific time
    func seek(to time: CMTime) {
        player?.seek(to: time)
    }
    
    // MARK: - Private Methods
    
    private func setupPiPController() {
        guard let playerLayer = playerLayer else { return }
        
        // Create PiP controller
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        
        // Configure PiP controller
        if #available(iOS 14.2, *) {
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        
        // Update PiP possibility
        isPictureInPicturePossible = pipController?.isPictureInPicturePossible ?? false
        
        // Observe PiP possibility changes
        pipController?.publisher(for: \.isPictureInPicturePossible)
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPictureInPicturePossible, on: self)
            .store(in: &cancellables)
    }
    
    private func monitorPlayerStatus() {
        guard let player = player else { return }
        
        // Monitor player status
        player.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.error = nil
                case .failed:
                    self?.error = .playerFailed(player.error)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Monitor player time
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
            // Update UI or handle time changes if needed
        }
    }
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func cleanup() {
        // Stop PiP if active
        if isPictureInPictureActive {
            stopPictureInPicture()
        }
        
        // Clean up player
        player?.pause()
        player = nil
        
        // Clean up player layer
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        
        // Clean up PiP controller
        pipController?.delegate = nil
        pipController = nil
        
        // Cancel subscriptions
        cancellables.removeAll()
        
        // End background task
        endBackgroundTask()
        
        // Reset states
        isPictureInPictureActive = false
        isPictureInPicturePossible = false
        isStreamPlaying = false
        currentStreamTitle = ""
        error = nil
    }
    
    // MARK: - Notification Handlers
    
    @objc private func applicationDidEnterBackground() {
        // Automatically start PiP when app enters background
        if isPictureInPicturePossible && isStreamPlaying {
            startPictureInPicture()
        }
    }
    
    @objc private func applicationWillEnterForeground() {
        // Handle app returning to foreground
        if isPictureInPictureActive {
            // Optionally stop PiP when returning to foreground
            // stopPictureInPicture()
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PictureInPictureManager: AVPictureInPictureControllerDelegate {
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Called when PiP is about to start
        isPictureInPictureActive = true
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Called when PiP has started
        print("Picture-in-Picture started for stream: \(currentStreamTitle)")
        
        // Analytics tracking
        trackPiPEvent("pip_started")
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Called when PiP is about to stop
        isPictureInPictureActive = false
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Called when PiP has stopped
        print("Picture-in-Picture stopped for stream: \(currentStreamTitle)")
        
        // End background task
        endBackgroundTask()
        
        // Analytics tracking
        trackPiPEvent("pip_stopped")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        // Called when PiP failed to start
        self.error = .startFailed(error)
        isPictureInPictureActive = false
        
        // End background task
        endBackgroundTask()
        
        // Analytics tracking
        trackPiPEvent("pip_start_failed")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // Called when user taps the PiP window to restore the app
        
        // Restore the user interface
        // This is where you would navigate back to the stream view
        restoreUserInterface { success in
            completionHandler(success)
        }
    }
    
    private func restoreUserInterface(completion: @escaping (Bool) -> Void) {
        // Implement logic to restore the user interface
        // This might involve navigating to the stream view
        
        // For now, just complete successfully
        DispatchQueue.main.async {
            completion(true)
        }
    }
    
    private func trackPiPEvent(_ event: String) {
        // Implement analytics tracking
        // This could integrate with your existing analytics system
        print("PiP Event: \(event) for stream: \(currentStreamTitle)")
    }
}

// MARK: - Error Types

enum PiPError: Error, LocalizedError {
    case notSupported
    case notPossible
    case audioSessionError(Error)
    case playerFailed(Error?)
    case startFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Picture-in-Picture is not supported on this device"
        case .notPossible:
            return "Picture-in-Picture is not currently possible"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        case .playerFailed(let error):
            return "Player failed: \(error?.localizedDescription ?? "Unknown error")"
        case .startFailed(let error):
            return "Failed to start Picture-in-Picture: \(error.localizedDescription)"
        }
    }
}

// MARK: - SwiftUI Integration

struct PictureInPictureView: UIViewRepresentable {
    let streamURL: URL
    let title: String
    @ObservedObject var pipManager: PictureInPictureManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        pipManager.configureForStream(url: streamURL, title: title, in: uiView)
    }
}

// MARK: - Accessibility Support

extension PictureInPictureManager {
    
    /// Configure accessibility for PiP controls
    func configureAccessibility() {
        // Add accessibility labels and hints for PiP controls
        // This would be implemented in the UI layer
    }
    
    /// Announce PiP status changes for VoiceOver users
    private func announceAccessibilityStatus(_ message: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

// MARK: - iOS Version Compatibility

extension PictureInPictureManager {
    
    /// Check if advanced PiP features are available
    var isAdvancedPiPAvailable: Bool {
        if #available(iOS 14.2, *) {
            return true
        }
        return false
    }
    
    /// Configure iOS version-specific features
    private func configureVersionSpecificFeatures() {
        guard let pipController = pipController else { return }
        
        if #available(iOS 14.2, *) {
            pipController.canStartPictureInPictureAutomaticallyFromInline = true
        }
        
        if #available(iOS 15.0, *) {
            // iOS 15+ specific features
        }
    }
}