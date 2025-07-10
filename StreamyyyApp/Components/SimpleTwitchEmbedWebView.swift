//
//  SimpleTwitchEmbedWebView.swift
//  StreamyyyApp
//
//  Simplified Twitch WebView that works reliably
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import WebKit

// MARK: - Simple Twitch Embed WebView
public struct SimpleTwitchEmbedWebView: UIViewRepresentable {
    let channelName: String
    let chatEnabled: Bool
    let quality: String
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var isLive: Bool
    @Binding var viewerCount: Int
    @Binding var currentQuality: String
    
    // Advanced configuration
    let lowLatency: Bool
    let autoplay: Bool
    let muted: Bool
    let volume: Double
    let fullscreen: Bool
    
    public init(
        channelName: String,
        chatEnabled: Bool = true,
        quality: String = "auto",
        isLoading: Binding<Bool>,
        hasError: Binding<Bool>,
        isLive: Binding<Bool>,
        viewerCount: Binding<Int>,
        currentQuality: Binding<String>,
        lowLatency: Bool = true,
        autoplay: Bool = true,
        muted: Bool = false,
        volume: Double = 1.0,
        fullscreen: Bool = false
    ) {
        self.channelName = channelName
        self.chatEnabled = chatEnabled
        self.quality = quality
        self._isLoading = isLoading
        self._hasError = hasError
        self._isLive = isLive
        self._viewerCount = viewerCount
        self._currentQuality = currentQuality
        self.lowLatency = lowLatency
        self.autoplay = autoplay
        self.muted = muted
        self.volume = volume
        self.fullscreen = fullscreen
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        
        return webView
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Load stream if needed
        if webView.url == nil || shouldReloadStream(webView) {
            loadTwitchStream(in: webView)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Helper Methods
    
    private func shouldReloadStream(_ webView: WKWebView) -> Bool {
        guard let currentURL = webView.url?.absoluteString else { return true }
        return !currentURL.contains(channelName)
    }
    
    private func loadTwitchStream(in webView: WKWebView) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.hasError = false
        }
        
        let twitchEmbedURL = createTwitchEmbedURL()
        
        if let url = URL(string: twitchEmbedURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            DispatchQueue.main.async {
                self.hasError = true
                self.isLoading = false
            }
        }
    }
    
    private func createTwitchEmbedURL() -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "player.twitch.tv"
        components.path = "/"
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "channel", value: channelName),
            URLQueryItem(name: "parent", value: "streamyyy.app"),
            URLQueryItem(name: "autoplay", value: autoplay ? "true" : "false"),
            URLQueryItem(name: "muted", value: muted ? "true" : "false")
        ]
        
        if !chatEnabled {
            queryItems.append(URLQueryItem(name: "controls", value: "false"))
        }
        
        if quality != "auto" {
            queryItems.append(URLQueryItem(name: "quality", value: quality))
        }
        
        components.queryItems = queryItems
        
        return components.url?.absoluteString ?? "https://player.twitch.tv/?channel=\(channelName)&parent=streamyyy.app"
    }
    
    // MARK: - Coordinator
    
    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SimpleTwitchEmbedWebView
        
        init(_ parent: SimpleTwitchEmbedWebView) {
            self.parent = parent
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.isLive = true
                self.parent.hasError = false
            }
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    struct SimpleTwitchEmbedPreview: View {
        @State private var isLoading = false
        @State private var hasError = false
        @State private var isLive = false
        @State private var viewerCount = 0
        @State private var currentQuality = "auto"
        
        var body: some View {
            SimpleTwitchEmbedWebView(
                channelName: "shroud",
                chatEnabled: false,
                quality: "720p",
                isLoading: $isLoading,
                hasError: $hasError,
                isLive: $isLive,
                viewerCount: $viewerCount,
                currentQuality: $currentQuality
            )
            .aspectRatio(16/9, contentMode: .fit)
            .background(Color.black)
        }
    }
    
    return SimpleTwitchEmbedPreview()
}