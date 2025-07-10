//
//  StreamQualityMonitor.swift
//  StreamyyyApp
//
//  Stream-specific quality monitoring and performance tracking
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

// MARK: - Stream Quality Monitor
class StreamQualityMonitor: ObservableObject {
    static let shared = StreamQualityMonitor()
    
    // MARK: - Published Properties
    @Published var activeStreams: [StreamQualityData] = []
    @Published var qualityMetrics: [StreamQualityMetric] = []
    @Published var bufferHealthData: [BufferHealthPoint] = []
    @Published var networkQualityData: [NetworkQualityPoint] = []
    @Published var streamPerformanceAlerts: [StreamAlert] = []
    @Published var qualityInsights: [QualityInsight] = []
    @Published var isMonitoringActive: Bool = false
    
    // MARK: - Real-time Metrics
    @Published var averageLatency: Double = 0.0
    @Published var bufferHealthScore: Double = 1.0
    @Published var overallQualityScore: Double = 100.0
    @Published var activeStreamCount: Int = 0
    @Published var networkStability: NetworkStability = .stable
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var analyticsManager = AnalyticsManager.shared
    private var performanceProfiler = PerformanceProfiler.shared
    private var monitoringTimer: Timer?
    private var streamObservers: [String: Any] = [:]
    
    // MARK: - Configuration
    private let monitoringInterval: TimeInterval = 5.0
    private let qualityThresholds = QualityThresholds()
    private let maxStoredMetrics = 1000
    private let alertCooldownPeriod: TimeInterval = 300.0 // 5 minutes
    
    // MARK: - Initialization
    private init() {
        setupQualityMonitoring()
    }
    
    // MARK: - Setup
    private func setupQualityMonitoring() {
        // Subscribe to stream lifecycle events
        NotificationCenter.default.publisher(for: .streamAdded)
            .sink { [weak self] notification in
                self?.handleStreamAdded(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .streamRemoved)
            .sink { [weak self] notification in
                self?.handleStreamRemoved(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .streamStateChanged)
            .sink { [weak self] notification in
                self?.handleStreamStateChanged(notification)
            }
            .store(in: &cancellables)
        
        // Subscribe to network changes
        NotificationCenter.default.publisher(for: .networkStateChanged)
            .sink { [weak self] notification in
                self?.handleNetworkStateChanged(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard !isMonitoringActive else { return }
        
        isMonitoringActive = true
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.performQualityCheck()
        }
        
        analyticsManager.trackFeatureUsed(feature: "stream_quality_monitoring_started")
    }
    
    func stopMonitoring() {
        guard isMonitoringActive else { return }
        
        isMonitoringActive = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Clean up stream observers
        streamObservers.removeAll()
        
        analyticsManager.trackFeatureUsed(feature: "stream_quality_monitoring_stopped")
    }
    
    // MARK: - Stream Quality Tracking
    func addStreamForMonitoring(_ stream: StreamInfo) {
        let qualityData = StreamQualityData(
            streamId: stream.id,
            title: stream.title,
            platform: stream.platform,
            url: stream.url,
            startTime: Date(),
            quality: stream.quality ?? "auto"
        )
        
        activeStreams.append(qualityData)
        activeStreamCount = activeStreams.count
        
        // Setup stream-specific monitoring
        setupStreamObserver(for: stream)
        
        analyticsManager.trackStreamAdded(platform: stream.platform, url: stream.url)
    }
    
    func removeStreamFromMonitoring(_ streamId: String) {
        if let index = activeStreams.firstIndex(where: { $0.streamId == streamId }) {
            let stream = activeStreams[index]
            
            // Generate final quality report
            generateStreamQualityReport(for: stream)
            
            activeStreams.remove(at: index)
            activeStreamCount = activeStreams.count
            
            // Remove stream observer
            streamObservers.removeValue(forKey: streamId)
            
            analyticsManager.trackStreamRemoved(platform: stream.platform)
        }
    }
    
    // MARK: - Quality Monitoring
    private func performQualityCheck() {
        updateStreamQualityMetrics()
        updateBufferHealth()
        updateNetworkQuality()
        checkQualityThresholds()
        generateQualityInsights()
        updateOverallQualityScore()
    }
    
    private func updateStreamQualityMetrics() {
        let timestamp = Date()
        
        for stream in activeStreams {
            let metrics = collectStreamMetrics(for: stream)
            
            let qualityMetric = StreamQualityMetric(
                id: UUID(),
                streamId: stream.streamId,
                platform: stream.platform,
                quality: stream.quality,
                bufferEvents: metrics.bufferEvents,
                latency: metrics.latency,
                loadTime: metrics.loadTime,
                viewerCount: metrics.viewerCount,
                timestamp: timestamp
            )
            
            qualityMetrics.append(qualityMetric)
            
            // Update stream quality data
            updateStreamQualityData(stream: stream, metrics: metrics)
            
            // Track quality metrics in analytics
            analyticsManager.trackStreamQuality(
                streamId: stream.streamId,
                platform: stream.platform,
                quality: stream.quality,
                bufferEvents: metrics.bufferEvents,
                latency: metrics.latency
            )
        }
        
        // Keep only recent metrics
        if qualityMetrics.count > maxStoredMetrics {
            qualityMetrics.removeFirst(qualityMetrics.count - maxStoredMetrics)
        }
    }
    
    private func updateBufferHealth() {
        let timestamp = Date()
        var totalBufferHealth = 0.0
        var streamCount = 0
        
        for stream in activeStreams {
            let bufferHealth = calculateBufferHealth(for: stream)
            totalBufferHealth += bufferHealth
            streamCount += 1
            
            let bufferPoint = BufferHealthPoint(
                timestamp: timestamp,
                streamId: stream.streamId,
                bufferHealth: bufferHealth,
                bufferSize: getBufferSize(for: stream),
                bufferEvents: getBufferEvents(for: stream)
            )
            
            bufferHealthData.append(bufferPoint)
        }
        
        // Update overall buffer health score
        bufferHealthScore = streamCount > 0 ? totalBufferHealth / Double(streamCount) : 1.0
        
        // Keep only recent buffer health data
        if bufferHealthData.count > maxStoredMetrics {
            bufferHealthData.removeFirst(bufferHealthData.count - maxStoredMetrics)
        }
    }
    
    private func updateNetworkQuality() {
        let timestamp = Date()
        let networkMetrics = collectNetworkMetrics()
        
        let networkPoint = NetworkQualityPoint(
            timestamp: timestamp,
            bandwidth: networkMetrics.bandwidth,
            latency: networkMetrics.latency,
            packetLoss: networkMetrics.packetLoss,
            jitter: networkMetrics.jitter,
            connectionType: networkMetrics.connectionType,
            signalStrength: networkMetrics.signalStrength
        )
        
        networkQualityData.append(networkPoint)
        
        // Update average latency
        let recentNetworkData = networkQualityData.suffix(12) // Last minute
        averageLatency = recentNetworkData.map { $0.latency }.reduce(0, +) / Double(recentNetworkData.count)
        
        // Update network stability
        updateNetworkStability(networkPoint)
        
        // Keep only recent network data
        if networkQualityData.count > maxStoredMetrics {
            networkQualityData.removeFirst(networkQualityData.count - maxStoredMetrics)
        }
    }
    
    private func checkQualityThresholds() {
        let currentTime = Date()
        
        for stream in activeStreams {
            let recentMetrics = qualityMetrics
                .filter { $0.streamId == stream.streamId }
                .suffix(6) // Last 30 seconds
            
            guard !recentMetrics.isEmpty else { continue }
            
            // Check latency threshold
            let avgLatency = recentMetrics.map { $0.latency }.reduce(0, +) / Double(recentMetrics.count)
            if avgLatency > qualityThresholds.maxLatency {
                createQualityAlert(
                    type: .highLatency,
                    streamId: stream.streamId,
                    message: "High latency detected: \(Int(avgLatency))ms",
                    severity: avgLatency > qualityThresholds.criticalLatency ? .critical : .warning
                )
            }
            
            // Check buffer events threshold
            let totalBufferEvents = recentMetrics.map { $0.bufferEvents }.reduce(0, +)
            if totalBufferEvents > qualityThresholds.maxBufferEvents {
                createQualityAlert(
                    type: .bufferingIssues,
                    streamId: stream.streamId,
                    message: "Excessive buffering: \(totalBufferEvents) events in 30s",
                    severity: .warning
                )
            }
            
            // Check load time threshold
            if let lastMetric = recentMetrics.last,
               lastMetric.loadTime > qualityThresholds.maxLoadTime {
                createQualityAlert(
                    type: .slowLoading,
                    streamId: stream.streamId,
                    message: "Slow loading: \(String(format: "%.1f", lastMetric.loadTime))s",
                    severity: .warning
                )
            }
        }
    }
    
    private func generateQualityInsights() {
        var insights: [QualityInsight] = []
        
        // Analyze overall quality trends
        if qualityMetrics.count >= 20 {
            let recentMetrics = qualityMetrics.suffix(20)
            let oldMetrics = qualityMetrics.dropLast(20).suffix(20)
            
            if !oldMetrics.isEmpty {
                let recentAvgLatency = recentMetrics.map { $0.latency }.reduce(0, +) / Double(recentMetrics.count)
                let oldAvgLatency = oldMetrics.map { $0.latency }.reduce(0, +) / Double(oldMetrics.count)
                
                if recentAvgLatency > oldAvgLatency * 1.2 {
                    insights.append(QualityInsight(
                        type: .performanceDegradation,
                        title: "Network Performance Declining",
                        description: "Average latency has increased by \(Int((recentAvgLatency - oldAvgLatency) / oldAvgLatency * 100))%",
                        recommendation: "Check network connection and consider reducing stream quality",
                        impact: .medium,
                        timestamp: Date()
                    ))
                }
            }
        }
        
        // Analyze platform-specific issues
        let platformMetrics = Dictionary(grouping: qualityMetrics.suffix(50)) { $0.platform }
        
        for (platform, metrics) in platformMetrics {
            let avgQualityScore = metrics.map { $0.qualityScore }.reduce(0, +) / Double(metrics.count)
            
            if avgQualityScore < 70 {
                insights.append(QualityInsight(
                    type: .platformIssue,
                    title: "\(platform) Quality Issues",
                    description: "Poor quality detected for \(platform) streams (Score: \(Int(avgQualityScore)))",
                    recommendation: "Consider switching to a different quality setting for \(platform)",
                    impact: .medium,
                    timestamp: Date()
                ))
            }
        }
        
        // Analyze buffer health trends
        if bufferHealthData.count >= 20 {
            let recentBufferHealth = bufferHealthData.suffix(20).map { $0.bufferHealth }.reduce(0, +) / 20.0
            
            if recentBufferHealth < 0.7 {
                insights.append(QualityInsight(
                    type: .bufferHealth,
                    title: "Poor Buffer Health",
                    description: "Buffer health is below optimal levels (\(Int(recentBufferHealth * 100))%)",
                    recommendation: "Reduce concurrent streams or improve network connection",
                    impact: .high,
                    timestamp: Date()
                ))
            }
        }
        
        qualityInsights = insights
    }
    
    private func updateOverallQualityScore() {
        guard !activeStreams.isEmpty else {
            overallQualityScore = 100.0
            return
        }
        
        var score = 100.0
        
        // Latency penalty
        if averageLatency > qualityThresholds.maxLatency {
            score -= min((averageLatency - qualityThresholds.maxLatency) / 10.0, 30.0)
        }
        
        // Buffer health penalty
        score -= (1.0 - bufferHealthScore) * 40.0
        
        // Network stability penalty
        switch networkStability {
        case .stable:
            break
        case .unstable:
            score -= 10.0
        case .poor:
            score -= 20.0
        }
        
        // Stream-specific penalties
        let recentMetrics = qualityMetrics.suffix(activeStreamCount * 5) // Last 25 seconds per stream
        let avgBufferEvents = recentMetrics.map { $0.bufferEvents }.reduce(0, +) / max(recentMetrics.count, 1)
        score -= Double(avgBufferEvents) * 2.0
        
        overallQualityScore = max(0, min(100, score))
    }
    
    // MARK: - Stream Observer Setup
    private func setupStreamObserver(for stream: StreamInfo) {
        // Setup AVPlayer observer if using AVPlayer
        // This is a simplified implementation
        
        let observer = StreamObserver(streamId: stream.id) { [weak self] metrics in
            self?.handleStreamMetricsUpdate(streamId: stream.id, metrics: metrics)
        }
        
        streamObservers[stream.id] = observer
    }
    
    private func handleStreamMetricsUpdate(streamId: String, metrics: RealTimeStreamMetrics) {
        if let index = activeStreams.firstIndex(where: { $0.streamId == streamId }) {
            activeStreams[index].updateMetrics(metrics)
        }
    }
    
    // MARK: - Metrics Collection
    private func collectStreamMetrics(for stream: StreamQualityData) -> StreamMetrics {
        // Collect real-time metrics for the stream
        // This would integrate with actual video player APIs
        
        return StreamMetrics(
            bufferEvents: Int.random(in: 0...3),
            latency: Double.random(in: 20...200),
            loadTime: Double.random(in: 0.5...5.0),
            viewerCount: Int.random(in: 1...1000),
            bitrate: Double.random(in: 1000...8000),
            frameRate: Double.random(in: 24...60),
            droppedFrames: Int.random(in: 0...5)
        )
    }
    
    private func collectNetworkMetrics() -> NetworkMetrics {
        // Collect network performance metrics
        
        return NetworkMetrics(
            bandwidth: Double.random(in: 1_000_000...100_000_000), // 1-100 Mbps
            latency: Double.random(in: 10...500),
            packetLoss: Double.random(in: 0...5),
            jitter: Double.random(in: 1...50),
            connectionType: getCurrentConnectionType(),
            signalStrength: Double.random(in: 0.3...1.0)
        )
    }
    
    private func calculateBufferHealth(for stream: StreamQualityData) -> Double {
        // Calculate buffer health based on recent buffer events
        let recentBufferEvents = getBufferEvents(for: stream)
        
        // Perfect buffer health = 1.0, poor = 0.0
        let baseHealth = max(0.0, 1.0 - Double(recentBufferEvents) / 10.0)
        
        // Adjust for network quality
        let networkAdjustment = min(1.0, averageLatency / 100.0) * 0.2
        
        return max(0.0, min(1.0, baseHealth - networkAdjustment))
    }
    
    // MARK: - Helper Methods
    private func updateStreamQualityData(stream: StreamQualityData, metrics: StreamMetrics) {
        if let index = activeStreams.firstIndex(where: { $0.streamId == stream.streamId }) {
            activeStreams[index].latency = metrics.latency
            activeStreams[index].bufferEvents = metrics.bufferEvents
            activeStreams[index].loadTime = metrics.loadTime
            activeStreams[index].bitrate = metrics.bitrate
            activeStreams[index].frameRate = metrics.frameRate
            activeStreams[index].droppedFrames = metrics.droppedFrames
            activeStreams[index].lastUpdate = Date()
        }
    }
    
    private func updateNetworkStability(_ networkPoint: NetworkQualityPoint) {
        let recentPoints = networkQualityData.suffix(10)
        guard recentPoints.count >= 5 else { return }
        
        let latencyVariance = calculateVariance(recentPoints.map { $0.latency })
        let packetLossAvg = recentPoints.map { $0.packetLoss }.reduce(0, +) / Double(recentPoints.count)
        
        if latencyVariance > 50 || packetLossAvg > 2.0 {
            networkStability = .poor
        } else if latencyVariance > 20 || packetLossAvg > 0.5 {
            networkStability = .unstable
        } else {
            networkStability = .stable
        }
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count - 1)
    }
    
    private func createQualityAlert(type: StreamAlertType, streamId: String, message: String, severity: AlertSeverity) {
        // Check cooldown period
        let recentAlerts = streamPerformanceAlerts.filter { alert in
            alert.streamId == streamId &&
            alert.type == type &&
            Date().timeIntervalSince(alert.timestamp) < alertCooldownPeriod
        }
        
        guard recentAlerts.isEmpty else { return }
        
        let alert = StreamAlert(
            id: UUID(),
            type: type,
            streamId: streamId,
            message: message,
            severity: severity,
            timestamp: Date()
        )
        
        streamPerformanceAlerts.append(alert)
        
        // Keep only recent alerts
        if streamPerformanceAlerts.count > 100 {
            streamPerformanceAlerts.removeFirst()
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: .streamQualityAlertCreated,
            object: self,
            userInfo: ["alert": alert]
        )
        
        // Track alert in analytics
        analyticsManager.trackPerformanceAlert(
            alert: message,
            threshold: 0,
            actualValue: 0,
            severity: severity.rawValue
        )
    }
    
    private func generateStreamQualityReport(for stream: StreamQualityData) {
        let streamMetrics = qualityMetrics.filter { $0.streamId == stream.streamId }
        
        let report = StreamQualityReport(
            streamId: stream.streamId,
            platform: stream.platform,
            sessionDuration: Date().timeIntervalSince(stream.startTime),
            averageLatency: streamMetrics.map { $0.latency }.reduce(0, +) / Double(max(streamMetrics.count, 1)),
            totalBufferEvents: streamMetrics.map { $0.bufferEvents }.reduce(0, +),
            averageLoadTime: streamMetrics.map { $0.loadTime }.reduce(0, +) / Double(max(streamMetrics.count, 1)),
            qualityScore: streamMetrics.map { $0.qualityScore }.reduce(0, +) / Double(max(streamMetrics.count, 1)),
            recommendations: generateStreamRecommendations(for: stream)
        )
        
        // Store report or send to analytics
        analyticsManager.track(name: "stream_quality_report", properties: [
            "stream_id": stream.streamId,
            "platform": stream.platform,
            "quality_score": report.qualityScore,
            "session_duration": report.sessionDuration
        ])
    }
    
    private func generateStreamRecommendations(for stream: StreamQualityData) -> [String] {
        var recommendations: [String] = []
        
        if stream.latency > qualityThresholds.maxLatency {
            recommendations.append("Consider switching to a lower quality setting to reduce latency")
        }
        
        if stream.bufferEvents > 5 {
            recommendations.append("Frequent buffering detected. Check network connection")
        }
        
        if stream.loadTime > qualityThresholds.maxLoadTime {
            recommendations.append("Slow loading times. Verify stream URL and network speed")
        }
        
        return recommendations
    }
    
    private func getBufferSize(for stream: StreamQualityData) -> Double {
        // Get current buffer size from stream player
        return Double.random(in: 5...30) // Placeholder: 5-30 seconds
    }
    
    private func getBufferEvents(for stream: StreamQualityData) -> Int {
        // Get recent buffer events count
        return stream.bufferEvents
    }
    
    private func getCurrentConnectionType() -> String {
        // Detect current connection type
        return "WiFi" // Placeholder
    }
    
    // MARK: - Event Handlers
    private func handleStreamAdded(_ notification: Notification) {
        guard let streamInfo = notification.userInfo?["stream"] as? StreamInfo else { return }
        addStreamForMonitoring(streamInfo)
    }
    
    private func handleStreamRemoved(_ notification: Notification) {
        guard let streamId = notification.userInfo?["streamId"] as? String else { return }
        removeStreamFromMonitoring(streamId)
    }
    
    private func handleStreamStateChanged(_ notification: Notification) {
        guard let streamId = notification.userInfo?["streamId"] as? String,
              let state = notification.userInfo?["state"] as? String else { return }
        
        if let index = activeStreams.firstIndex(where: { $0.streamId == streamId }) {
            activeStreams[index].state = StreamState(rawValue: state) ?? .unknown
        }
    }
    
    private func handleNetworkStateChanged(_ notification: Notification) {
        // Handle network state changes
        performQualityCheck()
    }
    
    // MARK: - Public API
    func getCurrentMetrics() async -> [StreamQualityMetric] {
        return qualityMetrics
    }
    
    func getStreamQualityData(for streamId: String) -> StreamQualityData? {
        return activeStreams.first { $0.streamId == streamId }
    }
    
    func getQualityReport(for streamId: String) -> StreamQualityReport? {
        guard let stream = activeStreams.first(where: { $0.streamId == streamId }) else { return nil }
        
        let streamMetrics = qualityMetrics.filter { $0.streamId == streamId }
        
        return StreamQualityReport(
            streamId: streamId,
            platform: stream.platform,
            sessionDuration: Date().timeIntervalSince(stream.startTime),
            averageLatency: streamMetrics.map { $0.latency }.reduce(0, +) / Double(max(streamMetrics.count, 1)),
            totalBufferEvents: streamMetrics.map { $0.bufferEvents }.reduce(0, +),
            averageLoadTime: streamMetrics.map { $0.loadTime }.reduce(0, +) / Double(max(streamMetrics.count, 1)),
            qualityScore: streamMetrics.map { $0.qualityScore }.reduce(0, +) / Double(max(streamMetrics.count, 1)),
            recommendations: generateStreamRecommendations(for: stream)
        )
    }
    
    func exportQualityData() -> Data? {
        let exportData = StreamQualityExportData(
            qualityMetrics: qualityMetrics,
            bufferHealthData: bufferHealthData,
            networkQualityData: networkQualityData,
            streamAlerts: streamPerformanceAlerts,
            qualityInsights: qualityInsights,
            exportDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(exportData)
        } catch {
            print("Failed to export quality data: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Classes
class StreamObserver {
    let streamId: String
    let metricsCallback: (RealTimeStreamMetrics) -> Void
    
    init(streamId: String, metricsCallback: @escaping (RealTimeStreamMetrics) -> Void) {
        self.streamId = streamId
        self.metricsCallback = metricsCallback
        startObserving()
    }
    
    private func startObserving() {
        // Setup actual stream monitoring
        // This would integrate with AVPlayer or other video frameworks
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let streamAdded = Notification.Name("streamAdded")
    static let streamRemoved = Notification.Name("streamRemoved")
    static let streamStateChanged = Notification.Name("streamStateChanged")
    static let networkStateChanged = Notification.Name("networkStateChanged")
    static let streamQualityAlertCreated = Notification.Name("streamQualityAlertCreated")
}