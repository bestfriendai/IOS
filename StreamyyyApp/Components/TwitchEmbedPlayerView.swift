//
//  TwitchEmbedPlayerView.swift
//  StreamyyyApp
//
//  Enhanced Twitch embed player for multi-stream viewing
//

import SwiftUI
import WebKit

struct TwitchEmbedPlayerView: View {
    let stream: TwitchStream
    let isCompact: Bool
    @Binding var isLoading: Bool
    
    var body: some View {
        // This view now uses the new, reliable TwitchEmbedWebView.
        TwitchEmbedWebView(
            channelName: stream.userLogin,
            isMuted: .constant(isCompact)
        )
    }
}

// Compact Player View remains for UI structure but uses the new robust player
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

// Fullscreen Player View also uses the new robust player
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