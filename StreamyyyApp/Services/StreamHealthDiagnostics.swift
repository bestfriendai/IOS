//
//  StreamHealthDiagnostics.swift
//  StreamyyyApp
//
//  Comprehensive stream health monitoring and diagnostics
//

import Foundation
import SwiftUI
import Combine
import Network
import WebKit

// MARK: - Stream Health Diagnostics

public class StreamHealthDiagnostics: ObservableObject {
    @Published public var streamHealth: StreamHealthStatus = .unknown
    @Published public var connectionQuality: ConnectionQuality = .unknown
    @Published public var diagnosticsReport: DiagnosticsReport = DiagnosticsReport()
    @Published public var activeIssues: [StreamIssue] = []
    
    private var currentStreamURL: String?
    private var currentPlatform: Platform?
    private var webView: WKWebView?
    
    private let diagnosticsQueue = DispatchQueue(label: "StreamHealthDiagnostics", qos: .utility)
    private var healthCheckTimer: Timer?
    private var connectionTestTimer: Timer?
    
    // Health monitoring
    private var healthHistory: [HealthCheckPoint] = []
    private var connectionAttempts: Int = 0
    private var successfulConnections: Int = 0
    private var lastHealthCheck: Date = Date()
    
    // Error tracking
    private var errorHistory: [StreamError] = []
    private var consecutiveErrors: Int = 0
    
    public func startMonitoring() {
        startHealthChecks()
        startConnectionTesting()
    }
    
    public func stopMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        
        connectionTestTimer?.invalidate()
        connectionTestTimer = nil
    }
    
    public func configureForStream(url: String, platform: Platform) {
        currentStreamURL = url
        currentPlatform = platform
        
        // Reset diagnostics for new stream
        resetDiagnostics()
        
        // Start immediate health check
        performHealthCheck()
    }
    
    public func setWebView(_ webView: WKWebView?) {
        self.webView = webView
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthChecks() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }
    
    private func performHealthCheck() {
        guard let streamURL = currentStreamURL,
              let platform = currentPlatform else { return }
        
        diagnosticsQueue.async { [weak self] in
            self?.runHealthChecks(url: streamURL, platform: platform)
        }
    }
    
    private func runHealthChecks(url: String, platform: Platform) {
        let healthCheck = HealthCheckPoint(
            timestamp: Date(),
            url: url,
            platform: platform,
            connectionStatus: .testing,
            responseTime: 0,
            bufferHealth: 0,
            errorCount: consecutiveErrors
        )
        
        // Test connection
        testConnection(url: url) { [weak self] result in
            self?.handleConnectionTest(result: result, healthCheck: healthCheck)
        }
    }
    
    private func testConnection(url: String, completion: @escaping (ConnectionTestResult) -> Void) {
        guard let testURL = URL(string: url) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let startTime = Date()
        
        var request = URLRequest(url: testURL)
        request.timeoutInterval = 10.0
        request.httpMethod = "HEAD"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let error = error {
                completion(.failure(.networkError(error)))
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    completion(.success(responseTime))
                } else {
                    completion(.failure(.serverError(httpResponse.statusCode, nil)))
                }
            } else {
                completion(.failure(.unknown))
            }
        }.resume()
    }
    
    private func handleConnectionTest(result: ConnectionTestResult, healthCheck: HealthCheckPoint) {
        DispatchQueue.main.async { [weak self] in
            self?.processConnectionTestResult(result: result, healthCheck: healthCheck)
        }
    }
    
    private func processConnectionTestResult(result: ConnectionTestResult, healthCheck: HealthCheckPoint) {
        var updatedHealthCheck = healthCheck
        
        switch result {
        case .success(let responseTime):
            updatedHealthCheck.connectionStatus = .connected
            updatedHealthCheck.responseTime = responseTime
            consecutiveErrors = 0
            successfulConnections += 1
            
        case .failure(let error):
            updatedHealthCheck.connectionStatus = .error
            consecutiveErrors += 1
            recordError(error)
        }
        
        // Update connection attempts
        connectionAttempts += 1
        
        // Add to history
        healthHistory.append(updatedHealthCheck)
        
        // Keep only last 100 checks
        if healthHistory.count > 100 {
            healthHistory.removeFirst()
        }
        
        // Update overall health
        updateStreamHealth()
        
        // Update diagnostics report
        updateDiagnosticsReport()
        
        // Check for issues
        checkForIssues()
    }
    
    // MARK: - Stream Health Assessment
    
    private func updateStreamHealth() {
        guard !healthHistory.isEmpty else {
            streamHealth = .unknown
            return
        }
        
        let recentChecks = healthHistory.suffix(10)
        let successfulChecks = recentChecks.filter { $0.connectionStatus == .connected }
        let successRate = Double(successfulChecks.count) / Double(recentChecks.count)
        
        let averageResponseTime = successfulChecks.map { $0.responseTime }.reduce(0, +) / Double(successfulChecks.count)
        
        // Determine health based on success rate and response time
        if successRate >= 0.9 && averageResponseTime < 1.0 {
            streamHealth = .healthy
        } else if successRate >= 0.7 && averageResponseTime < 2.0 {
            streamHealth = .good
        } else if successRate >= 0.5 && averageResponseTime < 5.0 {
            streamHealth = .warning
        } else {
            streamHealth = .error
        }
    }
    
    private func updateConnectionQuality() {
        guard !healthHistory.isEmpty else {
            connectionQuality = .unknown
            return
        }
        
        let recentChecks = healthHistory.suffix(5)
        let averageResponseTime = recentChecks.map { $0.responseTime }.reduce(0, +) / Double(recentChecks.count)
        
        if averageResponseTime < 0.5 {
            connectionQuality = .excellent
        } else if averageResponseTime < 1.0 {
            connectionQuality = .good
        } else if averageResponseTime < 2.0 {
            connectionQuality = .fair
        } else {
            connectionQuality = .poor
        }
    }
    
    // MARK: - Connection Testing
    
    private func startConnectionTesting() {
        connectionTestTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performConnectionTest()
        }
    }
    
    private func performConnectionTest() {
        guard let streamURL = currentStreamURL else { return }
        
        // Test various aspects of connection
        testLatency(url: streamURL)
        testBandwidth(url: streamURL)
        testBufferHealth()
    }
    
    private func testLatency(url: String) {
        // Implement latency testing
        // This would typically ping the stream server
    }
    
    private func testBandwidth(url: String) {
        // Implement bandwidth testing
        // This would measure actual download speed
    }
    
    private func testBufferHealth() {
        // Check buffer health from WebView
        guard let webView = webView else { return }
        
        let script = """
            (function() {
                const video = document.querySelector('video');
                if (video && video.buffered.length > 0) {
                    const buffered = video.buffered.end(0);
                    const current = video.currentTime;
                    const bufferHealth = buffered - current;
                    
                    window.webkit.messageHandlers.streamHandler.postMessage({
                        type: 'bufferHealth',
                        value: bufferHealth
                    });
                }
            })();
        """
        
        webView.evaluateJavaScript(script)
    }
    
    // MARK: - Error Handling
    
    private func recordError(_ error: StreamError) {
        errorHistory.append(error)
        
        // Keep only last 50 errors
        if errorHistory.count > 50 {
            errorHistory.removeFirst()
        }
        
        // Update diagnostics
        updateDiagnosticsReport()
    }
    
    private func checkForIssues() {
        var issues: [StreamIssue] = []
        
        // Check for connection issues
        if consecutiveErrors >= 3 {
            issues.append(.connectionUnstable)
        }
        
        // Check for performance issues
        if let latestHealth = healthHistory.last {
            if latestHealth.responseTime > 5.0 {
                issues.append(.highLatency)
            }
            
            if latestHealth.bufferHealth < 2.0 {
                issues.append(.bufferingIssues)
            }
        }
        
        // Check error patterns
        let recentErrors = errorHistory.suffix(10)
        let errorTypes = Set(recentErrors.map { type(of: $0) })
        
        if errorTypes.count == 1 && recentErrors.count >= 3 {
            issues.append(.repeatingErrors)
        }
        
        activeIssues = issues
    }
    
    // MARK: - Diagnostics Report
    
    private func updateDiagnosticsReport() {
        let successRate = connectionAttempts > 0 ? Double(successfulConnections) / Double(connectionAttempts) : 0.0
        let averageResponseTime = healthHistory.map { $0.responseTime }.reduce(0, +) / Double(max(healthHistory.count, 1))
        
        diagnosticsReport = DiagnosticsReport(
            streamURL: currentStreamURL ?? "",
            platform: currentPlatform ?? .other,
            lastUpdated: Date(),
            connectionAttempts: connectionAttempts,
            successfulConnections: successfulConnections,
            successRate: successRate,
            averageResponseTime: averageResponseTime,
            consecutiveErrors: consecutiveErrors,
            totalErrors: errorHistory.count,
            streamHealth: streamHealth,
            connectionQuality: connectionQuality,
            recentErrors: Array(errorHistory.suffix(5)),
            healthHistory: Array(healthHistory.suffix(10))
        )
    }
    
    // MARK: - Public Methods
    
    public func getDiagnosticsReport() -> DiagnosticsReport {
        return diagnosticsReport
    }
    
    public func getHealthSummary() -> HealthSummary {
        return HealthSummary(
            overallHealth: streamHealth,
            connectionQuality: connectionQuality,
            uptime: calculateUptime(),
            errorRate: calculateErrorRate(),
            averageResponseTime: diagnosticsReport.averageResponseTime,
            activeIssues: activeIssues
        )
    }
    
    public func getRecommendations() -> [DiagnosticRecommendation] {
        var recommendations: [DiagnosticRecommendation] = []
        
        if streamHealth == .error {
            recommendations.append(.checkInternetConnection)
        }
        
        if consecutiveErrors >= 3 {
            recommendations.append(.restartStream)
        }
        
        if diagnosticsReport.averageResponseTime > 3.0 {
            recommendations.append(.changeServer)
        }
        
        if activeIssues.contains(.bufferingIssues) {
            recommendations.append(.lowerQuality)
        }
        
        return recommendations
    }
    
    // MARK: - Helper Methods
    
    private func resetDiagnostics() {
        healthHistory.removeAll()
        errorHistory.removeAll()
        connectionAttempts = 0
        successfulConnections = 0
        consecutiveErrors = 0
        activeIssues.removeAll()
        streamHealth = .unknown
        connectionQuality = .unknown
    }
    
    private func calculateUptime() -> Double {
        guard !healthHistory.isEmpty else { return 0.0 }
        
        let connectedChecks = healthHistory.filter { $0.connectionStatus == .connected }
        return Double(connectedChecks.count) / Double(healthHistory.count)
    }
    
    private func calculateErrorRate() -> Double {
        guard connectionAttempts > 0 else { return 0.0 }
        
        let errorCount = connectionAttempts - successfulConnections
        return Double(errorCount) / Double(connectionAttempts)
    }
}

// MARK: - Supporting Types

public enum ConnectionQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
    
    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
}

public enum ConnectionStatus: String, CaseIterable {
    case testing = "testing"
    case connected = "connected"
    case error = "error"
    case disconnected = "disconnected"
}

public enum ConnectionTestResult {
    case success(TimeInterval)
    case failure(StreamError)
}

public enum StreamIssue: String, CaseIterable {
    case connectionUnstable = "connection_unstable"
    case highLatency = "high_latency"
    case bufferingIssues = "buffering_issues"
    case repeatingErrors = "repeating_errors"
    case serverDown = "server_down"
    case networkCongestion = "network_congestion"
    
    public var displayName: String {
        switch self {
        case .connectionUnstable: return "Connection Unstable"
        case .highLatency: return "High Latency"
        case .bufferingIssues: return "Buffering Issues"
        case .repeatingErrors: return "Repeating Errors"
        case .serverDown: return "Server Down"
        case .networkCongestion: return "Network Congestion"
        }
    }
    
    public var severity: IssueSeverity {
        switch self {
        case .connectionUnstable, .bufferingIssues:
            return .medium
        case .highLatency, .networkCongestion:
            return .low
        case .repeatingErrors, .serverDown:
            return .high
        }
    }
}

public enum IssueSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var color: Color {
        switch self {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

public enum DiagnosticRecommendation: String, CaseIterable {
    case checkInternetConnection = "check_internet"
    case restartStream = "restart_stream"
    case changeServer = "change_server"
    case lowerQuality = "lower_quality"
    case restartApp = "restart_app"
    case contactSupport = "contact_support"
    
    public var displayText: String {
        switch self {
        case .checkInternetConnection: return "Check internet connection"
        case .restartStream: return "Restart stream"
        case .changeServer: return "Try different server"
        case .lowerQuality: return "Lower stream quality"
        case .restartApp: return "Restart app"
        case .contactSupport: return "Contact support"
        }
    }
}

public struct HealthCheckPoint {
    public let timestamp: Date
    public let url: String
    public let platform: Platform
    public var connectionStatus: ConnectionStatus
    public var responseTime: TimeInterval
    public var bufferHealth: Double
    public let errorCount: Int
}

public struct DiagnosticsReport {
    public let streamURL: String
    public let platform: Platform
    public let lastUpdated: Date
    public let connectionAttempts: Int
    public let successfulConnections: Int
    public let successRate: Double
    public let averageResponseTime: TimeInterval
    public let consecutiveErrors: Int
    public let totalErrors: Int
    public let streamHealth: StreamHealthStatus
    public let connectionQuality: ConnectionQuality
    public let recentErrors: [StreamError]
    public let healthHistory: [HealthCheckPoint]
    
    public init() {
        self.streamURL = ""
        self.platform = .other
        self.lastUpdated = Date()
        self.connectionAttempts = 0
        self.successfulConnections = 0
        self.successRate = 0.0
        self.averageResponseTime = 0.0
        self.consecutiveErrors = 0
        self.totalErrors = 0
        self.streamHealth = .unknown
        self.connectionQuality = .unknown
        self.recentErrors = []
        self.healthHistory = []
    }
}

public struct HealthSummary {
    public let overallHealth: StreamHealthStatus
    public let connectionQuality: ConnectionQuality
    public let uptime: Double
    public let errorRate: Double
    public let averageResponseTime: TimeInterval
    public let activeIssues: [StreamIssue]
    
    public var healthScore: Double {
        var score = 100.0
        
        // Health status impact
        switch overallHealth {
        case .healthy: break
        case .good: score -= 10
        case .warning: score -= 30
        case .error: score -= 60
        case .unknown: score -= 20
        }
        
        // Connection quality impact
        switch connectionQuality {
        case .excellent: break
        case .good: score -= 5
        case .fair: score -= 15
        case .poor: score -= 35
        case .unknown: score -= 10
        }
        
        // Uptime impact
        score -= (1.0 - uptime) * 30
        
        // Error rate impact
        score -= errorRate * 40
        
        // Response time impact
        if averageResponseTime > 2.0 {
            score -= 20
        }
        
        // Active issues impact
        for issue in activeIssues {
            switch issue.severity {
            case .low: score -= 5
            case .medium: score -= 10
            case .high: score -= 20
            case .critical: score -= 40
            }
        }
        
        return max(0, min(100, score))
    }
}