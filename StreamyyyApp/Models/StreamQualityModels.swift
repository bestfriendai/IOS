//
//  StreamQualityModels.swift
//  StreamyyyApp
//
//  Data models for stream quality monitoring and analysis
//

import Foundation

// MARK: - Stream Quality Data
struct StreamQualityData: Identifiable, Codable {
    let streamId: String
    let title: String
    let platform: String
    let url: String
    let startTime: Date
    var quality: String
    var state: StreamState = .loading
    var latency: Double = 0.0
    var bufferEvents: Int = 0
    var loadTime: Double = 0.0
    var bitrate: Double = 0.0
    var frameRate: Double = 0.0
    var droppedFrames: Int = 0
    var lastUpdate: Date = Date()
    var isHealthy: Bool { 
        latency < 200 && bufferEvents < 5 && state == .playing 
    }
    
    var id: String { streamId }
    
    mutating func updateMetrics(_ metrics: RealTimeStreamMetrics) {
        self.latency = metrics.latency
        self.bufferEvents = metrics.bufferEvents
        self.bitrate = metrics.bitrate
        self.frameRate = metrics.frameRate
        self.droppedFrames = metrics.droppedFrames
        self.lastUpdate = Date()
    }
}

enum StreamState: String, CaseIterable, Codable {
    case loading = "loading"
    case playing = "playing"
    case buffering = "buffering"
    case paused = "paused"
    case error = "error"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .loading: return "Loading"
        case .playing: return "Playing"
        case .buffering: return "Buffering"
        case .paused: return "Paused"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Real-time Stream Metrics
struct RealTimeStreamMetrics: Codable {
    let latency: Double
    let bufferEvents: Int
    let bitrate: Double
    let frameRate: Double
    let droppedFrames: Int
    let timestamp: Date = Date()
    var bufferSize: Double?
    var networkBandwidth: Double?
    var cpuUsage: Double?
    var memoryUsage: Double?
}

// MARK: - Stream Metrics
struct StreamMetrics: Codable {
    let bufferEvents: Int
    let latency: Double
    let loadTime: Double
    let viewerCount: Int
    let bitrate: Double
    let frameRate: Double
    let droppedFrames: Int
}

// MARK: - Buffer Health Point
struct BufferHealthPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let streamId: String
    let bufferHealth: Double
    let bufferSize: Double
    let bufferEvents: Int
    var underrunEvents: Int = 0
    var rebufferingTime: TimeInterval = 0
}

// MARK: - Network Quality Point
struct NetworkQualityPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let bandwidth: Double
    let latency: Double
    let packetLoss: Double
    let jitter: Double
    let connectionType: String
    let signalStrength: Double?
    var throughput: Double?
    var downloadSpeed: Double?
    var uploadSpeed: Double?
}

// MARK: - Network Metrics
struct NetworkMetrics: Codable {
    let bandwidth: Double
    let latency: Double
    let packetLoss: Double
    let jitter: Double
    let connectionType: String
    let signalStrength: Double
}

// MARK: - Network Stability
enum NetworkStability: String, CaseIterable, Codable {
    case stable = "stable"
    case unstable = "unstable"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .unstable: return "Unstable"
        case .poor: return "Poor"
        }
    }
    
    var color: String {
        switch self {
        case .stable: return "green"
        case .unstable: return "yellow"
        case .poor: return "red"
        }
    }
}

// MARK: - Stream Alert
struct StreamAlert: Identifiable, Codable {
    let id: UUID
    let type: StreamAlertType
    let streamId: String
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    var isAcknowledged: Bool = false
    var acknowledgedAt: Date?
    var resolvedAt: Date?
    var isActive: Bool = true
    
    var ageInMinutes: Int {
        return Calendar.current.dateComponents([.minute], from: timestamp, to: Date()).minute ?? 0
    }
}

enum StreamAlertType: String, CaseIterable, Codable {
    case highLatency = "high_latency"
    case bufferingIssues = "buffering_issues"
    case slowLoading = "slow_loading"
    case qualityDegradation = "quality_degradation"
    case connectionLoss = "connection_loss"
    case lowBitrate = "low_bitrate"
    case frameDrops = "frame_drops"
    case audioIssues = "audio_issues"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .highLatency: return "High Latency"
        case .bufferingIssues: return "Buffering Issues"
        case .slowLoading: return "Slow Loading"
        case .qualityDegradation: return "Quality Degradation"
        case .connectionLoss: return "Connection Loss"
        case .lowBitrate: return "Low Bitrate"
        case .frameDrops: return "Frame Drops"
        case .audioIssues: return "Audio Issues"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .highLatency: return "clock"
        case .bufferingIssues: return "play.slash"
        case .slowLoading: return "tortoise"
        case .qualityDegradation: return "eye.slash"
        case .connectionLoss: return "wifi.slash"
        case .lowBitrate: return "speedometer"
        case .frameDrops: return "video.slash"
        case .audioIssues: return "speaker.slash"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Quality Insight
struct QualityInsight: Identifiable, Codable {
    let id = UUID()
    let type: QualityInsightType
    let title: String
    let description: String
    let recommendation: String
    let impact: InsightImpact
    let timestamp: Date
    var isActionable: Bool = true
    var actionTaken: Bool = false
    var actionDate: Date?
    
    var priority: Int {
        switch impact {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

enum QualityInsightType: String, CaseIterable, Codable {
    case performanceDegradation = "performance_degradation"
    case platformIssue = "platform_issue"
    case bufferHealth = "buffer_health"
    case networkOptimization = "network_optimization"
    case qualityRecommendation = "quality_recommendation"
    case userExperience = "user_experience"
    case systemResource = "system_resource"
    
    var displayName: String {
        switch self {
        case .performanceDegradation: return "Performance Degradation"
        case .platformIssue: return "Platform Issue"
        case .bufferHealth: return "Buffer Health"
        case .networkOptimization: return "Network Optimization"
        case .qualityRecommendation: return "Quality Recommendation"
        case .userExperience: return "User Experience"
        case .systemResource: return "System Resource"
        }
    }
}

enum InsightImpact: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Quality Thresholds
struct QualityThresholds {
    let maxLatency: Double = 200.0 // milliseconds
    let criticalLatency: Double = 500.0
    let maxBufferEvents: Int = 3 // per 30 seconds
    let maxLoadTime: Double = 3.0 // seconds
    let minBitrate: Double = 500.0 // kbps
    let minFrameRate: Double = 24.0 // fps
    let maxFrameDropRate: Double = 0.05 // 5%
    let minBufferHealth: Double = 0.8 // 80%
    let maxPacketLoss: Double = 1.0 // 1%
    let maxJitter: Double = 30.0 // milliseconds
}

// MARK: - Stream Quality Report
struct StreamQualityReport: Identifiable, Codable {
    let id = UUID()
    let streamId: String
    let platform: String
    let sessionDuration: TimeInterval
    let averageLatency: Double
    let totalBufferEvents: Int
    let averageLoadTime: Double
    let qualityScore: Double
    let recommendations: [String]
    let generatedAt: Date = Date()
    var issues: [QualityIssue] = []
    var performanceGrade: PerformanceGrade {
        if qualityScore >= 90 { return .excellent }
        else if qualityScore >= 80 { return .good }
        else if qualityScore >= 70 { return .fair }
        else if qualityScore >= 60 { return .poor }
        else { return .critical }
    }
}

enum PerformanceGrade: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .critical: return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Quality Issue
struct QualityIssue: Identifiable, Codable {
    let id = UUID()
    let type: QualityIssueType
    let severity: IssueSeverity
    let description: String
    let occurrenceCount: Int
    let firstOccurrence: Date
    let lastOccurrence: Date
    let affectedStreams: [String]
    let possibleCause: String?
    let recommendedAction: String
    var isResolved: Bool = false
    var resolvedAt: Date?
}

enum QualityIssueType: String, CaseIterable, Codable {
    case latency = "latency"
    case buffering = "buffering"
    case bitrate = "bitrate"
    case frameRate = "frame_rate"
    case connection = "connection"
    case audio = "audio"
    case video = "video"
    case sync = "sync"
    
    var displayName: String {
        switch self {
        case .latency: return "Latency"
        case .buffering: return "Buffering"
        case .bitrate: return "Bitrate"
        case .frameRate: return "Frame Rate"
        case .connection: return "Connection"
        case .audio: return "Audio"
        case .video: return "Video"
        case .sync: return "Sync"
        }
    }
}

enum IssueSeverity: String, CaseIterable, Codable {
    case minor = "minor"
    case moderate = "moderate"
    case major = "major"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .minor: return "Minor"
        case .moderate: return "Moderate"
        case .major: return "Major"
        case .critical: return "Critical"
        }
    }
    
    var priority: Int {
        switch self {
        case .minor: return 1
        case .moderate: return 2
        case .major: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Stream Info
struct StreamInfo: Identifiable, Codable {
    let id: String
    let title: String
    let platform: String
    let url: String
    let quality: String?
    let thumbnailURL: String?
    let isLive: Bool
    let viewerCount: Int?
    let category: String?
    let language: String?
    let createdAt: Date = Date()
}

// MARK: - Quality Benchmark
struct QualityBenchmark: Identifiable, Codable {
    let id = UUID()
    let platform: String
    let benchmarkType: BenchmarkType
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let timestamp: Date
    let sampleSize: Int
    
    var performanceRatio: Double {
        guard targetValue > 0 else { return 0 }
        return currentValue / targetValue
    }
    
    var meetsBenchmark: Bool {
        switch benchmarkType {
        case .latency, .loadTime, .bufferEvents:
            return currentValue <= targetValue
        case .bitrate, .frameRate, .qualityScore:
            return currentValue >= targetValue
        }
    }
}

enum BenchmarkType: String, CaseIterable, Codable {
    case latency = "latency"
    case loadTime = "load_time"
    case bufferEvents = "buffer_events"
    case bitrate = "bitrate"
    case frameRate = "frame_rate"
    case qualityScore = "quality_score"
    
    var displayName: String {
        switch self {
        case .latency: return "Latency"
        case .loadTime: return "Load Time"
        case .bufferEvents: return "Buffer Events"
        case .bitrate: return "Bitrate"
        case .frameRate: return "Frame Rate"
        case .qualityScore: return "Quality Score"
        }
    }
    
    var unit: String {
        switch self {
        case .latency: return "ms"
        case .loadTime: return "s"
        case .bufferEvents: return "events"
        case .bitrate: return "kbps"
        case .frameRate: return "fps"
        case .qualityScore: return "%"
        }
    }
}

// MARK: - Stream Quality Analytics
struct StreamQualityAnalytics: Codable {
    let platform: String
    let totalStreams: Int
    let averageQualityScore: Double
    let averageLatency: Double
    let averageLoadTime: Double
    let bufferingRate: Double // Percentage of time spent buffering
    let popularQualities: [String: Int] // Quality setting -> usage count
    let issueFrequency: [QualityIssueType: Int]
    let userSatisfactionScore: Double
    let timestamp: Date
    
    var reliabilityScore: Double {
        let latencyScore = max(0, 100 - (averageLatency - 50) / 5) // 50ms baseline, -1 point per 5ms
        let bufferingScore = max(0, 100 - bufferingRate * 200) // -2 points per 1% buffering
        let qualityScoreContribution = averageQualityScore
        
        return (latencyScore + bufferingScore + qualityScoreContribution) / 3
    }
}

// MARK: - Stream Optimization Suggestion
struct StreamOptimizationSuggestion: Identifiable, Codable {
    let id = UUID()
    let streamId: String
    let suggestionType: OptimizationType
    let title: String
    let description: String
    let expectedImprovement: Double
    let implementationEffort: ImplementationEffort
    let priority: SuggestionPriority
    let timestamp: Date
    var isImplemented: Bool = false
    var implementedAt: Date?
    var actualImprovement: Double?
}

enum OptimizationType: String, CaseIterable, Codable {
    case qualityReduction = "quality_reduction"
    case bufferOptimization = "buffer_optimization"
    case networkOptimization = "network_optimization"
    case codecOptimization = "codec_optimization"
    case caching = "caching"
    case loadBalancing = "load_balancing"
    
    var displayName: String {
        switch self {
        case .qualityReduction: return "Quality Reduction"
        case .bufferOptimization: return "Buffer Optimization"
        case .networkOptimization: return "Network Optimization"
        case .codecOptimization: return "Codec Optimization"
        case .caching: return "Caching"
        case .loadBalancing: return "Load Balancing"
        }
    }
}

enum ImplementationEffort: String, CaseIterable, Codable {
    case minimal = "minimal"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum SuggestionPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var order: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }
}

// MARK: - Stream Quality Export Data
struct StreamQualityExportData: Codable {
    let qualityMetrics: [StreamQualityMetric]
    let bufferHealthData: [BufferHealthPoint]
    let networkQualityData: [NetworkQualityPoint]
    let streamAlerts: [StreamAlert]
    let qualityInsights: [QualityInsight]
    let exportDate: Date
    let appVersion: String = Config.App.version
    let deviceModel: String = UIDevice.current.model
    let osVersion: String = UIDevice.current.systemVersion
    var summary: StreamQualityExportSummary {
        return StreamQualityExportSummary(
            totalMetrics: qualityMetrics.count,
            averageQualityScore: qualityMetrics.map { $0.qualityScore }.reduce(0, +) / Double(max(qualityMetrics.count, 1)),
            totalAlerts: streamAlerts.count,
            criticalAlerts: streamAlerts.filter { $0.severity == .critical }.count,
            totalInsights: qualityInsights.count,
            exportDuration: Date().timeIntervalSince(qualityMetrics.first?.timestamp ?? Date())
        )
    }
}

struct StreamQualityExportSummary: Codable {
    let totalMetrics: Int
    let averageQualityScore: Double
    let totalAlerts: Int
    let criticalAlerts: Int
    let totalInsights: Int
    let exportDuration: TimeInterval
}