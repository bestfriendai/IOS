//
//  SimpleYouTubeEmbedView.swift
//  StreamyyyApp
//
//  Simplified YouTube embed view matching web app functionality
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import WebKit

// MARK: - Simple YouTube Embed View

struct SimpleYouTubeEmbedView: View {
    let videoId: String
    let options: YouTubeEmbedOptions
    
    @State private var webView: WKWebView?
    @State private var isLoading = true
    @State private var hasError = false
    @State private var errorMessage = ""
    
    init(videoId: String, options: YouTubeEmbedOptions = YouTubeEmbedOptions()) {
        self.videoId = videoId
        self.options = options
    }
    
    var body: some View {
        ZStack {
            // WebView
            YouTubeWebView(
                videoId: videoId,
                options: options,
                webView: $webView,
                isLoading: $isLoading,
                hasError: $hasError,
                errorMessage: $errorMessage
            )
            
            // Loading overlay
            if isLoading {
                loadingOverlay
            }
            
            // Error overlay
            if hasError {
                errorOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onDisappear {
            pauseVideo()
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                    .scaleEffect(1.2)
                
                Text("Loading YouTube video...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var errorOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                
                Text("Failed to load video")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button("Retry") {
                    retryLoad()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
        }
    }
    
    private func pauseVideo() {
        webView?.evaluateJavaScript("player.pauseVideo();", completionHandler: nil)
    }
    
    private func retryLoad() {
        hasError = false
        isLoading = true
        
        if let webView = webView {
            let embedURL = generateEmbedURL()
            if let url = URL(string: embedURL) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }
    }
    
    private func generateEmbedURL() -> String {
        return YouTubeEmbedHelper.generateEmbedURL(videoId: videoId, options: options)
    }
}

// MARK: - YouTube WebView

struct YouTubeWebView: UIViewRepresentable {
    let videoId: String
    let options: YouTubeEmbedOptions
    
    @Binding var webView: WKWebView?
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var errorMessage: String
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = options.autoplay ? [] : .all
        
        // Enable picture-in-picture
        if #available(iOS 14.0, *) {
            configuration.allowsPictureInPictureMediaPlayback = true
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        
        // Set user agent for iOS
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        
        self.webView = webView
        
        // Load the embed URL
        let embedURL = YouTubeEmbedHelper.generateEmbedURL(videoId: videoId, options: options)
        if let url = URL(string: embedURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            hasError = true
            errorMessage = "Invalid video URL"
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Updates handled by coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: YouTubeWebView
        
        init(_ parent: YouTubeWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.hasError = false
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.hasError = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
            parent.errorMessage = error.localizedDescription
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
            parent.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - YouTube Embed Options

public struct YouTubeEmbedOptions {
    public let autoplay: Bool
    public let muted: Bool
    public let showControls: Bool
    public let showInfo: Bool
    public let showRelated: Bool
    public let enableJavaScriptAPI: Bool
    public let startTime: Int?
    public let endTime: Int?
    public let loop: Bool
    public let modestBranding: Bool
    public let enableFullscreen: Bool
    
    public init(
        autoplay: Bool = false,
        muted: Bool = true,
        showControls: Bool = true,
        showInfo: Bool = false,
        showRelated: Bool = false,
        enableJavaScriptAPI: Bool = true,
        startTime: Int? = nil,
        endTime: Int? = nil,
        loop: Bool = false,
        modestBranding: Bool = true,
        enableFullscreen: Bool = true
    ) {
        self.autoplay = autoplay
        self.muted = muted
        self.showControls = showControls
        self.showInfo = showInfo
        self.showRelated = showRelated
        self.enableJavaScriptAPI = enableJavaScriptAPI
        self.startTime = startTime
        self.endTime = endTime
        self.loop = loop
        self.modestBranding = modestBranding
        self.enableFullscreen = enableFullscreen
    }
}

// MARK: - YouTube Embed Helper

public struct YouTubeEmbedHelper {
    
    /// Extracts video ID from various YouTube URL formats
    public static func extractVideoId(from url: String) -> String? {
        let patterns = [
            "(?:youtube\\.com/watch\\?v=|youtu\\.be/|youtube\\.com/embed/)([^&\\n?#]+)",
            "youtube\\.com/live/([^&\\n?#]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = url as NSString
                let results = regex.matches(in: url, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first, match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    return nsString.substring(with: range)
                }
            }
        }
        
        return nil
    }
    
    /// Validates if a URL is a YouTube URL
    public static func isYouTubeURL(_ url: String) -> Bool {
        let lowercaseURL = url.lowercased()
        return lowercaseURL.contains("youtube.com") || lowercaseURL.contains("youtu.be")
    }
    
    /// Generates embed URL with options
    public static func generateEmbedURL(videoId: String, options: YouTubeEmbedOptions) -> String {
        var parameters: [String] = []
        
        parameters.append("autoplay=\(options.autoplay ? "1" : "0")")
        parameters.append("mute=\(options.muted ? "1" : "0")")
        parameters.append("controls=\(options.showControls ? "1" : "0")")
        parameters.append("showinfo=\(options.showInfo ? "1" : "0")")
        parameters.append("rel=\(options.showRelated ? "1" : "0")")
        parameters.append("enablejsapi=\(options.enableJavaScriptAPI ? "1" : "0")")
        parameters.append("modestbranding=\(options.modestBranding ? "1" : "0")")
        parameters.append("fs=\(options.enableFullscreen ? "1" : "0")")
        
        if let startTime = options.startTime {
            parameters.append("start=\(startTime)")
        }
        
        if let endTime = options.endTime {
            parameters.append("end=\(endTime)")
        }
        
        if options.loop {
            parameters.append("loop=1")
            parameters.append("playlist=\(videoId)")
        }
        
        // iOS-specific parameters for better mobile experience
        parameters.append("playsinline=1")
        parameters.append("origin=streamyyy.app")
        
        let parameterString = parameters.joined(separator: "&")
        return "https://www.youtube.com/embed/\(videoId)?\(parameterString)"
    }
    
    /// Generates thumbnail URL for video
    public static func generateThumbnailURL(videoId: String, quality: ThumbnailQuality = .medium) -> String {
        let qualityString = quality.rawValue
        return "https://img.youtube.com/vi/\(videoId)/\(qualityString).jpg"
    }
    
    public enum ThumbnailQuality: String {
        case low = "sddefault"
        case medium = "mqdefault"
        case high = "hqdefault"
        case max = "maxresdefault"
    }
}

// MARK: - Enhanced YouTube Stream View

struct EnhancedYouTubeStreamView: View {
    let videoId: String
    let title: String?
    let channelName: String?
    
    @State private var embedOptions = YouTubeEmbedOptions()
    @State private var showControls = true
    @State private var isMuted = true
    @State private var isLive = false
    @State private var viewerCount: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            // Stream info header
            if let title = title {
                streamInfoHeader
            }
            
            // Video embed
            SimpleYouTubeEmbedView(videoId: videoId, options: embedOptions)
                .aspectRatio(16/9, contentMode: .fit)
            
            // Controls footer
            streamControlsFooter
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            checkIfLive()
        }
    }
    
    private var streamInfoHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // YouTube icon
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? "YouTube Video")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let channelName = channelName {
                        Text(channelName)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Live indicator
                if isLive {
                    liveIndicator
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }
    
    private var liveIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Text("LIVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let count = viewerCount {
                Text("• \(count.formatted()) watching")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.2))
        .clipShape(Capsule())
    }
    
    private var streamControlsFooter: some View {
        HStack {
            // Mute toggle
            Button(action: {
                isMuted.toggle()
                embedOptions = YouTubeEmbedOptions(
                    autoplay: embedOptions.autoplay,
                    muted: isMuted,
                    showControls: embedOptions.showControls,
                    showInfo: embedOptions.showInfo,
                    showRelated: embedOptions.showRelated,
                    enableJavaScriptAPI: embedOptions.enableJavaScriptAPI,
                    startTime: embedOptions.startTime,
                    endTime: embedOptions.endTime,
                    loop: embedOptions.loop,
                    modestBranding: embedOptions.modestBranding,
                    enableFullscreen: embedOptions.enableFullscreen
                )
            }) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Controls toggle
            Button(action: {
                showControls.toggle()
                embedOptions = YouTubeEmbedOptions(
                    autoplay: embedOptions.autoplay,
                    muted: embedOptions.muted,
                    showControls: showControls,
                    showInfo: embedOptions.showInfo,
                    showRelated: embedOptions.showRelated,
                    enableJavaScriptAPI: embedOptions.enableJavaScriptAPI,
                    startTime: embedOptions.startTime,
                    endTime: embedOptions.endTime,
                    loop: embedOptions.loop,
                    modestBranding: embedOptions.modestBranding,
                    enableFullscreen: embedOptions.enableFullscreen
                )
            }) {
                Image(systemName: showControls ? "slider.horizontal.3" : "slider.horizontal.below.rectangle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.9))
    }
    
    private func checkIfLive() {
        // In a real implementation, this would check the YouTube API
        // to determine if the video is a live stream
        // For now, we'll use a simple heuristic
        Task {
            // Simulate API call
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Mock live detection based on video ID patterns
            isLive = videoId.contains("live") || Bool.random()
            
            if isLive {
                viewerCount = Int.random(in: 100...10000)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SimpleYouTubeEmbedView(
            videoId: "dQw4w9WgXcQ",
            options: YouTubeEmbedOptions(autoplay: false, muted: true)
        )
        .frame(height: 200)
        
        EnhancedYouTubeStreamView(
            videoId: "jNQXAC9IVRw",
            title: "Sample YouTube Live Stream",
            channelName: "Creator Channel"
        )
        .frame(height: 300)
    }
    .padding()
}