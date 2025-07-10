//
//  StreamAnalyticsManager.swift
//  StreamyyyApp
//
//  Comprehensive stream analytics tracking and performance monitoring
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Stream Analytics Manager
@MainActor
public class StreamAnalyticsManager: ObservableObject {
    
    // MARK: - Properties
    public static let shared = StreamAnalyticsManager()
    
    @Published public var isTracking: Bool = false
    @Published public var analyticsData: [StreamAnalytics] = []
    @Published public var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published public var usageStats: UsageStats = UsageStats()
    @Published public var syncStatus: SyncStatus = .disconnected
    
    private let supabaseService = SupabaseService.shared
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Analytics tracking
    private var trackingTimer: Timer?
    private var batchQueue: [StreamAnalytics] = []
    private let batchSize = 50
    private let batchInterval: TimeInterval = 30.0
    
    // Performance monitoring
    private var performanceTimer: Timer?
    private var streamHealthMonitor: [String: StreamHealthData] = [:]
    
    // MARK: - Initialization
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupObservers()
        loadAnalyticsData()
        startPerformanceMonitoring()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        supabaseService.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
            }
            .store(in: &cancellables)
    }
    
    private func loadAnalyticsData() {
        Task {
            do {
                let analytics = try await fetchLocalAnalytics()
                analyticsData = analytics
                updateUsageStats()
                
                print("✅ Analytics data loaded: \(analytics.count) events")
            } catch {
                print("❌ Failed to load analytics data: \(error)")
            }
        }
    }
    
    // MARK: - Analytics Tracking
    public func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        
        // Start batch processing timer
        trackingTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { _ in
            Task {
                await self.processBatch()
            }
        }
        
        print("✅ Analytics tracking started")
    }
    
    public func stopTracking() {
        guard isTracking else { return }
        
        isTracking = false
        
        // Stop timer and process remaining batch
        trackingTimer?.invalidate()
        trackingTimer = nil
        
        Task {
            await processBatch()
        }
        
        print("✅ Analytics tracking stopped")
    }
    
    public func trackEvent(_ event: AnalyticsEvent, streamId: String? = nil, value: Double = 1.0, metadata: [String: String] = [:]) {
        guard isTracking else { return }
        
        let analytics = StreamAnalytics(
            event: event,
            value: value,
            metadata: metadata
        )
        
        // Add to batch queue
        batchQueue.append(analytics)
        
        // Process batch if it's full
        if batchQueue.count >= batchSize {
            Task {
                await processBatch()
            }
        }
        
        // Update performance metrics
        updatePerformanceMetrics(for: event, streamId: streamId, value: value)
    }
    
    private func processBatch() async {
        guard !batchQueue.isEmpty else { return }
        
        let batch = batchQueue
        batchQueue.removeAll()
        
        // Save locally
        for analytics in batch {
            try? await createLocalAnalytics(analytics)
        }
        
        // Sync to remote if connected
        if supabaseService.canSync {
            for analytics in batch {
                try? await supabaseService.recordStreamAnalytics(analytics)
            }
        }
        
        // Update analytics data
        analyticsData.append(contentsOf: batch)
        
        // Update usage stats
        updateUsageStats()
        
        print("✅ Analytics batch processed: \(batch.count) events")
    }
    
    // MARK: - Performance Monitoring
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() async {
        // Update system metrics
        performanceMetrics.updateSystemMetrics()
        
        // Update stream health
        updateStreamHealth()
        
        // Record performance analytics
        if isTracking {
            trackEvent(
                .bufferingEvent,
                value: performanceMetrics.averageBufferHealth,
                metadata: [
                    "memory_usage": "\(performanceMetrics.memoryUsage)",
                    "cpu_usage": "\(performanceMetrics.cpuUsage)",
                    "network_latency": "\(performanceMetrics.networkLatency)"
                ]
            )
        }
    }
    
    private func updatePerformanceMetrics(for event: AnalyticsEvent, streamId: String?, value: Double) {
        switch event {
        case .streamStart:
            performanceMetrics.totalStreamStarts += 1
        case .streamEnd:
            performanceMetrics.totalStreamEnds += 1
            performanceMetrics.totalWatchTime += value
        case .bufferingEvent:
            performanceMetrics.totalBufferingEvents += 1
        case .connectionError:
            performanceMetrics.totalConnectionErrors += 1
        case .qualityChange:
            performanceMetrics.totalQualityChanges += 1
        default:
            break
        }
        
        // Update stream health if streamId provided
        if let streamId = streamId {
            updateStreamHealthData(streamId: streamId, event: event, value: value)
        }
    }
    
    private func updateStreamHealth() {
        // Update health metrics for all monitored streams
        for (streamId, healthData) in streamHealthMonitor {
            let health = calculateStreamHealth(healthData)
            
            // Track health changes
            if health != healthData.lastHealth {
                trackEvent(
                    .connectionError,
                    streamId: streamId,
                    value: health.rawValue,
                    metadata: [
                        "health_change": "\(healthData.lastHealth.rawValue) -> \(health.rawValue)",
                        "buffer_ratio": "\(healthData.bufferRatio)",
                        "error_rate": "\(healthData.errorRate)"
                    ]
                )
                
                streamHealthMonitor[streamId]?.lastHealth = health
            }
        }
    }
    
    private func updateStreamHealthData(streamId: String, event: AnalyticsEvent, value: Double) {
        if streamHealthMonitor[streamId] == nil {
            streamHealthMonitor[streamId] = StreamHealthData()
        }
        
        guard var healthData = streamHealthMonitor[streamId] else { return }
        
        switch event {
        case .bufferingEvent:
            healthData.bufferEvents += 1
            healthData.bufferRatio = min(1.0, healthData.bufferRatio + 0.1)
        case .connectionError:
            healthData.connectionErrors += 1
            healthData.errorRate = min(1.0, healthData.errorRate + 0.1)
        case .streamStart:
            healthData.startTime = Date()
        case .streamEnd:
            healthData.endTime = Date()
            healthData.totalWatchTime = value
        default:
            break
        }
        
        healthData.lastUpdate = Date()
        streamHealthMonitor[streamId] = healthData
    }
    
    private func calculateStreamHealth(_ healthData: StreamHealthData) -> StreamHealthStatus {
        let errorThreshold = 0.1
        let bufferThreshold = 0.3
        
        if healthData.errorRate > errorThreshold {
            return .error
        } else if healthData.bufferRatio > bufferThreshold {
            return .warning
        } else if healthData.errorRate == 0 && healthData.bufferRatio < 0.1 {
            return .healthy
        } else {
            return .good
        }
    }
    
    // MARK: - Usage Statistics
    private func updateUsageStats() {
        let today = Calendar.current.startOfDay(for: Date())
        let thisWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: today) ?? today
        let thisMonth = Calendar.current.date(byAdding: .month, value: -1, to: today) ?? today
        
        let todayEvents = analyticsData.filter { $0.timestamp >= today }
        let weekEvents = analyticsData.filter { $0.timestamp >= thisWeek }
        let monthEvents = analyticsData.filter { $0.timestamp >= thisMonth }
        
        usageStats.dailyEvents = todayEvents.count
        usageStats.weeklyEvents = weekEvents.count
        usageStats.monthlyEvents = monthEvents.count
        
        // Calculate watch time
        let todayWatchTime = todayEvents.filter { $0.event == .streamEnd }.reduce(0) { $0 + $1.value }
        let weekWatchTime = weekEvents.filter { $0.event == .streamEnd }.reduce(0) { $0 + $1.value }
        let monthWatchTime = monthEvents.filter { $0.event == .streamEnd }.reduce(0) { $0 + $1.value }
        
        usageStats.dailyWatchTime = todayWatchTime
        usageStats.weeklyWatchTime = weekWatchTime
        usageStats.monthlyWatchTime = monthWatchTime
        
        // Calculate most watched categories
        let categoryCount = monthEvents.compactMap { $0.metadata["category"] }.reduce(into: [:]) { counts, category in
            counts[category, default: 0] += 1
        }
        
        usageStats.topCategories = categoryCount.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        usageStats.lastUpdated = Date()
    }
    
    // MARK: - Analytics Queries
    public func getAnalytics(for timeRange: TimeRange) async throws -> [StreamAnalytics] {
        let startDate = timeRange.startDate
        let endDate = timeRange.endDate
        
        return analyticsData.filter { analytics in
            analytics.timestamp >= startDate && analytics.timestamp <= endDate
        }
    }
    
    public func getStreamAnalytics(streamId: String, timeRange: TimeRange) async throws -> [StreamAnalytics] {
        let analytics = try await getAnalytics(for: timeRange)
        return analytics.filter { $0.stream?.id == streamId }
    }
    
    public func getEventAnalytics(event: AnalyticsEvent, timeRange: TimeRange) async throws -> [StreamAnalytics] {
        let analytics = try await getAnalytics(for: timeRange)
        return analytics.filter { $0.event == event }
    }
    
    public func getTopStreams(timeRange: TimeRange, limit: Int = 10) async throws -> [(streamId: String, watchTime: TimeInterval)] {
        let analytics = try await getAnalytics(for: timeRange)
        let streamWatchTime = analytics
            .filter { $0.event == .streamEnd }
            .reduce(into: [String: TimeInterval]()) { result, analytics in
                if let streamId = analytics.stream?.id {
                    result[streamId, default: 0] += analytics.value
                }
            }
        
        return streamWatchTime
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (streamId: $0.key, watchTime: $0.value) }
    }
    
    public func getPerformanceReport(timeRange: TimeRange) async throws -> PerformanceReport {
        let analytics = try await getAnalytics(for: timeRange)
        
        let bufferingEvents = analytics.filter { $0.event == .bufferingEvent }
        let connectionErrors = analytics.filter { $0.event == .connectionError }
        let qualityChanges = analytics.filter { $0.event == .qualityChange }
        
        return PerformanceReport(
            timeRange: timeRange,
            totalEvents: analytics.count,
            bufferingEvents: bufferingEvents.count,
            connectionErrors: connectionErrors.count,
            qualityChanges: qualityChanges.count,
            averageBufferTime: bufferingEvents.isEmpty ? 0 : bufferingEvents.reduce(0) { $0 + $1.value } / Double(bufferingEvents.count),
            errorRate: Double(connectionErrors.count) / max(1, Double(analytics.count)),
            healthScore: calculateOverallHealthScore(analytics)
        )
    }
    
    private func calculateOverallHealthScore(_ analytics: [StreamAnalytics]) -> Double {
        let totalEvents = analytics.count
        guard totalEvents > 0 else { return 1.0 }
        
        let errorEvents = analytics.filter { $0.event == .connectionError }.count
        let bufferingEvents = analytics.filter { $0.event == .bufferingEvent }.count
        
        let errorWeight = 0.7
        let bufferWeight = 0.3
        
        let errorScore = max(0, 1.0 - (Double(errorEvents) / Double(totalEvents)) * errorWeight)
        let bufferScore = max(0, 1.0 - (Double(bufferingEvents) / Double(totalEvents)) * bufferWeight)
        
        return (errorScore + bufferScore) / 2.0
    }
    
    // MARK: - Export and Reporting
    public func exportAnalytics(timeRange: TimeRange, format: ExportFormat) async throws -> Data {
        let analytics = try await getAnalytics(for: timeRange)
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(analytics)
            
        case .csv:
            var csv = "timestamp,event,value,metadata\n"
            for analytics in analytics {
                let metadataString = analytics.metadata.map { "\($0.key):\($0.value)" }.joined(separator: ";")
                csv += "\(analytics.timestamp),\(analytics.event.rawValue),\(analytics.value),\"\(metadataString)\"\n"
            }
            return csv.data(using: .utf8) ?? Data()
            
        case .report:
            let report = try await getPerformanceReport(timeRange: timeRange)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(report)
        }
    }
    
    // MARK: - Local Data Operations
    private func fetchLocalAnalytics() async throws -> [StreamAnalytics] {
        let descriptor = FetchDescriptor<StreamAnalytics>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    private func createLocalAnalytics(_ analytics: StreamAnalytics) async throws {
        modelContext.insert(analytics)
        try modelContext.save()
    }
    
    // MARK: - Public Interface
    public func clearAnalytics(olderThan date: Date) async throws {
        let analytics = try await fetchLocalAnalytics()
        let oldAnalytics = analytics.filter { $0.timestamp < date }
        
        for analytics in oldAnalytics {
            modelContext.delete(analytics)
        }
        
        try modelContext.save()
        
        // Update in-memory data
        analyticsData = analyticsData.filter { $0.timestamp >= date }
        
        print("✅ Analytics cleared: \(oldAnalytics.count) events")
    }
    
    public func getStreamHealth(streamId: String) -> StreamHealthStatus {
        return streamHealthMonitor[streamId]?.lastHealth ?? .unknown
    }
    
    public func resetPerformanceMetrics() {
        performanceMetrics = PerformanceMetrics()
        streamHealthMonitor.removeAll()
        
        print("✅ Performance metrics reset")
    }
    
    // MARK: - Cleanup
    deinit {
        stopTracking()
        performanceTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Analytics Data Models
public struct PerformanceMetrics {
    public var memoryUsage: Double = 0
    public var cpuUsage: Double = 0
    public var networkLatency: Double = 0
    public var averageBufferHealth: Double = 0
    public var totalStreamStarts: Int = 0
    public var totalStreamEnds: Int = 0
    public var totalWatchTime: TimeInterval = 0
    public var totalBufferingEvents: Int = 0
    public var totalConnectionErrors: Int = 0
    public var totalQualityChanges: Int = 0
    
    public mutating func updateSystemMetrics() {
        // Update system metrics (simplified)
        memoryUsage = ProcessInfo.processInfo.physicalMemory > 0 ? 
            Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024) : 0
        cpuUsage = 0 // Would need platform-specific implementation
        networkLatency = 0 // Would need network monitoring
        averageBufferHealth = totalBufferingEvents > 0 ? 
            Double(totalBufferingEvents) / Double(max(1, totalStreamStarts)) : 1.0
    }
}

public struct UsageStats {
    public var dailyEvents: Int = 0
    public var weeklyEvents: Int = 0
    public var monthlyEvents: Int = 0
    public var dailyWatchTime: TimeInterval = 0
    public var weeklyWatchTime: TimeInterval = 0
    public var monthlyWatchTime: TimeInterval = 0
    public var topCategories: [String] = []
    public var lastUpdated: Date = Date()
}

public struct StreamHealthData {
    public var bufferEvents: Int = 0
    public var connectionErrors: Int = 0
    public var bufferRatio: Double = 0
    public var errorRate: Double = 0
    public var startTime: Date?
    public var endTime: Date?
    public var totalWatchTime: TimeInterval = 0
    public var lastUpdate: Date = Date()
    public var lastHealth: StreamHealthStatus = .unknown
}

public enum TimeRange {
    case today
    case week
    case month
    case custom(start: Date, end: Date)
    
    public var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .custom(let start, _):
            return start
        }
    }
    
    public var endDate: Date {
        switch self {
        case .today, .week, .month:
            return Date()
        case .custom(_, let end):
            return end
        }
    }
}

public enum ExportFormat {
    case json
    case csv
    case report
}

public struct PerformanceReport: Codable {
    public let timeRange: TimeRange
    public let totalEvents: Int
    public let bufferingEvents: Int
    public let connectionErrors: Int
    public let qualityChanges: Int
    public let averageBufferTime: Double
    public let errorRate: Double
    public let healthScore: Double
    
    enum CodingKeys: String, CodingKey {
        case totalEvents, bufferingEvents, connectionErrors, qualityChanges
        case averageBufferTime, errorRate, healthScore
    }
    
    public init(
        timeRange: TimeRange,
        totalEvents: Int,
        bufferingEvents: Int,
        connectionErrors: Int,
        qualityChanges: Int,
        averageBufferTime: Double,
        errorRate: Double,
        healthScore: Double
    ) {
        self.timeRange = timeRange
        self.totalEvents = totalEvents
        self.bufferingEvents = bufferingEvents
        self.connectionErrors = connectionErrors
        self.qualityChanges = qualityChanges
        self.averageBufferTime = averageBufferTime
        self.errorRate = errorRate
        self.healthScore = healthScore
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeRange = .month // Default for decoding
        totalEvents = try container.decode(Int.self, forKey: .totalEvents)
        bufferingEvents = try container.decode(Int.self, forKey: .bufferingEvents)
        connectionErrors = try container.decode(Int.self, forKey: .connectionErrors)
        qualityChanges = try container.decode(Int.self, forKey: .qualityChanges)
        averageBufferTime = try container.decode(Double.self, forKey: .averageBufferTime)
        errorRate = try container.decode(Double.self, forKey: .errorRate)
        healthScore = try container.decode(Double.self, forKey: .healthScore)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalEvents, forKey: .totalEvents)
        try container.encode(bufferingEvents, forKey: .bufferingEvents)
        try container.encode(connectionErrors, forKey: .connectionErrors)
        try container.encode(qualityChanges, forKey: .qualityChanges)
        try container.encode(averageBufferTime, forKey: .averageBufferTime)
        try container.encode(errorRate, forKey: .errorRate)
        try container.encode(healthScore, forKey: .healthScore)
    }
}