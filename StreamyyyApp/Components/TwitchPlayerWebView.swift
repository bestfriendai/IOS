//
//  TwitchPlayerWebView.swift
//  StreamyyyApp
//
//  Alternative Twitch player implementation using direct iframe approach
//  Created to bypass 2025 parent parameter restrictions
//

import SwiftUI
import WebKit
import Combine

/// Alternative Twitch player using direct iframe approach to bypass parent parameter issues
public struct TwitchPlayerWebView: UIViewRepresentable {
    let channelName: String
    @Binding var isMuted: Bool
    
    // Configuration options
    let showControls: Bool
    let autoPlay: Bool
    let volume: Float
    
    // Callbacks
    var onPlayerReady: (() -> Void)?
    var onError: ((String) -> Void)?
    
    public init(
        channelName: String,
        isMuted: Binding<Bool>,
        showControls: Bool = false,
        autoPlay: Bool = true,
        volume: Float = 0.5
    ) {
        self.channelName = channelName
        self._isMuted = isMuted
        self.showControls = showControls
        self.autoPlay = autoPlay
        self.volume = volume
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        
        // Additional configuration for better compatibility
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Load the player directly
        loadTwitchPlayer(webView)
        
        return webView
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Handle mute state changes
        if isMuted {
            webView.evaluateJavaScript("document.querySelector('video').muted = true;")
        } else {
            webView.evaluateJavaScript("document.querySelector('video').muted = false;")
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func loadTwitchPlayer(_ webView: WKWebView) {
        let playerHTML = createPlayerHTML()
        webView.loadHTMLString(playerHTML, baseURL: nil)
    }
    
    private func createPlayerHTML() -> String {
        let muteParam = isMuted ? "true" : "false"
        let autoplayParam = autoPlay ? "true" : "false"
        let controlsParam = showControls ? "true" : "false"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                html, body {
                    width: 100%;
                    height: 100%;
                    background-color: #000;
                    overflow: hidden;
                }
                
                .player-container {
                    position: relative;
                    width: 100%;
                    height: 100%;
                    background-color: #000;
                }
                
                #twitch-player {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    border: none;
                    background-color: #000;
                }
                
                .loading {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: #fff;
                    font-family: Arial, sans-serif;
                    font-size: 14px;
                    z-index: 100;
                }
                
                .error {
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    color: #ff4444;
                    font-family: Arial, sans-serif;
                    font-size: 14px;
                    text-align: center;
                    z-index: 100;
                }
            </style>
        </head>
        <body>
            <div class="player-container">
                <div id="loading" class="loading">Loading stream...</div>
                <iframe 
                    id="twitch-player"
                    src="https://player.twitch.tv/?channel=\(channelName)&parent=twitch.tv&muted=\(muteParam)&autoplay=\(autoplayParam)&controls=\(controlsParam)"
                    frameborder="0"
                    allowfullscreen="true"
                    scrolling="no"
                    height="100%"
                    width="100%">
                </iframe>
            </div>
            
            <script>
                console.log('Loading Twitch player for channel: \(channelName)');
                
                var iframe = document.getElementById('twitch-player');
                var loading = document.getElementById('loading');
                
                // Hide loading indicator after iframe loads
                iframe.onload = function() {
                    console.log('Twitch player iframe loaded');
                    loading.style.display = 'none';
                    
                    // Notify iOS that player is ready
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchPlayerEvents) {
                            window.webkit.messageHandlers.twitchPlayerEvents.postMessage({
                                event: 'ready',
                                channel: '\(channelName)'
                            });
                        }
                    } catch (e) {
                        console.error('Error sending ready message:', e);
                    }
                };
                
                // Handle iframe errors
                iframe.onerror = function() {
                    console.error('Twitch player iframe failed to load');
                    loading.innerHTML = 'Failed to load stream';
                    loading.className = 'error';
                    
                    // Notify iOS of error
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.twitchPlayerEvents) {
                            window.webkit.messageHandlers.twitchPlayerEvents.postMessage({
                                event: 'error',
                                message: 'Failed to load Twitch player'
                            });
                        }
                    } catch (e) {
                        console.error('Error sending error message:', e);
                    }
                };
                
                // Functions to control the player
                window.setMuted = function(muted) {
                    console.log('Setting muted state to:', muted);
                    // Update iframe src with new muted parameter
                    var currentSrc = iframe.src;
                    var newSrc = currentSrc.replace(/muted=(true|false)/, 'muted=' + muted);
                    if (newSrc !== currentSrc) {
                        iframe.src = newSrc;
                    }
                };
                
                window.getMuted = function() {
                    var src = iframe.src;
                    var match = src.match(/muted=(true|false)/);
                    return match ? match[1] === 'true' : false;
                };
                
                window.getChannel = function() {
                    return '\(channelName)';
                };
                
                // Auto-retry on network errors
                var retryCount = 0;
                var maxRetries = 3;
                
                function retryLoad() {
                    if (retryCount < maxRetries) {
                        retryCount++;
                        console.log('Retrying load, attempt:', retryCount);
                        loading.innerHTML = 'Retrying... (' + retryCount + '/' + maxRetries + ')';
                        loading.className = 'loading';
                        
                        setTimeout(function() {
                            iframe.src = iframe.src; // Reload iframe
                        }, 2000 * retryCount); // Exponential backoff
                    } else {
                        loading.innerHTML = 'Failed to load stream after ' + maxRetries + ' attempts';
                        loading.className = 'error';
                    }
                }
                
                // Monitor for loading timeout
                setTimeout(function() {
                    if (loading.style.display !== 'none') {
                        console.log('Loading timeout, attempting retry');
                        retryLoad();
                    }
                }, 10000); // 10 second timeout
                
            </script>
        </body>
        </html>
        """
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: TwitchPlayerWebView
        
        init(_ parent: TwitchPlayerWebView) {
            self.parent = parent
            super.init()
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("TwitchPlayerWebView finished loading")
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("TwitchPlayerWebView navigation failed: \(error)")
            DispatchQueue.main.async {
                self.parent.onError?("Navigation failed: \(error.localizedDescription)")
            }
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("TwitchPlayerWebView provisional navigation failed: \(error)")
            DispatchQueue.main.async {
                self.parent.onError?("Provisional navigation failed: \(error.localizedDescription)")
            }
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let event = body["event"] as? String else {
                print("Invalid message received: \(message.body)")
                return
            }
            
            DispatchQueue.main.async {
                switch event {
                case "ready":
                    print("Twitch player is ready!")
                    self.parent.onPlayerReady?()
                    
                case "error":
                    let errorMessage = body["message"] as? String ?? "Unknown error"
                    print("Twitch player error: \(errorMessage)")
                    self.parent.onError?(errorMessage)
                    
                default:
                    print("Unknown event received: \(event)")
                    break
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    TwitchPlayerWebView(
        channelName: "shroud",
        isMuted: .constant(true),
        showControls: false,
        autoPlay: true
    )
    .frame(width: 320, height: 180)
    .background(Color.black)
}