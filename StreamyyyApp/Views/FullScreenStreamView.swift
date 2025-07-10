//
//  FullScreenStreamView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI
import WebKit

struct FullScreenStreamView: View {
    let stream: StreamModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var streamManager: StreamManager
    
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var isMuted = false
    @State private var showingShareSheet = false
    @State private var showingStreamInfo = false
    @State private var dragOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Stream Content
            StreamWebView(stream: stream, isMuted: $isMuted)
                .scaleEffect(scale)
                .offset(dragOffset)
                .gesture(
                    SimultaneousGesture(
                        // Pinch to zoom
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Limit zoom range
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                } else if scale > 3.0 {
                                    withAnimation(.spring()) {
                                        scale = 3.0
                                        lastScale = 3.0
                                    }
                                }
                            },
                        
                        // Drag gesture
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                withAnimation(.spring()) {
                                    // Snap back to center if not dragged far enough
                                    if abs(value.translation.x) < 100 && abs(value.translation.y) < 100 {
                                        dragOffset = .zero
                                    } else {
                                        // Allow some offset for zoomed content
                                        let maxOffset: CGFloat = 50
                                        dragOffset.x = max(-maxOffset, min(maxOffset, dragOffset.x))
                                        dragOffset.y = max(-maxOffset, min(maxOffset, dragOffset.y))
                                    }
                                }
                            }
                    )
                )
                .onTapGesture {
                    toggleControls()
                }
                .onTapGesture(count: 2) {
                    // Double tap to reset zoom
                    withAnimation(.spring()) {
                        scale = 1.0
                        lastScale = 1.0
                        dragOffset = .zero
                    }
                }
            
            // Controls Overlay
            if showControls {
                VStack {
                    // Top Controls
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: { showingStreamInfo.toggle() }) {
                                Image(systemName: "info.circle")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: { showingShareSheet = true }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom Controls
                    HStack {
                        // Mute/Unmute
                        Button(action: { isMuted.toggle() }) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Stream Info
                        VStack(alignment: .center, spacing: 4) {
                            if stream.isLive {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("LIVE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(16)
                            }
                            
                            Text("\(stream.viewerCount) viewers")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        // Picture in Picture (placeholder)
                        Button(action: {}) {
                            Image(systemName: "pip.enter")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                }
                .transition(.opacity)
            }
            
            // Stream Info Overlay
            if showingStreamInfo {
                StreamInfoOverlay(stream: stream, isPresented: $showingStreamInfo)
            }
        }
        .statusBarHidden()
        .onAppear {
            startControlsTimer()
        }
        .onDisappear {
            controlsTimer?.invalidate()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [stream.url])
        }
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        
        if showControls {
            startControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

// MARK: - Stream Web View
struct StreamWebView: UIViewRepresentable {
    let stream: StreamModel
    @Binding var isMuted: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .black
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: getEmbedURL()) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Handle mute state
        if isMuted {
            webView.evaluateJavaScript("document.querySelector('video').muted = true;")
        } else {
            webView.evaluateJavaScript("document.querySelector('video').muted = false;")
        }
    }
    
    private func getEmbedURL() -> String {
        switch stream.type {
        case .twitch:
            let username = extractTwitchUsername(from: stream.url)
            return "https://player.twitch.tv/?channel=\(username)&parent=localhost&autoplay=true"
        case .youtube:
            let videoId = extractYouTubeVideoId(from: stream.url)
            return "https://www.youtube.com/embed/\(videoId)?autoplay=1&mute=\(isMuted ? 1 : 0)"
        case .other:
            return stream.url
        }
    }
    
    private func extractTwitchUsername(from url: String) -> String {
        return url.components(separatedBy: "/").last ?? "shroud"
    }
    
    private func extractYouTubeVideoId(from url: String) -> String {
        // Extract video ID from YouTube URL
        if url.contains("watch?v=") {
            return url.components(separatedBy: "watch?v=").last?.components(separatedBy: "&").first ?? "dQw4w9WgXcQ"
        } else if url.contains("youtu.be/") {
            return url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first ?? "dQw4w9WgXcQ"
        }
        return "dQw4w9WgXcQ" // Default video ID
    }
}

// MARK: - Stream Info Overlay
struct StreamInfoOverlay: View {
    let stream: StreamModel
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Stream Information")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Stream Details
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(title: "Title", value: stream.title)
                    InfoRow(title: "Platform", value: stream.type.displayName)
                    InfoRow(title: "URL", value: stream.url)
                    
                    if stream.isLive {
                        InfoRow(title: "Status", value: "🔴 Live")
                        InfoRow(title: "Viewers", value: "\(stream.viewerCount)")
                    } else {
                        InfoRow(title: "Status", value: "⚫ Offline")
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding()
        }
        .transition(.opacity)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    FullScreenStreamView(
        stream: StreamModel(
            id: "1",
            url: "https://twitch.tv/shroud",
            type: .twitch,
            title: "shroud",
            isLive: true,
            viewerCount: 25000
        )
    )
    .environmentObject(StreamManager())
}