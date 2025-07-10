//
//  StreamyyyStreamPlayer.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Enhanced stream player with modern controls and gestures
//

import SwiftUI
import AVFoundation

// MARK: - StreamyyyStreamPlayer
struct StreamyyyStreamPlayer: View {
    let stream: AppStream
    @Binding var isFullScreen: Bool
    @State private var showControls = true
    @State private var isPlaying = false
    @State private var isMuted = false
    @State private var volume: Double = 1.0
    @State private var currentTime: Double = 0
    @State private var duration: Double = 100
    @State private var isBuffering = false
    @State private var quality: StreamQuality = .auto
    @State private var showQualityPicker = false
    @State private var controlsTimer: Timer?
    @State private var gestureLocation: CGPoint = .zero
    @State private var brightness: Double = 0.5
    @State private var isDraggingSeekBar = false
    
    @Environment(\.dismiss) private var dismiss
    @GestureState private var dragOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Video Content Area
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        VStack {
                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(stream.streamerName)
                                .font(StreamyyyTypography.titleLarge)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                            
                            if stream.isLive {
                                HStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("LIVE")
                                        .font(StreamyyyTypography.labelSmall)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                    )
                
                // Buffering Indicator
                if isBuffering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                
                // Gesture Feedback Overlay
                if gestureLocation != .zero {
                    gestureOverlay
                }
                
                // Controls Overlay
                if showControls {
                    controlsOverlay
                }
            }
            .onTapGesture {
                toggleControlsWithTimer()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        gestureLocation = value.location
                        handleDragGesture(value)
                    }
                    .onEnded { _ in
                        gestureLocation = .zero
                        showControlsTemporarily()
                    }
            )
            .onAppear {
                setupPlayer()
                showControlsTemporarily()
            }
            .onDisappear {
                cleanup()
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .sheet(isPresented: $showQualityPicker) {
            qualityPickerSheet
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stream player for \(stream.streamerName)")
        .accessibilityHint("Double tap to toggle controls, swipe to adjust volume or brightness")
    }
    
    // MARK: - Controls Overlay
    private var controlsOverlay: some View {
        ZStack {
            // Top Controls
            VStack {
                HStack {
                    Button(action: {
                        StreamyyyDesignSystem.hapticFeedback(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close player")
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(stream.streamerName)
                            .font(StreamyyyTypography.titleMedium)
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                        
                        Text(stream.title)
                            .font(StreamyyyTypography.bodySmall)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showQualityPicker = true
                        StreamyyyDesignSystem.hapticFeedback(.light)
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Player settings")
                }
                .padding()
                
                Spacer()
            }
            
            // Center Controls
            HStack(spacing: 60) {
                Button(action: {
                    seekBackward()
                    StreamyyyDesignSystem.hapticFeedback(.medium)
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Seek backward 15 seconds")
                
                Button(action: {
                    togglePlayPause()
                    StreamyyyDesignSystem.hapticFeedback(.medium)
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                
                Button(action: {
                    seekForward()
                    StreamyyyDesignSystem.hapticFeedback(.medium)
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Seek forward 15 seconds")
            }
            
            // Bottom Controls
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Progress Bar
                    if !stream.isLive {
                        VStack(spacing: 4) {
                            Slider(value: $currentTime, in: 0...duration, onEditingChanged: { editing in
                                isDraggingSeekBar = editing
                                if !editing {
                                    seekToTime(currentTime)
                                }
                            })
                            .tint(.white)
                            .accessibilityLabel("Seek bar")
                            .accessibilityValue("\(Int(currentTime)) seconds of \(Int(duration)) seconds")
                            
                            HStack {
                                Text(timeString(currentTime))
                                    .font(StreamyyyTypography.captionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Spacer()
                                
                                Text(timeString(duration))
                                    .font(StreamyyyTypography.captionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Control Bar
                    HStack {
                        Button(action: {
                            toggleMute()
                            StreamyyyDesignSystem.hapticFeedback(.light)
                        }) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel(isMuted ? "Unmute" : "Mute")
                        
                        if !isMuted {
                            Slider(value: $volume, in: 0...1) { editing in
                                if !editing {
                                    setVolume(volume)
                                }
                            }
                            .tint(.white)
                            .frame(width: 80)
                            .accessibilityLabel("Volume")
                            .accessibilityValue("\(Int(volume * 100)) percent")
                        }
                        
                        Spacer()
                        
                        if stream.isLive {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(StreamyyyTypography.captionSmall)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            toggleFullScreen()
                            StreamyyyDesignSystem.hapticFeedback(.light)
                        }) {
                            Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel(isFullScreen ? "Exit fullscreen" : "Enter fullscreen")
                    }
                    .padding()
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: showControls)
    }
    
    // MARK: - Gesture Overlay
    private var gestureOverlay: some View {
        VStack {
            if gestureLocation.y < UIScreen.main.bounds.height / 2 {
                // Brightness indicator
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.white)
                    
                    ProgressView(value: brightness)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 100)
                    
                    Text("\(Int(brightness * 100))%")
                        .font(StreamyyyTypography.captionSmall)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .position(x: gestureLocation.x, y: gestureLocation.y)
            } else {
                // Volume indicator
                HStack {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(.white)
                    
                    ProgressView(value: volume)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 100)
                    
                    Text("\(Int(volume * 100))%")
                        .font(StreamyyyTypography.captionSmall)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .position(x: gestureLocation.x, y: gestureLocation.y)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: gestureLocation)
    }
    
    // MARK: - Quality Picker Sheet
    private var qualityPickerSheet: some View {
        NavigationView {
            List {
                Section("Video Quality") {
                    ForEach(StreamQuality.allCases, id: \.self) { streamQuality in
                        Button(action: {
                            quality = streamQuality
                            showQualityPicker = false
                            StreamyyyDesignSystem.hapticFeedback(.light)
                        }) {
                            HStack {
                                Text(streamQuality.displayName)
                                    .foregroundColor(StreamyyyColors.textPrimary)
                                
                                Spacer()
                                
                                if quality == streamQuality {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(StreamyyyColors.primary)
                                }
                            }
                        }
                    }
                }
                
                Section("Audio") {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Slider(value: $volume, in: 0...1)
                            .frame(width: 120)
                        Text("\(Int(volume * 100))%")
                            .font(StreamyyyTypography.captionMedium)
                            .foregroundColor(StreamyyyColors.textSecondary)
                    }
                    
                    Toggle("Mute", isOn: $isMuted)
                }
                
                Section("Stream Info") {
                    HStack {
                        Text("Platform")
                        Spacer()
                        Text(stream.platform)
                            .foregroundColor(StreamyyyColors.textSecondary)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(stream.isLive ? "Live" : "Offline")
                            .foregroundColor(stream.isLive ? StreamyyyColors.liveIndicator : StreamyyyColors.textSecondary)
                    }
                    
                    if stream.viewerCount > 0 {
                        HStack {
                            Text("Viewers")
                            Spacer()
                            Text(stream.formattedViewerCount)
                                .foregroundColor(StreamyyyColors.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("Player Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showQualityPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupPlayer() {
        // Initialize player with stream URL
        isPlaying = true
        isBuffering = false
        
        // Set initial volume
        setVolume(volume)
        
        // Configure audio session
        configureAudioSession()
    }
    
    private func cleanup() {
        controlsTimer?.invalidate()
        controlsTimer = nil
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            // Resume playback
        } else {
            // Pause playback
        }
    }
    
    private func toggleMute() {
        isMuted.toggle()
        if isMuted {
            // Mute audio
        } else {
            // Unmute audio
        }
    }
    
    private func setVolume(_ newVolume: Double) {
        volume = newVolume
        // Set actual volume
    }
    
    private func seekToTime(_ time: Double) {
        currentTime = time
        // Seek to time in player
    }
    
    private func seekForward() {
        let newTime = min(currentTime + 15, duration)
        seekToTime(newTime)
    }
    
    private func seekBackward() {
        let newTime = max(currentTime - 15, 0)
        seekToTime(newTime)
    }
    
    private func toggleFullScreen() {
        isFullScreen.toggle()
    }
    
    private func handleDragGesture(_ value: DragGesture.Value) {
        let translation = value.translation
        let screenHeight = UIScreen.main.bounds.height
        
        if value.location.y < screenHeight / 2 {
            // Adjust brightness
            let change = -translation.y / screenHeight
            brightness = max(0, min(1, brightness + change))
            setBrightness(brightness)
        } else {
            // Adjust volume
            let change = -translation.y / screenHeight
            volume = max(0, min(1, volume + change))
            setVolume(volume)
        }
    }
    
    private func setBrightness(_ newBrightness: Double) {
        brightness = newBrightness
        UIScreen.main.brightness = CGFloat(brightness)
    }
    
    private func toggleControlsWithTimer() {
        showControls.toggle()
        if showControls {
            showControlsTemporarily()
        }
    }
    
    private func showControlsTemporarily() {
        showControls = true
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation {
                showControls = false
            }
        }
    }
    
    private func timeString(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - StreamQuality
enum StreamQuality: String, CaseIterable {
    case auto = "auto"
    case source = "source"
    case p1080 = "1080p"
    case p720 = "720p"
    case p480 = "480p"
    case p360 = "360p"
    case p160 = "160p"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .source: return "Source"
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
        case .p360: return "360p"
        case .p160: return "160p"
        }
    }
}

// MARK: - StreamyyyMiniPlayer
struct StreamyyyMiniPlayer: View {
    let stream: AppStream
    @Binding var isVisible: Bool
    @State private var isPlaying = true
    @State private var isMuted = false
    @State private var offset = CGSize.zero
    @State private var position = CGPoint(x: UIScreen.main.bounds.width - 120, y: 200)
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // Video thumbnail
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack {
                                Image(systemName: "play.tv.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if stream.isLive {
                                    HStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 4, height: 4)
                                        Text("LIVE")
                                            .font(StreamyyyTypography.captionSmall)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        )
                    
                    // Close button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isVisible = false
                                StreamyyyDesignSystem.hapticFeedback(.light)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .padding(4)
                        }
                        Spacer()
                    }
                }
                
                // Controls
                HStack {
                    Button(action: {
                        isPlaying.toggle()
                        StreamyyyDesignSystem.hapticFeedback(.light)
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundColor(StreamyyyColors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isMuted.toggle()
                        StreamyyyDesignSystem.hapticFeedback(.light)
                    }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(StreamyyyColors.textPrimary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StreamyyyColors.surface)
            }
            .frame(width: 120, height: 90)
            .cornerRadius(8)
            .shadow(
                color: StreamyyyColors.overlay.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
            .position(x: position.x + offset.width, y: position.y + offset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
                    .onEnded { value in
                        // Snap to edges
                        let screenWidth = UIScreen.main.bounds.width
                        let screenHeight = UIScreen.main.bounds.height
                        let newX = position.x + value.translation.x
                        let newY = position.y + value.translation.y
                        
                        // Constrain to screen bounds
                        let constrainedX = max(60, min(screenWidth - 60, newX))
                        let constrainedY = max(60, min(screenHeight - 120, newY))
                        
                        // Snap to nearest edge
                        let snapToLeft = constrainedX < screenWidth / 2
                        let finalX = snapToLeft ? 60 : screenWidth - 60
                        
                        withAnimation(.spring()) {
                            position = CGPoint(x: finalX, y: constrainedY)
                            offset = .zero
                        }
                    }
            )
            .onTapGesture {
                // Expand to full screen
                StreamyyyDesignSystem.hapticFeedback(.medium)
            }
            .accessibilityLabel("Mini player for \(stream.streamerName)")
            .accessibilityHint("Drag to move, tap to expand")
        }
    }
}

// MARK: - Stream Player Preview
struct StreamyyyStreamPlayerPreview: View {
    @State private var isFullScreen = false
    @State private var showMiniPlayer = false
    
    private let sampleStream = AppStream(
        id: "sample",
        title: "Sample Stream Title",
        url: "https://example.com/stream",
        platform: "Twitch",
        isLive: true,
        viewerCount: 1234,
        streamerName: "SampleStreamer",
        gameName: "Sample Game",
        thumbnailURL: "",
        language: "en",
        startedAt: Date()
    )
    
    var body: some View {
        ZStack {
            StreamyyyScreenContainer {
                VStack(spacing: StreamyyySpacing.lg) {
                    Text("Stream Player Components")
                        .headlineLarge()
                    
                    StreamyyyButton(title: "Show Full Screen Player") {
                        isFullScreen = true
                    }
                    
                    StreamyyyButton(title: "Toggle Mini Player") {
                        showMiniPlayer.toggle()
                    }
                    
                    Spacer()
                }
            }
            
            StreamyyyMiniPlayer(stream: sampleStream, isVisible: $showMiniPlayer)
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            StreamyyyStreamPlayer(stream: sampleStream, isFullScreen: $isFullScreen)
        }
    }
}

#Preview {
    StreamyyyStreamPlayerPreview()
}