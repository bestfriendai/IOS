//
//  ModernMultiStreamView.swift
//  StreamyyyApp
//
//  Enhanced multi-stream view with modern UI/UX improvements
//  Glassmorphism design, improved accessibility, and production-ready features
//

import SwiftUI
import Combine

struct ModernMultiStreamView: View {
    @StateObject private var streamManager = MultiStreamManager()
    @StateObject private var audioManager = MultiStreamAudioManager.shared
    @State private var showingStreamPicker = false
    @State private var selectedSlotIndex = 0
    @State private var showingQualityControl = false
    @State private var showingLayoutOptions = false
    @State private var isFullscreenMode = false
    @State private var focusedStreamIndex: Int? = nil
    
    var body: some View {
        ZStack {
            // Background with gradient
            backgroundView
            
            if isFullscreenMode {
                fullscreenView
            } else {
                normalView
            }
            
            // Floating controls overlay
            if !isFullscreenMode {
                floatingControlsOverlay
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(isFullscreenMode)
        .sheet(isPresented: $showingStreamPicker) {
            EnhancedStreamPickerView(selectedSlotIndex: selectedSlotIndex) { stream in
                streamManager.addStream(stream, to: selectedSlotIndex)
                showingStreamPicker = false
            }
        }
        .sheet(isPresented: $showingQualityControl) {
            QualityControlPanel()
        }
        .sheet(isPresented: $showingLayoutOptions) {
            LayoutOptionsPanel(streamManager: streamManager)
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated background elements
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.15),
                                Color.cyan.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .offset(
                        x: CGFloat.random(in: -200...200),
                        y: CGFloat.random(in: -200...200)
                    )
                    .blur(radius: 100)
                    .animation(
                        .easeInOut(duration: Double.random(in: 15...25))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 3.0),
                        value: streamManager.currentLayout
                    )
            }
        }
    }
    
    // MARK: - Normal View Layout
    private var normalView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with controls
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                // Main stream grid
                modernStreamGrid(geometry: geometry)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                
                Spacer(minLength: 100) // Space for floating controls
            }
        }
    }
    
    // MARK: - Modern Header
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                // App branding
                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "tv")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Text("StreamHub")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Quick actions
                HStack(spacing: 12) {
                    quickActionButton(
                        icon: "speaker.slash.fill",
                        action: { audioManager.muteAll() }
                    )
                    
                    quickActionButton(
                        icon: "gearshape.fill",
                        action: { showingQualityControl = true }
                    )
                    
                    quickActionButton(
                        icon: "rectangle.3.offgrid",
                        action: { showingLayoutOptions = true }
                    )
                }
            }
            
            // Stream status bar
            streamStatusBar
        }
    }
    
    private func quickActionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(ModernButtonStyle())
    }
    
    private var streamStatusBar: some View {
        HStack {
            // Active streams indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .opacity(activeStreamCount > 0 ? 1 : 0.3)
                
                Text("\(activeStreamCount)/\(streamManager.currentLayout.maxStreams) Active")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Layout indicator
            Text(streamManager.currentLayout.displayName)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        }
    }
    
    // MARK: - Modern Stream Grid
    private func modernStreamGrid(geometry: GeometryProxy) -> some View {
        let itemSize = calculateOptimalItemSize(geometry: geometry)
        
        return LazyVGrid(
            columns: Array(
                repeating: GridItem(.fixed(itemSize.width), spacing: 16),
                count: streamManager.currentLayout.columns
            ),
            spacing: 16
        ) {
            ForEach(Array(streamManager.activeStreams.enumerated()), id: \.element.id) { index, slot in
                ModernStreamSlot(
                    slot: slot,
                    index: index,
                    isFocused: focusedStreamIndex == index,
                    onTap: {
                        selectedSlotIndex = index
                        if slot.stream == nil {
                            showingStreamPicker = true
                        }
                    },
                    onRemove: {
                        streamManager.removeStream(from: index)
                    },
                    onFocus: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            focusedStreamIndex = focusedStreamIndex == index ? nil : index
                        }
                    },
                    onFullscreen: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedSlotIndex = index
                            isFullscreenMode = true
                        }
                    }
                )
                .frame(width: itemSize.width, height: itemSize.height)
                .scaleEffect(focusedStreamIndex == index ? 1.05 : 1.0)
                .zIndex(focusedStreamIndex == index ? 1 : 0)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: streamManager.currentLayout)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: focusedStreamIndex)
    }
    
    // MARK: - Floating Controls
    private var floatingControlsOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                // Layout selector
                layoutSelectorButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
            }
        }
    }
    
    private var layoutSelectorButton: some View {
        Menu {
            ForEach(MultiStreamLayout.allCases, id: \.self) { layout in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        streamManager.updateLayout(layout)
                    }
                }) {
                    Label(layout.displayName, systemImage: layout.icon)
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: streamManager.currentLayout.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                
                Text(streamManager.currentLayout.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
    
    // MARK: - Fullscreen View
    private var fullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if selectedSlotIndex < streamManager.activeStreams.count,
               let stream = streamManager.activeStreams[selectedSlotIndex].stream {
                
                MultiStreamTwitchPlayer(
                    channelName: stream.getChannelName() ?? "shroud",
                    isMuted: .constant(false),
                    isVisible: true,
                    quality: .source
                )
                .ignoresSafeArea()
                
                // Fullscreen controls
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isFullscreenMode = false
                            }
                        }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        .buttonStyle(ModernButtonStyle())
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(stream.title)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(stream.userName)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding()
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private var activeStreamCount: Int {
        streamManager.activeStreams.compactMap { $0.stream }.count
    }
    
    private func calculateOptimalItemSize(geometry: GeometryProxy) -> CGSize {
        let safeArea = geometry.safeAreaInsets
        let availableWidth = geometry.size.width - safeArea.leading - safeArea.trailing - 32 // padding
        let availableHeight = geometry.size.height - safeArea.top - safeArea.bottom - 200 // header + controls
        
        let columns = CGFloat(streamManager.currentLayout.columns)
        let spacing: CGFloat = 16 * (columns - 1)
        
        let itemWidth = (availableWidth - spacing) / columns
        let itemHeight = itemWidth * (9.0 / 16.0) // 16:9 aspect ratio
        
        // Ensure minimum usable size
        let minWidth: CGFloat = 120
        let minHeight: CGFloat = 67.5
        
        return CGSize(
            width: max(minWidth, itemWidth),
            height: max(minHeight, itemHeight)
        )
    }
}

// MARK: - Modern Stream Slot
struct ModernStreamSlot: View {
    let slot: StreamSlot
    let index: Int
    let isFocused: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let onFocus: () -> Void
    let onFullscreen: () -> Void
    
    @StateObject private var audioManager = MultiStreamAudioManager.shared
    @State private var isMuted: Bool = true
    @State private var showingControls = false
    @State private var controlsOpacity: Double = 0
    
    var body: some View {
        ZStack {
            if let stream = slot.stream {
                activeStreamView(stream: stream)
            } else {
                emptySlotView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isFocused ?
                    LinearGradient(
                        colors: [Color.purple, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isFocused ? 3 : 1
                )
        )
        .shadow(
            color: isFocused ? Color.purple.opacity(0.3) : Color.black.opacity(0.2),
            radius: isFocused ? 20 : 8,
            x: 0,
            y: isFocused ? 8 : 4
        )
        .onTapGesture { onTap() }
        .onLongPressGesture { onFocus() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AudioStreamChanged"))) { obj in
            let activeId = obj.object as? String
            self.isMuted = activeId != slot.stream?.id
        }
    }
    
    private func activeStreamView(stream: TwitchStream) -> some View {
        ZStack {
            // Stream player
            MultiStreamTwitchPlayer(
                channelName: stream.getChannelName() ?? stream.userLogin,
                isMuted: $isMuted,
                isVisible: true,
                quality: .medium
            )
            .onMultiStreamEvents(
                onReady: {
                    print("Stream \(stream.userLogin) ready")
                },
                onStateChange: { state in
                    print("Stream \(stream.userLogin) state: \(state.displayName)")
                },
                onError: { error in
                    print("Stream \(stream.userLogin) error: \(error)")
                }
            )
            
            // Controls overlay
            if showingControls {
                streamControlsOverlay(stream: stream)
            }
        }
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
        .gesture(
            TapGesture(count: 2)
                .onEnded { onFullscreen() }
        )
    }
    
    private func streamControlsOverlay(stream: TwitchStream) -> some View {
        VStack {
            // Top controls
            HStack {
                Text(stream.userName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.8))
                        )
                }
                .buttonStyle(ModernButtonStyle())
            }
            .padding(8)
            
            Spacer()
            
            // Bottom controls
            HStack {
                Button(action: {
                    audioManager.setActiveAudioStream(stream.id)
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isMuted ? .white : .green)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(ModernButtonStyle())
                
                Spacer()
                
                Button(action: onFocus) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(ModernButtonStyle())
                
                Button(action: onFullscreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(ModernButtonStyle())
            }
            .padding(8)
        }
        .background(
            Color.black.opacity(0.3)
                .blur(radius: 10)
        )
        .transition(.opacity)
    }
    
    private var emptySlotView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                )
            
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                
                VStack(spacing: 4) {
                    Text("Add Stream")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("Tap to browse")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .onTapGesture { onTap() }
    }
}

// MARK: - Modern Button Style
struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Layout Extensions
extension MultiStreamLayout {
    var icon: String {
        switch self {
        case .single: return "square"
        case .twoByTwo: return "square.grid.2x2"
        case .threeByThree: return "square.grid.3x3"
        case .fourByFour: return "square.grid.4x4"
        }
    }
}

// MARK: - Preview
#Preview {
    ModernMultiStreamView()
}