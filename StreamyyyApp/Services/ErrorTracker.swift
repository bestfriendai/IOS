//
//  ErrorTracker.swift
//  StreamyyyApp
//
//  Comprehensive error tracking and crash reporting system
//

import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - Error Tracker
class ErrorTracker: ObservableObject {
    static let shared = ErrorTracker()
    
    // MARK: - Published Properties
    @Published var errorReports: [ErrorReport] = []
    @Published var crashReports: [CrashReport] = []
    @Published var errorSummary: ErrorSummary = ErrorSummary()
    @Published var isTrackingEnabled: Bool = true
    @Published var errorTrends: [ErrorTrend] = []
    @Published var frequentErrors: [FrequentError] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var analyticsManager = AnalyticsManager.shared
    private var crashHandler: CrashHandler?
    private let logger = Logger(subsystem: "com.streamyyy.app", category: "ErrorTracking")
    
    // MARK: - Error Storage
    private let errorQueue = DispatchQueue(label: "ErrorTracker", qos: .utility)
    private var pendingReports: [ErrorReport] = []
    private var uploadTimer: Timer?
    
    // MARK: - Configuration
    private let maxStoredErrors = 1000
    private let uploadInterval: TimeInterval = 60.0 // 1 minute
    private let errorGroupingWindow: TimeInterval = 300.0 // 5 minutes
    
    // MARK: - Initialization
    private init() {
        setupErrorTracking()
        setupCrashHandler()
        setupPeriodicUpload()
        loadStoredErrors()
    }
    
    // MARK: - Setup
    private func setupErrorTracking() {
        // Set up global error handler
        NSSetUncaughtExceptionHandler { exception in
            ErrorTracker.shared.trackCrash(exception: exception)
        }
        
        // Set up signal handlers for crashes
        signal(SIGABRT) { signal in
            ErrorTracker.shared.trackCrashSignal(signal: signal)
        }
        
        signal(SIGILL) { signal in
            ErrorTracker.shared.trackCrashSignal(signal: signal)
        }
        
        signal(SIGSEGV) { signal in
            ErrorTracker.shared.trackCrashSignal(signal: signal)
        }
        
        signal(SIGFPE) { signal in
            ErrorTracker.shared.trackCrashSignal(signal: signal)
        }
        
        signal(SIGBUS) { signal in
            ErrorTracker.shared.trackCrashSignal(signal: signal)
        }
    }
    
    private func setupCrashHandler() {
        crashHandler = CrashHandler()
        crashHandler?.delegate = self
    }
    
    private func setupPeriodicUpload() {
        uploadTimer = Timer.scheduledTimer(withTimeInterval: uploadInterval, repeats: true) { [weak self] _ in
            self?.uploadPendingReports()
        }
    }
    
    private func loadStoredErrors() {
        errorQueue.async { [weak self] in
            self?.loadErrorsFromStorage()
        }
    }
    
    // MARK: - Error Tracking
    func trackError(_ error: Error, context: String = "", userInfo: [String: Any] = [:], isFatal: Bool = false) {
        guard isTrackingEnabled else { return }
        
        let errorReport = createErrorReport(
            error: error,
            context: context,
            userInfo: userInfo,
            isFatal: isFatal
        )
        
        errorQueue.async { [weak self] in
            self?.processErrorReport(errorReport)
        }
        
        // Log error
        logger.error("Error tracked: \(error.localizedDescription) in context: \(context)")
        
        // Track in analytics
        analyticsManager.trackError(error: error, context: context)
    }
    
    func trackCustomError(title: String, message: String, context: String = "", severity: ErrorSeverity = .medium, userInfo: [String: Any] = [:]) {
        guard isTrackingEnabled else { return }
        
        let customError = CustomError(title: title, message: message, severity: severity)
        trackError(customError, context: context, userInfo: userInfo)
    }
    
    func trackCrash(exception: NSException) {
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            type: .exception,
            exception: exception,
            signal: nil,
            stackTrace: exception.callStackSymbols.joined(separator: "\n"),
            deviceInfo: getCurrentDeviceInfo(),
            appState: getCurrentAppState(),
            memoryInfo: getCurrentMemoryInfo(),
            threadInfo: getCurrentThreadInfo()
        )
        
        saveCrashReport(crashReport)
        
        // Track crash in analytics
        analyticsManager.trackCrash(
            error: exception.reason ?? "Unknown exception",
            stackTrace: crashReport.stackTrace,
            context: ["type": "exception", "name": exception.name.rawValue]
        )
    }
    
    func trackCrashSignal(signal: Int32) {
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            type: .signal,
            exception: nil,
            signal: signal,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            deviceInfo: getCurrentDeviceInfo(),
            appState: getCurrentAppState(),
            memoryInfo: getCurrentMemoryInfo(),
            threadInfo: getCurrentThreadInfo()
        )
        
        saveCrashReport(crashReport)
        
        // Track crash in analytics
        analyticsManager.trackCrash(
            error: "Signal \(signal) received",
            stackTrace: crashReport.stackTrace,
            context: ["type": "signal", "signal": String(signal)]
        )
    }
    
    func trackRecoveredError(_ error: Error, recoveryMethod: String, context: String = "") {
        guard isTrackingEnabled else { return }
        
        let errorReport = createErrorReport(
            error: error,
            context: context,
            userInfo: ["recovery_method": recoveryMethod],
            isFatal: false
        )
        
        errorReport.isRecovered = true
        errorReport.recoveryMethod = recoveryMethod
        
        errorQueue.async { [weak self] in
            self?.processErrorReport(errorReport)
        }
        
        // Track recovery in analytics
        analyticsManager.trackErrorRecovery(
            error: error.localizedDescription,
            recoveryMethod: recoveryMethod,
            success: true
        )
    }
    
    // MARK: - Error Processing
    private func createErrorReport(error: Error, context: String, userInfo: [String: Any], isFatal: Bool) -> ErrorReport {
        let nsError = error as NSError
        
        return ErrorReport(
            id: UUID(),
            error: error.localizedDescription,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            context: createContextDictionary(context: context, userInfo: userInfo),
            userId: getCurrentUserId(),
            sessionId: getCurrentSessionId(),
            deviceInfo: getCurrentDeviceInfo(),
            timestamp: Date(),
            isCrash: isFatal,
            isRecovered: false,
            errorCode: nsError.code,
            errorDomain: nsError.domain,
            severity: determineSeverity(error: error, isFatal: isFatal),
            category: categorizeError(error: error),
            breadcrumbs: getBreadcrumbs(),
            environment: getCurrentEnvironment()
        )
    }
    
    private func processErrorReport(_ report: ErrorReport) {
        // Add to error reports
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.errorReports.append(report)
            
            // Keep only the most recent errors
            if self.errorReports.count > self.maxStoredErrors {
                self.errorReports.removeFirst()
            }
            
            // Update error summary
            self.updateErrorSummary()
            
            // Check for frequent errors
            self.updateFrequentErrors()
            
            // Update error trends
            self.updateErrorTrends()
        }
        
        // Add to pending reports for upload
        pendingReports.append(report)
        
        // Save to storage
        saveErrorReport(report)
        
        // Send notification
        NotificationCenter.default.post(
            name: .errorTracked,
            object: self,
            userInfo: ["errorReport": report]
        )
        
        // Check if immediate upload is needed for critical errors
        if report.severity == .critical || report.isCrash {
            uploadPendingReports()
        }
    }
    
    // MARK: - Error Analysis
    private func updateErrorSummary() {
        let now = Date()
        let dayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        
        let recentErrors = errorReports.filter { $0.timestamp >= dayAgo }
        let weeklyErrors = errorReports.filter { $0.timestamp >= weekAgo }
        
        errorSummary = ErrorSummary(
            totalErrors: errorReports.count,
            todayErrors: recentErrors.count,
            weeklyErrors: weeklyErrors.count,
            criticalErrors: errorReports.filter { $0.severity == .critical }.count,
            crashCount: errorReports.filter { $0.isCrash }.count,
            recoveredErrors: errorReports.filter { $0.isRecovered }.count,
            lastErrorTime: errorReports.last?.timestamp,
            mostFrequentError: getMostFrequentError(),
            errorRate: calculateErrorRate()
        )
    }
    
    private func updateFrequentErrors() {
        let errorGroups = Dictionary(grouping: errorReports) { report in
            "\(report.errorDomain):\(report.errorCode)"
        }
        
        frequentErrors = errorGroups.compactMap { (key, reports) in
            guard reports.count >= 3 else { return nil }
            
            let recentReports = reports.filter { report in
                Date().timeIntervalSince(report.timestamp) < 86400 // Last 24 hours
            }
            
            guard !recentReports.isEmpty else { return nil }
            
            return FrequentError(
                id: UUID(),
                errorSignature: key,
                occurrenceCount: reports.count,
                recentCount: recentReports.count,
                firstOccurrence: reports.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date(),
                lastOccurrence: reports.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date(),
                averageFrequency: calculateAverageFrequency(reports: reports),
                severity: reports.first?.severity ?? .medium,
                description: reports.first?.error ?? "Unknown error",
                possibleCause: analyzePossibleCause(reports: reports)
            )
        }.sorted { $0.recentCount > $1.recentCount }
    }
    
    private func updateErrorTrends() {
        let calendar = Calendar.current
        let now = Date()
        
        // Group errors by hour for the last 24 hours
        var trends: [ErrorTrend] = []
        
        for i in 0..<24 {
            guard let hourStart = calendar.date(byAdding: .hour, value: -i, to: now),
                  let hourEnd = calendar.date(byAdding: .hour, value: -i + 1, to: now) else {
                continue
            }
            
            let errorsInHour = errorReports.filter { report in
                report.timestamp >= hourStart && report.timestamp < hourEnd
            }
            
            trends.append(ErrorTrend(
                timestamp: hourStart,
                errorCount: errorsInHour.count,
                crashCount: errorsInHour.filter { $0.isCrash }.count,
                criticalCount: errorsInHour.filter { $0.severity == .critical }.count,
                period: .hourly
            ))
        }
        
        errorTrends = trends.reversed()
    }
    
    // MARK: - Helper Methods
    private func createContextDictionary(context: String, userInfo: [String: Any]) -> [String: String] {
        var contextDict: [String: String] = [
            "context": context,
            "app_version": Config.App.version,
            "build_number": Config.App.build,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Add user info
        for (key, value) in userInfo {
            contextDict[key] = String(describing: value)
        }
        
        return contextDict
    }
    
    private func getCurrentUserId() -> String? {
        // Get current user ID from authentication system
        return "user_12345" // Placeholder
    }
    
    private func getCurrentSessionId() -> String {
        return UUID().uuidString // Placeholder - should use actual session ID
    }
    
    private func getCurrentDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Config.App.version,
            buildNumber: Config.App.build,
            memoryTotal: Double(ProcessInfo.processInfo.physicalMemory),
            storageTotal: getTotalStorageSpace(),
            thermalState: ProcessInfo.processInfo.thermalState.description,
            batteryLevel: UIDevice.current.batteryLevel >= 0 ? Double(UIDevice.current.batteryLevel) : nil,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
    
    private func getCurrentAppState() -> AppState {
        return AppState(
            applicationState: UIApplication.shared.applicationState.description,
            backgroundTimeRemaining: UIApplication.shared.backgroundTimeRemaining,
            isIdleTimerDisabled: UIApplication.shared.isIdleTimerDisabled,
            activeScenes: UIApplication.shared.connectedScenes.count,
            memoryWarnings: 0 // Placeholder
        )
    }
    
    private func getCurrentMemoryInfo() -> MemoryInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        let usedMemory = kerr == KERN_SUCCESS ? Double(info.resident_size) : 0
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        return MemoryInfo(
            usedMemory: usedMemory,
            totalMemory: totalMemory,
            availableMemory: totalMemory - usedMemory,
            memoryPressure: usedMemory / totalMemory,
            pageFaults: 0 // Placeholder
        )
    }
    
    private func getCurrentThreadInfo() -> ThreadInfo {
        return ThreadInfo(
            activeThreads: Thread.isMainThread ? 1 : 0, // Simplified
            mainThread: Thread.isMainThread,
            threadId: Thread.current.description,
            queueLabel: DispatchQueue.currentQueueLabel ?? "unknown"
        )
    }
    
    private func getCurrentEnvironment() -> ErrorEnvironment {
        return ErrorEnvironment(
            configuration: Config.isProduction ? "production" : "development",
            network: getNetworkType(),
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            accessibility: UIAccessibility.isVoiceOverRunning
        )
    }
    
    private func determineSeverity(error: Error, isFatal: Bool) -> ErrorSeverity {
        if isFatal {
            return .critical
        }
        
        let nsError = error as NSError
        
        // Determine severity based on error domain and code
        switch nsError.domain {
        case NSURLErrorDomain:
            return .low
        case NSCocoaErrorDomain:
            return nsError.code < 1000 ? .medium : .low
        default:
            return .medium
        }
    }
    
    private func categorizeError(error: Error) -> ErrorCategory {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSURLErrorDomain:
            return .network
        case NSCocoaErrorDomain:
            return .system
        case "com.streamyyy.app":
            return .application
        default:
            return .unknown
        }
    }
    
    private func getBreadcrumbs() -> [String] {
        // Return recent app actions/navigation
        return ["app_launched", "stream_loaded", "user_action"] // Placeholder
    }
    
    private func getMostFrequentError() -> String? {
        let errorGroups = Dictionary(grouping: errorReports) { $0.error }
        return errorGroups.max(by: { $0.value.count < $1.value.count })?.key
    }
    
    private func calculateErrorRate() -> Double {
        let dayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let recentErrors = errorReports.filter { $0.timestamp >= dayAgo }
        
        // Calculate errors per hour
        return Double(recentErrors.count) / 24.0
    }
    
    private func calculateAverageFrequency(reports: [ErrorReport]) -> TimeInterval {
        guard reports.count > 1 else { return 0 }
        
        let sortedReports = reports.sorted { $0.timestamp < $1.timestamp }
        var totalInterval: TimeInterval = 0
        
        for i in 1..<sortedReports.count {
            totalInterval += sortedReports[i].timestamp.timeIntervalSince(sortedReports[i-1].timestamp)
        }
        
        return totalInterval / Double(sortedReports.count - 1)
    }
    
    private func analyzePossibleCause(reports: [ErrorReport]) -> String? {
        // Analyze patterns in error reports to suggest possible causes
        let contexts = reports.compactMap { $0.context["context"] }
        let mostCommonContext = Dictionary(grouping: contexts) { $0 }
            .max(by: { $0.value.count < $1.value.count })?.key
        
        if let context = mostCommonContext {
            return "Frequently occurs in context: \(context)"
        }
        
        return nil
    }
    
    private func getTotalStorageSpace() -> Double {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let space = systemAttributes[.systemSize] as? NSNumber {
                return space.doubleValue
            }
        } catch {
            // Ignore error
        }
        return 0
    }
    
    private func getNetworkType() -> String {
        // Simplified network type detection
        return "WiFi" // Placeholder
    }
    
    // MARK: - Storage Operations
    private func saveErrorReport(_ report: ErrorReport) {
        // Save error report to local storage
        // Implementation would depend on chosen storage method (Core Data, SQLite, files, etc.)
    }
    
    private func saveCrashReport(_ report: CrashReport) {
        // Save crash report to local storage with high priority
        // These should be persisted even if the app terminates
        DispatchQueue.main.async { [weak self] in
            self?.crashReports.append(report)
        }
    }
    
    private func loadErrorsFromStorage() {
        // Load previously stored error reports
        // Implementation would depend on chosen storage method
    }
    
    // MARK: - Upload Operations
    private func uploadPendingReports() {
        guard !pendingReports.isEmpty else { return }
        
        let reportsToUpload = pendingReports
        pendingReports.removeAll()
        
        Task {
            await uploadErrorReports(reportsToUpload)
        }
    }
    
    private func uploadErrorReports(_ reports: [ErrorReport]) async {
        guard let url = URL(string: "\(Config.API.baseURL)/api/v1/errors") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("StreamyyyApp/\(Config.App.version)", forHTTPHeaderField: "User-Agent")
        
        do {
            let jsonData = try JSONEncoder().encode(reports)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                logger.info("Successfully uploaded \(reports.count) error reports")
            } else {
                // Re-queue reports for retry
                pendingReports.append(contentsOf: reports)
                logger.error("Failed to upload error reports")
            }
        } catch {
            // Re-queue reports for retry
            pendingReports.append(contentsOf: reports)
            logger.error("Error uploading reports: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public API
    func enableErrorTracking() {
        isTrackingEnabled = true
        analyticsManager.trackFeatureUsed(feature: "error_tracking_enabled")
    }
    
    func disableErrorTracking() {
        isTrackingEnabled = false
        analyticsManager.trackFeatureUsed(feature: "error_tracking_disabled")
    }
    
    func clearErrorHistory() {
        errorQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.errorReports.removeAll()
                self?.crashReports.removeAll()
                self?.updateErrorSummary()
            }
        }
    }
    
    func getErrorReport(id: UUID) -> ErrorReport? {
        return errorReports.first { $0.id == id }
    }
    
    func getCrashReport(id: UUID) -> CrashReport? {
        return crashReports.first { $0.id == id }
    }
    
    func getTotalErrors() -> Int {
        return errorReports.count
    }
    
    func getTotalCrashes() -> Int {
        return crashReports.count
    }
    
    func exportErrorData() -> Data? {
        let exportData = ErrorExportData(
            errorReports: errorReports,
            crashReports: crashReports,
            errorSummary: errorSummary,
            exportDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(exportData)
        } catch {
            logger.error("Failed to export error data: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - CrashHandlerDelegate
extension ErrorTracker: CrashHandlerDelegate {
    func crashHandler(_ handler: CrashHandler, didDetectCrash crashInfo: CrashInfo) {
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            type: crashInfo.type,
            exception: crashInfo.exception,
            signal: crashInfo.signal,
            stackTrace: crashInfo.stackTrace,
            deviceInfo: getCurrentDeviceInfo(),
            appState: getCurrentAppState(),
            memoryInfo: getCurrentMemoryInfo(),
            threadInfo: getCurrentThreadInfo()
        )
        
        saveCrashReport(crashReport)
    }
}

// MARK: - Custom Error
struct CustomError: LocalizedError {
    let title: String
    let message: String
    let severity: ErrorSeverity
    
    var errorDescription: String? {
        return title
    }
    
    var failureReason: String? {
        return message
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let errorTracked = Notification.Name("errorTracked")
    static let crashDetected = Notification.Name("crashDetected")
}

// MARK: - Extensions
extension UIApplicationState {
    var description: String {
        switch self {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }
}

extension ProcessInfo.ThermalState {
    var description: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}

extension DispatchQueue {
    static var currentQueueLabel: String? {
        return String(cString: __dispatch_queue_get_label(nil), encoding: .utf8)
    }
}