//
//  PictureInPictureOverlay.swift
//  StreamyyyApp
//
//  Picture-in-Picture overlay system for advanced multi-streaming
//  Created by Claude Code on 2025-07-10
//

import SwiftUI

// MARK: - Picture-in-Picture Overlay
struct PictureInPictureOverlay: View {
    @ObservedObject var layoutManager: AdvancedLayoutManager
    @ObservedObject var audioManager: MultiStreamAudioManager
    @State private var pipStreams: [PiPStream] = []
    
    var body: some View {
        ZStack {
            ForEach(pipStreams) { pipStream in
                PictureInPictureStreamView(
                    pipStream: pipStream,
                    audioManager: audioManager,
                    onPositionChanged: { newPosition in
                        updatePiPPosition(pipStream.id, position: newPosition)
                    },
                    onSizeChanged: { newSize in
                        updatePiPSize(pipStream.id, size: newSize)
                    },
                    onClose: {
                        removePiPStream(pipStream.id)
                    },
                    onMaximize: {
                        maximizePiPStream(pipStream.id)
                    },
                    onMinimize: {
                        minimizePiPStream(pipStream.id)
                    }
                )
                .position(pipStream.position)
                .zIndex(Double(pipStream.zIndex))
            }
        }
        .onAppear {
            loadPiPStreams()
        }
    }
    
    private func loadPiPStreams() {
        // Load PiP streams from layout manager
        // For now, create some mock PiP streams
        pipStreams = []
    }
    
    private func updatePiPPosition(_ pipId: String, position: CGPoint) {
        if let index = pipStreams.firstIndex(where: { $0.id == pipId }) {
            pipStreams[index].position = position
        }
    }
    
    private func updatePiPSize(_ pipId: String, size: CGSize) {
        if let index = pipStreams.firstIndex(where: { $0.id == pipId }) {
            pipStreams[index].size = size
        }
    }
    
    private func removePiPStream(_ pipId: String) {
        pipStreams.removeAll { $0.id == pipId }
    }
    
    private func maximizePiPStream(_ pipId: String) {
        if let index = pipStreams.firstIndex(where: { $0.id == pipId }) {
            pipStreams[index].isMinimized = false
            pipStreams[index].isMaximized = true
        }
    }
    
    private func minimizePiPStream(_ pipId: String) {
        if let index = pipStreams.firstIndex(where: { $0.id == pipId }) {
            pipStreams[index].isMinimized = true
            pipStreams[index].isMaximized = false
        }
    }
}

// MARK: - Picture-in-Picture Stream View
struct PictureInPictureStreamView: View {
    let pipStream: PiPStream
    @ObservedObject var audioManager: MultiStreamAudioManager
    
    let onPositionChanged: (CGPoint) -> Void
    let onSizeChanged: (CGSize) -> Void
    let onClose: () -> Void
    let onMaximize: () -> Void
    let onMinimize: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var showingControls = false
    @State private var resizeOffset = CGSize.zero
    @State private var isResizing = false
    
    var body: some View {
        ZStack {
            // Main PiP Container
            VStack(spacing: 0) {
                if !pipStream.isMinimized {
                    // Stream Content
                    streamContentView
                        .frame(width: pipStream.size.width, height: pipStream.size.height)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(pipStream.isAudioActive ? Color.purple : Color.white.opacity(0.3), lineWidth: 2)
                        )
                } else {
                    // Minimized View
                    minimizedView
                }
                
                // Controls Bar (if not minimized)
                if !pipStream.isMinimized && showingControls {
                    pipControlsView
                }
            }
            
            // Resize Handle (bottom-right corner)
            if !pipStream.isMinimized && showingControls {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        resizeHandle
                    }
                }
            }
        }
        .offset(dragOffset)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    isDragging = true
                }
                .onEnded { value in
                    // Update position
                    let newPosition = CGPoint(
                        x: pipStream.position.x + value.translation.x,
                        y: pipStream.position.y + value.translation.y
                    )
                    onPositionChanged(newPosition)
                    
                    dragOffset = .zero
                    isDragging = false
                }
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingControls.toggle()
            }
            
            // Auto-hide controls after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingControls = false
                }
            }
        }
    }
    
    private var streamContentView: some View {
        ZStack {
            // Stream Player
            EnhancedTwitchPlayerView(
                stream: pipStream.stream,
                isAudioActive: pipStream.isAudioActive,
                isCompact: true
            )
            
            // Stream Info Overlay
            VStack {
                HStack {
                    Text(pipStream.stream.userName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    if pipStream.isAudioActive {
                        AudioActiveIndicator()
                    }
                }
                .padding(6)
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Text(pipStream.stream.formattedViewerCount)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(3)
                }
                .padding(6)
            }
        }
    }
    
    private var minimizedView: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 60)
            
            VStack(spacing: 2) {
                Image(systemName: "tv.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Text(String(pipStream.stream.userName.prefix(3)))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .overlay(
            Circle()
                .stroke(pipStream.isAudioActive ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
        )
        .onTapGesture {
            onMaximize()
        }
    }
    
    private var pipControlsView: some View {
        HStack(spacing: 8) {
            // Audio Toggle
            Button(action: {
                audioManager.setActiveAudioStream(pipStream.stream.id)
            }) {
                Image(systemName: pipStream.isAudioActive ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.caption)
                    .foregroundColor(pipStream.isAudioActive ? .green : .white)
            }
            
            // Minimize
            Button(action: onMinimize) {
                Image(systemName: "minus.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // Maximize (return to grid)
            Button(action: onMaximize) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            // Close
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }
    
    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.white.opacity(0.6))
            .frame(width: 12, height: 12)
            .cornerRadius(2)
            .offset(resizeOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        resizeOffset = value.translation
                        isResizing = true
                        
                        // Update size based on drag
                        let newSize = CGSize(
                            width: max(160, pipStream.size.width + value.translation.x),
                            height: max(90, pipStream.size.height + value.translation.y)
                        )
                        onSizeChanged(newSize)
                    }
                    .onEnded { _ in
                        resizeOffset = .zero
                        isResizing = false
                    }
            )
    }
}

// MARK: - Audio Active Indicator
struct AudioActiveIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3) { index in
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 2, height: CGFloat.random(in: 4...8))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.7))
        .cornerRadius(3)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - PiP Stream Model
struct PiPStream: Identifiable {
    let id: String
    let stream: TwitchStream
    var position: CGPoint
    var size: CGSize
    var isMinimized: Bool
    var isMaximized: Bool
    var isAudioActive: Bool
    var zIndex: Int
    
    init(
        id: String = UUID().uuidString,
        stream: TwitchStream,
        position: CGPoint = CGPoint(x: 100, y: 100),
        size: CGSize = CGSize(width: 160, height: 90),
        isMinimized: Bool = false,
        isMaximized: Bool = false,
        isAudioActive: Bool = false,
        zIndex: Int = 100
    ) {
        self.id = id
        self.stream = stream
        self.position = position
        self.size = size
        self.isMinimized = isMinimized
        self.isMaximized = isMaximized
        self.isAudioActive = isAudioActive
        self.zIndex = zIndex
    }
}

#Preview {
    let mockStream = TwitchStream(
        id: "1",
        userId: "user1",
        userLogin: "teststreamer",
        userName: "Test Streamer",
        gameId: "game1",
        gameName: "Test Game",
        type: "live",
        title: "Test Stream",
        viewerCount: 1234,
        startedAt: "2025-01-01T00:00:00Z",
        language: "en",
        thumbnailUrl: "https://example.com/thumb.jpg",
        tagIds: [],
        tags: [],
        isMature: false
    )
    
    let pipStream = PiPStream(stream: mockStream, isAudioActive: true)
    
    return PictureInPictureStreamView(
        pipStream: pipStream,
        audioManager: MultiStreamAudioManager.shared,
        onPositionChanged: { _ in },
        onSizeChanged: { _ in },
        onClose: { },
        onMaximize: { },
        onMinimize: { }
    )
    .frame(width: 300, height: 200)
    .background(Color.black)
}