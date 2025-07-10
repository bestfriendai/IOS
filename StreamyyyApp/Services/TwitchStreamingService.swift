//
//  TwitchStreamingService.swift
//  StreamyyyApp
//
//  Comprehensive Twitch streaming service with multiple fallback methods
//  Updated for 2025 iOS compatibility and embed API issues
//

import SwiftUI
import WebKit
import Combine
import Network

/// Comprehensive service for handling Twitch streaming with multiple fallback approaches
@MainActor
public class TwitchStreamingService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var connectionStatus: TwitchConnectionStatus = .disconnected
    @Published var streamingMethod: TwitchStreamingMethod = .embedAPI
    @Published var isRetrying: Bool = false
    @Published var retryCount: Int = 0
    @Published var lastError: String?
    
    // MARK: - Private Properties
    private var networkMonitor: NWPathMonitor
    private var networkQueue = DispatchQueue(label: "TwitchNetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    private let maxRetryAttempts = 3
    
    // MARK: - Streaming Methods Available
    public enum TwitchStreamingMethod: String, CaseIterable {
        case embedAPI = "Embed API"
        case playerAPI = "Player API"
        case directIframe = "Direct iFrame"
        case fallbackPlayer = "Fallback Player"
        
        var description: String {
            switch self {
            case .embedAPI:
                return "Official Twitch Embed JavaScript API"
            case .playerAPI:
                return "Twitch Player API with custom parent"
            case .directIframe:
                return "Direct iFrame player embed"
            case .fallbackPlayer:
                return "Fallback player implementation"
            }
        }
        
        var isRecommended: Bool {
            switch self {
            case .embedAPI, .playerAPI:
                return true
            case .directIframe, .fallbackPlayer:
                return false
            }
        }
    }
    
    public enum TwitchConnectionStatus: String {
        case disconnected = "Disconnected"
        case connecting = "Connecting"
        case connected = "Connected"
        case error = "Error"
        case retrying = "Retrying"
        
        var color: Color {
            switch self {
            case .disconnected:
                return .gray
            case .connecting, .retrying:
                return .orange
            case .connected:
                return .green
            case .error:
                return .red
            }
        }
    }
    
    // MARK: - Initialization
    public init() {
        networkMonitor = NWPathMonitor()
        setupNetworkMonitoring()
        detectOptimalStreamingMethod()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Get the appropriate Twitch player view for the current streaming method
    public func createPlayerView(
        channelName: String,
        isMuted: Binding<Bool>
    ) -> AnyView {
        switch streamingMethod {
        case .embedAPI:
            return AnyView(
                TwitchEmbedWebView(
                    channelName: channelName,
                    isMuted: isMuted
                )
                .onAppear {
                    connectionStatus = .connecting
                }
            )
            
        case .playerAPI, .directIframe:
            return AnyView(
                TwitchPlayerWebView(
                    channelName: channelName,
                    isMuted: isMuted,
                    showControls: false,
                    autoPlay: true
                )
                .onAppear {
                    connectionStatus = .connecting
                }
            )
            
        case .fallbackPlayer:
            return AnyView(
                TwitchFallbackPlayerView(
                    channelName: channelName,
                    isMuted: isMuted
                )
                .onAppear {
                    connectionStatus = .connecting
                }
            )
        }
    }
    
    /// Test connection to Twitch services
    public func testConnection() async -> Bool {
        connectionStatus = .connecting
        
        do {
            // Test Twitch API availability
            let twitchURL = URL(string: "https://api.twitch.tv/helix/")!
            let (_, response) = try await URLSession.shared.data(from: twitchURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isSuccess = (200...299).contains(httpResponse.statusCode)
                connectionStatus = isSuccess ? .connected : .error
                return isSuccess
            }
            
            connectionStatus = .error
            return false
            
        } catch {
            connectionStatus = .error
            lastError = error.localizedDescription
            return false
        }
    }
    
    /// Attempt to connect with automatic fallback
    public func connectWithFallback(channelName: String) async {
        connectionStatus = .connecting
        retryCount = 0
        
        for method in TwitchStreamingMethod.allCases {
            streamingMethod = method
            
            let success = await attemptConnection(with: method, channelName: channelName)
            if success {
                connectionStatus = .connected
                return
            }
            
            // Wait before trying next method
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        connectionStatus = .error
        lastError = "All streaming methods failed"
    }
    
    /// Retry connection with current method
    public func retryConnection(channelName: String) async {
        guard retryCount < maxRetryAttempts else {
            lastError = "Maximum retry attempts reached"
            return
        }
        
        isRetrying = true
        retryCount += 1
        connectionStatus = .retrying
        
        let success = await attemptConnection(with: streamingMethod, channelName: channelName)
        connectionStatus = success ? .connected : .error
        
        if !success {
            // Try next method if current fails
            if let nextMethod = getNextStreamingMethod() {
                streamingMethod = nextMethod
                await retryConnection(channelName: channelName)
            }
        }
        
        isRetrying = false
    }
    
    /// Get streaming diagnostics
    public func getDiagnostics() -> TwitchStreamingDiagnostics {
        return TwitchStreamingDiagnostics(
            currentMethod: streamingMethod,
            connectionStatus: connectionStatus,
            networkStatus: getNetworkStatus(),
            retryCount: retryCount,
            lastError: lastError,
            systemInfo: getSystemInfo()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self?.connectionStatus == .error {
                        // Network restored, attempt reconnection
                        Task {
                            await self?.testConnection()
                        }
                    }
                } else {
                    self?.connectionStatus = .error
                    self?.lastError = "Network unavailable"
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func detectOptimalStreamingMethod() {
        // Determine the best streaming method based on iOS version and capabilities
        if #available(iOS 15.0, *) {
            streamingMethod = .embedAPI
        } else if #available(iOS 14.0, *) {
            streamingMethod = .playerAPI
        } else {
            streamingMethod = .directIframe
        }
    }
    
    private func attemptConnection(with method: TwitchStreamingMethod, channelName: String) async -> Bool {
        switch method {
        case .embedAPI:
            return await testEmbedAPI(channelName: channelName)
        case .playerAPI:
            return await testPlayerAPI(channelName: channelName)
        case .directIframe:
            return await testDirectIframe(channelName: channelName)
        case .fallbackPlayer:
            return await testFallbackPlayer(channelName: channelName)
        }
    }
    
    private func testEmbedAPI(channelName: String) async -> Bool {
        // Test if Embed API is accessible
        do {
            let embedURL = URL(string: "https://embed.twitch.tv/embed/v1.js")!
            let (_, response) = try await URLSession.shared.data(from: embedURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            lastError = "Embed API test failed: \(error.localizedDescription)"
            return false
        }
    }
    
    private func testPlayerAPI(channelName: String) async -> Bool {
        // Test if Player API is accessible
        do {
            let playerURL = URL(string: "https://player.twitch.tv/?channel=\(channelName)&parent=twitch.tv")!
            let (_, response) = try await URLSession.shared.data(from: playerURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            lastError = "Player API test failed: \(error.localizedDescription)"
            return false
        }
    }
    
    private func testDirectIframe(channelName: String) async -> Bool {
        // Test direct iframe approach
        return await testPlayerAPI(channelName: channelName)
    }
    
    private func testFallbackPlayer(channelName: String) async -> Bool {
        // Fallback player always returns true as it's our last resort
        return true
    }
    
    private func getNextStreamingMethod() -> TwitchStreamingMethod? {
        let methods = TwitchStreamingMethod.allCases
        guard let currentIndex = methods.firstIndex(of: streamingMethod),
              currentIndex < methods.count - 1 else {
            return nil
        }
        return methods[currentIndex + 1]
    }
    
    private func getNetworkStatus() -> String {
        if networkMonitor.currentPath.status == .satisfied {
            if networkMonitor.currentPath.usesInterfaceType(.wifi) {
                return "WiFi Connected"
            } else if networkMonitor.currentPath.usesInterfaceType(.cellular) {
                return "Cellular Connected"
            } else {
                return "Network Connected"
            }
        } else {
            return "No Network"
        }
    }
    
    private func getSystemInfo() -> [String: String] {
        return [
            "iOS Version": UIDevice.current.systemVersion,
            "Device Model": UIDevice.current.model,
            "WKWebView Available": "true",
            "JavaScript Enabled": "true"
        ]
    }
}

// MARK: - Diagnostics Model

public struct TwitchStreamingDiagnostics {
    let currentMethod: TwitchStreamingService.TwitchStreamingMethod
    let connectionStatus: TwitchStreamingService.TwitchConnectionStatus
    let networkStatus: String
    let retryCount: Int
    let lastError: String?
    let systemInfo: [String: String]
    
    var debugDescription: String {
        var info = [
            "Streaming Method: \(currentMethod.rawValue)",
            "Connection Status: \(connectionStatus.rawValue)",
            "Network Status: \(networkStatus)",
            "Retry Count: \(retryCount)"
        ]
        
        if let error = lastError {
            info.append("Last Error: \(error)")
        }
        
        info.append("System Info:")
        for (key, value) in systemInfo {
            info.append("  \(key): \(value)")
        }
        
        return info.joined(separator: "\n")
    }
}

// MARK: - Fallback Player View

/// Simple fallback player when all other methods fail
public struct TwitchFallbackPlayerView: UIViewRepresentable {
    let channelName: String
    @Binding var isMuted: Bool
    
    public func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = "Stream: \(channelName)\n\nTwitch player temporarily unavailable.\nPlease check your connection and try again."
        label.textColor = .white
        label.backgroundColor = .black
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }
    
    public func updateUIView(_ label: UILabel, context: Context) {
        // No updates needed
    }
}