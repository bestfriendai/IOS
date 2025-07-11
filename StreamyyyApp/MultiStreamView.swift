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
            headerView
            streamGridView(geometry: geometry)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "tv")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Multi-Stream Viewer")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { 
                        // Mute all action
                    }) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.title3)
                    }
                    
                    Button(action: { 
                        // Settings action
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                    }
                }
                .foregroundColor(.white)
            }
            
            HStack {
                Text("\(activeStreamCount) of \(currentLayout.maxStreams) streams")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let firstStream = streamSlots.first(where: { $0.stream != nil })?.stream {
                    Text(firstStream.streamerName ?? "")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            
            layoutSelectorView
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .foregroundColor(.white)
    }
    
    // MARK: - Stream Grid View
    private func streamGridView(geometry: GeometryProxy) -> some View {
        let itemSize = calculateItemSize(geometry: geometry)
        
        return ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(itemSize.width), spacing: 12), count: currentLayout.gridColumns),
                spacing: 12
            ) {
                ForEach(streamSlots) { slot in
                    streamSlotView(slot: slot, size: itemSize)
                        .frame(width: itemSize.width, height: itemSize.height)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
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
            // Enhanced Multi-Stream Twitch Player
            if let channelName = stream.getChannelName() {
                MultiStreamTwitchPlayer(
                    channelName: channelName,
                    isMuted: .constant(slot.isMuted),
                    isVisible: true,
                    quality: .medium
                )
                .onMultiStreamEvents(
                    onReady: {
                        print("Multi-stream \(channelName) ready")
                    },
                    onStateChange: { state in
                        print("Multi-stream \(channelName) state: \(state.displayName)")
                    },
                    onError: { error in
                        print("Multi-stream \(channelName) error: \(error)")
                    },
                    onViewerUpdate: { count in
                        print("Multi-stream \(channelName) viewers: \(count)")
                    }
                )
            } else {
                Text("Invalid Twitch URL")
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )
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
                    .fill(Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    )
                
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    
                    Text("Add Stream")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Tap to browse streams")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    

    
    // MARK: - Layout Selector
    private var layoutSelectorView: some View {
        HStack {
            Text("Layout:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(GridLayoutType.allCases, id: \.self) { layout in
                    Button(action: { changeLayout(to: layout) }) {
                        HStack(spacing: 6) {
                            layoutIcon(for: layout)
                            Text(layout.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(currentLayout == layout ? Color.blue : Color.white.opacity(0.1))
                        )
                        .foregroundColor(currentLayout == layout ? .white : .gray)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(currentLayout == layout ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            
            Spacer()
            
            Button(action: clearAllStreams) {
                Text("Clear All")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    @ViewBuilder
    private func layoutIcon(for layout: GridLayoutType) -> some View {
        switch layout {
        case .single:
            Image(systemName: "square")
                .font(.system(size: 12, weight: .medium))
        case .quad:
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 12, weight: .medium))
        case .nine:
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 12, weight: .medium))
        case .sixteen:
            Image(systemName: "square.grid.4x4")
                .font(.system(size: 12, weight: .medium))
        }
    }
    
    // MARK: - Fullscreen View
    private func fullScreenView(stream: Stream) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            MultiStreamTwitchPlayer(
                channelName: stream.getChannelName() ?? "shroud",
                isMuted: .constant(false),
                isVisible: true,
                quality: .source
            )
            .onMultiStreamEvents(
                onReady: {
                    print("Fullscreen multi-stream ready")
                },
                onStateChange: { state in
                    print("Fullscreen multi-stream state: \(state.displayName)")
                },
                onError: { error in
                    print("Fullscreen multi-stream error: \(error)")
                }
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
        let spacing: CGFloat = 12
        let columns = currentLayout.gridColumns
        
        // Calculate available space
        let availableWidth = geometry.size.width - padding
        let availableHeight = geometry.size.height - 200 // Account for header and layout selector
        
        // Calculate maximum possible width and height
        let maxItemWidth = (availableWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        let maxItemHeight = (availableHeight - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        
        // Use 16:9 aspect ratio for streams
        let aspectRatio: CGFloat = 16.0 / 9.0
        
        // Calculate size based on width constraint
        let widthBasedHeight = maxItemWidth / aspectRatio
        
        // Calculate size based on height constraint  
        let heightBasedWidth = maxItemHeight * aspectRatio
        
        // Use the smaller dimension to ensure it fits
        let finalWidth: CGFloat
        let finalHeight: CGFloat
        
        if widthBasedHeight <= maxItemHeight {
            // Width is the limiting factor
            finalWidth = maxItemWidth
            finalHeight = widthBasedHeight
        } else {
            // Height is the limiting factor
            finalWidth = heightBasedWidth
            finalHeight = maxItemHeight
        }
        
        return CGSize(width: finalWidth, height: finalHeight)
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