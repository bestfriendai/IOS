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
    @Published var activeStreams: [StreamSlot] = []
    @Published var currentLayout: MultiStreamLayout = .twoByTwo
    
    init() {
        setupInitialLayout()
    }
    
    func setupInitialLayout() {
        updateLayout(currentLayout)
    }
    
    func updateLayout(_ layout: MultiStreamLayout) {
        currentLayout = layout
        let slotCount = layout.maxStreams
        
        var newSlots = (0..<slotCount).map { StreamSlot(position: $0) }
        
        // Preserve existing streams up to the new slot count
        for i in 0..<min(activeStreams.count, slotCount) {
            newSlots[i].stream = activeStreams[i].stream
        }
        
        activeStreams = newSlots
    }
    
    func addStream(_ stream: TwitchStream, to slotIndex: Int) {
        guard slotIndex < activeStreams.count else { return }
        activeStreams[slotIndex].stream = stream
    }
    
    func removeStream(from slotIndex: Int) {
        guard slotIndex < activeStreams.count else { return }
        activeStreams[slotIndex].stream = nil
    }
    
    func clearAll() {
        for i in 0..<activeStreams.count {
            activeStreams[i].stream = nil
        }
    }
}

// MARK: - Stream Slot
struct StreamSlot: Identifiable, Codable, Equatable {
    static func == (lhs: StreamSlot, rhs: StreamSlot) -> Bool {
        lhs.id == rhs.id && lhs.stream?.id == rhs.stream?.id
    }
    
    let id = UUID()
    let position: Int
    var stream: TwitchStream?
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