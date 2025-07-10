//
//  UserBehaviorAnalyzer.swift
//  StreamyyyApp
//
//  Advanced user behavior analysis and engagement tracking
//

import Foundation
import SwiftUI
import Combine

// MARK: - User Behavior Analyzer
class UserBehaviorAnalyzer: ObservableObject {
    static let shared = UserBehaviorAnalyzer()
    
    // MARK: - Published Properties
    @Published var userSessions: [UserSession] = []
    @Published var behaviorPatterns: [BehaviorPattern] = []
    @Published var engagementMetrics: [UserEngagementMetric] = []
    @Published var userJourneys: [UserJourney] = []
    @Published var cohortAnalysis: [CohortData] = []
    @Published var conversionFunnels: [ConversionFunnel] = []
    @Published var featureUsageStats: [FeatureUsage] = []
    @Published var retentionMetrics: RetentionMetrics = RetentionMetrics()
    @Published var churnPredictions: [ChurnPrediction] = []
    
    // MARK: - Current Session Tracking
    @Published var currentSession: UserSession?
    @Published var currentUserJourney: UserJourney?
    @Published var sessionEngagementScore: Double = 0.0
    @Published var realTimeEvents: [BehaviorEvent] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var analyticsManager = AnalyticsManager.shared
    private var sessionStartTime: Date?
    private var lastEventTime: Date?
    private var eventSequence: [BehaviorEvent] = []
    private var screenTimeTracker: [String: TimeInterval] = [:]
    private var featureInteractions: [String: Int] = [:]
    
    // MARK: - Configuration
    private let sessionTimeoutInterval: TimeInterval = 1800 // 30 minutes
    private let engagementUpdateInterval: TimeInterval = 10.0 // 10 seconds
    private let maxStoredSessions = 1000
    private let maxEventsPerSession = 500
    
    // MARK: - Initialization
    private init() {
        setupBehaviorTracking()
        setupEngagementTracking()
        loadStoredData()
    }
    
    // MARK: - Setup
    private func setupBehaviorTracking() {
        // Subscribe to app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startSession()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pauseSession()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.endSession()
            }
            .store(in: &cancellables)
        
        // Subscribe to user actions
        NotificationCenter.default.publisher(for: .userActionTracked)
            .sink { [weak self] notification in
                self?.handleUserAction(notification)
            }
            .store(in: &cancellables)
    }
    
    private func setupEngagementTracking() {
        // Start periodic engagement tracking
        Timer.scheduledTimer(withTimeInterval: engagementUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateEngagementMetrics()
        }
    }
    
    // MARK: - Session Management
    func startSession() {
        let sessionId = UUID().uuidString
        sessionStartTime = Date()
        lastEventTime = Date()
        
        currentSession = UserSession(
            id: sessionId,
            userId: getCurrentUserId(),
            startTime: Date(),
            deviceInfo: getCurrentDeviceInfo(),
            appVersion: Config.App.version,
            platform: "iOS"
        )
        
        currentUserJourney = UserJourney(
            id: UUID(),
            sessionId: sessionId,
            userId: getCurrentUserId(),
            startTime: Date()
        )
        
        // Reset session tracking
        eventSequence.removeAll()
        screenTimeTracker.removeAll()
        featureInteractions.removeAll()
        sessionEngagementScore = 0.0
        
        trackBehaviorEvent(.sessionStart, properties: [
            "session_id": sessionId,
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion
        ])
        
        analyticsManager.trackUserBehavior(behavior: "session_started", properties: [
            "session_id": sessionId
        ])
    }
    
    func pauseSession() {
        guard let session = currentSession else { return }
        
        trackBehaviorEvent(.sessionPause, properties: [
            "session_duration": Date().timeIntervalSince(session.startTime)
        ])
    }
    
    func endSession() {
        guard var session = currentSession else { return }
        
        let endTime = Date()
        session.endTime = endTime
        session.duration = endTime.timeIntervalSince(session.startTime)
        session.events = eventSequence
        session.screenTime = screenTimeTracker
        session.featureInteractions = featureInteractions
        session.engagementScore = calculateSessionEngagementScore()
        
        // Finalize user journey
        if var journey = currentUserJourney {
            journey.endTime = endTime
            journey.duration = endTime.timeIntervalSince(journey.startTime)
            journey.events = eventSequence
            journey.touchpoints = extractTouchpoints(from: eventSequence)
            journey.conversionEvents = extractConversions(from: eventSequence)
            
            userJourneys.append(journey)
        }
        
        userSessions.append(session)
        
        // Keep only recent sessions
        if userSessions.count > maxStoredSessions {
            userSessions.removeFirst()
        }
        
        trackBehaviorEvent(.sessionEnd, properties: [
            "session_duration": session.duration,
            "engagement_score": session.engagementScore,
            "events_count": eventSequence.count
        ])
        
        // Analyze session for patterns
        analyzeSessionPatterns(session)
        
        // Update metrics
        updateUserMetrics()
        
        // Clear current session
        currentSession = nil
        currentUserJourney = nil
        
        analyticsManager.trackUserBehavior(behavior: "session_ended", properties: [
            "duration": session.duration,
            "engagement_score": session.engagementScore
        ])
    }
    
    // MARK: - Event Tracking
    func trackBehaviorEvent(_ type: BehaviorEventType, properties: [String: Any] = [:]) {
        let event = BehaviorEvent(
            id: UUID(),
            type: type,
            timestamp: Date(),
            sessionId: currentSession?.id ?? "",
            userId: getCurrentUserId(),
            properties: properties,
            screenName: getCurrentScreenName(),
            elementId: properties["element_id"] as? String,
            coordinates: extractCoordinates(from: properties)
        )
        
        eventSequence.append(event)
        realTimeEvents.append(event)
        lastEventTime = Date()
        
        // Keep only recent real-time events
        if realTimeEvents.count > 50 {
            realTimeEvents.removeFirst()
        }
        
        // Update current session
        currentSession?.eventCount += 1
        
        // Track feature usage
        if let feature = properties["feature"] as? String {
            featureInteractions[feature, default: 0] += 1
        }
        
        // Update screen time
        if let screenName = event.screenName {
            updateScreenTime(for: screenName)
        }
        
        // Process event for real-time insights
        processRealTimeEvent(event)
        
        // Post notification for other components
        NotificationCenter.default.post(
            name: .behaviorEventTracked,
            object: self,
            userInfo: ["event": event]
        )
    }
    
    func trackScreenView(_ screenName: String, properties: [String: Any] = [:]) {
        var screenProperties = properties
        screenProperties["screen_name"] = screenName
        
        trackBehaviorEvent(.screenView, properties: screenProperties)
        
        analyticsManager.trackUserBehavior(behavior: "screen_viewed", properties: screenProperties)
    }
    
    func trackUserAction(_ action: String, target: String? = nil, properties: [String: Any] = [:]) {
        var actionProperties = properties
        actionProperties["action"] = action
        if let target = target {
            actionProperties["target"] = target
        }
        
        trackBehaviorEvent(.userAction, properties: actionProperties)
        
        analyticsManager.trackUserBehavior(behavior: "user_action", properties: actionProperties)
    }
    
    func trackFeatureUsage(_ feature: String, duration: TimeInterval? = nil, success: Bool = true, properties: [String: Any] = [:]) {
        var featureProperties = properties
        featureProperties["feature"] = feature
        featureProperties["success"] = success
        if let duration = duration {
            featureProperties["duration"] = duration
        }
        
        trackBehaviorEvent(.featureUsage, properties: featureProperties)
        
        // Update feature usage statistics
        updateFeatureUsageStats(feature: feature, duration: duration, success: success)
        
        analyticsManager.trackFeatureUsed(feature: feature, context: properties["context"] as? String ?? "")
    }
    
    func trackConversionEvent(_ event: String, value: Double? = nil, properties: [String: Any] = [:]) {
        var conversionProperties = properties
        conversionProperties["conversion_event"] = event
        if let value = value {
            conversionProperties["value"] = value
        }
        
        trackBehaviorEvent(.conversion, properties: conversionProperties)
        
        // Update conversion funnel
        updateConversionFunnels(event: event, properties: conversionProperties)
        
        analyticsManager.trackConversionEvent(event: event, value: value, properties: properties)
    }
    
    // MARK: - Engagement Analysis
    private func updateEngagementMetrics() {
        guard let session = currentSession,
              let startTime = sessionStartTime else { return }
        
        let currentEngagement = calculateCurrentEngagement(
            sessionDuration: Date().timeIntervalSince(startTime),
            eventCount: eventSequence.count,
            featureInteractions: featureInteractions.values.reduce(0, +),
            screenTransitions: getScreenTransitionCount()
        )
        
        sessionEngagementScore = currentEngagement
        
        let engagementMetric = UserEngagementMetric(
            id: UUID(),
            userId: session.userId,
            sessionId: session.id,
            action: "session_engagement",
            duration: Date().timeIntervalSince(startTime),
            engagementScore: currentEngagement,
            timestamp: Date()
        )
        
        engagementMetrics.append(engagementMetric)
        
        // Keep only recent metrics
        if engagementMetrics.count > 1000 {
            engagementMetrics.removeFirst()
        }
    }
    
    private func calculateCurrentEngagement(sessionDuration: TimeInterval, eventCount: Int, featureInteractions: Int, screenTransitions: Int) -> Double {
        // Base engagement score
        var score = 0.0
        
        // Duration factor (0-30 points)
        let durationScore = min(sessionDuration / 300.0, 1.0) * 30.0 // Max 5 minutes
        score += durationScore
        
        // Event frequency factor (0-25 points)
        let eventFrequency = Double(eventCount) / max(sessionDuration / 60.0, 1.0) // Events per minute
        let eventScore = min(eventFrequency / 10.0, 1.0) * 25.0 // Max 10 events per minute
        score += eventScore
        
        // Feature interaction factor (0-25 points)
        let interactionScore = min(Double(featureInteractions) / 20.0, 1.0) * 25.0 // Max 20 interactions
        score += interactionScore
        
        // Screen transition factor (0-20 points)
        let transitionScore = min(Double(screenTransitions) / 10.0, 1.0) * 20.0 // Max 10 transitions
        score += transitionScore
        
        return min(score, 100.0)
    }
    
    private func calculateSessionEngagementScore() -> Double {
        guard let session = currentSession else { return 0.0 }
        
        return calculateCurrentEngagement(
            sessionDuration: session.duration,
            eventCount: session.eventCount,
            featureInteractions: session.featureInteractions.values.reduce(0, +),
            screenTransitions: getScreenTransitionCount()
        )
    }
    
    // MARK: - Pattern Analysis
    private func analyzeSessionPatterns(_ session: UserSession) {
        // Analyze user behavior patterns
        let patterns = extractBehaviorPatterns(from: session)
        
        for pattern in patterns {
            if let existingIndex = behaviorPatterns.firstIndex(where: { $0.patternId == pattern.patternId }) {
                // Update existing pattern
                behaviorPatterns[existingIndex].occurrenceCount += 1
                behaviorPatterns[existingIndex].lastSeen = Date()
                behaviorPatterns[existingIndex].confidence = updatePatternConfidence(behaviorPatterns[existingIndex])
            } else {
                // Add new pattern
                behaviorPatterns.append(pattern)
            }
        }
        
        // Sort patterns by confidence and frequency
        behaviorPatterns.sort { pattern1, pattern2 in
            if pattern1.confidence == pattern2.confidence {
                return pattern1.occurrenceCount > pattern2.occurrenceCount
            }
            return pattern1.confidence > pattern2.confidence
        }
        
        // Keep only top 100 patterns
        if behaviorPatterns.count > 100 {
            behaviorPatterns = Array(behaviorPatterns.prefix(100))
        }
    }
    
    private func extractBehaviorPatterns(from session: UserSession) -> [BehaviorPattern] {
        var patterns: [BehaviorPattern] = []
        
        // Analyze event sequences
        let eventTypes = session.events.map { $0.type }
        
        // Find common sequences of length 3
        for i in 0..<(eventTypes.count - 2) {
            let sequence = Array(eventTypes[i..<i+3])
            let patternId = sequence.map { $0.rawValue }.joined(separator: "->")
            
            let pattern = BehaviorPattern(
                id: UUID(),
                patternId: patternId,
                description: "User sequence: \(patternId)",
                eventSequence: sequence,
                occurrenceCount: 1,
                firstSeen: session.startTime,
                lastSeen: session.endTime ?? Date(),
                confidence: 0.5,
                category: .navigation,
                significance: .medium
            )
            
            patterns.append(pattern)
        }
        
        // Analyze feature usage patterns
        for (feature, count) in session.featureInteractions {
            if count >= 3 {
                let pattern = BehaviorPattern(
                    id: UUID(),
                    patternId: "feature_usage_\(feature)",
                    description: "Heavy usage of \(feature)",
                    eventSequence: [.featureUsage],
                    occurrenceCount: count,
                    firstSeen: session.startTime,
                    lastSeen: session.endTime ?? Date(),
                    confidence: min(Double(count) / 10.0, 1.0),
                    category: .engagement,
                    significance: count >= 10 ? .high : .medium
                )
                
                patterns.append(pattern)
            }
        }
        
        return patterns
    }
    
    private func updatePatternConfidence(_ pattern: BehaviorPattern) -> Double {
        // Calculate confidence based on frequency and recency
        let frequencyScore = min(Double(pattern.occurrenceCount) / 100.0, 1.0)
        let recencyScore = max(0, 1.0 - Date().timeIntervalSince(pattern.lastSeen) / 86400.0) // Decay over 24 hours
        
        return (frequencyScore + recencyScore) / 2.0
    }
    
    // MARK: - Cohort Analysis
    func performCohortAnalysis() {
        let calendar = Calendar.current
        let now = Date()
        
        // Group users by signup week
        let userCohorts = Dictionary(grouping: userSessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? session.startTime
        }
        
        var cohortData: [CohortData] = []
        
        for (cohortDate, sessions) in userCohorts {
            let uniqueUsers = Set(sessions.compactMap { $0.userId }).count
            
            // Calculate retention for each week after signup
            var retentionData: [RetentionPoint] = []
            
            for week in 0..<12 { // 12 weeks of retention data
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: week, to: cohortDate),
                      let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                    continue
                }
                
                let activeUsers = Set(sessions.filter { session in
                    session.startTime >= weekStart && session.startTime < weekEnd
                }.compactMap { $0.userId }).count
                
                let retentionRate = uniqueUsers > 0 ? Double(activeUsers) / Double(uniqueUsers) : 0.0
                
                retentionData.append(RetentionPoint(
                    week: week,
                    activeUsers: activeUsers,
                    retentionRate: retentionRate
                ))
            }
            
            cohortData.append(CohortData(
                cohortDate: cohortDate,
                totalUsers: uniqueUsers,
                retentionData: retentionData
            ))
        }
        
        self.cohortAnalysis = cohortData.sorted { $0.cohortDate > $1.cohortDate }
    }
    
    // MARK: - Conversion Funnel Analysis
    private func updateConversionFunnels(event: String, properties: [String: Any]) {
        // Define conversion funnels
        let funnels = [
            ConversionFunnel(
                id: UUID(),
                name: "User Onboarding",
                steps: ["app_opened", "signup_started", "signup_completed", "first_stream_added"],
                description: "User onboarding process"
            ),
            ConversionFunnel(
                id: UUID(),
                name: "Subscription Flow",
                steps: ["subscription_viewed", "plan_selected", "payment_started", "subscription_completed"],
                description: "Subscription conversion process"
            )
        ]
        
        // Update funnel data
        for var funnel in funnels {
            if funnel.steps.contains(event) {
                funnel.updateConversion(event: event, userId: getCurrentUserId() ?? "anonymous")
                
                if let index = conversionFunnels.firstIndex(where: { $0.id == funnel.id }) {
                    conversionFunnels[index] = funnel
                } else {
                    conversionFunnels.append(funnel)
                }
            }
        }
    }
    
    // MARK: - Feature Usage Analysis
    private func updateFeatureUsageStats(feature: String, duration: TimeInterval?, success: Bool) {
        if let index = featureUsageStats.firstIndex(where: { $0.featureName == feature }) {
            var stats = featureUsageStats[index]
            stats.totalUsage += 1
            stats.lastUsed = Date()
            
            if let duration = duration {
                stats.totalDuration += duration
                stats.averageDuration = stats.totalDuration / Double(stats.totalUsage)
            }
            
            if success {
                stats.successfulUsage += 1
            }
            
            stats.successRate = Double(stats.successfulUsage) / Double(stats.totalUsage)
            featureUsageStats[index] = stats
        } else {
            let newStats = FeatureUsage(
                featureName: feature,
                totalUsage: 1,
                successfulUsage: success ? 1 : 0,
                totalDuration: duration ?? 0,
                averageDuration: duration ?? 0,
                successRate: success ? 1.0 : 0.0,
                firstUsed: Date(),
                lastUsed: Date()
            )
            featureUsageStats.append(newStats)
        }
    }
    
    // MARK: - Churn Prediction
    func performChurnPrediction() {
        // Analyze user behavior to predict churn
        let recentUsers = Set(userSessions.filter { session in
            Date().timeIntervalSince(session.startTime) <= 2592000 // Last 30 days
        }.compactMap { $0.userId })
        
        var predictions: [ChurnPrediction] = []
        
        for userId in recentUsers {
            let userSessions = self.userSessions.filter { $0.userId == userId }
            let churnRisk = calculateChurnRisk(for: userId, sessions: userSessions)
            
            predictions.append(ChurnPrediction(
                userId: userId,
                churnRisk: churnRisk,
                riskFactors: identifyChurnRiskFactors(sessions: userSessions),
                lastActivity: userSessions.last?.startTime ?? Date(),
                predictedChurnDate: calculatePredictedChurnDate(churnRisk: churnRisk),
                recommendations: generateRetentionRecommendations(churnRisk: churnRisk)
            ))
        }
        
        self.churnPredictions = predictions.sorted { $0.churnRisk > $1.churnRisk }
    }
    
    private func calculateChurnRisk(for userId: String, sessions: [UserSession]) -> Double {
        guard !sessions.isEmpty else { return 1.0 }
        
        let lastSession = sessions.max(by: { $0.startTime < $1.startTime })!
        let daysSinceLastSession = Date().timeIntervalSince(lastSession.startTime) / 86400.0
        
        // Base risk on days since last session
        var risk = min(daysSinceLastSession / 14.0, 1.0) // 14 days = 100% risk
        
        // Adjust based on engagement
        let avgEngagement = sessions.map { $0.engagementScore }.reduce(0, +) / Double(sessions.count)
        risk *= (1.0 - avgEngagement / 100.0)
        
        // Adjust based on session frequency
        let sessionFrequency = Double(sessions.count) / max(daysSinceLastSession, 1.0)
        risk *= max(0.1, 1.0 - sessionFrequency / 7.0) // 7 sessions per day = low risk
        
        return min(risk, 1.0)
    }
    
    private func identifyChurnRiskFactors(sessions: [UserSession]) -> [String] {
        var riskFactors: [String] = []
        
        if sessions.isEmpty {
            riskFactors.append("No session data")
            return riskFactors
        }
        
        let lastSession = sessions.max(by: { $0.startTime < $1.startTime })!
        let daysSinceLastSession = Date().timeIntervalSince(lastSession.startTime) / 86400.0
        
        if daysSinceLastSession > 7 {
            riskFactors.append("Inactive for \(Int(daysSinceLastSession)) days")
        }
        
        let avgEngagement = sessions.map { $0.engagementScore }.reduce(0, +) / Double(sessions.count)
        if avgEngagement < 50 {
            riskFactors.append("Low engagement score: \(Int(avgEngagement))")
        }
        
        let avgSessionDuration = sessions.map { $0.duration }.reduce(0, +) / Double(sessions.count)
        if avgSessionDuration < 300 { // 5 minutes
            riskFactors.append("Short session duration: \(Int(avgSessionDuration))s")
        }
        
        return riskFactors
    }
    
    private func calculatePredictedChurnDate(churnRisk: Double) -> Date? {
        guard churnRisk > 0 else { return nil }
        
        // Predict churn within 1-30 days based on risk
        let daysUntilChurn = (1.0 - churnRisk) * 30.0
        return Calendar.current.date(byAdding: .day, value: Int(daysUntilChurn), to: Date())
    }
    
    private func generateRetentionRecommendations(churnRisk: Double) -> [String] {
        var recommendations: [String] = []
        
        if churnRisk > 0.8 {
            recommendations.append("Send immediate re-engagement campaign")
            recommendations.append("Offer premium features trial")
            recommendations.append("Personal outreach recommended")
        } else if churnRisk > 0.5 {
            recommendations.append("Send targeted content recommendations")
            recommendations.append("Highlight unused features")
            recommendations.append("Offer customer support assistance")
        } else if churnRisk > 0.3 {
            recommendations.append("Increase content personalization")
            recommendations.append("Send feature tutorials")
        }
        
        return recommendations
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserId() -> String? {
        // Get current user ID from authentication system
        return "user_12345" // Placeholder
    }
    
    private func getCurrentScreenName() -> String? {
        // Get current screen name from navigation system
        return "StreamGridView" // Placeholder
    }
    
    private func getCurrentDeviceInfo() -> [String: String] {
        return [
            "model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "app_version": Config.App.version
        ]
    }
    
    private func extractCoordinates(from properties: [String: Any]) -> CGPoint? {
        guard let x = properties["x"] as? Double,
              let y = properties["y"] as? Double else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }
    
    private func updateScreenTime(for screenName: String) {
        // Simple screen time tracking
        screenTimeTracker[screenName, default: 0] += engagementUpdateInterval
    }
    
    private func getScreenTransitionCount() -> Int {
        return eventSequence.filter { $0.type == .screenView }.count
    }
    
    private func extractTouchpoints(from events: [BehaviorEvent]) -> [String] {
        return events.compactMap { $0.screenName }.removingDuplicates()
    }
    
    private func extractConversions(from events: [BehaviorEvent]) -> [String] {
        return events.filter { $0.type == .conversion }.compactMap { $0.properties["conversion_event"] as? String }
    }
    
    private func processRealTimeEvent(_ event: BehaviorEvent) {
        // Process event for real-time insights
        // This could trigger immediate actions based on behavior
        
        if event.type == .featureUsage {
            // Check for feature adoption
            if let feature = event.properties["feature"] as? String {
                checkFeatureAdoption(feature: feature, userId: event.userId)
            }
        }
        
        if event.type == .conversion {
            // Trigger conversion tracking
            if let conversionEvent = event.properties["conversion_event"] as? String {
                analyticsManager.trackConversionEvent(event: conversionEvent)
            }
        }
    }
    
    private func checkFeatureAdoption(feature: String, userId: String?) {
        guard let userId = userId else { return }
        
        let userFeatureUsage = eventSequence.filter { event in
            event.userId == userId &&
            event.type == .featureUsage &&
            event.properties["feature"] as? String == feature
        }
        
        // Track feature adoption milestone
        if userFeatureUsage.count == 1 {
            analyticsManager.trackFeatureAdoption(feature: feature, adopted: true)
        }
    }
    
    private func updateUserMetrics() {
        // Calculate retention metrics
        calculateRetentionMetrics()
        
        // Update engagement trends
        updateEngagementTrends()
    }
    
    private func calculateRetentionMetrics() {
        let uniqueUsers = Set(userSessions.compactMap { $0.userId })
        let totalUsers = uniqueUsers.count
        
        // Calculate daily retention
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let activeYesterday = Set(userSessions.filter { session in
            Calendar.current.isDate(session.startTime, inSameDayAs: yesterday)
        }.compactMap { $0.userId })
        
        let today = Date()
        let activeToday = Set(userSessions.filter { session in
            Calendar.current.isDate(session.startTime, inSameDayAs: today)
        }.compactMap { $0.userId })
        
        let dayOneRetention = activeYesterday.intersection(activeToday).count
        let dayOneRetentionRate = activeYesterday.count > 0 ? Double(dayOneRetention) / Double(activeYesterday.count) : 0.0
        
        // Calculate weekly retention (simplified)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let activeLastWeek = Set(userSessions.filter { session in
            session.startTime >= weekAgo && session.startTime < yesterday
        }.compactMap { $0.userId })
        
        let weeklyRetention = activeLastWeek.intersection(activeToday).count
        let weeklyRetentionRate = activeLastWeek.count > 0 ? Double(weeklyRetention) / Double(activeLastWeek.count) : 0.0
        
        retentionMetrics = RetentionMetrics(
            totalUsers: totalUsers,
            dayOneRetention: dayOneRetentionRate,
            weekOneRetention: weeklyRetentionRate,
            monthOneRetention: 0.0, // Placeholder
            averageSessionLength: userSessions.map { $0.duration }.reduce(0, +) / Double(max(userSessions.count, 1)),
            sessionsPerUser: Double(userSessions.count) / Double(max(totalUsers, 1))
        )
    }
    
    private func updateEngagementTrends() {
        // Calculate engagement trends over time
        // Implementation would analyze engagement over different time periods
    }
    
    private func loadStoredData() {
        // Load previously stored user behavior data
        // Implementation would depend on chosen storage method
    }
    
    private func handleUserAction(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let action = userInfo["action"] as? String else { return }
        
        trackUserAction(action, properties: userInfo)
    }
    
    // MARK: - Public API
    func getCurrentEngagementMetrics() async -> [UserEngagementMetric] {
        return engagementMetrics
    }
    
    func getBehaviorInsights(for userId: String) -> BehaviorInsights {
        let userSessions = self.userSessions.filter { $0.userId == userId }
        let userPatterns = behaviorPatterns.filter { pattern in
            userSessions.contains { session in
                session.events.contains { event in
                    pattern.eventSequence.contains(event.type)
                }
            }
        }
        
        return BehaviorInsights(
            userId: userId,
            totalSessions: userSessions.count,
            averageEngagement: userSessions.map { $0.engagementScore }.reduce(0, +) / Double(max(userSessions.count, 1)),
            favoriteFeatures: extractFavoriteFeatures(from: userSessions),
            behaviorPatterns: userPatterns,
            churnRisk: churnPredictions.first { $0.userId == userId }?.churnRisk ?? 0.0
        )
    }
    
    private func extractFavoriteFeatures(from sessions: [UserSession]) -> [String] {
        let allInteractions = sessions.flatMap { $0.featureInteractions }
        let groupedInteractions = Dictionary(grouping: allInteractions) { $0.key }
        
        return groupedInteractions
            .mapValues { $0.map { $0.value }.reduce(0, +) }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    func exportBehaviorData() -> Data? {
        let exportData = BehaviorExportData(
            userSessions: userSessions,
            behaviorPatterns: behaviorPatterns,
            engagementMetrics: engagementMetrics,
            userJourneys: userJourneys,
            cohortAnalysis: cohortAnalysis,
            conversionFunnels: conversionFunnels,
            featureUsageStats: featureUsageStats,
            retentionMetrics: retentionMetrics,
            churnPredictions: churnPredictions,
            exportDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(exportData)
        } catch {
            print("Failed to export behavior data: \(error)")
            return nil
        }
    }
}

// MARK: - Array Extension
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let userActionTracked = Notification.Name("userActionTracked")
    static let behaviorEventTracked = Notification.Name("behaviorEventTracked")
}