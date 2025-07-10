//
//  PerformanceProfiler.swift
//  StreamyyyApp
//
//  Enhanced performance tracking and optimization insights
//

import Foundation
import SwiftUI
import Combine
import os.log
import MetricKit

// MARK: - Performance Profiler
class PerformanceProfiler: ObservableObject {
    static let shared = PerformanceProfiler()
    
    // MARK: - Published Properties
    @Published var isProfilerActive: Bool = false
    @Published var currentProfile: PerformanceProfile?
    @Published var profileHistory: [PerformanceProfile] = []
    @Published var optimizationInsights: [OptimizationInsight] = []
    @Published var bottlenecks: [PerformanceBottleneck] = []
    @Published var recommendedOptimizations: [PerformanceOptimization] = []
    
    // MARK: - Performance Metrics
    @Published var cpuProfileData: CPUProfileData = CPUProfileData()
    @Published var memoryProfileData: MemoryProfileData = MemoryProfileData()
    @Published var networkProfileData: NetworkProfileData = NetworkProfileData()
    @Published var renderingProfileData: RenderingProfileData = RenderingProfileData()
    @Published var batteryProfileData: BatteryProfileData = BatteryProfileData()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var profileStartTime: Date?
    private var performanceTimer: Timer?
    private var metricSubscriber: MXMetricManagerSubscriber?
    private var analyticsManager = AnalyticsManager.shared
    
    // MARK: - Profiling Configuration
    private let profilingInterval: TimeInterval = 1.0
    private let profileDuration: TimeInterval = 300.0 // 5 minutes
    private var profiledMethods: [String: MethodProfileData] = [:]
    
    // MARK: - Initialization
    private init() {
        setupPerformanceProfiler()
        setupMetricKit()
    }
    
    // MARK: - Setup
    private func setupPerformanceProfiler() {
        // Subscribe to app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.startProfiling()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.pauseProfiling()
            }
            .store(in: &cancellables)
    }
    
    private func setupMetricKit() {
        if #available(iOS 13.0, *) {
            metricSubscriber = MXMetricManagerSubscriber()
            MXMetricManager.shared.add(metricSubscriber!)
        }
    }
    
    // MARK: - Profiling Control
    func startProfiling() {
        guard !isProfilerActive else { return }
        
        isProfilerActive = true
        profileStartTime = Date()
        
        // Start performance monitoring
        performanceTimer = Timer.scheduledTimer(withTimeInterval: profilingInterval, repeats: true) { [weak self] _ in
            self?.collectPerformanceData()
        }
        
        // Initialize current profile
        currentProfile = PerformanceProfile(
            id: UUID(),
            startTime: Date(),
            sessionId: UUID().uuidString,
            appVersion: Config.App.version,
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion
        )
        
        analyticsManager.trackPerformanceProfilingStarted()
    }
    
    func stopProfiling() {
        guard isProfilerActive else { return }
        
        isProfilerActive = false
        performanceTimer?.invalidate()
        performanceTimer = nil
        
        // Finalize current profile
        if var profile = currentProfile {
            profile.endTime = Date()
            profile.duration = profile.endTime!.timeIntervalSince(profile.startTime)
            
            // Generate insights and recommendations
            generateOptimizationInsights(for: profile)
            generatePerformanceRecommendations(for: profile)
            
            // Save to history
            profileHistory.append(profile)
            
            // Keep only last 50 profiles
            if profileHistory.count > 50 {
                profileHistory.removeFirst()
            }
            
            currentProfile = nil
        }
        
        analyticsManager.trackPerformanceProfilingStopped()
    }
    
    func pauseProfiling() {
        guard isProfilerActive else { return }
        
        performanceTimer?.invalidate()
        performanceTimer = nil
    }
    
    func resumeProfiling() {
        guard isProfilerActive else { return }
        
        performanceTimer = Timer.scheduledTimer(withTimeInterval: profilingInterval, repeats: true) { [weak self] _ in
            self?.collectPerformanceData()
        }
    }
    
    // MARK: - Data Collection
    private func collectPerformanceData() {
        updateCPUProfile()
        updateMemoryProfile()
        updateNetworkProfile()
        updateRenderingProfile()
        updateBatteryProfile()
        
        // Check for bottlenecks
        detectBottlenecks()
        
        // Update current profile
        updateCurrentProfile()
    }
    
    private func updateCPUProfile() {
        let cpuUsage = getCurrentCPUUsage()
        let timestamp = Date()
        
        cpuProfileData.usage.append(CPUUsagePoint(timestamp: timestamp, usage: cpuUsage))
        cpuProfileData.currentUsage = cpuUsage
        
        // Calculate averages
        let recentUsage = cpuProfileData.usage.suffix(60) // Last 60 seconds
        cpuProfileData.averageUsage = recentUsage.map { $0.usage }.reduce(0, +) / Double(recentUsage.count)
        cpuProfileData.peakUsage = recentUsage.map { $0.usage }.max() ?? 0
        
        // Keep only last 300 data points (5 minutes)
        if cpuProfileData.usage.count > 300 {
            cpuProfileData.usage.removeFirst()
        }
    }
    
    private func updateMemoryProfile() {
        let memoryInfo = getCurrentMemoryUsage()
        let timestamp = Date()
        
        let memoryPoint = MemoryUsagePoint(
            timestamp: timestamp,
            used: memoryInfo.used,
            available: memoryInfo.available,
            pressure: memoryInfo.pressure
        )
        
        memoryProfileData.usage.append(memoryPoint)
        memoryProfileData.currentUsage = memoryInfo.used
        memoryProfileData.availableMemory = memoryInfo.available
        memoryProfileData.memoryPressure = memoryInfo.pressure
        
        // Calculate statistics
        let recentUsage = memoryProfileData.usage.suffix(60)
        memoryProfileData.averageUsage = recentUsage.map { $0.used }.reduce(0, +) / Double(recentUsage.count)
        memoryProfileData.peakUsage = recentUsage.map { $0.used }.max() ?? 0
        
        // Keep only last 300 data points
        if memoryProfileData.usage.count > 300 {
            memoryProfileData.usage.removeFirst()
        }
    }
    
    private func updateNetworkProfile() {
        let networkInfo = getCurrentNetworkUsage()
        let timestamp = Date()
        
        let networkPoint = NetworkUsagePoint(
            timestamp: timestamp,
            bytesReceived: networkInfo.bytesReceived,
            bytesSent: networkInfo.bytesSent,
            connectionType: networkInfo.connectionType,
            latency: networkInfo.latency
        )
        
        networkProfileData.usage.append(networkPoint)
        networkProfileData.totalBytesReceived = networkInfo.bytesReceived
        networkProfileData.totalBytesSent = networkInfo.bytesSent
        networkProfileData.currentLatency = networkInfo.latency
        
        // Calculate bandwidth
        if let previousPoint = networkProfileData.usage.dropLast().last {
            let timeDiff = timestamp.timeIntervalSince(previousPoint.timestamp)
            let bytesDiff = networkInfo.bytesReceived - previousPoint.bytesReceived
            networkProfileData.currentBandwidth = bytesDiff / timeDiff
        }
        
        // Keep only last 300 data points
        if networkProfileData.usage.count > 300 {
            networkProfileData.usage.removeFirst()
        }
    }
    
    private func updateRenderingProfile() {
        let renderingInfo = getCurrentRenderingMetrics()
        let timestamp = Date()
        
        let renderingPoint = RenderingMetricsPoint(
            timestamp: timestamp,
            frameRate: renderingInfo.frameRate,
            frameTime: renderingInfo.frameTime,
            droppedFrames: renderingInfo.droppedFrames,
            gpuUsage: renderingInfo.gpuUsage
        )
        
        renderingProfileData.metrics.append(renderingPoint)
        renderingProfileData.currentFrameRate = renderingInfo.frameRate
        renderingProfileData.averageFrameTime = renderingInfo.frameTime
        renderingProfileData.droppedFrameCount = renderingInfo.droppedFrames
        renderingProfileData.gpuUsage = renderingInfo.gpuUsage
        
        // Keep only last 300 data points
        if renderingProfileData.metrics.count > 300 {
            renderingProfileData.metrics.removeFirst()
        }
    }
    
    private func updateBatteryProfile() {
        let batteryInfo = getCurrentBatteryInfo()
        let timestamp = Date()
        
        let batteryPoint = BatteryUsagePoint(
            timestamp: timestamp,
            level: batteryInfo.level,
            state: batteryInfo.state,
            thermalState: batteryInfo.thermalState,
            lowPowerMode: batteryInfo.lowPowerMode
        )
        
        batteryProfileData.usage.append(batteryPoint)
        batteryProfileData.currentLevel = batteryInfo.level
        batteryProfileData.batteryState = batteryInfo.state
        batteryProfileData.thermalState = batteryInfo.thermalState
        batteryProfileData.isLowPowerMode = batteryInfo.lowPowerMode
        
        // Calculate battery drain rate
        if let previousPoint = batteryProfileData.usage.dropLast().last {
            let timeDiff = timestamp.timeIntervalSince(previousPoint.timestamp) / 3600.0 // Convert to hours
            let levelDiff = previousPoint.level - batteryInfo.level
            batteryProfileData.drainRate = levelDiff / timeDiff
        }
        
        // Keep only last 300 data points
        if batteryProfileData.usage.count > 300 {
            batteryProfileData.usage.removeFirst()
        }
    }
    
    // MARK: - Bottleneck Detection
    private func detectBottlenecks() {
        var detectedBottlenecks: [PerformanceBottleneck] = []
        
        // CPU bottlenecks
        if cpuProfileData.currentUsage > 0.8 {
            detectedBottlenecks.append(PerformanceBottleneck(
                type: .cpu,
                severity: cpuProfileData.currentUsage > 0.95 ? .critical : .high,
                description: "High CPU usage detected: \(Int(cpuProfileData.currentUsage * 100))%",
                metric: cpuProfileData.currentUsage,
                timestamp: Date()
            ))
        }
        
        // Memory bottlenecks
        if memoryProfileData.memoryPressure > 0.8 {
            detectedBottlenecks.append(PerformanceBottleneck(
                type: .memory,
                severity: memoryProfileData.memoryPressure > 0.95 ? .critical : .high,
                description: "High memory pressure detected: \(Int(memoryProfileData.memoryPressure * 100))%",
                metric: memoryProfileData.memoryPressure,
                timestamp: Date()
            ))
        }
        
        // Network bottlenecks
        if networkProfileData.currentLatency > 500 {
            detectedBottlenecks.append(PerformanceBottleneck(
                type: .network,
                severity: networkProfileData.currentLatency > 1000 ? .critical : .medium,
                description: "High network latency detected: \(Int(networkProfileData.currentLatency))ms",
                metric: networkProfileData.currentLatency,
                timestamp: Date()
            ))
        }
        
        // Rendering bottlenecks
        if renderingProfileData.currentFrameRate < 30 {
            detectedBottlenecks.append(PerformanceBottleneck(
                type: .rendering,
                severity: renderingProfileData.currentFrameRate < 15 ? .critical : .high,
                description: "Low frame rate detected: \(Int(renderingProfileData.currentFrameRate)) FPS",
                metric: renderingProfileData.currentFrameRate,
                timestamp: Date()
            ))
        }
        
        // Battery bottlenecks
        if batteryProfileData.drainRate > 15 {
            detectedBottlenecks.append(PerformanceBottleneck(
                type: .battery,
                severity: batteryProfileData.drainRate > 25 ? .critical : .medium,
                description: "High battery drain detected: \(Int(batteryProfileData.drainRate))% per hour",
                metric: batteryProfileData.drainRate,
                timestamp: Date()
            ))
        }
        
        // Update bottlenecks
        bottlenecks = detectedBottlenecks
        
        // Track bottlenecks
        for bottleneck in detectedBottlenecks {
            analyticsManager.trackPerformanceBottleneck(bottleneck)
        }
    }
    
    // MARK: - Optimization Insights
    private func generateOptimizationInsights(for profile: PerformanceProfile) {
        var insights: [OptimizationInsight] = []
        
        // CPU optimization insights
        if profile.averageCPUUsage > 0.7 {
            insights.append(OptimizationInsight(
                category: .cpu,
                title: "High CPU Usage",
                description: "Average CPU usage was \(Int(profile.averageCPUUsage * 100))% during this session",
                impact: .high,
                effort: .medium,
                recommendation: "Consider optimizing computationally intensive operations and using background queues",
                expectedImprovement: 0.2,
                timestamp: Date()
            ))
        }
        
        // Memory optimization insights
        if profile.averageMemoryUsage > 0.6 {
            insights.append(OptimizationInsight(
                category: .memory,
                title: "High Memory Usage",
                description: "Average memory usage was \(Int(profile.averageMemoryUsage * 100))% during this session",
                impact: .high,
                effort: .medium,
                recommendation: "Review memory allocation patterns and implement memory pooling for frequently allocated objects",
                expectedImprovement: 0.3,
                timestamp: Date()
            ))
        }
        
        // Network optimization insights
        if profile.averageNetworkLatency > 200 {
            insights.append(OptimizationInsight(
                category: .network,
                title: "High Network Latency",
                description: "Average network latency was \(Int(profile.averageNetworkLatency))ms during this session",
                impact: .medium,
                effort: .low,
                recommendation: "Implement request caching and optimize API calls to reduce network overhead",
                expectedImprovement: 0.4,
                timestamp: Date()
            ))
        }
        
        // Rendering optimization insights
        if profile.averageFrameRate < 45 {
            insights.append(OptimizationInsight(
                category: .rendering,
                title: "Low Frame Rate",
                description: "Average frame rate was \(Int(profile.averageFrameRate)) FPS during this session",
                impact: .high,
                effort: .high,
                recommendation: "Optimize rendering pipeline and reduce complex UI animations",
                expectedImprovement: 0.5,
                timestamp: Date()
            ))
        }
        
        optimizationInsights = insights
    }
    
    private func generatePerformanceRecommendations(for profile: PerformanceProfile) {
        var recommendations: [PerformanceOptimization] = []
        
        // CPU recommendations
        if profile.peakCPUUsage > 0.9 {
            recommendations.append(PerformanceOptimization(
                type: .cpu,
                priority: .high,
                title: "Optimize CPU-intensive operations",
                description: "Move heavy computations to background threads",
                implementation: "Use DispatchQueue.global(qos: .background) for non-UI operations",
                estimatedEffort: .medium,
                expectedImpact: .high,
                timestamp: Date()
            ))
        }
        
        // Memory recommendations
        if profile.peakMemoryUsage > 0.8 {
            recommendations.append(PerformanceOptimization(
                type: .memory,
                priority: .high,
                title: "Reduce memory footprint",
                description: "Implement lazy loading and memory cleanup",
                implementation: "Use weak references and implement proper deallocation",
                estimatedEffort: .high,
                expectedImpact: .high,
                timestamp: Date()
            ))
        }
        
        // Network recommendations
        if profile.totalNetworkUsage > 100_000_000 { // 100 MB
            recommendations.append(PerformanceOptimization(
                type: .network,
                priority: .medium,
                title: "Optimize network usage",
                description: "Implement data compression and caching",
                implementation: "Use URLSession with caching policies and compress image data",
                estimatedEffort: .medium,
                expectedImpact: .medium,
                timestamp: Date()
            ))
        }
        
        // Battery recommendations
        if profile.averageBatteryDrain > 10 {
            recommendations.append(PerformanceOptimization(
                type: .battery,
                priority: .medium,
                title: "Improve battery efficiency",
                description: "Reduce background processing and screen brightness",
                implementation: "Implement power-saving modes and optimize timer usage",
                estimatedEffort: .low,
                expectedImpact: .medium,
                timestamp: Date()
            ))
        }
        
        recommendedOptimizations = recommendations
    }
    
    // MARK: - Current Profile Update
    private func updateCurrentProfile() {
        guard var profile = currentProfile else { return }
        
        // Update profile with current metrics
        profile.averageCPUUsage = cpuProfileData.averageUsage
        profile.peakCPUUsage = cpuProfileData.peakUsage
        profile.averageMemoryUsage = memoryProfileData.averageUsage
        profile.peakMemoryUsage = memoryProfileData.peakUsage
        profile.averageNetworkLatency = networkProfileData.currentLatency
        profile.totalNetworkUsage = networkProfileData.totalBytesReceived + networkProfileData.totalBytesSent
        profile.averageFrameRate = renderingProfileData.currentFrameRate
        profile.droppedFrames = renderingProfileData.droppedFrameCount
        profile.averageBatteryDrain = batteryProfileData.drainRate
        profile.thermalEvents = batteryProfileData.thermalState == .critical ? 1 : 0
        
        currentProfile = profile
    }
    
    // MARK: - Method Profiling
    func profileMethod<T>(_ name: String, block: () throws -> T) rethrows -> T {
        let startTime = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(startTime)
        
        // Update method profile data
        if var methodData = profiledMethods[name] {
            methodData.totalCalls += 1
            methodData.totalDuration += duration
            methodData.averageDuration = methodData.totalDuration / Double(methodData.totalCalls)
            methodData.minDuration = min(methodData.minDuration, duration)
            methodData.maxDuration = max(methodData.maxDuration, duration)
            methodData.lastCallTime = Date()
            profiledMethods[name] = methodData
        } else {
            profiledMethods[name] = MethodProfileData(
                methodName: name,
                totalCalls: 1,
                totalDuration: duration,
                averageDuration: duration,
                minDuration: duration,
                maxDuration: duration,
                lastCallTime: Date()
            )
        }
        
        return result
    }
    
    func profileAsyncMethod<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(startTime)
        
        // Update method profile data
        if var methodData = profiledMethods[name] {
            methodData.totalCalls += 1
            methodData.totalDuration += duration
            methodData.averageDuration = methodData.totalDuration / Double(methodData.totalCalls)
            methodData.minDuration = min(methodData.minDuration, duration)
            methodData.maxDuration = max(methodData.maxDuration, duration)
            methodData.lastCallTime = Date()
            profiledMethods[name] = methodData
        } else {
            profiledMethods[name] = MethodProfileData(
                methodName: name,
                totalCalls: 1,
                totalDuration: duration,
                averageDuration: duration,
                minDuration: duration,
                maxDuration: duration,
                lastCallTime: Date()
            )
        }
        
        return result
    }
    
    // MARK: - Data Retrieval
    func getMethodProfileData() -> [MethodProfileData] {
        return Array(profiledMethods.values).sorted { $0.totalDuration > $1.totalDuration }
    }
    
    func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            timestamp: Date(),
            cpuData: cpuProfileData,
            memoryData: memoryProfileData,
            networkData: networkProfileData,
            renderingData: renderingProfileData,
            batteryData: batteryProfileData,
            bottlenecks: bottlenecks,
            optimizationInsights: optimizationInsights,
            recommendations: recommendedOptimizations
        )
    }
    
    func exportProfileData() -> Data? {
        let exportData = ProfileExportData(
            profiles: profileHistory,
            methodData: Array(profiledMethods.values),
            insights: optimizationInsights,
            recommendations: recommendedOptimizations
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(exportData)
        } catch {
            print("Failed to export profile data: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentCPUUsage() -> Double {
        // Implementation to get current CPU usage
        // This is a simplified version
        return Double.random(in: 0.1...0.8)
    }
    
    private func getCurrentMemoryUsage() -> (used: Double, available: Double, pressure: Double) {
        // Implementation to get current memory usage
        // This is a simplified version
        return (
            used: Double.random(in: 200...800) * 1024 * 1024, // MB to bytes
            available: Double.random(in: 1000...3000) * 1024 * 1024,
            pressure: Double.random(in: 0.1...0.7)
        )
    }
    
    private func getCurrentNetworkUsage() -> (bytesReceived: Double, bytesSent: Double, connectionType: String, latency: Double) {
        // Implementation to get current network usage
        // This is a simplified version
        return (
            bytesReceived: Double.random(in: 1000...10000),
            bytesSent: Double.random(in: 500...5000),
            connectionType: "WiFi",
            latency: Double.random(in: 10...200)
        )
    }
    
    private func getCurrentRenderingMetrics() -> (frameRate: Double, frameTime: Double, droppedFrames: Int, gpuUsage: Double) {
        // Implementation to get current rendering metrics
        // This is a simplified version
        return (
            frameRate: Double.random(in: 30...60),
            frameTime: Double.random(in: 8...33),
            droppedFrames: Int.random(in: 0...5),
            gpuUsage: Double.random(in: 0.1...0.6)
        )
    }
    
    private func getCurrentBatteryInfo() -> (level: Double, state: String, thermalState: ThermalState, lowPowerMode: Bool) {
        // Implementation to get current battery info
        // This is a simplified version
        return (
            level: Double.random(in: 0.2...1.0),
            state: "unplugged",
            thermalState: .normal,
            lowPowerMode: false
        )
    }
}

// MARK: - Performance Analytics Extensions
extension AnalyticsManager {
    func trackPerformanceProfilingStarted() {
        track(name: "performance_profiling_started")
    }
    
    func trackPerformanceProfilingStopped() {
        track(name: "performance_profiling_stopped")
    }
    
    func trackPerformanceBottleneck(_ bottleneck: PerformanceBottleneck) {
        track(name: "performance_bottleneck", properties: [
            "type": bottleneck.type.rawValue,
            "severity": bottleneck.severity.rawValue,
            "metric": bottleneck.metric
        ])
    }
}

// MARK: - MetricKit Subscriber
@available(iOS 13.0, *)
class MXMetricManagerSubscriber: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // Process MetricKit data
            if let cpuMetrics = payload.cpuMetrics {
                // Handle CPU metrics
            }
            
            if let memoryMetrics = payload.memoryMetrics {
                // Handle memory metrics
            }
            
            if let networkMetrics = payload.networkTransferMetrics {
                // Handle network metrics
            }
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let performanceAlertTriggered = Notification.Name("performanceAlertTriggered")
    static let errorOccurred = Notification.Name("errorOccurred")
}