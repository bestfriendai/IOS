//
//  MonitoringModels.swift
//  StreamyyyApp
//
//  Data models for monitoring, analytics, and quality assurance
//

import Foundation
import SwiftUI

// MARK: - System Status
enum SystemStatus: String, CaseIterable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .healthy:
            return .green
        case .warning:
            return .yellow
        case .critical:
            return .red
        }
    }
}

// MARK: - Thermal State
enum ThermalState: String, CaseIterable {
    case normal = "normal"
    case warm = "warm"
    case hot = "hot"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .warm:
            return "Warm"
        case .hot:
            return "Hot"
        case .critical:
            return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .normal:
            return .green
        case .warm:
            return .yellow
        case .hot:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Alert Models
enum AlertSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .error:
            return .orange
        case .critical:
            return .red
        }
    }
}

enum AlertCategory: String, CaseIterable {
    case system = "system"
    case performance = "performance"
    case streaming = "streaming"
    case network = "network"
    case user = "user"
    case security = "security"
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .performance:
            return "Performance"
        case .streaming:
            return "Streaming"
        case .network:
            return "Network"
        case .user:
            return "User"
        case .security:
            return "Security"
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "gear"
        case .performance:
            return "speedometer"
        case .streaming:
            return "play.circle"
        case .network:
            return "wifi"
        case .user:
            return "person.circle"
        case .security:
            return "shield"
        }
    }
}

struct MonitoringAlert: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    let category: AlertCategory
    var isActive: Bool
    var acknowledgedAt: Date?
    var resolvedAt: Date?
    
    init(id: UUID = UUID(), title: String, message: String, severity: AlertSeverity, timestamp: Date, category: AlertCategory, isActive: Bool = true) {
        self.id = id
        self.title = title
        self.message = message
        self.severity = severity
        self.timestamp = timestamp
        self.category = category
        self.isActive = isActive
    }
}

// MARK: - Performance Models
struct PerformanceMetrics: Codable {
    var cpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var frameRate: Double = 0.0
    var frameDropRate: Double = 0.0
    var networkThroughput: Double = 0.0
    var bufferHealth: Double = 0.0
    var timestamp: Date = Date()
}

struct PerformanceMetric: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let frameRate: Double
    let frameDropRate: Double
    let networkThroughput: Double
    let bufferHealth: Double
    
    var performanceScore: Double {
        let cpuScore = max(0, 1.0 - cpuUsage)
        let memoryScore = max(0, 1.0 - memoryUsage)
        let frameScore = min(1.0, frameRate / 60.0)
        let dropScore = max(0, 1.0 - frameDropRate)
        let bufferScore = bufferHealth
        
        return (cpuScore + memoryScore + frameScore + dropScore + bufferScore) / 5.0
    }
}

// MARK: - Health Data Models
struct HealthDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let healthScore: Double
    let cpuUsage: Double
    let memoryUsage: Double
    let thermalState: ThermalState
}

struct FrameRateDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let frameRate: Double
    let frameDropRate: Double
}

struct MemoryUsageDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let memoryUsage: Double
    let memoryPressure: Bool
}

struct NetworkMetric: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let isConnected: Bool
    let connectionType: String
    let bandwidth: Double
    let latency: Double?
    
    init(timestamp: Date, isConnected: Bool, connectionType: String, bandwidth: Double, latency: Double? = nil) {
        self.timestamp = timestamp
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.bandwidth = bandwidth
        self.latency = latency
    }
}

// MARK: - Stream Quality Models
struct StreamQualityMetric: Identifiable, Codable {
    let id = UUID()
    let streamId: String
    let platform: String
    let quality: String
    let bufferEvents: Int
    let latency: Double
    let loadTime: Double
    let viewerCount: Int
    let timestamp: Date
    
    var qualityScore: Double {
        var score = 100.0
        
        // Buffer events impact
        score -= Double(bufferEvents) * 10.0
        
        // Latency impact
        if latency > 5.0 {
            score -= (latency - 5.0) * 5.0
        }
        
        // Load time impact
        if loadTime > 3.0 {
            score -= (loadTime - 3.0) * 10.0
        }
        
        return max(0, min(100, score))
    }
}

struct StreamStatus: Identifiable, Codable {
    let id = UUID()
    let streamId: String
    let title: String
    let platform: String
    let isHealthy: Bool
    let viewerCount: Int
    let quality: String
    let bufferHealth: Double
    let latency: Double
    let timestamp: Date
}

// MARK: - User Engagement Models
struct UserEngagementMetric: Identifiable, Codable {
    let id = UUID()
    let userId: String?
    let sessionId: String
    let action: String
    let duration: TimeInterval
    let engagementScore: Double
    let timestamp: Date
}

struct UserBehaviorEvent: Identifiable, Codable {
    let id = UUID()
    let userId: String?
    let sessionId: String
    let event: String
    let properties: [String: String]
    let timestamp: Date
}

struct FeatureAdoptionMetric: Identifiable, Codable {
    let id = UUID()
    let feature: String
    let adoptionRate: Double
    let totalUsers: Int
    let adoptedUsers: Int
    let averageTimeToAdopt: TimeInterval
    let timestamp: Date
}

// MARK: - A/B Testing Models
struct ABTestResult: Identifiable, Codable {
    let id = UUID()
    let testName: String
    let variant: String
    let participantCount: Int
    let conversionRate: Double
    let conversionCount: Int
    let statisticalSignificance: Double
    let isWinner: Bool
    let timestamp: Date
}

struct ABTestMetric: Identifiable, Codable {
    let id = UUID()
    let testName: String
    let variant: String
    let metric: String
    let value: Double
    let timestamp: Date
}

// MARK: - Error and Crash Models
struct ErrorReport: Identifiable, Codable {
    let id = UUID()
    let error: String
    let stackTrace: String?
    let context: [String: String]
    let userId: String?
    let sessionId: String
    let deviceInfo: DeviceInfo
    let timestamp: Date
    let isCrash: Bool
    let isRecovered: Bool
}

struct DeviceInfo: Codable {
    let model: String
    let osVersion: String
    let appVersion: String
    let buildNumber: String
    let memoryTotal: Double
    let storageTotal: Double
    let thermalState: String
    let batteryLevel: Double?
    let isLowPowerMode: Bool
}

// MARK: - Quality Assurance Models
struct QATestResult: Identifiable, Codable {
    let id = UUID()
    let testName: String
    let testSuite: String
    let status: QATestStatus
    let duration: TimeInterval
    let failureReason: String?
    let assertions: Int
    let passedAssertions: Int
    let timestamp: Date
}

enum QATestStatus: String, CaseIterable, Codable {
    case passed = "passed"
    case failed = "failed"
    case skipped = "skipped"
    case error = "error"
    
    var color: Color {
        switch self {
        case .passed:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .yellow
        case .error:
            return .orange
        }
    }
}

struct QATestSuite: Identifiable, Codable {
    let id = UUID()
    let name: String
    let tests: [QATestResult]
    let totalTests: Int
    let passedTests: Int
    let failedTests: Int
    let skippedTests: Int
    let totalDuration: TimeInterval
    let timestamp: Date
    
    var passRate: Double {
        guard totalTests > 0 else { return 0.0 }
        return Double(passedTests) / Double(totalTests)
    }
}

// MARK: - Business Intelligence Models
struct BusinessMetric: Identifiable, Codable {
    let id = UUID()
    let name: String
    let value: Double
    let category: String
    let unit: String
    let timestamp: Date
    let metadata: [String: String]
}

struct RevenueMetric: Identifiable, Codable {
    let id = UUID()
    let amount: Double
    let currency: String
    let source: String
    let userId: String?
    let subscriptionId: String?
    let timestamp: Date
}

struct UserRetentionMetric: Identifiable, Codable {
    let id = UUID()
    let cohortDate: Date
    let day: Int
    let totalUsers: Int
    let activeUsers: Int
    let retentionRate: Double
    let timestamp: Date
}

// MARK: - System Health Report
struct SystemHealthReport: Codable {
    let systemStatus: SystemStatus
    let healthScore: Double
    let cpuUsage: Double
    let memoryUsage: Double
    let thermalState: ThermalState
    let activeStreams: Int
    let activeAlerts: Int
    let timestamp: Date
    
    var summary: String {
        return "System is \(systemStatus.displayName.lowercased()) with \(Int(healthScore * 100))% health score"
    }
}

// MARK: - Alert Manager
class AlertManager: ObservableObject {
    static let shared = AlertManager()
    
    @Published var alerts: [MonitoringAlert] = []
    @Published var activeAlerts: [MonitoringAlert] = []
    @Published var alertHistory: [MonitoringAlert] = []
    
    private init() {
        setupAlertObservers()
    }
    
    private func setupAlertObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewAlert),
            name: .monitoringAlertCreated,
            object: nil
        )
    }
    
    @objc private func handleNewAlert(_ notification: Notification) {
        guard let alert = notification.userInfo?["alert"] as? MonitoringAlert else { return }
        
        alerts.append(alert)
        updateActiveAlerts()
    }
    
    private func updateActiveAlerts() {
        activeAlerts = alerts.filter { $0.isActive }
        alertHistory = alerts.filter { !$0.isActive }
    }
    
    func acknowledgeAlert(_ alert: MonitoringAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].acknowledgedAt = Date()
        }
        updateActiveAlerts()
    }
    
    func resolveAlert(_ alert: MonitoringAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].isActive = false
            alerts[index].resolvedAt = Date()
        }
        updateActiveAlerts()
    }
    
    func refreshAlerts() async {
        // Refresh logic for alerts
        updateActiveAlerts()
    }
}

// MARK: - Extensions
extension SystemStatus: Codable {}
extension ThermalState: Codable {}
extension AlertSeverity: Codable {}
extension AlertCategory: Codable {}