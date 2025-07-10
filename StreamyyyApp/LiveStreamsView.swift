//
//  LiveStreamsView.swift
//  StreamyyyApp
//
//  Live Twitch streams view with real API integration
//

import SwiftUI
import Foundation
import WebKit

// MARK: - Simple Twitch WebView
struct SimpleTwitchWebView: UIViewRepresentable {
    let channelName: String
    let chatEnabled: Bool
    let quality: String
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var isLive: Bool
    @Binding var viewerCount: Int
    @Binding var currentQuality: String
    
    let lowLatency: Bool
    let autoplay: Bool
    let muted: Bool
    let volume: Double
    let fullscreen: Bool
    
    @State private var webView: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        
        // Enable JavaScript and modern web features
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        // Add user script to handle Twitch player
        let userScript = WKUserScript(
            source: """
                function setupVideoPlayback() {
                    const videos = document.getElementsByTagName('video');
                    console.log('Found', videos.length, 'video elements');
                    
                    for (let video of videos) {
                        // Force video attributes for iOS
                        video.setAttribute('playsinline', 'true');
                        video.setAttribute('webkit-playsinline', 'true');
                        video.setAttribute('controls', 'true');
                        video.muted = false; // Ensure unmuted for proper rendering
                        video.volume = 1.0;
                        
                        // Force video dimensions and display
                        video.style.width = '100%';
                        video.style.height = '100%';
                        video.style.objectFit = 'contain';
                        video.style.display = 'block';
                        video.style.visibility = 'visible';
                        
                        // Force video to load and play
                        video.load();
                        video.play().then(() => {
                            console.log('Video started successfully');
                        }).catch(e => {
                            console.log('Video play failed:', e);
                            // Try clicking Twitch play button
                            setTimeout(() => {
                                const playBtn = document.querySelector('[data-a-target="player-play-pause-button"]');
                                if (playBtn) {
                                    console.log('Clicking Twitch play button');
                                    playBtn.click();
                                }
                            }, 1000);
                        });
                        
                        // Listen for video events
                        video.addEventListener('loadedmetadata', function() {
                            console.log('Video metadata loaded');
                            this.play();
                        });
                        
                        video.addEventListener('canplay', function() {
                            console.log('Video can play');
                            this.play();
                        });
                    }
                }
                
                // Try multiple times to catch video elements
                window.addEventListener('load', setupVideoPlayback);
                setTimeout(setupVideoPlayback, 1000);
                setTimeout(setupVideoPlayback, 3000);
                setTimeout(setupVideoPlayback, 5000);
                
                // Observer for dynamically added video elements
                const observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                        if (mutation.addedNodes) {
                            mutation.addedNodes.forEach(function(node) {
                                if (node.tagName === 'VIDEO' || (node.getElementsByTagName && node.getElementsByTagName('video').length > 0)) {
                                    console.log('New video element detected');
                                    setTimeout(setupVideoPlayback, 500);
                                }
                            });
                        }
                    });
                });
                
                observer.observe(document.body, {
                    childList: true,
                    subtree: true
                });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        // Store webView reference for later use
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        // Create enhanced Twitch URL with mobile optimizations
        let twitchURL = createOptimizedTwitchURL()
        if let url = URL(string: twitchURL) {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            webView.load(request)
        }
        
        return webView
    }
    
    private func createOptimizedTwitchURL() -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "player.twitch.tv"
        components.path = "/"
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "channel", value: channelName),
            URLQueryItem(name: "parent", value: "localhost"),
            URLQueryItem(name: "autoplay", value: "true"), // Force autoplay
            URLQueryItem(name: "muted", value: "false"), // Force unmuted to ensure video renders
            URLQueryItem(name: "controls", value: "true"),
            URLQueryItem(name: "playsinline", value: "true"),
            URLQueryItem(name: "allowfullscreen", value: "true"),
            URLQueryItem(name: "time", value: "0s"), // Start from beginning
            URLQueryItem(name: "quality", value: "auto"), // Let Twitch decide quality
            URLQueryItem(name: "migration", value: "true") // Use newer player
        ]
        
        components.queryItems = queryItems
        
        return components.url?.absoluteString ?? "https://player.twitch.tv/?channel=\(channelName)&parent=localhost&autoplay=true&muted=false&playsinline=true"
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update if needed
    }
    
    func triggerPlayback() {
        webView?.evaluateJavaScript("""
            function aggressiveVideoFix() {
                const videos = document.getElementsByTagName('video');
                console.log('Aggressive video fix on', videos.length, 'videos');
                
                for (let video of videos) {
                    // Remove any poster image that might be blocking
                    video.removeAttribute('poster');
                    
                    // Force all necessary attributes
                    video.setAttribute('playsinline', 'true');
                    video.setAttribute('webkit-playsinline', 'true');
                    video.setAttribute('controls', 'true');
                    video.muted = false;
                    video.volume = 1.0;
                    
                    // Force CSS to ensure video is visible
                    video.style.cssText = `
                        width: 100% !important;
                        height: 100% !important;
                        object-fit: contain !important;
                        display: block !important;
                        visibility: visible !important;
                        opacity: 1 !important;
                        z-index: 999 !important;
                        position: relative !important;
                        background: black !important;
                    `;
                    
                    // Force parent containers to be visible
                    let parent = video.parentElement;
                    while (parent && parent !== document.body) {
                        parent.style.overflow = 'visible';
                        parent.style.height = 'auto';
                        parent.style.minHeight = '200px';
                        parent = parent.parentElement;
                    }
                    
                    // Try to reload and play
                    video.load();
                    video.currentTime = 0;
                    
                    video.play().then(() => {
                        console.log('Aggressive play successful');
                    }).catch(e => {
                        console.log('Aggressive play failed:', e);
                        
                        // Try clicking all possible play buttons
                        const selectors = [
                            '[data-a-target="player-play-pause-button"]',
                            '.player-button--play',
                            '[aria-label*="play"]',
                            '[aria-label*="Play"]',
                            'button[data-a-target*="play"]',
                            '.tw-interactive'
                        ];
                        
                        for (let selector of selectors) {
                            const btn = document.querySelector(selector);
                            if (btn) {
                                console.log('Clicking button:', selector);
                                btn.click();
                                break;
                            }
                        }
                    });
                }
                
                return videos.length;
            }
            
            aggressiveVideoFix();
        """) { result, error in
            if let error = error {
                print("Aggressive video fix failed: \(error)")
            } else if let count = result as? Int {
                print("Applied aggressive video fix to \(count) elements")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SimpleTwitchWebView
        
        init(_ parent: SimpleTwitchWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.isLive = true
                self.parent.hasError = false
            }
            
            // Multiple attempts to ensure video playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.forceVideoPlayback(webView)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.forceVideoPlayback(webView)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                self.forceVideoPlayback(webView)
            }
        }
        
        private func forceVideoPlayback(_ webView: WKWebView) {
            webView.evaluateJavaScript("""
                function forceVideo() {
                    const videos = document.getElementsByTagName('video');
                    console.log('Forcing video playback on', videos.length, 'videos');
                    
                    for (let video of videos) {
                        // Reset video attributes
                        video.setAttribute('playsinline', 'true');
                        video.setAttribute('webkit-playsinline', 'true');
                        video.muted = false;
                        video.volume = 1.0;
                        
                        // Force display properties
                        video.style.display = 'block';
                        video.style.visibility = 'visible';
                        video.style.width = '100%';
                        video.style.height = '100%';
                        video.style.objectFit = 'contain';
                        
                        // Try to reload and play
                        if (video.paused) {
                            video.load();
                            video.play().then(() => {
                                console.log('Video playback forced successfully');
                            }).catch(e => {
                                console.log('Force play failed:', e);
                                // Try Twitch controls
                                const playButton = document.querySelector('[data-a-target="player-play-pause-button"]');
                                if (playButton) {
                                    playButton.click();
                                    console.log('Clicked Twitch play button');
                                }
                            });
                        }
                    }
                    
                    return videos.length;
                }
                
                forceVideo();
            """) { result, error in
                if let error = error {
                    print("Force video playback failed: \(error)")
                } else if let count = result as? Int {
                    print("Attempted to force playback on \(count) video elements")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}

struct LiveStreamsView: View {
    @StateObject private var twitchService = RealTwitchAPIService.shared
    
    @State private var streams: [TwitchStream] = []
    @State private var topGames: [TwitchGame] = []
    @State private var selectedGameId: String?
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var showingStreamPlayer = false
    @State private var selectedStream: TwitchStream?
    @State private var currentPagination: TwitchPagination?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText, placeholder: "Search streams...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                if twitchService.isLoading && streams.isEmpty {
                    LoadingView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Top Games Section
                            if !topGames.isEmpty {
                                TopGamesSection(
                                    games: topGames,
                                    selectedGameId: $selectedGameId,
                                    onGameSelected: { gameId in
                                        selectedGameId = gameId
                                        Task {
                                            await loadStreamsByGame(gameId: gameId)
                                        }
                                    }
                                )
                                .padding(.vertical)
                                
                                Divider()
                            }
                            
                            // Streams Section
                            StreamsSection(
                                streams: streams,
                                isLoading: twitchService.isLoading,
                                onStreamTapped: { stream in
                                    selectedStream = stream
                                    showingStreamPlayer = true
                                },
                                onLoadMore: {
                                    await loadMoreStreams()
                                }
                            )
                        }
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
                
            }
            .navigationTitle("Live Streams")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingStreamPlayer) {
                if let stream = selectedStream {
                    StreamPlayerSheet(stream: stream)
                }
            }
            .task {
                await loadInitialData()
            }
            .onChange(of: searchText) { newValue in
                if !newValue.isEmpty {
                    Task {
                        await searchStreams(query: newValue)
                    }
                } else {
                    Task {
                        await loadTopStreams()
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadInitialData() async {
        // Ensure app access token is available for public API calls
        await twitchService.validateAndRefreshTokens()
        
        async let streamsTask: () = loadTopStreams()
        async let gamesTask: () = loadTopGames()
        
        await streamsTask
        await gamesTask
    }
    
    private func loadTopStreams() async {
        let (newStreams, pagination) = await twitchService.getTopStreams(first: 20)
        streams = newStreams
        currentPagination = pagination
    }
    
    private func loadStreamsByGame(gameId: String) async {
        let newStreams = await twitchService.getStreamsByGame(gameId: gameId, first: 20)
        streams = newStreams
    }
    
    private func loadTopGames() async {
        topGames = await twitchService.getTopGames(first: 10)
    }
    
    private func searchStreams(query: String) async {
        let searchResults = await twitchService.searchStreams(query: query, first: 20)
        streams = searchResults
    }
    
    private func loadMoreStreams() async {
        guard let pagination = currentPagination,
              let cursor = pagination.cursor else { return }
        
        let (moreStreams, newPagination) = await twitchService.getTopStreams(first: 20, after: cursor)
        streams.append(contentsOf: moreStreams)
        currentPagination = newPagination
    }
    
    private func refreshData() async {
        isRefreshing = true
        await loadInitialData()
        isRefreshing = false
    }
}

// MARK: - Supporting Views
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct TopGamesSection: View {
    let games: [TwitchGame]
    @Binding var selectedGameId: String?
    let onGameSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Categories")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button("All Streams") {
                    selectedGameId = nil
                    onGameSelected("")
                }
                .font(.caption)
                .foregroundColor(.purple)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(games) { game in
                        GameCard(
                            game: game,
                            isSelected: selectedGameId == game.id,
                            onTap: {
                                onGameSelected(game.id)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct GameCard: View {
    let game: TwitchGame
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: game.boxArtUrlLarge)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "gamecontroller")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(game.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 60)
            }
        }
        .foregroundColor(isSelected ? .purple : .primary)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct StreamsSection: View {
    let streams: [TwitchStream]
    let isLoading: Bool
    let onStreamTapped: (TwitchStream) -> Void
    let onLoadMore: () async -> Void
    
    var body: some View {
        LazyVStack(spacing: 1) {
            ForEach(streams) { stream in
                StreamCard(stream: stream, onTap: {
                    onStreamTapped(stream)
                })
                .onAppear {
                    if stream == streams.last {
                        Task {
                            await onLoadMore()
                        }
                    }
                }
            }
            
            if isLoading && !streams.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading more streams...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

struct StreamCard: View {
    let stream: TwitchStream
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: stream.thumbnailUrlMedium)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "tv")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    // Live indicator
                    VStack {
                        HStack {
                            Spacer()
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Text(stream.formattedViewerCount)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                    }
                    .padding(6)
                )
                
                // Stream info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(stream.userName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    if !stream.gameName.isEmpty {
                        Text(stream.gameName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "eye")
                        Text(stream.formattedViewerCount)
                        
                        if !stream.language.isEmpty {
                            Spacer()
                            Text(stream.language.uppercased())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(Color(.systemBackground))
        }
        .foregroundColor(.primary)
        .buttonStyle(PlainButtonStyle())
    }
}


struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading live streams...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StreamPlayerSheet: View {
    let stream: TwitchStream
    @Environment(\.presentationMode) var presentationMode
    
    // State for WebView and controls
    @State private var isLoading = true
    @State private var hasError = false
    @State private var isLive = false
    @State private var viewerCount = 0
    @State private var currentQuality: String = "auto"
    @State private var showControls = true
    @State private var volume: Double = 1.0
    @State private var isMuted = false
    @State private var isFullscreen = false
    @State private var showQualitySelection = false
    
    // Available quality options for Twitch
    private let availableQualities: [String] = [
        "auto", "source", "720p60", "720p", "480p", "360p", "160p"
    ]
    
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Twitch Stream Player
                    ZStack {
                        SimpleTwitchWebView(
                            channelName: stream.userLogin,
                            chatEnabled: false,
                            quality: currentQuality,
                            isLoading: $isLoading,
                            hasError: $hasError,
                            isLive: $isLive,
                            viewerCount: $viewerCount,
                            currentQuality: $currentQuality,
                            lowLatency: true,
                            autoplay: true,
                            muted: isMuted,
                            volume: volume,
                            fullscreen: isFullscreen
                        )
                        .aspectRatio(16/9, contentMode: ContentMode.fit)
                        .background(Color.black)
                        .clipped()
                        
                        // Play button overlay for manual video start
                        if !isLoading && !hasError && isLive && showControls {
                            VStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 80, height: 80)
                                    )
                                
                                VStack(spacing: 4) {
                                    Text("Tap anywhere to play")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    Text("If video doesn't start, try tapping the Twitch player controls")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                            }
                            .transition(.opacity)
                        }
                        
                        // Loading overlay
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text("Loading stream...")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.8))
                        }
                        
                        // Error overlay
                        if hasError {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.red)
                                
                                Text("Stream Unavailable")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("The stream may be offline or experiencing technical difficulties.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                
                                Button("Retry") {
                                    hasError = false
                                    isLoading = true
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.purple)
                                .cornerRadius(8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.8))
                        }
                        
                        // Player controls overlay
                        if showControls && !isLoading && !hasError {
                            VStack {
                                Spacer()
                                
                                PlayerControlsView(
                                    volume: $volume,
                                    isMuted: $isMuted,
                                    currentQuality: $currentQuality,
                                    availableQualities: availableQualities,
                                    isLive: isLive,
                                    showQualitySelection: $showQualitySelection,
                                    onFullscreenToggle: {
                                        isFullscreen.toggle()
                                    }
                                )
                            }
                            .padding()
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showControls.toggle()
                        }
                    }
                    
                    // Stream details
                    if !isFullscreen {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(stream.title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text(stream.userName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    if isLive {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 6, height: 6)
                                        Text("LIVE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                    }
                                    
                                    Image(systemName: "eye.fill")
                                    Text(stream.formattedViewerCount)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            if !stream.gameName.isEmpty {
                                HStack {
                                    Image(systemName: "gamecontroller")
                                        .foregroundColor(.secondary)
                                    Text("Playing \(stream.gameName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !stream.language.isEmpty {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(.secondary)
                                    Text("Language: \(stream.language.uppercased())")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    
                    if !isFullscreen {
                        Spacer()
                    }
                }
            }
            .navigationTitle(isFullscreen ? "" : "Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isFullscreen)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isFullscreen {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewerCount = stream.viewerCount
        }
    }
}

// MARK: - Player Controls View

struct PlayerControlsView: View {
    @Binding var volume: Double
    @Binding var isMuted: Bool
    @Binding var currentQuality: String
    let availableQualities: [String]
    let isLive: Bool
    @Binding var showQualitySelection: Bool
    let onFullscreenToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Volume control
            HStack(spacing: 8) {
                Button(action: {
                    isMuted.toggle()
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                if !isMuted {
                    Slider(value: $volume, in: 0...1)
                        .frame(width: 60)
                        .accentColor(.white)
                }
            }
            
            Spacer()
            
            // Live indicator
            if isLive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Quality selection
            Button(action: {
                showQualitySelection.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                    Text(currentQuality)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
            }
            .actionSheet(isPresented: $showQualitySelection) {
                ActionSheet(
                    title: Text("Select Quality"),
                    buttons: qualityButtons()
                )
            }
            
            // Fullscreen toggle
            Button(action: onFullscreenToggle) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.4),
                    Color.clear
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
    
    private func qualityButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        
        for quality in availableQualities {
            buttons.append(.default(Text(quality)) {
                currentQuality = quality
            })
        }
        
        buttons.append(.cancel())
        return buttons
    }
}

#Preview {
    LiveStreamsView()
}