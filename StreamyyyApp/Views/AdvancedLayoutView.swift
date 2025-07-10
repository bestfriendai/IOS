//
//  AdvancedLayoutView.swift
//  StreamyyyApp
//
//  Advanced multi-stream layout view with Focus mode and Custom Bento grid
//  Created by Claude Code on 2025-07-10
//

import SwiftUI

// MARK: - Advanced Layout View

struct AdvancedLayoutView: View {
    let streams: [Stream]
    
    @StateObject private var layoutManager = AdvancedLayoutManager()
    @State private var selectedStreamIndex: Int = 0
    @State private var showLayoutSelector = false
    @State private var showBentoTemplates = false
    @State private var containerSize: CGSize = .zero
    @State private var draggedStream: Stream?
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Stream layout
                streamLayoutView(geometry: geometry)
                
                // Controls overlay
                controlsOverlay
                
                // Focus mode overlay
                if layoutManager.isInFocusMode {
                    focusModeOverlay
                }
            }
            .onAppear {
                containerSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                containerSize = newSize
            }
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        layoutManager.toggleFocusMode()
                    }
            )
            .sheet(isPresented: $showLayoutSelector) {
                LayoutSelectorSheet(layoutManager: layoutManager)
            }
            .sheet(isPresented: $showBentoTemplates) {
                BentoTemplateSheet(layoutManager: layoutManager)
            }
        }
    }
    
    // MARK: - Stream Layout View
    
    private func streamLayoutView(geometry: GeometryProxy) -> some View {
        let positions = layoutManager.getStreamPositions(for: streams, in: geometry.size)
        
        return ZStack {
            ForEach(positions.indices, id: \.self) { index in
                let position = positions[index]
                
                StreamView(
                    stream: position.stream,
                    isSelected: selectedStreamIndex == index,
                    isFocused: layoutManager.isInFocusMode && layoutManager.focusedStreamIndex == index
                )
                .frame(width: position.frame.width, height: position.frame.height)
                .position(
                    x: position.frame.midX,
                    y: position.frame.midY
                )
                .scaleEffect(position.scale)
                .opacity(position.opacity)
                .zIndex(Double(position.zIndex))
                .animation(layoutManager.getAnimationConfiguration(), value: position.frame)
                .animation(layoutManager.getAnimationConfiguration(), value: position.opacity)
                .animation(layoutManager.getAnimationConfiguration(), value: position.scale)
                .onTapGesture {
                    handleStreamTap(index: index)
                }
                .onLongPressGesture {
                    handleStreamLongPress(index: index)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleStreamDrag(stream: position.stream, offset: value.translation)
                        }
                        .onEnded { _ in
                            handleStreamDragEnd()
                        }
                )
            }
        }
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        VStack {
            // Top controls
            HStack {
                // Layout type indicator
                layoutTypeIndicator
                
                Spacer()
                
                // Layout controls
                layoutControls
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
            
            // Bottom controls
            HStack {
                // Stream navigation (in focus mode)
                if layoutManager.isInFocusMode {
                    focusNavigationControls
                }
                
                Spacer()
                
                // Layout actions
                layoutActionButtons
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private var layoutTypeIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: currentLayoutIcon)
                .font(.title2)
                .foregroundColor(.white)
            
            Text(currentLayoutName)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            if layoutManager.isInFocusMode {
                Text("• Focus Mode")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    private var layoutControls: some View {
        HStack(spacing: 12) {
            // Grid layout
            Button(action: { layoutManager.switchToGridLayout() }) {
                Image(systemName: "grid")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            // PiP layout
            Button(action: { layoutManager.switchToPiPLayout() }) {
                Image(systemName: "pip")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            // Mosaic layout
            Button(action: { layoutManager.switchToMosaicLayout() }) {
                Image(systemName: "square.3.layers.3d")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            // More layouts
            Button(action: { showLayoutSelector = true }) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }
    
    private var focusNavigationControls: some View {
        HStack(spacing: 16) {
            Button(action: { layoutManager.focusPreviousStream(streamCount: streams.count) }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            Text("\(layoutManager.focusedStreamIndex + 1) of \(streams.count)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            
            Button(action: { layoutManager.focusNextStream(streamCount: streams.count) }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }
    
    private var layoutActionButtons: some View {
        HStack(spacing: 12) {
            // Focus mode toggle
            Button(action: { layoutManager.toggleFocusMode() }) {
                Image(systemName: layoutManager.isInFocusMode ? "viewfinder.circle.fill" : "viewfinder.circle")
                    .font(.title2)
                    .foregroundColor(layoutManager.isInFocusMode ? .orange : .white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            // Bento templates
            Button(action: { showBentoTemplates = true }) {
                Image(systemName: "square.grid.3x3")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }
    
    // MARK: - Focus Mode Overlay
    
    private var focusModeOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button("Exit Focus") {
                    layoutManager.exitFocusMode()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange, in: Capsule())
                .padding()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentLayoutIcon: String {
        switch layoutManager.currentLayout {
        case .grid: return "grid"
        case .pip: return "pip"
        case .focus: return "viewfinder.circle.fill"
        case .mosaic: return "square.3.layers.3d"
        case .customBento: return "square.grid.3x3"
        }
    }
    
    private var currentLayoutName: String {
        switch layoutManager.currentLayout {
        case .grid: return "Grid"
        case .pip: return "Picture-in-Picture"
        case .focus: return "Focus"
        case .mosaic: return "Mosaic"
        case .customBento: return "Bento"
        }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleStreamTap(index: Int) {
        selectedStreamIndex = index
        
        if layoutManager.isInFocusMode {
            layoutManager.focusOnStream(index)
        }
    }
    
    private func handleStreamLongPress(index: Int) {
        layoutManager.focusOnStream(index)
    }
    
    private func handleStreamDrag(stream: Stream, offset: CGSize) {
        draggedStream = stream
        dragOffset = offset
    }
    
    private func handleStreamDragEnd() {
        draggedStream = nil
        dragOffset = .zero
    }
}

// MARK: - Stream View

struct StreamView: View {
    let stream: Stream
    let isSelected: Bool
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            // Stream content placeholder
            Rectangle()
                .fill(stream.platform.color.opacity(0.3))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: stream.platform.systemImage)
                            .font(.largeTitle)
                            .foregroundColor(stream.platform.color)
                        
                        Text(stream.title ?? "Stream")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Text(stream.channelName ?? "Channel")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                )
            
            // Selection indicator
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue, lineWidth: 3)
            }
            
            // Focus indicator
            if isFocused {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.orange, lineWidth: 4)
                    .overlay(
                        VStack {
                            HStack {
                                Image(systemName: "viewfinder.circle.fill")
                                    .foregroundColor(.orange)
                                    .padding(8)
                                    .background(.black.opacity(0.8), in: Circle())
                                
                                Spacer()
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                    )
            }
            
            // Platform indicator
            VStack {
                HStack {
                    Spacer()
                    
                    Image(systemName: stream.platform.icon)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(stream.platform.color, in: Circle())
                }
                
                Spacer()
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Layout Selector Sheet

struct LayoutSelectorSheet: View {
    let layoutManager: AdvancedLayoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Grid layouts
                    layoutSection(title: "Grid Layouts") {
                        LayoutOptionCard(
                            title: "2x2 Grid",
                            icon: "grid",
                            description: "Classic 2x2 grid layout"
                        ) {
                            layoutManager.switchToGridLayout(columns: 2)
                            dismiss()
                        }
                        
                        LayoutOptionCard(
                            title: "3x3 Grid",
                            icon: "grid",
                            description: "3x3 grid for many streams"
                        ) {
                            layoutManager.switchToGridLayout(columns: 3)
                            dismiss()
                        }
                        
                        LayoutOptionCard(
                            title: "4x4 Grid",
                            icon: "grid",
                            description: "4x4 grid for maximum streams"
                        ) {
                            layoutManager.switchToGridLayout(columns: 4)
                            dismiss()
                        }
                    }
                    
                    // Mosaic layouts
                    layoutSection(title: "Mosaic Layouts") {
                        LayoutOptionCard(
                            title: "Balanced",
                            icon: "square.3.layers.3d",
                            description: "Evenly distributed streams"
                        ) {
                            layoutManager.switchToMosaicLayout(pattern: .balanced)
                            dismiss()
                        }
                        
                        LayoutOptionCard(
                            title: "Asymmetric",
                            icon: "square.3.layers.3d.down.right",
                            description: "Featured stream with sidebar"
                        ) {
                            layoutManager.switchToMosaicLayout(pattern: .asymmetric)
                            dismiss()
                        }
                        
                        LayoutOptionCard(
                            title: "Pyramid",
                            icon: "triangle",
                            description: "Top featured, bottom grid"
                        ) {
                            layoutManager.switchToMosaicLayout(pattern: .pyramid)
                            dismiss()
                        }
                    }
                    
                    // PiP layouts
                    layoutSection(title: "Picture-in-Picture") {
                        LayoutOptionCard(
                            title: "Bottom Right",
                            icon: "pip",
                            description: "Small streams in bottom corner"
                        ) {
                            layoutManager.switchToPiPLayout(pipPosition: .bottomTrailing)
                            dismiss()
                        }
                        
                        LayoutOptionCard(
                            title: "Top Right",
                            icon: "pip",
                            description: "Small streams in top corner"
                        ) {
                            layoutManager.switchToPiPLayout(pipPosition: .topTrailing)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Layout Options")
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
    
    private func layoutSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content()
        }
    }
}

// MARK: - Bento Template Sheet

struct BentoTemplateSheet: View {
    let layoutManager: AdvancedLayoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 16)
                ], spacing: 16) {
                    ForEach(BentoTemplate.allCases, id: \.self) { template in
                        BentoTemplateCard(template: template) {
                            layoutManager.applyBentoTemplate(template)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Bento Templates")
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

// MARK: - Layout Option Card

struct LayoutOptionCard: View {
    let title: String
    let icon: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bento Template Card

struct BentoTemplateCard: View {
    let template: BentoTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Template preview
                BentoPreview(template: template)
                    .frame(height: 100)
                
                // Template info
                VStack(spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(template.createConfiguration().cells.count) cells")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bento Preview

struct BentoPreview: View {
    let template: BentoTemplate
    
    var body: some View {
        let config = template.createConfiguration()
        
        GeometryReader { geometry in
            ZStack {
                ForEach(config.cells.indices, id: \.self) { index in
                    let cell = config.cells[index]
                    let frame = cell.getFrame(in: geometry.size, gridSize: config.gridSize)
                    
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: frame.width - 2, height: frame.height - 2)
                        .position(x: frame.midX, y: frame.midY)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .position(x: frame.midX, y: frame.midY)
                        )
                }
            }
        }
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    let sampleStreams = [
        Stream(id: "1", platform: .twitch, title: "Gaming Stream", channelName: "Streamer1"),
        Stream(id: "2", platform: .youtube, title: "Live Tutorial", channelName: "Educator"),
        Stream(id: "3", platform: .rumble, title: "News Update", channelName: "NewsChannel"),
        Stream(id: "4", platform: .twitch, title: "Art Stream", channelName: "Artist")
    ]
    
    AdvancedLayoutView(streams: sampleStreams)
}