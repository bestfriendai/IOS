//
//  AnalyticsManager.swift
//  StreamyyyApp
//
//  Analytics and tracking manager
//

import Foundation
import UIKit
import Combine

// MARK: - Analytics Manager
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published var isEnabled = true
    
    private var sessionId: String
    private var sessionStartTime: Date
    private var eventQueue: [AnalyticsEvent] = []
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.sessionId = UUID().uuidString
        self.sessionStartTime = Date()
        
        setupAnalytics()
        startSession()
    }
    
    deinit {
        endSession()
    }
    
    // MARK: - Setup
    private func setupAnalytics() {
        // Check user preferences
        isEnabled = UserDefaults.standard.bool(forKey: "analytics_enabled")
        
        // Setup periodic flush
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.flushEvents()
        }
        
        // Setup app lifecycle observers
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in self.handleAppBackground() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in self.handleAppForeground() }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Management
    private func startSession() {
        guard isEnabled else { return }
        
        let event = AnalyticsEvent(
            name: "session_start",
            properties: [
                "session_id": sessionId,
                "app_version": Config.App.version,
                "build_number": Config.App.build,
                "device_model": UIDevice.current.model,
                "os_version": UIDevice.current.systemVersion,
                "is_first_launch": isFirstLaunch()
            ]
        )
        
        track(event)
    }
    
    private func endSession() {
        guard isEnabled else { return }
        
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        
        let event = AnalyticsEvent(
            name: "session_end",
            properties: [
                "session_id": sessionId,
                "session_duration": sessionDuration
            ]
        )
        
        track(event)
        flushEvents()
    }
    
    private func isFirstLaunch() -> Bool {
        let key = "has_launched_before"
        let hasLaunched = UserDefaults.standard.bool(forKey: key)
        
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: key)
            return true
        }
        
        return false
    }
    
    // MARK: - Event Tracking
    func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        
        var enrichedEvent = event
        enrichedEvent.sessionId = sessionId
        enrichedEvent.timestamp = Date()
        // enrichedEvent.userId = ClerkManager.shared.user?.id // TODO: Fix concurrency issue
        
        eventQueue.append(enrichedEvent)
        
        #if DEBUG
        print("📊 Analytics: \(event.name) - \(event.properties)")
        #endif
        
        // Flush immediately for critical events
        if event.isCritical {
            flushEvents()
        }
    }
    
    func track(name: String, properties: [String: Any] = [:]) {
        let event = AnalyticsEvent(name: name, properties: properties)
        track(event)
    }
    
    // MARK: - User Events
    func trackUserSignUp(method: String) {
        track(name: "user_sign_up", properties: [
            "method": method
        ])
    }
    
    func trackUserSignIn(method: String) {
        track(name: "user_sign_in", properties: [
            "method": method
        ])
    }
    
    func trackUserSignOut() {
        track(name: "user_sign_out")
    }
    
    // MARK: - Stream Events
    func trackStreamAdded(platform: String, url: String) {
        track(name: "stream_added", properties: [
            "platform": platform,
            "url_domain": URL(string: url)?.host ?? "unknown"
        ])
    }
    
    func trackStreamRemoved(platform: String) {
        track(name: "stream_removed", properties: [
            "platform": platform
        ])
    }
    
    func trackStreamViewed(streamId: String, platform: String, duration: TimeInterval) {
        track(name: "stream_viewed", properties: [
            "stream_id": streamId,
            "platform": platform,
            "duration": duration
        ])
    }
    
    func trackStreamShared(streamId: String, platform: String, method: String) {
        track(name: "stream_shared", properties: [
            "stream_id": streamId,
            "platform": platform,
            "method": method
        ])
    }
    
    // MARK: - Layout Events
    func trackLayoutChanged(from: String, to: String) {
        track(name: "layout_changed", properties: [
            "from_layout": from,
            "to_layout": to
        ])
    }
    
    func trackFullScreenEntered(streamId: String) {
        track(name: "fullscreen_entered", properties: [
            "stream_id": streamId
        ])
    }
    
    func trackFullScreenExited(streamId: String, duration: TimeInterval) {
        track(name: "fullscreen_exited", properties: [
            "stream_id": streamId,
            "duration": duration
        ])
    }
    
    // MARK: - Subscription Events
    func trackSubscriptionViewed() {
        track(name: "subscription_viewed")
    }
    
    func trackSubscriptionStarted(plan: String) {
        track(name: "subscription_started", properties: [
            "plan": plan
        ])
    }
    
    func trackSubscriptionCompleted(plan: String, price: Double) {
        track(name: "subscription_completed", properties: [
            "plan": plan,
            "price": price
        ])
    }
    
    func trackSubscriptionCancelled(plan: String, reason: String?) {
        track(name: "subscription_cancelled", properties: [
            "plan": plan,
            "reason": reason ?? "unknown"
        ])
    }
    
    // MARK: - Search Events
    func trackSearch(query: String, platform: String?, resultsCount: Int) {
        track(name: "search_performed", properties: [
            "query_length": query.count,
            "platform": platform ?? "all",
            "results_count": resultsCount
        ])
    }
    
    func trackSearchResultTapped(query: String, position: Int) {
        track(name: "search_result_tapped", properties: [
            "query_length": query.count,
            "position": position
        ])
    }
    
    // MARK: - Error Events
    func trackError(error: Error, context: String) {
        let event = AnalyticsEvent(
            name: "error_occurred",
            properties: [
                "error_description": error.localizedDescription,
                "context": context,
                "error_domain": (error as NSError).domain,
                "error_code": (error as NSError).code
            ],
            isCritical: true
        )
        
        track(event)
    }
    
    func trackPerformanceMetric(name: String, duration: TimeInterval, context: String) {
        track(name: "performance_metric", properties: [
            "metric_name": name,
            "duration": duration,
            "context": context
        ])
    }
    
    // MARK: - App Lifecycle
    private func handleAppBackground() {
        track(name: "app_backgrounded")
        flushEvents()
    }
    
    private func handleAppForeground() {
        track(name: "app_foregrounded")
    }
    
    // MARK: - Event Flushing
    private func flushEvents() {
        guard !eventQueue.isEmpty else { return }
        
        let eventsToSend = eventQueue
        eventQueue.removeAll()
        
        sendEvents(eventsToSend)
    }
    
    private func sendEvents(_ events: [AnalyticsEvent]) {
        guard isEnabled else { return }
        
        // Convert events to JSON
        do {
            let jsonData = try JSONEncoder().encode(events)
            
            // Send to analytics service
            sendToAnalyticsService(jsonData)
            
        } catch {
            print("Failed to encode analytics events: \(error)")
            
            // Re-queue events on failure
            eventQueue.append(contentsOf: events)
        }
    }
    
    private func sendToAnalyticsService(_ data: Data) {
        guard let url = URL(string: "\(Config.API.baseURL)/api/v1/analytics") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("StreamyyyApp/\(Config.App.version)", forHTTPHeaderField: "User-Agent")
        
        // TODO: Fix concurrency issue with ClerkManager
        // if let token = ClerkManager.shared.user?.id {
        //     request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // }
        
        request.httpBody = data
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Analytics upload failed: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    #if DEBUG
                    print("📊 Analytics events uploaded successfully")
                    #endif
                } else {
                    print("Analytics upload failed with status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    // MARK: - Privacy Controls
    func enableAnalytics() {
        isEnabled = true
        UserDefaults.standard.set(true, forKey: "analytics_enabled")
        
        track(name: "analytics_enabled")
    }
    
    func disableAnalytics() {
        track(name: "analytics_disabled")
        flushEvents()
        
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "analytics_enabled")
        eventQueue.removeAll()
    }
    
    func clearAnalyticsData() {
        eventQueue.removeAll()
        
        // Clear any cached analytics data
        let cacheKey = "analytics_cache"
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}

// MARK: - Analytics Event Model
struct AnalyticsEvent: Codable {
    let name: String
    let properties: [String: AnyCodable]
    var timestamp: Date?
    var sessionId: String?
    var userId: String?
    let isCritical: Bool
    
    init(name: String, properties: [String: Any] = [:], isCritical: Bool = false) {
        self.name = name
        self.properties = properties.mapValues { AnyCodable($0) }
        self.isCritical = isCritical
    }
}

// MARK: - AnyCodable Helper
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode value"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode(String(describing: value))
        }
    }
}

// MARK: - Performance Tracker
class PerformanceTracker {
    private var startTimes: [String: Date] = [:]
    
    func startTracking(_ name: String) {
        startTimes[name] = Date()
    }
    
    func endTracking(_ name: String, context: String = "") {
        guard let startTime = startTimes[name] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        startTimes.removeValue(forKey: name)
        
        AnalyticsManager.shared.trackPerformanceMetric(
            name: name,
            duration: duration,
            context: context
        )
    }
    
    func trackBlock<T>(_ name: String, context: String = "", block: () throws -> T) rethrows -> T {
        startTracking(name)
        defer { endTracking(name, context: context) }
        return try block()
    }
}

// MARK: - Global Performance Tracker
let performanceTracker = PerformanceTracker()

// MARK: - Analytics Extensions
extension AnalyticsManager {
    // MARK: - A/B Testing Support
    func trackExperiment(name: String, variant: String) {
        track(name: "experiment_viewed", properties: [
            "experiment_name": name,
            "variant": variant
        ])
    }
    
    func trackExperimentConversion(name: String, variant: String, goal: String) {
        track(name: "experiment_conversion", properties: [
            "experiment_name": name,
            "variant": variant,
            "goal": goal
        ])
    }
    
    // MARK: - Funnel Tracking
    func trackFunnelStep(funnel: String, step: String, properties: [String: Any] = [:]) {
        var funnelProperties = properties
        funnelProperties["funnel_name"] = funnel
        funnelProperties["step_name"] = step
        
        track(name: "funnel_step", properties: funnelProperties)
    }
    
    // MARK: - Retention Tracking
    func trackRetentionEvent(day: Int) {
        track(name: "retention_day_\(day)")
    }
    
    // MARK: - Feature Usage
    func trackFeatureUsed(feature: String, context: String = "") {
        track(name: "feature_used", properties: [
            "feature_name": feature,
            "context": context
        ])
    }
}