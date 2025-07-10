//
//  ErrorHandling.swift
//  StreamyyyApp
//
//  Comprehensive error handling and validation system
//

import Foundation
import SwiftUI

// MARK: - Global Error Protocol
public protocol AppError: Error, LocalizedError, Identifiable {
    var id: String { get }
    var title: String { get }
    var message: String { get }
    var code: String { get }
    var category: ErrorCategory { get }
    var severity: ErrorSeverity { get }
    var userInfo: [String: Any] { get }
    var timestamp: Date { get }
    var isRetryable: Bool { get }
    var suggestedActions: [ErrorAction] { get }
}

// MARK: - Error Categories
public enum ErrorCategory: String, CaseIterable {
    case authentication = "authentication"
    case network = "network"
    case validation = "validation"
    case database = "database"
    case payment = "payment"
    case streaming = "streaming"
    case permission = "permission"
    case system = "system"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .authentication: return "Authentication"
        case .network: return "Network"
        case .validation: return "Validation"
        case .database: return "Database"
        case .payment: return "Payment"
        case .streaming: return "Streaming"
        case .permission: return "Permission"
        case .system: return "System"
        case .unknown: return "Unknown"
        }
    }
    
    public var icon: String {
        switch self {
        case .authentication: return "person.badge.key"
        case .network: return "wifi.exclamationmark"
        case .validation: return "exclamationmark.triangle"
        case .database: return "externaldrive.badge.exclamationmark"
        case .payment: return "creditcard.trianglebadge.exclamationmark"
        case .streaming: return "play.slash"
        case .permission: return "lock.shield"
        case .system: return "gear.badge.xmark"
        case .unknown: return "questionmark.circle"
        }
    }
    
    public var color: Color {
        switch self {
        case .authentication: return .blue
        case .network: return .orange
        case .validation: return .yellow
        case .database: return .purple
        case .payment: return .red
        case .streaming: return .green
        case .permission: return .indigo
        case .system: return .gray
        case .unknown: return .black
        }
    }
}

// MARK: - Error Severity
public enum ErrorSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    public var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Error Actions
public enum ErrorAction {
    case retry
    case refresh
    case login
    case upgrade
    case contactSupport
    case dismiss
    case settings
    case custom(String, () -> Void)
    
    public var title: String {
        switch self {
        case .retry: return "Retry"
        case .refresh: return "Refresh"
        case .login: return "Login"
        case .upgrade: return "Upgrade"
        case .contactSupport: return "Contact Support"
        case .dismiss: return "Dismiss"
        case .settings: return "Settings"
        case .custom(let title, _): return title
        }
    }
    
    public var icon: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .refresh: return "arrow.clockwise.circle"
        case .login: return "person.crop.circle"
        case .upgrade: return "arrow.up.circle"
        case .contactSupport: return "envelope"
        case .dismiss: return "xmark"
        case .settings: return "gear"
        case .custom: return "star"
        }
    }
    
    public func execute() {
        switch self {
        case .retry:
            print("Retrying operation...")
        case .refresh:
            print("Refreshing data...")
        case .login:
            print("Navigating to login...")
        case .upgrade:
            print("Navigating to upgrade...")
        case .contactSupport:
            print("Opening support...")
        case .dismiss:
            print("Dismissing error...")
        case .settings:
            print("Opening settings...")
        case .custom(_, let action):
            action()
        }
    }
}

// MARK: - Base App Error
public struct BaseAppError: AppError {
    public let id: String
    public let title: String
    public let message: String
    public let code: String
    public let category: ErrorCategory
    public let severity: ErrorSeverity
    public let userInfo: [String: Any]
    public let timestamp: Date
    public let isRetryable: Bool
    public let suggestedActions: [ErrorAction]
    public let underlyingError: Error?
    
    public init(
        title: String,
        message: String,
        code: String,
        category: ErrorCategory,
        severity: ErrorSeverity = .medium,
        userInfo: [String: Any] = [:],
        isRetryable: Bool = true,
        suggestedActions: [ErrorAction] = [.retry, .dismiss],
        underlyingError: Error? = nil
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.message = message
        self.code = code
        self.category = category
        self.severity = severity
        self.userInfo = userInfo
        self.timestamp = Date()
        self.isRetryable = isRetryable
        self.suggestedActions = suggestedActions
        self.underlyingError = underlyingError
    }
    
    public var errorDescription: String? {
        return message
    }
    
    public var failureReason: String? {
        return title
    }
    
    public var recoverySuggestion: String? {
        return suggestedActions.first?.title
    }
}

// MARK: - Specific Error Types
public enum AuthenticationError: AppError {
    case invalidCredentials
    case userNotFound
    case accountLocked
    case sessionExpired
    case networkError
    case clerkError(String)
    case unknown(Error)
    
    public var id: String {
        return "auth_\(code)"
    }
    
    public var title: String {
        switch self {
        case .invalidCredentials: return "Invalid Credentials"
        case .userNotFound: return "User Not Found"
        case .accountLocked: return "Account Locked"
        case .sessionExpired: return "Session Expired"
        case .networkError: return "Network Error"
        case .clerkError: return "Authentication Error"
        case .unknown: return "Unknown Error"
        }
    }
    
    public var message: String {
        switch self {
        case .invalidCredentials: return "The email or password you entered is incorrect."
        case .userNotFound: return "No account found with this email address."
        case .accountLocked: return "Your account has been temporarily locked due to too many failed attempts."
        case .sessionExpired: return "Your session has expired. Please log in again."
        case .networkError: return "Unable to connect to authentication servers."
        case .clerkError(let error): return error
        case .unknown(let error): return error.localizedDescription
        }
    }
    
    public var code: String {
        switch self {
        case .invalidCredentials: return "AUTH_001"
        case .userNotFound: return "AUTH_002"
        case .accountLocked: return "AUTH_003"
        case .sessionExpired: return "AUTH_004"
        case .networkError: return "AUTH_005"
        case .clerkError: return "AUTH_006"
        case .unknown: return "AUTH_999"
        }
    }
    
    public var category: ErrorCategory { return .authentication }
    
    public var severity: ErrorSeverity {
        switch self {
        case .invalidCredentials, .userNotFound: return .medium
        case .accountLocked, .sessionExpired: return .high
        case .networkError, .clerkError, .unknown: return .high
        }
    }
    
    public var userInfo: [String: Any] {
        return [
            "timestamp": timestamp,
            "category": category.rawValue,
            "severity": severity.rawValue
        ]
    }
    
    public var timestamp: Date { return Date() }
    
    public var isRetryable: Bool {
        switch self {
        case .invalidCredentials, .userNotFound, .accountLocked: return false
        case .sessionExpired, .networkError, .clerkError, .unknown: return true
        }
    }
    
    public var suggestedActions: [ErrorAction] {
        switch self {
        case .invalidCredentials, .userNotFound:
            return [.dismiss]
        case .accountLocked:
            return [.contactSupport, .dismiss]
        case .sessionExpired:
            return [.login, .dismiss]
        case .networkError:
            return [.retry, .refresh, .dismiss]
        case .clerkError, .unknown:
            return [.retry, .contactSupport, .dismiss]
        }
    }
    
    public var errorDescription: String? { return message }
}

public enum NetworkError: AppError {
    case noConnection
    case timeout
    case serverError(Int)
    case badResponse
    case rateLimited
    case unknown(Error)
    
    public var id: String {
        return "network_\(code)"
    }
    
    public var title: String {
        switch self {
        case .noConnection: return "No Internet Connection"
        case .timeout: return "Request Timeout"
        case .serverError: return "Server Error"
        case .badResponse: return "Invalid Response"
        case .rateLimited: return "Rate Limited"
        case .unknown: return "Network Error"
        }
    }
    
    public var message: String {
        switch self {
        case .noConnection: return "Please check your internet connection and try again."
        case .timeout: return "The request took too long to complete. Please try again."
        case .serverError(let code): return "Server error occurred (HTTP \(code)). Please try again later."
        case .badResponse: return "Received an invalid response from the server."
        case .rateLimited: return "Too many requests. Please wait a moment and try again."
        case .unknown(let error): return "Network error: \(error.localizedDescription)"
        }
    }
    
    public var code: String {
        switch self {
        case .noConnection: return "NET_001"
        case .timeout: return "NET_002"
        case .serverError: return "NET_003"
        case .badResponse: return "NET_004"
        case .rateLimited: return "NET_005"
        case .unknown: return "NET_999"
        }
    }
    
    public var category: ErrorCategory { return .network }
    
    public var severity: ErrorSeverity {
        switch self {
        case .noConnection, .timeout: return .medium
        case .serverError, .badResponse, .rateLimited: return .high
        case .unknown: return .medium
        }
    }
    
    public var userInfo: [String: Any] {
        var info: [String: Any] = [
            "timestamp": timestamp,
            "category": category.rawValue,
            "severity": severity.rawValue
        ]
        
        if case .serverError(let statusCode) = self {
            info["statusCode"] = statusCode
        }
        
        return info
    }
    
    public var timestamp: Date { return Date() }
    
    public var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError, .rateLimited: return true
        case .badResponse, .unknown: return false
        }
    }
    
    public var suggestedActions: [ErrorAction] {
        switch self {
        case .noConnection:
            return [.retry, .settings, .dismiss]
        case .timeout, .serverError:
            return [.retry, .refresh, .dismiss]
        case .badResponse:
            return [.refresh, .contactSupport, .dismiss]
        case .rateLimited:
            return [.dismiss]
        case .unknown:
            return [.retry, .contactSupport, .dismiss]
        }
    }
    
    public var errorDescription: String? { return message }
}

public enum ValidationError: AppError {
    case invalidEmail
    case invalidPassword
    case invalidURL
    case invalidUsername
    case invalidPhoneNumber
    case fieldRequired(String)
    case fieldTooLong(String, Int)
    case fieldTooShort(String, Int)
    case invalidFormat(String)
    case custom(String, String)
    
    public var id: String {
        return "validation_\(code)"
    }
    
    public var title: String {
        switch self {
        case .invalidEmail: return "Invalid Email"
        case .invalidPassword: return "Invalid Password"
        case .invalidURL: return "Invalid URL"
        case .invalidUsername: return "Invalid Username"
        case .invalidPhoneNumber: return "Invalid Phone Number"
        case .fieldRequired: return "Field Required"
        case .fieldTooLong: return "Field Too Long"
        case .fieldTooShort: return "Field Too Short"
        case .invalidFormat: return "Invalid Format"
        case .custom(let title, _): return title
        }
    }
    
    public var message: String {
        switch self {
        case .invalidEmail: return "Please enter a valid email address."
        case .invalidPassword: return "Password must be at least 8 characters long and contain letters and numbers."
        case .invalidURL: return "Please enter a valid URL."
        case .invalidUsername: return "Username must be 3-20 characters and contain only letters, numbers, and underscores."
        case .invalidPhoneNumber: return "Please enter a valid phone number."
        case .fieldRequired(let field): return "\(field) is required."
        case .fieldTooLong(let field, let limit): return "\(field) must be no more than \(limit) characters."
        case .fieldTooShort(let field, let limit): return "\(field) must be at least \(limit) characters."
        case .invalidFormat(let field): return "\(field) is not in the correct format."
        case .custom(_, let message): return message
        }
    }
    
    public var code: String {
        switch self {
        case .invalidEmail: return "VAL_001"
        case .invalidPassword: return "VAL_002"
        case .invalidURL: return "VAL_003"
        case .invalidUsername: return "VAL_004"
        case .invalidPhoneNumber: return "VAL_005"
        case .fieldRequired: return "VAL_006"
        case .fieldTooLong: return "VAL_007"
        case .fieldTooShort: return "VAL_008"
        case .invalidFormat: return "VAL_009"
        case .custom: return "VAL_999"
        }
    }
    
    public var category: ErrorCategory { return .validation }
    public var severity: ErrorSeverity { return .low }
    public var userInfo: [String: Any] { return [:] }
    public var timestamp: Date { return Date() }
    public var isRetryable: Bool { return false }
    public var suggestedActions: [ErrorAction] { return [.dismiss] }
    public var errorDescription: String? { return message }
}

// MARK: - Error Manager
@MainActor
public class ErrorManager: ObservableObject {
    public static let shared = ErrorManager()
    
    @Published public var currentError: AppError?
    @Published public var errorHistory: [AppError] = []
    @Published public var isShowingError = false
    @Published public var errorCount = 0
    @Published public var criticalErrorCount = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupErrorObservers()
    }
    
    private func setupErrorObservers() {
        // Listen for global errors
        NotificationCenter.default.publisher(for: .init("GlobalError"))
            .sink { [weak self] notification in
                if let error = notification.object as? AppError {
                    self?.handleError(error)
                }
            }
            .store(in: &cancellables)
        
        // Listen for unhandled exceptions
        NotificationCenter.default.publisher(for: .init("UnhandledException"))
            .sink { [weak self] notification in
                let error = BaseAppError(
                    title: "Unexpected Error",
                    message: "An unexpected error occurred. Please try again.",
                    code: "UNHANDLED_001",
                    category: .system,
                    severity: .critical,
                    isRetryable: false,
                    suggestedActions: [.contactSupport, .dismiss]
                )
                self?.handleError(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling
    public func handleError(_ error: AppError) {
        errorHistory.append(error)
        errorCount += 1
        
        if error.severity == .critical {
            criticalErrorCount += 1
        }
        
        // Show error if it's high severity or critical
        if error.severity.priority >= ErrorSeverity.high.priority {
            currentError = error
            isShowingError = true
        }
        
        // Log error
        logError(error)
        
        // Send to analytics
        trackError(error)
        
        // Send to crash reporting
        if error.severity == .critical {
            reportCriticalError(error)
        }
    }
    
    public func handleError(_ error: Error) {
        let appError = convertToAppError(error)
        handleError(appError)
    }
    
    private func convertToAppError(_ error: Error) -> AppError {
        // Convert standard errors to app errors
        if let appError = error as? AppError {
            return appError
        }
        
        // Handle specific error types
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return NetworkError.noConnection
            case .timedOut:
                return NetworkError.timeout
            case .badServerResponse:
                return NetworkError.badResponse
            default:
                return NetworkError.unknown(error)
            }
        }
        
        // Default conversion
        return BaseAppError(
            title: "Error",
            message: error.localizedDescription,
            code: "GENERIC_001",
            category: .unknown,
            severity: .medium,
            underlyingError: error
        )
    }
    
    // MARK: - Error Resolution
    public func dismissError() {
        currentError = nil
        isShowingError = false
    }
    
    public func executeAction(_ action: ErrorAction) {
        action.execute()
        
        // Track action execution
        if let error = currentError {
            trackErrorAction(error, action: action)
        }
        
        dismissError()
    }
    
    public func retryLastOperation() {
        // Implement retry logic
        print("Retrying last operation...")
        dismissError()
    }
    
    // MARK: - Error Logging
    private func logError(_ error: AppError) {
        print("🔥 Error: [\(error.code)] \(error.title) - \(error.message)")
        
        // Log to file or external service
        let logEntry = [
            "id": error.id,
            "code": error.code,
            "title": error.title,
            "message": error.message,
            "category": error.category.rawValue,
            "severity": error.severity.rawValue,
            "timestamp": error.timestamp.iso8601,
            "userInfo": error.userInfo
        ] as [String: Any]
        
        // Save to persistent storage
        saveErrorLog(logEntry)
    }
    
    private func saveErrorLog(_ logEntry: [String: Any]) {
        // Save to UserDefaults or external logging service
        var errorLogs = UserDefaults.standard.array(forKey: "ErrorLogs") as? [[String: Any]] ?? []
        errorLogs.append(logEntry)
        
        // Keep only last 100 errors
        if errorLogs.count > 100 {
            errorLogs = Array(errorLogs.suffix(100))
        }
        
        UserDefaults.standard.set(errorLogs, forKey: "ErrorLogs")
    }
    
    // MARK: - Analytics
    private func trackError(_ error: AppError) {
        let properties = [
            "error_id": error.id,
            "error_code": error.code,
            "error_category": error.category.rawValue,
            "error_severity": error.severity.rawValue,
            "is_retryable": error.isRetryable,
            "timestamp": error.timestamp.timeIntervalSince1970
        ] as [String: Any]
        
        AnalyticsManager.shared.track("error_occurred", properties: properties)
    }
    
    private func trackErrorAction(_ error: AppError, action: ErrorAction) {
        let properties = [
            "error_id": error.id,
            "error_code": error.code,
            "action_taken": action.title,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        AnalyticsManager.shared.track("error_action_taken", properties: properties)
    }
    
    // MARK: - Crash Reporting
    private func reportCriticalError(_ error: AppError) {
        // Send to crash reporting service (e.g., Sentry)
        SentryManager.shared.captureError(error)
    }
    
    // MARK: - Statistics
    public func getErrorStatistics() -> [String: Any] {
        let categoryDistribution = Dictionary(grouping: errorHistory) { $0.category.rawValue }
            .mapValues { $0.count }
        
        let severityDistribution = Dictionary(grouping: errorHistory) { $0.severity.rawValue }
            .mapValues { $0.count }
        
        return [
            "totalErrors": errorCount,
            "criticalErrors": criticalErrorCount,
            "categoryDistribution": categoryDistribution,
            "severityDistribution": severityDistribution,
            "recentErrors": errorHistory.suffix(10).map { $0.code }
        ]
    }
    
    // MARK: - Error Recovery
    public func clearErrorHistory() {
        errorHistory.removeAll()
        errorCount = 0
        criticalErrorCount = 0
        UserDefaults.standard.removeObject(forKey: "ErrorLogs")
    }
    
    public func exportErrorLogs() -> Data? {
        let errorLogs = UserDefaults.standard.array(forKey: "ErrorLogs") as? [[String: Any]] ?? []
        
        do {
            return try JSONSerialization.data(withJSONObject: errorLogs, options: .prettyPrinted)
        } catch {
            print("Failed to export error logs: \(error)")
            return nil
        }
    }
}

// MARK: - Error Alert View
public struct ErrorAlertView: View {
    @ObservedObject private var errorManager = ErrorManager.shared
    @State private var showingDetails = false
    
    public var body: some View {
        EmptyView()
            .alert(
                errorManager.currentError?.title ?? "Error",
                isPresented: $errorManager.isShowingError,
                presenting: errorManager.currentError
            ) { error in
                ForEach(error.suggestedActions.prefix(3), id: \.title) { action in
                    Button(action.title) {
                        errorManager.executeAction(action)
                    }
                }
                
                if error.suggestedActions.count > 3 {
                    Button("More Options") {
                        showingDetails = true
                    }
                }
            } message: { error in
                Text(error.message)
            }
            .sheet(isPresented: $showingDetails) {
                ErrorDetailView(error: errorManager.currentError)
            }
    }
}

// MARK: - Error Detail View
public struct ErrorDetailView: View {
    let error: AppError?
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error = error {
                        // Error Icon and Category
                        HStack {
                            Image(systemName: error.category.icon)
                                .foregroundColor(error.category.color)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text(error.category.displayName)
                                    .font(.headline)
                                    .foregroundColor(error.category.color)
                                
                                Text(error.severity.displayName)
                                    .font(.caption)
                                    .foregroundColor(error.severity.color)
                            }
                            
                            Spacer()
                        }
                        
                        // Error Details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error Details")
                                .font(.headline)
                            
                            Text("Code: \(error.code)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Time: \(error.timestamp.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(error.message)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        // Suggested Actions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested Actions")
                                .font(.headline)
                            
                            ForEach(error.suggestedActions, id: \.title) { action in
                                Button(action: {
                                    ErrorManager.shared.executeAction(action)
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: action.icon)
                                        Text(action.title)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding()
            }
            .navigationTitle("Error Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Date Extension
extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

// MARK: - Error Handling Modifiers
extension View {
    public func handleErrors() -> some View {
        self.overlay(ErrorAlertView())
    }
    
    public func onError(_ handler: @escaping (AppError) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .init("GlobalError"))) { notification in
            if let error = notification.object as? AppError {
                handler(error)
            }
        }
    }
}

// MARK: - Global Error Functions
public func handleGlobalError(_ error: AppError) {
    DispatchQueue.main.async {
        ErrorManager.shared.handleError(error)
    }
}

public func handleGlobalError(_ error: Error) {
    DispatchQueue.main.async {
        ErrorManager.shared.handleError(error)
    }
}

// MARK: - Result Extensions
extension Result {
    public func handleError() -> Success? {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            handleGlobalError(error)
            return nil
        }
    }
}

// MARK: - Task Extensions
extension Task where Failure == Error {
    @discardableResult
    public static func handleError(priority: TaskPriority? = nil, operation: @escaping @Sendable () async throws -> Success) -> Task<Success?, Never> {
        return Task<Success?, Never>(priority: priority) {
            do {
                return try await operation()
            } catch {
                await MainActor.run {
                    handleGlobalError(error)
                }
                return nil
            }
        }
    }
}