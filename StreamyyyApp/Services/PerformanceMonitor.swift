//
//  PerformanceMonitor.swift
//  StreamyyyApp
//
//  Advanced performance monitoring for stream quality optimization
//

import Foundation
import SwiftUI
import Combine
import AVKit
import UIKit
import CoreTelephony

// MARK: - Performance Monitor

public class PerformanceMonitor: ObservableObject {
    @Published public var metrics: PerformanceMetrics = PerformanceMetrics()
    @Published public var thermalState: ThermalState = .normal
    @Published public var cpuUsage: Double = 0.0
    @Published public var memoryUsage: Double = 0.0
    @Published public var frameRate: Double = 0.0
    @Published public var frameDropRate: Double = 0.0
    
    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var droppedFrames: Int = 0
    
    private var thermalStateObserver: NSObjectProtocol?
    private var memoryWarningObserver: NSObjectProtocol?
    
    private let monitoringQueue = DispatchQueue(label: "PerformanceMonitor", qos: .utility)
    private var monitoringTimer: Timer?
    
    public func startMonitoring() {
        setupDisplayLink()
        setupThermalMonitoring()
        setupMemoryMonitoring()
        startPeriodicMonitoring()
    }
    
    public func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - Display Link Setup
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.add(to: .current, forMode: .default)
    }
    
    @objc private func displayLinkCallback(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        if lastFrameTime > 0 {
            let deltaTime = currentTime - lastFrameTime
            
            if deltaTime > 0 {
                let currentFrameRate = 1.0 / deltaTime
                
                // Update frame rate with smoothing
                DispatchQueue.main.async { [weak self] in
                    self?.updateFrameRate(currentFrameRate)
                }
            }
        }
        
        lastFrameTime = currentTime
        frameCount += 1
        
        // Detect dropped frames
        let expectedFrames = Int(displayLink.targetTimestamp - displayLink.timestamp) * 60
        if expectedFrames > 1 {
            droppedFrames += expectedFrames - 1
            
            DispatchQueue.main.async { [weak self] in
                self?.updateFrameDropRate()
            }
        }
    }
    
    private func updateFrameRate(_ newFrameRate: Double) {
        // Smooth frame rate updates
        let smoothingFactor = 0.1
        frameRate = (frameRate * (1.0 - smoothingFactor)) + (newFrameRate * smoothingFactor)
        
        // Update metrics
        metrics.frameRate = frameRate
        metrics.timestamp = Date()
    }
    
    private func updateFrameDropRate() {
        let totalFrames = frameCount
        guard totalFrames > 0 else { return }
        
        frameDropRate = Double(droppedFrames) / Double(totalFrames)
        metrics.frameDropRate = frameDropRate
    }
    
    // MARK: - Thermal Monitoring
    
    private func setupThermalMonitoring() {
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateThermalState()
        }
        
        updateThermalState()
    }
    
    private func updateThermalState() {
        let processInfo = ProcessInfo.processInfo
        
        switch processInfo.thermalState {
        case .nominal:
            thermalState = .normal
        case .fair:
            thermalState = .warm
        case .serious:
            thermalState = .hot
        case .critical:
            thermalState = .critical
        @unknown default:
            thermalState = .normal
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func setupMemoryMonitoring() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        // Update memory usage immediately when warning is received
        updateMemoryUsage()
        
        // Notify about memory pressure
        NotificationCenter.default.post(
            name: .memoryPressureDetected,
            object: self,
            userInfo: ["memoryUsage": memoryUsage]
        )
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageBytes = info.resident_size
            let memoryUsageMB = Double(memoryUsageBytes) / 1024.0 / 1024.0
            
            // Get total physical memory
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            
            memoryUsage = memoryUsageMB / totalMemory
            metrics.memoryUsage = memoryUsage
        }
    }
    
    // MARK: - CPU Monitoring
    
    private func updateCPUUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // Get thread info for CPU usage
            var threadCount: mach_msg_type_number_t = 0
            var threadList: thread_act_array_t? = nil
            
            let threadResult = task_threads(mach_task_self_, &threadList, &threadCount)
            
            if threadResult == KERN_SUCCESS {
                var totalCPUUsage: Double = 0.0
                
                for i in 0..<threadCount {
                    var threadInfo = thread_basic_info()
                    var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                    
                    let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                            thread_info(threadList![Int(i)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                        }
                    }
                    
                    if infoResult == KERN_SUCCESS {
                        if threadInfo.flags & TH_FLAGS_IDLE == 0 {
                            totalCPUUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                        }
                    }
                }
                
                // Clean up thread list
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList), vm_size_t(threadCount * MemoryLayout<thread_t>.size))
                
                cpuUsage = totalCPUUsage
                metrics.cpuUsage = cpuUsage
            }
        }
    }
    
    // MARK: - Periodic Monitoring
    
    private func startPeriodicMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.performPeriodicUpdate()
        }
    }
    
    private func performPeriodicUpdate() {
        monitoringQueue.async { [weak self] in
            self?.updateCPUUsage()
            self?.updateMemoryUsage()
            self?.updateNetworkThroughput()
            
            DispatchQueue.main.async {
                self?.updateMetrics()
            }
        }
    }
    
    private func updateNetworkThroughput() {
        // This would typically measure actual network throughput
        // For now, we'll use a placeholder implementation
        metrics.networkThroughput = 0.0
    }
    
    private func updateMetrics() {
        metrics.timestamp = Date()
        
        // Post performance metrics update notification
        NotificationCenter.default.post(
            name: .performanceMetricsUpdated,
            object: self,
            userInfo: ["metrics": metrics]
        )
    }
    
    // MARK: - Buffer Health Monitoring
    
    public func updateBufferHealth(_ bufferHealth: Double) {
        metrics.bufferHealth = bufferHealth
        updateMetrics()
    }
    
    // MARK: - Performance Analysis
    
    public func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            frameRate: frameRate,
            frameDropRate: frameDropRate,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            thermalState: thermalState,
            bufferHealth: metrics.bufferHealth,
            timestamp: Date()
        )
    }
    
    public func isPerformanceGood() -> Bool {
        return frameDropRate < 0.05 && // Less than 5% frame drops
               cpuUsage < 0.8 && // Less than 80% CPU usage
               memoryUsage < 0.8 && // Less than 80% memory usage
               thermalState != .critical
    }
    
    public func getPerformanceRecommendations() -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        if frameDropRate > 0.1 {
            recommendations.append(.reduceQuality)
        }
        
        if cpuUsage > 0.8 {
            recommendations.append(.reduceCPULoad)
        }
        
        if memoryUsage > 0.8 {
            recommendations.append(.reduceMemoryUsage)
        }
        
        if thermalState == .hot || thermalState == .critical {
            recommendations.append(.reduceThermalLoad)
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

public struct PerformanceReport {
    public let frameRate: Double
    public let frameDropRate: Double
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let thermalState: ThermalState
    public let bufferHealth: Double
    public let timestamp: Date
    
    public var performanceScore: Double {
        var score = 100.0
        
        // Frame rate impact
        if frameRate < 30 {
            score -= 20
        } else if frameRate < 60 {
            score -= 10
        }
        
        // Frame drop impact
        score -= frameDropRate * 100
        
        // CPU usage impact
        score -= cpuUsage * 30
        
        // Memory usage impact
        score -= memoryUsage * 20
        
        // Thermal state impact
        switch thermalState {
        case .normal:
            break
        case .warm:
            score -= 5
        case .hot:
            score -= 15
        case .critical:
            score -= 30
        }
        
        return max(0, min(100, score))
    }
}

public enum PerformanceRecommendation {
    case reduceQuality
    case reduceCPULoad
    case reduceMemoryUsage
    case reduceThermalLoad
    case enablePowerSaving
    case closeOtherApps
    case restartApp
    
    public var displayText: String {
        switch self {
        case .reduceQuality:
            return "Reduce stream quality to improve performance"
        case .reduceCPULoad:
            return "Close other apps to reduce CPU load"
        case .reduceMemoryUsage:
            return "Restart app to free memory"
        case .reduceThermalLoad:
            return "Let device cool down"
        case .enablePowerSaving:
            return "Enable power saving mode"
        case .closeOtherApps:
            return "Close other apps"
        case .restartApp:
            return "Restart the app"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let memoryPressureDetected = Notification.Name("memoryPressureDetected")
    public static let thermalStateChanged = Notification.Name("thermalStateChanged")
}