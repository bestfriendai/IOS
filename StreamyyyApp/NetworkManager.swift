//
//  NetworkManager.swift
//  StreamyyyApp
//
//  Network layer for API communication
//

import Foundation
import Combine
import SwiftUI
import Network

// MARK: - Enhanced Network Manager
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType = .wifi
    @Published var connectionQuality: ConnectionQuality = .excellent
    @Published var lastConnectedAt: Date = Date()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // Network statistics
    @Published var bytesReceived: Int64 = 0
    @Published var bytesSent: Int64 = 0
    @Published var requestCount: Int = 0
    @Published var errorCount: Int = 0
    
    // Connection quality metrics
    private var latencyHistory: [TimeInterval] = []
    private var bandwidthHistory: [Double] = []
    
    private init() {
        startMonitoring()
        startMetricsCollection()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                
                if let interface = path.availableInterfaces.first {
                    self?.connectionType = interface.type
                }
                
                if !wasConnected && path.status == .satisfied {
                    self?.lastConnectedAt = Date()
                }
                
                self?.updateConnectionQuality(path: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    private func updateConnectionQuality(path: NWPath) {
        // Assess connection quality based on interface type and status
        switch (path.status, connectionType) {
        case (.satisfied, .wifi):
            connectionQuality = .excellent
        case (.satisfied, .cellular):
            connectionQuality = .good
        case (.satisfied, .wiredEthernet):
            connectionQuality = .excellent
        case (.requiresConnection, _):
            connectionQuality = .poor
        default:
            connectionQuality = .poor
        }
    }
    
    private func startMetricsCollection() {
        // Collect network metrics every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.collectNetworkMetrics()
        }
    }
    
    private func collectNetworkMetrics() {
        // This would collect actual network statistics
        // For now, we'll just update the timestamp
        if isConnected {
            lastConnectedAt = Date()
        }
    }
    
    // MARK: - Public Methods
    
    func recordRequest() {
        requestCount += 1
    }
    
    func recordError() {
        errorCount += 1
    }
    
    func recordLatency(_ latency: TimeInterval) {
        latencyHistory.append(latency)
        if latencyHistory.count > 100 {
            latencyHistory.removeFirst()
        }
    }
    
    func recordBandwidth(_ bandwidth: Double) {
        bandwidthHistory.append(bandwidth)
        if bandwidthHistory.count > 100 {
            bandwidthHistory.removeFirst()
        }
    }
    
    var averageLatency: TimeInterval {
        guard !latencyHistory.isEmpty else { return 0 }
        return latencyHistory.reduce(0, +) / Double(latencyHistory.count)
    }
    
    var averageBandwidth: Double {
        guard !bandwidthHistory.isEmpty else { return 0 }
        return bandwidthHistory.reduce(0, +) / Double(bandwidthHistory.count)
    }
    
    var errorRate: Double {
        guard requestCount > 0 else { return 0 }
        return Double(errorCount) / Double(requestCount)
    }
    
    var connectionStatusText: String {
        if isConnected {
            return "Connected via \(connectionType.displayName)"
        } else {
            return "Disconnected"
        }
    }
    
    var shouldUseOfflineMode: Bool {
        return !isConnected || connectionQuality == .poor
    }
}

// MARK: - Connection Quality
enum ConnectionQuality {
    case excellent
    case good
    case fair
    case poor
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Interface Type Extension
extension NWInterface.InterfaceType {
    var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Enhanced API Client
class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let networkManager = NetworkManager.shared
    
    // Request metrics
    @Published var activeRequests: Int = 0
    @Published var totalRequests: Int = 0
    @Published var successfulRequests: Int = 0
    @Published var failedRequests: Int = 0
    
    // Rate limiting
    private var requestQueue = DispatchQueue(label: "api.request.queue", qos: .utility)
    private var rateLimiters: [String: RateLimiter] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        // Enable HTTP/2 and HTTP/3 support
        config.httpMaximumConnectionsPerHost = 6
        config.httpShouldUsePipelining = true
        
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        setupRateLimiters()
    }
    
    private func setupRateLimiters() {
        // Twitch API rate limits
        rateLimiters["api.twitch.tv"] = RateLimiter(maxRequests: 800, timeWindow: 60)
        // YouTube API rate limits
        rateLimiters["googleapis.com"] = RateLimiter(maxRequests: 100, timeWindow: 60)
    }
    
    // MARK: - Enhanced Request Method
    func request<T: Codable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        retryCount: Int = 3,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) -> AnyPublisher<T, APIError> {
        
        guard let url = endpoint.url else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        // Check network connectivity
        guard networkManager.isConnected else {
            return Fail(error: APIError.networkError(URLError(.notConnectedToInternet)))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.headers
        request.cachePolicy = cachePolicy
        
        // Set user agent
        request.setValue("StreamyyyApp/\(Config.App.version) (iOS)", forHTTPHeaderField: "User-Agent")
        
        if let body = endpoint.body {
            do {
                request.httpBody = try encoder.encode(body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                return Fail(error: APIError.encodingError(error))
                    .eraseToAnyPublisher()
            }
        }
        
        return performRequestWithRetry(request: request, retryCount: retryCount)
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                self.failedRequests += 1
                self.networkManager.recordError()
                
                if error is DecodingError {
                    return APIError.decodingError(error)
                } else {
                    return APIError.networkError(error)
                }
            }
            .handleEvents(
                receiveSubscription: { _ in
                    self.activeRequests += 1
                    self.totalRequests += 1
                    self.networkManager.recordRequest()
                },
                receiveOutput: { _ in
                    self.successfulRequests += 1
                },
                receiveCompletion: { _ in
                    self.activeRequests -= 1
                }
            )
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func performRequestWithRetry(request: URLRequest, retryCount: Int) -> AnyPublisher<Data, Error> {
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.unknown
                }
                
                // Handle HTTP status codes
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw APIError.unauthorized
                case 404:
                    throw APIError.notFound
                case 429:
                    throw APIError.rateLimited
                case 500...599:
                    throw APIError.serverError(httpResponse.statusCode, nil)
                default:
                    throw APIError.unknown
                }
            }
            .retry(retryCount)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Stream Data Requests
    func fetchStreamData(url: String) -> AnyPublisher<StreamData, APIError> {
        let endpoint = APIEndpoint.streamData(url: url)
        return request(endpoint: endpoint, responseType: StreamData.self)
    }
    
    func fetchPopularStreams(platform: String? = nil) -> AnyPublisher<[StreamData], APIError> {
        let endpoint = APIEndpoint.popularStreams(platform: platform)
        return request(endpoint: endpoint, responseType: [StreamData].self, cachePolicy: .returnCacheDataElseLoad)
    }
    
    func searchStreams(query: String, platform: String? = nil) -> AnyPublisher<[StreamData], APIError> {
        let endpoint = APIEndpoint.searchStreams(query: query, platform: platform)
        return request(endpoint: endpoint, responseType: [StreamData].self)
    }
    
    // MARK: - User Data Requests
    func fetchUserProfile(userId: String) -> AnyPublisher<UserProfile, APIError> {
        let endpoint = APIEndpoint.userProfile(userId: userId)
        return request(endpoint: endpoint, responseType: UserProfile.self)
    }
    
    func updateUserProfile(userId: String, profile: UserProfile) -> AnyPublisher<UserProfile, APIError> {
        let endpoint = APIEndpoint.updateUserProfile(userId: userId, profile: profile)
        return request(endpoint: endpoint, responseType: UserProfile.self)
    }
    
    // MARK: - Real-time Updates
    func createStreamStatusPublisher(streamIds: [String]) -> AnyPublisher<[StreamStatus], APIError> {
        // This would create a publisher that periodically checks stream status
        return Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .flatMap { _ in
                self.fetchStreamStatuses(streamIds: streamIds)
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchStreamStatuses(streamIds: [String]) -> AnyPublisher<[StreamStatus], APIError> {
        // This would fetch the current status of multiple streams
        return Just(streamIds.map { StreamStatus(id: $0, isLive: true, viewerCount: 0, updatedAt: Date()) })
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Metrics
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    var errorRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(failedRequests) / Double(totalRequests)
    }
}

// MARK: - Rate Limiter
class RateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "rate.limiter", attributes: .concurrent)
    
    init(maxRequests: Int, timeWindow: TimeInterval) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func canMakeRequest() -> Bool {
        return queue.sync {
            let now = Date()
            let cutoff = now.addingTimeInterval(-timeWindow)
            
            // Remove old requests
            requestTimes = requestTimes.filter { $0 > cutoff }
            
            return requestTimes.count < maxRequests
        }
    }
    
    func recordRequest() {
        queue.async(flags: .barrier) {
            self.requestTimes.append(Date())
        }
    }
}

// MARK: - Stream Status
struct StreamStatus: Codable {
    let id: String
    let isLive: Bool
    let viewerCount: Int
    let updatedAt: Date
}

// MARK: - API Endpoints
enum APIEndpoint {
    case streamData(url: String)
    case popularStreams(platform: String?)
    case searchStreams(query: String, platform: String?)
    case userProfile(userId: String)
    case updateUserProfile(userId: String, profile: UserProfile)
    
    var url: URL? {
        var components = URLComponents(string: Config.API.baseURL)
        
        switch self {
        case .streamData(let url):
            components?.path = "/api/v1/streams/data"
            components?.queryItems = [URLQueryItem(name: "url", value: url)]
            
        case .popularStreams(let platform):
            components?.path = "/api/v1/streams/popular"
            if let platform = platform {
                components?.queryItems = [URLQueryItem(name: "platform", value: platform)]
            }
            
        case .searchStreams(let query, let platform):
            components?.path = "/api/v1/streams/search"
            var queryItems = [URLQueryItem(name: "q", value: query)]
            if let platform = platform {
                queryItems.append(URLQueryItem(name: "platform", value: platform))
            }
            components?.queryItems = queryItems
            
        case .userProfile(let userId):
            components?.path = "/api/v1/users/\(userId)"
            
        case .updateUserProfile(let userId, _):
            components?.path = "/api/v1/users/\(userId)"
        }
        
        return components?.url
    }
    
    var method: HTTPMethod {
        switch self {
        case .streamData, .popularStreams, .searchStreams, .userProfile:
            return .GET
        case .updateUserProfile:
            return .PUT
        }
    }
    
    var headers: [String: String] {
        var headers = [
            "Accept": "application/json",
            "User-Agent": "StreamyyyApp/\(Config.App.version)"
        ]
        
        // Add authorization header if needed
        // TODO: Fix concurrency issue
        // if let token = AuthenticationManager.shared.currentUser?.accessToken {
        //     headers["Authorization"] = "Bearer \(token)"
        // }
        
        return headers
    }
    
    var body: Codable? {
        switch self {
        case .updateUserProfile(_, let profile):
            return profile
        default:
            return nil
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - API Error
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
    case serverError(Int, String?)
    case unauthorized
    case notFound
    case rateLimited
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("Invalid URL", comment: "")
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError:
            return NSLocalizedString("Failed to decode response", comment: "")
        case .encodingError:
            return NSLocalizedString("Failed to encode request", comment: "")
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .unauthorized:
            return NSLocalizedString("Unauthorized access", comment: "")
        case .notFound:
            return NSLocalizedString("Resource not found", comment: "")
        case .rateLimited:
            return NSLocalizedString("Too many requests. Please try again later.", comment: "")
        case .unknown:
            return NSLocalizedString("An unknown error occurred", comment: "")
        }
    }
}

// MARK: - Data Models
struct StreamData: Codable, Identifiable {
    let id: String
    let title: String
    let streamerName: String
    let platform: String
    let url: String
    let embedUrl: String?
    let thumbnailUrl: String?
    let isLive: Bool
    let viewerCount: Int?
    let category: String?
    let tags: [String]?
    let startedAt: Date?
    let language: String?
    
    var displayViewerCount: String {
        guard let count = viewerCount else { return "" }
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
}

struct UserProfile: Codable {
    let id: String
    var email: String
    var fullName: String
    var avatarUrl: String?
    var preferences: UserPreferences
    var subscription: SubscriptionInfo?
    let createdAt: Date
    var updatedAt: Date
}

struct UserPreferences: Codable {
    var theme: String = "system"
    var autoPlay: Bool = true
    var notifications: Bool = true
    var quality: String = "auto"
    var defaultLayout: String = "grid"
}

struct SubscriptionInfo: Codable {
    let id: String
    let plan: String
    let status: String
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let cancelAtPeriodEnd: Bool
}

// MARK: - Enhanced Cache Manager
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let metadataDirectory: URL
    
    // Cache statistics
    @Published var cacheSize: Int64 = 0
    @Published var hitCount: Int = 0
    @Published var missCount: Int = 0
    @Published var totalItems: Int = 0
    
    // Cache expiration tracking
    private var expirationTimes: [String: Date] = [:]
    private let expirationQueue = DispatchQueue(label: "cache.expiration", qos: .utility)
    
    private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("StreamyyyCache")
        metadataDirectory = cacheDirectory.appendingPathComponent("metadata")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache limits
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        
        // Load expiration metadata
        loadExpirationMetadata()
        
        // Start cleanup timer
        startCleanupTimer()
        
        // Calculate initial cache size
        calculateCacheSize()
    }
    
    // MARK: - Storage Methods
    
    func store<T: Codable>(_ object: T, forKey key: String, expiration: TimeInterval = 3600) {
        do {
            let data = try JSONEncoder().encode(object)
            let cost = data.count
            
            // Store in memory cache
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: cost)
            
            // Store to disk for persistence
            let url = cacheDirectory.appendingPathComponent(key)
            try data.write(to: url)
            
            // Store expiration time
            expirationQueue.async {
                self.expirationTimes[key] = Date().addingTimeInterval(expiration)
                self.saveExpirationMetadata()
            }
            
            // Update statistics
            updateCacheStatistics()
            
        } catch {
            print("Failed to cache object: \(error)")
        }
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // Check if item has expired
        if let expirationTime = expirationTimes[key], expirationTime < Date() {
            remove(forKey: key)
            missCount += 1
            return nil
        }
        
        // Try memory cache first
        if let data = memoryCache.object(forKey: key as NSString) as Data? {
            hitCount += 1
            return try? JSONDecoder().decode(type, from: data)
        }
        
        // Try disk cache
        let url = cacheDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: url) else {
            missCount += 1
            return nil
        }
        
        let object = try? JSONDecoder().decode(type, from: data)
        
        // Store back in memory cache
        if object != nil {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            hitCount += 1
        } else {
            missCount += 1
        }
        
        return object
    }
    
    func remove(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        
        let url = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: url)
        
        expirationQueue.async {
            self.expirationTimes.removeValue(forKey: key)
            self.saveExpirationMetadata()
        }
        
        updateCacheStatistics()
    }
    
    func clearAll() {
        memoryCache.removeAllObjects()
        
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        
        expirationQueue.async {
            self.expirationTimes.removeAll()
            self.saveExpirationMetadata()
        }
        
        updateCacheStatistics()
    }
    
    // MARK: - Specialized Stream Cache Methods
    
    // TODO: Fix Stream Codable issue
    // func storeStreamData(_ streams: [Any], forKey key: String) {
    //     store(streams, forKey: key, expiration: 300) // 5 minutes for stream data
    // }
    
    // TODO: Fix Stream Codable issue
    // func retrieveStreamData(forKey key: String) -> [Any]? {
    //     return retrieve([Any].self, forKey: key)
    // }
    
    func storeThumbnail(_ imageData: Data, forKey key: String) {
        let url = cacheDirectory.appendingPathComponent("thumbnails").appendingPathComponent(key)
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? imageData.write(to: url)
        
        // Store in memory cache too
        memoryCache.setObject(imageData as NSData, forKey: "thumbnail_\(key)" as NSString, cost: imageData.count)
        
        // Set expiration for 1 hour
        expirationQueue.async {
            self.expirationTimes["thumbnail_\(key)"] = Date().addingTimeInterval(3600)
            self.saveExpirationMetadata()
        }
    }
    
    func retrieveThumbnail(forKey key: String) -> Data? {
        let cacheKey = "thumbnail_\(key)"
        
        // Check expiration
        if let expirationTime = expirationTimes[cacheKey], expirationTime < Date() {
            remove(forKey: cacheKey)
            return nil
        }
        
        // Try memory cache
        if let data = memoryCache.object(forKey: cacheKey as NSString) as Data? {
            return data
        }
        
        // Try disk cache
        let url = cacheDirectory.appendingPathComponent("thumbnails").appendingPathComponent(key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        // Store back in memory
        memoryCache.setObject(data as NSData, forKey: cacheKey as NSString, cost: data.count)
        
        return data
    }
    
    // MARK: - Expiration Management
    
    private func loadExpirationMetadata() {
        let url = metadataDirectory.appendingPathComponent("expiration.json")
        guard let data = try? Data(contentsOf: url),
              let metadata = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return
        }
        
        expirationTimes = metadata
    }
    
    private func saveExpirationMetadata() {
        let url = metadataDirectory.appendingPathComponent("expiration.json")
        guard let data = try? JSONEncoder().encode(expirationTimes) else { return }
        try? data.write(to: url)
    }
    
    private func startCleanupTimer() {
        // Clean up expired items every 10 minutes
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            self.cleanupExpiredItems()
        }
    }
    
    private func cleanupExpiredItems() {
        let now = Date()
        let expiredKeys = expirationTimes.compactMap { key, expiration in
            expiration < now ? key : nil
        }
        
        for key in expiredKeys {
            remove(forKey: key)
        }
    }
    
    // MARK: - Statistics
    
    private func updateCacheStatistics() {
        calculateCacheSize()
        totalItems = calculateTotalItems()
    }
    
    private func calculateCacheSize() {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            cacheSize = 0
            return
        }
        
        var totalSize: Int64 = 0
        for case let url as URL in enumerator {
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        cacheSize = totalSize
    }
    
    private func calculateTotalItems() -> Int {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        
        var count = 0
        for _ in enumerator {
            count += 1
        }
        
        return count
    }
    
    var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }
    
    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }
}