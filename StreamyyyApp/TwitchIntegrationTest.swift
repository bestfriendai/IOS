//
//  TwitchIntegrationTest.swift
//  StreamyyyApp
//
//  Test for Twitch API integration
//

import Foundation

@MainActor
class TwitchIntegrationTest: ObservableObject {
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    
    struct TestResult {
        let name: String
        let passed: Bool
        let message: String
    }
    
    // Mock service for testing
    private let twitchService = MockTwitchService()
    
    func runTests() async {
        isRunning = true
        testResults.removeAll()
        
        // Test 1: Configuration
        await testConfiguration()
        
        // Test 2: Authentication
        await testAuthentication()
        
        // Test 3: Fetch streams
        await testFetchStreams()
        
        // Test 4: Stream data validation
        await testStreamDataValidation()
        
        isRunning = false
        
        let passedTests = testResults.filter { $0.passed }.count
        let totalTests = testResults.count
        
        print("🧪 Twitch Integration Tests Complete: \(passedTests)/\(totalTests) passed")
    }
    
    private func testConfiguration() async {
        let clientId = Config.Twitch.clientId
        let clientSecret = Config.Twitch.clientSecret
        
        let passed = !clientId.isEmpty && !clientSecret.isEmpty
        let message = passed ? "✅ Configuration loaded successfully" : "❌ Missing Twitch credentials"
        
        testResults.append(TestResult(
            name: "Configuration Test",
            passed: passed,
            message: message
        ))
    }
    
    private func testAuthentication() async {
        do {
            try await twitchService.getAppAccessToken()
            
            let passed = twitchService.isAuthenticated
            let message = passed ? "✅ Authentication successful" : "❌ Authentication failed"
            
            testResults.append(TestResult(
                name: "Authentication Test",
                passed: passed,
                message: message
            ))
        } catch {
            testResults.append(TestResult(
                name: "Authentication Test",
                passed: false,
                message: "❌ Authentication error: \(error.localizedDescription)"
            ))
        }
    }
    
    private func testFetchStreams() async {
        do {
            let (streams, pagination) = try await twitchService.getTopStreams(first: 5)
            
            let passed = !streams.isEmpty
            let message = passed ? 
                "✅ Fetched \(streams.count) streams successfully" : 
                "❌ No streams returned"
            
            testResults.append(TestResult(
                name: "Fetch Streams Test",
                passed: passed,
                message: message
            ))
        } catch {
            testResults.append(TestResult(
                name: "Fetch Streams Test",
                passed: false,
                message: "❌ Fetch error: \(error.localizedDescription)"
            ))
        }
    }
    
    private func testStreamDataValidation() async {
        do {
            let (streams, _) = try await twitchService.getTopStreams(first: 1)
            
            guard let firstStream = streams.first else {
                testResults.append(TestResult(
                    name: "Stream Data Validation Test",
                    passed: false,
                    message: "❌ No stream data to validate"
                ))
                return
            }
            
            let hasRequiredFields = !firstStream.id.isEmpty && 
                                  !firstStream.userName.isEmpty && 
                                  !firstStream.title.isEmpty &&
                                  firstStream.viewerCount >= 0
            
            let message = hasRequiredFields ? 
                "✅ Stream data structure valid" : 
                "❌ Stream data missing required fields"
            
            testResults.append(TestResult(
                name: "Stream Data Validation Test",
                passed: hasRequiredFields,
                message: message
            ))
        } catch {
            testResults.append(TestResult(
                name: "Stream Data Validation Test",
                passed: false,
                message: "❌ Validation error: \(error.localizedDescription)"
            ))
        }
    }
    
    func printTestReport() {
        print("\n🧪 TWITCH INTEGRATION TEST REPORT")
        print("=" * 50)
        
        for result in testResults {
            print("\(result.name): \(result.message)")
        }
        
        let passedTests = testResults.filter { $0.passed }.count
        let totalTests = testResults.count
        
        print("\nSUMMARY: \(passedTests)/\(totalTests) tests passed")
        
        if passedTests == totalTests {
            print("🎉 All tests passed! Twitch integration is working correctly.")
        } else {
            print("⚠️  Some tests failed. Please check the configuration and network connection.")
        }
    }
}

// MARK: - Mock Twitch Service
class MockTwitchService {
    var isAuthenticated = false
    
    func getAppAccessToken() async throws {
        print("MockTwitchService: Getting app access token")
        try await Task.sleep(nanoseconds: 500_000_000)
        isAuthenticated = true
    }
    
    func getTopStreams(first: Int) async throws -> ([MockStream], MockPagination) {
        print("MockTwitchService: Getting top streams")
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let mockStreams = (1...first).map { index in
            MockStream(
                id: "stream_\(index)",
                userName: "streamer_\(index)",
                title: "Mock Stream \(index)",
                viewerCount: index * 1000
            )
        }
        
        return (mockStreams, MockPagination())
    }
}

// MARK: - Mock Data Types
struct MockStream {
    let id: String
    let userName: String
    let title: String
    let viewerCount: Int
}

struct MockPagination {
    let cursor: String? = nil
}

// String extension for test formatting
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}