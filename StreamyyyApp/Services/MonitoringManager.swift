//
//  MonitoringManager.swift
//  StreamyyyApp
//
//  Comprehensive monitoring manager for system health and performance
//

import Foundation
import SwiftUI
import Combine
import Network

// MARK: - Monitoring Manager
class MonitoringManager: ObservableObject {
    static let shared = MonitoringManager()
    
    // MARK: - Published Properties
    @Published var systemStatus: SystemStatus = .healthy
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var networkThroughput: Double = 0.0
    @Published var thermalState: ThermalState = .normal
    @Published var isRefreshing: Bool = false
    
    // MARK: - Data Properties
    @Published var healthHistory: [HealthDataPoint] = []
    @Published var performanceMetrics: [PerformanceMetric] = []
    @Published var activeStreams: [StreamStatus] = []
    @Published var networkMetrics: [NetworkMetric] = []
    @Published var frameRateHistory: [FrameRateDataPoint] = []
    @Published var memoryUsageHistory: [MemoryUsageDataPoint] = []
    @Published var streamQualityMetrics: [StreamQualityMetric] = []
    @Published var userEngagementMetrics: [UserEngagementMetric] = []
    @Published var alerts: [MonitoringAlert] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var performanceMonitor: PerformanceMonitor?
    private var networkMonitor: NWPathMonitor?
    private var networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var analyticsManager = AnalyticsManager.shared
    
    // MARK: - Initialization
    private init() {
        setupMonitoring()
        setupNetworkMonitoring()
        setupPerformanceMonitoring()
    }
    
    // MARK: - Setup Methods
    private func setupMonitoring() {
        // Subscribe to performance monitor updates
        NotificationCenter.default.publisher(for: .performanceMetricsUpdated)
            .sink { [weak self] notification in
                self?.handlePerformanceUpdate(notification)
            }
            .store(in: &cancellables)
        
        // Subscribe to memory pressure notifications
        NotificationCenter.default.publisher(for: .memoryPressureDetected)
            .sink { [weak self] notification in
                self?.handleMemoryPressure(notification)
            }
            .store(in: &cancellables)
        
        // Subscribe to thermal state changes
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkPathUpdate(path)
            }
        }
        networkMonitor?.start(queue: networkQueue)
    }
    
    private func setupPerformanceMonitoring() {
        performanceMonitor = PerformanceMonitor()
        performanceMonitor?.startMonitoring()
        
        // Bind performance monitor data
        performanceMonitor?.$cpuUsage
            .receive(on: DispatchQueue.main)
            .assign(to: \.cpuUsage, on: self)
            .store(in: &cancellables)
        
        performanceMonitor?.$memoryUsage
            .receive(on: DispatchQueue.main)
            .assign(to: \.memoryUsage, on: self)
            .store(in: &cancellables)
        
        performanceMonitor?.$thermalState
            .receive(on: DispatchQueue.main)
            .assign(to: \.thermalState, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        stopMonitoring() // Stop any existing monitoring
        
        performanceMonitor?.startMonitoring()
        
        // Start periodic data collection
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.collectMonitoringData()
        }
        
        // Initial data collection
        collectMonitoringData()
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        performanceMonitor?.stopMonitoring()
    }
    
    // MARK: - Data Collection
    private func collectMonitoringData() {
        Task {
            await collectSystemHealth()
            await collectPerformanceMetrics()
            await collectStreamMetrics()
            await collectUserEngagementData()
            await updateSystemStatus()
        }
    }
    
    private func collectSystemHealth() async {
        let healthScore = calculateSystemHealthScore()
        let healthDataPoint = HealthDataPoint(
            timestamp: Date(),
            healthScore: healthScore,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            thermalState: thermalState
        )
        
        await MainActor.run {
            healthHistory.append(healthDataPoint)
            
            // Keep only last 100 data points
            if healthHistory.count > 100 {
                healthHistory.removeFirst()
            }
        }
    }
    
    private func collectPerformanceMetrics() async {
        guard let frameRate = performanceMonitor?.frameRate else { return }
        
        let frameRateDataPoint = FrameRateDataPoint(
            timestamp: Date(),
            frameRate: frameRate,
            frameDropRate: performanceMonitor?.frameDropRate ?? 0.0
        )
        
        let memoryDataPoint = MemoryUsageDataPoint(
            timestamp: Date(),
            memoryUsage: memoryUsage,
            memoryPressure: memoryUsage > 0.8
        )
        
        await MainActor.run {
            frameRateHistory.append(frameRateDataPoint)
            memoryUsageHistory.append(memoryDataPoint)
            
            // Keep only last 100 data points
            if frameRateHistory.count > 100 {
                frameRateHistory.removeFirst()
            }
            if memoryUsageHistory.count > 100 {
                memoryUsageHistory.removeFirst()
            }
        }
    }
    
    private func collectStreamMetrics() async {
        // Collect stream quality metrics
        let streamMetrics = await StreamQualityMonitor.shared.getCurrentMetrics()
        
        await MainActor.run {
            streamQualityMetrics = streamMetrics
            
            // Update active streams status
            activeStreams = StreamManager.shared.getActiveStreamsStatus()
        }
    }
    
    private func collectUserEngagementData() async {
        // Collect user engagement metrics from analytics
        let engagementMetrics = await UserBehaviorAnalyzer.shared.getCurrentEngagementMetrics()
        
        await MainActor.run {
            userEngagementMetrics = engagementMetrics
        }
    }
    
    private func updateSystemStatus() async {
        let healthScore = calculateSystemHealthScore()
        let newStatus: SystemStatus
        
        if healthScore >= 0.8 {
            newStatus = .healthy
        } else if healthScore >= 0.6 {
            newStatus = .warning
        } else {
            newStatus = .critical
        }
        
        await MainActor.run {
            if systemStatus != newStatus {
                systemStatus = newStatus
                
                // Send notification about status change
                NotificationCenter.default.post(
                    name: .systemStatusChanged,
                    object: self,
                    userInfo: ["status": newStatus]
                )
                
                // Track status change
                analyticsManager.trackSystemStatusChange(from: systemStatus, to: newStatus)
            }
        }
    }
    
    // MARK: - Calculations
    private func calculateSystemHealthScore() -> Double {
        var score = 1.0
        
        // CPU usage impact
        if cpuUsage > 0.8 {
            score -= 0.3
        } else if cpuUsage > 0.6 {
            score -= 0.1
        }
        
        // Memory usage impact
        if memoryUsage > 0.8 {
            score -= 0.3
        } else if memoryUsage > 0.6 {
            score -= 0.1
        }
        
        // Thermal state impact
        switch thermalState {
        case .normal:
            break
        case .warm:
            score -= 0.1
        case .hot:
            score -= 0.2
        case .critical:
            score -= 0.4
        }
        
        // Frame rate impact
        if let frameRate = performanceMonitor?.frameRate {
            if frameRate < 30 {
                score -= 0.2
            } else if frameRate < 45 {
                score -= 0.1
            }
        }
        
        // Active streams health
        let unhealthyStreams = activeStreams.filter { !$0.isHealthy }.count
        if unhealthyStreams > 0 {
            score -= Double(unhealthyStreams) * 0.1
        }
        
        return max(0.0, min(1.0, score))
    }
    
    // MARK: - Event Handlers
    private func handlePerformanceUpdate(_ notification: Notification) {
        guard let metrics = notification.userInfo?["metrics"] as? PerformanceMetrics else { return }
        
        // Update performance metrics
        let performanceMetric = PerformanceMetric(
            timestamp: Date(),
            cpuUsage: metrics.cpuUsage,
            memoryUsage: metrics.memoryUsage,
            frameRate: metrics.frameRate,
            frameDropRate: metrics.frameDropRate,
            networkThroughput: metrics.networkThroughput,
            bufferHealth: metrics.bufferHealth
        )
        
        performanceMetrics.append(performanceMetric)
        
        // Keep only last 100 metrics
        if performanceMetrics.count > 100 {
            performanceMetrics.removeFirst()
        }
        
        // Check for performance alerts
        checkPerformanceAlerts(performanceMetric)
    }
    
    private func handleMemoryPressure(_ notification: Notification) {
        let alert = MonitoringAlert(
            id: UUID(),
            title: "Memory Pressure Detected",
            message: "High memory usage detected. Consider reducing active streams or restarting the app.",
            severity: .warning,
            timestamp: Date(),
            category: .performance,
            isActive: true
        )
        
        alerts.append(alert)
        
        // Track memory pressure event
        analyticsManager.trackMemoryPressure(usage: memoryUsage)
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
        
        // Check for thermal alerts
        if thermalState == .hot || thermalState == .critical {
            let alert = MonitoringAlert(
                id: UUID(),
                title: "Thermal Warning",
                message: "Device temperature is high. Performance may be throttled.",
                severity: thermalState == .critical ? .critical : .warning,
                timestamp: Date(),
                category: .system,
                isActive: true
            )
            
            alerts.append(alert)
        }
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let networkMetric = NetworkMetric(
            timestamp: Date(),
            isConnected: path.status == .satisfied,
            connectionType: path.availableInterfaces.first?.type.description ?? "Unknown",
            bandwidth: estimateBandwidth(for: path)
        )
        
        networkMetrics.append(networkMetric)
        
        // Keep only last 100 metrics
        if networkMetrics.count > 100 {
            networkMetrics.removeFirst()
        }
        
        // Update network throughput
        networkThroughput = networkMetric.bandwidth
    }
    
    private func estimateBandwidth(for path: NWPath) -> Double {
        // Simplified bandwidth estimation
        // In a real implementation, you'd measure actual throughput
        if path.isExpensive {
            return 1_000_000 // 1 MB/s for cellular
        } else {
            return 10_000_000 // 10 MB/s for Wi-Fi
        }
    }
    
    // MARK: - Alert Management
    private func checkPerformanceAlerts(_ metric: PerformanceMetric) {
        // CPU usage alert
        if metric.cpuUsage > 0.9 {
            createAlert(
                title: "High CPU Usage",
                message: "CPU usage is above 90%. Consider reducing active streams.",
                severity: .warning,
                category: .performance
            )
        }
        
        // Memory usage alert
        if metric.memoryUsage > 0.85 {
            createAlert(
                title: "High Memory Usage",
                message: "Memory usage is above 85%. App may become unstable.",
                severity: .warning,
                category: .performance
            )
        }
        
        // Frame rate alert
        if metric.frameRate < 20 {
            createAlert(
                title: "Poor Frame Rate",
                message: "Frame rate is below 20 FPS. User experience may be degraded.",
                severity: .warning,
                category: .performance
            )
        }
        
        // Buffer health alert
        if metric.bufferHealth < 0.5 {
            createAlert(
                title: "Poor Buffer Health",
                message: "Stream buffering issues detected. Check network connection.",
                severity: .warning,
                category: .streaming
            )
        }
    }
    
    private func createAlert(title: String, message: String, severity: AlertSeverity, category: AlertCategory) {
        let alert = MonitoringAlert(
            id: UUID(),
            title: title,
            message: message,
            severity: severity,
            timestamp: Date(),
            category: category,
            isActive: true
        )
        
        alerts.append(alert)
        
        // Track alert
        analyticsManager.trackAlert(alert: alert)
        
        // Send notification
        NotificationCenter.default.post(
            name: .monitoringAlertCreated,
            object: self,
            userInfo: ["alert": alert]
        )
    }
    
    // MARK: - Public Methods
    func refreshData() async {
        isRefreshing = true
        
        await collectMonitoringData()
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    func refreshSystemHealth() async {
        await collectSystemHealth()
    }
    
    func refreshPerformanceMetrics() async {
        await collectPerformanceMetrics()
    }
    
    func refreshStreamQuality() async {
        await collectStreamMetrics()
    }
    
    func refreshUserAnalytics() async {
        await collectUserEngagementData()
    }
    
    func dismissAlert(_ alert: MonitoringAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].isActive = false
        }
    }
    
    func getSystemHealthReport() -> SystemHealthReport {
        return SystemHealthReport(
            systemStatus: systemStatus,
            healthScore: calculateSystemHealthScore(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            thermalState: thermalState,
            activeStreams: activeStreams.count,
            activeAlerts: alerts.filter { $0.isActive }.count,
            timestamp: Date()
        )
    }
}

// MARK: - Extensions for Analytics
extension AnalyticsManager {
    func trackSystemStatusChange(from oldStatus: SystemStatus, to newStatus: SystemStatus) {
        track(name: "system_status_changed", properties: [
            "old_status": oldStatus.rawValue,
            "new_status": newStatus.rawValue
        ])
    }
    
    func trackMemoryPressure(usage: Double) {
        track(name: "memory_pressure", properties: [
            "memory_usage": usage
        ])
    }
    
    func trackAlert(alert: MonitoringAlert) {
        track(name: "monitoring_alert", properties: [
            "alert_title": alert.title,
            "alert_severity": alert.severity.rawValue,
            "alert_category": alert.category.rawValue
        ])
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let systemStatusChanged = Notification.Name("systemStatusChanged")
    static let monitoringAlertCreated = Notification.Name("monitoringAlertCreated")
    static let performanceMetricsUpdated = Notification.Name("performanceMetricsUpdated")
}

// MARK: - Network Interface Extension
extension NWInterface.InterfaceType {
    var description: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }
}