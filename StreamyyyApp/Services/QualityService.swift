//
//  QualityService.swift
//  StreamyyyApp
//
//  Advanced stream quality control and performance optimization system
//

import Foundation
import SwiftUI
import Combine
import Network
import AVKit
import CoreTelephony
import UIKit

// MARK: - Quality Service

@MainActor
public class QualityService: ObservableObject {
    public static let shared = QualityService()
    
    // MARK: - Published Properties
    @Published public var currentQuality: StreamQuality = .auto
    @Published public var availableQualities: [StreamQuality] = []
    @Published public var isAdaptiveQualityEnabled: Bool = true
    @Published public var networkCondition: NetworkCondition = .unknown
    @Published public var batteryState: BatteryState = .normal
    @Published public var thermalState: ThermalState = .normal
    @Published public var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    
    // MARK: - Private Properties
    private let networkMonitor = NetworkQualityMonitor()
    private let adaptiveController = AdaptiveQualityController()
    private let performanceMonitor = PerformanceMonitor()
    private let batteryOptimizer = BatteryOptimizer()
    private let healthDiagnostics = StreamHealthDiagnostics()
    private let qualityPresets = QualityPresets()
    
    private var cancellables = Set<AnyCancellable>()
    private var currentStream: String?
    private var qualityChangeTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        startMonitoring()
        loadUserPreferences()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // Network condition updates
        networkMonitor.$networkCondition
            .receive(on: DispatchQueue.main)
            .assign(to: \.networkCondition, on: self)
            .store(in: &cancellables)
        
        // Battery state updates
        batteryOptimizer.$batteryState
            .receive(on: DispatchQueue.main)
            .assign(to: \.batteryState, on: self)
            .store(in: &cancellables)
        
        // Thermal state updates
        performanceMonitor.$thermalState
            .receive(on: DispatchQueue.main)
            .assign(to: \.thermalState, on: self)
            .store(in: &cancellables)
        
        // Performance metrics updates
        performanceMonitor.$metrics
            .receive(on: DispatchQueue.main)
            .assign(to: \.performanceMetrics, on: self)
            .store(in: &cancellables)
        
        // Adaptive quality changes
        adaptiveController.$recommendedQuality
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newQuality in
                self?.handleAdaptiveQualityChange(newQuality)
            }
            .store(in: &cancellables)
    }
    
    private func startMonitoring() {
        networkMonitor.startMonitoring()
        performanceMonitor.startMonitoring()
        batteryOptimizer.startMonitoring()
        healthDiagnostics.startMonitoring()
    }
    
    private func stopMonitoring() {
        networkMonitor.stopMonitoring()
        performanceMonitor.stopMonitoring()
        batteryOptimizer.stopMonitoring()
        healthDiagnostics.stopMonitoring()
    }
    
    private func loadUserPreferences() {
        let preferences = qualityPresets.loadPreferences()
        isAdaptiveQualityEnabled = preferences.adaptiveQuality
        currentQuality = preferences.defaultQuality
    }
    
    // MARK: - Public Methods
    
    public func configureForStream(url: String, platform: Platform) {
        currentStream = url
        availableQualities = platform.availableQualities
        
        // Update adaptive controller with stream info
        adaptiveController.configureForStream(url: url, platform: platform)
        
        // Start health diagnostics for this stream
        healthDiagnostics.configureForStream(url: url, platform: platform)
        
        // Apply quality based on current conditions
        updateQualityForCurrentConditions()
    }
    
    public func setQuality(_ quality: StreamQuality, userInitiated: Bool = false) {
        guard availableQualities.contains(quality) else { return }
        
        if userInitiated {
            isAdaptiveQualityEnabled = false
            qualityPresets.updatePreferences { preferences in
                preferences.adaptiveQuality = false
                preferences.defaultQuality = quality
            }
        }
        
        currentQuality = quality
        notifyQualityChange(quality)
    }
    
    public func enableAdaptiveQuality() {
        isAdaptiveQualityEnabled = true
        qualityPresets.updatePreferences { preferences in
            preferences.adaptiveQuality = true
        }
        updateQualityForCurrentConditions()
    }
    
    public func disableAdaptiveQuality() {
        isAdaptiveQualityEnabled = false
        qualityPresets.updatePreferences { preferences in
            preferences.adaptiveQuality = false
        }
    }
    
    public func getOptimalQuality() -> StreamQuality {
        return adaptiveController.getOptimalQuality(
            networkCondition: networkCondition,
            batteryState: batteryState,
            thermalState: thermalState,
            performanceMetrics: performanceMetrics
        )
    }
    
    public func forceQualityCheck() {
        updateQualityForCurrentConditions()
    }
    
    // MARK: - Private Methods
    
    private func updateQualityForCurrentConditions() {
        guard isAdaptiveQualityEnabled else { return }
        
        let optimalQuality = getOptimalQuality()
        
        // Only change if significantly different
        if shouldChangeQuality(from: currentQuality, to: optimalQuality) {
            setQuality(optimalQuality, userInitiated: false)
        }
    }
    
    private func shouldChangeQuality(from current: StreamQuality, to new: StreamQuality) -> Bool {
        // Avoid frequent quality changes
        guard qualityChangeTimer == nil else { return false }
        
        // Check if change is significant enough
        let currentBitrate = current.bitrate
        let newBitrate = new.bitrate
        
        let difference = abs(currentBitrate - newBitrate)
        let threshold = currentBitrate * 0.3 // 30% difference threshold
        
        return difference > threshold
    }
    
    private func handleAdaptiveQualityChange(_ newQuality: StreamQuality) {
        guard isAdaptiveQualityEnabled else { return }
        
        // Debounce quality changes
        qualityChangeTimer?.invalidate()
        qualityChangeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.setQuality(newQuality, userInitiated: false)
            self?.qualityChangeTimer = nil
        }
    }
    
    private func notifyQualityChange(_ quality: StreamQuality) {
        // Notify any observers about quality change
        NotificationCenter.default.post(
            name: .streamQualityChanged,
            object: self,
            userInfo: [
                "quality": quality,
                "stream": currentStream ?? "",
                "metrics": performanceMetrics
            ]
        )
    }
}

// MARK: - Network Quality Monitor

public class NetworkQualityMonitor: ObservableObject {
    @Published public var networkCondition: NetworkCondition = .unknown
    @Published public var bandwidth: Double = 0.0
    @Published public var latency: Double = 0.0
    @Published public var packetLoss: Double = 0.0
    
    private let pathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkQualityMonitor")
    private var currentPath: NWPath?
    
    public func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        pathMonitor.start(queue: queue)
    }
    
    public func stopMonitoring() {
        pathMonitor.cancel()
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        currentPath = path
        
        DispatchQueue.main.async { [weak self] in
            self?.updateNetworkCondition(path)
        }
        
        // Perform detailed network quality tests
        performBandwidthTest()
        performLatencyTest()
    }
    
    private func updateNetworkCondition(_ path: NWPath) {
        guard path.status == .satisfied else {
            networkCondition = .offline
            return
        }
        
        if path.isExpensive {
            networkCondition = .cellular
        } else if path.usesInterfaceType(.wifi) {
            networkCondition = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            networkCondition = .ethernet
        } else {
            networkCondition = .unknown
        }
    }
    
    private func performBandwidthTest() {
        // Simplified bandwidth estimation
        // In a real implementation, you'd perform actual bandwidth tests
        Task {
            let estimatedBandwidth = estimateBandwidth()
            
            await MainActor.run {
                self.bandwidth = estimatedBandwidth
            }
        }
    }
    
    private func performLatencyTest() {
        // Simplified latency test
        // In a real implementation, you'd ping test servers
        Task {
            let estimatedLatency = estimateLatency()
            
            await MainActor.run {
                self.latency = estimatedLatency
            }
        }
    }
    
    private func estimateBandwidth() -> Double {
        // Simplified bandwidth estimation based on connection type
        guard let path = currentPath else { return 0.0 }
        
        if path.usesInterfaceType(.wiredEthernet) {
            return 100.0 // Mbps
        } else if path.usesInterfaceType(.wifi) {
            return 25.0 // Mbps
        } else if path.usesInterfaceType(.cellular) {
            return 5.0 // Mbps
        } else {
            return 1.0 // Mbps
        }
    }
    
    private func estimateLatency() -> Double {
        // Simplified latency estimation
        guard let path = currentPath else { return 1000.0 }
        
        if path.usesInterfaceType(.wiredEthernet) {
            return 10.0 // ms
        } else if path.usesInterfaceType(.wifi) {
            return 25.0 // ms
        } else if path.usesInterfaceType(.cellular) {
            return 100.0 // ms
        } else {
            return 500.0 // ms
        }
    }
}

// MARK: - Adaptive Quality Controller

public class AdaptiveQualityController: ObservableObject {
    @Published public var recommendedQuality: StreamQuality = .auto
    
    private var currentPlatform: Platform?
    private var availableQualities: [StreamQuality] = []
    
    public func configureForStream(url: String, platform: Platform) {
        currentPlatform = platform
        availableQualities = platform.availableQualities
    }
    
    public func getOptimalQuality(
        networkCondition: NetworkCondition,
        batteryState: BatteryState,
        thermalState: ThermalState,
        performanceMetrics: PerformanceMetrics
    ) -> StreamQuality {
        
        var targetQuality: StreamQuality = .auto
        
        // Base quality on network condition
        switch networkCondition {
        case .ethernet:
            targetQuality = .hd1080
        case .wifi:
            targetQuality = .hd720
        case .cellular:
            targetQuality = .medium
        case .offline, .unknown:
            targetQuality = .low
        }
        
        // Adjust for battery state
        if batteryState == .low {
            targetQuality = downgradeQuality(targetQuality)
        }
        
        // Adjust for thermal state
        if thermalState == .hot {
            targetQuality = downgradeQuality(targetQuality)
        }
        
        // Adjust for performance metrics
        if performanceMetrics.frameDropRate > 0.1 {
            targetQuality = downgradeQuality(targetQuality)
        }
        
        // Ensure quality is available
        if !availableQualities.contains(targetQuality) {
            targetQuality = findClosestAvailableQuality(targetQuality)
        }
        
        return targetQuality
    }
    
    private func downgradeQuality(_ quality: StreamQuality) -> StreamQuality {
        switch quality {
        case .hd1080:
            return .hd720
        case .hd720, .high:
            return .medium
        case .medium:
            return .low
        case .low:
            return .mobile
        case .mobile:
            return .mobile
        case .auto, .source:
            return .medium
        }
    }
    
    private func findClosestAvailableQuality(_ targetQuality: StreamQuality) -> StreamQuality {
        let qualityOrder: [StreamQuality] = [.hd1080, .hd720, .high, .medium, .low, .mobile]
        
        guard let targetIndex = qualityOrder.firstIndex(of: targetQuality) else {
            return availableQualities.first ?? .auto
        }
        
        // Look for closest available quality
        for i in 0..<qualityOrder.count {
            let lowerIndex = targetIndex - i
            let higherIndex = targetIndex + i
            
            if lowerIndex >= 0 && availableQualities.contains(qualityOrder[lowerIndex]) {
                return qualityOrder[lowerIndex]
            }
            
            if higherIndex < qualityOrder.count && availableQualities.contains(qualityOrder[higherIndex]) {
                return qualityOrder[higherIndex]
            }
        }
        
        return availableQualities.first ?? .auto
    }
}

// MARK: - Supporting Types

public enum NetworkCondition: String, CaseIterable {
    case ethernet = "ethernet"
    case wifi = "wifi"
    case cellular = "cellular"
    case offline = "offline"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .ethernet: return "Ethernet"
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .offline: return "Offline"
        case .unknown: return "Unknown"
        }
    }
}

public enum BatteryState: String, CaseIterable {
    case normal = "normal"
    case low = "low"
    case critical = "critical"
    case charging = "charging"
    
    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .low: return "Low"
        case .critical: return "Critical"
        case .charging: return "Charging"
        }
    }
}

public enum ThermalState: String, CaseIterable {
    case normal = "normal"
    case warm = "warm"
    case hot = "hot"
    case critical = "critical"
    
    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .warm: return "Warm"
        case .hot: return "Hot"
        case .critical: return "Critical"
        }
    }
}

public struct PerformanceMetrics {
    public var frameRate: Double = 0.0
    public var frameDropRate: Double = 0.0
    public var bufferHealth: Double = 0.0
    public var cpuUsage: Double = 0.0
    public var memoryUsage: Double = 0.0
    public var networkThroughput: Double = 0.0
    public var timestamp: Date = Date()
}

// MARK: - Notification Names

extension Notification.Name {
    public static let streamQualityChanged = Notification.Name("streamQualityChanged")
    public static let networkConditionChanged = Notification.Name("networkConditionChanged")
    public static let performanceMetricsUpdated = Notification.Name("performanceMetricsUpdated")
}