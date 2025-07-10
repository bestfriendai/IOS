//
//  TestTwitchPlayer.swift
//  StreamyyyApp
//
//  Ultra-simple test player to verify Twitch streaming works
//

import SwiftUI
import WebKit

struct TestTwitchPlayer: UIViewRepresentable {
    let channelName: String
    
    func makeUIView(context: Context) -> WKWebView {
        // Configure WKWebView according to Twitch embed requirements
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Using official Twitch embed URL format
        // For iOS apps, we can use the bundle identifier as parent
        let parentDomain = Bundle.main.bundleIdentifier ?? "localhost"
        let urlString = "https://player.twitch.tv/?channel=\(channelName)&parent=\(parentDomain)&autoplay=true&muted=false"
        
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
            print("🔄 Loading Twitch embed for \(channelName) with parent: \(parentDomain)")
        }
    }
}

// Alternative ultra-simple HTML approach
struct SimpleHTMLTwitchPlayer: UIViewRepresentable {
    let channelName: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Official Twitch embed HTML approach with proper parent parameter
        let html = """
        <!DOCTYPE html>
        <html style="margin:0;padding:0;background:#000;height:100%;">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
            <style>
                body { margin:0; padding:0; background:#000; overflow:hidden; height:100vh; }
                iframe { width:100%; height:100%; border:none; display:block; min-height:300px; min-width:400px; }
            </style>
        </head>
        <body>
            <iframe 
                src="https://player.twitch.tv/?channel=\(channelName)&parent=\(Bundle.main.bundleIdentifier ?? "localhost")&autoplay=true&muted=false" 
                frameborder="0" 
                allowfullscreen>
            </iframe>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: URL(string: "https://localhost"))
        print("🔄 Loading HTML iframe for \(channelName)")
    }
}

// MARK: - Production-Ready Twitch Player
/// A production-ready Twitch player that follows all official Twitch embed guidelines
struct ProductionTwitchPlayer: UIViewRepresentable {
    let channelName: String
    let autoplay: Bool
    let muted: Bool
    
    init(channelName: String, autoplay: Bool = true, muted: Bool = false) {
        self.channelName = channelName
        self.autoplay = autoplay
        self.muted = muted
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // Configure WKWebView according to official Twitch requirements
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Construct URL following official Twitch embed documentation
        let autoplayParam = autoplay ? "true" : "false"
        let mutedParam = muted ? "true" : "false"
        
        // Using bundle identifier as parent for iOS apps
        let parentDomain = Bundle.main.bundleIdentifier ?? "localhost"
        let urlString = "https://player.twitch.tv/?channel=\(channelName)&parent=\(parentDomain)&autoplay=\(autoplayParam)&muted=\(mutedParam)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Twitch URL for channel: \(channelName)")
            return
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
        print("🔄 Loading production Twitch embed for \(channelName)")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ProductionTwitchPlayer
        
        init(_ parent: ProductionTwitchPlayer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ Twitch embed loaded successfully for: \(parent.channelName)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ Twitch embed failed for \(parent.channelName): \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ Twitch embed provisional navigation failed for \(parent.channelName): \(error.localizedDescription)")
        }
    }
}