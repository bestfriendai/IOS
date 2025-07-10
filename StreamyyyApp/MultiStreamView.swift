//
//  MultiStreamView.swift
//  StreamyyyApp
//
//  Comprehensive multi-stream layout view with advanced features
//  Supports 1x1, 2x2, 3x3, 4x4 grid layouts with drag & drop functionality
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Layout Configuration
enum GridGridLayoutType: String, CaseIterable, Identifiable {
    case single = "1x1"
    case quad = "2x2"
    case nine = "3x3"
    case sixteen = "4x4"
    
    var id: String { rawValue }
    
    var gridColumns: Int {
        switch self {
        case .single: return 1
        case .quad: return 2
        case .nine: return 3
        case .sixteen: return 4
        }
    }
    
    var maxStreams: Int {
        gridColumns * gridColumns
    }
    
    var displayName: String {
        switch self {
        case .single: return "Single"
        case .quad: return "Quad"
        case .nine: return "Nine Grid"
        case .sixteen: return "Sixteen Grid"
        }
    }
}

// MARK: - Stream Slot Model
struct StreamSlot: Identifiable, Codable {
    let id = UUID()
    var stream: Stream?
    var position: Int
    var isMuted: Bool = false
    var isFullscreen: Bool = false
    
    init(position: Int, stream: Stream? = nil) {
        self.position = position
        self.stream = stream
    }
}

// MARK: - Layout Preference Model
struct LayoutPreference: Codable {
    let layoutType: GridLayoutType
    let slots: [StreamSlot]
    let name: String
    let createdAt: Date
    
    init(layoutType: GridLayoutType, slots: [StreamSlot], name: String) {
        self.layoutType = layoutType
        self.slots = slots
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Layout Persistence Manager
class LayoutPersistenceService: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let layoutsKey = "SavedLayouts"
    
    @Published var savedLayouts: [LayoutPreference] = []
    
    init() {
        loadLayouts()
    }
    
    func saveLayout(_ layout: LayoutPreference) {
        savedLayouts.append(layout)
        persistLayouts()
    }
    
    func deleteLayout(at index: Int) {
        guard index < savedLayouts.count else { return }
        savedLayouts.remove(at: index)
        persistLayouts()
    }
    
    func loadLayout(_ layout: LayoutPreference) -> [StreamSlot] {
        return layout.slots
    }
    
    private func persistLayouts() {
        if let encoded = try? JSONEncoder().encode(savedLayouts) {
            userDefaults.set(encoded, forKey: layoutsKey)
        }
    }
    
    private func loadLayouts() {
        guard let data = userDefaults.data(forKey: layoutsKey),
              let layouts = try? JSONDecoder().decode([LayoutPreference].self, from: data) else {
            return
        }
        savedLayouts = layouts
    }
}

// MARK: - Main Multi Stream View
struct GridMultiStreamView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Stream.updatedAt, order: .reverse) private var allStreams: [Stream]
    
    @StateObject private var layoutPersistence = LayoutPersistenceService()
    @State private var currentLayout: GridLayoutType = .quad
    @State private var streamSlots: [StreamSlot] = []
    @State private var selectedSlotIndex: Int?
    @State private var draggedStream: Stream?
    @State private var fullscreenStream: Stream?
    
    // UI State
    @State private var showingStreamPicker = false
    @State private var showingLayoutPicker = false
    @State private var showingSavedLayouts = false
    @State private var showingSaveDialog = false
    @State private var newLayoutName = ""
    @State private var showingFullScreen = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                
                if showingFullScreen, let stream = fullscreenStream {
                    fullScreenView(stream: stream)
                } else {
                    normalView(geometry: geometry)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            initializeSlots()
        }
        .sheet(isPresented: $showingStreamPicker) {
            streamPickerView
        }
        .sheet(isPresented: $showingLayoutPicker) {
            layoutPickerView
        }
        .sheet(isPresented: $showingSavedLayouts) {
            savedLayoutsView
        }
        .alert("Save Layout", isPresented: $showingSaveDialog) {
            TextField("Layout Name", text: $newLayoutName)
            Button("Save") {
                saveCurrentLayout()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Animated background elements
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.1),
                                Color.cyan.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(
                        x: CGFloat.random(in: -200...200),
                        y: CGFloat.random(in: -200...200)
                    )
                    .blur(radius: 80)
                    .animation(
                        .easeInOut(duration: Double.random(in: 8...12))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 2.0),
                        value: currentLayout
                    )
            }
        }
    }
    
    // MARK: - Normal View Layout
    private func normalView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topControlBar
            streamGridView(geometry: geometry)
            bottomControlBar
        }
    }
    
    // MARK: - Top Control Bar
    private var topControlBar: some View {
        HStack {
            // Layout selector
            Button(action: { showingLayoutPicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "grid")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text(currentLayout.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.cyan.opacity(0.5), .purple.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // Active streams indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(.green)
                            .blur(radius: 2)
                            .scaleEffect(1.5)
                    )
                
                Text("\(activeStreamCount)/\(currentLayout.maxStreams)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(.green.opacity(0.3), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            // Save/Load menu
            Menu {
                Button(action: { showingSaveDialog = true }) {
                    Label("Save Layout", systemImage: "square.and.arrow.down")
                }
                
                Button(action: { showingSavedLayouts = true }) {
                    Label("Load Layout", systemImage: "folder")
                }
                
                Divider()
                
                Button(action: clearAllStreams) {
                    Label("Clear All", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
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
                                colors: [.clear, .black.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
    }
    
    // MARK: - Stream Grid View
    private func streamGridView(geometry: GeometryProxy) -> some View {
        let itemSize = calculateItemSize(geometry: geometry)
        
        return ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: currentLayout.gridColumns),
                spacing: 4
            ) {
                ForEach(streamSlots) { slot in
                    streamSlotView(slot: slot, size: itemSize)
                        .frame(width: itemSize.width, height: itemSize.height)
                        .onDrop(of: [.text], delegate: StreamDropDelegate(
                            slot: slot,
                            streamSlots: $streamSlots,
                            draggedStream: $draggedStream
                        ))
                }
            }
            .padding(.horizontal, 12)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: streamSlots)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Stream Slot View
    private func streamSlotView(slot: StreamSlot, size: CGSize) -> some View {
        ZStack {
            if let stream = slot.stream {
                activeStreamSlotView(stream: stream, slot: slot, size: size)
            } else {
                emptyStreamSlotView(slot: slot, size: size)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Active Stream Slot
    private func activeStreamSlotView(stream: Stream, slot: StreamSlot, size: CGSize) -> some View {
        ZStack {
            // Twitch WebView embed
            TwitchEmbedWebView(
                url: stream.url,
                isMuted: slot.isMuted,
                isLoading: .constant(false),
                hasError: .constant(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        stream.isLive ?
                        LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
            )
            
            // Stream overlay info
            VStack {
                // Top overlay
                HStack {
                    if stream.isLive {
                        liveIndicator
                    }
                    
                    Spacer()
                    
                    qualityIndicator
                }
                .padding(8)
                
                Spacer()
                
                // Bottom overlay
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Slot \(slot.position + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(stream.formattedViewerCount)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    streamControlButtons(stream: stream, slot: slot)
                }
                .padding(8)
            }
        }
        .onTapGesture {
            handleStreamTap(stream: stream)
        }
        .onDrag {
            draggedStream = stream
            return NSItemProvider(object: stream.id.uuidString as NSString)
        }
        .contextMenu {
            streamContextMenu(stream: stream, slot: slot)
        }
    }
    
    // MARK: - Empty Stream Slot
    private func emptyStreamSlotView(slot: StreamSlot, size: CGSize) -> some View {
        Button(action: {
            selectedSlotIndex = slot.position
            showingStreamPicker = true
        }) {
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
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.cyan.opacity(0.7))
                    
                    VStack(spacing: 4) {
                        Text("Add Stream")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Slot \(slot.position + 1)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Stream Control Components
    private var liveIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            
            Text("LIVE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
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
    
    private var qualityIndicator: some View {
        Text("HD")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(.cyan.opacity(0.5), lineWidth: 1)
                    )
            )
    }
    
    private func streamControlButtons(stream: Stream, slot: StreamSlot) -> some View {
        HStack(spacing: 8) {
            // Mute button
            Button(action: {
                toggleMute(for: slot)
            }) {
                Image(systemName: slot.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(slot.isMuted ? .red.opacity(0.5) : .cyan.opacity(0.5), lineWidth: 1)
                            )
                    )
            }
            
            // Fullscreen button
            Button(action: {
                enterFullscreen(stream: stream)
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
    }
    
    // MARK: - Context Menu
    private func streamContextMenu(stream: Stream, slot: StreamSlot) -> some View {
        Group {
            Button(action: {
                enterFullscreen(stream: stream)
            }) {
                Label("Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            
            Button(action: {
                toggleMute(for: slot)
            }) {
                Label(slot.isMuted ? "Unmute" : "Mute", systemImage: slot.isMuted ? "speaker.wave.2" : "speaker.slash")
            }
            
            Divider()
            
            Button(action: {
                removeStream(from: slot)
            }) {
                Label("Remove", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Bottom Control Bar
    private var bottomControlBar: some View {
        HStack {
            // Add Stream button
            Button(action: { showingStreamPicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Add Stream")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // Layout controls
            HStack(spacing: 16) {
                ForEach(GridLayoutType.allCases, id: \.self) { layout in
                    Button(action: {
                        changeLayout(to: layout)
                    }) {
                        Text(layout.rawValue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(currentLayout == layout ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(currentLayout == layout ? .white : .clear)
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
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
                                colors: [.black.opacity(0.1), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                )
        )
    }
    
    // MARK: - Fullscreen View
    private func fullScreenView(stream: Stream) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TwitchEmbedWebView(
                url: stream.url,
                isMuted: false,
                isLoading: .constant(false),
                hasError: .constant(false)
            )
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: exitFullscreen) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Spacer()
                    
                    // Stream info
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(stream.displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let streamerName = stream.streamerName {
                            Text(streamerName)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
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
        .transition(.opacity)
    }
    
    // MARK: - Sheet Views
    private var streamPickerView: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List(availableStreams) { stream in
                    Button(action: {
                        addStreamToSlot(stream)
                        showingStreamPicker = false
                    }) {
                        StreamRowView(stream: stream)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingStreamPicker = false
                        selectedSlotIndex = nil
                    }
                }
            }
        }
    }
    
    private var layoutPickerView: some View {
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
                        ForEach(GridLayoutType.allCases, id: \.self) { layout in
                            LayoutPreviewCard(
                                layout: layout,
                                isSelected: currentLayout == layout,
                                action: {
                                    changeLayout(to: layout)
                                    showingLayoutPicker = false
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingLayoutPicker = false
                    }
                }
            }
        }
    }
    
    private var savedLayoutsView: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if layoutPersistence.savedLayouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Saved Layouts")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Text("Save your current layout to access it here")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(Array(layoutPersistence.savedLayouts.enumerated()), id: \.element.name) { index, layout in
                            SavedLayoutRow(
                                layout: layout,
                                onLoad: {
                                    loadLayout(layout)
                                    showingSavedLayouts = false
                                },
                                onDelete: {
                                    layoutPersistence.deleteLayout(at: index)
                                }
                            )
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Saved Layouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSavedLayouts = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private var availableStreams: [Stream] {
        allStreams.filter { stream in
            !streamSlots.contains { $0.stream?.id == stream.id }
        }
    }
    
    private var activeStreamCount: Int {
        streamSlots.filter { $0.stream != nil }.count
    }
    
    private func initializeSlots() {
        if streamSlots.isEmpty {
            streamSlots = (0..<currentLayout.maxStreams).map { StreamSlot(position: $0) }
            
            // Add some default streams if available
            let defaultStreams = Array(allStreams.prefix(min(2, allStreams.count)))
            for (index, stream) in defaultStreams.enumerated() {
                if index < streamSlots.count {
                    streamSlots[index].stream = stream
                }
            }
        }
    }
    
    private func changeLayout(to newLayout: GridLayoutType) {
        let oldSlots = streamSlots
        currentLayout = newLayout
        
        // Preserve existing streams in new layout
        streamSlots = (0..<newLayout.maxStreams).map { position in
            if position < oldSlots.count {
                var slot = oldSlots[position]
                slot.position = position
                return slot
            } else {
                return StreamSlot(position: position)
            }
        }
    }
    
    private func addStreamToSlot(_ stream: Stream) {
        if let index = selectedSlotIndex {
            streamSlots[index].stream = stream
            selectedSlotIndex = nil
        } else {
            // Find first empty slot
            if let emptyIndex = streamSlots.firstIndex(where: { $0.stream == nil }) {
                streamSlots[emptyIndex].stream = stream
            }
        }
    }
    
    private func removeStream(from slot: StreamSlot) {
        if let index = streamSlots.firstIndex(where: { $0.id == slot.id }) {
            streamSlots[index].stream = nil
        }
    }
    
    private func toggleMute(for slot: StreamSlot) {
        if let index = streamSlots.firstIndex(where: { $0.id == slot.id }) {
            streamSlots[index].isMuted.toggle()
        }
    }
    
    private func handleStreamTap(stream: Stream) {
        // Double tap for fullscreen could be implemented here
    }
    
    private func enterFullscreen(stream: Stream) {
        fullscreenStream = stream
        showingFullScreen = true
    }
    
    private func exitFullscreen() {
        showingFullScreen = false
        fullscreenStream = nil
    }
    
    private func clearAllStreams() {
        for index in streamSlots.indices {
            streamSlots[index].stream = nil
        }
    }
    
    private func saveCurrentLayout() {
        guard !newLayoutName.isEmpty else { return }
        
        let layout = LayoutPreference(
            layoutType: currentLayout,
            slots: streamSlots,
            name: newLayoutName
        )
        
        layoutPersistence.saveLayout(layout)
        newLayoutName = ""
    }
    
    private func loadLayout(_ layout: LayoutPreference) {
        currentLayout = layout.layoutType
        streamSlots = layout.slots
    }
    
    private func calculateItemSize(geometry: GeometryProxy) -> CGSize {
        let padding: CGFloat = 24
        let spacing: CGFloat = 4
        let columns = currentLayout.gridColumns
        
        let availableWidth = geometry.size.width - padding
        let itemWidth = (availableWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        
        let availableHeight = geometry.size.height - 140 // Account for top/bottom bars
        let itemHeight = (availableHeight - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
}

// MARK: - Supporting Views

struct StreamRowView: View {
    let stream: Stream
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: stream.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
                
                if let streamerName = stream.streamerName {
                    Text(streamerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if stream.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        
                        Text("\(stream.formattedViewerCount) viewers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if stream.isLive {
                Text("LIVE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.red)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

struct LayoutPreviewCard: View {
    let layout: GridLayoutType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(height: 100)
                    
                    layoutPreview
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ?
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.white.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                
                VStack(spacing: 4) {
                    Text(layout.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(layout.maxStreams) streams")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    @ViewBuilder
    private var layoutPreview: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: layout.gridColumns),
            spacing: 2
        ) {
            ForEach(0..<layout.maxStreams, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .fill(.cyan.opacity(0.3))
            }
        }
        .padding(8)
    }
}

struct SavedLayoutRow: View {
    let layout: LayoutPreference
    let onLoad: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(layout.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(layout.layoutType.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(layout.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Load", action: onLoad)
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Drag & Drop Support
struct StreamDropDelegate: DropDelegate {
    let slot: StreamSlot
    @Binding var streamSlots: [StreamSlot]
    @Binding var draggedStream: Stream?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedStream = draggedStream else { return false }
        
        // Find the slot index
        guard let targetIndex = streamSlots.firstIndex(where: { $0.id == slot.id }) else { return false }
        
        // Find source slot and clear it
        if let sourceIndex = streamSlots.firstIndex(where: { $0.stream?.id == draggedStream.id }) {
            streamSlots[sourceIndex].stream = nil
        }
        
        // Set stream in target slot
        streamSlots[targetIndex].stream = draggedStream
        
        self.draggedStream = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Visual feedback could be added here
    }
    
    func dropExited(info: DropInfo) {
        // Reset visual feedback
    }
}

// MARK: - Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    GridMultiStreamView()
        .modelContainer(for: [Stream.self])
}