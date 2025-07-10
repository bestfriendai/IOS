//
//  TwitchEmbedPlayerView.swift
//  StreamyyyApp
//
//  Enhanced Twitch embed player for multi-stream viewing
//

import SwiftUI
import WebKit

struct TwitchEmbedPlayerView: UIViewRepresentable {
    let stream: TwitchStream
    let isCompact: Bool
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Add script message handler
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "loadingHandler")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let embedHTML = createTwitchEmbedHTML()
        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://player.twitch.tv"))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createTwitchEmbedHTML() -> String {
        let autoplay = "true"
        let muted = isCompact ? "true" : "false"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background-color: #000;
                    overflow: hidden;
                }
                iframe {
                    border: none;
                    width: 100%;
                    height: 100%;
                }
            </style>
        </head>
        <body>
            <iframe 
                src="https://player.twitch.tv/?channel=\(stream.userLogin)&parent=player.twitch.tv&autoplay=\(autoplay)&muted=\(muted)"
                frameborder="0" 
                allowfullscreen="true" 
                scrolling="no"
                allow="autoplay; fullscreen">
            </iframe>
            <script type="text/javascript">
                // Disable context menu
                document.addEventListener('contextmenu', event => event.preventDefault());
                
                // Disable text selection
                document.onselectstart = function() { return false; }
                document.onmousedown = function() { return false; }
                
                // Handle loading state
                window.addEventListener('load', function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.loadingHandler) {
                        window.webkit.messageHandlers.loadingHandler.postMessage('loaded');
                    }
                });
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: TwitchEmbedPlayerView
        
        init(_ parent: TwitchEmbedPlayerView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "loadingHandler" {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }
            }
        }
    }
}

struct CompactTwitchPlayerView: View {
    let stream: TwitchStream
    @State private var isLoading = true
    @State private var showingFullscreen = false
    
    var body: some View {
        ZStack {
            Color.black
            
            TwitchEmbedPlayerView(
                stream: stream,
                isCompact: true,
                isLoading: $isLoading
            )
            
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading \(stream.userName)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // Overlay controls for compact view
            VStack {
                HStack {
                    Text(stream.userName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Button(action: {
                        showingFullscreen = true
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding(8)
                
                Spacer()
                
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                        
                        Text(stream.formattedViewerCount)
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(3)
                    
                    Spacer()
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .fullScreenCover(isPresented: $showingFullscreen) {
            FullscreenTwitchPlayerView(stream: stream) {
                showingFullscreen = false
            }
        }
    }
}

struct FullscreenTwitchPlayerView: View {
    let stream: TwitchStream
    let onDismiss: () -> Void
    @State private var isLoading = true
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TwitchEmbedPlayerView(
                stream: stream,
                isCompact: false,
                isLoading: $isLoading
            )
            
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading \(stream.userName)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
            
            // Fullscreen controls
            if showControls && !isLoading {
                VStack {
                    HStack {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stream.title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            HStack {
                                Text(stream.userName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    
                                    Text("LIVE • \(stream.formattedViewerCount)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            if !stream.gameName.isEmpty {
                                Text("Playing: \(stream.gameName)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.8), Color.clear]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
                .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            resetControlsTimer()
        }
        .onAppear {
            resetControlsTimer()
        }
        .onDisappear {
            controlsTimer?.invalidate()
        }
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

#Preview {
    let sampleStream = TwitchStream(
        id: "preview",
        userId: "user1",
        userLogin: "ninja",
        userName: "Ninja",
        gameId: "33214",
        gameName: "Fortnite",
        type: "live",
        title: "Epic Fortnite Gameplay!",
        viewerCount: 45000,
        startedAt: "2025-01-10T12:00:00Z",
        language: "en",
        thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_ninja-{width}x{height}.jpg",
        tagIds: [],
        isMature: false
    )
    
    CompactTwitchPlayerView(stream: sampleStream)
        .frame(width: 300, height: 169)
}