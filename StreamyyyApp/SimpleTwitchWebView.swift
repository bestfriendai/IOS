//
//  SimpleTwitchWebView.swift
//  StreamyyyApp
//
//  Working Twitch player implementation
//

import SwiftUI
import WebKit

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
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.black
        
        let twitchURL = "https://player.twitch.tv/?channel=\(channelName)&parent=streamyyy.app&autoplay=\(autoplay)&muted=\(muted)"
        if let url = URL(string: twitchURL) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update if needed
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
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }
    }
}