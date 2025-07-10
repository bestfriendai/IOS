//
//  ErrorHandler.swift
//  StreamyyyApp
//
//  Central error handling service for comprehensive error processing
//  Coordinates all error handling activities across the application
//

import Foundation
import Combine
import SwiftUI

// MARK: - Error Handler Service
@MainActor
public class ErrorHandler: ObservableObject {
    public static let shared = ErrorHandler()
    
    // MARK: - Published Properties
    @Published public private(set) var isHandlingError = false
    @Published public private(set) var errorQueue: [AppError] = []
    @Published public private(set) var errorStatistics = ErrorStatistics()
    @Published public private(set) var systemHealth = SystemHealth()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let errorQueue_lock = NSLock()
    private let processingQueue = DispatchQueue(label: "errorHandler.processing", qos: .utility)
    
    // MARK: - Dependencies
    private let errorLogger = ErrorLoggingService.shared
    private let errorReporter = ErrorReportingService.shared
    private let recoveryManager = ErrorRecoveryManager.shared
    private let presentationManager = ErrorPresentationManager.shared
    private let diagnosticsManager = DiagnosticsManager.shared
    
    // MARK: - Configuration
    private let config = ErrorHandlerConfig()
    
    private init() {
        setupErrorHandling()
        setupSystemMonitoring()
    }
    
    // MARK: - Setup
    private func setupErrorHandling() {
        // Listen for global errors
        NotificationCenter.default.publisher(for: .globalError)
            .sink { [weak self] notification in
                if let error = notification.object as? AppError {
                    self?.handleError(error)
                }
            }
            .store(in: &cancellables)
        
        // Listen for unhandled exceptions
        NotificationCenter.default.publisher(for: .unhandledException)
            .sink { [weak self] notification in
                self?.handleUnhandledException(notification)
            }
            .store(in: &cancellables)
        
        // Listen for memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
        
        // Listen for system errors
        NotificationCenter.default.publisher(for: .systemError)
            .sink { [weak self] notification in
                self?.handleSystemError(notification)
            }
            .store(in: &cancellables)
    }
    
    private func setupSystemMonitoring() {
        // Monitor system health every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateSystemHealth()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Error Handling Methods
    public func handleError(_ error: AppError) {
        Task { @MainActor in
            isHandlingError = true
            
            // Add to error queue
            errorQueue_lock.lock()
            errorQueue.append(error)
            errorQueue_lock.unlock()
            
            // Update statistics
            updateErrorStatistics(for: error)
            
            // Process the error
            await processError(error)
            
            isHandlingError = false
        }
    }
    
    public func handleError(_ error: Error) {
        let appError = convertToAppError(error)
        handleError(appError)
    }
    
    public func handleCriticalError(_ error: AppError) {
        // Mark as critical and handle immediately
        var criticalError = error
        if let baseError = error as? BaseAppError {
            criticalError = BaseAppError(
                title: baseError.title,
                message: baseError.message,
                code: baseError.code,
                category: baseError.category,
                severity: .critical,
                userInfo: baseError.userInfo,
                isRetryable: baseError.isRetryable,
                suggestedActions: baseError.suggestedActions,
                underlyingError: baseError.underlyingError
            )
        }
        
        handleError(criticalError)
    }
    
    public func handleBatchErrors(_ errors: [AppError]) {
        Task { @MainActor in
            isHandlingError = true
            
            for error in errors {
                await processError(error)
            }
            
            isHandlingError = false
        }
    }
    
    // MARK: - Error Processing
    private func processError(_ error: AppError) async {
        do {
            // Log the error
            await errorLogger.logError(error)
            
            // Report to analytics and crash reporting
            await errorReporter.reportError(error)
            
            // Update diagnostics
            await diagnosticsManager.recordError(error)
            
            // Check if error is recoverable
            if error.isRetryable {
                let recoveryResult = await recoveryManager.attemptRecovery(for: error)
                
                if recoveryResult.wasSuccessful {
                    // Recovery successful, log success
                    await errorLogger.logRecoverySuccess(error, result: recoveryResult)
                    return
                }
                
                // Recovery failed, continue with normal error handling
                await errorLogger.logRecoveryFailure(error, result: recoveryResult)
            }
            
            // Present error to user if needed
            await presentError(error)
            
        } catch {
            // Error occurred while processing error - log but don't recurse
            print("⚠️ Error occurred while processing error: \(error)")
            await errorLogger.logMetaError(error, originalError: error)
        }
    }
    
    private func presentError(_ error: AppError) async {
        // Only present errors that meet certain criteria
        let shouldPresent = shouldPresentError(error)
        
        if shouldPresent {
            await presentationManager.presentError(error)
        }
    }
    
    private func shouldPresentError(_ error: AppError) -> Bool {
        // Don't present low severity errors
        if error.severity == .low {
            return false
        }
        
        // Don't present validation errors for input fields
        if error.category == .validation {
            return false
        }
        
        // Don't present if too many errors recently
        if errorStatistics.recentErrorCount > config.maxErrorsPerMinute {
            return false
        }
        
        // Don't present duplicate errors within short time
        if let lastError = errorStatistics.lastError,
           lastError.code == error.code,
           Date().timeIntervalSince(lastError.timestamp) < config.duplicateErrorWindow {
            return false
        }
        
        return true
    }
    
    // MARK: - Error Conversion
    private func convertToAppError(_ error: Error) -> AppError {
        // If already an AppError, return as-is
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert common system errors
        if let urlError = error as? URLError {
            return convertURLError(urlError)
        }
        
        if let decodingError = error as? DecodingError {
            return convertDecodingError(decodingError)
        }
        
        if let encodingError = error as? EncodingError {
            return convertEncodingError(encodingError)
        }
        
        // Default conversion for unknown errors
        return BaseAppError(
            title: "Unexpected Error",
            message: error.localizedDescription,
            code: "UNKNOWN_ERROR",
            category: .unknown,
            severity: .medium,
            underlyingError: error
        )
    }
    
    private func convertURLError(_ urlError: URLError) -> AppError {
        switch urlError.code {
        case .notConnectedToInternet:
            return NetworkError.noConnection
        case .timedOut:
            return NetworkError.timeout
        case .badServerResponse:
            return NetworkError.badResponse
        case .cancelled:
            return BaseAppError(
                title: "Request Cancelled",
                message: "The request was cancelled by the user.",
                code: "NET_CANCELLED",
                category: .network,
                severity: .low,
                isRetryable: false
            )
        default:
            return NetworkError.unknown(urlError)
        }
    }
    
    private func convertDecodingError(_ decodingError: DecodingError) -> AppError {
        let message: String
        let code: String
        
        switch decodingError {
        case .typeMismatch(let type, let context):
            message = "Expected \(type) but received different type at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            code = "DECODE_TYPE_MISMATCH"
            
        case .valueNotFound(let type, let context):
            message = "Required value of type \(type) not found at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            code = "DECODE_VALUE_NOT_FOUND"
            
        case .keyNotFound(let key, let context):
            message = "Required key '\(key.stringValue)' not found at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            code = "DECODE_KEY_NOT_FOUND"
            
        case .dataCorrupted(let context):
            message = "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            code = "DECODE_DATA_CORRUPTED"
            
        @unknown default:
            message = "Unknown decoding error occurred"
            code = "DECODE_UNKNOWN"
        }
        
        return BaseAppError(
            title: "Data Processing Error",
            message: message,
            code: code,
            category: .database,
            severity: .medium,
            underlyingError: decodingError
        )
    }
    
    private func convertEncodingError(_ encodingError: EncodingError) -> AppError {
        let message: String
        let code: String
        
        switch encodingError {
        case .invalidValue(let value, let context):
            message = "Invalid value '\(value)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            code = "ENCODE_INVALID_VALUE"
            
        @unknown default:
            message = "Unknown encoding error occurred"
            code = "ENCODE_UNKNOWN"
        }
        
        return BaseAppError(
            title: "Data Encoding Error",
            message: message,
            code: code,
            category: .database,
            severity: .medium,
            underlyingError: encodingError
        )
    }
    
    // MARK: - Specialized Error Handlers
    private func handleUnhandledException(_ notification: Notification) {
        let error = BaseAppError(
            title: "Critical System Error",
            message: "An unhandled exception occurred. The app may need to restart.",
            code: "SYSTEM_UNHANDLED_EXCEPTION",
            category: .system,
            severity: .critical,
            isRetryable: false,
            suggestedActions: [.contactSupport, .dismiss]
        )
        
        handleError(error)
    }
    
    private func handleMemoryWarning() {
        let error = BaseAppError(
            title: "Memory Warning",
            message: "The app is using too much memory. Some features may be temporarily disabled.",
            code: "SYSTEM_MEMORY_WARNING",
            category: .system,
            severity: .high,
            isRetryable: false,
            suggestedActions: [.dismiss]
        )
        
        handleError(error)
        
        // Trigger memory cleanup
        Task {
            await performMemoryCleanup()
        }
    }
    
    private func handleSystemError(_ notification: Notification) {
        let error = BaseAppError(
            title: "System Error",
            message: "A system-level error occurred.",
            code: "SYSTEM_ERROR",
            category: .system,
            severity: .high,
            underlyingError: notification.object as? Error
        )
        
        handleError(error)
    }
    
    // MARK: - Statistics and Monitoring
    private func updateErrorStatistics(for error: AppError) {
        errorStatistics.totalErrors += 1
        errorStatistics.lastError = error
        
        if error.severity == .critical {
            errorStatistics.criticalErrors += 1
        }
        
        // Update category distribution
        let categoryKey = error.category.rawValue
        errorStatistics.categoryDistribution[categoryKey] = (errorStatistics.categoryDistribution[categoryKey] ?? 0) + 1
        
        // Update recent error count
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        errorStatistics.recentErrorCount = errorQueue.filter { $0.timestamp > oneMinuteAgo }.count
    }
    
    private func updateSystemHealth() {
        Task {
            let health = await diagnosticsManager.getSystemHealth()
            systemHealth = health
        }
    }
    
    // MARK: - Memory Management
    private func performMemoryCleanup() async {
        // Clear old errors from queue
        errorQueue_lock.lock()
        let cutoffDate = Date().addingTimeInterval(-config.errorRetentionTime)
        errorQueue = errorQueue.filter { $0.timestamp > cutoffDate }
        errorQueue_lock.unlock()
        
        // Trigger system cleanup
        await diagnosticsManager.performMemoryCleanup()
    }
    
    // MARK: - Public Utility Methods
    public func clearErrorQueue() {
        errorQueue_lock.lock()
        errorQueue.removeAll()
        errorQueue_lock.unlock()
    }
    
    public func getErrorStatistics() -> ErrorStatistics {
        return errorStatistics
    }
    
    public func getSystemHealth() -> SystemHealth {
        return systemHealth
    }
    
    public func exportErrorLogs() async -> Data? {
        return await errorLogger.exportLogs()
    }
    
    public func resetErrorStatistics() {
        errorStatistics = ErrorStatistics()
    }
}

// MARK: - Error Handler Configuration
private struct ErrorHandlerConfig {
    let maxErrorsPerMinute: Int = 10
    let duplicateErrorWindow: TimeInterval = 30.0
    let errorRetentionTime: TimeInterval = 24 * 60 * 60 // 24 hours
    let maxQueueSize: Int = 1000
    let processingTimeout: TimeInterval = 5.0
}

// MARK: - Error Statistics
public struct ErrorStatistics {
    public var totalErrors: Int = 0
    public var criticalErrors: Int = 0
    public var recentErrorCount: Int = 0
    public var categoryDistribution: [String: Int] = [:]
    public var lastError: AppError?
    public var uptime: TimeInterval = 0
    
    public var errorRate: Double {
        guard uptime > 0 else { return 0 }
        return Double(totalErrors) / (uptime / 60.0) // errors per minute
    }
    
    public var criticalErrorRate: Double {
        guard totalErrors > 0 else { return 0 }
        return Double(criticalErrors) / Double(totalErrors)
    }
}

// MARK: - System Health
public struct SystemHealth {
    public var memoryUsage: Double = 0.0
    public var diskUsage: Double = 0.0
    public var batteryLevel: Double = 0.0
    public var thermalState: String = "normal"
    public var isLowPowerMode: Bool = false
    public var networkStatus: String = "connected"
    public var lastUpdated: Date = Date()
    
    public var healthScore: Double {
        var score = 100.0
        
        // Deduct points for high memory usage
        if memoryUsage > 0.8 {
            score -= 20.0
        } else if memoryUsage > 0.6 {
            score -= 10.0
        }
        
        // Deduct points for high disk usage
        if diskUsage > 0.9 {
            score -= 15.0
        } else if diskUsage > 0.8 {
            score -= 8.0
        }
        
        // Deduct points for thermal throttling
        if thermalState == "critical" {
            score -= 30.0
        } else if thermalState == "serious" {
            score -= 15.0
        }
        
        // Deduct points for low battery
        if batteryLevel < 0.1 {
            score -= 10.0
        }
        
        // Deduct points for low power mode
        if isLowPowerMode {
            score -= 5.0
        }
        
        // Deduct points for network issues
        if networkStatus == "disconnected" {
            score -= 25.0
        }
        
        return max(0, score)
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let globalError = Notification.Name("GlobalError")
    static let unhandledException = Notification.Name("UnhandledException")
    static let systemError = Notification.Name("SystemError")
}

// MARK: - Global Error Functions
public func handleGlobalError(_ error: AppError) {
    Task { @MainActor in
        ErrorHandler.shared.handleError(error)
    }
}

public func handleGlobalError(_ error: Error) {
    Task { @MainActor in
        ErrorHandler.shared.handleError(error)
    }
}

public func handleCriticalError(_ error: AppError) {
    Task { @MainActor in
        ErrorHandler.shared.handleCriticalError(error)
    }
}

// MARK: - SwiftUI Extensions
extension View {
    public func handleErrors() -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .globalError)) { notification in
            if let error = notification.object as? AppError {
                Task { @MainActor in
                    ErrorHandler.shared.handleError(error)
                }
            }
        }
    }
}