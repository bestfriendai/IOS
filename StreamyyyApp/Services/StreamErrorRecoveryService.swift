//
//  StreamErrorRecoveryService.swift
//  StreamyyyApp
//
//  Comprehensive error handling and recovery service for stream data operations
//  Created by Claude Code on 2025-07-10
//

import Foundation
import Combine
import Network
import SwiftUI

// MARK: - Stream Error Recovery Service

/// Comprehensive error handling and recovery service that provides intelligent error recovery,
/// fallback mechanisms, and resilient data operations across all streaming platforms
@MainActor
public class StreamErrorRecoveryService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var networkStatus: NetworkStatus = .unknown
    @Published public private(set) var serviceHealth: ServiceHealth = ServiceHealth()
    @Published public private(set) var activeErrors: [ActiveError] = []
    @Published public private(set) var recoveryAttempts: [RecoveryAttempt] = []
    @Published public private(set) var systemAlerts: [SystemAlert] = []
    
    // MARK: - Services and Dependencies
    
    private let networkMonitor: NWPathMonitor
    private let errorLogger: ErrorLogger
    private let retryManager: RetryManager
    private let fallbackManager: FallbackManager
    private let alertManager: AlertManager
    
    // MARK: - Configuration
    
    public struct Configuration {
        public let maxRetryAttempts: Int
        public let baseRetryDelay: TimeInterval
        public let exponentialBackoffMultiplier: Double
        public let maxRetryDelay: TimeInterval
        public let networkTimeoutDuration: TimeInterval
        public let enableAutoRecovery: Bool
        public let enableOfflineMode: Bool
        public let errorReportingEnabled: Bool
        
        public init(
            maxRetryAttempts: Int = 3,
            baseRetryDelay: TimeInterval = 1.0,
            exponentialBackoffMultiplier: Double = 2.0,
            maxRetryDelay: TimeInterval = 30.0,
            networkTimeoutDuration: TimeInterval = 10.0,
            enableAutoRecovery: Bool = true,
            enableOfflineMode: Bool = true,
            errorReportingEnabled: Bool = true
        ) {
            self.maxRetryAttempts = maxRetryAttempts
            self.baseRetryDelay = baseRetryDelay
            self.exponentialBackoffMultiplier = exponentialBackoffMultiplier
            self.maxRetryDelay = maxRetryDelay
            self.networkTimeoutDuration = networkTimeoutDuration
            self.enableAutoRecovery = enableAutoRecovery
            self.enableOfflineMode = enableOfflineMode
            self.errorReportingEnabled = errorReportingEnabled
        }
    }
    
    private let configuration: Configuration
    
    // MARK: - State Management
    
    private var cancellables = Set<AnyCancellable>()
    private let errorQueue = DispatchQueue(label: "error.recovery", qos: .utility)
    private var platformHealthStatus: [Platform: PlatformHealth] = [:]
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.networkMonitor = NWPathMonitor()
        self.errorLogger = ErrorLogger(enabled: configuration.errorReportingEnabled)
        self.retryManager = RetryManager(configuration: configuration)
        self.fallbackManager = FallbackManager(configuration: configuration)
        self.alertManager = AlertManager()
        
        setupNetworkMonitoring()
        setupHealthMonitoring()
        initializePlatformHealth()
    }
    
    // MARK: - Public Error Handling Methods
    
    /// Handle errors with automatic recovery and fallback mechanisms
    public func handleError<T>(
        _ error: Error,
        context: ErrorContext,
        fallbackOperation: (() async throws -> T)? = nil
    ) async throws -> T? {
        
        // Log the error
        await errorLogger.logError(error, context: context)
        
        // Determine error type and severity
        let errorInfo = analyzeError(error, context: context)
        
        // Update service health
        updateServiceHealth(for: errorInfo)
        
        // Add to active errors
        let activeError = ActiveError(
            id: UUID(),
            error: error,
            context: context,
            severity: errorInfo.severity,
            timestamp: Date(),
            recoveryAttempts: 0
        )
        activeErrors.append(activeError)
        
        // Attempt recovery based on error type
        if configuration.enableAutoRecovery {
            if let result = try await attemptRecovery(for: activeError, fallbackOperation: fallbackOperation) {
                markErrorAsRecovered(activeError.id)
                return result
            }
        }
        
        // If recovery failed, create system alert if needed
        if errorInfo.severity.requiresUserAttention {
            createSystemAlert(for: errorInfo, context: context)
        }
        
        throw error
    }
    
    /// Retry a failed operation with exponential backoff
    public func retryOperation<T>(
        _ operation: @escaping () async throws -> T,
        context: ErrorContext,
        maxAttempts: Int? = nil
    ) async throws -> T {
        
        let attempts = maxAttempts ?? configuration.maxRetryAttempts
        
        for attempt in 1...attempts {
            do {
                let result = try await operation()
                
                // Log successful retry if it took multiple attempts
                if attempt > 1 {
                    let recoveryAttempt = RecoveryAttempt(
                        id: UUID(),
                        context: context,
                        attemptNumber: attempt,
                        successful: true,
                        timestamp: Date()
                    )
                    recoveryAttempts.append(recoveryAttempt)
                }
                
                return result
            } catch {
                // Log failed attempt
                let recoveryAttempt = RecoveryAttempt(
                    id: UUID(),
                    context: context,
                    attemptNumber: attempt,
                    successful: false,
                    timestamp: Date(),
                    error: error
                )
                recoveryAttempts.append(recoveryAttempt)
                
                // If this is not the last attempt, wait before retrying
                if attempt < attempts {
                    let delay = retryManager.calculateDelay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))\n                }\n            }\n        }\n        \n        // All attempts failed\n        throw StreamErrorRecoveryError.allRetryAttemptsFailed(attempts)\n    }\n    \n    /// Execute operation with automatic error handling and fallback\n    public func executeWithRecovery<T>(\n        _ operation: @escaping () async throws -> T,\n        context: ErrorContext,\n        fallback: (() async throws -> T)? = nil\n    ) async -> Result<T, Error> {\n        \n        do {\n            let result = try await operation()\n            return .success(result)\n        } catch {\n            do {\n                if let recovered: T = try await handleError(error, context: context, fallbackOperation: fallback) {\n                    return .success(recovered)\n                } else if let fallback = fallback {\n                    let fallbackResult = try await fallback()\n                    return .success(fallbackResult)\n                } else {\n                    return .failure(error)\n                }\n            } catch {\n                return .failure(error)\n            }\n        }\n    }\n    \n    /// Get cached data as fallback for failed operations\n    public func getCachedFallback<T>(\n        for operation: String,\n        type: T.Type\n    ) -> T? {\n        return fallbackManager.getCachedData(for: operation, type: type)\n    }\n    \n    /// Check if a platform is currently healthy\n    public func isPlatformHealthy(_ platform: Platform) -> Bool {\n        return platformHealthStatus[platform]?.isHealthy ?? false\n    }\n    \n    /// Get platform health information\n    public func getPlatformHealth(_ platform: Platform) -> PlatformHealth? {\n        return platformHealthStatus[platform]\n    }\n    \n    /// Force refresh platform health status\n    public func refreshPlatformHealth() async {\n        for platform in Platform.allCases {\n            await checkPlatformHealth(platform)\n        }\n    }\n    \n    // MARK: - Error Analysis\n    \n    private func analyzeError(_ error: Error, context: ErrorContext) -> ErrorInfo {\n        var severity: ErrorSeverity = .medium\n        var category: ErrorCategory = .unknown\n        var isRecoverable = true\n        var suggestedAction: RecoveryAction = .retry\n        \n        // Network errors\n        if let urlError = error as? URLError {\n            category = .network\n            switch urlError.code {\n            case .notConnectedToInternet, .networkConnectionLost:\n                severity = .high\n                suggestedAction = .switchToOfflineMode\n            case .timedOut:\n                severity = .medium\n                suggestedAction = .retry\n            case .badURL, .unsupportedURL:\n                severity = .low\n                isRecoverable = false\n                suggestedAction = .showError\n            default:\n                severity = .medium\n                suggestedAction = .retry\n            }\n        }\n        \n        // Platform-specific errors\n        else if let twitchError = error as? TwitchAPIError {\n            category = .platformAPI\n            switch twitchError {\n            case .rateLimitExceeded:\n                severity = .medium\n                suggestedAction = .waitAndRetry\n            case .authenticationFailed:\n                severity = .high\n                suggestedAction = .reauthenticate\n            case .invalidResponse:\n                severity = .medium\n                suggestedAction = .retry\n            default:\n                severity = .medium\n                suggestedAction = .retry\n            }\n        }\n        \n        // YouTube API errors\n        else if let youtubeError = error as? YouTubeAPIError {\n            category = .platformAPI\n            switch youtubeError {\n            case .quotaExceeded:\n                severity = .high\n                suggestedAction = .switchPlatform\n            case .rateLimited:\n                severity = .medium\n                suggestedAction = .waitAndRetry\n            case .unauthorized:\n                severity = .high\n                suggestedAction = .reauthenticate\n            default:\n                severity = .medium\n                suggestedAction = .retry\n            }\n        }\n        \n        // Cache errors\n        else if error is StreamCacheError {\n            category = .cache\n            severity = .low\n            suggestedAction = .clearCache\n        }\n        \n        // Discovery errors\n        else if let discoveryError = error as? DiscoveryError {\n            category = .discovery\n            switch discoveryError {\n            case .networkUnavailable:\n                severity = .high\n                suggestedAction = .switchToOfflineMode\n            case .quotaExceeded:\n                severity = .medium\n                suggestedAction = .switchPlatform\n            default:\n                severity = .medium\n                suggestedAction = .retry\n            }\n        }\n        \n        return ErrorInfo(\n            error: error,\n            severity: severity,\n            category: category,\n            isRecoverable: isRecoverable,\n            suggestedAction: suggestedAction,\n            context: context\n        )\n    }\n    \n    // MARK: - Recovery Mechanisms\n    \n    private func attemptRecovery<T>(\n        for activeError: ActiveError,\n        fallbackOperation: (() async throws -> T)? = nil\n    ) async throws -> T? {\n        \n        let errorInfo = analyzeError(activeError.error, context: activeError.context)\n        \n        switch errorInfo.suggestedAction {\n        case .retry:\n            return try await executeRetry(for: activeError, fallbackOperation: fallbackOperation)\n            \n        case .waitAndRetry:\n            let delay = retryManager.calculateRateLimitDelay(for: activeError.context.platform)\n            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))\n            return try await executeRetry(for: activeError, fallbackOperation: fallbackOperation)\n            \n        case .switchPlatform:\n            return try await executePlatformFallback(for: activeError, fallbackOperation: fallbackOperation)\n            \n        case .switchToOfflineMode:\n            return try await executeOfflineFallback(for: activeError, fallbackOperation: fallbackOperation)\n            \n        case .clearCache:\n            // This would need access to the cache manager\n            return try await executeRetry(for: activeError, fallbackOperation: fallbackOperation)\n            \n        case .reauthenticate:\n            // This would trigger reauthentication flow\n            return nil\n            \n        case .showError:\n            return nil\n        }\n    }\n    \n    private func executeRetry<T>(\n        for activeError: ActiveError,\n        fallbackOperation: (() async throws -> T)? = nil\n    ) async throws -> T? {\n        \n        guard activeError.recoveryAttempts < configuration.maxRetryAttempts else {\n            return nil\n        }\n        \n        // Update recovery attempts\n        if let index = activeErrors.firstIndex(where: { $0.id == activeError.id }) {\n            activeErrors[index].recoveryAttempts += 1\n        }\n        \n        // Execute fallback operation if provided\n        if let fallbackOperation = fallbackOperation {\n            return try await fallbackOperation()\n        }\n        \n        return nil\n    }\n    \n    private func executePlatformFallback<T>(\n        for activeError: ActiveError,\n        fallbackOperation: (() async throws -> T)? = nil\n    ) async throws -> T? {\n        \n        // Find alternative healthy platforms\n        let healthyPlatforms = platformHealthStatus\n            .filter { $0.value.isHealthy && $0.key != activeError.context.platform }\n            .map { $0.key }\n        \n        if !healthyPlatforms.isEmpty {\n            // Try to execute operation on alternative platform\n            if let fallbackOperation = fallbackOperation {\n                return try await fallbackOperation()\n            }\n        }\n        \n        return nil\n    }\n    \n    private func executeOfflineFallback<T>(\n        for activeError: ActiveError,\n        fallbackOperation: (() async throws -> T)? = nil\n    ) async throws -> T? {\n        \n        guard configuration.enableOfflineMode else { return nil }\n        \n        // Try to get cached data\n        let cachedData: T? = fallbackManager.getCachedData(\n            for: activeError.context.operation,\n            type: T.self\n        )\n        \n        if let cached = cachedData {\n            return cached\n        }\n        \n        // Execute fallback operation if provided\n        if let fallbackOperation = fallbackOperation {\n            return try await fallbackOperation()\n        }\n        \n        return nil\n    }\n    \n    // MARK: - Health Monitoring\n    \n    private func setupHealthMonitoring() {\n        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in\n            Task {\n                await self.updateServiceHealth()\n                await self.refreshPlatformHealth()\n                await self.cleanupOldErrors()\n            }\n        }\n    }\n    \n    private func initializePlatformHealth() {\n        for platform in Platform.allCases {\n            platformHealthStatus[platform] = PlatformHealth(\n                platform: platform,\n                isHealthy: true,\n                lastChecked: Date(),\n                errorCount: 0,\n                averageResponseTime: 0\n            )\n        }\n    }\n    \n    private func checkPlatformHealth(_ platform: Platform) async {\n        let startTime = Date()\n        var isHealthy = true\n        var errorCount = 0\n        \n        // Simple health check based on recent errors\n        let recentErrors = activeErrors.filter {\n            $0.context.platform == platform &&\n            Date().timeIntervalSince($0.timestamp) < 300 // Last 5 minutes\n        }\n        \n        errorCount = recentErrors.count\n        isHealthy = errorCount < 5 // Consider unhealthy if more than 5 errors in 5 minutes\n        \n        let responseTime = Date().timeIntervalSince(startTime)\n        \n        platformHealthStatus[platform] = PlatformHealth(\n            platform: platform,\n            isHealthy: isHealthy,\n            lastChecked: Date(),\n            errorCount: errorCount,\n            averageResponseTime: responseTime\n        )\n    }\n    \n    private func updateServiceHealth() async {\n        let totalErrors = activeErrors.count\n        let criticalErrors = activeErrors.filter { $0.severity == .critical }.count\n        let highErrors = activeErrors.filter { $0.severity == .high }.count\n        \n        let healthScore = calculateHealthScore(total: totalErrors, critical: criticalErrors, high: highErrors)\n        \n        serviceHealth = ServiceHealth(\n            overallHealth: healthScore,\n            activeErrorCount: totalErrors,\n            criticalErrorCount: criticalErrors,\n            networkStatus: networkStatus,\n            lastUpdated: Date()\n        )\n    }\n    \n    private func calculateHealthScore(total: Int, critical: Int, high: Int) -> Double {\n        if critical > 0 {\n            return 0.0 // Critical errors make system unhealthy\n        } else if high > 3 {\n            return 0.3 // Multiple high severity errors\n        } else if total > 10 {\n            return 0.5 // Many errors overall\n        } else if total > 5 {\n            return 0.7 // Some errors\n        } else {\n            return 1.0 // Healthy\n        }\n    }\n    \n    // MARK: - Network Monitoring\n    \n    private func setupNetworkMonitoring() {\n        networkMonitor.pathUpdateHandler = { [weak self] path in\n            DispatchQueue.main.async {\n                self?.updateNetworkStatus(path)\n            }\n        }\n        \n        let queue = DispatchQueue(label: "NetworkMonitor")\n        networkMonitor.start(queue: queue)\n    }\n    \n    private func updateNetworkStatus(_ path: NWPath) {\n        switch path.status {\n        case .satisfied:\n            networkStatus = .connected(path.usesInterfaceType(.wifi) ? .wifi : .cellular)\n        case .unsatisfied:\n            networkStatus = .disconnected\n        case .requiresConnection:\n            networkStatus = .connecting\n        @unknown default:\n            networkStatus = .unknown\n        }\n    }\n    \n    // MARK: - Alert Management\n    \n    private func createSystemAlert(for errorInfo: ErrorInfo, context: ErrorContext) {\n        let alert = SystemAlert(\n            id: UUID(),\n            title: generateAlertTitle(for: errorInfo),\n            message: generateAlertMessage(for: errorInfo),\n            severity: errorInfo.severity,\n            timestamp: Date(),\n            actions: generateAlertActions(for: errorInfo)\n        )\n        \n        systemAlerts.append(alert)\n    }\n    \n    private func generateAlertTitle(for errorInfo: ErrorInfo) -> String {\n        switch errorInfo.category {\n        case .network:\n            return "Network Connection Issue"\n        case .platformAPI:\n            return "\\(errorInfo.context.platform?.displayName ?? "Platform") Service Issue"\n        case .cache:\n            return "Data Storage Issue"\n        case .discovery:\n            return "Content Discovery Issue"\n        case .authentication:\n            return "Authentication Required"\n        case .unknown:\n            return "Unexpected Error"\n        }\n    }\n    \n    private func generateAlertMessage(for errorInfo: ErrorInfo) -> String {\n        switch errorInfo.suggestedAction {\n        case .retry:\n            return "We're experiencing a temporary issue. The app will automatically retry."\n        case .waitAndRetry:\n            return "We're being rate limited. Waiting before retrying..."\n        case .switchPlatform:\n            return "This platform is currently unavailable. Trying alternative sources."\n        case .switchToOfflineMode:\n            return "No internet connection. Switching to offline mode with cached content."\n        case .clearCache:\n            return "There's an issue with stored data. Clearing cache may help."\n        case .reauthenticate:\n            return "Please sign in again to continue using this platform."\n        case .showError:\n            return "Unable to complete the requested action."\n        }\n    }\n    \n    private func generateAlertActions(for errorInfo: ErrorInfo) -> [AlertAction] {\n        switch errorInfo.suggestedAction {\n        case .retry, .waitAndRetry:\n            return [AlertAction(title: "OK", style: .default)]\n        case .switchPlatform:\n            return [\n                AlertAction(title: "Try Alternative", style: .default),\n                AlertAction(title: "Cancel", style: .cancel)\n            ]\n        case .switchToOfflineMode:\n            return [\n                AlertAction(title: "Use Offline Mode", style: .default),\n                AlertAction(title: "Retry Connection", style: .cancel)\n            ]\n        case .clearCache:\n            return [\n                AlertAction(title: "Clear Cache", style: .destructive),\n                AlertAction(title: "Cancel", style: .cancel)\n            ]\n        case .reauthenticate:\n            return [\n                AlertAction(title: "Sign In", style: .default),\n                AlertAction(title: "Skip", style: .cancel)\n            ]\n        case .showError:\n            return [AlertAction(title: "OK", style: .default)]\n        }\n    }\n    \n    // MARK: - Cleanup\n    \n    private func markErrorAsRecovered(_ errorId: UUID) {\n        activeErrors.removeAll { $0.id == errorId }\n    }\n    \n    private func cleanupOldErrors() async {\n        let cutoffTime = Date().addingTimeInterval(-3600) // 1 hour ago\n        \n        activeErrors.removeAll { $0.timestamp < cutoffTime }\n        recoveryAttempts.removeAll { $0.timestamp < cutoffTime }\n        systemAlerts.removeAll { $0.timestamp < cutoffTime }\n    }\n    \n    deinit {\n        networkMonitor.cancel()\n    }\n}\n\n// MARK: - Supporting Types\n\n/// Context information for errors\npublic struct ErrorContext {\n    public let operation: String\n    public let platform: Platform?\n    public let userInitiated: Bool\n    public let retryable: Bool\n    \n    public init(\n        operation: String,\n        platform: Platform? = nil,\n        userInitiated: Bool = true,\n        retryable: Bool = true\n    ) {\n        self.operation = operation\n        self.platform = platform\n        self.userInitiated = userInitiated\n        self.retryable = retryable\n    }\n}\n\n/// Error severity levels\npublic enum ErrorSeverity {\n    case low\n    case medium\n    case high\n    case critical\n    \n    public var requiresUserAttention: Bool {\n        switch self {\n        case .low, .medium:\n            return false\n        case .high, .critical:\n            return true\n        }\n    }\n    \n    public var color: Color {\n        switch self {\n        case .low: return .green\n        case .medium: return .yellow\n        case .high: return .orange\n        case .critical: return .red\n        }\n    }\n}\n\n/// Error categories\npublic enum ErrorCategory {\n    case network\n    case platformAPI\n    case cache\n    case discovery\n    case authentication\n    case unknown\n}\n\n/// Suggested recovery actions\npublic enum RecoveryAction {\n    case retry\n    case waitAndRetry\n    case switchPlatform\n    case switchToOfflineMode\n    case clearCache\n    case reauthenticate\n    case showError\n}\n\n/// Network status\npublic enum NetworkStatus {\n    case connected(ConnectionType)\n    case disconnected\n    case connecting\n    case unknown\n    \n    public enum ConnectionType {\n        case wifi\n        case cellular\n        case ethernet\n    }\n    \n    public var isConnected: Bool {\n        if case .connected = self {\n            return true\n        }\n        return false\n    }\n}\n\n/// Active error information\npublic struct ActiveError: Identifiable {\n    public let id: UUID\n    public let error: Error\n    public let context: ErrorContext\n    public let severity: ErrorSeverity\n    public let timestamp: Date\n    public var recoveryAttempts: Int\n}\n\n/// Recovery attempt information\npublic struct RecoveryAttempt: Identifiable {\n    public let id: UUID\n    public let context: ErrorContext\n    public let attemptNumber: Int\n    public let successful: Bool\n    public let timestamp: Date\n    public let error: Error?\n    \n    public init(\n        id: UUID,\n        context: ErrorContext,\n        attemptNumber: Int,\n        successful: Bool,\n        timestamp: Date,\n        error: Error? = nil\n    ) {\n        self.id = id\n        self.context = context\n        self.attemptNumber = attemptNumber\n        self.successful = successful\n        self.timestamp = timestamp\n        self.error = error\n    }\n}\n\n/// Platform health status\npublic struct PlatformHealth {\n    public let platform: Platform\n    public let isHealthy: Bool\n    public let lastChecked: Date\n    public let errorCount: Int\n    public let averageResponseTime: TimeInterval\n    \n    public var healthScore: Double {\n        if !isHealthy {\n            return 0.0\n        }\n        \n        let errorPenalty = min(Double(errorCount) * 0.1, 0.5)\n        let responsePenalty = min(averageResponseTime / 10.0, 0.3)\n        \n        return max(0.0, 1.0 - errorPenalty - responsePenalty)\n    }\n}\n\n/// Overall service health\npublic struct ServiceHealth {\n    public let overallHealth: Double\n    public let activeErrorCount: Int\n    public let criticalErrorCount: Int\n    public let networkStatus: NetworkStatus\n    public let lastUpdated: Date\n    \n    public init(\n        overallHealth: Double = 1.0,\n        activeErrorCount: Int = 0,\n        criticalErrorCount: Int = 0,\n        networkStatus: NetworkStatus = .unknown,\n        lastUpdated: Date = Date()\n    ) {\n        self.overallHealth = overallHealth\n        self.activeErrorCount = activeErrorCount\n        self.criticalErrorCount = criticalErrorCount\n        self.networkStatus = networkStatus\n        self.lastUpdated = lastUpdated\n    }\n    \n    public var healthStatus: String {\n        if overallHealth >= 0.8 {\n            return "Excellent"\n        } else if overallHealth >= 0.6 {\n            return "Good"\n        } else if overallHealth >= 0.4 {\n            return "Fair"\n        } else if overallHealth >= 0.2 {\n            return "Poor"\n        } else {\n            return "Critical"\n        }\n    }\n    \n    public var healthColor: Color {\n        if overallHealth >= 0.8 {\n            return .green\n        } else if overallHealth >= 0.6 {\n            return .blue\n        } else if overallHealth >= 0.4 {\n            return .yellow\n        } else if overallHealth >= 0.2 {\n            return .orange\n        } else {\n            return .red\n        }\n    }\n}\n\n/// System alert for user notifications\npublic struct SystemAlert: Identifiable {\n    public let id: UUID\n    public let title: String\n    public let message: String\n    public let severity: ErrorSeverity\n    public let timestamp: Date\n    public let actions: [AlertAction]\n}\n\n/// Alert action\npublic struct AlertAction {\n    public let title: String\n    public let style: ActionStyle\n    \n    public enum ActionStyle {\n        case `default`\n        case cancel\n        case destructive\n    }\n    \n    public init(title: String, style: ActionStyle) {\n        self.title = title\n        self.style = style\n    }\n}\n\n/// Error information analysis result\npublic struct ErrorInfo {\n    public let error: Error\n    public let severity: ErrorSeverity\n    public let category: ErrorCategory\n    public let isRecoverable: Bool\n    public let suggestedAction: RecoveryAction\n    public let context: ErrorContext\n}\n\n/// Stream cache error\npublic enum StreamCacheError: Error {\n    case diskFull\n    case corruptedData\n    case accessDenied\n    case unknown(Error)\n}\n\n/// Stream error recovery errors\npublic enum StreamErrorRecoveryError: Error, LocalizedError {\n    case allRetryAttemptsFailed(Int)\n    case recoveryNotPossible\n    case fallbackUnavailable\n    case timeoutExceeded\n    \n    public var errorDescription: String? {\n        switch self {\n        case .allRetryAttemptsFailed(let attempts):\n            return "All \\(attempts) retry attempts failed"\n        case .recoveryNotPossible:\n            return "Error recovery is not possible"\n        case .fallbackUnavailable:\n            return "No fallback mechanism available"\n        case .timeoutExceeded:\n            return "Recovery timeout exceeded"\n        }\n    }\n}\n\n// MARK: - Helper Services\n\n/// Error logging service\npublic class ErrorLogger {\n    private let enabled: Bool\n    private var errorLog: [LogEntry] = []\n    private let maxLogEntries = 1000\n    \n    public init(enabled: Bool) {\n        self.enabled = enabled\n    }\n    \n    public func logError(_ error: Error, context: ErrorContext) async {\n        guard enabled else { return }\n        \n        let entry = LogEntry(\n            timestamp: Date(),\n            error: error,\n            context: context\n        )\n        \n        errorLog.append(entry)\n        \n        // Keep log size manageable\n        if errorLog.count > maxLogEntries {\n            errorLog.removeFirst(errorLog.count - maxLogEntries)\n        }\n        \n        // In a real implementation, this might send to a remote logging service\n        print("🔴 Error logged: \\(error.localizedDescription) in \\(context.operation)")\n    }\n    \n    public func getRecentErrors(limit: Int = 50) -> [LogEntry] {\n        return Array(errorLog.suffix(limit))\n    }\n    \n    private struct LogEntry {\n        let timestamp: Date\n        let error: Error\n        let context: ErrorContext\n    }\n}\n\n/// Retry management service\npublic class RetryManager {\n    private let configuration: StreamErrorRecoveryService.Configuration\n    \n    public init(configuration: StreamErrorRecoveryService.Configuration) {\n        self.configuration = configuration\n    }\n    \n    public func calculateDelay(for attempt: Int) -> TimeInterval {\n        let delay = configuration.baseRetryDelay * pow(configuration.exponentialBackoffMultiplier, Double(attempt - 1))\n        return min(delay, configuration.maxRetryDelay)\n    }\n    \n    public func calculateRateLimitDelay(for platform: Platform?) -> TimeInterval {\n        // Platform-specific rate limit delays\n        switch platform {\n        case .twitch:\n            return 60.0 // Twitch rate limits often require 1 minute wait\n        case .youtube:\n            return 30.0 // YouTube quotas may require shorter waits\n        default:\n            return 30.0\n        }\n    }\n}\n\n/// Fallback data management\npublic class FallbackManager {\n    private let configuration: StreamErrorRecoveryService.Configuration\n    private var cachedData: [String: Any] = [:]\n    \n    public init(configuration: StreamErrorRecoveryService.Configuration) {\n        self.configuration = configuration\n    }\n    \n    public func getCachedData<T>(for operation: String, type: T.Type) -> T? {\n        return cachedData[operation] as? T\n    }\n    \n    public func cacheData<T>(_ data: T, for operation: String) {\n        cachedData[operation] = data\n    }\n}\n\n/// Alert management service\npublic class AlertManager {\n    private var activeAlerts: [SystemAlert] = []\n    \n    public func addAlert(_ alert: SystemAlert) {\n        activeAlerts.append(alert)\n    }\n    \n    public func removeAlert(_ alertId: UUID) {\n        activeAlerts.removeAll { $0.id == alertId }\n    }\n    \n    public func getActiveAlerts() -> [SystemAlert] {\n        return activeAlerts\n    }\n}"