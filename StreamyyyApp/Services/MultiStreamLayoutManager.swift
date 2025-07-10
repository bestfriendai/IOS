//
//  MultiStreamLayoutManager.swift
//  StreamyyyApp
//
//  Centralized manager for handling multiple stream layouts, positioning, and coordination
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
public class MultiStreamLayoutManager: ObservableObject {
    // MARK: - Published Properties
    @Published public var currentLayout: Layout?
    @Published public var activeStreams: [Stream] = []
    @Published public var streamPositions: [String: StreamPosition] = [:]
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var draggingStream: Stream?
    @Published public var dragOffset: CGSize = .zero
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var focusedStream: Stream?
    @Published public var isFullscreen = false
    @Published public var showingControls = true
    @Published public var containerSize: CGSize = .zero
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    private let audioManager: AudioManager
    private var layoutUpdateTimer: Timer?
    private var controlsHideTimer: Timer?
    private let maxConcurrentStreams = 16
    private let minStreamSize = CGSize(width: 100, height: 75)
    private let maxStreamSize = CGSize(width: 800, height: 600)
    
    // MARK: - Initialization
    public init(audioManager: AudioManager) {
        self.audioManager = audioManager
        setupBindings()
    }
    
    // MARK: - Setup Methods
    public func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    /// Set the current layout and update stream positions
    public func setLayout(_ layout: Layout) {
        currentLayout = layout
        layout.recordUsage()
        
        // Save to persistence
        try? modelContext?.save()
        
        // Update stream positions based on layout
        updateStreamPositions()
        
        // Notify audio manager of layout change
        audioManager.layoutDidChange(layout)
    }
    
    /// Add a stream to the current layout
    public func addStream(_ stream: Stream) {
        guard activeStreams.count < maxConcurrentStreams else {
            error = MultiStreamError.maxStreamsExceeded
            return
        }
        
        guard let layout = currentLayout else {
            error = MultiStreamError.noLayoutSelected
            return
        }
        
        // Check if stream already exists
        guard !activeStreams.contains(where: { $0.id == stream.id }) else {
            return
        }
        
        // Calculate position for new stream
        let position = calculatePositionForNewStream(in: layout)
        streamPositions[stream.id] = position
        
        // Add to active streams
        activeStreams.append(stream)
        
        // Update layout with new stream
        layout.addStream(position: position, streamId: stream.id)
        
        // Save changes
        try? modelContext?.save()
        
        // Notify audio manager
        audioManager.streamAdded(stream)
    }
    
    /// Remove a stream from the current layout
    public func removeStream(_ stream: Stream) {
        activeStreams.removeAll { $0.id == stream.id }
        streamPositions.removeValue(forKey: stream.id)
        
        // Update layout
        currentLayout?.removeStream(streamId: stream.id)
        
        // Save changes
        try? modelContext?.save()
        
        // Notify audio manager
        audioManager.streamRemoved(stream)
        
        // Reposition remaining streams
        updateStreamPositions()
    }
    
    /// Update stream position
    public func updateStreamPosition(_ stream: Stream, to position: StreamPosition) {
        streamPositions[stream.id] = position
        stream.updatePosition(position)
        
        // Update layout
        currentLayout?.updateStreamPosition(streamId: stream.id, position: position)
        
        // Save changes
        try? modelContext?.save()
    }
    
    /// Handle drag gesture for stream reordering
    public func handleDragGesture(for stream: Stream, translation: CGSize) {
        draggingStream = stream
        dragOffset = translation
        
        // Calculate new position
        guard let currentPosition = streamPositions[stream.id] else { return }
        
        let newPosition = StreamPosition(
            x: currentPosition.x + Double(translation.x),
            y: currentPosition.y + Double(translation.y),
            width: currentPosition.width,
            height: currentPosition.height,
            zIndex: currentPosition.zIndex + 1000 // Bring to front while dragging
        )
        
        updateStreamPosition(stream, to: newPosition)
    }
    
    /// Handle end of drag gesture
    public func handleDragEnd(for stream: Stream) {
        draggingStream = nil
        dragOffset = .zero
        
        // Snap to grid if enabled
        if currentLayout?.configuration.snapToGrid == true {
            snapStreamToGrid(stream)
        }
        
        // Reset z-index
        guard let position = streamPositions[stream.id] else { return }
        let snappedPosition = StreamPosition(
            x: position.x,
            y: position.y,
            width: position.width,
            height: position.height,
            zIndex: calculateZIndexForStream(stream)
        )
        
        updateStreamPosition(stream, to: snappedPosition)
    }
    
    /// Handle pinch gesture for stream scaling
    public func handlePinchGesture(for stream: Stream, scale: CGFloat) {
        guard let currentPosition = streamPositions[stream.id] else { return }
        
        let newWidth = max(minStreamSize.width, min(maxStreamSize.width, currentPosition.width * Double(scale)))
        let newHeight = max(minStreamSize.height, min(maxStreamSize.height, currentPosition.height * Double(scale)))
        
        let newPosition = StreamPosition(
            x: currentPosition.x,
            y: currentPosition.y,
            width: newWidth,
            height: newHeight,
            zIndex: currentPosition.zIndex
        )
        
        updateStreamPosition(stream, to: newPosition)
    }
    
    /// Focus on a specific stream
    public func focusStream(_ stream: Stream) {
        focusedStream = stream
        
        // Switch audio to focused stream
        audioManager.switchAudioTo(stream)
        
        // Animate to focus layout
        if let layout = currentLayout {
            animateToFocusMode(stream: stream, layout: layout)
        }
    }
    
    /// Exit focus mode
    public func exitFocusMode() {
        focusedStream = nil
        
        // Return to normal layout
        if let layout = currentLayout {
            animateToNormalMode(layout: layout)
        }
    }
    
    /// Toggle fullscreen mode
    public func toggleFullscreen(for stream: Stream) {
        if isFullscreen && focusedStream?.id == stream.id {
            exitFullscreen()
        } else {
            enterFullscreen(stream)
        }
    }
    
    /// Enter fullscreen mode
    public func enterFullscreen(_ stream: Stream) {
        isFullscreen = true
        focusedStream = stream
        
        // Switch audio to fullscreen stream
        audioManager.switchAudioTo(stream)
        
        // Hide controls temporarily
        showingControls = false
        
        // Auto-hide controls after delay
        resetControlsTimer()
    }
    
    /// Exit fullscreen mode
    public func exitFullscreen() {
        isFullscreen = false
        focusedStream = nil
        showingControls = true
        
        // Return audio control to normal
        audioManager.exitFullscreen()
        
        // Cancel controls timer
        controlsHideTimer?.invalidate()
    }
    
    /// Update container size when view size changes
    public func updateContainerSize(_ size: CGSize) {
        containerSize = size
        updateStreamPositions()
    }
    
    /// Show/hide controls
    public func toggleControls() {
        showingControls.toggle()
        
        if showingControls {
            resetControlsTimer()
        }
    }
    
    /// Handle tap gesture on container
    public func handleContainerTap() {
        if isFullscreen {
            toggleControls()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-hide controls timer
        $showingControls
            .sink { [weak self] showing in
                if showing {
                    self?.resetControlsTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateStreamPositions() {
        guard let layout = currentLayout else { return }
        
        let positions = calculateStreamPositions(for: layout)
        
        for (streamId, position) in positions {
            streamPositions[streamId] = position
        }
    }
    
    private func calculateStreamPositions(for layout: Layout) -> [String: StreamPosition] {
        var positions: [String: StreamPosition] = [:]
        
        let config = layout.configuration
        let containerWidth = containerSize.width
        let containerHeight = containerSize.height
        
        switch layout.type {
        case .grid2x2:
            positions = calculateGridPositions(streams: activeStreams, columns: 2, rows: 2, config: config)
        case .grid3x3:
            positions = calculateGridPositions(streams: activeStreams, columns: 3, rows: 3, config: config)
        case .grid4x4:
            positions = calculateGridPositions(streams: activeStreams, columns: 4, rows: 4, config: config)
        case .stack:
            positions = calculateStackPositions(streams: activeStreams, config: config)
        case .carousel:
            positions = calculateCarouselPositions(streams: activeStreams, config: config)
        case .focus:
            positions = calculateFocusPositions(streams: activeStreams, config: config)
        case .mosaic:
            positions = calculateMosaicPositions(streams: activeStreams, config: config)
        default:
            positions = calculateDefaultPositions(streams: activeStreams, config: config)
        }
        
        return positions
    }
    
    private func calculateGridPositions(streams: [Stream], columns: Int, rows: Int, config: LayoutConfiguration) -> [String: StreamPosition] {
        var positions: [String: StreamPosition] = [:]
        
        let spacing = config.spacing
        let padding = config.padding
        let availableWidth = containerSize.width - padding.leading - padding.trailing
        let availableHeight = containerSize.height - padding.top - padding.bottom
        
        let streamWidth = (availableWidth - (Double(columns - 1) * spacing)) / Double(columns)
        let streamHeight = (availableHeight - (Double(rows - 1) * spacing)) / Double(rows)
        
        for (index, stream) in streams.enumerated() {
            let column = index % columns
            let row = index / columns
            
            if row >= rows { break } // Don't exceed grid bounds
            
            let x = padding.leading + (Double(column) * (streamWidth + spacing))
            let y = padding.top + (Double(row) * (streamHeight + spacing))
            
            positions[stream.id] = StreamPosition(
                x: x,
                y: y,
                width: streamWidth,
                height: streamHeight,
                zIndex: index
            )
        }
        
        return positions
    }
    
    private func calculateStackPositions(streams: [Stream], config: LayoutConfiguration) -> [String: StreamPosition] {
        var positions: [String: StreamPosition] = [:]
        
        let spacing = config.spacing
        let padding = config.padding
        let availableWidth = containerSize.width - padding.leading - padding.trailing
        let availableHeight = containerSize.height - padding.top - padding.bottom
        
        let streamHeight = (availableHeight - (Double(streams.count - 1) * spacing)) / Double(streams.count)
        let streamWidth = availableWidth
        
        for (index, stream) in streams.enumerated() {
            let y = padding.top + (Double(index) * (streamHeight + spacing))
            
            positions[stream.id] = StreamPosition(
                x: padding.leading,
                y: y,
                width: streamWidth,
                height: streamHeight,
                zIndex: index
            )
        }
        
        return positions
    }
    
    private func calculateCarouselPositions(streams: [Stream], config: LayoutConfiguration) -> [String: StreamPosition] {
        var positions: [String: StreamPosition] = [:]
        
        let spacing = config.spacing
        let padding = config.padding
        let availableWidth = containerSize.width - padding.leading - padding.trailing
        let availableHeight = containerSize.height - padding.top - padding.bottom
        
        let streamWidth = min(config.minStreamSize.width, availableWidth / 3)
        let streamHeight = availableHeight
        
        for (index, stream) in streams.enumerated() {
            let x = padding.leading + (Double(index) * (streamWidth + spacing))
            
            positions[stream.id] = StreamPosition(
                x: x,
                y: padding.top,
                width: streamWidth,
                height: streamHeight,
                zIndex: index
            )
        }
        
        return positions
    }
    
    private func calculateFocusPositions(streams: [Stream], config: LayoutConfiguration) -> [String: StreamPosition] {
        var positions: [String: StreamPosition] = [:]
        
        guard let mainStream = focusedStream ?? streams.first else { return positions }
        
        let spacing = config.spacing
        let padding = config.padding
        let availableWidth = containerSize.width - padding.leading - padding.trailing
        let availableHeight = containerSize.height - padding.top - padding.bottom
        
        // Main stream takes most of the space
        let mainWidth = availableWidth * 0.7
        let mainHeight = availableHeight
        
        positions[mainStream.id] = StreamPosition(
            x: padding.leading,
            y: padding.top,
            width: mainWidth,
            height: mainHeight,
            zIndex: 1000
        )
        
        // Other streams as thumbnails
        let thumbnailWidth = availableWidth * 0.25
        let thumbnailHeight = thumbnailWidth * 9 / 16 // 16:9 aspect ratio
        let thumbnailStartX = padding.leading + mainWidth + spacing
        
        let otherStreams = streams.filter { $0.id != mainStream.id }
        for (index, stream) in otherStreams.enumerated() {
            let y = padding.top + (Double(index) * (thumbnailHeight + spacing))
            
            positions[stream.id] = StreamPosition(
                x: thumbnailStartX,
                y: y,
                width: thumbnailWidth,
                height: thumbnailHeight,
                zIndex: index
            )
        }
        
        return positions
    }
    
    private func calculateMosaicPositions(streams: [Stream], config: LayoutConfiguration) -> [String: StreamPosition] {
        var positions: [String: StreamPosition] = [:]
        
        // For mosaic, use current positions if they exist, otherwise calculate initial positions
        for (index, stream) in streams.enumerated() {
            if let existingPosition = streamPositions[stream.id] {
                positions[stream.id] = existingPosition
            } else {
                let padding = config.padding
                let baseWidth = containerSize.width * 0.3
                let baseHeight = baseWidth * 9 / 16
                
                let x = padding.leading + (Double(index % 3) * (baseWidth + config.spacing))
                let y = padding.top + (Double(index / 3) * (baseHeight + config.spacing))
                
                positions[stream.id] = StreamPosition(
                    x: x,
                    y: y,
                    width: baseWidth,
                    height: baseHeight,
                    zIndex: index
                )
            }
        }
        
        return positions
    }
    
    private func calculateDefaultPositions(streams: [Stream], config: LayoutConfiguration) -> [String: StreamPosition] {
        return calculateGridPositions(streams: streams, columns: 2, rows: 2, config: config)
    }
    
    private func calculatePositionForNewStream(in layout: Layout) -> StreamPosition {
        let config = layout.configuration
        let padding = config.padding
        
        // Simple positioning for new stream
        let baseWidth = containerSize.width * 0.3
        let baseHeight = baseWidth * 9 / 16
        
        let x = padding.leading + (Double(activeStreams.count % 3) * (baseWidth + config.spacing))
        let y = padding.top + (Double(activeStreams.count / 3) * (baseHeight + config.spacing))
        
        return StreamPosition(
            x: x,
            y: y,
            width: baseWidth,
            height: baseHeight,
            zIndex: activeStreams.count
        )
    }
    
    private func snapStreamToGrid(_ stream: Stream) {
        guard let layout = currentLayout,
              let position = streamPositions[stream.id] else { return }
        
        let gridSize = layout.configuration.gridSize
        
        let snappedX = round(position.x / gridSize) * gridSize
        let snappedY = round(position.y / gridSize) * gridSize
        
        let snappedPosition = StreamPosition(
            x: snappedX,
            y: snappedY,
            width: position.width,
            height: position.height,
            zIndex: position.zIndex
        )
        
        updateStreamPosition(stream, to: snappedPosition)
    }
    
    private func calculateZIndexForStream(_ stream: Stream) -> Int {
        return activeStreams.firstIndex(where: { $0.id == stream.id }) ?? 0
    }
    
    private func animateToFocusMode(stream: Stream, layout: Layout) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            updateStreamPositions()
        }
    }
    
    private func animateToNormalMode(layout: Layout) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            updateStreamPositions()
        }
    }
    
    private func resetControlsTimer() {
        controlsHideTimer?.invalidate()
        
        if isFullscreen {
            controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self?.showingControls = false
                }
            }
        }
    }
}

// MARK: - Audio Manager Protocol
public protocol AudioManagerProtocol {
    func layoutDidChange(_ layout: Layout)
    func streamAdded(_ stream: Stream)
    func streamRemoved(_ stream: Stream)
    func switchAudioTo(_ stream: Stream)
    func exitFullscreen()
}

// MARK: - Multi-Stream Errors
public enum MultiStreamError: Error, LocalizedError {
    case maxStreamsExceeded
    case noLayoutSelected
    case invalidStreamPosition
    case layoutUpdateFailed
    case audioSwitchFailed
    
    public var errorDescription: String? {
        switch self {
        case .maxStreamsExceeded:
            return "Maximum number of streams exceeded"
        case .noLayoutSelected:
            return "No layout selected"
        case .invalidStreamPosition:
            return "Invalid stream position"
        case .layoutUpdateFailed:
            return "Failed to update layout"
        case .audioSwitchFailed:
            return "Failed to switch audio"
        }
    }
}

// MARK: - Extensions
extension MultiStreamLayoutManager {
    
    /// Get streams sorted by z-index for proper rendering order
    public var sortedStreams: [Stream] {
        return activeStreams.sorted { stream1, stream2 in
            let zIndex1 = streamPositions[stream1.id]?.zIndex ?? 0
            let zIndex2 = streamPositions[stream2.id]?.zIndex ?? 0
            return zIndex1 < zIndex2
        }
    }
    
    /// Check if a stream is currently focused
    public func isStreamFocused(_ stream: Stream) -> Bool {
        return focusedStream?.id == stream.id
    }
    
    /// Get the visual bounds for a stream
    public func getStreamBounds(_ stream: Stream) -> CGRect {
        return streamPositions[stream.id]?.rect ?? .zero
    }
    
    /// Check if two streams are overlapping
    public func areStreamsOverlapping(_ stream1: Stream, _ stream2: Stream) -> Bool {
        guard let rect1 = streamPositions[stream1.id]?.rect,
              let rect2 = streamPositions[stream2.id]?.rect else {
            return false
        }
        
        return rect1.intersects(rect2)
    }
}