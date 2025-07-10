//
//  AdvancedLayoutManager.swift
//  StreamyyyApp
//
//  Advanced layout management with Focus mode and Custom Bento grid
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import Combine

// MARK: - Advanced Layout Manager

@MainActor
public class AdvancedLayoutManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentLayout: AdvancedLayoutConfiguration = .grid(GridLayoutConfiguration())
    @Published var isInFocusMode = false
    @Published var focusedStreamIndex: Int = 0
    @Published var customBentoLayout: BentoLayoutConfiguration?
    @Published var layoutTransition: LayoutTransition = .none
    @Published var isLayoutAnimating = false
    
    // MARK: - Configuration
    
    public struct LayoutManagerConfiguration {
        public let enableAnimations: Bool
        public let animationDuration: Double
        public let enableGestures: Bool
        public let enableKeyboardShortcuts: Bool
        public let defaultLayoutType: LayoutType
        
        public init(
            enableAnimations: Bool = true,
            animationDuration: Double = 0.3,
            enableGestures: Bool = true,
            enableKeyboardShortcuts: Bool = true,
            defaultLayoutType: LayoutType = .grid
        ) {
            self.enableAnimations = enableAnimations
            self.animationDuration = animationDuration
            self.enableGestures = enableGestures
            self.enableKeyboardShortcuts = enableKeyboardShortcuts
            self.defaultLayoutType = defaultLayoutType
        }
    }
    
    private let configuration: LayoutManagerConfiguration
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Initialization
    
    public init(configuration: LayoutManagerConfiguration = LayoutManagerConfiguration()) {
        self.configuration = configuration
        setupObservers()
    }
    
    // MARK: - Layout Management
    
    /// Switch to grid layout
    public func switchToGridLayout(
        columns: Int = 2,
        aspectRatio: AspectRatio = .standard,
        spacing: CGFloat = 8
    ) {
        let gridConfig = GridLayoutConfiguration(
            columns: columns,
            aspectRatio: aspectRatio,
            spacing: spacing
        )
        
        switchToLayout(.grid(gridConfig))
    }
    
    /// Switch to picture-in-picture layout
    public func switchToPiPLayout(
        mainStreamIndex: Int = 0,
        pipPosition: PiPPosition = .bottomTrailing,
        pipSize: PiPSize = .medium
    ) {
        let pipConfig = PiPLayoutConfiguration(
            mainStreamIndex: mainStreamIndex,
            position: pipPosition,
            size: pipSize
        )
        
        switchToLayout(.pip(pipConfig))
    }
    
    /// Switch to focus mode
    public func enterFocusMode(streamIndex: Int = 0) {
        focusedStreamIndex = streamIndex
        isInFocusMode = true
        
        let focusConfig = FocusLayoutConfiguration(
            focusedStreamIndex: streamIndex,
            showSecondaryStreams: true,
            secondaryStreamSize: .small
        )
        
        switchToLayout(.focus(focusConfig))
        provideFeedback()
    }
    
    /// Exit focus mode
    public func exitFocusMode() {
        isInFocusMode = false
        
        // Return to previous layout
        switchToGridLayout()
        provideFeedback()
    }
    
    /// Toggle focus mode
    public func toggleFocusMode(streamIndex: Int? = nil) {
        if isInFocusMode {
            exitFocusMode()
        } else {
            enterFocusMode(streamIndex: streamIndex ?? focusedStreamIndex)
        }
    }
    
    /// Switch to mosaic layout
    public func switchToMosaicLayout(pattern: MosaicPattern = .balanced) {
        let mosaicConfig = MosaicLayoutConfiguration(pattern: pattern)
        switchToLayout(.mosaic(mosaicConfig))
    }
    
    /// Create custom Bento grid layout
    public func createCustomBentoLayout(_ configuration: BentoLayoutConfiguration) {
        customBentoLayout = configuration
        switchToLayout(.customBento(configuration))
    }
    
    /// Apply predefined Bento layout template
    public func applyBentoTemplate(_ template: BentoTemplate) {
        let bentoConfig = template.createConfiguration()
        createCustomBentoLayout(bentoConfig)
    }
    
    // MARK: - Stream Focus Management
    
    /// Focus on next stream
    public func focusNextStream(streamCount: Int) {
        guard isInFocusMode else { return }
        
        focusedStreamIndex = (focusedStreamIndex + 1) % streamCount
        updateFocusLayout()
        provideFeedback()
    }
    
    /// Focus on previous stream
    public func focusPreviousStream(streamCount: Int) {
        guard isInFocusMode else { return }
        
        focusedStreamIndex = focusedStreamIndex > 0 ? focusedStreamIndex - 1 : streamCount - 1
        updateFocusLayout()
        provideFeedback()
    }
    
    /// Focus on specific stream
    public func focusOnStream(_ index: Int) {
        focusedStreamIndex = index
        
        if isInFocusMode {
            updateFocusLayout()
        } else {
            enterFocusMode(streamIndex: index)
        }
    }
    
    // MARK: - Layout Transitions
    
    /// Get layout positions for streams
    public func getStreamPositions(
        for streams: [Stream],
        in containerSize: CGSize
    ) -> [StreamPosition] {
        switch currentLayout {
        case .grid(let config):
            return calculateGridPositions(streams: streams, config: config, containerSize: containerSize)
            
        case .pip(let config):
            return calculatePiPPositions(streams: streams, config: config, containerSize: containerSize)
            
        case .focus(let config):
            return calculateFocusPositions(streams: streams, config: config, containerSize: containerSize)
            
        case .mosaic(let config):
            return calculateMosaicPositions(streams: streams, config: config, containerSize: containerSize)
            
        case .customBento(let config):
            return calculateBentoPositions(streams: streams, config: config, containerSize: containerSize)
        }
    }
    
    /// Get animation configuration for layout transition
    public func getAnimationConfiguration() -> Animation? {
        guard configuration.enableAnimations else { return nil }
        
        switch layoutTransition {
        case .none:
            return nil
        case .fade:
            return .easeInOut(duration: configuration.animationDuration)
        case .slide:
            return .spring(duration: configuration.animationDuration)
        case .scale:
            return .spring(response: configuration.animationDuration, dampingFraction: 0.8)
        case .flip:
            return .easeInOut(duration: configuration.animationDuration * 1.5)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe layout changes for animations
        $currentLayout
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleLayoutChange()
            }
            .store(in: &cancellables)
    }
    
    private func switchToLayout(_ layout: AdvancedLayoutConfiguration) {
        layoutTransition = determineTransition(from: currentLayout, to: layout)
        
        if configuration.enableAnimations {
            isLayoutAnimating = true
            
            withAnimation(getAnimationConfiguration()) {
                currentLayout = layout
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + configuration.animationDuration) {
                self.isLayoutAnimating = false
                self.layoutTransition = .none
            }
        } else {
            currentLayout = layout
        }
    }
    
    private func updateFocusLayout() {
        if case .focus(let config) = currentLayout {
            let updatedConfig = FocusLayoutConfiguration(
                focusedStreamIndex: focusedStreamIndex,
                showSecondaryStreams: config.showSecondaryStreams,
                secondaryStreamSize: config.secondaryStreamSize
            )
            
            switchToLayout(.focus(updatedConfig))
        }
    }
    
    private func handleLayoutChange() {
        // Perform any necessary cleanup or setup for layout changes
        if configuration.enableAnimations {
            provideFeedback()
        }
    }
    
    private func provideFeedback() {
        if configuration.enableAnimations {
            hapticFeedback.impactOccurred()
        }
    }
    
    private func determineTransition(
        from currentLayout: AdvancedLayoutConfiguration,
        to newLayout: AdvancedLayoutConfiguration
    ) -> LayoutTransition {
        switch (currentLayout, newLayout) {
        case (.grid, .focus), (.focus, .grid):
            return .scale
        case (.pip, _), (_, .pip):
            return .slide
        case (.mosaic, _), (_, .mosaic):
            return .fade
        default:
            return .fade
        }
    }
}

// MARK: - Layout Calculations

extension AdvancedLayoutManager {
    
    private func calculateGridPositions(
        streams: [Stream],
        config: GridLayoutConfiguration,
        containerSize: CGSize
    ) -> [StreamPosition] {
        let columns = min(config.columns, streams.count)
        let rows = Int(ceil(Double(streams.count) / Double(columns)))
        
        let totalHorizontalSpacing = CGFloat(columns - 1) * config.spacing
        let totalVerticalSpacing = CGFloat(rows - 1) * config.spacing
        
        let itemWidth = (containerSize.width - totalHorizontalSpacing) / CGFloat(columns)
        let itemHeight = itemWidth / config.aspectRatio.ratio
        
        var positions: [StreamPosition] = []
        
        for (index, stream) in streams.enumerated() {
            let column = index % columns
            let row = index / columns
            
            let x = CGFloat(column) * (itemWidth + config.spacing)
            let y = CGFloat(row) * (itemHeight + config.spacing)
            
            positions.append(StreamPosition(
                stream: stream,
                frame: CGRect(x: x, y: y, width: itemWidth, height: itemHeight),
                zIndex: 0,
                opacity: 1.0,
                scale: 1.0
            ))
        }
        
        return positions
    }
    
    private func calculatePiPPositions(
        streams: [Stream],
        config: PiPLayoutConfiguration,
        containerSize: CGSize
    ) -> [StreamPosition] {
        guard !streams.isEmpty else { return [] }
        
        var positions: [StreamPosition] = []
        let mainStream = streams[config.mainStreamIndex]
        
        // Main stream takes full container
        positions.append(StreamPosition(
            stream: mainStream,
            frame: CGRect(origin: .zero, size: containerSize),
            zIndex: 0,
            opacity: 1.0,
            scale: 1.0
        ))
        
        // Calculate PiP positions for other streams
        let pipSize = config.size.getSize(for: containerSize)
        let margin: CGFloat = 16
        
        for (index, stream) in streams.enumerated() {
            guard index != config.mainStreamIndex else { continue }
            
            let pipFrame = config.position.getFrame(
                size: pipSize,
                containerSize: containerSize,
                margin: margin,
                index: index - (index > config.mainStreamIndex ? 1 : 0)
            )
            
            positions.append(StreamPosition(
                stream: stream,
                frame: pipFrame,
                zIndex: 10 + index,
                opacity: 1.0,
                scale: 1.0
            ))
        }
        
        return positions
    }
    
    private func calculateFocusPositions(
        streams: [Stream],
        config: FocusLayoutConfiguration,
        containerSize: CGSize
    ) -> [StreamPosition] {
        guard !streams.isEmpty else { return [] }
        
        var positions: [StreamPosition] = []
        let focusedStream = streams[config.focusedStreamIndex]
        
        if config.showSecondaryStreams && streams.count > 1 {
            // Focused stream takes most of the space
            let secondaryHeight = config.secondaryStreamSize.getHeight(for: containerSize)
            let focusHeight = containerSize.height - secondaryHeight - 16
            
            positions.append(StreamPosition(
                stream: focusedStream,
                frame: CGRect(x: 0, y: 0, width: containerSize.width, height: focusHeight),
                zIndex: 1,
                opacity: 1.0,
                scale: 1.0
            ))
            
            // Secondary streams in a horizontal strip
            let secondaryStreams = streams.enumerated().filter { $0.offset != config.focusedStreamIndex }
            let secondaryWidth = containerSize.width / CGFloat(secondaryStreams.count)
            
            for (index, (_, stream)) in secondaryStreams.enumerated() {
                let x = CGFloat(index) * secondaryWidth
                let y = focusHeight + 16
                
                positions.append(StreamPosition(
                    stream: stream,
                    frame: CGRect(x: x, y: y, width: secondaryWidth, height: secondaryHeight),
                    zIndex: 0,
                    opacity: 0.8,
                    scale: 1.0
                ))
            }
        } else {
            // Only focused stream
            positions.append(StreamPosition(
                stream: focusedStream,
                frame: CGRect(origin: .zero, size: containerSize),
                zIndex: 0,
                opacity: 1.0,
                scale: 1.0
            ))
        }
        
        return positions
    }
    
    private func calculateMosaicPositions(
        streams: [Stream],
        config: MosaicLayoutConfiguration,
        containerSize: CGSize
    ) -> [StreamPosition] {
        switch config.pattern {
        case .balanced:
            return calculateBalancedMosaicPositions(streams: streams, containerSize: containerSize)
        case .asymmetric:
            return calculateAsymmetricMosaicPositions(streams: streams, containerSize: containerSize)
        case .pyramid:
            return calculatePyramidMosaicPositions(streams: streams, containerSize: containerSize)
        }
    }
    
    private func calculateBentoPositions(
        streams: [Stream],
        config: BentoLayoutConfiguration,
        containerSize: CGSize
    ) -> [StreamPosition] {
        var positions: [StreamPosition] = []
        
        for (index, stream) in streams.enumerated() {
            guard index < config.cells.count else { break }
            
            let cell = config.cells[index]
            let frame = cell.getFrame(in: containerSize, gridSize: config.gridSize)
            
            positions.append(StreamPosition(
                stream: stream,
                frame: frame,
                zIndex: cell.priority,
                opacity: 1.0,
                scale: 1.0
            ))
        }
        
        return positions
    }
    
    // MARK: - Mosaic Calculations
    
    private func calculateBalancedMosaicPositions(
        streams: [Stream],
        containerSize: CGSize
    ) -> [StreamPosition] {
        // Implementation for balanced mosaic layout
        return calculateGridPositions(
            streams: streams,
            config: GridLayoutConfiguration(columns: 2, spacing: 4),
            containerSize: containerSize
        )
    }
    
    private func calculateAsymmetricMosaicPositions(
        streams: [Stream],
        containerSize: CGSize
    ) -> [StreamPosition] {
        // Implementation for asymmetric mosaic layout
        var positions: [StreamPosition] = []
        
        guard !streams.isEmpty else { return positions }
        
        // First stream takes 2/3 of width, full height
        let mainWidth = containerSize.width * 2/3
        positions.append(StreamPosition(
            stream: streams[0],
            frame: CGRect(x: 0, y: 0, width: mainWidth, height: containerSize.height),
            zIndex: 0,
            opacity: 1.0,
            scale: 1.0
        ))
        
        // Remaining streams stack vertically in the remaining 1/3
        let sideWidth = containerSize.width - mainWidth
        let sideHeight = containerSize.height / CGFloat(max(1, streams.count - 1))
        
        for (index, stream) in streams.dropFirst().enumerated() {
            let y = CGFloat(index) * sideHeight
            
            positions.append(StreamPosition(
                stream: stream,
                frame: CGRect(x: mainWidth, y: y, width: sideWidth, height: sideHeight),
                zIndex: 0,
                opacity: 1.0,
                scale: 1.0
            ))
        }
        
        return positions
    }
    
    private func calculatePyramidMosaicPositions(
        streams: [Stream],
        containerSize: CGSize
    ) -> [StreamPosition] {
        // Implementation for pyramid mosaic layout
        var positions: [StreamPosition] = []
        
        guard !streams.isEmpty else { return positions }
        
        // Top stream takes full width, 1/2 height
        let topHeight = containerSize.height / 2
        positions.append(StreamPosition(
            stream: streams[0],
            frame: CGRect(x: 0, y: 0, width: containerSize.width, height: topHeight),
            zIndex: 0,
            opacity: 1.0,
            scale: 1.0
        ))
        
        // Bottom streams split the remaining space
        let bottomStreams = Array(streams.dropFirst())
        let bottomWidth = containerSize.width / CGFloat(max(1, bottomStreams.count))
        let bottomHeight = containerSize.height - topHeight
        
        for (index, stream) in bottomStreams.enumerated() {
            let x = CGFloat(index) * bottomWidth
            
            positions.append(StreamPosition(
                stream: stream,
                frame: CGRect(x: x, y: topHeight, width: bottomWidth, height: bottomHeight),
                zIndex: 0,
                opacity: 1.0,
                scale: 1.0
            ))
        }
        
        return positions
    }
}

// MARK: - Data Models

public enum AdvancedLayoutConfiguration: Equatable {
    case grid(GridLayoutConfiguration)
    case pip(PiPLayoutConfiguration)
    case focus(FocusLayoutConfiguration)
    case mosaic(MosaicLayoutConfiguration)
    case customBento(BentoLayoutConfiguration)
}

public struct GridLayoutConfiguration: Equatable {
    public let columns: Int
    public let aspectRatio: AspectRatio
    public let spacing: CGFloat
    
    public init(columns: Int = 2, aspectRatio: AspectRatio = .standard, spacing: CGFloat = 8) {
        self.columns = columns
        self.aspectRatio = aspectRatio
        self.spacing = spacing
    }
}

public struct PiPLayoutConfiguration: Equatable {
    public let mainStreamIndex: Int
    public let position: PiPPosition
    public let size: PiPSize
    
    public init(mainStreamIndex: Int = 0, position: PiPPosition = .bottomTrailing, size: PiPSize = .medium) {
        self.mainStreamIndex = mainStreamIndex
        self.position = position
        self.size = size
    }
}

public struct FocusLayoutConfiguration: Equatable {
    public let focusedStreamIndex: Int
    public let showSecondaryStreams: Bool
    public let secondaryStreamSize: SecondaryStreamSize
    
    public init(focusedStreamIndex: Int = 0, showSecondaryStreams: Bool = true, secondaryStreamSize: SecondaryStreamSize = .small) {
        self.focusedStreamIndex = focusedStreamIndex
        self.showSecondaryStreams = showSecondaryStreams
        self.secondaryStreamSize = secondaryStreamSize
    }
}

public struct MosaicLayoutConfiguration: Equatable {
    public let pattern: MosaicPattern
    
    public init(pattern: MosaicPattern = .balanced) {
        self.pattern = pattern
    }
}

public struct BentoLayoutConfiguration: Equatable {
    public let gridSize: GridSize
    public let cells: [BentoCell]
    
    public init(gridSize: GridSize, cells: [BentoCell]) {
        self.gridSize = gridSize
        self.cells = cells
    }
}

public struct BentoCell: Equatable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let priority: Int
    
    public init(x: Int, y: Int, width: Int, height: Int, priority: Int = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.priority = priority
    }
    
    public func getFrame(in containerSize: CGSize, gridSize: GridSize) -> CGRect {
        let cellWidth = containerSize.width / CGFloat(gridSize.columns)
        let cellHeight = containerSize.height / CGFloat(gridSize.rows)
        
        return CGRect(
            x: CGFloat(x) * cellWidth,
            y: CGFloat(y) * cellHeight,
            width: CGFloat(width) * cellWidth,
            height: CGFloat(height) * cellHeight
        )
    }
}

public struct GridSize: Equatable {
    public let columns: Int
    public let rows: Int
    
    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }
}

public struct StreamPosition {
    public let stream: Stream
    public let frame: CGRect
    public let zIndex: Int
    public let opacity: Double
    public let scale: Double
    
    public init(stream: Stream, frame: CGRect, zIndex: Int, opacity: Double, scale: Double) {
        self.stream = stream
        self.frame = frame
        self.zIndex = zIndex
        self.opacity = opacity
        self.scale = scale
    }
}

public enum AspectRatio: Equatable {
    case standard // 16:9
    case wide // 21:9
    case square // 1:1
    case tall // 9:16
    
    public var ratio: CGFloat {
        switch self {
        case .standard: return 16/9
        case .wide: return 21/9
        case .square: return 1
        case .tall: return 9/16
        }
    }
}

public enum PiPPosition: Equatable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case center
    
    public func getFrame(size: CGSize, containerSize: CGSize, margin: CGFloat, index: Int) -> CGRect {
        let offset = CGFloat(index) * (size.height + margin/2)
        
        switch self {
        case .topLeading:
            return CGRect(x: margin, y: margin + offset, width: size.width, height: size.height)
        case .topTrailing:
            return CGRect(x: containerSize.width - size.width - margin, y: margin + offset, width: size.width, height: size.height)
        case .bottomLeading:
            return CGRect(x: margin, y: containerSize.height - size.height - margin - offset, width: size.width, height: size.height)
        case .bottomTrailing:
            return CGRect(x: containerSize.width - size.width - margin, y: containerSize.height - size.height - margin - offset, width: size.width, height: size.height)
        case .center:
            return CGRect(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2 + offset, width: size.width, height: size.height)
        }
    }
}

public enum PiPSize: Equatable {
    case small
    case medium
    case large
    
    public func getSize(for containerSize: CGSize) -> CGSize {
        let scale: CGFloat
        switch self {
        case .small: scale = 0.2
        case .medium: scale = 0.3
        case .large: scale = 0.4
        }
        
        return CGSize(
            width: containerSize.width * scale,
            height: containerSize.width * scale * 9/16 // Maintain 16:9 aspect ratio
        )
    }
}

public enum SecondaryStreamSize: Equatable {
    case small
    case medium
    case large
    
    public func getHeight(for containerSize: CGSize) -> CGFloat {
        switch self {
        case .small: return containerSize.height * 0.2
        case .medium: return containerSize.height * 0.3
        case .large: return containerSize.height * 0.4
        }
    }
}

public enum MosaicPattern: Equatable {
    case balanced
    case asymmetric
    case pyramid
}

public enum LayoutTransition: Equatable {
    case none
    case fade
    case slide
    case scale
    case flip
}

// MARK: - Bento Templates

public enum BentoTemplate: CaseIterable {
    case twoByTwo
    case featured
    case sidebar
    case magazine
    case dashboard
    
    public var name: String {
        switch self {
        case .twoByTwo: return "2x2 Grid"
        case .featured: return "Featured"
        case .sidebar: return "Sidebar"
        case .magazine: return "Magazine"
        case .dashboard: return "Dashboard"
        }
    }
    
    public func createConfiguration() -> BentoLayoutConfiguration {
        switch self {
        case .twoByTwo:
            return BentoLayoutConfiguration(
                gridSize: GridSize(columns: 4, rows: 4),
                cells: [
                    BentoCell(x: 0, y: 0, width: 2, height: 2, priority: 1),
                    BentoCell(x: 2, y: 0, width: 2, height: 2, priority: 1),
                    BentoCell(x: 0, y: 2, width: 2, height: 2, priority: 1),
                    BentoCell(x: 2, y: 2, width: 2, height: 2, priority: 1)
                ]
            )
            
        case .featured:
            return BentoLayoutConfiguration(
                gridSize: GridSize(columns: 6, rows: 4),
                cells: [
                    BentoCell(x: 0, y: 0, width: 4, height: 3, priority: 2), // Main
                    BentoCell(x: 4, y: 0, width: 2, height: 1, priority: 1),
                    BentoCell(x: 4, y: 1, width: 2, height: 1, priority: 1),
                    BentoCell(x: 4, y: 2, width: 2, height: 1, priority: 1),
                    BentoCell(x: 0, y: 3, width: 2, height: 1, priority: 0),
                    BentoCell(x: 2, y: 3, width: 2, height: 1, priority: 0),
                    BentoCell(x: 4, y: 3, width: 2, height: 1, priority: 0)
                ]
            )
            
        case .sidebar:
            return BentoLayoutConfiguration(
                gridSize: GridSize(columns: 5, rows: 4),
                cells: [
                    BentoCell(x: 0, y: 0, width: 4, height: 4, priority: 2), // Main
                    BentoCell(x: 4, y: 0, width: 1, height: 1, priority: 1),
                    BentoCell(x: 4, y: 1, width: 1, height: 1, priority: 1),
                    BentoCell(x: 4, y: 2, width: 1, height: 1, priority: 1),
                    BentoCell(x: 4, y: 3, width: 1, height: 1, priority: 1)
                ]
            )
            
        case .magazine:
            return BentoLayoutConfiguration(
                gridSize: GridSize(columns: 6, rows: 6),
                cells: [
                    BentoCell(x: 0, y: 0, width: 3, height: 3, priority: 2), // Feature
                    BentoCell(x: 3, y: 0, width: 3, height: 2, priority: 1),
                    BentoCell(x: 3, y: 2, width: 1, height: 1, priority: 0),
                    BentoCell(x: 4, y: 2, width: 1, height: 1, priority: 0),
                    BentoCell(x: 5, y: 2, width: 1, height: 1, priority: 0),
                    BentoCell(x: 0, y: 3, width: 2, height: 3, priority: 1),
                    BentoCell(x: 2, y: 3, width: 2, height: 3, priority: 1),
                    BentoCell(x: 4, y: 3, width: 2, height: 3, priority: 1)
                ]
            )
            
        case .dashboard:
            return BentoLayoutConfiguration(
                gridSize: GridSize(columns: 8, rows: 6),
                cells: [
                    BentoCell(x: 0, y: 0, width: 5, height: 4, priority: 2), // Main dashboard
                    BentoCell(x: 5, y: 0, width: 3, height: 2, priority: 1),
                    BentoCell(x: 5, y: 2, width: 1, height: 2, priority: 0),
                    BentoCell(x: 6, y: 2, width: 1, height: 2, priority: 0),
                    BentoCell(x: 7, y: 2, width: 1, height: 2, priority: 0),
                    BentoCell(x: 0, y: 4, width: 2, height: 2, priority: 1),
                    BentoCell(x: 2, y: 4, width: 2, height: 2, priority: 1),
                    BentoCell(x: 4, y: 4, width: 2, height: 2, priority: 1),
                    BentoCell(x: 6, y: 4, width: 2, height: 2, priority: 1)
                ]
            )
        }
    }
}