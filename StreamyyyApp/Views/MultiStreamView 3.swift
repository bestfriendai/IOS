//
//  MultiStreamView.swift
//  StreamyyyApp
//
//  Main multi-stream viewing interface - the core feature of the app
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import WebKit
import Combine

// MARK: - Multi Stream View
struct MultiStreamView: View {
    @StateObject private var streamManager = MultiStreamManager()
    @State private var showingStreamPicker = false
    @State private var selectedSlotIndex = 0
    @State private var showingLayoutPicker = false
    @State private var streamStates: [Int: StreamPlaybackState] = [:]
    @State private var streamViewerCounts: [Int: Int] = [:]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    LayoutControlsBar(
                        currentLayout: streamManager.currentLayout,
                        onLayoutChange: { layout in
                            streamManager.updateLayout(layout)
                        },
                        onFocusToggle: {
                            // Focus mode can be implemented here
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    MultiStreamGrid(
                        streamManager: streamManager,
                        onSlotTap: { index in
                            selectedSlotIndex = index
                            showingStreamPicker = true
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Multi-Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear All", role: .destructive) {
                            streamManager.clearAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingStreamPicker) {
            let mockStreams = [
                TwitchStream(id: "1", userId: "1", userLogin: "shroud", userName: "Shroud", gameId: "1", gameName: "VALORANT", type: "live", title: "Pro Gameplay", viewerCount: 12000, startedAt: "", language: "en", thumbnailUrl: "", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "2", userId: "2", userLogin: "pokimane", userName: "Pokimane", gameId: "2", gameName: "Just Chatting", type: "live", title: "Chilling", viewerCount: 8000, startedAt: "", language: "en", thumbnailUrl: "", tagIds: nil, tags: nil, isMature: false),
                TwitchStream(id: "3", userId: "3", userLogin: "xqc", userName: "xQc", gameId: "3", gameName: "GTA V", type: "live", title: "RP Server", viewerCount: 50000, startedAt: "", language: "en", thumbnailUrl: "", tagIds: nil, tags: nil, isMature: false)
            ]
            
            StreamPickerView(
                streams: mockStreams,
                onStreamSelected: { stream in
                    streamManager.addStream(stream, to: selectedSlotIndex)
                    showingStreamPicker = false
                }
            )
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
            Menu {
                ForEach(MultiStreamLayout.allCases) { layout in
                    Button(action: {
                        onLayoutChange(layout)
                    }) {
                        Label(layout.displayName, systemImage: layout.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: currentLayout.icon)
                    Text(currentLayout.displayName)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.1)).cornerRadius(8).foregroundColor(.white)
            }
            Spacer()
        }
    }
}

// MARK: - Multi-Stream Grid
struct MultiStreamGrid: View {
    @ObservedObject var streamManager: MultiStreamManager
    let onSlotTap: (Int) -> Void
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: streamManager.currentLayout.columns)
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(streamManager.activeStreams.indices, id: \.self) { index in
                StreamSlotView(
                    slot: streamManager.activeStreams[index],
                    onTap: { onSlotTap(index) },
                    onRemove: { streamManager.removeStream(from: index) }
                )
                .aspectRatio(16/9, contentMode: .fit)
                .frame(minHeight: 200)
                .id(streamManager.activeStreams[index].id)
            }
        }
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: streamManager.currentLayout)
    }
}

// MARK: - Stream Slot View
struct StreamSlotView: View {
    let slot: StreamSlot
    let onTap: () -> Void
    let onRemove: () -> Void
    @StateObject private var audioManager = MultiStreamAudioManager.shared
    @State private var isMuted: Bool = true
    
    var body: some View {
        ZStack {
            if let stream = slot.stream {
                MultiStreamTwitchPlayer(
                    channelName: stream.userLogin,
                    isMuted: $isMuted,
                    isVisible: true,
                    quality: .medium
                )
                .onMultiStreamEvents(
                    onReady: {
                        print("Multi-stream \(stream.userLogin) ready")
                    },
                    onStateChange: { state in
                        print("Multi-stream \(stream.userLogin) state: \(state.displayName)")
                    },
                    onError: { error in
                        print("Multi-stream \(stream.userLogin) error: \(error)")
                    },
                    onViewerUpdate: { count in
                        // Update viewer count if needed
                    }
                )
                    .overlay(streamOverlay(stream: stream))
            } else {
                emptySlotView
            }
        }
        .background(Color.black)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(audioManager.activeAudioStreamId == slot.stream?.id ? Color.purple : Color.clear, lineWidth: 2))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AudioStreamChanged"))) { obj in
            let activeId = obj.object as? String
            self.isMuted = activeId != slot.stream?.id
        }
    }

    private var emptySlotView: some View {
        Button(action: onTap) {
            ZStack {
                Color.gray.opacity(0.2)
                Image(systemName: "plus")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private func streamOverlay(stream: TwitchStream) -> some View {
        VStack {
            HStack {
                Text(stream.userName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5).clipShape(Circle()))
                }
            }
            .padding(4)
            
            Spacer()
            
            HStack {
                Button(action: {
                    audioManager.setActiveAudioStream(stream.id)
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(isMuted ? .white : .green)
                        .padding(4)
                        .background(Color.black.opacity(0.6).clipShape(Circle()))
                }
                Spacer()
            }
            .padding(4)
        }
    }
}

// MARK: - Stream Picker View (Mock)
struct StreamPickerView: View {
    let streams: [TwitchStream]
    let onStreamSelected: (TwitchStream) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(streams) { stream in
                Button(action: { onStreamSelected(stream) }) {
                    Text(stream.userName)
                }
            }
            .navigationTitle("Select Stream")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}


#Preview {
    MultiStreamView()
}