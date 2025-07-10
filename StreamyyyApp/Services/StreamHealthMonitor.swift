//
//  StreamHealthMonitor.swift
//  StreamyyyApp
//
//  Monitor stream health and performance with real-time diagnostics
//

import Foundation
import SwiftUI
import Combine
import Network

// MARK: - Stream Health Monitor
@MainActor
public class StreamHealthMonitor: ObservableObject {
    
    // MARK: - Properties
    public static let shared = StreamHealthMonitor()
    
    @Published public var healthUpdates: [StreamHealthUpdate] = []
    @Published public var isMonitoring: Bool = false
    @Published public var monitoredStreams: [String: StreamHealthData] = [:]
    @Published public var systemHealth: SystemHealthStatus = .healthy
    
    // Monitoring configuration
    private let monitoringInterval: TimeInterval = 30.0
    private let healthCheckTimeout: TimeInterval = 10.0
    private let maxConnectionAttempts: Int = 3
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "health.network.monitor")
    
    // Timers and monitoring
    private var healthCheckTimers: [String: Timer] = [:]
    private var urlSession: URLSession
    
    // Metrics collection
    private var performanceMetrics: [String: StreamPerformanceData] = [:]
    private var healthHistory: [String: [StreamHealthSnapshot]] = [:]
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init() {
        // Configure URL session for health checks
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = healthCheckTimeout
        configuration.timeoutIntervalForResource = healthCheckTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        self.urlSession = URLSession(configuration: configuration)
        
        setupNetworkMonitoring()
        startSystemHealthMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path: path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func updateNetworkStatus(path: NWPath) {
        let wasConnected = systemHealth.isNetworkConnected
        systemHealth.isNetworkConnected = path.status == .satisfied
        
        if !wasConnected && systemHealth.isNetworkConnected {
            // Network restored, resume monitoring
            resumeAllMonitoring()
        } else if wasConnected && !systemHealth.isNetworkConnected {
            // Network lost, pause monitoring
            pauseAllMonitoring()
        }
    }
    
    // MARK: - Stream Monitoring
    public func startMonitoring(stream: Stream) async {
        guard !monitoredStreams.keys.contains(stream.id) else { return }
        
        let healthData = StreamHealthData(
            streamId: stream.id,
            url: stream.url,
            platform: stream.platform,
            status: .unknown,
            lastCheck: Date(),
            responseTime: 0,
            errorCount: 0,
            uptime: 0
        )
        
        monitoredStreams[stream.id] = healthData
        
        // Start periodic health checks
        startHealthCheckTimer(for: stream.id)
        
        // Perform initial health check
        await performHealthCheck(streamId: stream.id)
        
        print("✅ Started monitoring stream: \(stream.title)")
    }
    
    public func stopMonitoring(streamId: String) async {
        guard monitoredStreams.keys.contains(streamId) else { return }
        
        // Stop timer
        healthCheckTimers[streamId]?.invalidate()
        healthCheckTimers.removeValue(forKey: streamId)
        
        // Remove from monitoring
        monitoredStreams.removeValue(forKey: streamId)
        performanceMetrics.removeValue(forKey: streamId)
        healthHistory.removeValue(forKey: streamId)
        
        print("⏹️ Stopped monitoring stream: \(streamId)")
    }
    
    public func pauseMonitoring(streamId: String) {
        healthCheckTimers[streamId]?.invalidate()
        healthCheckTimers.removeValue(forKey: streamId)
    }
    
    public func resumeMonitoring(streamId: String) {
        guard monitoredStreams.keys.contains(streamId) else { return }
        startHealthCheckTimer(for: streamId)
    }
    
    private func pauseAllMonitoring() {
        for streamId in monitoredStreams.keys {
            pauseMonitoring(streamId: streamId)
        }
        isMonitoring = false
    }
    
    private func resumeAllMonitoring() {
        for streamId in monitoredStreams.keys {
            resumeMonitoring(streamId: streamId)
        }
        isMonitoring = true
    }
    
    // MARK: - Health Check Timer
    private func startHealthCheckTimer(for streamId: String) {
        let timer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { _ in
            Task {
                await self.performHealthCheck(streamId: streamId)
            }
        }
        
        healthCheckTimers[streamId] = timer
        isMonitoring = true
    }
    
    // MARK: - Health Check Implementation
    private func performHealthCheck(streamId: String) async {
        guard let healthData = monitoredStreams[streamId] else { return }
        
        let startTime = Date()
        
        do {
            let status = try await checkStreamHealth(url: healthData.url, platform: healthData.platform)
            let responseTime = Date().timeIntervalSince(startTime)
            
            // Update health data
            var updatedHealthData = healthData
            updatedHealthData.status = status
            updatedHealthData.lastCheck = Date()
            updatedHealthData.responseTime = responseTime
            updatedHealthData.errorCount = 0 // Reset error count on success
            updatedHealthData.uptime += monitoringInterval
            
            monitoredStreams[streamId] = updatedHealthData
            
            // Record performance metrics
            updatePerformanceMetrics(streamId: streamId, responseTime: responseTime, success: true)
            
            // Record health snapshot
            recordHealthSnapshot(streamId: streamId, status: status, responseTime: responseTime)
            
            // Notify observers
            let healthUpdate = StreamHealthUpdate(
                streamId: streamId,
                status: status,
                responseTime: responseTime,
                timestamp: Date()
            )
            
            healthUpdates.append(healthUpdate)
            
            // Keep only recent updates
            if healthUpdates.count > 100 {
                healthUpdates.removeFirst()
            }
            
        } catch {
            await handleHealthCheckError(streamId: streamId, error: error)
        }
    }
    
    private func checkStreamHealth(url: String, platform: Platform) async throws -> StreamHealthStatus {
        // Determine the appropriate health check URL based on platform
        let healthCheckURL = try getHealthCheckURL(for: url, platform: platform)
        
        guard let url = URL(string: healthCheckURL) else {
            throw StreamHealthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StreamHealthError.invalidResponse
            }
            
            return interpretHealthStatus(statusCode: httpResponse.statusCode, platform: platform)
            
        } catch {
            throw StreamHealthError.networkError(error)
        }
    }
    
    private func getHealthCheckURL(for streamURL: String, platform: Platform) throws -> String {
        switch platform {
        case .twitch:
            // For Twitch, we can check the channel endpoint
            if let channelName = extractTwitchChannelName(from: streamURL) {
                return "https://api.twitch.tv/helix/streams?user_login=\(channelName)"
            }
            
        case .youtube:
            // For YouTube, we can check the video/channel endpoint
            if let videoId = extractYouTubeVideoId(from: streamURL) {
                return "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=\(videoId)"
            }
            
        case .kick:
            // For Kick, we can check the channel endpoint
            if let channelName = extractKickChannelName(from: streamURL) {
                return "https://kick.com/api/v1/channels/\(channelName)"
            }
            
        default:
            // For other platforms, use the original URL
            return streamURL
        }
        
        throw StreamHealthError.unsupportedPlatform
    }
    
    private func interpretHealthStatus(statusCode: Int, platform: Platform) -> StreamHealthStatus {
        switch statusCode {
        case 200...299:
            return .healthy
        case 300...399:
            return .good
        case 400...499:
            return .warning
        case 500...599:
            return .error
        default:
            return .unknown
        }
    }
    
    private func handleHealthCheckError(streamId: String, error: Error) async {
        guard var healthData = monitoredStreams[streamId] else { return }
        
        healthData.errorCount += 1
        healthData.lastCheck = Date()
        healthData.status = .error
        
        // If too many consecutive errors, mark as offline
        if healthData.errorCount >= maxConnectionAttempts {
            healthData.status = .unknown
        }
        
        monitoredStreams[streamId] = healthData
        
        // Record performance metrics
        updatePerformanceMetrics(streamId: streamId, responseTime: 0, success: false)
        
        // Record health snapshot
        recordHealthSnapshot(streamId: streamId, status: healthData.status, responseTime: 0)
        
        // Notify observers
        let healthUpdate = StreamHealthUpdate(
            streamId: streamId,
            status: healthData.status,
            responseTime: 0,
            timestamp: Date(),
            error: error
        )
        
        healthUpdates.append(healthUpdate)
        
        print("❌ Health check failed for stream \(streamId): \(error)")
    }
    
    // MARK: - URL Extraction Helpers
    private func extractTwitchChannelName(from url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        let pathComponents = url.pathComponents
        return pathComponents.count > 1 ? pathComponents[1] : nil
    }
    
    private func extractYouTubeVideoId(from url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        
        if url.absoluteString.contains("watch?v=") {
            return url.query?.components(separatedBy: "&")
                .first(where: { $0.hasPrefix("v=") })?
                .replacingOccurrences(of: "v=", with: "")
        }
        
        return url.pathComponents.last
    }
    
    private func extractKickChannelName(from url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        return url.pathComponents.last
    }
    
    // MARK: - Performance Metrics
    private func updatePerformanceMetrics(streamId: String, responseTime: TimeInterval, success: Bool) {
        var metrics = performanceMetrics[streamId] ?? StreamPerformanceData(
            streamId: streamId,
            totalChecks: 0,
            successfulChecks: 0,
            averageResponseTime: 0,
            minResponseTime: 0,
            maxResponseTime: 0,
            lastUpdated: Date()
        )
        
        metrics.totalChecks += 1
        
        if success {
            metrics.successfulChecks += 1
            
            // Update response time metrics
            if metrics.minResponseTime == 0 || responseTime < metrics.minResponseTime {
                metrics.minResponseTime = responseTime
            }
            
            if responseTime > metrics.maxResponseTime {
                metrics.maxResponseTime = responseTime
            }
            
            // Calculate new average
            let totalResponseTime = metrics.averageResponseTime * Double(metrics.successfulChecks - 1)
            metrics.averageResponseTime = (totalResponseTime + responseTime) / Double(metrics.successfulChecks)
        }
        
        metrics.lastUpdated = Date()
        performanceMetrics[streamId] = metrics
    }
    
    private func recordHealthSnapshot(streamId: String, status: StreamHealthStatus, responseTime: TimeInterval) {
        let snapshot = StreamHealthSnapshot(
            timestamp: Date(),
            status: status,
            responseTime: responseTime
        )
        
        if healthHistory[streamId] == nil {
            healthHistory[streamId] = []
        }
        
        healthHistory[streamId]?.append(snapshot)
        
        // Keep only last 100 snapshots
        if let count = healthHistory[streamId]?.count, count > 100 {
            healthHistory[streamId]?.removeFirst()
        }
    }
    
    // MARK: - System Health Monitoring
    private func startSystemHealthMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.updateSystemHealth()
        }
    }
    
    private func updateSystemHealth() {
        let totalStreams = monitoredStreams.count
        let healthyStreams = monitoredStreams.values.filter { $0.status == .healthy || $0.status == .good }.count
        
        systemHealth.totalStreams = totalStreams
        systemHealth.healthyStreams = healthyStreams
        systemHealth.lastUpdated = Date()
        
        // Determine overall system health
        if totalStreams == 0 {
            systemHealth.overallStatus = .healthy
        } else {
            let healthPercentage = Double(healthyStreams) / Double(totalStreams)
            
            if healthPercentage >= 0.9 {
                systemHealth.overallStatus = .healthy
            } else if healthPercentage >= 0.7 {
                systemHealth.overallStatus = .good
            } else if healthPercentage >= 0.5 {
                systemHealth.overallStatus = .warning
            } else {
                systemHealth.overallStatus = .error
            }
        }
    }
    
    // MARK: - Public API
    public func getStreamHealth(streamId: String) -> StreamHealthData? {
        return monitoredStreams[streamId]
    }
    
    public func getStreamPerformance(streamId: String) -> StreamPerformanceData? {
        return performanceMetrics[streamId]
    }
    
    public func getStreamHealthHistory(streamId: String) -> [StreamHealthSnapshot]? {
        return healthHistory[streamId]
    }
    
    public func getAverageResponseTime() -> TimeInterval {
        let allMetrics = performanceMetrics.values
        guard !allMetrics.isEmpty else { return 0 }
        
        let totalResponseTime = allMetrics.reduce(0) { $0 + $1.averageResponseTime }
        return totalResponseTime / Double(allMetrics.count)
    }
    
    public func getSystemHealthReport() -> SystemHealthReport {
        return SystemHealthReport(
            totalStreams: systemHealth.totalStreams,
            healthyStreams: systemHealth.healthyStreams,
            averageResponseTime: getAverageResponseTime(),
            uptime: systemHealth.uptime,
            lastUpdated: systemHealth.lastUpdated
        )
    }
    
    // MARK: - Cleanup
    deinit {
        healthCheckTimers.values.forEach { $0.invalidate() }
        networkMonitor.cancel()
        cancellables.removeAll()
    }
}

// MARK: - Stream Health Data
public struct StreamHealthData {
    public let streamId: String
    public let url: String
    public let platform: Platform
    public var status: StreamHealthStatus
    public var lastCheck: Date
    public var responseTime: TimeInterval
    public var errorCount: Int
    public var uptime: TimeInterval
    
    public var healthPercentage: Double {
        guard errorCount > 0 else { return 100.0 }
        return max(0, 100.0 - (Double(errorCount) * 10.0))
    }
}

// MARK: - Stream Health Update
public struct StreamHealthUpdate {
    public let streamId: String
    public let status: StreamHealthStatus
    public let responseTime: TimeInterval
    public let timestamp: Date
    public let error: Error?
    
    public init(streamId: String, status: StreamHealthStatus, responseTime: TimeInterval, timestamp: Date, error: Error? = nil) {
        self.streamId = streamId
        self.status = status
        self.responseTime = responseTime
        self.timestamp = timestamp
        self.error = error
    }
}

// MARK: - Stream Performance Data
public struct StreamPerformanceData {
    public let streamId: String
    public var totalChecks: Int
    public var successfulChecks: Int
    public var averageResponseTime: TimeInterval
    public var minResponseTime: TimeInterval
    public var maxResponseTime: TimeInterval
    public var lastUpdated: Date
    
    public var successRate: Double {
        guard totalChecks > 0 else { return 0 }
        return Double(successfulChecks) / Double(totalChecks) * 100
    }
}

// MARK: - Stream Health Snapshot
public struct StreamHealthSnapshot {
    public let timestamp: Date
    public let status: StreamHealthStatus
    public let responseTime: TimeInterval
}

// MARK: - System Health Status
public struct SystemHealthStatus {
    public var totalStreams: Int = 0
    public var healthyStreams: Int = 0
    public var overallStatus: StreamHealthStatus = .healthy
    public var isNetworkConnected: Bool = true
    public var uptime: TimeInterval = 0
    public var lastUpdated: Date = Date()
    
    public var healthPercentage: Double {
        guard totalStreams > 0 else { return 100.0 }
        return Double(healthyStreams) / Double(totalStreams) * 100
    }
}

// MARK: - System Health Report
public struct SystemHealthReport {
    public let totalStreams: Int
    public let healthyStreams: Int
    public let averageResponseTime: TimeInterval
    public let uptime: TimeInterval
    public let lastUpdated: Date
    
    public var healthPercentage: Double {
        guard totalStreams > 0 else { return 100.0 }
        return Double(healthyStreams) / Double(totalStreams) * 100
    }
    
    public var status: StreamHealthStatus {
        if healthPercentage >= 90 {
            return .healthy
        } else if healthPercentage >= 70 {
            return .good
        } else if healthPercentage >= 50 {
            return .warning
        } else {
            return .error
        }
    }
}

// MARK: - Stream Health Errors
public enum StreamHealthError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case unsupportedPlatform
    case timeout
    case tooManyErrors
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for health check"
        case .invalidResponse:
            return "Invalid response from health check"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unsupportedPlatform:
            return "Unsupported platform for health monitoring"
        case .timeout:
            return "Health check timeout"
        case .tooManyErrors:
            return "Too many consecutive errors"
        }
    }
}