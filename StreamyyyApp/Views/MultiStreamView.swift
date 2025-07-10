//
//  MultiStreamView.swift
//  StreamyyyApp
//
//  Multi-stream viewing page with grid layout similar to mobile Twitch multiview
//

import SwiftUI
import SwiftData

struct MultiStreamView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Stream.updatedAt, order: .reverse) private var allStreams: [Stream]
    
    @State private var activeStreams: [Stream] = []
    @State private var selectedLayoutIndex = 0
    @State private var showingStreamPicker = false
    @State private var showingLayoutPicker = false
    @State private var showingSettings = false
    
    private let layouts = ["2x2", "3x1", "4x1", "2x3"]
    private let maxStreams = [4, 3, 4, 6]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enhanced background with subtle gradients
                ZStack {
                    // Base dark background
                    Color.black
                    
                    // Subtle gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.purple.opacity(0.03),
                            Color.cyan.opacity(0.02),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Dynamic background particles for active streams
                    ForEach(0..<activeStreams.count, id: \.self) { index in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.cyan.opacity(0.02),
                                        Color.purple.opacity(0.01),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 300, height: 300)
                            .position(
                                x: geometry.size.width * CGFloat.random(in: 0.2...0.8),
                                y: geometry.size.height * CGFloat.random(in: 0.2...0.8)
                            )
                            .blur(radius: 100)
                            .animation(
                                .easeInOut(duration: Double.random(in: 8...12))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 1.0),
                                value: activeStreams.count
                            )
                    }
                }
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced top status bar
                    enhancedTopStatusBar
                    
                    // Main stream grid with improved layout
                    enhancedStreamGridView(geometry: geometry)
                    
                    // Modern bottom navigation
                    modernBottomNavigationBar
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupInitialStreams()
        }
        .sheet(isPresented: $showingStreamPicker) {
            ModernStreamPickerView(
                availableStreams: availableStreams,
                onStreamSelected: addStream
            )
        }
        .sheet(isPresented: $showingLayoutPicker) {
            ModernLayoutPickerView(
                layouts: layouts,
                selectedIndex: $selectedLayoutIndex
            )
        }
    }
    
    // MARK: - Enhanced Top Status Bar
    private var enhancedTopStatusBar: some View {
        HStack {
            // Modern layout button with glassmorphism
            Button(action: {
                showingLayoutPicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "grid")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text(layouts[selectedLayoutIndex])
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // Active streams count with modern design
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .blur(radius: 2)
                    )
                
                Text("\(activeStreams.count) Live")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.green.opacity(0.5), .cyan.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            
            Spacer()
            
            // Settings button
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.title3)
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
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
    }
    
    // MARK: - Enhanced Stream Grid View
    private func enhancedStreamGridView(geometry: GeometryProxy) -> some View {
        let layout = getGridLayout(for: selectedLayoutIndex)
        let itemSize = calculateItemSize(geometry: geometry, layout: layout)
        
        return ScrollView {
            LazyVGrid(columns: layout, spacing: 4) {
                ForEach(Array(activeStreams.enumerated()), id: \.element.id) { index, stream in
                    EnhancedMultiStreamItemView(
                        stream: stream,
                        size: itemSize,
                        index: index,
                        onRemove: { removeStream(stream) }
                    )
                    .frame(width: itemSize.width, height: itemSize.height)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                // Enhanced add stream slots
                if activeStreams.count < maxStreams[selectedLayoutIndex] {
                    ForEach(activeStreams.count..<maxStreams[selectedLayoutIndex], id: \.self) { index in
                        EnhancedAddStreamSlotView(
                            size: itemSize,
                            slotIndex: index,
                            onTap: { showingStreamPicker = true }
                        )
                        .frame(width: itemSize.width, height: itemSize.height)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: activeStreams.count)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedLayoutIndex)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Modern Bottom Navigation Bar
    private var modernBottomNavigationBar: some View {
        HStack {
            ModernBottomNavButton(
                icon: "plus.circle.fill",
                title: "Add Stream",
                isHighlighted: true,
                action: { showingStreamPicker = true }
            )
            
            Spacer()
            
            ModernBottomNavButton(
                icon: "safari.fill",
                title: "Discover",
                action: { /* Navigate to discover */ }
            )
            
            Spacer()
            
            ModernBottomNavButton(
                icon: "rectangle.3.group.fill",
                title: "Layout",
                badgeCount: activeStreams.count,
                action: { showingLayoutPicker = true }
            )
            
            Spacer()
            
            ModernBottomNavButton(
                icon: "bookmark.fill",
                title: "Saved",
                action: { /* Show saved layouts */ }
            )
            
            Spacer()
            
            ModernBottomNavButton(
                icon: "message.fill",
                title: "Chat",
                badgeCount: 12,
                action: { /* Show chat */ }
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            ZStack {
                // Glassmorphism background
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Gradient overlay
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
            }
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
            alignment: .top
        )
    }
    
    // MARK: - Helper Methods
    private var availableStreams: [Stream] {
        allStreams.filter { stream in
            !activeStreams.contains { $0.id == stream.id }
        }
    }
    
    private func setupInitialStreams() {
        if activeStreams.isEmpty {
            // Add first few streams as default
            activeStreams = Array(allStreams.prefix(min(4, allStreams.count)))
        }
    }
    
    private func addStream(_ stream: Stream) {
        if activeStreams.count < maxStreams[selectedLayoutIndex] {
            activeStreams.append(stream)
        }
    }
    
    private func removeStream(_ stream: Stream) {
        activeStreams.removeAll { $0.id == stream.id }
    }
    
    private func getGridLayout(for index: Int) -> [GridItem] {
        switch index {
        case 0: // 2x2
            return Array(repeating: GridItem(.flexible(), spacing: 2), count: 2)
        case 1: // 3x1
            return Array(repeating: GridItem(.flexible(), spacing: 2), count: 1)
        case 2: // 4x1
            return Array(repeating: GridItem(.flexible(), spacing: 2), count: 1)
        case 3: // 2x3
            return Array(repeating: GridItem(.flexible(), spacing: 2), count: 2)
        default:
            return Array(repeating: GridItem(.flexible(), spacing: 2), count: 2)
        }
    }
    
    private func calculateItemSize(geometry: GeometryProxy, layout: [GridItem]) -> CGSize {
        let padding: CGFloat = 16
        let spacing: CGFloat = 2
        let columns = layout.count
        
        let availableWidth = geometry.size.width - padding
        let itemWidth = (availableWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        
        // Calculate rows based on layout
        let rows: Int
        switch selectedLayoutIndex {
        case 0: rows = 2 // 2x2
        case 1: rows = 3 // 3x1
        case 2: rows = 4 // 4x1
        case 3: rows = 3 // 2x3
        default: rows = 2
        }
        
        let availableHeight = geometry.size.height - 120 // Account for top/bottom bars
        let itemHeight = (availableHeight - CGFloat(rows - 1) * spacing) / CGFloat(rows)
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
}

// MARK: - Multi Stream Item View
struct MultiStreamItemView: View {
    let stream: Stream
    let size: CGSize
    let onRemove: () -> Void
    
    @State private var showingControls = false
    @State private var isMuted = false
    @State private var controlsTimer: Timer?
    
    var body: some View {
        ZStack {
            // Stream player
            StreamWebView(
                url: stream.url,
                isMuted: isMuted,
                isLoading: .constant(false),
                hasError: .constant(false)
            )
            .clipped()
            .onTapGesture {
                toggleControls()
            }
            
            // Top overlay with stream info
            VStack {
                HStack {
                    // Live indicator and viewer count
                    if stream.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Viewer count
                    if stream.viewerCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            Text(stream.formattedViewerCount)
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                    }
                }
                .padding(8)
                
                Spacer()
            }
            
            // Stream info at bottom
            VStack {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watching \(activeStreamCount)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\(stream.formattedViewerCount) viewers")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Platform indicator
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text("\(Int.random(in: 50...100)).264+ live")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Twitch")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            
            // Controls overlay
            if showingControls {
                streamControlsOverlay
            }
        }
        .background(Color.black)
        .cornerRadius(8)
    }
    
    private var streamControlsOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
            
            VStack {
                Spacer()
                
                HStack(spacing: 20) {
                    // Mute button
                    Button(action: {
                        isMuted.toggle()
                    }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    // Fullscreen button
                    Button(action: {
                        // Handle fullscreen
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    // Menu button
                    Button(action: {
                        // Show menu with remove option
                        onRemove()
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
            }
        }
        .opacity(showingControls ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: showingControls)
    }
    
    private var activeStreamCount: Int {
        // This would normally come from a shared state
        return Int.random(in: 3...5)
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingControls.toggle()
        }
        
        if showingControls {
            startControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls = false
            }
        }
    }
}

// MARK: - Add Stream Slot View
struct AddStreamSlotView: View {
    let size: CGSize
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
                
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Add Stream")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bottom Navigation Button
struct BottomNavButton: View {
    let icon: String
    let title: String
    let badgeCount: Int?
    let action: () -> Void
    
    init(icon: String, title: String, badgeCount: Int? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.badgeCount = badgeCount
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    if let count = badgeCount, count > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                    }
                }
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stream Picker View
struct StreamPickerView: View {
    let availableStreams: [Stream]
    let onStreamSelected: (Stream) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(availableStreams) { stream in
                Button(action: {
                    onStreamSelected(stream)
                    dismiss()
                }) {
                    HStack {
                        AsyncImage(url: URL(string: stream.thumbnailURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 60, height: 34)
                        .clipped()
                        .cornerRadius(4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stream.displayTitle)
                                .font(.headline)
                                .lineLimit(1)
                            
                            Text(stream.streamerName ?? "Unknown")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if stream.isLive {
                                Text("\(stream.formattedViewerCount) viewers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if stream.isLive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Add Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Layout Picker View
struct LayoutPickerView: View {
    let layouts: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Layout")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(Array(layouts.enumerated()), id: \.offset) { index, layout in
                        Button(action: {
                            selectedIndex = index
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                layoutPreview(for: index)
                                    .frame(width: 120, height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedIndex == index ? Color.blue : Color.gray.opacity(0.3),
                                                lineWidth: selectedIndex == index ? 3 : 1
                                            )
                                    )
                                
                                Text(layout)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func layoutPreview(for index: Int) -> some View {
        switch index {
        case 0: // 2x2
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 2) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.7))
                }
            }
        case 1: // 3x1
            VStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.7))
                }
            }
        case 2: // 4x1
            VStack(spacing: 2) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.7))
                }
            }
        case 3: // 2x3
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 2) {
                ForEach(0..<6) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.7))
                }
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Enhanced UI Components

// Enhanced Multi Stream Item View
struct EnhancedMultiStreamItemView: View {
    let stream: Stream
    let size: CGSize
    let index: Int
    let onRemove: () -> Void
    
    @State private var showingControls = false
    @State private var isMuted = false
    @State private var controlsTimer: Timer?
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Stream player with enhanced border
            StreamWebView(
                url: stream.url,
                isMuted: isMuted,
                isLoading: .constant(false),
                hasError: .constant(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: stream.isLive ? 
                            [.cyan.opacity(0.6), .purple.opacity(0.4)] :
                            [.gray.opacity(0.3), .gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: stream.isLive ? 2 : 1
                    )
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    toggleControls()
                }
            }
            
            // Enhanced overlays
            VStack {
                // Top overlay with improved design
                HStack {
                    if stream.isLive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                                .overlay(
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 4, height: 4)
                                        .blur(radius: 2)
                                        .scaleEffect(1.5)
                                )
                            
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(.red.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                    
                    Spacer()
                    
                    // Quality indicator
                    Text("HD")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(.cyan.opacity(0.5), lineWidth: 1)
                                )
                        )
                }
                .padding(10)
                .opacity(showingControls ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: showingControls)
                
                Spacer()
                
                // Bottom info overlay
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Slot \(index + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        if stream.viewerCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.cyan)
                                
                                Text(stream.formattedViewerCount)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Platform badge
                    Text("Twitch")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .opacity(showingControls ? 1.0 : 0.7)
            }
            
            // Enhanced controls overlay
            if showingControls {
                enhancedControlsOverlay
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var enhancedControlsOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            
            VStack {
                Spacer()
                
                HStack(spacing: 16) {
                    // Mute button with modern design
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isMuted.toggle()
                        }
                    }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                isMuted ? .red.opacity(0.5) : .cyan.opacity(0.5),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // Fullscreen button
                    Button(action: {
                        // Handle fullscreen
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // Remove button
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(.red.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                
                Spacer()
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private func toggleControls() {
        showingControls.toggle()
        
        if showingControls {
            startControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls = false
            }
        }
    }
}

// Enhanced Add Stream Slot View
struct EnhancedAddStreamSlotView: View {
    let size: CGSize
    let slotIndex: Int
    let onTap: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.3), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                    )
                
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.2), .purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    
                    VStack(spacing: 4) {
                        Text("Add Stream")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Slot \(slotIndex + 1)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            isAnimating = true
        }
    }
}

// Modern Bottom Navigation Button
struct ModernBottomNavButton: View {
    let icon: String
    let title: String
    let badgeCount: Int?
    let isHighlighted: Bool
    let action: () -> Void
    
    init(icon: String, title: String, badgeCount: Int? = nil, isHighlighted: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.badgeCount = badgeCount
        self.isHighlighted = isHighlighted
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isHighlighted {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isHighlighted ? .white : .white.opacity(0.7))
                    
                    if let count = badgeCount, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(
                                Circle()
                                    .fill(.red)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .offset(x: 12, y: -12)
                    }
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(isHighlighted ? .white : .white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// Modern Stream Picker and Layout Picker (simplified versions)
struct ModernStreamPickerView: View {
    let availableStreams: [Stream]
    let onStreamSelected: (Stream) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List(availableStreams) { stream in
                    Button(action: {
                        onStreamSelected(stream)
                        dismiss()
                    }) {
                        HStack {
                            AsyncImage(url: URL(string: stream.thumbnailURL ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                            }
                            .frame(width: 80, height: 45)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stream.displayTitle)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(stream.streamerName ?? "Unknown")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if stream.isLive {
                                    HStack(spacing: 4) {
                                        Circle().fill(.red).frame(width: 6, height: 6)
                                        Text("\(stream.formattedViewerCount) viewers")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ModernLayoutPickerView: View {
    let layouts: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Choose Layout")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                        ForEach(Array(layouts.enumerated()), id: \.offset) { index, layout in
                            Button(action: {
                                selectedIndex = index
                                dismiss()
                            }) {
                                VStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .frame(height: 80)
                                        .overlay(
                                            Text(layout)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedIndex == index ? 
                                                    LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing) :
                                                    LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                                                    lineWidth: 2
                                                )
                                        )
                                    
                                    Text(layout)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
    }
}

#Preview {
    MultiStreamView()
        .modelContainer(for: [Stream.self])
}