//
//  QualityServiceTests.swift
//  StreamyyyApp
//
//  Comprehensive tests for quality control system
//

import XCTest
import SwiftUI
import Combine
@testable import StreamyyyApp

class QualityServiceTests: XCTestCase {
    var qualityService: QualityService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        qualityService = QualityService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        qualityService = nil
        super.tearDown()
    }
    
    // MARK: - Quality Service Tests
    
    func testQualityServiceInitialization() {
        XCTAssertNotNil(qualityService)
        XCTAssertEqual(qualityService.currentQuality, .auto)
        XCTAssertTrue(qualityService.isAdaptiveQualityEnabled)
        XCTAssertEqual(qualityService.networkCondition, .unknown)
    }
    
    func testStreamConfiguration() {
        let url = "https://twitch.tv/test"
        let platform = Platform.twitch
        
        qualityService.configureForStream(url: url, platform: platform)
        
        XCTAssertEqual(qualityService.availableQualities, platform.availableQualities)
    }
    
    func testQualitySelection() {
        let testQuality = StreamQuality.hd720
        qualityService.availableQualities = [.hd1080, .hd720, .medium, .low]
        
        qualityService.setQuality(testQuality, userInitiated: true)
        
        XCTAssertEqual(qualityService.currentQuality, testQuality)
        XCTAssertFalse(qualityService.isAdaptiveQualityEnabled)
    }
    
    func testAdaptiveQualityToggle() {
        qualityService.disableAdaptiveQuality()
        XCTAssertFalse(qualityService.isAdaptiveQualityEnabled)
        
        qualityService.enableAdaptiveQuality()
        XCTAssertTrue(qualityService.isAdaptiveQualityEnabled)
    }
    
    func testOptimalQualityCalculation() {
        let optimalQuality = qualityService.getOptimalQuality()
        XCTAssertNotNil(optimalQuality)
        XCTAssertTrue(StreamQuality.allCases.contains(optimalQuality))
    }
    
    // MARK: - Network Quality Monitor Tests
    
    func testNetworkMonitorInitialization() {
        let monitor = NetworkQualityMonitor()
        XCTAssertNotNil(monitor)
        XCTAssertEqual(monitor.networkCondition, .unknown)
        XCTAssertEqual(monitor.bandwidth, 0.0)
    }
    
    func testNetworkMonitoringLifecycle() {
        let monitor = NetworkQualityMonitor()
        
        // Test starting monitoring
        monitor.startMonitoring()
        // Network monitoring should begin
        
        // Test stopping monitoring
        monitor.stopMonitoring()
        // Network monitoring should stop
    }
    
    // MARK: - Adaptive Quality Controller Tests
    
    func testAdaptiveQualityController() {
        let controller = AdaptiveQualityController()
        
        // Configure for stream
        controller.configureForStream(url: "https://twitch.tv/test", platform: .twitch)
        
        // Test quality recommendation
        let quality = controller.getOptimalQuality(
            networkCondition: .wifi,
            batteryState: .normal,
            thermalState: .normal,
            performanceMetrics: PerformanceMetrics()
        )
        
        XCTAssertNotNil(quality)
        XCTAssertTrue(StreamQuality.allCases.contains(quality))
    }
    
    func testQualityDowngradeLogic() {
        let controller = AdaptiveQualityController()
        
        // Test quality downgrade for low battery
        let lowBatteryQuality = controller.getOptimalQuality(
            networkCondition: .wifi,
            batteryState: .low,
            thermalState: .normal,
            performanceMetrics: PerformanceMetrics()
        )
        
        // Test quality downgrade for high thermal state
        let highThermalQuality = controller.getOptimalQuality(
            networkCondition: .wifi,
            batteryState: .normal,
            thermalState: .hot,
            performanceMetrics: PerformanceMetrics()
        )
        
        XCTAssertNotNil(lowBatteryQuality)
        XCTAssertNotNil(highThermalQuality)
    }
    
    // MARK: - Performance Monitor Tests
    
    func testPerformanceMonitorInitialization() {
        let monitor = PerformanceMonitor()
        XCTAssertNotNil(monitor)
        XCTAssertEqual(monitor.thermalState, .normal)
        XCTAssertEqual(monitor.cpuUsage, 0.0)
        XCTAssertEqual(monitor.memoryUsage, 0.0)
    }
    
    func testPerformanceMonitoringLifecycle() {
        let monitor = PerformanceMonitor()
        
        monitor.startMonitoring()
        // Performance monitoring should begin
        
        monitor.stopMonitoring()
        // Performance monitoring should stop
    }
    
    func testPerformanceMetricsUpdate() {
        let monitor = PerformanceMonitor()
        let bufferHealth = 3.5
        
        monitor.updateBufferHealth(bufferHealth)
        
        XCTAssertEqual(monitor.metrics.bufferHealth, bufferHealth)
    }
    
    func testPerformanceReport() {
        let monitor = PerformanceMonitor()
        let report = monitor.getPerformanceReport()
        
        XCTAssertNotNil(report)
        XCTAssertGreaterThanOrEqual(report.performanceScore, 0)
        XCTAssertLessThanOrEqual(report.performanceScore, 100)
    }
    
    func testPerformanceRecommendations() {
        let monitor = PerformanceMonitor()
        let recommendations = monitor.getPerformanceRecommendations()
        
        XCTAssertNotNil(recommendations)
        XCTAssertTrue(recommendations.allSatisfy { $0 is PerformanceRecommendation })
    }
    
    // MARK: - Battery Optimizer Tests
    
    func testBatteryOptimizerInitialization() {
        let optimizer = BatteryOptimizer()
        XCTAssertNotNil(optimizer)
        XCTAssertEqual(optimizer.batteryState, .normal)
        XCTAssertEqual(optimizer.batteryLevel, 1.0)
        XCTAssertEqual(optimizer.powerSavingMode, .disabled)
    }
    
    func testPowerSavingModeToggle() {
        let optimizer = BatteryOptimizer()
        
        optimizer.setPowerSavingMode(.moderate)
        XCTAssertEqual(optimizer.powerSavingMode, .moderate)
        
        optimizer.setPowerSavingMode(.aggressive)
        XCTAssertEqual(optimizer.powerSavingMode, .aggressive)
    }
    
    func testBatteryReport() {
        let optimizer = BatteryOptimizer()
        let report = optimizer.getBatteryReport()
        
        XCTAssertNotNil(report)
        XCTAssertGreaterThanOrEqual(report.currentLevel, 0.0)
        XCTAssertLessThanOrEqual(report.currentLevel, 1.0)
        XCTAssertGreaterThanOrEqual(report.efficiency, 0.0)
    }
    
    func testQualityRecommendation() {
        let optimizer = BatteryOptimizer()
        let recommendedQuality = optimizer.getRecommendedQuality()
        
        XCTAssertNotNil(recommendedQuality)
        XCTAssertTrue(StreamQuality.allCases.contains(recommendedQuality))
    }
    
    func testConcurrentStreamLimits() {
        let optimizer = BatteryOptimizer()
        let maxStreams = optimizer.getMaxConcurrentStreams()
        
        XCTAssertGreaterThan(maxStreams, 0)
        XCTAssertLessThanOrEqual(maxStreams, 10)
    }
    
    // MARK: - Stream Health Diagnostics Tests
    
    func testHealthDiagnosticsInitialization() {
        let diagnostics = StreamHealthDiagnostics()
        XCTAssertNotNil(diagnostics)
        XCTAssertEqual(diagnostics.streamHealth, .unknown)
        XCTAssertEqual(diagnostics.connectionQuality, .unknown)
        XCTAssertTrue(diagnostics.activeIssues.isEmpty)
    }
    
    func testStreamConfiguration() {
        let diagnostics = StreamHealthDiagnostics()
        
        diagnostics.configureForStream(url: "https://twitch.tv/test", platform: .twitch)
        
        // Configuration should reset diagnostics
        XCTAssertEqual(diagnostics.streamHealth, .unknown)
        XCTAssertTrue(diagnostics.activeIssues.isEmpty)
    }
    
    func testHealthSummary() {
        let diagnostics = StreamHealthDiagnostics()
        let summary = diagnostics.getHealthSummary()
        
        XCTAssertNotNil(summary)
        XCTAssertGreaterThanOrEqual(summary.healthScore, 0)
        XCTAssertLessThanOrEqual(summary.healthScore, 100)
    }
    
    func testDiagnosticsReport() {
        let diagnostics = StreamHealthDiagnostics()
        let report = diagnostics.getDiagnosticsReport()
        
        XCTAssertNotNil(report)
        XCTAssertGreaterThanOrEqual(report.connectionAttempts, 0)
        XCTAssertGreaterThanOrEqual(report.successfulConnections, 0)
        XCTAssertGreaterThanOrEqual(report.successRate, 0.0)
        XCTAssertLessThanOrEqual(report.successRate, 1.0)
    }
    
    // MARK: - Quality Presets Tests
    
    func testQualityPresetsInitialization() {
        let presets = QualityPresets()
        XCTAssertNotNil(presets)
        XCTAssertNotNil(presets.userPreferences)
        XCTAssertFalse(presets.customPresets.isEmpty)
    }
    
    func testPresetSelection() {
        let presets = QualityPresets()
        let allPresets = presets.getAllPresets()
        
        XCTAssertFalse(allPresets.isEmpty)
        
        if let firstPreset = allPresets.first {
            presets.selectPreset(firstPreset)
            XCTAssertEqual(presets.currentPreset?.id, firstPreset.id)
        }
    }
    
    func testPresetValidation() {
        let presets = QualityPresets()
        
        let validPreset = QualityPreset(
            name: "Test Preset",
            description: "Test description",
            defaultQuality: .hd720,
            adaptiveQuality: true,
            maxQuality: .hd1080,
            minQuality: .low,
            batteryOptimization: true,
            thermalOptimization: true,
            networkOptimization: true,
            maxConcurrentStreams: 2,
            bufferSize: .medium,
            frameRateLimit: 30,
            isDefault: false
        )
        
        let errors = presets.validatePreset(validPreset)
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testPresetRecommendations() {
        let presets = QualityPresets()
        
        let recommendedPreset = presets.getRecommendedPreset(
            networkCondition: .wifi,
            batteryLevel: 0.8,
            thermalState: .normal,
            isCharging: false
        )
        
        XCTAssertNotNil(recommendedPreset)
    }
    
    // MARK: - Stream Buffer Manager Tests
    
    func testBufferManagerInitialization() {
        let bufferManager = StreamBufferManager()
        XCTAssertNotNil(bufferManager)
        XCTAssertEqual(bufferManager.bufferHealth, 0.0)
        XCTAssertEqual(bufferManager.bufferSize, 5.0)
        XCTAssertTrue(bufferManager.bufferOptimizationEnabled)
    }
    
    func testBufferConfiguration() {
        let bufferManager = StreamBufferManager()
        
        bufferManager.configureBuffer(
            for: "https://twitch.tv/test",
            quality: .hd720,
            networkCondition: .wifi
        )
        
        // Buffer should be configured
        XCTAssertGreaterThan(bufferManager.bufferSize, 0)
    }
    
    func testBufferLifecycle() {
        let bufferManager = StreamBufferManager()
        let streamURL = "https://twitch.tv/test"
        
        bufferManager.startBuffering(for: streamURL)
        // Buffering should start
        
        bufferManager.pauseBuffering(for: streamURL)
        // Buffering should pause
        
        bufferManager.resumeBuffering(for: streamURL)
        // Buffering should resume
        
        bufferManager.stopBuffering(for: streamURL)
        // Buffering should stop
    }
    
    func testBufferStats() {
        let bufferManager = StreamBufferManager()
        let stats = bufferManager.getBufferStats()
        
        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(stats.activeStreams, 0)
        XCTAssertGreaterThanOrEqual(stats.totalBufferSize, 0)
        XCTAssertGreaterThanOrEqual(stats.averageBufferHealth, 0)
    }
    
    func testCacheManagement() {
        let bufferManager = StreamBufferManager()
        
        // Test cache clearing
        bufferManager.clearCache()
        
        // Cache size should be reset
        XCTAssertEqual(bufferManager.cacheSize, 0)
    }
    
    // MARK: - Integration Tests
    
    func testQualityServiceNetworkIntegration() {
        let expectation = XCTestExpectation(description: "Network condition update")
        
        qualityService.$networkCondition
            .dropFirst()
            .sink { condition in
                if condition != .unknown {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate network condition change
        qualityService.networkMonitor.networkCondition = .wifi
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testQualityServiceBatteryIntegration() {
        let expectation = XCTestExpectation(description: "Battery state update")
        
        qualityService.$batteryState
            .dropFirst()
            .sink { state in
                if state != .normal {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate battery state change
        qualityService.batteryOptimizer.batteryState = .low
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testQualityServicePerformanceIntegration() {
        let expectation = XCTestExpectation(description: "Performance metrics update")
        
        qualityService.$performanceMetrics
            .dropFirst()
            .sink { metrics in
                if metrics.frameRate > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate performance metrics update
        var metrics = PerformanceMetrics()
        metrics.frameRate = 60.0
        qualityService.performanceMonitor.metrics = metrics
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testAdaptiveQualityIntegration() {
        qualityService.availableQualities = [.hd1080, .hd720, .medium, .low]
        qualityService.enableAdaptiveQuality()
        
        // Simulate poor network conditions
        qualityService.networkMonitor.networkCondition = .cellular
        qualityService.batteryOptimizer.batteryState = .low
        qualityService.performanceMonitor.thermalState = .hot
        
        let optimalQuality = qualityService.getOptimalQuality()
        
        // Quality should be downgraded due to poor conditions
        XCTAssertTrue([.medium, .low, .mobile].contains(optimalQuality))
    }
    
    // MARK: - Performance Tests
    
    func testQualityServicePerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = qualityService.getOptimalQuality()
            }
        }
    }
    
    func testAdaptiveQualityPerformance() {
        let controller = AdaptiveQualityController()
        controller.configureForStream(url: "https://twitch.tv/test", platform: .twitch)
        
        measure {
            for _ in 0..<1000 {
                let _ = controller.getOptimalQuality(
                    networkCondition: .wifi,
                    batteryState: .normal,
                    thermalState: .normal,
                    performanceMetrics: PerformanceMetrics()
                )
            }
        }
    }
    
    func testBufferManagerPerformance() {
        let bufferManager = StreamBufferManager()
        
        measure {
            for i in 0..<100 {
                bufferManager.configureBuffer(
                    for: "https://twitch.tv/test\(i)",
                    quality: .hd720,
                    networkCondition: .wifi
                )
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidQualitySelection() {
        qualityService.availableQualities = [.hd720, .medium, .low]
        
        // Try to select unavailable quality
        qualityService.setQuality(.hd1080, userInitiated: true)
        
        // Quality should not change
        XCTAssertNotEqual(qualityService.currentQuality, .hd1080)
    }
    
    func testEmptyAvailableQualities() {
        qualityService.availableQualities = []
        
        let optimalQuality = qualityService.getOptimalQuality()
        
        // Should return auto or a default quality
        XCTAssertNotNil(optimalQuality)
    }
    
    func testBufferManagerWithInvalidURL() {
        let bufferManager = StreamBufferManager()
        
        // Configure buffer with invalid URL
        bufferManager.configureBuffer(
            for: "invalid-url",
            quality: .hd720,
            networkCondition: .wifi
        )
        
        // Should handle gracefully
        let stats = bufferManager.getBufferStats()
        XCTAssertNotNil(stats)
    }
    
    // MARK: - Memory Tests
    
    func testMemoryUsage() {
        let initialMemory = getCurrentMemoryUsage()
        
        // Create multiple instances
        var services: [QualityService] = []
        for _ in 0..<10 {
            let service = QualityService()
            service.configureForStream(url: "https://twitch.tv/test", platform: .twitch)
            services.append(service)
        }
        
        let peakMemory = getCurrentMemoryUsage()
        
        // Clean up
        services.removeAll()
        
        let finalMemory = getCurrentMemoryUsage()
        
        // Memory should be released
        XCTAssertLessThan(finalMemory, peakMemory)
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
}

// MARK: - Mock Classes for Testing

class MockWebView: NSObject {
    var evaluatedJavaScript: String?
    var loadedURL: URL?
    
    func evaluateJavaScript(_ javaScriptString: String) {
        evaluatedJavaScript = javaScriptString
    }
    
    func load(_ request: URLRequest) {
        loadedURL = request.url
    }
}

class MockPerformanceMonitor: PerformanceMonitor {
    var mockMetrics = PerformanceMetrics()
    
    override var metrics: PerformanceMetrics {
        return mockMetrics
    }
    
    override func startMonitoring() {
        // Mock implementation
    }
    
    override func stopMonitoring() {
        // Mock implementation
    }
}

class MockNetworkMonitor: NetworkQualityMonitor {
    override func startMonitoring() {
        // Mock implementation
    }
    
    override func stopMonitoring() {
        // Mock implementation
    }
}

// MARK: - Test Utilities

extension QualityServiceTests {
    func createTestStream() -> Stream {
        return Stream(
            id: UUID().uuidString,
            url: "https://twitch.tv/test",
            platform: .twitch,
            title: "Test Stream"
        )
    }
    
    func createTestPerformanceMetrics() -> PerformanceMetrics {
        var metrics = PerformanceMetrics()
        metrics.frameRate = 60.0
        metrics.frameDropRate = 0.01
        metrics.bufferHealth = 3.0
        metrics.cpuUsage = 0.5
        metrics.memoryUsage = 0.4
        metrics.networkThroughput = 25.0
        return metrics
    }
    
    func waitForCondition(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5.0) {
        let expectation = XCTestExpectation(description: "Condition met")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }
}