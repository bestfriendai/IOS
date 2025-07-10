//
//  GestureHandler.swift
//  StreamyyyApp
//
//  Handle touch gestures for drag-and-drop, pinch-to-zoom, and stream reordering
//

import Foundation
import SwiftUI
import Combine

@MainActor
public class GestureHandler: ObservableObject {
    // MARK: - Published Properties
    @Published public var isDragging: Bool = false
    @Published public var isZooming: Bool = false
    @Published public var draggedStream: Stream?
    @Published public var dragOffset: CGSize = .zero
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var lastTapTime: Date = Date()
    @Published public var tapCount: Int = 0
    
    // MARK: - Private Properties
    private let layoutManager: MultiStreamLayoutManager
    private let audioManager: AudioManager
    private var tapTimer: Timer?
    private var longPressTimer: Timer?
    private var dragStartPosition: CGPoint = .zero
    private var zoomStartScale: CGFloat = 1.0
    private var velocityTracker: VelocityTracker = VelocityTracker()
    
    // MARK: - Gesture Configuration
    private let doubleTapTimeThreshold: TimeInterval = 0.5
    private let longPressTimeThreshold: TimeInterval = 0.5
    private let minimumDragDistance: CGFloat = 10.0
    private let minimumZoomScale: CGFloat = 0.5
    private let maximumZoomScale: CGFloat = 3.0
    private let snapBackAnimationDuration: TimeInterval = 0.3
    private let elasticBounceAnimationDuration: TimeInterval = 0.6
    
    // MARK: - Initialization
    public init(layoutManager: MultiStreamLayoutManager, audioManager: AudioManager) {
        self.layoutManager = layoutManager
        self.audioManager = audioManager
    }
    
    // MARK: - Tap Gestures
    
    /// Handle single tap on stream
    public func handleStreamTap(_ stream: Stream, at location: CGPoint) {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < doubleTapTimeThreshold {
            tapCount += 1
        } else {
            tapCount = 1
        }
        
        lastTapTime = now
        
        // Cancel existing timer
        tapTimer?.invalidate()
        
        // Start new timer
        tapTimer = Timer.scheduledTimer(withTimeInterval: doubleTapTimeThreshold, repeats: false) { [weak self] _ in
            self?.processTapGesture(stream, tapCount: self?.tapCount ?? 1, at: location)
        }
    }
    
    /// Handle long press on stream
    public func handleStreamLongPress(_ stream: Stream, at location: CGPoint) {
        // Start long press timer
        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressTimeThreshold, repeats: false) { [weak self] _ in
            self?.processLongPressGesture(stream, at: location)
        }
    }
    
    /// Cancel long press timer
    public func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    // MARK: - Drag Gestures
    
    /// Handle drag gesture start
    public func handleDragStart(_ stream: Stream, at location: CGPoint) {
        isDragging = true
        draggedStream = stream
        dragStartPosition = location
        dragOffset = .zero
        
        // Cancel long press if active
        cancelLongPress()
        
        // Start velocity tracking
        velocityTracker.startTracking(at: location)
        
        // Bring stream to front
        layoutManager.handleDragGesture(for: stream, translation: .zero)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// Handle drag gesture change
    public func handleDragChange(_ stream: Stream, translation: CGSize) {
        guard isDragging, draggedStream?.id == stream.id else { return }
        
        dragOffset = translation
        
        // Update velocity tracking
        let currentLocation = CGPoint(
            x: dragStartPosition.x + translation.width,
            y: dragStartPosition.y + translation.height
        )
        velocityTracker.updateTracking(at: currentLocation)
        
        // Update layout manager
        layoutManager.handleDragGesture(for: stream, translation: translation)
        
        // Check for snap zones or magnetic effects
        checkSnapZones(for: stream, at: currentLocation)
    }
    
    /// Handle drag gesture end
    public func handleDragEnd(_ stream: Stream) {
        guard isDragging, draggedStream?.id == stream.id else { return }
        
        let velocity = velocityTracker.finalVelocity
        
        // Handle momentum scrolling or snapping
        if abs(velocity.x) > 100 || abs(velocity.y) > 100 {
            animateWithMomentum(stream, velocity: velocity)
        } else {
            // Snap to grid or validate position
            layoutManager.handleDragEnd(for: stream)
        }
        
        // Reset drag state
        isDragging = false
        draggedStream = nil
        dragOffset = .zero
        
        // Stop velocity tracking
        velocityTracker.stopTracking()
    }
    
    // MARK: - Zoom Gestures
    
    /// Handle zoom gesture start
    public func handleZoomStart(_ stream: Stream, scale: CGFloat) {
        isZooming = true
        zoomStartScale = scale
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// Handle zoom gesture change
    public func handleZoomChange(_ stream: Stream, scale: CGFloat) {
        guard isZooming else { return }
        
        let constrainedScale = max(minimumZoomScale, min(maximumZoomScale, scale))
        zoomScale = constrainedScale
        
        // Update layout manager
        layoutManager.handlePinchGesture(for: stream, scale: constrainedScale)
        
        // Provide elastic feedback at limits
        if scale < minimumZoomScale || scale > maximumZoomScale {
            let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
            impactFeedback.impactOccurred()
        }
    }
    
    /// Handle zoom gesture end
    public func handleZoomEnd(_ stream: Stream) {
        guard isZooming else { return }
        
        // Animate back to valid scale if needed
        if zoomScale < minimumZoomScale {
            animateScaleBack(stream, to: minimumZoomScale)
        } else if zoomScale > maximumZoomScale {
            animateScaleBack(stream, to: maximumZoomScale)
        }
        
        isZooming = false
        zoomScale = 1.0
    }
    
    // MARK: - Rotation Gestures
    
    /// Handle rotation gesture (if enabled)
    public func handleRotation(_ stream: Stream, angle: Angle) {
        // Rotation handling could be added here if needed
        // For now, we'll keep streams in standard orientation
    }
    
    // MARK: - Compound Gestures
    
    /// Handle simultaneous zoom and drag
    public func handleSimultaneousZoomAndDrag(_ stream: Stream, translation: CGSize, scale: CGFloat) {
        // Handle both gestures simultaneously
        handleDragChange(stream, translation: translation)
        handleZoomChange(stream, scale: scale)
    }
    
    // MARK: - Container Gestures
    
    /// Handle tap on empty container area
    public func handleContainerTap(at location: CGPoint) {
        // Hide controls in fullscreen mode
        if layoutManager.isFullscreen {
            layoutManager.handleContainerTap()
        }
    }
    
    /// Handle double tap on container
    public func handleContainerDoubleTap(at location: CGPoint) {
        // Could be used for creating new streams or other actions
    }
    
    // MARK: - Private Methods
    
    private func processTapGesture(_ stream: Stream, tapCount: Int, at location: CGPoint) {
        switch tapCount {
        case 1:
            handleSingleTap(stream, at: location)
        case 2:
            handleDoubleTap(stream, at: location)
        default:
            break
        }
    }
    
    private func handleSingleTap(_ stream: Stream, at location: CGPoint) {
        // Focus on stream and switch audio
        layoutManager.focusStream(stream)
        audioManager.switchAudioTo(stream)
        
        // Haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func handleDoubleTap(_ stream: Stream, at location: CGPoint) {
        // Toggle fullscreen mode
        layoutManager.toggleFullscreen(for: stream)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    private func processLongPressGesture(_ stream: Stream, at location: CGPoint) {
        // Show context menu or enter edit mode
        showContextMenu(for: stream, at: location)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    private func showContextMenu(for stream: Stream, at location: CGPoint) {
        // This would trigger a context menu or options overlay
        // Implementation depends on the UI framework being used
    }
    
    private func checkSnapZones(for stream: Stream, at location: CGPoint) {
        // Check if stream is near snap zones (edges, other streams, etc.)
        let streamBounds = layoutManager.getStreamBounds(stream)
        let containerBounds = CGRect(origin: .zero, size: layoutManager.containerSize)
        
        // Edge snapping
        let snapDistance: CGFloat = 20.0
        
        if abs(streamBounds.minX - containerBounds.minX) < snapDistance {
            // Snap to left edge
            provideMagneticFeedback()
        } else if abs(streamBounds.maxX - containerBounds.maxX) < snapDistance {
            // Snap to right edge
            provideMagneticFeedback()
        }
        
        if abs(streamBounds.minY - containerBounds.minY) < snapDistance {
            // Snap to top edge
            provideMagneticFeedback()
        } else if abs(streamBounds.maxY - containerBounds.maxY) < snapDistance {
            // Snap to bottom edge
            provideMagneticFeedback()
        }
        
        // Stream-to-stream snapping
        for activeStream in layoutManager.activeStreams {
            guard activeStream.id != stream.id else { continue }
            
            let otherBounds = layoutManager.getStreamBounds(activeStream)
            
            if abs(streamBounds.minX - otherBounds.maxX) < snapDistance ||
               abs(streamBounds.maxX - otherBounds.minX) < snapDistance ||
               abs(streamBounds.minY - otherBounds.maxY) < snapDistance ||
               abs(streamBounds.maxY - otherBounds.minY) < snapDistance {
                provideMagneticFeedback()
            }
        }
    }
    
    private func provideMagneticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func animateWithMomentum(_ stream: Stream, velocity: CGPoint) {
        // Calculate momentum animation
        let friction: CGFloat = 0.95
        let minimumVelocity: CGFloat = 10.0
        
        var currentVelocity = velocity
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Apply friction
            currentVelocity.x *= friction
            currentVelocity.y *= friction
            
            // Update position
            let translation = CGSize(width: currentVelocity.x * 0.016, height: currentVelocity.y * 0.016)
            self.layoutManager.handleDragGesture(for: stream, translation: translation)
            
            // Stop when velocity is too low
            if abs(currentVelocity.x) < minimumVelocity && abs(currentVelocity.y) < minimumVelocity {
                timer.invalidate()
                self.layoutManager.handleDragEnd(for: stream)
            }
        }
    }
    
    private func animateScaleBack(_ stream: Stream, to targetScale: CGFloat) {
        let animationDuration: TimeInterval = 0.3
        let steps = 20
        let stepDuration = animationDuration / Double(steps)
        
        let startScale = zoomScale
        let scaleDifference = targetScale - startScale
        
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = CGFloat(currentStep) / CGFloat(steps)
            
            // Ease-out animation
            let easedProgress = 1.0 - pow(1.0 - progress, 3.0)
            let currentScale = startScale + (scaleDifference * easedProgress)
            
            self?.layoutManager.handlePinchGesture(for: stream, scale: currentScale)
            
            if currentStep >= steps {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Velocity Tracker
private class VelocityTracker {
    private var positions: [(point: CGPoint, time: Date)] = []
    private let maxTrackingPoints = 10
    
    func startTracking(at point: CGPoint) {
        positions.removeAll()
        positions.append((point: point, time: Date()))
    }
    
    func updateTracking(at point: CGPoint) {
        positions.append((point: point, time: Date()))
        
        // Keep only recent points
        if positions.count > maxTrackingPoints {
            positions.removeFirst()
        }
    }
    
    func stopTracking() {
        // Keep the positions for final velocity calculation
    }
    
    var finalVelocity: CGPoint {
        guard positions.count >= 2 else { return .zero }
        
        let recent = positions.suffix(3) // Use last 3 points
        guard recent.count >= 2 else { return .zero }
        
        let first = recent.first!
        let last = recent.last!
        
        let timeDiff = last.time.timeIntervalSince(first.time)
        guard timeDiff > 0 else { return .zero }
        
        let dx = last.point.x - first.point.x
        let dy = last.point.y - first.point.y
        
        return CGPoint(x: dx / timeDiff, y: dy / timeDiff)
    }
}

// MARK: - Gesture Configuration
public struct GestureConfiguration {
    public var doubleTapEnabled: Bool = true
    public var longPressEnabled: Bool = true
    public var dragEnabled: Bool = true
    public var zoomEnabled: Bool = true
    public var rotationEnabled: Bool = false
    public var simultaneousGesturesEnabled: Bool = true
    public var hapticFeedbackEnabled: Bool = true
    public var magneticSnappingEnabled: Bool = true
    public var elasticBounceEnabled: Bool = true
    
    public init() {}
}

// MARK: - Gesture Extensions
extension GestureHandler {
    
    /// Update gesture configuration
    public func updateConfiguration(_ config: GestureConfiguration) {
        // Update internal configuration based on provided settings
    }
    
    /// Get current gesture state
    public func getCurrentGestureState() -> GestureState {
        return GestureState(
            isDragging: isDragging,
            isZooming: isZooming,
            draggedStreamId: draggedStream?.id,
            dragOffset: dragOffset,
            zoomScale: zoomScale
        )
    }
    
    /// Check if gestures are enabled for a stream
    public func areGesturesEnabled(for stream: Stream) -> Bool {
        // Check if gestures are enabled based on stream state, layout, etc.
        return !layoutManager.isFullscreen || layoutManager.focusedStream?.id == stream.id
    }
}

// MARK: - Gesture State
public struct GestureState {
    public let isDragging: Bool
    public let isZooming: Bool
    public let draggedStreamId: String?
    public let dragOffset: CGSize
    public let zoomScale: CGFloat
}