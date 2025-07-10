//
//  BatteryOptimizer.swift
//  StreamyyyApp
//
//  Battery-aware streaming optimizations for extended viewing
//

import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Battery Optimizer

public class BatteryOptimizer: ObservableObject {
    @Published public var batteryState: BatteryState = .normal
    @Published public var batteryLevel: Float = 1.0
    @Published public var isLowPowerModeEnabled: Bool = false
    @Published public var powerSavingMode: PowerSavingMode = .disabled
    @Published public var estimatedWatchTime: TimeInterval = 0
    
    private var batteryObserver: NSObjectProtocol?
    private var powerModeObserver: NSObjectProtocol?
    
    private let batteryMonitoringQueue = DispatchQueue(label: "BatteryOptimizer", qos: .utility)
    private var monitoringTimer: Timer?
    
    // Battery usage tracking
    private var initialBatteryLevel: Float = 1.0
    private var sessionStartTime: Date = Date()
    private var batteryUsageHistory: [BatteryUsagePoint] = []
    
    public func startMonitoring() {
        setupBatteryMonitoring()
        setupPowerModeMonitoring()
        startPeriodicMonitoring()
        
        // Initialize session
        sessionStartTime = Date()
        initialBatteryLevel = UIDevice.current.batteryLevel
        updateBatteryState()
    }
    
    public func stopMonitoring() {
        if let observer = batteryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if let observer = powerModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - Battery Monitoring Setup
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        batteryObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBatteryState()
        }
    }
    
    private func setupPowerModeMonitoring() {
        powerModeObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePowerMode()
        }
        
        updatePowerMode()
    }
    
    private func updateBatteryState() {
        batteryLevel = UIDevice.current.batteryLevel
        
        // Update battery state based on level
        switch batteryLevel {
        case 0.0...0.1:
            batteryState = .critical
        case 0.1...0.2:
            batteryState = .low
        case 0.8...1.0:
            batteryState = UIDevice.current.batteryState == .charging ? .charging : .normal
        default:
            batteryState = .normal
        }
        
        // Track battery usage
        recordBatteryUsage()
        
        // Update estimated watch time
        updateEstimatedWatchTime()
        
        // Auto-enable power saving if needed
        checkForAutoPowerSaving()
    }
    
    private func updatePowerMode() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerModeEnabled && powerSavingMode == .disabled {
            powerSavingMode = .moderate
        }
    }
    
    // MARK: - Battery Usage Tracking
    
    private func recordBatteryUsage() {
        let usagePoint = BatteryUsagePoint(
            timestamp: Date(),
            batteryLevel: batteryLevel,
            sessionDuration: Date().timeIntervalSince(sessionStartTime)
        )
        
        batteryUsageHistory.append(usagePoint)
        
        // Keep only last 100 points
        if batteryUsageHistory.count > 100 {
            batteryUsageHistory.removeFirst()
        }
    }
    
    private func updateEstimatedWatchTime() {
        guard batteryUsageHistory.count >= 2 else {
            estimatedWatchTime = 0
            return
        }
        
        // Calculate average battery drain rate
        let recentUsage = batteryUsageHistory.suffix(10)
        let totalDrain = recentUsage.first!.batteryLevel - recentUsage.last!.batteryLevel
        let timeDuration = recentUsage.last!.timestamp.timeIntervalSince(recentUsage.first!.timestamp)
        
        guard totalDrain > 0 && timeDuration > 0 else {
            estimatedWatchTime = 0
            return
        }
        
        let drainRate = totalDrain / timeDuration
        estimatedWatchTime = Double(batteryLevel) / drainRate
    }
    
    // MARK: - Power Saving Controls
    
    public func setPowerSavingMode(_ mode: PowerSavingMode) {
        powerSavingMode = mode
        applyPowerSavingSettings()
        
        // Save preference
        UserDefaults.standard.set(mode.rawValue, forKey: "PowerSavingMode")
    }
    
    private func applyPowerSavingSettings() {
        switch powerSavingMode {
        case .disabled:
            // No power saving optimizations
            break
            
        case .moderate:
            // Moderate power saving
            applyModeratePowerSaving()
            
        case .aggressive:
            // Aggressive power saving
            applyAggressivePowerSaving()
            
        case .emergency:
            // Emergency power saving
            applyEmergencyPowerSaving()
        }
        
        // Notify about power saving changes
        NotificationCenter.default.post(
            name: .powerSavingModeChanged,
            object: self,
            userInfo: [
                "mode": powerSavingMode,
                "batteryLevel": batteryLevel
            ]
        )
    }
    
    private func applyModeratePowerSaving() {
        // Reduce refresh rate
        // Limit concurrent streams
        // Reduce quality slightly
        let recommendations = PowerSavingRecommendations(
            maxQuality: .hd720,
            maxConcurrentStreams: 2,
            reduceFrameRate: true,
            disableHaptics: false,
            dimScreen: false
        )
        
        applyRecommendations(recommendations)
    }
    
    private func applyAggressivePowerSaving() {
        // More aggressive optimizations
        let recommendations = PowerSavingRecommendations(
            maxQuality: .medium,
            maxConcurrentStreams: 1,
            reduceFrameRate: true,
            disableHaptics: true,
            dimScreen: false
        )
        
        applyRecommendations(recommendations)
    }
    
    private func applyEmergencyPowerSaving() {
        // Emergency mode - minimal functionality
        let recommendations = PowerSavingRecommendations(
            maxQuality: .low,
            maxConcurrentStreams: 1,
            reduceFrameRate: true,
            disableHaptics: true,
            dimScreen: true
        )
        
        applyRecommendations(recommendations)
    }
    
    private func applyRecommendations(_ recommendations: PowerSavingRecommendations) {
        // Apply recommendations through quality service
        NotificationCenter.default.post(
            name: .powerSavingRecommendationsChanged,
            object: self,
            userInfo: ["recommendations": recommendations]
        )
    }
    
    // MARK: - Auto Power Saving
    
    private func checkForAutoPowerSaving() {
        // Auto-enable power saving based on battery level
        if batteryLevel < 0.1 && powerSavingMode != .emergency {
            setPowerSavingMode(.emergency)
        } else if batteryLevel < 0.2 && powerSavingMode == .disabled {
            setPowerSavingMode(.aggressive)
        } else if batteryLevel < 0.3 && powerSavingMode == .disabled {
            setPowerSavingMode(.moderate)
        }
    }
    
    // MARK: - Periodic Monitoring
    
    private func startPeriodicMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performPeriodicUpdate()
        }
    }
    
    private func performPeriodicUpdate() {
        batteryMonitoringQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.updateBatteryState()
                self?.analyzeUsagePatterns()
            }
        }
    }
    
    private func analyzeUsagePatterns() {
        // Analyze battery usage patterns for optimization
        guard batteryUsageHistory.count >= 10 else { return }
        
        let recentUsage = batteryUsageHistory.suffix(10)
        let averageDrain = recentUsage.map { $0.batteryLevel }.reduce(0, +) / Float(recentUsage.count)
        
        // Suggest optimizations based on usage patterns
        if averageDrain > 0.01 { // High drain rate
            suggestOptimizations()
        }
    }
    
    private func suggestOptimizations() {
        let suggestions = BatteryOptimizationSuggestions(
            enablePowerSaving: powerSavingMode == .disabled,
            reduceQuality: true,
            limitConcurrentStreams: true,
            enableAudioOnlyMode: batteryLevel < 0.15
        )
        
        NotificationCenter.default.post(
            name: .batteryOptimizationSuggested,
            object: self,
            userInfo: ["suggestions": suggestions]
        )
    }
    
    // MARK: - Public Utilities
    
    public func getBatteryReport() -> BatteryReport {
        return BatteryReport(
            currentLevel: batteryLevel,
            batteryState: batteryState,
            powerSavingMode: powerSavingMode,
            estimatedWatchTime: estimatedWatchTime,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            totalDrain: initialBatteryLevel - batteryLevel,
            isLowPowerModeEnabled: isLowPowerModeEnabled
        )
    }
    
    public func getRecommendedQuality() -> StreamQuality {
        switch powerSavingMode {
        case .disabled:
            return batteryLevel > 0.5 ? .hd720 : .medium
        case .moderate:
            return .medium
        case .aggressive:
            return .low
        case .emergency:
            return .mobile
        }
    }
    
    public func shouldLimitConcurrentStreams() -> Bool {
        return powerSavingMode != .disabled || batteryLevel < 0.3
    }
    
    public func getMaxConcurrentStreams() -> Int {
        switch powerSavingMode {
        case .disabled:
            return batteryLevel > 0.5 ? 4 : 2
        case .moderate:
            return 2
        case .aggressive:
            return 1
        case .emergency:
            return 1
        }
    }
}

// MARK: - Supporting Types

public enum PowerSavingMode: String, CaseIterable {
    case disabled = "disabled"
    case moderate = "moderate"
    case aggressive = "aggressive"
    case emergency = "emergency"
    
    public var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .moderate: return "Moderate"
        case .aggressive: return "Aggressive"
        case .emergency: return "Emergency"
        }
    }
}

public struct BatteryUsagePoint {
    public let timestamp: Date
    public let batteryLevel: Float
    public let sessionDuration: TimeInterval
}

public struct PowerSavingRecommendations {
    public let maxQuality: StreamQuality
    public let maxConcurrentStreams: Int
    public let reduceFrameRate: Bool
    public let disableHaptics: Bool
    public let dimScreen: Bool
}

public struct BatteryOptimizationSuggestions {
    public let enablePowerSaving: Bool
    public let reduceQuality: Bool
    public let limitConcurrentStreams: Bool
    public let enableAudioOnlyMode: Bool
}

public struct BatteryReport {
    public let currentLevel: Float
    public let batteryState: BatteryState
    public let powerSavingMode: PowerSavingMode
    public let estimatedWatchTime: TimeInterval
    public let sessionDuration: TimeInterval
    public let totalDrain: Float
    public let isLowPowerModeEnabled: Bool
    
    public var efficiency: Double {
        guard sessionDuration > 0 else { return 0 }
        return Double(totalDrain) / sessionDuration * 3600 // Battery drain per hour
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let powerSavingModeChanged = Notification.Name("powerSavingModeChanged")
    public static let powerSavingRecommendationsChanged = Notification.Name("powerSavingRecommendationsChanged")
    public static let batteryOptimizationSuggested = Notification.Name("batteryOptimizationSuggested")
}