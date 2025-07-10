//
//  UserBehaviorModels.swift
//  StreamyyyApp
//
//  Data models for user behavior analysis and tracking
//

import Foundation
import CoreGraphics

// MARK: - User Session
struct UserSession: Identifiable, Codable {
    let id: String
    let userId: String?
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    let deviceInfo: [String: String]
    let appVersion: String
    let platform: String
    var eventCount: Int = 0
    var events: [BehaviorEvent] = []
    var screenTime: [String: TimeInterval] = [:]
    var featureInteractions: [String: Int] = [:]
    var engagementScore: Double = 0.0
    var exitReason: ExitReason?
    var sessionQuality: SessionQuality = .unknown
    
    var isActive: Bool {
        return endTime == nil
    }
    
    var sessionLength: SessionLength {
        if duration < 30 { return .veryShort }
        else if duration < 300 { return .short }
        else if duration < 1800 { return .medium }
        else if duration < 3600 { return .long }
        else { return .veryLong }
    }
}

enum ExitReason: String, CaseIterable, Codable {
    case background = "background"
    case crash = "crash"
    case userExit = "user_exit"
    case timeout = "timeout"
    case memoryPressure = "memory_pressure"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .background: return "Backgrounded"
        case .crash: return "Crashed"
        case .userExit: return "User Exit"
        case .timeout: return "Timeout"
        case .memoryPressure: return "Memory Pressure"
        case .unknown: return "Unknown"
        }
    }
}

enum SessionLength: String, CaseIterable, Codable {
    case veryShort = "very_short"
    case short = "short"
    case medium = "medium"
    case long = "long"
    case veryLong = "very_long"
    
    var displayName: String {
        switch self {
        case .veryShort: return "< 30s"
        case .short: return "30s - 5m"
        case .medium: return "5m - 30m"
        case .long: return "30m - 1h"
        case .veryLong: return "> 1h"
        }
    }
}

enum SessionQuality: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case average = "average"
    case poor = "poor"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .average: return "Average"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Behavior Event
struct BehaviorEvent: Identifiable, Codable {
    let id: UUID
    let type: BehaviorEventType
    let timestamp: Date
    let sessionId: String
    let userId: String?
    let properties: [String: AnyCodable]
    let screenName: String?
    let elementId: String?
    let coordinates: CGPoint?
    var sequenceNumber: Int = 0
    var duration: TimeInterval?
    var context: EventContext?
    
    init(id: UUID, type: BehaviorEventType, timestamp: Date, sessionId: String, userId: String?, properties: [String: Any], screenName: String?, elementId: String?, coordinates: CGPoint?) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.properties = properties.mapValues { AnyCodable($0) }
        self.screenName = screenName
        self.elementId = elementId
        self.coordinates = coordinates
    }
}

enum BehaviorEventType: String, CaseIterable, Codable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case sessionPause = "session_pause"
    case sessionResume = "session_resume"
    case screenView = "screen_view"
    case userAction = "user_action"
    case featureUsage = "feature_usage"
    case conversion = "conversion"
    case error = "error"
    case performance = "performance"
    case notification = "notification"
    case purchase = "purchase"
    case share = "share"
    case search = "search"
    case filter = "filter"
    case sort = "sort"
    case scroll = "scroll"
    case swipe = "swipe"
    case tap = "tap"
    case longPress = "long_press"
    case pinch = "pinch"
    case rotate = "rotate"
    case drag = "drag"
    case custom = "custom"
    
    var category: EventCategory {
        switch self {
        case .sessionStart, .sessionEnd, .sessionPause, .sessionResume:
            return .session
        case .screenView:
            return .navigation
        case .userAction, .tap, .longPress, .swipe, .scroll, .pinch, .rotate, .drag:
            return .interaction
        case .featureUsage:
            return .feature
        case .conversion, .purchase:
            return .conversion
        case .error:
            return .error
        case .performance:
            return .performance
        case .notification:
            return .notification
        case .share:
            return .social
        case .search, .filter, .sort:
            return .discovery
        case .custom:
            return .custom
        }
    }
}

enum EventCategory: String, CaseIterable, Codable {
    case session = "session"
    case navigation = "navigation"
    case interaction = "interaction"
    case feature = "feature"
    case conversion = "conversion"
    case error = "error"
    case performance = "performance"
    case notification = "notification"
    case social = "social"
    case discovery = "discovery"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .session: return "Session"
        case .navigation: return "Navigation"
        case .interaction: return "Interaction"
        case .feature: return "Feature"
        case .conversion: return "Conversion"
        case .error: return "Error"
        case .performance: return "Performance"
        case .notification: return "Notification"
        case .social: return "Social"
        case .discovery: return "Discovery"
        case .custom: return "Custom"
        }
    }
}

struct EventContext: Codable {
    let screenOrientation: String
    let batteryLevel: Double?
    let networkType: String
    let memoryUsage: Double?
    let isLowPowerMode: Bool
    let timestamp: Date
}

// MARK: - Behavior Pattern
struct BehaviorPattern: Identifiable, Codable {
    let id: UUID
    let patternId: String
    let description: String
    let eventSequence: [BehaviorEventType]
    var occurrenceCount: Int
    let firstSeen: Date
    var lastSeen: Date
    var confidence: Double
    let category: PatternCategory
    let significance: PatternSignificance
    var userSegments: [String] = []
    var associatedFeatures: [String] = []
    var conversionImpact: Double?
    
    var frequency: PatternFrequency {
        let daysSinceFirst = Date().timeIntervalSince(firstSeen) / 86400.0
        let occurrencesPerDay = Double(occurrenceCount) / max(daysSinceFirst, 1.0)
        
        if occurrencesPerDay >= 10 { return .veryHigh }
        else if occurrencesPerDay >= 5 { return .high }
        else if occurrencesPerDay >= 1 { return .medium }
        else if occurrencesPerDay >= 0.1 { return .low }
        else { return .veryLow }
    }
}

enum PatternCategory: String, CaseIterable, Codable {
    case navigation = "navigation"
    case engagement = "engagement"
    case conversion = "conversion"
    case retention = "retention"
    case feature = "feature"
    case performance = "performance"
    case error = "error"
    case social = "social"
    
    var displayName: String {
        switch self {
        case .navigation: return "Navigation"
        case .engagement: return "Engagement"
        case .conversion: return "Conversion"
        case .retention: return "Retention"
        case .feature: return "Feature"
        case .performance: return "Performance"
        case .error: return "Error"
        case .social: return "Social"
        }
    }
}

enum PatternSignificance: String, CaseIterable, Codable {
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

enum PatternFrequency: String, CaseIterable, Codable {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}

// MARK: - User Journey
struct UserJourney: Identifiable, Codable {
    let id: UUID
    let sessionId: String
    let userId: String?
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    var events: [BehaviorEvent] = []
    var touchpoints: [String] = []
    var conversionEvents: [String] = []
    var dropOffPoint: String?
    var journeyStage: JourneyStage = .discovery
    var satisfaction: Double?
    var completionRate: Double = 0.0
    
    var isCompleted: Bool {
        return endTime != nil && !conversionEvents.isEmpty
    }
    
    var journeyEfficiency: Double {
        guard events.count > 0 else { return 0.0 }
        let conversionEventCount = Double(conversionEvents.count)
        let totalEventCount = Double(events.count)
        return conversionEventCount / totalEventCount
    }
}

enum JourneyStage: String, CaseIterable, Codable {
    case discovery = "discovery"
    case exploration = "exploration"
    case engagement = "engagement"
    case conversion = "conversion"
    case retention = "retention"
    case advocacy = "advocacy"
    
    var displayName: String {
        switch self {
        case .discovery: return "Discovery"
        case .exploration: return "Exploration"
        case .engagement: return "Engagement"
        case .conversion: return "Conversion"
        case .retention: return "Retention"
        case .advocacy: return "Advocacy"
        }
    }
}

// MARK: - Cohort Analysis
struct CohortData: Identifiable, Codable {
    let id = UUID()
    let cohortDate: Date
    let totalUsers: Int
    let retentionData: [RetentionPoint]
    var cohortSize: CohortSize {
        if totalUsers >= 1000 { return .large }
        else if totalUsers >= 100 { return .medium }
        else if totalUsers >= 10 { return .small }
        else { return .tiny }
    }
}

struct RetentionPoint: Codable {
    let week: Int
    let activeUsers: Int
    let retentionRate: Double
}

enum CohortSize: String, CaseIterable, Codable {
    case tiny = "tiny"
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .tiny: return "< 10 users"
        case .small: return "10-99 users"
        case .medium: return "100-999 users"
        case .large: return "1000+ users"
        }
    }
}

// MARK: - Conversion Funnel
struct ConversionFunnel: Identifiable, Codable {
    let id: UUID
    let name: String
    var steps: [String]
    let description: String
    var conversionData: [String: [String]] = [:] // step -> user IDs
    var conversionRates: [String: Double] = [:]
    var dropOffRates: [String: Double] = [:]
    var lastUpdated: Date = Date()
    
    mutating func updateConversion(event: String, userId: String) {
        if steps.contains(event) {
            conversionData[event, default: []].append(userId)
            calculateConversionRates()
            lastUpdated = Date()
        }
    }
    
    private mutating func calculateConversionRates() {
        for (index, step) in steps.enumerated() {
            let stepUsers = Set(conversionData[step] ?? [])
            let previousStepUsers: Set<String>
            
            if index == 0 {
                previousStepUsers = stepUsers
            } else {
                previousStepUsers = Set(conversionData[steps[index - 1]] ?? [])
            }
            
            let conversionRate = previousStepUsers.count > 0 
                ? Double(stepUsers.count) / Double(previousStepUsers.count) 
                : 0.0
            conversionRates[step] = conversionRate
            dropOffRates[step] = 1.0 - conversionRate
        }
    }
    
    var overallConversionRate: Double {
        guard !steps.isEmpty,
              let firstStep = steps.first,
              let lastStep = steps.last else { return 0.0 }
        
        let firstStepUsers = Set(conversionData[firstStep] ?? []).count
        let lastStepUsers = Set(conversionData[lastStep] ?? []).count
        
        return firstStepUsers > 0 ? Double(lastStepUsers) / Double(firstStepUsers) : 0.0
    }
}

// MARK: - Feature Usage
struct FeatureUsage: Identifiable, Codable {
    let id = UUID()
    let featureName: String
    var totalUsage: Int
    var successfulUsage: Int
    var totalDuration: TimeInterval
    var averageDuration: TimeInterval
    var successRate: Double
    let firstUsed: Date
    var lastUsed: Date
    var userSegments: [String: Int] = [:]
    var adoptionRate: Double = 0.0
    var retentionRate: Double = 0.0
    
    var usageFrequency: UsageFrequency {
        let daysSinceFirst = Date().timeIntervalSince(firstUsed) / 86400.0
        let usagePerDay = Double(totalUsage) / max(daysSinceFirst, 1.0)
        
        if usagePerDay >= 10 { return .veryHigh }
        else if usagePerDay >= 5 { return .high }
        else if usagePerDay >= 1 { return .medium }
        else if usagePerDay >= 0.1 { return .low }
        else { return .veryLow }
    }
}

enum UsageFrequency: String, CaseIterable, Codable {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}

// MARK: - Retention Metrics
struct RetentionMetrics: Codable {
    var totalUsers: Int = 0
    var dayOneRetention: Double = 0.0
    var weekOneRetention: Double = 0.0
    var monthOneRetention: Double = 0.0
    var averageSessionLength: TimeInterval = 0.0
    var sessionsPerUser: Double = 0.0
    var churned30Day: Int = 0
    var churnRate: Double = 0.0
    var lifetimeValue: Double = 0.0
    
    var retentionGrade: RetentionGrade {
        let avgRetention = (dayOneRetention + weekOneRetention + monthOneRetention) / 3.0
        
        if avgRetention >= 0.8 { return .excellent }
        else if avgRetention >= 0.6 { return .good }
        else if avgRetention >= 0.4 { return .average }
        else if avgRetention >= 0.2 { return .poor }
        else { return .critical }
    }
}

enum RetentionGrade: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case average = "average"
    case poor = "poor"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent (80%+)"
        case .good: return "Good (60-79%)"
        case .average: return "Average (40-59%)"
        case .poor: return "Poor (20-39%)"
        case .critical: return "Critical (<20%)"
        }
    }
}

// MARK: - Churn Prediction
struct ChurnPrediction: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let churnRisk: Double
    let riskFactors: [String]
    let lastActivity: Date
    let predictedChurnDate: Date?
    let recommendations: [String]
    var interventionActions: [String] = []
    var isInterventionActive: Bool = false
    var interventionDate: Date?
    
    var riskLevel: ChurnRiskLevel {
        if churnRisk >= 0.8 { return .critical }
        else if churnRisk >= 0.6 { return .high }
        else if churnRisk >= 0.4 { return .medium }
        else if churnRisk >= 0.2 { return .low }
        else { return .minimal }
    }
    
    var daysSinceLastActivity: Int {
        return Calendar.current.dateComponents([.day], from: lastActivity, to: Date()).day ?? 0
    }
}

enum ChurnRiskLevel: String, CaseIterable, Codable {
    case minimal = "minimal"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .minimal: return "Minimal (<20%)"
        case .low: return "Low (20-39%)"
        case .medium: return "Medium (40-59%)"
        case .high: return "High (60-79%)"
        case .critical: return "Critical (80%+)"
        }
    }
    
    var color: String {
        switch self {
        case .minimal: return "green"
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Behavior Insights
struct BehaviorInsights: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let totalSessions: Int
    let averageEngagement: Double
    let favoriteFeatures: [String]
    let behaviorPatterns: [BehaviorPattern]
    let churnRisk: Double
    let lastActivity: Date = Date()
    var userSegment: UserSegment = .unknown
    var preferredTime: TimeOfDay = .unknown
    var devicePreference: DeviceType = .unknown
    var engagementTrend: EngagementTrend = .stable
    
    var insightSummary: String {
        return "User has \(totalSessions) sessions with \(Int(averageEngagement))% engagement"
    }
}

enum UserSegment: String, CaseIterable, Codable {
    case powerUser = "power_user"
    case regularUser = "regular_user"
    case casualUser = "casual_user"
    case newUser = "new_user"
    case churningUser = "churning_user"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .powerUser: return "Power User"
        case .regularUser: return "Regular User"
        case .casualUser: return "Casual User"
        case .newUser: return "New User"
        case .churningUser: return "Churning User"
        case .unknown: return "Unknown"
        }
    }
}

enum TimeOfDay: String, CaseIterable, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        case .unknown: return "Unknown"
        }
    }
}

enum DeviceType: String, CaseIterable, Codable {
    case phone = "phone"
    case tablet = "tablet"
    case desktop = "desktop"
    case tv = "tv"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .phone: return "Phone"
        case .tablet: return "Tablet"
        case .desktop: return "Desktop"
        case .tv: return "TV"
        case .unknown: return "Unknown"
        }
    }
}

enum EngagementTrend: String, CaseIterable, Codable {
    case increasing = "increasing"
    case stable = "stable"
    case decreasing = "decreasing"
    case volatile = "volatile"
    
    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .stable: return "Stable"
        case .decreasing: return "Decreasing"
        case .volatile: return "Volatile"
        }
    }
}

// MARK: - A/B Test Participation
struct ABTestParticipation: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let testName: String
    let variant: String
    let startDate: Date
    var endDate: Date?
    var hasConverted: Bool = false
    var conversionDate: Date?
    var conversionValue: Double?
    var exposureEvents: [BehaviorEvent] = []
    
    var participationDuration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }
}

// MARK: - User Segment Analysis
struct UserSegmentAnalysis: Identifiable, Codable {
    let id = UUID()
    let segmentName: String
    let criteria: [String: Any]
    let userCount: Int
    let averageEngagement: Double
    let retentionRate: Double
    let conversionRate: Double
    let churnRate: Double
    let topFeatures: [String]
    let behaviorCharacteristics: [String]
    let recommendations: [String]
    
    // Custom Codable implementation for Any type
    enum CodingKeys: String, CodingKey {
        case id, segmentName, userCount, averageEngagement, retentionRate, conversionRate, churnRate, topFeatures, behaviorCharacteristics, recommendations
        case criteria
    }
    
    init(id: UUID = UUID(), segmentName: String, criteria: [String: Any], userCount: Int, averageEngagement: Double, retentionRate: Double, conversionRate: Double, churnRate: Double, topFeatures: [String], behaviorCharacteristics: [String], recommendations: [String]) {
        self.id = id
        self.segmentName = segmentName
        self.criteria = criteria
        self.userCount = userCount
        self.averageEngagement = averageEngagement
        self.retentionRate = retentionRate
        self.conversionRate = conversionRate
        self.churnRate = churnRate
        self.topFeatures = topFeatures
        self.behaviorCharacteristics = behaviorCharacteristics
        self.recommendations = recommendations
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        segmentName = try container.decode(String.self, forKey: .segmentName)
        userCount = try container.decode(Int.self, forKey: .userCount)
        averageEngagement = try container.decode(Double.self, forKey: .averageEngagement)
        retentionRate = try container.decode(Double.self, forKey: .retentionRate)
        conversionRate = try container.decode(Double.self, forKey: .conversionRate)
        churnRate = try container.decode(Double.self, forKey: .churnRate)
        topFeatures = try container.decode([String].self, forKey: .topFeatures)
        behaviorCharacteristics = try container.decode([String].self, forKey: .behaviorCharacteristics)
        recommendations = try container.decode([String].self, forKey: .recommendations)
        
        // Decode criteria as simplified string dictionary
        criteria = try container.decode([String: String].self, forKey: .criteria)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(segmentName, forKey: .segmentName)
        try container.encode(userCount, forKey: .userCount)
        try container.encode(averageEngagement, forKey: .averageEngagement)
        try container.encode(retentionRate, forKey: .retentionRate)
        try container.encode(conversionRate, forKey: .conversionRate)
        try container.encode(churnRate, forKey: .churnRate)
        try container.encode(topFeatures, forKey: .topFeatures)
        try container.encode(behaviorCharacteristics, forKey: .behaviorCharacteristics)
        try container.encode(recommendations, forKey: .recommendations)
        
        // Encode criteria as simplified string dictionary
        let stringCriteria = criteria.mapValues { String(describing: $0) }
        try container.encode(stringCriteria, forKey: .criteria)
    }
}

// MARK: - Behavior Export Data
struct BehaviorExportData: Codable {
    let userSessions: [UserSession]
    let behaviorPatterns: [BehaviorPattern]
    let engagementMetrics: [UserEngagementMetric]
    let userJourneys: [UserJourney]
    let cohortAnalysis: [CohortData]
    let conversionFunnels: [ConversionFunnel]
    let featureUsageStats: [FeatureUsage]
    let retentionMetrics: RetentionMetrics
    let churnPredictions: [ChurnPrediction]
    let exportDate: Date
    let appVersion: String = Config.App.version
    let deviceModel: String = UIDevice.current.model
    let osVersion: String = UIDevice.current.systemVersion
}

// MARK: - AnyCodable for CGPoint
extension CGPoint: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    private enum CodingKeys: String, CodingKey {
        case x, y
    }
}