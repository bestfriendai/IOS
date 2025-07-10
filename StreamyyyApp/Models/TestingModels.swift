//
//  TestingModels.swift
//  StreamyyyApp
//
//  Data models for testing framework and CI/CD integration
//

import Foundation

// MARK: - Test Suite
struct TestSuite: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    var tests: [TestCase]
    let category: TestCategory
    var isEnabled: Bool
    let parallelExecution: Bool
    let timeout: TimeInterval
    var lastExecuted: Date?
    var tags: [String] = []
    var dependencies: [UUID] = [] // Other test suite IDs
    var configuration: TestSuiteConfiguration?
    
    var estimatedDuration: TimeInterval {
        return tests.reduce(0) { $0 + $1.estimatedDuration }
    }
    
    var testCount: Int {
        return tests.count
    }
    
    var averagePassRate: Double {
        // This would be calculated from historical data
        return 0.95 // Placeholder
    }
}

// MARK: - Test Case
struct TestCase: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: TestCategory
    let priority: TestPriority
    let estimatedDuration: TimeInterval
    var tags: [String]
    let requirements: [String]
    let testFunction: () async -> TestResult
    var isEnabled: Bool = true
    var retryCount: Int = 0
    var timeout: TimeInterval?
    var preconditions: [String] = []
    var expectedResults: [String] = []
    var testData: [String: Any] = [:]
    
    // Custom Codable implementation since functions can't be encoded
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, priority, estimatedDuration, tags, requirements
        case isEnabled, retryCount, timeout, preconditions, expectedResults
        case testData
    }
    
    init(id: UUID, name: String, description: String, category: TestCategory, priority: TestPriority, estimatedDuration: TimeInterval, tags: [String], requirements: [String], testFunction: @escaping () async -> TestResult) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.tags = tags
        self.requirements = requirements
        self.testFunction = testFunction
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(TestCategory.self, forKey: .category)
        priority = try container.decode(TestPriority.self, forKey: .priority)
        estimatedDuration = try container.decode(TimeInterval.self, forKey: .estimatedDuration)
        tags = try container.decode([String].self, forKey: .tags)
        requirements = try container.decode([String].self, forKey: .requirements)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0
        timeout = try container.decodeIfPresent(TimeInterval.self, forKey: .timeout)
        preconditions = try container.decodeIfPresent([String].self, forKey: .preconditions) ?? []
        expectedResults = try container.decodeIfPresent([String].self, forKey: .expectedResults) ?? []
        
        // Decode testData as string dictionary
        let stringData = try container.decodeIfPresent([String: String].self, forKey: .testData) ?? [:]
        testData = stringData
        
        // Provide a default test function
        testFunction = { TestResult.createDefault() }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(priority, forKey: .priority)
        try container.encode(estimatedDuration, forKey: .estimatedDuration)
        try container.encode(tags, forKey: .tags)
        try container.encode(requirements, forKey: .requirements)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(timeout, forKey: .timeout)
        try container.encode(preconditions, forKey: .preconditions)
        try container.encode(expectedResults, forKey: .expectedResults)
        
        // Encode testData as string dictionary
        let stringData = testData.mapValues { String(describing: $0) }
        try container.encode(stringData, forKey: .testData)
    }
}

// MARK: - Test Result
struct TestResult: Identifiable, Codable {
    let id: UUID
    let testCase: TestCase
    var status: TestStatus
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var failureReason: String?
    var stackTrace: String?
    var screenshots: [String] = []
    var logs: [String] = []
    var metrics: TestMetrics?
    var retryAttempts: Int = 0
    var environment: String?
    
    static func createDefault() -> TestResult {
        let defaultTestCase = TestCase(
            id: UUID(),
            name: "Default Test",
            description: "Default test case",
            category: .unit,
            priority: .medium,
            estimatedDuration: 0,
            tags: [],
            requirements: [],
            testFunction: { TestResult.createDefault() }
        )
        
        return TestResult(
            id: UUID(),
            testCase: defaultTestCase,
            status: .passed,
            startTime: Date(),
            endTime: Date(),
            duration: 0.0
        )
    }
}

// MARK: - Test Execution
struct TestExecution: Identifiable, Codable {
    let id: UUID
    let testSuite: TestSuite
    let environment: TestEnvironment?
    let startTime: Date
    var endTime: Date?
    var status: TestExecutionStatus = .running
    var results: [TestResult] = []
    var error: Error?
    let configuration: TestExecutionConfiguration
    var artifacts: [TestArtifact] = []
    var cicdContext: CICDContext?
    
    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var passRate: Double {
        let passedTests = results.filter { $0.status == .passed }.count
        return results.count > 0 ? Double(passedTests) / Double(results.count) : 0.0
    }
    
    // Custom Codable implementation for Error
    enum CodingKeys: String, CodingKey {
        case id, testSuite, environment, startTime, endTime, status, results, configuration, artifacts, cicdContext
        case errorDescription
    }
    
    init(id: UUID, testSuite: TestSuite, environment: TestEnvironment?, startTime: Date, configuration: TestExecutionConfiguration) {
        self.id = id
        self.testSuite = testSuite
        self.environment = environment
        self.startTime = startTime
        self.configuration = configuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        testSuite = try container.decode(TestSuite.self, forKey: .testSuite)
        environment = try container.decodeIfPresent(TestEnvironment.self, forKey: .environment)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        status = try container.decode(TestExecutionStatus.self, forKey: .status)
        results = try container.decode([TestResult].self, forKey: .results)
        configuration = try container.decode(TestExecutionConfiguration.self, forKey: .configuration)
        artifacts = try container.decodeIfPresent([TestArtifact].self, forKey: .artifacts) ?? []
        cicdContext = try container.decodeIfPresent(CICDContext.self, forKey: .cicdContext)
        
        // Handle error
        if let errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription) {
            error = TestingError.executionFailed(errorDescription)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(testSuite, forKey: .testSuite)
        try container.encodeIfPresent(environment, forKey: .environment)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(status, forKey: .status)
        try container.encode(results, forKey: .results)
        try container.encode(configuration, forKey: .configuration)
        try container.encode(artifacts, forKey: .artifacts)
        try container.encodeIfPresent(cicdContext, forKey: .cicdContext)
        
        // Handle error
        if let error = error {
            try container.encode(error.localizedDescription, forKey: .errorDescription)
        }
    }
}

// MARK: - Enums
enum TestCategory: String, CaseIterable, Codable {
    case unit = "unit"
    case integration = "integration"
    case ui = "ui"
    case performance = "performance"
    case security = "security"
    case regression = "regression"
    case endToEnd = "end_to_end"
    case api = "api"
    case accessibility = "accessibility"
    case compatibility = "compatibility"
    
    var displayName: String {
        switch self {
        case .unit: return "Unit Tests"
        case .integration: return "Integration Tests"
        case .ui: return "UI Tests"
        case .performance: return "Performance Tests"
        case .security: return "Security Tests"
        case .regression: return "Regression Tests"
        case .endToEnd: return "End-to-End Tests"
        case .api: return "API Tests"
        case .accessibility: return "Accessibility Tests"
        case .compatibility: return "Compatibility Tests"
        }
    }
}

enum TestPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var order: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

enum TestStatus: String, CaseIterable, Codable {
    case passed = "passed"
    case failed = "failed"
    case skipped = "skipped"
    case running = "running"
    case pending = "pending"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .skipped: return "Skipped"
        case .running: return "Running"
        case .pending: return "Pending"
        case .error: return "Error"
        }
    }
    
    var color: String {
        switch self {
        case .passed: return "green"
        case .failed: return "red"
        case .skipped: return "yellow"
        case .running: return "blue"
        case .pending: return "gray"
        case .error: return "orange"
        }
    }
}

enum TestExecutionStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case running = "running"
    case passed = "passed"
    case failed = "failed"
    case cancelled = "cancelled"
    case timeout = "timeout"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .timeout: return "Timeout"
        }
    }
}

// MARK: - Test Configuration
struct TestSuiteConfiguration: Codable {
    var maxRetries: Int = 1
    var failFast: Bool = false
    var captureScreenshots: Bool = true
    var captureVideos: Bool = false
    var generateReports: Bool = true
    var notifyOnFailure: Bool = true
    var cleanupAfterExecution: Bool = true
    var environmentVariables: [String: String] = [:]
    var customSettings: [String: String] = [:]
}

struct TestExecutionConfiguration: Codable {
    let parallel: Bool
    let retryCount: Int
    let timeout: TimeInterval
    let captureScreenshots: Bool
    let captureVideos: Bool
    let generateReports: Bool
    var deviceConfiguration: DeviceConfiguration?
    var networkConditions: NetworkConditions?
    var customParameters: [String: String] = [:]
}

struct DeviceConfiguration: Codable {
    let deviceType: String
    let osVersion: String
    let orientation: String
    let locale: String
    let timezone: String
    var accessibility: AccessibilityConfiguration?
}

struct AccessibilityConfiguration: Codable {
    let voiceOverEnabled: Bool
    let dynamicTypeSize: String
    let reduceMotionEnabled: Bool
    let highContrastEnabled: Bool
}

struct NetworkConditions: Codable {
    let connectionType: String
    let bandwidth: Double
    let latency: Double
    let packetLoss: Double
}

// MARK: - Test Environment
struct TestEnvironment: Identifiable, Codable {
    let id = UUID()
    let name: String
    let baseURL: String
    let apiKey: String?
    let databaseURL: String?
    var isActive: Bool = true
    var configuration: [String: String] = [:]
    var secrets: [String: String] = [:]
    var healthCheckURL: String?
    var deploymentInfo: DeploymentInfo?
    
    init(name: String, baseURL: String, apiKey: String? = nil, databaseURL: String? = nil) {
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.databaseURL = databaseURL
    }
}

struct DeploymentInfo: Codable {
    let version: String
    let buildNumber: String
    let deploymentDate: Date
    let commitHash: String?
    let branch: String?
}

// MARK: - Test Metrics
struct TestMetrics: Codable {
    let cpuUsage: Double
    let memoryUsage: Double
    let networkUsage: Double
    let batteryUsage: Double?
    let frameRate: Double?
    let loadTime: Double?
    let responseTime: Double?
    var customMetrics: [String: Double] = [:]
}

// MARK: - Test Artifacts
struct TestArtifact: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: ArtifactType
    let filePath: String
    let size: Int64
    let createdAt: Date
    var metadata: [String: String] = [:]
}

enum ArtifactType: String, CaseIterable, Codable {
    case screenshot = "screenshot"
    case video = "video"
    case log = "log"
    case report = "report"
    case crashLog = "crash_log"
    case performanceTrace = "performance_trace"
    case coverage = "coverage"
    
    var displayName: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .video: return "Video"
        case .log: return "Log"
        case .report: return "Report"
        case .crashLog: return "Crash Log"
        case .performanceTrace: return "Performance Trace"
        case .coverage: return "Coverage"
        }
    }
}

// MARK: - Test Automation
struct TestScheduleItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let testSuites: [UUID]
    let schedule: TestSchedule
    var isEnabled: Bool
    let environment: TestEnvironment?
    var lastExecution: Date?
    var nextExecution: Date?
    var notificationSettings: NotificationSettings?
}

enum TestSchedule: Codable {
    case hourly
    case daily(hour: Int, minute: Int)
    case weekly(day: Int, hour: Int, minute: Int)
    case manual
    
    var displayName: String {
        switch self {
        case .hourly: return "Every hour"
        case .daily(let hour, let minute): return "Daily at \(hour):\(String(format: "%02d", minute))"
        case .weekly(let day, let hour, let minute): return "Weekly on day \(day) at \(hour):\(String(format: "%02d", minute))"
        case .manual: return "Manual trigger"
        }
    }
}

struct NotificationSettings: Codable {
    let emailNotifications: Bool
    let slackNotifications: Bool
    let webhookURL: String?
    let notifyOnFailure: Bool
    let notifyOnSuccess: Bool
    let recipients: [String]
}

// MARK: - CI/CD Integration
struct CICDConfiguration: Codable {
    var provider: CICDProvider = .github
    var webhookURL: String = ""
    var apiToken: String = ""
    var branchTriggers: [String] = []
    var pullRequestTesting: Bool = true
    var deploymentGates: [DeploymentGate] = []
    var buildConfiguration: BuildConfiguration?
    var artifactStorage: ArtifactStorage?
}

enum CICDProvider: String, CaseIterable, Codable {
    case github = "github"
    case gitlab = "gitlab"
    case jenkins = "jenkins"
    case azure = "azure"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .github: return "GitHub Actions"
        case .gitlab: return "GitLab CI"
        case .jenkins: return "Jenkins"
        case .azure: return "Azure DevOps"
        case .custom: return "Custom"
        }
    }
}

struct DeploymentGate: Identifiable, Codable {
    let id = UUID()
    let name: String
    let requiredTestSuites: [UUID]
    let passingThreshold: Double
    var isEnabled: Bool = true
    var timeoutMinutes: Int = 30
}

struct BuildConfiguration: Codable {
    let scheme: String
    let configuration: String
    let archivePath: String?
    let exportOptions: [String: Any]
    
    // Custom Codable implementation for Any type
    enum CodingKeys: String, CodingKey {
        case scheme, configuration, archivePath, exportOptions
    }
    
    init(scheme: String, configuration: String, archivePath: String? = nil, exportOptions: [String: Any] = [:]) {
        self.scheme = scheme
        self.configuration = configuration
        self.archivePath = archivePath
        self.exportOptions = exportOptions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheme = try container.decode(String.self, forKey: .scheme)
        configuration = try container.decode(String.self, forKey: .configuration)
        archivePath = try container.decodeIfPresent(String.self, forKey: .archivePath)
        let stringOptions = try container.decodeIfPresent([String: String].self, forKey: .exportOptions) ?? [:]
        exportOptions = stringOptions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheme, forKey: .scheme)
        try container.encode(configuration, forKey: .configuration)
        try container.encodeIfPresent(archivePath, forKey: .archivePath)
        let stringOptions = exportOptions.mapValues { String(describing: $0) }
        try container.encode(stringOptions, forKey: .exportOptions)
    }
}

struct ArtifactStorage: Codable {
    let provider: String
    let bucket: String
    let region: String?
    let accessKey: String?
    let retentionDays: Int
}

struct CICDEvent: Codable {
    let type: CICDEventType
    let branch: String
    let commit: String
    let author: String
    let timestamp: Date
    let pullRequestNumber: Int?
    var metadata: [String: String] = [:]
}

enum CICDEventType: String, CaseIterable, Codable {
    case push = "push"
    case pullRequest = "pull_request"
    case deployment = "deployment"
    case scheduled = "scheduled"
    
    var displayName: String {
        switch self {
        case .push: return "Push"
        case .pullRequest: return "Pull Request"
        case .deployment: return "Deployment"
        case .scheduled: return "Scheduled"
        }
    }
}

struct CICDContext: Codable {
    let buildNumber: String
    let jobId: String
    let runId: String
    let actor: String
    let repository: String
    let ref: String
    let sha: String
    let workflow: String?
}

// MARK: - Test Coverage
struct CodeCoverage: Codable {
    var totalLines: Int = 0
    var coveredLines: Int = 0
    var percentage: Double = 0.0
    var lastUpdated: Date = Date()
    var moduleCoverage: [String: Double] = [:]
    var fileCoverage: [String: FileCoverage] = [:]
    var thresholds: CoverageThresholds = CoverageThresholds()
    
    var grade: CoverageGrade {
        if percentage >= 0.9 { return .excellent }
        else if percentage >= 0.8 { return .good }
        else if percentage >= 0.7 { return .fair }
        else if percentage >= 0.6 { return .poor }
        else { return .critical }
    }
}

struct FileCoverage: Codable {
    let filePath: String
    let totalLines: Int
    let coveredLines: Int
    let percentage: Double
    let functions: [FunctionCoverage]
}

struct FunctionCoverage: Codable {
    let name: String
    let lineNumber: Int
    let isCovered: Bool
    let callCount: Int
}

struct CoverageThresholds: Codable {
    let minimum: Double = 0.8
    let target: Double = 0.9
    let excellent: Double = 0.95
}

enum CoverageGrade: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent (90%+)"
        case .good: return "Good (80-89%)"
        case .fair: return "Fair (70-79%)"
        case .poor: return "Poor (60-69%)"
        case .critical: return "Critical (<60%)"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Test Reporting
struct TestReport: Identifiable, Codable {
    let id = UUID()
    let execution: TestExecution
    let summary: TestSummary
    let coverage: CodeCoverage
    let recommendations: [TestRecommendation]
    let generatedAt: Date = Date()
    var distribution: TestDistribution?
    var trends: TestTrends?
    var flakiness: FlakinessReport?
}

struct TestSummary: Codable {
    let totalTests: Int
    let passedTests: Int
    let failedTests: Int
    let skippedTests: Int
    let executionTime: TimeInterval
    let passRate: Double
    var failureAnalysis: [FailureAnalysis] = []
    var performanceMetrics: TestPerformanceMetrics?
}

struct TestDistribution: Codable {
    let byCategory: [String: Int]
    let byPriority: [String: Int]
    let byDuration: [String: Int]
    let byStatus: [String: Int]
}

struct TestTrends: Codable {
    let passRateTrend: [Double]
    let executionTimeTrend: [Double]
    let flakinessTrend: [Double]
    let coverageTrend: [Double]
    let periodDays: Int
}

struct FlakinessReport: Codable {
    let flakyTests: [FlakyTest]
    let overallFlakinessScore: Double
    let recommendations: [String]
}

struct FlakyTest: Identifiable, Codable {
    let id = UUID()
    let testName: String
    let flakinessScore: Double
    let totalRuns: Int
    let failures: Int
    let successRate: Double
    let lastFailure: Date?
    let possibleCauses: [String]
}

struct FailureAnalysis: Codable {
    let category: String
    let count: Int
    let percentage: Double
    let topReasons: [String]
    let recommendedActions: [String]
}

struct TestPerformanceMetrics: Codable {
    let averageExecutionTime: TimeInterval
    let slowestTests: [String]
    let fastestTests: [String]
    let timeoutTests: [String]
    let memoryUsage: Double
    let cpuUsage: Double
}

struct TestRecommendation: Identifiable, Codable {
    let id = UUID()
    let type: RecommendationType
    let priority: TestPriority
    let title: String
    let description: String
    let action: String
    var isImplemented: Bool = false
    var implementedAt: Date?
}

enum RecommendationType: String, CaseIterable, Codable {
    case quality = "quality"
    case performance = "performance"
    case coverage = "coverage"
    case maintenance = "maintenance"
    case infrastructure = "infrastructure"
    
    var displayName: String {
        switch self {
        case .quality: return "Quality"
        case .performance: return "Performance"
        case .coverage: return "Coverage"
        case .maintenance: return "Maintenance"
        case .infrastructure: return "Infrastructure"
        }
    }
}

// MARK: - Test Data Management
class TestDataManager: ObservableObject {
    @Published var testDataSets: [TestDataSet] = []
    @Published var mockData: [String: Any] = [:]
    
    func loadTestDataSets() {
        testDataSets = [
            TestDataSet(
                name: "Sample Users",
                description: "Sample user data for testing",
                data: [
                    "users": [
                        ["id": "1", "name": "Test User 1", "email": "test1@example.com"],
                        ["id": "2", "name": "Test User 2", "email": "test2@example.com"]
                    ]
                ],
                testSuite: "Integration"
            ),
            TestDataSet(
                name: "Sample Streams",
                description: "Sample stream data for testing",
                data: [
                    "streams": [
                        ["id": "1", "title": "Test Stream 1", "platform": "twitch"],
                        ["id": "2", "title": "Test Stream 2", "platform": "youtube"]
                    ]
                ],
                testSuite: "UI"
            )
        ]
    }
}

// MARK: - Mock Service Manager
class MockServiceManager: ObservableObject {
    @Published var mockServices: [String: MockService] = [:]
    
    func setupMockStreams() {
        mockServices["streams"] = MockService(
            name: "Stream Service",
            endpoints: [
                "GET /streams": MockResponse(statusCode: 200, data: ["streams": []]),
                "POST /streams": MockResponse(statusCode: 201, data: ["id": "123"])
            ]
        )
    }
    
    func setupMockUsers() {
        mockServices["users"] = MockService(
            name: "User Service",
            endpoints: [
                "GET /users/me": MockResponse(statusCode: 200, data: ["id": "1", "name": "Test User"]),
                "POST /users": MockResponse(statusCode: 201, data: ["id": "123"])
            ]
        )
    }
    
    func setupMockAnalytics() {
        mockServices["analytics"] = MockService(
            name: "Analytics Service",
            endpoints: [
                "POST /analytics": MockResponse(statusCode: 200, data: ["success": true])
            ]
        )
    }
}

struct MockService: Codable {
    let name: String
    let endpoints: [String: MockResponse]
}

struct MockResponse: Codable {
    let statusCode: Int
    let data: [String: Any]
    let delay: TimeInterval
    
    init(statusCode: Int, data: [String: Any], delay: TimeInterval = 0.1) {
        self.statusCode = statusCode
        self.data = data
        self.delay = delay
    }
    
    // Custom Codable implementation for Any type
    enum CodingKeys: String, CodingKey {
        case statusCode, delay, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statusCode = try container.decode(Int.self, forKey: .statusCode)
        delay = try container.decode(TimeInterval.self, forKey: .delay)
        let stringData = try container.decode([String: String].self, forKey: .data)
        data = stringData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(delay, forKey: .delay)
        let stringData = data.mapValues { String(describing: $0) }
        try container.encode(stringData, forKey: .data)
    }
}