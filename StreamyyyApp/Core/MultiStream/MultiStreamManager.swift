//
//  MultiStreamManager.swift
//  StreamyyyApp
//
//  Core multi-stream viewing manager with working video players
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

// MARK: - Multi Stream Manager
class MultiStreamManager: ObservableObject {
    @Published var activeStreams: [StreamSlot] = []
    @Published var currentLayout: MultiStreamLayout = .single
    @Published var focusedStream: StreamSlot?
    @Published var isLoading = false
    
    private var players: [String: AVPlayer] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupInitialLayout()
    }
    
    func setupInitialLayout() {
        // Start with empty slots based on layout
        updateLayout(currentLayout)
    }
    
    func updateLayout(_ layout: MultiStreamLayout) {
        currentLayout = layout
        let slotCount = layout.maxStreams
        
        // Preserve existing streams, add empty slots as needed
        while activeStreams.count < slotCount {
            activeStreams.append(StreamSlot(position: activeStreams.count))
        }
        
        // Remove extra slots if downsizing
        if activeStreams.count > slotCount {
            let removedSlots = Array(activeStreams[slotCount...])
            activeStreams = Array(activeStreams[0..<slotCount])
            
            // Clean up removed players
            for slot in removedSlots {
                if let streamId = slot.stream?.id {
                    players[streamId]?.pause()
                    players.removeValue(forKey: streamId)
                }
            }
        }
    }
    
    func addStream(_ stream: TwitchStream, to slotIndex: Int) {
        guard slotIndex < activeStreams.count else { return }
        
        // Remove previous stream from this slot
        if let previousStream = activeStreams[slotIndex].stream {
            players[previousStream.id]?.pause()
            players.removeValue(forKey: previousStream.id)
        }
        
        // Add new stream
        activeStreams[slotIndex].stream = stream
        activeStreams[slotIndex].isLoading = true
        
        // Create player for new stream
        createPlayer(for: stream, slotIndex: slotIndex)
    }
    
    func removeStream(from slotIndex: Int) {
        guard slotIndex < activeStreams.count else { return }
        
        if let stream = activeStreams[slotIndex].stream {
            players[stream.id]?.pause()
            players.removeValue(forKey: stream.id)
        }
        
        activeStreams[slotIndex].stream = nil
        activeStreams[slotIndex].isLoading = false
        activeStreams[slotIndex].hasError = false
    }
    
    func focusOnStream(at slotIndex: Int) {
        guard slotIndex < activeStreams.count,
              activeStreams[slotIndex].stream != nil else { return }
        
        focusedStream = activeStreams[slotIndex]
    }
    
    func clearFocus() {
        focusedStream = nil
    }
    
    private func createPlayer(for stream: TwitchStream, slotIndex: Int) {
        // Try to get HLS stream URL
        getStreamURL(for: stream) { [weak self] url in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let url = url {
                    let player = AVPlayer(url: url)
                    self.players[stream.id] = player
                    
                    // Configure player for optimal streaming
                    player.automaticallyWaitsToMinimizeStalling = false
                    player.preventsDisplaySleepDuringVideoPlayback = true
                    
                    // Start playback
                    player.play()
                    
                    self.activeStreams[slotIndex].isLoading = false
                    self.activeStreams[slotIndex].hasError = false
                } else {
                    // Fallback to WebView-based player
                    self.activeStreams[slotIndex].isLoading = false
                    self.activeStreams[slotIndex].useWebPlayer = true
                }
            }
        }
    }
    
    private func getStreamURL(for stream: TwitchStream, completion: @escaping (URL?) -> Void) {
        // Try to extract HLS URL from Twitch
        // This is a simplified version - in production you'd use Twitch's API
        
        // For now, we'll use a working approach with direct channel URLs
        let channelURL = "https://www.twitch.tv/\(stream.userLogin)"
        
        // Use a background task to try to extract the real stream URL
        Task {
            do {
                // This would be replaced with actual HLS URL extraction
                // For now, return nil to fall back to WebView
                completion(nil)
            } catch {
                completion(nil)
            }
        }
    }
    
    // MARK: - Access Methods
    
    func getPlayer(for streamId: String) -> AVPlayer? {
        return players[streamId]
    }
    
    func getStreamState(for streamId: String) -> StreamViewState? {
        return streamStates[streamId]
    }
    
    func getValidationResult(for streamId: String) -> ValidationResult? {
        return streamValidationResults[streamId]
    }
    
    func getActiveStreamCount() -> Int {
        return activeStreams.compactMap { $0.stream }.count
    }
    
    func getEmptySlotCount() -> Int {
        return activeStreams.filter { $0.stream == nil }.count
    }
    
    func hasStreams() -> Bool {
        return getActiveStreamCount() > 0
    }
    
    func isFull() -> Bool {
        return getEmptySlotCount() == 0
    }
    
    func canAddMoreStreams() -> Bool {
        return !isFull() && connectionStatus != .error
    }
    
    // MARK: - Playback Control
    
    func pauseAll() async {
        for (streamId, player) in players {
            player.pause()
            
            var state = streamStates[streamId] ?? StreamViewState(streamId: streamId)
            state.isPlaying = false
            streamStates[streamId] = state
        }
        
        // Update WebView players
        StreamStateManager.shared.pauseAllStreams()
        
        isPlaying = false
        connectionStatus = .paused
    }
    
    func resumeAll() async {
        for (streamId, player) in players {
            player.play()
            
            var state = streamStates[streamId] ?? StreamViewState(streamId: streamId)
            state.isPlaying = true
            streamStates[streamId] = state
        }
        
        // Update WebView players
        StreamStateManager.shared.resumeAllStreams()
        
        updatePlayingStatus()
    }
    
    func setGlobalVolume(_ volume: Double) async {
        globalVolume = max(0.0, min(1.0, volume))
        
        for (streamId, player) in players {
            let state = streamStates[streamId] ?? StreamViewState(streamId: streamId)
            player.volume = Float(globalVolume * state.volume)
        }
        
        StreamStateManager.shared.setGlobalVolume(globalVolume)
        
        try? await persistenceManager.saveVolumeChange(globalVolume)
    }
    
    func toggleGlobalMute() async {
        isGlobalMuted.toggle()
        
        for (streamId, player) in players {
            let state = streamStates[streamId] ?? StreamViewState(streamId: streamId)
            player.isMuted = isGlobalMuted || state.isMuted
        }
        
        StreamStateManager.shared.toggleGlobalMute()
        
        try? await persistenceManager.saveMuteChange(isGlobalMuted)
    }
    
    func setAudioMixMode(_ mode: AudioMixMode) async {
        audioMixMode = mode
        await updateAudioMixing()
        
        try? await persistenceManager.saveAudioMixMode(mode)
    }
    
    private func updatePlayingStatus() {
        let hasPlayingStreams = players.values.contains { $0.timeControlStatus == .playing } ||
                               streamStates.values.contains { $0.isPlaying }
        
        isPlaying = hasPlayingStreams
        connectionStatus = hasPlayingStreams ? .connected : .disconnected
    }
    
    private func updateTotalViewerCount() {
        totalViewerCount = activeStreams.compactMap { $0.stream?.viewerCount }.reduce(0, +)
    }
    
    // MARK: - Utility Methods
    
    func clearAll() async {
        for slot in activeStreams {
            await cleanupStream(slot)
        }
        
        activeStreams.removeAll()
        streamStates.removeAll()
        streamValidationResults.removeAll()
        pendingOperations.removeAll()
        
        focusedStream = nil
        isPlaying = false
        totalViewerCount = 0
        connectionStatus = .disconnected
        
        // Reset to single layout
        await updateLayout(.single)
        
        try? await persistenceManager.clearAllStreams()
    }
    
    func refreshAll() async {
        for (index, slot) in activeStreams.enumerated() {
            guard let stream = slot.stream else { continue }
            
            // Re-validate stream
            let validationResult = await validationService.validateStream(stream)
            streamValidationResults[stream.id] = validationResult
            
            if !validationResult.isValid {
                activeStreams[index].hasError = true
                var state = streamStates[stream.id] ?? StreamViewState(streamId: stream.id)
                state.hasError = true
                state.errorMessage = validationResult.errors.first
                streamStates[stream.id] = state
            } else {
                // Recreate player if needed
                if players[stream.id] == nil {
                    await createPlayer(for: stream, slotIndex: index)
                }
            }
        }
    }
    
    // MARK: - Synchronization
    
    func syncWithRemote() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            let remoteState = try await syncService.fetchRemoteState()
            
            // Merge with local state
            await mergeRemoteState(remoteState)
            
            // Upload local changes
            try await syncService.uploadLocalState(createSyncState())
            
            lastSyncDate = Date()
            
        } catch {
            syncError = .syncFailed(error)
        }
        
        isSyncing = false
    }
    
    private func mergeRemoteState(_ remoteState: SyncState) async {
        // This would implement conflict resolution logic
        // For now, just update if remote is newer
        if let remoteDate = remoteState.lastModified,
           let localDate = lastSyncDate,
           remoteDate > localDate {
            
            // Apply remote changes
            favoriteLayouts = remoteState.favoriteLayouts
            audioMixMode = remoteState.audioMixMode
            globalVolume = remoteState.globalVolume
        }
    }
    
    private func createSyncState() -> SyncState {
        return SyncState(
            layout: currentLayout,
            favoriteLayouts: favoriteLayouts,
            audioMixMode: audioMixMode,
            globalVolume: globalVolume,
            lastModified: Date()
        )
    }
    
    // MARK: - Error Handling
    
    private func handleNetworkStatusChange() {
        Task {
            let networkStatus = await NetworkMonitor.shared.currentStatus()
            
            if networkStatus.isConnected {
                connectionStatus = isPlaying ? .connected : .disconnected
                await refreshAll()
            } else {
                connectionStatus = .error
                await pauseAll()
            }
        }
    }
    
    private func handleMemoryWarning() {
        Task {
            // Pause non-focused streams to free memory
            for slot in activeStreams {
                guard let stream = slot.stream,
                      focusedStream?.stream?.id != stream.id else { continue }
                
                players[stream.id]?.pause()
                
                var state = streamStates[stream.id] ?? StreamViewState(streamId: stream.id)
                state.isPlaying = false
                streamStates[stream.id] = state
            }
        }
    }
    
    func retryFailedOperations() async {
        let failedOps = pendingOperations.filter { Date().timeIntervalSince($0.timestamp) > 30 }
        
        for operation in failedOps {
            switch operation.type {
            case .add:
                try? await addStream(operation.stream, to: operation.slotIndex)
            case .remove:
                try? await removeStream(from: operation.slotIndex)
            }
        }
    }
}

// MARK: - Stream Slot
struct StreamSlot: Identifiable, Codable {
    let id = UUID()
    let position: Int
    var stream: TwitchStream?
    var isLoading = false
    var hasError = false
    var useWebPlayer = false
    var lastUpdated = Date()
    var retryCount = 0
    var maxRetries = 3
    
    var isEmpty: Bool {
        return stream == nil
    }
    
    var canRetry: Bool {
        return hasError && retryCount < maxRetries
    }
    
    mutating func incrementRetry() {
        retryCount += 1
        lastUpdated = Date()
    }
    
    mutating func resetRetry() {
        retryCount = 0
        hasError = false
        lastUpdated = Date()
    }
}

// MARK: - Multi Stream Layout
enum MultiStreamLayout: String, CaseIterable, Identifiable {
    case single = "1x1"
    case twoByTwo = "2x2"
    case threeByThree = "3x3"
    case fourByFour = "4x4"
    case oneByThree = "1x3"
    case threeByOne = "3x1"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .single: return "Single"
        case .twoByTwo: return "2×2 Grid"
        case .threeByThree: return "3×3 Grid"
        case .fourByFour: return "4×4 Grid"
        case .oneByThree: return "1×3 Vertical"
        case .threeByOne: return "3×1 Horizontal"
        }
    }
    
    var maxStreams: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 4
        case .threeByThree: return 9
        case .fourByFour: return 16
        case .oneByThree: return 3
        case .threeByOne: return 3
        }
    }
    
    var columns: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 2
        case .threeByThree: return 3
        case .fourByFour: return 4
        case .oneByThree: return 1
        case .threeByOne: return 3
        }
    }
    
    var rows: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 2
        case .threeByThree: return 3
        case .fourByFour: return 4
        case .oneByThree: return 3
        case .threeByOne: return 1
        }
    }
    
    var icon: String {
        switch self {
        case .single: return "square"
        case .twoByTwo: return "grid"
        case .threeByThree: return "square.grid.3x3"
        case .fourByFour: return "square.grid.4x4"
        case .oneByThree: return "rectangle.grid.1x2"
        case .threeByOne: return "rectangle.grid.2x1"
        }
    }
}

// MARK: - Working Stream Player View
struct WorkingStreamPlayer: View {
    let stream: TwitchStream
    let streamManager: MultiStreamManager
    let isCompact: Bool
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var useWebView = false
    @State private var showControls = false
    
    var body: some View {
        ZStack {
            Color.black
            
            if isLoading {
                LoadingPlayerView(isCompact: isCompact)
            } else if useWebView {
                WorkingStreamWebView(
                    channelName: stream.userLogin,
                    isCompact: isCompact
                )
            } else if let player = player {
                VideoPlayerView(player: player)
            } else {
                ErrorPlayerView(
                    stream: stream,
                    isCompact: isCompact,
                    onRetry: {
                        loadStream()
                    }
                )
            }
            
            // Stream info overlay
            if !isCompact || showControls {
                VStack {
                    Spacer()
                    
                    StreamInfoOverlay(
                        stream: stream,
                        isCompact: isCompact
                    )
                }
            }
        }
        .onAppear {
            loadStream()
        }
        .onTapGesture {
            if isCompact {
                withAnimation {
                    showControls.toggle()
                }
            }
        }
    }
    
    private func loadStream() {
        isLoading = true
        
        // Try to get the actual player from the manager
        if let existingPlayer = streamManager.getPlayer(for: stream.id) {
            self.player = existingPlayer
            self.isLoading = false
        } else {
            // Fall back to WebView player
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.useWebView = true
                self.isLoading = false
            }
        }
    }
}

// MARK: - Working Stream WebView
struct WorkingStreamWebView: UIViewRepresentable {
    let channelName: String
    let isCompact: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false // Disable PiP in multi-view
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        // Load optimized player URL
        let playerURL = createOptimizedPlayerURL()
        if let url = URL(string: playerURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createOptimizedPlayerURL() -> String {
        // Use Twitch player embed with optimizations for multi-stream
        var components = URLComponents()
        components.scheme = "https"
        components.host = "player.twitch.tv"
        components.path = "/"
        
        components.queryItems = [
            URLQueryItem(name: "channel", value: channelName),
            URLQueryItem(name: "parent", value: "localhost"),
            URLQueryItem(name: "autoplay", value: "true"),
            URLQueryItem(name: "muted", value: isCompact ? "true" : "false"), // Mute in multi-view
            URLQueryItem(name: "controls", value: "false"), // Hide controls in compact view
            URLQueryItem(name: "playsinline", value: "true"),
            URLQueryItem(name: "allowfullscreen", value: "false"), // Disable fullscreen in multi-view
            URLQueryItem(name: "time", value: "0s")
        ]
        
        return components.url?.absoluteString ?? "https://player.twitch.tv/?channel=\(channelName)&parent=localhost&autoplay=true&muted=\(isCompact)&playsinline=true"
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WorkingStreamWebView
        
        init(_ parent: WorkingStreamWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Optimize for multi-stream viewing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                webView.evaluateJavaScript("""
                    // Remove all unnecessary UI elements for multi-stream
                    const selectors = [
                        '[data-a-target="consent-banner"]',
                        '.consent-banner',
                        '[class*="chat"]',
                        '[class*="sidebar"]',
                        '[class*="recommendations"]',
                        '.tw-full-height'
                    ];
                    
                    selectors.forEach(selector => {
                        document.querySelectorAll(selector).forEach(el => el.remove());
                    });
                    
                    // Force video to fill container
                    const videos = document.getElementsByTagName('video');
                    for (let video of videos) {
                        video.style.width = '100%';
                        video.style.height = '100%';
                        video.style.objectFit = 'cover';
                        video.muted = \(parent.isCompact);
                        video.play().catch(e => console.log('Multi-stream autoplay prevented'));
                    }
                    
                    // Hide player UI in compact mode
                    if (\(parent.isCompact)) {
                        document.querySelectorAll('[class*="player-controls"]').forEach(el => {
                            el.style.display = 'none';
                        });
                    }
                """)
            }
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        
        let view = UIView()
        view.layer.addSublayer(playerLayer)
        
        // Store layer reference for layout updates
        context.coordinator.playerLayer = playerLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Supporting Views
struct LoadingPlayerView: View {
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 8 : 16) {
            ProgressView()
                .scaleEffect(isCompact ? 1.0 : 1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            if !isCompact {
                Text("Loading Stream...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
    }
}

struct ErrorPlayerView: View {
    let stream: TwitchStream
    let isCompact: Bool
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: isCompact ? 4 : 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: isCompact ? 20 : 30))
                .foregroundColor(.red)
            
            if !isCompact {
                Text("Stream Error")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

struct StreamInfoOverlay: View {
    let stream: TwitchStream
    let isCompact: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if !isCompact {
                    Text(stream.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Text(stream.userName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                
                if !isCompact && !stream.gameName.isEmpty {
                    Text(stream.gameName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: isCompact ? 4 : 6, height: isCompact ? 4 : 6)
                
                Text(stream.formattedViewerCount)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Supporting Types

// Stream View State for detailed state management
struct StreamViewState: Codable {
    let streamId: String
    var position: Int = 0
    var layout: MultiStreamLayout = .single
    var isVisible = true
    var isLoading = false
    var hasError = false
    var errorMessage: String?
    var isPlaying = false
    var isFocused = false
    var isMuted = false
    var volume: Double = 1.0
    var useWebPlayer = false
    var lastUpdated = Date()
    
    init(streamId: String) {
        self.streamId = streamId
    }
}

// Audio Mix Modes
enum AudioMixMode: String, CaseIterable, Codable {
    case focusedOnly = "focused_only"
    case all = "all"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .focusedOnly: return "Focused Only"
        case .all: return "All Streams"
        case .manual: return "Manual Control"
        }
    }
}

// Connection Status
enum ConnectionStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case paused = "paused"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .paused: return "Paused"
        case .error: return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .paused: return .orange
        case .error: return .red
        }
    }
}

// Stream Operations for tracking pending changes
struct StreamOperation: Identifiable, Codable {
    let id = UUID()
    let type: OperationType
    let stream: TwitchStream
    let slotIndex: Int
    let timestamp: Date
    
    enum OperationType: String, Codable {
        case add = "add"
        case remove = "remove"
    }
}

// Saved Layout for favorites
struct SavedLayout: Identifiable, Codable {
    let id = UUID()
    let name: String
    let layout: MultiStreamLayout
    let streamIds: [String]
    let createdAt = Date()
    var lastUsed: Date?
}

// Validation Result
struct ValidationResult: Codable {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    let timestamp = Date()
    
    static let valid = ValidationResult(isValid: true, errors: [], warnings: [])
}

// Sync State for cloud synchronization
struct SyncState: Codable {
    let layout: MultiStreamLayout
    let favoriteLayouts: [SavedLayout]
    let audioMixMode: AudioMixMode
    let globalVolume: Double
    let lastModified: Date?
}

// Multi-Stream Errors
enum MultiStreamError: Error, LocalizedError {
    case invalidSlotIndex(Int)
    case streamValidationFailed([String])
    case streamAdditionFailed(Error)
    case streamRemovalFailed(Error)
    case layoutUpdateFailed(Error)
    case playerCreationFailed(Error)
    case insufficientMemory(required: Int, available: Int)
    case insufficientBandwidth(required: Double, available: Double)
    case persistenceError(Error)
    case syncFailed(Error)
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidSlotIndex(let index):
            return "Invalid slot index: \(index)"
        case .streamValidationFailed(let errors):
            return "Stream validation failed: \(errors.joined(separator: ", "))"
        case .streamAdditionFailed(let error):
            return "Failed to add stream: \(error.localizedDescription)"
        case .streamRemovalFailed(let error):
            return "Failed to remove stream: \(error.localizedDescription)"
        case .layoutUpdateFailed(let error):
            return "Failed to update layout: \(error.localizedDescription)"
        case .playerCreationFailed(let error):
            return "Failed to create player: \(error.localizedDescription)"
        case .insufficientMemory(let required, let available):
            return "Insufficient memory: need \(required)MB, only \(available)MB available"
        case .insufficientBandwidth(let required, let available):
            return "Insufficient bandwidth: need \(required)Mbps, only \(available)Mbps available"
        case .persistenceError(let error):
            return "Persistence error: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .networkError:
            return "Network connection error"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

// Sync Errors
enum SyncError: Error, LocalizedError {
    case syncFailed(Error)
    case conflictResolutionFailed
    case uploadFailed(Error)
    case downloadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflicts"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    static let streamAdded = Notification.Name("streamAdded")
    static let streamRemoved = Notification.Name("streamRemoved")
    static let layoutChanged = Notification.Name("layoutChanged")
}

// MARK: - Import fix
import WebKit