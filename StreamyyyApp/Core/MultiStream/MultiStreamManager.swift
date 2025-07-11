//
//  MultiStreamManager.swift
//  StreamyyyApp
//
//  Core multi-stream viewing manager with working video players
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

// MARK: - Multi Stream Manager
class MultiStreamManager: ObservableObject {
    static let shared = MultiStreamManager()
    
    @Published var activeStreams: [StreamSlot] = []
    @Published var currentLayout: MultiStreamLayout = .twoByTwo
    @Published var globalQuality: StreamQuality = .medium
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Stream management
    private var streamQualities: [String: StreamQuality] = [:]
    private var streamStates: [String: StreamPlaybackState] = [:]
    private var persistenceService = StreamPersistenceService()
    private var cancellables = Set<AnyCancellable>()
    
    // Performance monitoring
    @Published var performanceMetrics = PerformanceMetrics()
    private var performanceTimer: Timer?
    
    private init() {
        setupInitialLayout()
        setupPerformanceMonitoring()
        loadPersistedState()
    }
    
    deinit {
        performanceTimer?.invalidate()
    }
    
    // MARK: - Layout Management
    func setupInitialLayout() {
        updateLayout(currentLayout)
    }
    
    func updateLayout(_ layout: MultiStreamLayout) {
        let previousLayout = currentLayout
        currentLayout = layout
        let slotCount = layout.maxStreams
        
        var newSlots = (0..<slotCount).map { StreamSlot(position: $0) }
        
        // Preserve existing streams up to the new slot count
        for i in 0..<min(activeStreams.count, slotCount) {
            newSlots[i].stream = activeStreams[i].stream
            newSlots[i].quality = activeStreams[i].quality
        }
        
        activeStreams = newSlots
        
        // Auto-optimize quality based on layout
        if layout.maxStreams > previousLayout.maxStreams {
            autoOptimizeQualityForLayout(layout)
        }
        
        // Persist the layout change
        persistCurrentState()
        
        // Update performance metrics
        updatePerformanceMetrics()
    }
    
    // MARK: - Stream Management
    func addStream(_ stream: TwitchStream, to slotIndex: Int) {
        guard slotIndex < activeStreams.count else { return }
        
        activeStreams[slotIndex].stream = stream
        activeStreams[slotIndex].quality = streamQualities[stream.id] ?? globalQuality
        
        // Initialize stream state
        streamStates[stream.id] = .loading
        
        // Auto-optimize quality if needed
        if shouldAutoOptimizeQuality() {
            autoOptimizeQualityForActiveStreams()
        }
        
        // Persist the change
        persistCurrentState()
        
        // Update performance metrics
        updatePerformanceMetrics()
        
        // Notify analytics
        recordStreamEvent(.streamAdded, streamId: stream.id)
    }
    
    func removeStream(from slotIndex: Int) {
        guard slotIndex < activeStreams.count,
              let stream = activeStreams[slotIndex].stream else { return }
        
        // Clean up stream state
        streamStates.removeValue(forKey: stream.id)
        streamQualities.removeValue(forKey: stream.id)
        
        activeStreams[slotIndex].stream = nil
        activeStreams[slotIndex].quality = globalQuality
        
        // Persist the change
        persistCurrentState()
        
        // Update performance metrics
        updatePerformanceMetrics()
        
        // Notify analytics
        recordStreamEvent(.streamRemoved, streamId: stream.id)
    }
    
    func clearAll() {
        let removedStreams = activeStreams.compactMap { $0.stream }
        
        for i in 0..<activeStreams.count {
            activeStreams[i].stream = nil
            activeStreams[i].quality = globalQuality
        }
        
        // Clean up all stream states
        streamStates.removeAll()
        streamQualities.removeAll()
        
        // Persist the change
        persistCurrentState()
        
        // Update performance metrics
        updatePerformanceMetrics()
        
        // Notify analytics
        for stream in removedStreams {
            recordStreamEvent(.streamRemoved, streamId: stream.id)
        }
    }
    
    func moveStream(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < activeStreams.count,
              destinationIndex < activeStreams.count,
              sourceIndex != destinationIndex else { return }
        
        let sourceSlot = activeStreams[sourceIndex]
        activeStreams[sourceIndex] = activeStreams[destinationIndex]
        activeStreams[destinationIndex] = sourceSlot
        
        // Update positions
        activeStreams[sourceIndex].position = sourceIndex
        activeStreams[destinationIndex].position = destinationIndex
        
        persistCurrentState()
    }
    
    // MARK: - Quality Management
    func setGlobalQuality(_ quality: StreamQuality) {
        globalQuality = quality
        
        // Apply to all streams that don't have individual quality settings
        for i in 0..<activeStreams.count {
            if let stream = activeStreams[i].stream,
               streamQualities[stream.id] == nil {
                activeStreams[i].quality = quality
            }
        }
        
        persistCurrentState()
        updatePerformanceMetrics()
    }
    
    func setStreamQuality(_ quality: StreamQuality, for streamId: String) {
        streamQualities[streamId] = quality
        
        if let index = activeStreams.firstIndex(where: { $0.stream?.id == streamId }) {
            activeStreams[index].quality = quality
        }
        
        persistCurrentState()
        updatePerformanceMetrics()
    }
    
    func getStreamQuality(for streamId: String) -> StreamQuality {
        return streamQualities[streamId] ?? globalQuality
    }
    
    private func autoOptimizeQualityForLayout(_ layout: MultiStreamLayout) {
        let recommendedQuality: StreamQuality
        
        switch layout.maxStreams {
        case 1:
            recommendedQuality = .source
        case 2...4:
            recommendedQuality = .high
        case 5...9:
            recommendedQuality = .medium
        default:
            recommendedQuality = .low
        }
        
        setGlobalQuality(recommendedQuality)
    }
    
    private func autoOptimizeQualityForActiveStreams() {
        let activeCount = activeStreams.filter { $0.stream != nil }.count
        
        let recommendedQuality: StreamQuality
        switch activeCount {
        case 0...1:
            recommendedQuality = .high
        case 2...4:
            recommendedQuality = .medium
        default:
            recommendedQuality = .low
        }
        
        if globalQuality.cpuMultiplier > recommendedQuality.cpuMultiplier {
            setGlobalQuality(recommendedQuality)
        }
    }
    
    private func shouldAutoOptimizeQuality() -> Bool {
        return performanceMetrics.cpuUsage > 80 || performanceMetrics.memoryUsage > 1024
    }
    
    // MARK: - Stream State Management
    func updateStreamState(_ state: StreamPlaybackState, for streamId: String) {
        streamStates[streamId] = state
        
        // Update performance metrics if needed
        if state == .playing {
            updatePerformanceMetrics()
        }
        
        recordStreamEvent(.stateChanged, streamId: streamId, metadata: ["state": state.rawValue])
    }
    
    func getStreamState(for streamId: String) -> StreamPlaybackState {
        return streamStates[streamId] ?? .loading
    }
    
    // MARK: - Performance Monitoring
    private func setupPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func updatePerformanceMetrics() {
        let activeCount = activeStreams.filter { $0.stream != nil }.count
        
        // Estimate CPU usage based on active streams and quality
        let baseCPU = activeCount * 15
        let qualityMultiplier = globalQuality.cpuMultiplier
        performanceMetrics.cpuUsage = min(100, Int(Double(baseCPU) * qualityMultiplier))
        
        // Estimate memory usage
        let baseMemory = activeCount * 150
        let memoryMultiplier = globalQuality.memoryMultiplier
        performanceMetrics.memoryUsage = Int(Double(baseMemory) * memoryMultiplier)
        
        // Estimate bandwidth usage
        let baseBandwidth = activeCount * 2
        let bandwidthMultiplier = globalQuality.bandwidthMultiplier
        performanceMetrics.bandwidthUsage = Int(Double(baseBandwidth) * bandwidthMultiplier)
        
        // Update last updated time
        performanceMetrics.lastUpdated = Date()
    }
    
    // MARK: - Persistence
    private func persistCurrentState() {
        let state = MultiStreamState(
            layout: currentLayout,
            streams: activeStreams.compactMap { slot in
                guard let stream = slot.stream else { return nil }
                return PersistedStream(
                    position: slot.position,
                    streamId: stream.id,
                    channelName: stream.userLogin,
                    quality: slot.quality
                )
            },
            globalQuality: globalQuality,
            timestamp: Date()
        )
        
        persistenceService.saveState(state)
    }
    
    private func loadPersistedState() {
        guard let state = persistenceService.loadState() else { return }
        
        // Only restore if the state is recent (within last 24 hours)
        guard Date().timeIntervalSince(state.timestamp) < 86400 else { return }
        
        currentLayout = state.layout
        globalQuality = state.globalQuality
        
        setupInitialLayout()
        
        // Note: We don't restore actual streams here to avoid auto-loading
        // streams on app launch. This would be done when user manually
        // loads a saved layout.
    }
    
    func saveCurrentLayoutAs(name: String) -> Bool {
        let layout = SavedLayout(
            name: name,
            layout: currentLayout,
            streams: activeStreams.compactMap { slot in
                guard let stream = slot.stream else { return nil }
                return PersistedStream(
                    position: slot.position,
                    streamId: stream.id,
                    channelName: stream.userLogin,
                    quality: slot.quality
                )
            },
            createdAt: Date()
        )
        
        return persistenceService.saveLayout(layout)
    }
    
    func loadSavedLayout(_ layout: SavedLayout) {
        currentLayout = layout.layout
        setupInitialLayout()
        
        // This would trigger loading the actual streams
        // Implementation would depend on how streams are fetched
    }
    
    func getSavedLayouts() -> [SavedLayout] {
        return persistenceService.getSavedLayouts()
    }
    
    func deleteSavedLayout(_ layout: SavedLayout) {
        persistenceService.deleteLayout(layout)
    }
    
    // MARK: - Analytics
    private func recordStreamEvent(_ event: StreamEvent, streamId: String, metadata: [String: String] = [:]) {
        let eventData = StreamEventData(
            event: event,
            streamId: streamId,
            layoutType: currentLayout.rawValue,
            timestamp: Date(),
            metadata: metadata
        )
        
        // This would be sent to an analytics service
        // For now, just log it
        print("Stream Event: \(event.rawValue) for \(streamId)")
    }
}

// MARK: - Supporting Models

struct PerformanceMetrics {
    var cpuUsage: Int = 0
    var memoryUsage: Int = 0 // MB
    var bandwidthUsage: Int = 0 // Mbps
    var activeStreams: Int = 0
    var lastUpdated = Date()
}

struct MultiStreamState: Codable {
    let layout: MultiStreamLayout
    let streams: [PersistedStream]
    let globalQuality: StreamQuality
    let timestamp: Date
}

struct PersistedStream: Codable, Identifiable {
    let id = UUID()
    let position: Int
    let streamId: String
    let channelName: String
    let quality: StreamQuality
}

struct SavedLayout: Codable, Identifiable {
    let id = UUID()
    let name: String
    let layout: MultiStreamLayout
    let streams: [PersistedStream]
    let createdAt: Date
}

enum StreamEvent: String, CaseIterable {
    case streamAdded = "stream_added"
    case streamRemoved = "stream_removed"
    case stateChanged = "state_changed"
    case qualityChanged = "quality_changed"
    case layoutChanged = "layout_changed"
    case audioSwitched = "audio_switched"
}

struct StreamEventData {
    let event: StreamEvent
    let streamId: String
    let layoutType: String
    let timestamp: Date
    let metadata: [String: String]
}

// MARK: - Stream Persistence Service
class StreamPersistenceService {
    private let userDefaults = UserDefaults.standard
    private let stateKey = "MultiStreamState"
    private let layoutsKey = "SavedLayouts"
    
    func saveState(_ state: MultiStreamState) {
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: stateKey)
        } catch {
            print("Failed to save multi-stream state: \(error)")
        }
    }
    
    func loadState() -> MultiStreamState? {
        guard let data = userDefaults.data(forKey: stateKey) else { return nil }
        
        do {
            return try JSONDecoder().decode(MultiStreamState.self, from: data)
        } catch {
            print("Failed to load multi-stream state: \(error)")
            return nil
        }
    }
    
    func saveLayout(_ layout: SavedLayout) -> Bool {
        var layouts = getSavedLayouts()
        layouts.append(layout)
        
        do {
            let data = try JSONEncoder().encode(layouts)
            userDefaults.set(data, forKey: layoutsKey)
            return true
        } catch {
            print("Failed to save layout: \(error)")
            return false
        }
    }
    
    func getSavedLayouts() -> [SavedLayout] {
        guard let data = userDefaults.data(forKey: layoutsKey) else { return [] }
        
        do {
            return try JSONDecoder().decode([SavedLayout].self, from: data)
        } catch {
            print("Failed to load saved layouts: \(error)")
            return []
        }
    }
    
    func deleteLayout(_ layout: SavedLayout) {
        var layouts = getSavedLayouts()
        layouts.removeAll { $0.id == layout.id }
        
        do {
            let data = try JSONEncoder().encode(layouts)
            userDefaults.set(data, forKey: layoutsKey)
        } catch {
            print("Failed to delete layout: \(error)")
        }
    }
}

// MARK: - Stream Slot
struct StreamSlot: Identifiable, Codable, Equatable {
    static func == (lhs: StreamSlot, rhs: StreamSlot) -> Bool {
        lhs.id == rhs.id && lhs.stream?.id == rhs.stream?.id && lhs.quality == rhs.quality
    }
    
    let id = UUID()
    var position: Int
    var stream: TwitchStream?
    var quality: StreamQuality = .medium
    
    init(position: Int, stream: TwitchStream? = nil, quality: StreamQuality = .medium) {
        self.position = position
        self.stream = stream
        self.quality = quality
    }
}

// MARK: - Multi Stream Layout
enum MultiStreamLayout: String, CaseIterable, Identifiable {
    case single = "1x1"
    case twoByTwo = "2x2"
    case threeByThree = "3x3"
    case fourByFour = "4x4"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .single: return "Single"
        case .twoByTwo: return "2×2 Grid"
        case .threeByThree: return "3×3 Grid"
        case .fourByFour: return "4×4 Grid"
        }
    }
    
    var maxStreams: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 4
        case .threeByThree: return 9
        case .fourByFour: return 16
        }
    }
    
    var columns: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 2
        case .threeByThree: return 3
        case .fourByFour: return 4
        }
    }
    
    var icon: String {
        switch self {
        case .single: return "square"
        case .twoByTwo: return "grid"
        case .threeByThree: return "square.grid.3x3"
        case .fourByFour: return "square.grid.4x4"
        }
    }
}