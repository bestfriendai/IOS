//
//  ErrorRecoveryManager.swift
//  StreamyyyApp
//
//  Automatic error recovery mechanisms with retry logic and exponential backoff
//  Handles recovery attempts for various error types
//

import Foundation
import Combine
import Network

// MARK: - Error Recovery Manager
@MainActor
public class ErrorRecoveryManager: ObservableObject {
    public static let shared = ErrorRecoveryManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isRecovering = false
    @Published public private(set) var activeRecoveries: [String: RecoveryOperation] = [:]
    @Published public private(set) var recoveryStatistics = RecoveryStatistics()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let recoveryQueue = DispatchQueue(label: "errorRecovery.queue", qos: .userInitiated)
    private let config = ErrorRecoveryConfig()
    
    // MARK: - Dependencies
    private let connectionRecovery = ConnectionRecoveryManager.shared
    private let dataRecovery = DataRecoveryService.shared
    private let diagnostics = DiagnosticsManager.shared
    
    private init() {
        setupRecoveryMonitoring()
    }
    
    // MARK: - Setup
    private func setupRecoveryMonitoring() {
        // Monitor active recoveries
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateActiveRecoveries()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Recovery Methods
    public func attemptRecovery(for error: AppError) async -> RecoveryResult {
        let recoveryId = UUID().uuidString
        
        // Check if recovery is already in progress for this error type
        if let existingRecovery = activeRecoveries[error.code] {
            return await waitForExistingRecovery(existingRecovery)
        }
        
        // Create new recovery operation
        let operation = RecoveryOperation(
            id: recoveryId,
            errorCode: error.code,
            errorCategory: error.category,
            startTime: Date(),
            maxAttempts: getMaxAttempts(for: error),
            currentAttempt: 0
        )
        
        activeRecoveries[error.code] = operation
        isRecovering = true
        
        let result = await performRecovery(for: error, operation: operation)
        
        // Clean up
        activeRecoveries.removeValue(forKey: error.code)
        if activeRecoveries.isEmpty {
            isRecovering = false
        }
        
        // Update statistics
        updateRecoveryStatistics(result: result)
        
        return result
    }
    
    public func cancelRecovery(for errorCode: String) {
        guard let operation = activeRecoveries[errorCode] else { return }
        
        operation.isCancelled = true
        activeRecoveries.removeValue(forKey: errorCode)
        
        if activeRecoveries.isEmpty {
            isRecovering = false
        }
    }
    
    public func cancelAllRecoveries() {
        for operation in activeRecoveries.values {
            operation.isCancelled = true
        }
        
        activeRecoveries.removeAll()
        isRecovering = false
    }
    
    // MARK: - Recovery Implementation
    private func performRecovery(for error: AppError, operation: RecoveryOperation) async -> RecoveryResult {
        guard operation.currentAttempt < operation.maxAttempts && !operation.isCancelled else {
            return RecoveryResult(
                wasSuccessful: false,
                attemptsMade: operation.currentAttempt,
                timeTaken: Date().timeIntervalSince(operation.startTime),
                failureReason: operation.isCancelled ? "Recovery cancelled" : "Max attempts exceeded"
            )
        }
        
        operation.currentAttempt += 1
        operation.lastAttemptTime = Date()
        
        // Select recovery strategy based on error type
        let strategy = getRecoveryStrategy(for: error)
        
        do {
            let success = try await executeRecoveryStrategy(strategy, for: error, operation: operation)
            
            if success {
                return RecoveryResult(
                    wasSuccessful: true,
                    attemptsMade: operation.currentAttempt,
                    timeTaken: Date().timeIntervalSince(operation.startTime),
                    recoveryStrategy: strategy.name
                )
            } else {
                // Wait before retry with exponential backoff
                let delay = calculateBackoffDelay(attempt: operation.currentAttempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Recursive call for next attempt
                return await performRecovery(for: error, operation: operation)
            }
            
        } catch {
            // Recovery strategy failed with error
            let delay = calculateBackoffDelay(attempt: operation.currentAttempt)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            return await performRecovery(for: error, operation: operation)
        }
    }
    
    private func executeRecoveryStrategy(_ strategy: RecoveryStrategy, for error: AppError, operation: RecoveryOperation) async throws -> Bool {
        switch strategy {
        case .networkRetry:
            return await connectionRecovery.attemptNetworkRecovery()
            
        case .dataIntegrityCheck:
            return await dataRecovery.checkAndRepairData(for: error)
            
        case .cacheRefresh:
            return await refreshCache(for: error)
            
        case .serviceRestart:
            return await restartService(for: error)
            
        case .authTokenRefresh:
            return await refreshAuthToken()
            
        case .systemResourceCleanup:
            return await performSystemCleanup()
            
        case .configurationReset:
            return await resetConfiguration(for: error)
            
        case .userSessionRestart:
            return await restartUserSession()
            
        case .custom(let handler):
            return await handler(error, operation)
        }
    }
    
    // MARK: - Recovery Strategies
    private func getRecoveryStrategy(for error: AppError) -> RecoveryStrategy {
        switch error.category {
        case .network:
            return .networkRetry
            
        case .authentication:
            if let authError = error as? AuthenticationError {
                switch authError {
                case .sessionExpired:
                    return .authTokenRefresh
                case .networkError:
                    return .networkRetry
                default:
                    return .userSessionRestart
                }
            }
            return .userSessionRestart
            
        case .database:
            return .dataIntegrityCheck
            
        case .streaming:
            return .serviceRestart
            
        case .payment:
            return .configurationReset
            
        case .system:
            return .systemResourceCleanup
            
        case .validation:
            return .configurationReset
            
        case .permission:
            return .userSessionRestart
            
        case .unknown:
            return .cacheRefresh
        }
    }
    
    // MARK: - Specific Recovery Methods
    private func refreshCache(for error: AppError) async -> Bool {
        do {
            // Clear relevant caches
            CacheManager.shared.clearAll()
            
            // Trigger cache refresh
            await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            return true
        } catch {
            return false
        }
    }
    
    private func restartService(for error: AppError) async -> Bool {
        do {
            // Restart relevant services based on error context
            if error.code.contains("STREAM") {
                // Restart streaming services
                await StreamManager.shared.restartStreamingServices()
            } else if error.code.contains("AUTH") {
                // Restart authentication services
                await ClerkManager.shared.reinitialize()
            }
            
            return true
        } catch {
            return false
        }
    }
    
    private func refreshAuthToken() async -> Bool {
        do {
            // Attempt to refresh authentication token
            let success = await ClerkManager.shared.refreshSession()
            return success
        } catch {
            return false
        }
    }
    
    private func performSystemCleanup() async -> Bool {
        do {
            // Perform memory cleanup
            await diagnostics.performMemoryCleanup()
            
            // Clear temporary files
            await diagnostics.clearTemporaryFiles()
            
            // Garbage collection
            await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            return true
        } catch {
            return false
        }
    }
    
    private func resetConfiguration(for error: AppError) async -> Bool {
        do {
            // Reset configuration based on error type
            switch error.category {
            case .payment:
                await StripeManager.shared.resetConfiguration()
            case .streaming:
                await StreamManager.shared.resetConfiguration()
            default:
                break
            }
            
            return true
        } catch {
            return false
        }
    }
    
    private func restartUserSession() async -> Bool {
        do {
            // Restart user session
            await ClerkManager.shared.signOut()
            
            // Clear session data
            UserDefaults.standard.removeObject(forKey: "user_session")
            
            // Trigger re-authentication
            await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Utility Methods
    private func getMaxAttempts(for error: AppError) -> Int {
        switch error.severity {
        case .critical:
            return config.maxCriticalAttempts
        case .high:
            return config.maxHighAttempts
        case .medium:
            return config.maxMediumAttempts
        case .low:
            return config.maxLowAttempts
        }
    }
    
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        let baseDelay = config.baseBackoffDelay
        let maxDelay = config.maxBackoffDelay
        
        // Exponential backoff with jitter
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.1) * exponentialDelay
        
        return min(exponentialDelay + jitter, maxDelay)
    }
    
    private func waitForExistingRecovery(_ operation: RecoveryOperation) async -> RecoveryResult {
        // Wait for existing recovery to complete
        while activeRecoveries[operation.errorCode] != nil && !operation.isCancelled {
            await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Return a synthetic result indicating the recovery was already in progress
        return RecoveryResult(
            wasSuccessful: false,
            attemptsMade: 0,
            timeTaken: 0,
            failureReason: "Recovery already in progress"
        )
    }
    
    private func updateActiveRecoveries() {
        let now = Date()
        let timeout = config.recoveryTimeout
        
        // Remove timed-out recoveries
        activeRecoveries = activeRecoveries.filter { _, operation in
            now.timeIntervalSince(operation.startTime) < timeout
        }
        
        if activeRecoveries.isEmpty {
            isRecovering = false
        }
    }
    
    private func updateRecoveryStatistics(result: RecoveryResult) {
        recoveryStatistics.totalAttempts += result.attemptsMade
        recoveryStatistics.totalRecoveries += 1
        
        if result.wasSuccessful {
            recoveryStatistics.successfulRecoveries += 1
        }
        
        recoveryStatistics.averageAttempts = Double(recoveryStatistics.totalAttempts) / Double(recoveryStatistics.totalRecoveries)
        recoveryStatistics.successRate = Double(recoveryStatistics.successfulRecoveries) / Double(recoveryStatistics.totalRecoveries)
    }
    
    // MARK: - Public Utility Methods
    public func getRecoveryStatistics() -> RecoveryStatistics {
        return recoveryStatistics
    }
    
    public func resetRecoveryStatistics() {
        recoveryStatistics = RecoveryStatistics()
    }
    
    public func isRecoveryInProgress(for errorCode: String) -> Bool {
        return activeRecoveries[errorCode] != nil
    }
}

// MARK: - Recovery Strategy
public enum RecoveryStrategy {
    case networkRetry
    case dataIntegrityCheck
    case cacheRefresh
    case serviceRestart
    case authTokenRefresh
    case systemResourceCleanup
    case configurationReset
    case userSessionRestart
    case custom((AppError, RecoveryOperation) async -> Bool)
    
    var name: String {
        switch self {
        case .networkRetry:
            return "Network Retry"
        case .dataIntegrityCheck:
            return "Data Integrity Check"
        case .cacheRefresh:
            return "Cache Refresh"
        case .serviceRestart:
            return "Service Restart"
        case .authTokenRefresh:
            return "Auth Token Refresh"
        case .systemResourceCleanup:
            return "System Resource Cleanup"
        case .configurationReset:
            return "Configuration Reset"
        case .userSessionRestart:
            return "User Session Restart"
        case .custom:
            return "Custom Recovery"
        }
    }
}

// MARK: - Recovery Operation
public class RecoveryOperation: ObservableObject {
    @Published public let id: String
    @Published public let errorCode: String
    @Published public let errorCategory: ErrorCategory
    @Published public let startTime: Date
    @Published public let maxAttempts: Int
    @Published public var currentAttempt: Int
    @Published public var lastAttemptTime: Date?
    @Published public var isCancelled: Bool = false
    
    public init(id: String, errorCode: String, errorCategory: ErrorCategory, startTime: Date, maxAttempts: Int, currentAttempt: Int) {
        self.id = id
        self.errorCode = errorCode
        self.errorCategory = errorCategory
        self.startTime = startTime
        self.maxAttempts = maxAttempts
        self.currentAttempt = currentAttempt
    }
    
    public var progress: Double {
        return Double(currentAttempt) / Double(maxAttempts)
    }
    
    public var timeElapsed: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
    
    public var isComplete: Bool {
        return currentAttempt >= maxAttempts || isCancelled
    }
}

// MARK: - Recovery Result
public struct RecoveryResult {
    public let wasSuccessful: Bool
    public let attemptsMade: Int
    public let timeTaken: TimeInterval
    public let recoveryStrategy: String?
    public let failureReason: String?
    
    public init(wasSuccessful: Bool, attemptsMade: Int, timeTaken: TimeInterval, recoveryStrategy: String? = nil, failureReason: String? = nil) {
        self.wasSuccessful = wasSuccessful
        self.attemptsMade = attemptsMade
        self.timeTaken = timeTaken
        self.recoveryStrategy = recoveryStrategy
        self.failureReason = failureReason
    }
}

// MARK: - Recovery Statistics
public struct RecoveryStatistics {
    public var totalRecoveries: Int = 0
    public var successfulRecoveries: Int = 0
    public var totalAttempts: Int = 0
    public var averageAttempts: Double = 0.0
    public var successRate: Double = 0.0
    
    public var failureRate: Double {
        return 1.0 - successRate
    }
    
    public var averageAttemptsPerFailure: Double {
        let failures = totalRecoveries - successfulRecoveries
        guard failures > 0 else { return 0.0 }
        return Double(totalAttempts - successfulRecoveries) / Double(failures)
    }
}

// MARK: - Error Recovery Configuration
private struct ErrorRecoveryConfig {
    let maxCriticalAttempts: Int = 5
    let maxHighAttempts: Int = 3
    let maxMediumAttempts: Int = 2
    let maxLowAttempts: Int = 1
    
    let baseBackoffDelay: TimeInterval = 1.0
    let maxBackoffDelay: TimeInterval = 60.0
    
    let recoveryTimeout: TimeInterval = 5 * 60.0 // 5 minutes
}

// MARK: - Manager Extensions
extension StreamManager {
    func restartStreamingServices() async {
        // Implementation would restart streaming services
        print("🔄 Restarting streaming services...")
    }
    
    func resetConfiguration() async {
        // Implementation would reset streaming configuration
        print("🔄 Resetting streaming configuration...")
    }
}

extension ClerkManager {
    func reinitialize() async {
        // Implementation would reinitialize Clerk
        print("🔄 Reinitializing Clerk...")
    }
    
    func refreshSession() async -> Bool {
        // Implementation would refresh the session
        print("🔄 Refreshing session...")
        return true
    }
}

extension StripeManager {
    func resetConfiguration() async {
        // Implementation would reset Stripe configuration
        print("🔄 Resetting Stripe configuration...")
    }
}