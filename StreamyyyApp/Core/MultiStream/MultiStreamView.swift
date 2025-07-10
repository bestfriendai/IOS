//
//  MultiStreamView.swift
//  StreamyyyApp
//
//  Main multi-stream viewing interface - the core feature of the app
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import WebKit

// MARK: - Multi Stream View
struct MultiStreamView: View {
    @StateObject private var streamManager = MultiStreamManager()
    @StateObject private var streamStore = StreamStoreManager()
    @State private var showingStreamPicker = false
    @State private var selectedSlotIndex = 0
    @State private var showingLayoutPicker = false
    @State private var showingFocusView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Layout Controls
                    LayoutControlsBar(
                        currentLayout: streamManager.currentLayout,
                        onLayoutChange: { layout in
                            streamManager.updateLayout(layout)
                        },
                        onFocusToggle: {
                            showingFocusView.toggle()
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Multi-Stream Grid
                    MultiStreamGrid(
                        streamManager: streamManager,
                        onSlotTap: { index in
                            selectedSlotIndex = index
                            showingStreamPicker = true
                        },
                        onSlotLongPress: { index in
                            streamManager.focusOnStream(at: index)
                            showingFocusView = true
                        }
                    )
                    .padding(.horizontal, 8)
                    
                    // Quick Actions
                    QuickActionsBar(
                        streamManager: streamManager,
                        onAddStream: {
                            // Find first empty slot
                            if let emptyIndex = streamManager.activeStreams.firstIndex(where: { $0.isEmpty }) {
                                selectedSlotIndex = emptyIndex
                                showingStreamPicker = true
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Multi-Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear All") {
                            clearAllStreams()
                        }
                        
                        Button("Pause All") {
                            streamManager.pauseAll()
                        }
                        
                        Button("Resume All") {
                            streamManager.resumeAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingStreamPicker) {
            StreamPickerView(
                streamStore: streamStore,
                selectedSlotIndex: selectedSlotIndex,
                onStreamSelected: { stream in
                    streamManager.addStream(stream, to: selectedSlotIndex)
                    showingStreamPicker = false
                }
            )
        }
        .fullScreenCover(isPresented: $showingFocusView) {
            if let focusedStream = streamManager.focusedStream {
                FocusStreamView(
                    streamSlot: focusedStream,
                    streamManager: streamManager,
                    onDismiss: {
                        streamManager.clearFocus()
                        showingFocusView = false
                    }
                )
            }
        }
        .onAppear {
            streamStore.loadStreams()
        }
    }
    
    private func clearAllStreams() {
        for i in 0..<streamManager.activeStreams.count {
            streamManager.removeStream(from: i)
        }
    }
}

// MARK: - Layout Controls Bar
struct LayoutControlsBar: View {
    let currentLayout: MultiStreamLayout
    let onLayoutChange: (MultiStreamLayout) -> Void
    let onFocusToggle: () -> Void
    
    var body: some View {
        HStack {
            // Layout Picker
            Menu {
                ForEach(MultiStreamLayout.allCases) { layout in
                    Button(action: {
                        onLayoutChange(layout)
                    }) {
                        HStack {
                            Image(systemName: layout.icon)
                            Text(layout.displayName)
                            if layout == currentLayout {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: currentLayout.icon)
                    Text(currentLayout.displayName)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .foregroundColor(.white)
            }
            
            Spacer()
            
            // Focus Button
            Button(action: onFocusToggle) {
                Image(systemName: "viewfinder")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Multi Stream Grid
struct MultiStreamGrid: View {
    @ObservedObject var streamManager: MultiStreamManager
    let onSlotTap: (Int) -> Void
    let onSlotLongPress: (Int) -> Void
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: streamManager.currentLayout.columns)
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 4) {
            ForEach(Array(streamManager.activeStreams.enumerated()), id: \.offset) { index, slot in
                StreamSlotView(
                    slot: slot,
                    streamManager: streamManager,
                    isCompact: streamManager.currentLayout != .single,
                    onTap: {
                        onSlotTap(index)
                    },
                    onLongPress: {
                        onSlotLongPress(index)
                    },
                    onRemove: {
                        streamManager.removeStream(from: index)
                    }
                )
                .aspectRatio(16/9, contentMode: .fill)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: streamManager.currentLayout)
    }
}

// MARK: - Stream Slot View
struct StreamSlotView: View {
    let slot: StreamSlot
    @ObservedObject var streamManager: MultiStreamManager
    let isCompact: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onRemove: () -> Void
    
    @State private var showControls = false
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            if let stream = slot.stream {
                // Video Player
                if slot.useWebPlayer {
                    WorkingStreamWebView(
                        channelName: stream.userLogin,
                        isCompact: isCompact
                    )
                } else if let player = streamManager.getPlayer(for: stream.id) {
                    VideoPlayerView(player: player)
                } else {
                    LoadingPlayerView(isCompact: isCompact)
                }
                
                // Overlay Controls
                VStack {
                    // Top Controls
                    HStack {
                        if !isCompact || showControls {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stream.userName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                
                                if !isCompact {
                                    Text(stream.title)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                        .shadow(radius: 2)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if showControls {
                            Button(action: onRemove) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(8)
                    
                    Spacer()
                    
                    // Bottom Info
                    if !isCompact || showControls {
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 4, height: 4)
                                
                                Text(stream.formattedViewerCount)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                
                // Loading Overlay
                if slot.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                
                // Error Overlay
                if slot.hasError {
                    ZStack {
                        Color.black.opacity(0.5)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.white)
                                .font(.title)
                            
                            if !isCompact {
                                Text("Stream Error")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    }
                }
            } else {
                // Empty Slot
                EmptySlotView(isCompact: isCompact, onTap: onTap)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            if slot.stream != nil && isCompact {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls.toggle()
                }
                
                // Auto-hide controls after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls = false
                    }
                }
            } else {
                onTap()
            }
        }
        .onLongPressGesture {
            if slot.stream != nil {
                onLongPress()
            }
        }
    }
}

// MARK: - Empty Slot View
struct EmptySlotView: View {
    let isCompact: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: isCompact ? 4 : 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: isCompact ? 20 : 40))
                    .foregroundColor(.white.opacity(0.6))
                
                if !isCompact {
                    Text("Add Stream")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
        )
    }
}

// MARK: - Quick Actions Bar
struct QuickActionsBar: View {
    @ObservedObject var streamManager: MultiStreamManager
    let onAddStream: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Add Stream Button
            Button(action: onAddStream) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Stream")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.purple)
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Stream Count
            Text("\(streamManager.activeStreams.filter { !$0.isEmpty }.count)/\(streamManager.currentLayout.maxStreams)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            // Playback Controls
            HStack(spacing: 12) {
                Button(action: { streamManager.pauseAll() }) {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.white)
                }
                
                Button(action: { streamManager.resumeAll() }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Focus Stream View
struct FocusStreamView: View {
    let streamSlot: StreamSlot
    @ObservedObject var streamManager: MultiStreamManager
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                if let stream = streamSlot.stream {
                    WorkingStreamPlayer(
                        stream: stream,
                        streamManager: streamManager,
                        isCompact: false
                    )
                }
            }
            
            // Dismiss Button
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
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.y > 100 {
                        onDismiss()
                    }
                }
        )
    }
}

#Preview {
    MultiStreamView()
}