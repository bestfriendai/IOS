//
//  LayoutManager.swift
//  StreamyyyApp
//
//  Advanced layout management service with drag-and-drop capabilities
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Layout Manager
@MainActor
public class LayoutManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = LayoutManager()
    
    // MARK: - Published Properties
    @Published public var currentLayout: Layout?
    @Published public var availableLayouts: [Layout] = []
    @Published public var isDragging: Bool = false
    @Published public var dragOffset: CGSize = .zero
    @Published public var isAnimating: Bool = false
    @Published public var snapTarget: StreamPosition?
    @Published public var templateLayouts: [Layout] = []
    @Published public var customLayouts: [Layout] = []
    @Published public var recentLayouts: [Layout] = []
    @Published public var favoriteLayouts: [Layout] = []
    
    // MARK: - Drag and Drop State
    @Published public var draggedStream: Stream?
    @Published public var draggedStreamPosition: StreamPosition?
    @Published public var dropTargets: [DropTarget] = []
    @Published public var activeDropTarget: DropTarget?
    @Published public var dragPreview: DragPreview?
    
    // MARK: - Animation Properties
    @Published public var layoutTransition: LayoutTransition = .none
    @Published public var animationDuration: Double = 0.3
    @Published public var springAnimation: Animation = .interactiveSpring(response: 0.6, dampingFraction: 0.8)
    
    // MARK: - Grid and Snap Properties
    @Published public var gridSize: CGSize = CGSize(width: 20, height: 20)
    @Published public var showGrid: Bool = false
    @Published public var snapToGrid: Bool = true
    @Published public var showGuides: Bool = true
    @Published public var magneticSnap: Bool = true
    
    // MARK: - Screen Size Adaptation
    @Published public var screenSize: CGSize = UIScreen.main.bounds.size
    @Published public var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    @Published public var safeAreaInsets: EdgeInsets = .init()
    
    // MARK: - Private Properties
    private let modelContext: ModelContext
    private let layoutSyncManager: LayoutSyncManager
    private var cancellables = Set<AnyCancellable>()
    private var lastLayoutUpdate: Date = Date()
    private var isPerformingBatchUpdate: Bool = false
    
    // MARK: - Initialization
    public init(modelContext: ModelContext = ModelContainer.shared.mainContext) {
        self.modelContext = modelContext
        self.layoutSyncManager = LayoutSyncManager(modelContext: modelContext)
        setupObservers()
        loadInitialData()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Screen size changes
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateScreenProperties()
            }
            .store(in: &cancellables)
        
        // Layout sync updates
        layoutSyncManager.$sharedLayouts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] layouts in
                self?.handleSyncedLayouts(layouts)
            }
            .store(in: &cancellables)
        
        // Current layout changes
        $currentLayout
            .receive(on: DispatchQueue.main)
            .sink { [weak self] layout in
                self?.handleCurrentLayoutChange(layout)
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await loadAvailableLayouts()
            await loadTemplateLayouts()
            await loadRecentLayouts()
            await setDefaultLayoutIfNeeded()
        }
    }
    
    // MARK: - Layout Management
    public func loadAvailableLayouts() async {
        do {
            let descriptor = FetchDescriptor<Layout>(
                sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
            )
            let layouts = try modelContext.fetch(descriptor)
            
            availableLayouts = layouts
            customLayouts = layouts.filter { $0.isCustom }
            favoriteLayouts = layouts.filter { $0.isHighlyRated }
            
            print("✅ Loaded \(layouts.count) layouts")
        } catch {
            print("❌ Failed to load layouts: \(error)")
        }
    }
    
    public func loadTemplateLayouts() async {
        do {
            let templates = try await layoutSyncManager.loadTemplates()
            templateLayouts = templates.compactMap { template in
                guard let config = LayoutConfiguration.import(template.layoutData) else { return nil }
                return Layout(
                    name: template.name,
                    type: LayoutType(rawValue: template.category) ?? .custom,
                    configuration: config
                )
            }
            
            print("✅ Loaded \(templateLayouts.count) template layouts")
        } catch {
            print("❌ Failed to load template layouts: \(error)")
        }
    }
    
    public func loadRecentLayouts() async {
        recentLayouts = availableLayouts
            .filter { $0.lastUsedAt != nil }
            .sorted { $0.lastUsedAt! > $1.lastUsedAt! }
            .prefix(5)
            .map { $0 }
    }
    
    public func setCurrentLayout(_ layout: Layout) {
        withAnimation(springAnimation) {
            currentLayout = layout
            layout.recordUsage()
        }
        
        Task {
            try await layoutSyncManager.syncLayout(layout)
        }
    }
    
    public func createLayout(name: String, type: LayoutType, configuration: LayoutConfiguration? = nil) -> Layout {
        let layout = Layout(
            name: name,
            type: type,
            configuration: configuration ?? type.defaultConfiguration
        )
        
        modelContext.insert(layout)
        try? modelContext.save()
        
        availableLayouts.append(layout)
        customLayouts.append(layout)
        
        print("✅ Created layout: \(name)")
        return layout
    }
    
    public func duplicateLayout(_ layout: Layout) -> Layout {
        let newLayout = Layout(
            name: "\(layout.name) Copy",
            type: layout.type,
            configuration: layout.configuration
        )
        
        // Copy streams
        for stream in layout.streams {
            newLayout.addStream(position: stream.position, streamId: stream.streamId)
        }
        
        modelContext.insert(newLayout)
        try? modelContext.save()
        
        availableLayouts.append(newLayout)
        customLayouts.append(newLayout)
        
        print("✅ Duplicated layout: \(layout.name)")
        return newLayout
    }
    
    public func deleteLayout(_ layout: Layout) {
        modelContext.delete(layout)
        try? modelContext.save()
        
        availableLayouts.removeAll { $0.id == layout.id }
        customLayouts.removeAll { $0.id == layout.id }
        favoriteLayouts.removeAll { $0.id == layout.id }
        recentLayouts.removeAll { $0.id == layout.id }
        
        // Set a new current layout if this was the current one
        if currentLayout?.id == layout.id {
            currentLayout = availableLayouts.first
        }
        
        Task {
            try await layoutSyncManager.deleteLayout(layout)
        }
        
        print("✅ Deleted layout: \(layout.name)")
    }
    
    // MARK: - Drag and Drop
    public func startDragging(stream: Stream, at position: CGPoint) {
        isDragging = true
        draggedStream = stream
        draggedStreamPosition = stream.position
        
        generateDropTargets()
        createDragPreview(for: stream)
        
        // Enable magnetic snapping
        if magneticSnap {
            findNearestSnapTarget(position)
        }
        
        print("🎯 Started dragging stream: \(stream.displayTitle)")
    }
    
    public func updateDragPosition(_ position: CGPoint) {
        guard isDragging, let stream = draggedStream else { return }
        
        let adjustedPosition = snapToGrid ? snapToGridPosition(position) : position
        dragOffset = CGSize(
            width: adjustedPosition.x - stream.position.x,
            height: adjustedPosition.y - stream.position.y
        )
        
        // Update snap target
        if snapToGrid || magneticSnap {
            findNearestSnapTarget(adjustedPosition)
        }
        
        // Update active drop target
        updateActiveDropTarget(at: adjustedPosition)
        
        // Update drag preview
        updateDragPreview(at: adjustedPosition)
    }
    
    public func endDragging(at position: CGPoint) {
        guard isDragging, let stream = draggedStream else { return }
        
        let finalPosition = snapTarget?.position ?? 
                           (snapToGrid ? snapToGridPosition(position) : position)
        
        // Update stream position
        updateStreamPosition(stream, to: finalPosition)
        
        // Animate to final position
        withAnimation(springAnimation) {
            isDragging = false
            dragOffset = .zero
            snapTarget = nil
            activeDropTarget = nil
            dragPreview = nil
        }
        
        // Clean up
        draggedStream = nil
        draggedStreamPosition = nil
        dropTargets = []
        
        print("🎯 Ended dragging stream: \(stream.displayTitle)")
    }
    
    public func cancelDragging() {
        withAnimation(springAnimation) {
            isDragging = false
            dragOffset = .zero
            snapTarget = nil
            activeDropTarget = nil
            dragPreview = nil
        }
        
        draggedStream = nil
        draggedStreamPosition = nil
        dropTargets = []
        
        print("🎯 Cancelled dragging")
    }
    
    // MARK: - Stream Position Management
    public func updateStreamPosition(_ stream: Stream, to position: CGPoint) {
        let newPosition = StreamPosition(
            x: position.x,
            y: position.y,
            width: stream.position.width,
            height: stream.position.height,
            zIndex: stream.position.zIndex
        )
        
        stream.updatePosition(newPosition)
        
        // Update in current layout
        currentLayout?.updateStreamPosition(streamId: stream.id, position: newPosition)
        
        // Save changes
        try? modelContext.save()
        
        // Sync changes
        if let layout = currentLayout {
            Task {
                try await layoutSyncManager.syncLayout(layout)
            }
        }
    }
    
    public func resizeStream(_ stream: Stream, to size: CGSize) {
        let newPosition = StreamPosition(
            x: stream.position.x,
            y: stream.position.y,
            width: size.width,
            height: size.height,
            zIndex: stream.position.zIndex
        )
        
        stream.updatePosition(newPosition)
        currentLayout?.updateStreamPosition(streamId: stream.id, position: newPosition)
        
        try? modelContext.save()
    }
    
    public func bringStreamToFront(_ stream: Stream) {
        let maxZIndex = currentLayout?.streams.map { $0.position.zIndex }.max() ?? 0
        let newPosition = StreamPosition(
            x: stream.position.x,
            y: stream.position.y,
            width: stream.position.width,
            height: stream.position.height,
            zIndex: maxZIndex + 1
        )
        
        stream.updatePosition(newPosition)
        currentLayout?.updateStreamPosition(streamId: stream.id, position: newPosition)
        
        try? modelContext.save()
    }
    
    public func sendStreamToBack(_ stream: Stream) {
        let minZIndex = currentLayout?.streams.map { $0.position.zIndex }.min() ?? 0
        let newPosition = StreamPosition(
            x: stream.position.x,
            y: stream.position.y,
            width: stream.position.width,
            height: stream.position.height,
            zIndex: minZIndex - 1
        )
        
        stream.updatePosition(newPosition)
        currentLayout?.updateStreamPosition(streamId: stream.id, position: newPosition)
        
        try? modelContext.save()
    }
    
    // MARK: - Layout Transitions
    public func applyLayoutTransition(_ transition: LayoutTransition, to layout: Layout) {
        layoutTransition = transition
        isAnimating = true
        
        let animation = getAnimationForTransition(transition)
        
        withAnimation(animation) {
            currentLayout = layout
        }
        
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.isAnimating = false
            self.layoutTransition = .none
        }
    }
    
    private func getAnimationForTransition(_ transition: LayoutTransition) -> Animation {
        switch transition {
        case .none:
            return .easeInOut(duration: 0.1)
        case .fade:
            return .easeInOut(duration: 0.3)
        case .slide:
            return .easeInOut(duration: 0.4)
        case .scale:
            return .interpolatingSpring(stiffness: 300, damping: 25)
        case .flip:
            return .easeInOut(duration: 0.6)
        case .custom(let duration, let curve):
            return Animation.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: duration)
        }
    }
    
    // MARK: - Grid and Snap Utilities
    private func snapToGridPosition(_ position: CGPoint) -> CGPoint {
        let snappedX = round(position.x / gridSize.width) * gridSize.width
        let snappedY = round(position.y / gridSize.height) * gridSize.height
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    private func findNearestSnapTarget(_ position: CGPoint) {
        guard let layout = currentLayout else { return }
        
        let snapDistance: CGFloat = 30
        var nearestTarget: StreamPosition?
        var minDistance: CGFloat = .greatestFiniteMagnitude
        
        for layoutStream in layout.streams {
            let streamRect = layoutStream.position.rect
            let centers = [
                streamRect.center,
                CGPoint(x: streamRect.minX, y: streamRect.center.y),
                CGPoint(x: streamRect.maxX, y: streamRect.center.y),
                CGPoint(x: streamRect.center.x, y: streamRect.minY),
                CGPoint(x: streamRect.center.x, y: streamRect.maxY)
            ]
            
            for center in centers {
                let distance = position.distance(to: center)
                if distance < snapDistance && distance < minDistance {
                    minDistance = distance
                    nearestTarget = StreamPosition(
                        x: center.x,
                        y: center.y,
                        width: layoutStream.position.width,
                        height: layoutStream.position.height,
                        zIndex: layoutStream.position.zIndex
                    )
                }
            }
        }
        
        snapTarget = nearestTarget
    }
    
    // MARK: - Drop Target Management
    private func generateDropTargets() {
        guard let layout = currentLayout else { return }
        
        dropTargets = []
        
        // Create drop targets for each stream position
        for layoutStream in layout.streams {
            let dropTarget = DropTarget(
                id: layoutStream.id,
                position: layoutStream.position,
                type: .stream,
                isActive: false
            )
            dropTargets.append(dropTarget)
        }
        
        // Add grid drop targets if enabled
        if showGrid {
            generateGridDropTargets()
        }
    }
    
    private func generateGridDropTargets() {
        let gridCols = Int(screenSize.width / gridSize.width)
        let gridRows = Int(screenSize.height / gridSize.height)
        
        for row in 0..<gridRows {
            for col in 0..<gridCols {
                let position = StreamPosition(
                    x: Double(col) * gridSize.width,
                    y: Double(row) * gridSize.height,
                    width: gridSize.width,
                    height: gridSize.height,
                    zIndex: 0
                )
                
                let dropTarget = DropTarget(
                    id: "grid_\(row)_\(col)",
                    position: position,
                    type: .grid,
                    isActive: false
                )
                
                dropTargets.append(dropTarget)
            }
        }
    }
    
    private func updateActiveDropTarget(at position: CGPoint) {
        // Find the drop target at the given position
        let hitTarget = dropTargets.first { target in
            target.position.rect.contains(position)
        }
        
        // Update active state
        for target in dropTargets {
            target.isActive = target.id == hitTarget?.id
        }
        
        activeDropTarget = hitTarget
    }
    
    // MARK: - Drag Preview
    private func createDragPreview(for stream: Stream) {
        dragPreview = DragPreview(
            stream: stream,
            position: stream.position,
            opacity: 0.8,
            scale: 0.95,
            rotation: 2.0
        )
    }
    
    private func updateDragPreview(at position: CGPoint) {
        guard let preview = dragPreview else { return }
        
        preview.position = StreamPosition(
            x: position.x,
            y: position.y,
            width: preview.position.width,
            height: preview.position.height,
            zIndex: preview.position.zIndex
        )
    }
    
    // MARK: - Screen Size Management
    private func updateScreenProperties() {
        screenSize = UIScreen.main.bounds.size
        deviceOrientation = UIDevice.current.orientation
        
        // Update grid size based on screen size
        let baseGridSize: CGFloat = 20
        let scaleFactor = min(screenSize.width, screenSize.height) / 375 // iPhone base size
        gridSize = CGSize(
            width: baseGridSize * scaleFactor,
            height: baseGridSize * scaleFactor
        )
        
        // Regenerate drop targets if needed
        if isDragging {
            generateDropTargets()
        }
    }
    
    // MARK: - Layout Validation
    public func validateLayout(_ layout: Layout) -> [LayoutValidationError] {
        var errors: [LayoutValidationError] = []
        
        // Check for overlapping streams
        let streamPositions = layout.streams.map { $0.position }
        for i in 0..<streamPositions.count {
            for j in (i+1)..<streamPositions.count {
                if streamPositions[i].rect.intersects(streamPositions[j].rect) {
                    errors.append(.overlappingStreams(i, j))
                }
            }
        }
        
        // Check for streams outside bounds
        for (index, stream) in layout.streams.enumerated() {
            let rect = stream.position.rect
            if rect.minX < 0 || rect.minY < 0 || 
               rect.maxX > screenSize.width || rect.maxY > screenSize.height {
                errors.append(.streamOutOfBounds(index))
            }
        }
        
        // Check for minimum stream size
        let minSize = layout.configuration.minStreamSize
        for (index, stream) in layout.streams.enumerated() {
            if stream.position.width < minSize.width || stream.position.height < minSize.height {
                errors.append(.streamTooSmall(index))
            }
        }
        
        return errors
    }
    
    // MARK: - Auto Layout
    public func autoArrangeStreams(in layout: Layout, style: AutoArrangeStyle) {
        guard !layout.streams.isEmpty else { return }
        
        let streams = layout.streams.sorted { $0.order < $1.order }
        let availableArea = CGRect(
            x: layout.configuration.padding.leading,
            y: layout.configuration.padding.top,
            width: screenSize.width - layout.configuration.padding.leading - layout.configuration.padding.trailing,
            height: screenSize.height - layout.configuration.padding.top - layout.configuration.padding.bottom
        )
        
        switch style {
        case .grid:
            arrangeStreamsInGrid(streams, in: availableArea, layout: layout)
        case .cascade:
            arrangeStreamsInCascade(streams, in: availableArea, layout: layout)
        case .stack:
            arrangeStreamsInStack(streams, in: availableArea, layout: layout)
        case .circle:
            arrangeStreamsInCircle(streams, in: availableArea, layout: layout)
        }
        
        try? modelContext.save()
    }
    
    private func arrangeStreamsInGrid(_ streams: [LayoutStream], in area: CGRect, layout: Layout) {
        let count = streams.count
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))
        
        let streamWidth = (area.width - layout.configuration.spacing * Double(cols - 1)) / Double(cols)
        let streamHeight = (area.height - layout.configuration.spacing * Double(rows - 1)) / Double(rows)
        
        for (index, stream) in streams.enumerated() {
            let col = index % cols
            let row = index / cols
            
            let x = area.minX + Double(col) * (streamWidth + layout.configuration.spacing)
            let y = area.minY + Double(row) * (streamHeight + layout.configuration.spacing)
            
            let newPosition = StreamPosition(
                x: x,
                y: y,
                width: streamWidth,
                height: streamHeight,
                zIndex: stream.position.zIndex
            )
            
            stream.position = newPosition
        }
    }
    
    private func arrangeStreamsInCascade(_ streams: [LayoutStream], in area: CGRect, layout: Layout) {
        let offset: CGFloat = 30
        let streamWidth = min(area.width * 0.6, 400)
        let streamHeight = min(area.height * 0.6, 300)
        
        for (index, stream) in streams.enumerated() {
            let x = area.minX + Double(index) * Double(offset)
            let y = area.minY + Double(index) * Double(offset)
            
            let newPosition = StreamPosition(
                x: x,
                y: y,
                width: streamWidth,
                height: streamHeight,
                zIndex: index
            )
            
            stream.position = newPosition
        }
    }
    
    private func arrangeStreamsInStack(_ streams: [LayoutStream], in area: CGRect, layout: Layout) {
        let streamWidth = area.width
        let streamHeight = (area.height - layout.configuration.spacing * Double(streams.count - 1)) / Double(streams.count)
        
        for (index, stream) in streams.enumerated() {
            let x = area.minX
            let y = area.minY + Double(index) * (streamHeight + layout.configuration.spacing)
            
            let newPosition = StreamPosition(
                x: x,
                y: y,
                width: streamWidth,
                height: streamHeight,
                zIndex: stream.position.zIndex
            )
            
            stream.position = newPosition
        }
    }
    
    private func arrangeStreamsInCircle(_ streams: [LayoutStream], in area: CGRect, layout: Layout) {
        let center = CGPoint(x: area.midX, y: area.midY)
        let radius = min(area.width, area.height) * 0.3
        let angleStep = 2.0 * .pi / Double(streams.count)
        
        let streamSize = CGSize(width: 150, height: 112)
        
        for (index, stream) in streams.enumerated() {
            let angle = Double(index) * angleStep
            let x = center.x + radius * cos(angle) - streamSize.width / 2
            let y = center.y + radius * sin(angle) - streamSize.height / 2
            
            let newPosition = StreamPosition(
                x: x,
                y: y,
                width: streamSize.width,
                height: streamSize.height,
                zIndex: stream.position.zIndex
            )
            
            stream.position = newPosition
        }
    }
    
    // MARK: - Helper Methods
    private func setDefaultLayoutIfNeeded() async {
        if currentLayout == nil {
            currentLayout = await layoutSyncManager.getDefaultLayout() ?? availableLayouts.first
        }
    }
    
    private func handleSyncedLayouts(_ layouts: [Layout]) {
        // Update available layouts with synced data
        for syncedLayout in layouts {
            if let existingIndex = availableLayouts.firstIndex(where: { $0.id == syncedLayout.id }) {
                availableLayouts[existingIndex] = syncedLayout
            } else {
                availableLayouts.append(syncedLayout)
            }
        }
    }
    
    private func handleCurrentLayoutChange(_ layout: Layout?) {
        guard let layout = layout else { return }
        
        // Update recent layouts
        recentLayouts.removeAll { $0.id == layout.id }
        recentLayouts.insert(layout, at: 0)
        recentLayouts = Array(recentLayouts.prefix(5))
        
        // Generate drop targets for new layout
        if isDragging {
            generateDropTargets()
        }
    }
}

// MARK: - Supporting Models
public class DropTarget: ObservableObject, Identifiable {
    public let id: String
    public let position: StreamPosition
    public let type: DropTargetType
    @Published public var isActive: Bool
    
    public init(id: String, position: StreamPosition, type: DropTargetType, isActive: Bool = false) {
        self.id = id
        self.position = position
        self.type = type
        self.isActive = isActive
    }
}

public enum DropTargetType {
    case stream
    case grid
    case custom
}

public class DragPreview: ObservableObject {
    public let stream: Stream
    @Published public var position: StreamPosition
    @Published public var opacity: Double
    @Published public var scale: Double
    @Published public var rotation: Double
    
    public init(stream: Stream, position: StreamPosition, opacity: Double = 1.0, scale: Double = 1.0, rotation: Double = 0.0) {
        self.stream = stream
        self.position = position
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
    }
}

public enum LayoutTransition {
    case none
    case fade
    case slide
    case scale
    case flip
    case custom(duration: Double, curve: BezierCurve)
}

public struct BezierCurve {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
}

public enum AutoArrangeStyle {
    case grid
    case cascade
    case stack
    case circle
}

public enum LayoutValidationError: Error {
    case overlappingStreams(Int, Int)
    case streamOutOfBounds(Int)
    case streamTooSmall(Int)
}

// MARK: - Extensions
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}