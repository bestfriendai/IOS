//
//  EnhancedStreamSlotView.swift
//  StreamyyyApp
//
//  Enhanced stream slot with real Twitch player integration and advanced controls
//

import SwiftUI

struct EnhancedStreamSlotView: View {
    let slot: StreamSlot
    let size: CGSize
    let onTap: () -> Void
    let onRemove: () -> Void
    let onAudioToggle: (TwitchStream) -> Void
    let isAudioActive: (String) -> Bool
    
    @State private var isHovered = false
    @State private var showControls = false
    @State private var streamState: StreamPlaybackState = .loading
    @State private var viewerCount: Int = 0
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let stream = slot.stream {
                activeStreamView(stream: stream)
            } else {
                emptyStreamView
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    slot.stream != nil && isAudioActive(slot.stream?.id ?? "") ? 
                    LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: slot.stream != nil && isAudioActive(slot.stream?.id ?? "") ? 3 : 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                showControls = hovering
            }
        }
        .onTapGesture {
            if slot.stream == nil {
                onTap()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls.toggle()
                }
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Active Stream View
    private func activeStreamView(stream: TwitchStream) -> some View {
        ZStack {
            // Main video player
            if let channelName = stream.getChannelName() {
                MultiStreamTwitchPlayer(
                    channelName: channelName,
                    isMuted: .constant(!isAudioActive(stream.id)),
                    isVisible: true,
                    quality: .medium
                )
                .onMultiStreamEvents(
                    onReady: {
                        withAnimation(.easeInOut) {
                            streamState = .ready
                            isLoading = false
                        }
                    },
                    onStateChange: { state in
                        withAnimation(.easeInOut) {
                            streamState = state
                        }
                    },
                    onError: { error in
                        print("Stream error for \(channelName): \(error)")
                        streamState = .error
                        isLoading = false
                    },
                    onViewerUpdate: { count in
                        viewerCount = count
                    }
                )
                .background(Color.black)
            } else {
                errorView(message: "Invalid channel name")
            }
            
            // Loading overlay
            if isLoading || streamState.shouldShowLoadingIndicator {
                loadingOverlay
            }
            
            // Stream info overlay
            streamInfoOverlay(stream: stream)
            
            // Controls overlay
            if showControls || isHovered {
                controlsOverlay(stream: stream)
            }
            
            // Audio indicator
            if isAudioActive(stream.id) {
                audioIndicator
            }
        }
    }
    
    // MARK: - Empty Stream View
    private var emptyStreamView: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.1),
                                Color.gray.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                Color.white.opacity(0.2),
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                    )
                
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: min(size.width, size.height) * 0.2))
                        .foregroundColor(.white.opacity(0.6))
                    
                    VStack(spacing: 4) {
                        Text("Add Stream")
                            .font(.system(size: min(16, size.width * 0.08)))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Tap to browse")
                            .font(.system(size: min(12, size.width * 0.06)))
                            .foregroundColor(.gray)
                    }
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
            
            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    .scaleEffect(1.2)
                
                Text(streamState.displayName)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Stream Info Overlay
    private func streamInfoOverlay(stream: TwitchStream) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stream.userName)
                        .font(.system(size: min(14, size.width * 0.07)))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 1)
                    
                    if !stream.gameName.isEmpty {
                        Text(stream.gameName)
                            .font(.system(size: min(10, size.width * 0.05)))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black, radius: 1, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial.opacity(0.8))
                )
                
                Spacer()
                
                // Live indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text("LIVE")
                        .font(.system(size: min(10, size.width * 0.05)))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.9))
                )
            }
            .padding(8)
            
            Spacer()
            
            // Viewer count
            HStack {
                Spacer()
                
                if viewerCount > 0 {
                    Text("\(formatViewerCount(viewerCount)) viewers")
                        .font(.system(size: min(10, size.width * 0.05)))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.ultraThinMaterial.opacity(0.8))
                        )
                }
            }
            .padding(8)
        }
    }
    
    // MARK: - Controls Overlay
    private func controlsOverlay(stream: TwitchStream) -> some View {
        ZStack {
            Color.black.opacity(0.3)
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.8))
                                    .frame(width: 32, height: 32)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                HStack {
                    Button(action: {
                        onAudioToggle(stream)
                    }) {
                        Image(systemName: isAudioActive(stream.id) ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.title3)
                            .foregroundColor(isAudioActive(stream.id) ? .green : .white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial.opacity(0.8))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
            .padding(12)
        }
        .transition(.opacity)
    }
    
    // MARK: - Audio Indicator
    private var audioIndicator: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    Text("AUDIO")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .scaleEffect(0.9)
            }
        }
        .padding(8)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        ZStack {
            Color.black
            
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatViewerCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Extensions for TwitchStream
extension TwitchStream {
    func getChannelName() -> String? {
        return userLogin.isEmpty ? nil : userLogin
    }
}

#Preview {
    EnhancedStreamSlotView(
        slot: StreamSlot(position: 0),
        size: CGSize(width: 200, height: 112),
        onTap: {},
        onRemove: {},
        onAudioToggle: { _ in },
        isAudioActive: { _ in false }
    )
    .background(Color.black)
}