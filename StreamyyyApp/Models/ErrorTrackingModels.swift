//
//  ErrorTrackingModels.swift
//  StreamyyyApp
//
//  Data models for error tracking and crash reporting
//

import Foundation

// MARK: - Enhanced Error Report
struct ErrorReport: Identifiable, Codable {
    let id: UUID
    let error: String
    let stackTrace: String?
    let context: [String: String]
    let userId: String?
    let sessionId: String
    let deviceInfo: DeviceInfo
    let timestamp: Date
    let isCrash: Bool
    var isRecovered: Bool
    let errorCode: Int
    let errorDomain: String
    let severity: ErrorSeverity
    let category: ErrorCategory
    let breadcrumbs: [String]
    let environment: ErrorEnvironment
    var recoveryMethod: String?
    var tags: [String] = []
    var customData: [String: String] = [:]
    
    init(id: UUID, error: String, stackTrace: String?, context: [String: String], userId: String?, sessionId: String, deviceInfo: DeviceInfo, timestamp: Date, isCrash: Bool, isRecovered: Bool, errorCode: Int = 0, errorDomain: String = "", severity: ErrorSeverity = .medium, category: ErrorCategory = .unknown, breadcrumbs: [String] = [], environment: ErrorEnvironment = ErrorEnvironment()) {
        self.id = id
        self.error = error
        self.stackTrace = stackTrace
        self.context = context
        self.userId = userId
        self.sessionId = sessionId
        self.deviceInfo = deviceInfo
        self.timestamp = timestamp
        self.isCrash = isCrash
        self.isRecovered = isRecovered
        self.errorCode = errorCode
        self.errorDomain = errorDomain
        self.severity = severity
        self.category = category
        self.breadcrumbs = breadcrumbs
        self.environment = environment
    }
}

// MARK: - Crash Report
struct CrashReport: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: CrashType
    let exception: NSException?
    let signal: Int32?
    let stackTrace: String
    let deviceInfo: DeviceInfo
    let appState: AppState
    let memoryInfo: MemoryInfo
    let threadInfo: ThreadInfo
    var isSymbolicated: Bool = false
    var analysisResults: CrashAnalysis?
    
    // Custom Codable implementation for NSException
    enum CodingKeys: String, CodingKey {
        case id, timestamp, type, signal, stackTrace, deviceInfo, appState, memoryInfo, threadInfo, isSymbolicated, analysisResults
        case exceptionName, exceptionReason, exceptionUserInfo
    }
    
    init(id: UUID, timestamp: Date, type: CrashType, exception: NSException?, signal: Int32?, stackTrace: String, deviceInfo: DeviceInfo, appState: AppState, memoryInfo: MemoryInfo, threadInfo: ThreadInfo) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.exception = exception
        self.signal = signal
        self.stackTrace = stackTrace
        self.deviceInfo = deviceInfo
        self.appState = appState
        self.memoryInfo = memoryInfo
        self.threadInfo = threadInfo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        type = try container.decode(CrashType.self, forKey: .type)
        signal = try container.decodeIfPresent(Int32.self, forKey: .signal)
        stackTrace = try container.decode(String.self, forKey: .stackTrace)
        deviceInfo = try container.decode(DeviceInfo.self, forKey: .deviceInfo)
        appState = try container.decode(AppState.self, forKey: .appState)
        memoryInfo = try container.decode(MemoryInfo.self, forKey: .memoryInfo)
        threadInfo = try container.decode(ThreadInfo.self, forKey: .threadInfo)
        isSymbolicated = try container.decodeIfPresent(Bool.self, forKey: .isSymbolicated) ?? false
        analysisResults = try container.decodeIfPresent(CrashAnalysis.self, forKey: .analysisResults)
        
        // Decode exception if present
        if let exceptionName = try container.decodeIfPresent(String.self, forKey: .exceptionName),
           let exceptionReason = try container.decodeIfPresent(String.self, forKey: .exceptionReason) {
            let userInfo = try container.decodeIfPresent([String: String].self, forKey: .exceptionUserInfo) ?? [:]
            exception = NSException(name: NSExceptionName(exceptionName), reason: exceptionReason, userInfo: userInfo)
        } else {
            exception = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(signal, forKey: .signal)
        try container.encode(stackTrace, forKey: .stackTrace)
        try container.encode(deviceInfo, forKey: .deviceInfo)
        try container.encode(appState, forKey: .appState)
        try container.encode(memoryInfo, forKey: .memoryInfo)
        try container.encode(threadInfo, forKey: .threadInfo)
        try container.encode(isSymbolicated, forKey: .isSymbolicated)
        try container.encodeIfPresent(analysisResults, forKey: .analysisResults)
        
        // Encode exception if present
        if let exception = exception {
            try container.encode(exception.name.rawValue, forKey: .exceptionName)
            try container.encode(exception.reason, forKey: .exceptionReason)
            if let userInfo = exception.userInfo as? [String: String] {
                try container.encode(userInfo, forKey: .exceptionUserInfo)
            }
        }
    }
}

// MARK: - Error Enums
enum ErrorSeverity: String, CaseIterable, Codable {
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
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

enum ErrorCategory: String, CaseIterable, Codable {
    case network = "network"
    case system = "system"
    case application = "application"
    case user = "user"
    case security = "security"
    case performance = "performance"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .network: return "Network"
        case .system: return "System"
        case .application: return "Application"
        case .user: return "User"
        case .security: return "Security"
        case .performance: return "Performance"
        case .unknown: return "Unknown"
        }
    }
}

enum CrashType: String, CaseIterable, Codable {
    case exception = "exception"
    case signal = "signal"
    case assertion = "assertion"
    case abort = "abort"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .exception: return "Exception"
        case .signal: return "Signal"
        case .assertion: return "Assertion"
        case .abort: return "Abort"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Supporting Data Structures
struct AppState: Codable {
    let applicationState: String
    let backgroundTimeRemaining: TimeInterval
    let isIdleTimerDisabled: Bool
    let activeScenes: Int
    let memoryWarnings: Int
    var activeViewControllers: [String] = []
    var navigationStack: [String] = []
    var modalStack: [String] = []
}

struct MemoryInfo: Codable {
    let usedMemory: Double
    let totalMemory: Double
    let availableMemory: Double
    let memoryPressure: Double
    let pageFaults: Int
    var memoryMappings: [String] = []
    var largestAllocations: [String] = []
}

struct ThreadInfo: Codable {
    let activeThreads: Int
    let mainThread: Bool
    let threadId: String
    let queueLabel: String
    var threadStates: [String] = []
    var deadlocks: [String] = []
}

struct ErrorEnvironment: Codable {
    let configuration: String
    let network: String
    let locale: String
    let timezone: String
    let accessibility: Bool
    var featureFlags: [String: Bool] = [:]
    var customEnvironment: [String: String] = [:]
    
    init(configuration: String = "development", network: String = "WiFi", locale: String = "en_US", timezone: String = "UTC", accessibility: Bool = false) {
        self.configuration = configuration
        self.network = network
        self.locale = locale
        self.timezone = timezone
        self.accessibility = accessibility
    }
}

// MARK: - Error Summary
struct ErrorSummary: Codable {
    var totalErrors: Int = 0
    var todayErrors: Int = 0
    var weeklyErrors: Int = 0
    var criticalErrors: Int = 0
    var crashCount: Int = 0
    var recoveredErrors: Int = 0
    var lastErrorTime: Date?
    var mostFrequentError: String?
    var errorRate: Double = 0.0
    var topErrorCategories: [String] = []
    var errorTrend: ErrorTrendDirection = .stable
    
    var healthScore: Double {
        let baseScore = 100.0
        let errorPenalty = min(Double(todayErrors) * 2.0, 50.0)
        let crashPenalty = min(Double(crashCount) * 10.0, 30.0)
        let criticalPenalty = min(Double(criticalErrors) * 5.0, 20.0)
        
        return max(0, baseScore - errorPenalty - crashPenalty - criticalPenalty)
    }
}

enum ErrorTrendDirection: String, CaseIterable, Codable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
    
    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        }
    }
}

// MARK: - Frequent Error
struct FrequentError: Identifiable, Codable {
    let id: UUID
    let errorSignature: String
    let occurrenceCount: Int
    let recentCount: Int
    let firstOccurrence: Date
    let lastOccurrence: Date
    let averageFrequency: TimeInterval
    let severity: ErrorSeverity
    let description: String
    let possibleCause: String?
    var isResolved: Bool = false
    var resolution: String?
    var priority: ErrorPriority = .medium
}

enum ErrorPriority: String, CaseIterable, Codable {
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
}

// MARK: - Error Trend
struct ErrorTrend: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let errorCount: Int
    let crashCount: Int
    let criticalCount: Int
    let period: TrendPeriod
    var categories: [String: Int] = [:]
    var severityBreakdown: [String: Int] = [:]
}

enum TrendPeriod: String, CaseIterable, Codable {
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - Crash Analysis
struct CrashAnalysis: Codable {
    let crashSignature: String
    let probableCause: String
    let similarCrashes: Int
    let affectedUsers: Int
    let regressionVersion: String?
    let recommendations: [String]
    let severity: CrashSeverity
    let category: CrashCategory
    let isKnownIssue: Bool
    let bugTrackingId: String?
}

enum CrashSeverity: String, CaseIterable, Codable {
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
}

enum CrashCategory: String, CaseIterable, Codable {
    case memoryCorruption = "memory_corruption"
    case nullPointer = "null_pointer"
    case infiniteLoop = "infinite_loop"
    case stackOverflow = "stack_overflow"
    case deadlock = "deadlock"
    case assertion = "assertion"
    case outOfMemory = "out_of_memory"
    case networkTimeout = "network_timeout"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .memoryCorruption: return "Memory Corruption"
        case .nullPointer: return "Null Pointer"
        case .infiniteLoop: return "Infinite Loop"
        case .stackOverflow: return "Stack Overflow"
        case .deadlock: return "Deadlock"
        case .assertion: return "Assertion"
        case .outOfMemory: return "Out of Memory"
        case .networkTimeout: return "Network Timeout"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Error Export Data
struct ErrorExportData: Codable {
    let errorReports: [ErrorReport]
    let crashReports: [CrashReport]
    let errorSummary: ErrorSummary
    let exportDate: Date
    let appVersion: String = Config.App.version
    let deviceModel: String = UIDevice.current.model
    let osVersion: String = UIDevice.current.systemVersion
}

// MARK: - Crash Handler
protocol CrashHandlerDelegate: AnyObject {
    func crashHandler(_ handler: CrashHandler, didDetectCrash crashInfo: CrashInfo)
}

class CrashHandler {
    weak var delegate: CrashHandlerDelegate?
    
    func detectCrash() {
        // Implementation for crash detection
    }
}

struct CrashInfo {
    let type: CrashType
    let exception: NSException?
    let signal: Int32?
    let stackTrace: String
    let timestamp: Date
    
    init(type: CrashType, exception: NSException? = nil, signal: Int32? = nil, stackTrace: String = "", timestamp: Date = Date()) {
        self.type = type
        self.exception = exception
        self.signal = signal
        self.stackTrace = stackTrace
        self.timestamp = timestamp
    }
}

// MARK: - Error Pattern Detection
struct ErrorPattern: Identifiable, Codable {
    let id = UUID()
    let pattern: String
    let description: String
    let occurrences: Int
    let firstSeen: Date
    let lastSeen: Date
    let affectedUsers: Set<String>
    let severity: ErrorSeverity
    let category: ErrorCategory
    let recommendation: String
    var isAcknowledged: Bool = false
    var isSuppressed: Bool = false
    
    init(pattern: String, description: String, occurrences: Int, firstSeen: Date, lastSeen: Date, affectedUsers: Set<String>, severity: ErrorSeverity, category: ErrorCategory, recommendation: String) {
        self.pattern = pattern
        self.description = description
        self.occurrences = occurrences
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.affectedUsers = affectedUsers
        self.severity = severity
        self.category = category
        self.recommendation = recommendation
    }
}

// MARK: - Error Alert
struct ErrorAlert: Identifiable, Codable {
    let id = UUID()
    let title: String
    let message: String
    let errorPattern: String
    let threshold: Int
    let currentCount: Int
    let severity: AlertSeverity
    let category: ErrorCategory
    let timestamp: Date
    var isActive: Bool = true
    var acknowledgedBy: String?
    var acknowledgedAt: Date?
    var resolvedAt: Date?
    
    init(title: String, message: String, errorPattern: String, threshold: Int, currentCount: Int, severity: AlertSeverity, category: ErrorCategory, timestamp: Date = Date()) {
        self.title = title
        self.message = message
        self.errorPattern = errorPattern
        self.threshold = threshold
        self.currentCount = currentCount
        self.severity = severity
        self.category = category
        self.timestamp = timestamp
    }
}

// MARK: - Error Metrics
struct ErrorMetrics: Codable {
    let timestamp: Date
    let errorRate: Double
    let crashRate: Double
    let meanTimeToResolution: TimeInterval
    let errorsByCategory: [String: Int]
    let errorsBySeverity: [String: Int]
    let topErrors: [String]
    let affectedUsers: Int
    let totalSessions: Int
    let qualityScore: Double
}

// MARK: - Error Configuration
struct ErrorTrackingConfiguration: Codable {
    var isEnabled: Bool = true
    var maxStoredErrors: Int = 1000
    var uploadInterval: TimeInterval = 60.0
    var enableCrashReporting: Bool = true
    var enableAutomaticErrorRecovery: Bool = true
    var errorGroupingWindow: TimeInterval = 300.0
    var minimumSeverityToReport: ErrorSeverity = .low
    var excludedErrorDomains: Set<String> = []
    var includedErrorCategories: Set<ErrorCategory> = Set(ErrorCategory.allCases)
    var enableStackTraceCollection: Bool = true
    var enableBreadcrumbCollection: Bool = true
    var maxBreadcrumbs: Int = 50
    var enableEnvironmentCollection: Bool = true
    var enableUserDataCollection: Bool = false
    var privacyMode: Bool = false
    
    var alertThresholds: [ErrorCategory: Int] = [
        .critical: 1,
        .high: 5,
        .medium: 10,
        .low: 20
    ]
}

// MARK: - Error Recovery Strategy
struct ErrorRecoveryStrategy: Codable {
    let errorPattern: String
    let recoveryMethod: RecoveryMethod
    let description: String
    let automaticRecovery: Bool
    let maxRetries: Int
    let retryDelay: TimeInterval
    let fallbackStrategy: String?
    var successRate: Double = 0.0
    var lastUsed: Date?
}

enum RecoveryMethod: String, CaseIterable, Codable {
    case retry = "retry"
    case fallback = "fallback"
    case restart = "restart"
    case ignore = "ignore"
    case userIntervention = "user_intervention"
    case gracefulDegradation = "graceful_degradation"
    
    var displayName: String {
        switch self {
        case .retry: return "Retry"
        case .fallback: return "Fallback"
        case .restart: return "Restart"
        case .ignore: return "Ignore"
        case .userIntervention: return "User Intervention"
        case .gracefulDegradation: return "Graceful Degradation"
        }
    }
}