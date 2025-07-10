//
//  AlternativeStreamPlayer.swift
//  StreamyyyApp
//
//  Alternative video player using direct Twitch mobile site
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import WebKit
import SafariServices

// MARK: - Alternative Stream Player
struct AlternativeStreamPlayer: View {
    let stream: TwitchStream
    @Binding var isPresented: Bool
    
    @State private var showingSafari = false
    @State private var safariURL: URL?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Stream Preview
                StreamPreviewCard(stream: stream)
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Watch in Safari (Most Reliable)
                    Button(action: {
                        safariURL = URL(string: "https://m.twitch.tv/\(stream.userLogin)")
                        showingSafari = true
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Watch in Safari")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Open in Twitch App
                    Button(action: {
                        openInTwitchApp()
                    }) {
                        HStack {
                            Image(systemName: "tv")
                            Text("Open in Twitch App")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Embedded Player (Fallback)
                    Button(action: {
                        // This would show the embedded player we created
                    }) {
                        HStack {
                            Image(systemName: "play.rectangle")
                            Text("Try Embedded Player")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Information
                VStack(spacing: 12) {
                    Text("Stream Viewing Options")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Safari: Full features, most reliable")
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Twitch App: Best quality if installed")
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Embedded: Limited by platform restrictions")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Watch Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }
    
    private func openInTwitchApp() {
        // Try to open in Twitch app first
        if let twitchURL = URL(string: "twitch://stream/\(stream.userLogin)"),
           UIApplication.shared.canOpenURL(twitchURL) {
            UIApplication.shared.open(twitchURL)
            isPresented = false
        } else {
            // Fallback to App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/app/twitch/id460177396") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
}

// MARK: - Stream Preview Card
struct StreamPreviewCard: View {
    let stream: TwitchStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: stream.thumbnailUrlLarge)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fill)
                    .overlay(
                        VStack {
                            Image(systemName: "tv")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                VStack {
                    HStack {
                        Spacer()
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text(stream.formattedViewerCount)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                    }
                }
                .padding(12)
            )
            
            // Stream Info
            VStack(alignment: .leading, spacing: 8) {
                Text(stream.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(3)
                
                HStack {
                    Text(stream.userName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text("\(stream.viewerCount) viewers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !stream.gameName.isEmpty {
                    HStack {
                        Image(systemName: "gamecontroller")
                            .foregroundColor(.secondary)
                        Text(stream.gameName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !stream.language.isEmpty {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                        Text("Language: \(stream.language.uppercased())")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
        .padding(.horizontal)
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor.systemPurple
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Working Embedded Player (Alternative)
struct WorkingEmbeddedPlayer: View {
    let stream: TwitchStream
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Video Area
                    ReliableTwitchWebView(channelName: stream.userLogin)
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    // Stream Info
                    StreamInfoSection(stream: stream)
                        .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Live Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Safari") {
                        if let url = URL(string: "https://m.twitch.tv/\(stream.userLogin)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Reliable Twitch WebView
struct ReliableTwitchWebView: UIViewRepresentable {
    let channelName: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.black
        
        // Load mobile Twitch site for better compatibility
        let urlString = "https://m.twitch.tv/\(channelName)"
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Auto-dismiss cookie banners and popups
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                webView.evaluateJavaScript("""
                    // Remove cookie banners and overlays
                    const selectors = [
                        '[data-a-target="consent-banner"]',
                        '.consent-banner',
                        '.gdpr-banner',
                        '.cookies-banner',
                        '[class*="cookie"]',
                        '[class*="consent"]'
                    ];
                    
                    selectors.forEach(selector => {
                        const elements = document.querySelectorAll(selector);
                        elements.forEach(el => el.remove());
                    });
                    
                    // Try to start video playback
                    const videos = document.getElementsByTagName('video');
                    for (let video of videos) {
                        video.play().catch(e => console.log('Autoplay prevented'));
                    }
                """)
            }
        }
    }
}

struct StreamInfoSection: View {
    let stream: TwitchStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stream.title)
                .font(.headline)
                .fontWeight(.bold)
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
                    
                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text("• \(stream.formattedViewerCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !stream.gameName.isEmpty {
                Text("Playing: \(stream.gameName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    AlternativeStreamPlayer(
        stream: TwitchStream(
            id: "123",
            userId: "456",
            userLogin: "shroud",
            userName: "shroud",
            gameId: "32982",
            gameName: "Grand Theft Auto V",
            type: "live",
            title: "Test Stream",
            viewerCount: 12345,
            startedAt: "2023-01-01T00:00:00Z",
            language: "en",
            thumbnailUrl: "https://example.com/thumbnail.jpg",
            tagIds: [],
            tags: [],
            isMature: false
        ),
        isPresented: .constant(true)
    )
}