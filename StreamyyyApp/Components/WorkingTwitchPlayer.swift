//
//  WorkingTwitchPlayer.swift
//  StreamyyyApp
//
//  Simple, working Twitch player that actually displays streams
//  Created to replace the non-working embed approaches
//

import SwiftUI
import WebKit

/// A simple Twitch player that actually works by using the direct Twitch player URL
struct WorkingTwitchPlayer: UIViewRepresentable {
    let channelName: String
    @Binding var isMuted: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let playerHTML = createWorkingPlayerHTML()
        webView.loadHTMLString(playerHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createWorkingPlayerHTML() -> String {
        let muteParam = isMuted ? "true" : "false"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { 
                    width: 100%; 
                    height: 100%; 
                    background: #000; 
                    overflow: hidden;
                }
                .container {
                    position: relative;
                    width: 100%;
                    height: 100%;
                    background: #000;
                }
                iframe {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    border: none;
                    background: #000;
                }
                .loading {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: #fff;
                    font-family: Arial, sans-serif;
                    font-size: 14px;
                    text-align: center;
                    z-index: 10;
                }
                .error {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: #ff4444;
                    font-family: Arial, sans-serif;
                    font-size: 12px;
                    text-align: center;
                    z-index: 10;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div id="loading" class="loading">
                    Loading \(channelName)...
                </div>
                
                <iframe 
                    id="player"
                    src="https://player.twitch.tv/?channel=\(channelName)&parent=twitch.tv&muted=\(muteParam)&autoplay=true&controls=false"
                    allowfullscreen>
                </iframe>
            </div>
            
            <script>
                console.log('Loading Twitch stream: \(channelName)');
                
                const iframe = document.getElementById('player');
                const loading = document.getElementById('loading');
                
                let loaded = false;
                
                // Hide loading after iframe loads
                iframe.onload = function() {
                    console.log('Iframe loaded for: \(channelName)');
                    if (loading) {
                        loading.style.display = 'none';
                    }
                    loaded = true;
                };
                
                // Handle iframe errors
                iframe.onerror = function() {
                    console.error('Failed to load: \(channelName)');
                    if (loading) {
                        loading.innerHTML = 'Failed to load<br>\(channelName)';
                        loading.className = 'error';
                    }
                };
                
                // Timeout fallback
                setTimeout(function() {
                    if (!loaded && loading) {
                        console.log('Trying alternative approach for: \(channelName)');
                        
                        // Try alternative URL
                        iframe.src = 'https://player.twitch.tv/?channel=\(channelName)&parent=localhost&muted=\(muteParam)&autoplay=true&controls=false';
                        
                        setTimeout(function() {
                            if (loading && loading.style.display !== 'none') {
                                loading.innerHTML = '\(channelName)<br><small>Stream may be offline</small>';
                                loading.className = 'error';
                            }
                        }, 5000);
                    }
                }, 3000);
                
                // Function to update mute state
                window.setMuted = function(muted) {
                    console.log('Setting muted to:', muted);
                    const currentSrc = iframe.src;
                    const newSrc = currentSrc.replace(/muted=(true|false)/, 'muted=' + muted);
                    if (newSrc !== currentSrc) {
                        iframe.src = newSrc;
                    }
                };
                
                // Prevent context menu
                document.addEventListener('contextmenu', e => e.preventDefault());
                document.addEventListener('selectstart', e => e.preventDefault());
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WorkingTwitchPlayer
        
        init(_ parent: WorkingTwitchPlayer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WorkingTwitchPlayer loaded for: \(parent.channelName)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WorkingTwitchPlayer failed for \(parent.channelName): \(error)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WorkingTwitchPlayer provisional navigation failed for \(parent.channelName): \(error)")
        }
    }
}

// MARK: - Alternative Simple Twitch Player
struct SimpleTwitchWebPlayer: UIViewRepresentable {
    let channelName: String
    @State private var isMuted = true
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html style="margin:0;padding:0;background:#000;">
        <head>
            <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
            <style>
                body { margin:0; padding:0; background:#000; overflow:hidden; }
                iframe { width:100%; height:100vh; border:none; display:block; }
            </style>
        </head>
        <body>
            <iframe src="https://player.twitch.tv/?channel=\(channelName)&parent=twitch.tv&autoplay=true&muted=true" allowfullscreen></iframe>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        print("🔄 Loading simple player for: \(channelName)")
    }
}

#Preview {
    WorkingTwitchPlayer(
        channelName: "shroud",
        isMuted: .constant(true)
    )
    .frame(height: 200)
}