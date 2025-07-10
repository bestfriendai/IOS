//
//  AdvancedMultiStreamView.swift
//  StreamyyyApp
//
//  Advanced multi-stream viewing interface with interactive features
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers

// MARK: - Advanced Multi-Stream View
struct AdvancedMultiStreamView: View {
    @StateObject private var layoutManager = AdvancedLayoutManager()
    @StateObject private var streamManager = MultiStreamManager()
    @StateObject private var audioManager = MultiStreamAudioManager.shared
    @StateObject private var recordingManager = StreamRecordingManager()
    
    @State private var showingStreamPicker = false
    @State private var showingLayoutPresets = false
    @State private var showingStreamComparison = false
    @State private var showingRecordingControls = false
    @State private var selectedSlotIndex = 0
    @State private var draggedStream: TwitchStream?
    @State private var dropTargetIndex: Int?
    @State private var showingLayoutCustomizer = false
    @State private var searchText = ""
    
    // Gesture states
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Advanced Controls Bar
                        AdvancedControlsBar(
                            layoutManager: layoutManager,
                            streamManager: streamManager,
                            recordingManager: recordingManager,
                            onShowStreamPicker: { index in
                                selectedSlotIndex = index
                                showingStreamPicker = true
                            },
                            onShowLayoutPresets: { showingLayoutPresets = true },
                            onShowComparison: { showingStreamComparison = true },
                            onToggleRecording: { showingRecordingControls.toggle() }
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Main Stream Grid
                        AdvancedStreamGridView(
                            streamManager: streamManager,
                            layoutManager: layoutManager,
                            audioManager: audioManager,
                            recordingManager: recordingManager,
                            containerSize: geometry.size,
                            onSlotTap: { index in
                                selectedSlotIndex = index
                                showingStreamPicker = true
                            },
                            onStreamMove: { from, to in
                                moveStream(from: from, to: to)
                            },
                            onStreamFocus: { streamId in
                                focusOnStream(streamId)
                            }
                        )
                        .padding(.horizontal, 8)
                        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                            handleStreamDrop(providers: providers)
                        }
                        
                        // Picture-in-Picture Overlay
                        PictureInPictureOverlay(
                            layoutManager: layoutManager,
                            audioManager: audioManager
                        )
                    }
                }
            }
            .navigationTitle("Advanced Multi-Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: { showingLayoutCustomizer = true }) {
                            Image(systemName: "square.grid.3x3.square")
                        }
                        
                        Button(action: { layoutManager.toggleFocusMode() }) {
                            Image(systemName: layoutManager.isInFocusMode ? "viewfinder.circle.fill" : "viewfinder.circle")
                                .foregroundColor(layoutManager.isInFocusMode ? .purple : .primary)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear All", role: .destructive) {
                            clearAllStreams()
                        }
                        
                        Button("Export Layout") {
                            exportCurrentLayout()
                        }
                        
                        Button("Performance Monitor") {
                            showPerformanceMonitor()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingStreamPicker) {
            AdvancedStreamPickerView(
                selectedSlotIndex: selectedSlotIndex,
                onStreamSelected: { stream in
                    addStream(stream, to: selectedSlotIndex)
                    showingStreamPicker = false
                }
            )
        }
        .sheet(isPresented: $showingLayoutPresets) {
            LayoutPresetsView(layoutManager: layoutManager)
        }
        .sheet(isPresented: $showingStreamComparison) {
            StreamComparisonView(streamManager: streamManager)
        }
        .sheet(isPresented: $showingRecordingControls) {
            RecordingControlsView(recordingManager: recordingManager)
        }
        .sheet(isPresented: $showingLayoutCustomizer) {
            LayoutCustomizerView(layoutManager: layoutManager)
        }
    }
    
    // MARK: - Stream Management
    private func addStream(_ stream: TwitchStream, to slotIndex: Int) {
        streamManager.addStream(stream, to: slotIndex)
        
        // Auto-enable audio for first stream
        if streamManager.activeStreams.compactMap({ $0.stream }).count == 1 {
            audioManager.setActiveAudioStream(stream.id)
        }
    }
    
    private func moveStream(from sourceIndex: Int, to destinationIndex: Int) {
        streamManager.activeStreams.swapAt(sourceIndex, destinationIndex)
    }
    
    private func focusOnStream(_ streamId: String) {
        if let index = streamManager.activeStreams.firstIndex(where: { $0.stream?.id == streamId }) {
            layoutManager.focusOnStream(index)
        }
    }
    
    private func clearAllStreams() {
        streamManager.clearAll()
        recordingManager.stopAllRecordings()
        audioManager.muteAll()
    }
    
    private func handleStreamDrop(providers: [NSItemProvider]) -> Bool {
        // Handle external stream URL drops
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let urlString = String(data: data, encoding: .utf8),
                   let url = URL(string: urlString) {
                    // Process dropped stream URL
                    processDroppedStreamURL(url)
                }
            }
        }
        return true
    }
    
    private func processDroppedStreamURL(_ url: URL) {
        // Implementation for processing dropped stream URLs
        // This would extract stream information and add to available slot
        print("Processing dropped stream URL: \(url)")
    }
    
    private func exportCurrentLayout() {
        layoutManager.saveLayoutPreset(name: "Exported Layout \(Date().formatted())")
    }
    
    private func showPerformanceMonitor() {
        // Implementation for showing performance monitor
        print("Showing performance monitor")
    }
}

// MARK: - Advanced Controls Bar
struct AdvancedControlsBar: View {
    @ObservedObject var layoutManager: AdvancedLayoutManager
    @ObservedObject var streamManager: MultiStreamManager
    @ObservedObject var recordingManager: StreamRecordingManager
    
    let onShowStreamPicker: (Int) -> Void
    let onShowLayoutPresets: () -> Void
    let onShowComparison: () -> Void
    let onToggleRecording: () -> Void
    
    var body: some View {
        HStack {
            // Layout Controls
            Menu {
                Button("2×2 Grid") {
                    layoutManager.switchToGridLayout(columns: 2)
                }
                Button("3×3 Grid") {
                    layoutManager.switchToGridLayout(columns: 3)
                }
                Button("Picture-in-Picture") {
                    layoutManager.switchToPiPLayout()
                }
                Button("Mosaic") {
                    layoutManager.switchToMosaicLayout()
                }
                Button("Custom Bento") {
                    layoutManager.applyBentoTemplate(.featured)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: currentLayoutIcon)
                    Text(currentLayoutName)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.1)).cornerRadius(8).foregroundColor(.white)
            }
            
            Spacer()
            
            // Quick Actions
            HStack(spacing: 12) {
                // Add Stream Button
                Button(action: {
                    if let emptyIndex = streamManager.activeStreams.firstIndex(where: { $0.stream == nil }) {
                        onShowStreamPicker(emptyIndex)
                    }
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.green)
                }
                
                // Layout Presets
                Button(action: onShowLayoutPresets) {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundColor(.blue)
                }
                
                // Stream Comparison
                Button(action: onShowComparison) {
                    Image(systemName: "rectangle.split.2x2")
                        .foregroundColor(.orange)
                }
                
                // Recording Controls
                Button(action: onToggleRecording) {
                    Image(systemName: recordingManager.isRecording ? "record.circle.fill" : "record.circle")
                        .foregroundColor(recordingManager.isRecording ? .red : .white)
                }
            }
        }
    }
    
    private var currentLayoutIcon: String {
        switch layoutManager.currentLayout {
        case .grid: return "grid"
        case .pip: return "pip.enter"
        case .focus: return "viewfinder"
        case .mosaic: return "square.grid.3x3"
        case .customBento: return "square.dashed"
        }
    }
    
    private var currentLayoutName: String {
        switch layoutManager.currentLayout {
        case .grid: return "Grid"
        case .pip: return "PiP"
        case .focus: return "Focus"
        case .mosaic: return "Mosaic"
        case .customBento: return "Bento"
        }
    }
}

// MARK: - Advanced Stream Grid View
struct AdvancedStreamGridView: View {
    @ObservedObject var streamManager: MultiStreamManager
    @ObservedObject var layoutManager: AdvancedLayoutManager
    @ObservedObject var audioManager: MultiStreamAudioManager
    @ObservedObject var recordingManager: StreamRecordingManager
    
    let containerSize: CGSize
    let onSlotTap: (Int) -> Void
    let onStreamMove: (Int, Int) -> Void
    let onStreamFocus: (String) -> Void
    
    var body: some View {
        let streams = streamManager.activeStreams.compactMap { $0.stream }
        let positions = layoutManager.getTwitchStreamPositions(for: streams, in: containerSize)
        
        ZStack {
            ForEach(Array(positions.enumerated()), id: \.offset) { index, position in
                AdvancedStreamSlotView(
                    stream: position.stream,
                    position: position,
                    index: index,
                    audioManager: audioManager,
                    recordingManager: recordingManager,
                    onTap: { onSlotTap(index) },
                    onMove: { dragIndex, dropIndex in
                        onStreamMove(dragIndex, dropIndex)
                    },
                    onFocus: { streamId in
                        onStreamFocus(streamId)
                    },
                    onRemove: {
                        streamManager.removeStream(from: index)
                    }
                )
                .position(x: position.frame.midX, y: position.frame.midY)
                .frame(width: position.frame.width, height: position.frame.height)
                .opacity(position.opacity)
                .scaleEffect(position.scale)
                .zIndex(Double(position.zIndex))
                .animation(layoutManager.getAnimationConfiguration(), value: position.frame)
            }
            
            // Empty slots for remaining positions
            ForEach(streams.count..<streamManager.currentLayout.maxStreams, id: \.self) { index in
                EmptyStreamSlotView(
                    index: index,
                    onTap: { onSlotTap(index) }
                )
                .frame(width: 100, height: 56)
                .position(x: 100, y: CGFloat(index * 70) + 100)
            }
        }
    }
}

// MARK: - Advanced Stream Slot View
struct AdvancedStreamSlotView: View {
    let stream: TwitchStream
    let position: TwitchStreamPosition
    let index: Int
    
    @ObservedObject var audioManager: MultiStreamAudioManager
    @ObservedObject var recordingManager: StreamRecordingManager
    
    let onTap: () -> Void
    let onMove: (Int, Int) -> Void
    let onFocus: (String) -> Void
    let onRemove: () -> Void
    
    @State private var showingControls = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            // Stream Player
            EnhancedTwitchPlayerView(
                stream: stream,
                isAudioActive: position.isAudioActive,
                isCompact: true
            )
            .cornerRadius(8)
            
            // Recording Indicator
            if position.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        RecordingIndicatorView()
                            .padding(8)
                    }
                    Spacer()
                }
            }
            
            // Audio Active Indicator
            if position.isAudioActive {
                VStack {
                    Spacer()
                    HStack {
                        AudioWaveIndicatorView()
                            .padding(8)
                        Spacer()
                    }
                }
            }
            
            // Stream Controls Overlay
            if showingControls {
                StreamControlsOverlay(
                    stream: stream,
                    isAudioActive: position.isAudioActive,
                    isRecording: position.isRecording,
                    onAudioToggle: {
                        audioManager.setActiveAudioStream(stream.id)
                    },
                    onRecordingToggle: {
                        if position.isRecording {
                            recordingManager.stopRecording(for: stream.id)
                        } else {
                            recordingManager.startRecording(for: stream.id)
                        }
                    },
                    onFocus: {
                        onFocus(stream.id)
                    },
                    onRemove: onRemove
                )
            }
        }
        .offset(dragOffset)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .onTapGesture {
            if showingControls {
                showingControls = false
            } else {
                onTap()
            }
        }
        .onLongPressGesture {
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
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    isDragging = true
                }
                .onEnded { value in
                    dragOffset = .zero
                    isDragging = false
                    
                    // Handle drop logic here
                    // Calculate which slot the stream was dropped on
                    // Call onMove if needed
                }
        )
    }
}

// MARK: - Empty Stream Slot View
struct EmptyStreamSlotView: View {
    let index: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .background(Color.black.opacity(0.3))
                
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Add Stream")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .cornerRadius(8)
    }
}

// MARK: - Stream Controls Overlay
struct StreamControlsOverlay: View {
    let stream: TwitchStream
    let isAudioActive: Bool
    let isRecording: Bool
    
    let onAudioToggle: () -> Void
    let onRecordingToggle: () -> Void
    let onFocus: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                // Stream Title
                Text(stream.userName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                
                Spacer()
                
                // Remove Button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(8)
            
            Spacer()
            
            HStack {
                // Audio Toggle
                Button(action: onAudioToggle) {
                    Image(systemName: isAudioActive ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundColor(isAudioActive ? .green : .white)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                
                // Recording Toggle
                Button(action: onRecordingToggle) {
                    Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                        .foregroundColor(isRecording ? .red : .white)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Focus Button
                Button(action: onFocus) {
                    Image(systemName: "viewfinder")
                        .foregroundColor(.purple)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Enhanced Twitch Player View
struct EnhancedTwitchPlayerView: UIViewRepresentable {
    let stream: TwitchStream
    let isAudioActive: Bool
    let isCompact: Bool
    
    func makeUIView(context: Context) -> TwitchPlayerView {
        let playerView = TwitchPlayerView()
        playerView.configure(with: stream, isAudioActive: isAudioActive, isCompact: isCompact)
        return playerView
    }
    
    func updateUIView(_ uiView: TwitchPlayerView, context: Context) {
        uiView.updateAudioState(isAudioActive)
    }
}

// MARK: - Twitch Player View (UIKit)
class TwitchPlayerView: UIView {
    private var webView: WKWebView?
    private var stream: TwitchStream?
    
    func configure(with stream: TwitchStream, isAudioActive: Bool, isCompact: Bool) {
        self.stream = stream
        setupWebView(isAudioActive: isAudioActive, isCompact: isCompact)
    }
    
    func updateAudioState(_ isAudioActive: Bool) {
        // Update audio state in web view
        webView?.evaluateJavaScript("updateAudioState(\(isAudioActive))")
    }
    
    private func setupWebView(isAudioActive: Bool, isCompact: Bool) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlaybook = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: bounds, configuration: config)
        guard let webView = webView else { return }
        
        webView.backgroundColor = UIColor.black
        webView.isOpaque = true
        webView.scrollView.isScrollEnabled = false
        
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        loadTwitchStream(isAudioActive: isAudioActive, isCompact: isCompact)
    }
    
    private func loadTwitchStream(isAudioActive: Bool, isCompact: Bool) {
        guard let stream = stream else { return }
        
        let html = generateTwitchPlayerHTML(
            channelName: stream.userLogin,
            isAudioActive: isAudioActive,
            isCompact: isCompact
        )
        
        webView?.loadHTMLString(html, baseURL: URL(string: "https://player.twitch.tv"))
    }
    
    private func generateTwitchPlayerHTML(channelName: String, isAudioActive: Bool, isCompact: Bool) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                iframe { width: 100%; height: 100%; border: none; }
            </style>
        </head>
        <body>
            <iframe 
                src="https://player.twitch.tv/?channel=\(channelName)&parent=localhost&muted=\(!isAudioActive)&autoplay=true&controls=\(!isCompact)"
                allowfullscreen>
            </iframe>
            <script>
                function updateAudioState(isActive) {
                    // Update audio state
                    console.log('Audio state updated:', isActive);
                }
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Recording Indicator View
struct RecordingIndicatorView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(isAnimating ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(), value: isAnimating)
            
            Text("REC")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Audio Wave Indicator View
struct AudioWaveIndicatorView: View {
    @State private var waveHeights: [CGFloat] = [4, 8, 6, 10, 5]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 2, height: waveHeights[index])
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: waveHeights[index])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
        .onAppear {
            startWaveAnimation()
        }
    }
    
    private func startWaveAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation {
                waveHeights = waveHeights.map { _ in CGFloat.random(in: 4...12) }
            }
        }
    }
}

#Preview {
    AdvancedMultiStreamView()
}