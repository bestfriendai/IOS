//
//  PerformanceModels.swift
//  StreamyyyApp
//
//  Data models for performance profiling and optimization
//

import Foundation

// MARK: - Performance Profile
struct PerformanceProfile: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    let sessionId: String
    let appVersion: String
    let deviceModel: String
    let osVersion: String
    
    var averageCPUUsage: Double = 0
    var peakCPUUsage: Double = 0
    var averageMemoryUsage: Double = 0
    var peakMemoryUsage: Double = 0
    var averageNetworkLatency: Double = 0
    var totalNetworkUsage: Double = 0
    var averageFrameRate: Double = 0
    var droppedFrames: Int = 0
    var averageBatteryDrain: Double = 0
    var thermalEvents: Int = 0
    
    var performanceScore: Double {
        var score = 100.0
        
        // CPU impact
        score -= averageCPUUsage * 30
        
        // Memory impact
        score -= averageMemoryUsage * 25
        
        // Frame rate impact
        if averageFrameRate < 60 {
            score -= (60 - averageFrameRate) * 0.5
        }
        
        // Network impact
        if averageNetworkLatency > 100 {
            score -= (averageNetworkLatency - 100) * 0.1
        }
        
        // Battery impact
        if averageBatteryDrain > 10 {
            score -= (averageBatteryDrain - 10) * 2
        }
        
        // Thermal impact
        score -= Double(thermalEvents) * 10
        
        return max(0, min(100, score))
    }
}

// MARK: - CPU Profile Data
struct CPUProfileData: Codable {
    var usage: [CPUUsagePoint] = []
    var currentUsage: Double = 0
    var averageUsage: Double = 0
    var peakUsage: Double = 0
    var coreCount: Int = ProcessInfo.processInfo.activeProcessorCount
    var thermalState: ThermalState = .normal
}

struct CPUUsagePoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let usage: Double
    let coreUsage: [Double]?
    
    init(timestamp: Date, usage: Double, coreUsage: [Double]? = nil) {
        self.timestamp = timestamp
        self.usage = usage
        self.coreUsage = coreUsage
    }
}

// MARK: - Memory Profile Data
struct MemoryProfileData: Codable {
    var usage: [MemoryUsagePoint] = []
    var currentUsage: Double = 0
    var averageUsage: Double = 0
    var peakUsage: Double = 0
    var availableMemory: Double = 0
    var memoryPressure: Double = 0
    var swapUsage: Double = 0
    var leakDetected: Bool = false
}

struct MemoryUsagePoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let used: Double
    let available: Double
    let pressure: Double
    let swap: Double?
    
    init(timestamp: Date, used: Double, available: Double, pressure: Double, swap: Double? = nil) {
        self.timestamp = timestamp
        self.used = used
        self.available = available
        self.pressure = pressure
        self.swap = swap
    }
}

// MARK: - Network Profile Data
struct NetworkProfileData: Codable {
    var usage: [NetworkUsagePoint] = []
    var totalBytesReceived: Double = 0
    var totalBytesSent: Double = 0
    var currentBandwidth: Double = 0
    var currentLatency: Double = 0
    var connectionType: String = "Unknown"
    var packetsLost: Int = 0
    var retransmissions: Int = 0
}

struct NetworkUsagePoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let bytesReceived: Double
    let bytesSent: Double
    let connectionType: String
    let latency: Double
    let signalStrength: Double?
    
    init(timestamp: Date, bytesReceived: Double, bytesSent: Double, connectionType: String, latency: Double, signalStrength: Double? = nil) {
        self.timestamp = timestamp
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.connectionType = connectionType
        self.latency = latency
        self.signalStrength = signalStrength
    }
}

// MARK: - Rendering Profile Data
struct RenderingProfileData: Codable {
    var metrics: [RenderingMetricsPoint] = []
    var currentFrameRate: Double = 0
    var averageFrameTime: Double = 0
    var droppedFrameCount: Int = 0
    var gpuUsage: Double = 0
    var renderingMode: String = "Hardware"
    var vsyncEnabled: Bool = true
}

struct RenderingMetricsPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let frameRate: Double
    let frameTime: Double
    let droppedFrames: Int
    let gpuUsage: Double
    let renderingComplexity: Double?
    
    init(timestamp: Date, frameRate: Double, frameTime: Double, droppedFrames: Int, gpuUsage: Double, renderingComplexity: Double? = nil) {
        self.timestamp = timestamp
        self.frameRate = frameRate
        self.frameTime = frameTime
        self.droppedFrames = droppedFrames
        self.gpuUsage = gpuUsage
        self.renderingComplexity = renderingComplexity
    }
}

// MARK: - Battery Profile Data
struct BatteryProfileData: Codable {
    var usage: [BatteryUsagePoint] = []
    var currentLevel: Double = 0
    var batteryState: String = "Unknown"
    var thermalState: ThermalState = .normal
    var isLowPowerMode: Bool = false
    var drainRate: Double = 0
    var chargingRate: Double = 0
}

struct BatteryUsagePoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let level: Double
    let state: String
    let thermalState: ThermalState
    let lowPowerMode: Bool
    let voltage: Double?
    
    init(timestamp: Date, level: Double, state: String, thermalState: ThermalState, lowPowerMode: Bool, voltage: Double? = nil) {
        self.timestamp = timestamp
        self.level = level
        self.state = state
        self.thermalState = thermalState
        self.lowPowerMode = lowPowerMode
        self.voltage = voltage
    }
}

// MARK: - Performance Bottleneck
struct PerformanceBottleneck: Identifiable, Codable {
    let id = UUID()
    let type: BottleneckType
    let severity: BottleneckSeverity
    let description: String
    let metric: Double
    let timestamp: Date
    let context: String?
    
    init(type: BottleneckType, severity: BottleneckSeverity, description: String, metric: Double, timestamp: Date, context: String? = nil) {
        self.type = type
        self.severity = severity
        self.description = description
        self.metric = metric
        self.timestamp = timestamp
        self.context = context
    }
}

enum BottleneckType: String, CaseIterable, Codable {
    case cpu = "cpu"
    case memory = "memory"
    case network = "network"
    case rendering = "rendering"
    case battery = "battery"
    case io = "io"
    case database = "database"
    
    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .rendering: return "Rendering"
        case .battery: return "Battery"
        case .io: return "I/O"
        case .database: return "Database"
        }
    }
}

enum BottleneckSeverity: String, CaseIterable, Codable {
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
}

// MARK: - Optimization Insight
struct OptimizationInsight: Identifiable, Codable {
    let id = UUID()
    let category: OptimizationCategory
    let title: String
    let description: String
    let impact: OptimizationImpact
    let effort: OptimizationEffort
    let recommendation: String
    let expectedImprovement: Double
    let timestamp: Date
    let priority: Int
    
    init(category: OptimizationCategory, title: String, description: String, impact: OptimizationImpact, effort: OptimizationEffort, recommendation: String, expectedImprovement: Double, timestamp: Date, priority: Int = 0) {
        self.category = category
        self.title = title
        self.description = description
        self.impact = impact
        self.effort = effort
        self.recommendation = recommendation
        self.expectedImprovement = expectedImprovement
        self.timestamp = timestamp
        self.priority = priority
    }
}

enum OptimizationCategory: String, CaseIterable, Codable {
    case cpu = "cpu"
    case memory = "memory"
    case network = "network"
    case rendering = "rendering"
    case battery = "battery"
    case userExperience = "user_experience"
    case architecture = "architecture"
    
    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .rendering: return "Rendering"
        case .battery: return "Battery"
        case .userExperience: return "User Experience"
        case .architecture: return "Architecture"
        }
    }
}

enum OptimizationImpact: String, CaseIterable, Codable {
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
}

enum OptimizationEffort: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}

// MARK: - Performance Optimization
struct PerformanceOptimization: Identifiable, Codable {
    let id = UUID()
    let type: OptimizationType
    let priority: OptimizationPriority
    let title: String
    let description: String
    let implementation: String
    let estimatedEffort: OptimizationEffort
    let expectedImpact: OptimizationImpact
    let timestamp: Date
    var isCompleted: Bool = false
    var completedAt: Date?
    
    init(type: OptimizationType, priority: OptimizationPriority, title: String, description: String, implementation: String, estimatedEffort: OptimizationEffort, expectedImpact: OptimizationImpact, timestamp: Date) {
        self.type = type
        self.priority = priority
        self.title = title
        self.description = description
        self.implementation = implementation
        self.estimatedEffort = estimatedEffort
        self.expectedImpact = expectedImpact
        self.timestamp = timestamp
    }
}

enum OptimizationType: String, CaseIterable, Codable {
    case cpu = "cpu"
    case memory = "memory"
    case network = "network"
    case rendering = "rendering"
    case battery = "battery"
    case caching = "caching"
    case algorithm = "algorithm"
    case dataStructure = "data_structure"
    
    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .rendering: return "Rendering"
        case .battery: return "Battery"
        case .caching: return "Caching"
        case .algorithm: return "Algorithm"
        case .dataStructure: return "Data Structure"
        }
    }
}

enum OptimizationPriority: String, CaseIterable, Codable {
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
}

// MARK: - Method Profile Data
struct MethodProfileData: Identifiable, Codable {
    let id = UUID()
    let methodName: String
    var totalCalls: Int
    var totalDuration: TimeInterval
    var averageDuration: TimeInterval
    var minDuration: TimeInterval
    var maxDuration: TimeInterval
    var lastCallTime: Date
    var callHistory: [MethodCallRecord] = []
    
    init(methodName: String, totalCalls: Int, totalDuration: TimeInterval, averageDuration: TimeInterval, minDuration: TimeInterval, maxDuration: TimeInterval, lastCallTime: Date) {
        self.methodName = methodName
        self.totalCalls = totalCalls
        self.totalDuration = totalDuration
        self.averageDuration = averageDuration
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.lastCallTime = lastCallTime
    }
}

struct MethodCallRecord: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let duration: TimeInterval
    let parameters: [String: String]?
    let result: String?
    let error: String?
    
    init(timestamp: Date, duration: TimeInterval, parameters: [String: String]? = nil, result: String? = nil, error: String? = nil) {
        self.timestamp = timestamp
        self.duration = duration
        self.parameters = parameters
        self.result = result
        self.error = error
    }
}

// MARK: - Performance Report
struct PerformanceReport: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let cpuData: CPUProfileData
    let memoryData: MemoryProfileData
    let networkData: NetworkProfileData
    let renderingData: RenderingProfileData
    let batteryData: BatteryProfileData
    let bottlenecks: [PerformanceBottleneck]
    let optimizationInsights: [OptimizationInsight]
    let recommendations: [PerformanceOptimization]
    
    var overallPerformanceScore: Double {
        var score = 100.0
        
        // CPU score
        score -= cpuData.currentUsage * 30
        
        // Memory score
        score -= memoryData.memoryPressure * 25
        
        // Network score
        if networkData.currentLatency > 100 {
            score -= (networkData.currentLatency - 100) * 0.1
        }
        
        // Rendering score
        if renderingData.currentFrameRate < 60 {
            score -= (60 - renderingData.currentFrameRate) * 0.5
        }
        
        // Battery score
        if batteryData.drainRate > 10 {
            score -= (batteryData.drainRate - 10) * 2
        }
        
        // Bottleneck penalties
        for bottleneck in bottlenecks {
            switch bottleneck.severity {
            case .low: score -= 5
            case .medium: score -= 10
            case .high: score -= 20
            case .critical: score -= 30
            }
        }
        
        return max(0, min(100, score))
    }
    
    var summary: String {
        return "Performance score: \(Int(overallPerformanceScore))/100 with \(bottlenecks.count) bottlenecks detected"
    }
}

// MARK: - Profile Export Data
struct ProfileExportData: Codable {
    let profiles: [PerformanceProfile]
    let methodData: [MethodProfileData]
    let insights: [OptimizationInsight]
    let recommendations: [PerformanceOptimization]
    let exportDate: Date = Date()
    let appVersion: String = Config.App.version
    let deviceModel: String = UIDevice.current.model
    let osVersion: String = UIDevice.current.systemVersion
}

// MARK: - Performance Benchmark
struct PerformanceBenchmark: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let category: BenchmarkCategory
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let timestamp: Date
    
    var isPassingBenchmark: Bool {
        return currentValue <= targetValue
    }
    
    var performanceRatio: Double {
        return currentValue / targetValue
    }
}

enum BenchmarkCategory: String, CaseIterable, Codable {
    case appLaunch = "app_launch"
    case streamLoad = "stream_load"
    case memoryUsage = "memory_usage"
    case cpuUsage = "cpu_usage"
    case networkLatency = "network_latency"
    case batteryDrain = "battery_drain"
    case renderingFPS = "rendering_fps"
    
    var displayName: String {
        switch self {
        case .appLaunch: return "App Launch"
        case .streamLoad: return "Stream Load"
        case .memoryUsage: return "Memory Usage"
        case .cpuUsage: return "CPU Usage"
        case .networkLatency: return "Network Latency"
        case .batteryDrain: return "Battery Drain"
        case .renderingFPS: return "Rendering FPS"
        }
    }
}

// MARK: - Performance Regression
struct PerformanceRegression: Identifiable, Codable {
    let id = UUID()
    let metric: String
    let previousValue: Double
    let currentValue: Double
    let regressionPercentage: Double
    let detectedAt: Date
    let severity: RegressionSeverity
    let possibleCause: String?
    
    init(metric: String, previousValue: Double, currentValue: Double, detectedAt: Date, possibleCause: String? = nil) {
        self.metric = metric
        self.previousValue = previousValue
        self.currentValue = currentValue
        self.regressionPercentage = ((currentValue - previousValue) / previousValue) * 100
        self.detectedAt = detectedAt
        self.possibleCause = possibleCause
        
        // Determine severity based on regression percentage
        if regressionPercentage > 50 {
            self.severity = .critical
        } else if regressionPercentage > 25 {
            self.severity = .high
        } else if regressionPercentage > 10 {
            self.severity = .medium
        } else {
            self.severity = .low
        }
    }
}

enum RegressionSeverity: String, CaseIterable, Codable {
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
}