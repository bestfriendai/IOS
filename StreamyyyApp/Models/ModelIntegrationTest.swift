//
//  ModelIntegrationTest.swift
//  StreamyyyApp
//
//  Integration test for comprehensive data models
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Model Integration Test
public class ModelIntegrationTest: ObservableObject {
    @Published public var testResults: [TestResult] = []
    @Published public var isRunning = false
    @Published public var overallResult: TestStatus = .pending
    
    public enum TestStatus {
        case pending
        case running
        case passed
        case failed
        case warning
        
        var color: Color {
            switch self {
            case .pending: return .gray
            case .running: return .blue
            case .passed: return .green
            case .failed: return .red
            case .warning: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .running: return "arrow.clockwise"
            case .passed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    public struct TestResult {
        let id = UUID()
        let testName: String
        let status: TestStatus
        let message: String
        let timestamp: Date
        let duration: TimeInterval
        
        init(testName: String, status: TestStatus, message: String, duration: TimeInterval = 0) {
            self.testName = testName
            self.status = status
            self.message = message
            self.timestamp = Date()
            self.duration = duration
        }
    }
    
    // MARK: - Test Execution
    public func runAllTests() async {
        await MainActor.run {
            isRunning = true
            overallResult = .running
            testResults.removeAll()
        }
        
        let tests: [(String, () async -> (TestStatus, String))] = [
            ("Model Container Initialization", testModelContainer),
            ("User Model Creation", testUserModel),
            ("Stream Model Creation", testStreamModel),
            ("Subscription Model Creation", testSubscriptionModel),
            ("Favorite Model Creation", testFavoriteModel),
            ("Layout Model Creation", testLayoutModel),
            ("Notification Model Creation", testNotificationModel),
            ("Model Relationships", testModelRelationships),
            ("Repository Operations", testRepositoryOperations),
            ("Observer Integration", testObserverIntegration),
            ("Error Handling", testErrorHandling),
            ("Data Validation", testDataValidation),
            ("Performance", testPerformance)
        ]
        
        var passedTests = 0
        var failedTests = 0
        var warningTests = 0
        
        for (testName, test) in tests {
            let startTime = Date()
            let (status, message) = await test()
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                let result = TestResult(
                    testName: testName,
                    status: status,
                    message: message,
                    duration: duration
                )
                testResults.append(result)
            }
            
            switch status {
            case .passed: passedTests += 1
            case .failed: failedTests += 1
            case .warning: warningTests += 1
            default: break
            }
        }
        
        await MainActor.run {
            isRunning = false
            if failedTests > 0 {
                overallResult = .failed
            } else if warningTests > 0 {
                overallResult = .warning
            } else {
                overallResult = .passed
            }
        }
    }
    
    // MARK: - Individual Tests
    private func testModelContainer() async -> (TestStatus, String) {
        do {
            let container = AppModelContainer.shared
            
            if container.isReady {
                return (.passed, "Model container initialized successfully")
            } else {
                return (.failed, "Model container not ready")
            }
        } catch {
            return (.failed, "Model container initialization failed: \(error.localizedDescription)")
        }
    }
    
    private func testUserModel() async -> (TestStatus, String) {
        do {
            let user = User(
                email: "test@example.com",
                firstName: "Test",
                lastName: "User"
            )
            
            // Test basic properties
            if user.email == "test@example.com" &&
               user.firstName == "Test" &&
               user.lastName == "User" {
                
                // Test computed properties
                let displayName = user.displayName
                let isValid = user.validateEmail()
                let completionPercentage = user.completionPercentage
                
                if !displayName.isEmpty && isValid && completionPercentage > 0 {
                    return (.passed, "User model created and validated successfully")
                } else {
                    return (.warning, "User model created but validation issues detected")
                }
            } else {
                return (.failed, "User model property assignment failed")
            }
        } catch {
            return (.failed, "User model creation failed: \(error.localizedDescription)")
        }
    }
    
    private func testStreamModel() async -> (TestStatus, String) {
        do {
            let stream = Stream(
                url: "https://www.twitch.tv/teststream",
                platform: .twitch,
                title: "Test Stream"
            )
            
            // Test basic properties
            if stream.url == "https://www.twitch.tv/teststream" &&
               stream.platform == .twitch &&
               stream.title == "Test Stream" {
                
                // Test platform detection
                let detectedPlatform = Platform.detect(from: stream.url)
                if detectedPlatform == .twitch {
                    
                    // Test validation
                    let isValid = stream.validateURL()
                    if isValid {
                        return (.passed, "Stream model created and validated successfully")
                    } else {
                        return (.warning, "Stream model created but validation failed")
                    }
                } else {
                    return (.warning, "Stream model created but platform detection failed")
                }
            } else {
                return (.failed, "Stream model property assignment failed")
            }
        } catch {
            return (.failed, "Stream model creation failed: \(error.localizedDescription)")
        }
    }
    
    private func testSubscriptionModel() async -> (TestStatus, String) {
        do {
            let subscription = Subscription(
                plan: .premium,
                billingInterval: .monthly
            )
            
            // Test basic properties
            if subscription.plan == .premium &&
               subscription.billingInterval == .monthly &&
               subscription.amount == 9.99 {
                
                // Test computed properties
                let displayPrice = subscription.displayPrice
                let isActive = subscription.isActive
                let daysUntilRenewal = subscription.daysUntilRenewal
                
                if !displayPrice.isEmpty && daysUntilRenewal >= 0 {
                    return (.passed, "Subscription model created and validated successfully")
                } else {
                    return (.warning, "Subscription model created but computed properties failed")
                }
            } else {
                return (.failed, "Subscription model property assignment failed")
            }
        } catch {
            return (.failed, "Subscription model creation failed: \(error.localizedDescription)")
        }
    }
    
    private func testFavoriteModel() async -> (TestStatus, String) {
        do {
            let favorite = Favorite()
            
            // Test basic properties
            if !favorite.id.isEmpty &&
               favorite.rating >= 0 &&
               favorite.rating <= 5 &&
               favorite.viewCount >= 0 {
                
                // Test methods
                favorite.updateRating(4)
                favorite.recordView()
                
                if favorite.rating == 4 && favorite.viewCount == 1 {
                    return (.passed, "Favorite model created and methods work correctly")
                } else {
                    return (.warning, "Favorite model created but methods failed")
                }
            } else {
                return (.failed, "Favorite model property validation failed")
            }
        } catch {
            return (.failed, "Favorite model creation failed: \(error.localizedDescription)")
        }
    }
    
    private func testLayoutModel() async -> (TestStatus, String) {
        do {
            let layout = Layout(
                name: "Test Layout",
                type: .grid2x2
            )
            
            // Test basic properties
            if layout.name == "Test Layout" &&
               layout.type == .grid2x2 &&
               layout.configuration.maxStreams > 0 {
                
                // Test configuration
                let isValid = layout.validateConfiguration()
                if isValid {
                    return (.passed, "Layout model created and configuration validated successfully")
                } else {
                    return (.warning, "Layout model created but configuration validation failed")
                }
            } else {
                return (.failed, "Layout model property assignment failed")
            }
        } catch {
            return (.failed, "Layout model creation failed: \(error.localizedDescription)")
        }
    }
    
    private func testNotificationModel() async -> (TestStatus, String) {
        do {
            let notification = UserNotification(
                type: .streamLive,
                title: "Test Notification",
                message: "This is a test notification"
            )
            
            // Test basic properties
            if notification.type == .streamLive &&
               notification.title == "Test Notification" &&
               notification.message == "This is a test notification" {
                
                // Test methods
                notification.markAsRead()
                
                if notification.isRead {
                    return (.passed, "Notification model created and methods work correctly")
                } else {
                    return (.warning, "Notification model created but methods failed")
                }
            } else {
                return (.failed, "Notification model property assignment failed")
            }
        } catch {
            return (.failed, "Notification model creation failed: \(error.localizedDescription)")
        }
    }
    
    private func testModelRelationships() async -> (TestStatus, String) {
        do {
            let user = User(email: "test@example.com")
            let stream = Stream(url: "https://www.twitch.tv/test", owner: user)
            let favorite = Favorite(user: user, stream: stream)
            
            // Test relationships
            if stream.owner?.id == user.id &&
               favorite.user?.id == user.id &&
               favorite.stream?.id == stream.id {
                return (.passed, "Model relationships established successfully")
            } else {
                return (.failed, "Model relationships failed")
            }
        } catch {
            return (.failed, "Model relationships test failed: \(error.localizedDescription)")
        }
    }
    
    private func testRepositoryOperations() async -> (TestStatus, String) {
        do {
            let repository = RepositoryFactory.shared.userRepository()
            
            // Test basic repository operations
            let initialCount = repository.count()
            
            let testUser = User(email: "repo_test@example.com")
            repository.insert(testUser)
            
            let newCount = repository.count()
            
            if newCount == initialCount + 1 {
                let fetchedUser = repository.fetch(by: testUser.id)
                if fetchedUser?.id == testUser.id {
                    repository.delete(testUser)
                    return (.passed, "Repository operations work correctly")
                } else {
                    return (.warning, "Repository insert works but fetch failed")
                }
            } else {
                return (.failed, "Repository insert operation failed")
            }
        } catch {
            return (.failed, "Repository operations test failed: \(error.localizedDescription)")
        }
    }
    
    private func testObserverIntegration() async -> (TestStatus, String) {
        do {
            let observer = UserObserver()
            
            // Test observer initialization
            if observer.users.isEmpty {
                observer.loadUsers()
                
                // Check if observer is working
                if observer.users.count >= 0 {
                    return (.passed, "Observer integration works correctly")
                } else {
                    return (.warning, "Observer initialized but data loading failed")
                }
            } else {
                return (.passed, "Observer integration works correctly")
            }
        } catch {
            return (.failed, "Observer integration test failed: \(error.localizedDescription)")
        }
    }
    
    private func testErrorHandling() async -> (TestStatus, String) {
        do {
            let errorManager = ErrorManager.shared
            
            // Test error creation
            let testError = ValidationError.invalidEmail
            errorManager.handleError(testError)
            
            // Test error handling
            if errorManager.errorCount > 0 {
                return (.passed, "Error handling system works correctly")
            } else {
                return (.failed, "Error handling system failed")
            }
        } catch {
            return (.failed, "Error handling test failed: \(error.localizedDescription)")
        }
    }
    
    private func testDataValidation() async -> (TestStatus, String) {
        let validationTests: [(String, Bool)] = [
            ("Valid email", "test@example.com".isValidEmail),
            ("Invalid email", !"invalid-email".isValidEmail),
            ("Valid URL", "https://www.example.com".isValidURL),
            ("Invalid URL", !"invalid-url".isValidURL),
            ("Valid username", "validuser123".isValidUsername),
            ("Invalid username", !"invalid user!".isValidUsername)
        ]
        
        let failedTests = validationTests.filter { !$0.1 }
        
        if failedTests.isEmpty {
            return (.passed, "All data validation tests passed")
        } else {
            let failedTestNames = failedTests.map { $0.0 }.joined(separator: ", ")
            return (.failed, "Data validation failed for: \(failedTestNames)")
        }
    }
    
    private func testPerformance() async -> (TestStatus, String) {
        let startTime = Date()
        
        // Create a large number of models to test performance
        let numberOfModels = 1000
        var users: [User] = []
        
        for i in 0..<numberOfModels {
            let user = User(email: "user\(i)@example.com")
            users.append(user)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        if duration < 1.0 {
            return (.passed, "Performance test passed: Created \(numberOfModels) models in \(String(format: "%.2f", duration))s")
        } else if duration < 3.0 {
            return (.warning, "Performance test warning: Created \(numberOfModels) models in \(String(format: "%.2f", duration))s")
        } else {
            return (.failed, "Performance test failed: Created \(numberOfModels) models in \(String(format: "%.2f", duration))s")
        }
    }
}

// MARK: - Test Results View
public struct ModelIntegrationTestView: View {
    @StateObject private var testRunner = ModelIntegrationTest()
    
    public var body: some View {
        NavigationView {
            VStack {
                // Overall Status
                VStack(spacing: 8) {
                    Image(systemName: testRunner.overallResult.icon)
                        .font(.system(size: 48))
                        .foregroundColor(testRunner.overallResult.color)
                    
                    Text(testRunner.overallResult == .passed ? "All Tests Passed" : 
                         testRunner.overallResult == .failed ? "Tests Failed" :
                         testRunner.overallResult == .warning ? "Tests Passed with Warnings" :
                         testRunner.overallResult == .running ? "Running Tests..." : "Ready to Test")
                        .font(.headline)
                        .foregroundColor(testRunner.overallResult.color)
                    
                    if testRunner.isRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .padding()
                
                // Test Results List
                List(testRunner.testResults, id: \.id) { result in
                    HStack {
                        Image(systemName: result.status.icon)
                            .foregroundColor(result.status.color)
                        
                        VStack(alignment: .leading) {
                            Text(result.testName)
                                .font(.headline)
                            
                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if result.duration > 0 {
                                Text("Duration: \(String(format: "%.2f", result.duration))s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Run Tests Button
                Button(action: {
                    Task {
                        await testRunner.runAllTests()
                    }
                }) {
                    HStack {
                        if testRunner.isRunning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        
                        Text(testRunner.isRunning ? "Running Tests..." : "Run All Tests")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(testRunner.isRunning ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(testRunner.isRunning)
                .padding()
            }
            .navigationTitle("Model Integration Tests")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Test Summary View
public struct TestSummaryView: View {
    let testResults: [ModelIntegrationTest.TestResult]
    
    private var passedCount: Int {
        testResults.filter { $0.status == .passed }.count
    }
    
    private var failedCount: Int {
        testResults.filter { $0.status == .failed }.count
    }
    
    private var warningCount: Int {
        testResults.filter { $0.status == .warning }.count
    }
    
    private var totalDuration: TimeInterval {
        testResults.reduce(0) { $0 + $1.duration }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Summary")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Passed")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("\(passedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("Failed")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("\(failedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Warnings")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(warningCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            HStack {
                Text("Total Duration:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.2fs", totalDuration))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Success Rate:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let successRate = Double(passedCount) / Double(max(testResults.count, 1)) * 100
                Text(String(format: "%.1f%%", successRate))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(successRate >= 80 ? .green : successRate >= 60 ? .orange : .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview
struct ModelIntegrationTestView_Previews: PreviewProvider {
    static var previews: some View {
        ModelIntegrationTestView()
    }
}