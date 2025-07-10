//
//  StreamGridView.swift
//  StreamyyyApp
//
//  Main stream grid view with multiple layout options
//

import SwiftUI
import SwiftData
import Combine

struct StreamGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Stream.updatedAt, order: .reverse) private var streams: [Stream]
    @Query(sort: \Layout.lastUsedAt, order: .reverse) private var layouts: [Layout]
    
    @State private var selectedLayout: Layout?
    @State private var isLoading = false
    @State private var showingLayoutSelector = false
    @State private var showingAddStream = false
    @State private var refreshing = false
    @State private var searchText = ""
    @State private var selectedStreams: Set<String> = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var dragOffset: CGSize = .zero
    @State private var currentPage = 0
    @State private var selectedStreamForPlayer: Stream? = nil
    @State private var showingStreamPlayer = false
    
    @StateObject private var layoutManager = LayoutManager()
    @StateObject private var streamManager = StreamManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var multiStreamLayoutManager: MultiStreamLayoutManager
    @StateObject private var gestureHandler: GestureHandler
    
    init() {
        let audioManager = AudioManager()
        let multiStreamLayoutManager = MultiStreamLayoutManager(audioManager: audioManager)
        let gestureHandler = GestureHandler(layoutManager: multiStreamLayoutManager, audioManager: audioManager)
        
        self._audioManager = StateObject(wrappedValue: audioManager)
        self._multiStreamLayoutManager = StateObject(wrappedValue: multiStreamLayoutManager)
        self._gestureHandler = StateObject(wrappedValue: gestureHandler)
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color.purple.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Layout Selector
                    if showingLayoutSelector {
                        LayoutSelectorView(
                            selectedLayout: $selectedLayout,
                            onLayoutSelected: { layout in
                                withAnimation(.spring()) {
                                    selectedLayout = layout
                                    multiStreamLayoutManager.setLayout(layout)
                                    showingLayoutSelector = false
                                }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Multi-Stream Content
                    multiStreamContentView
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                await refreshStreams()
            }
        }
        .onAppear {
            setupInitialLayout()
        }
        .sheet(isPresented: $showingAddStream) {
            AddStreamView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingStreamPlayer) {
            if let selectedStream = selectedStreamForPlayer {
                StreamPlayerModalView(stream: selectedStream, isPresented: $showingStreamPlayer)
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Streams")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("\(filteredStreams.count) active")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Layout Button
                    Button(action: {
                        withAnimation(.spring()) {
                            showingLayoutSelector.toggle()
                        }
                    }) {
                        Image(systemName: selectedLayout?.typeIcon ?? "square.grid.2x2")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Add Stream Button
                    Button(action: {
                        showingAddStream = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search streams...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Multi-Stream Content View
    private var multiStreamContentView: some View {
        Group {
            if isLoading {
                loadingView
            } else if filteredStreams.isEmpty {
                emptyStateView
            } else {
                multiStreamGridView
            }
        }
    }
    
    // MARK: - Multi-Stream Grid View
    private var multiStreamGridView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background tap gesture
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        gestureHandler.handleContainerTap(at: .zero)
                    }
                    .onTapGesture(count: 2) {
                        gestureHandler.handleContainerDoubleTap(at: .zero)
                    }
                
                // Multi-stream layout
                ForEach(multiStreamLayoutManager.sortedStreams) { stream in
                    if let position = multiStreamLayoutManager.streamPositions[stream.id] {
                        MultiStreamItemView(
                            stream: stream,
                            position: position,
                            isActive: audioManager.isStreamAudioEnabled(stream),
                            isFocused: multiStreamLayoutManager.isStreamFocused(stream),
                            isDragging: gestureHandler.isDragging && gestureHandler.draggedStream?.id == stream.id,
                            gestureHandler: gestureHandler
                        )
                        .position(
                            x: position.x + position.width / 2,
                            y: position.y + position.height / 2
                        )
                        .frame(width: position.width, height: position.height)
                        .zIndex(Double(position.zIndex))
                    }
                }
                
                // Fullscreen overlay
                if multiStreamLayoutManager.isFullscreen,
                   let focusedStream = multiStreamLayoutManager.focusedStream {
                    FullscreenStreamOverlay(
                        stream: focusedStream,
                        showingControls: $multiStreamLayoutManager.showingControls,
                        onExit: {
                            multiStreamLayoutManager.exitFullscreen()
                        }
                    )
                    .ignoresSafeArea()
                    .zIndex(1000)
                }
            }
            .onAppear {
                multiStreamLayoutManager.updateContainerSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                multiStreamLayoutManager.updateContainerSize(newSize)
            }
        }
    }
    
    // MARK: - Grid View
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(filteredStreams) { stream in
                    StreamGridItemView(
                        stream: stream,
                        layout: selectedLayout,
                        isSelected: selectedStreams.contains(stream.id),
                        onTap: { handleStreamTap(stream) }
                    )
                    .onLongPressGesture {
                        handleStreamLongPress(stream)
                    }
                    .contextMenu {
                        streamContextMenu(stream)
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                .scaleEffect(1.5)
            
            Text("Loading streams...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "tv")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("No Streams Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your first stream to get started watching")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showingAddStream = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Stream")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Computed Properties
    private var filteredStreams: [Stream] {
        if searchText.isEmpty {
            return streams.filter { !$0.isArchived }
        } else {
            return streams.filter { stream in
                !stream.isArchived && (
                    stream.title.localizedCaseInsensitiveContains(searchText) ||
                    stream.streamerName?.localizedCaseInsensitiveContains(searchText) == true ||
                    stream.platform.displayName.localizedCaseInsensitiveContains(searchText)
                )
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        guard let layout = selectedLayout else {
            return [GridItem(.adaptive(minimum: 150), spacing: 12)]
        }
        
        switch layout.type {
        case .grid2x2:
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        case .grid3x3:
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        case .grid4x4:
            return Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
        case .stack:
            return [GridItem(.flexible())]
        default:
            return [GridItem(.adaptive(minimum: 150), spacing: 12)]
        }
    }
    
    private var spacing: CGFloat {
        guard let layout = selectedLayout else { return 12 }
        return layout.configuration.spacing
    }
    
    // MARK: - Actions
    private func handleStreamTap(_ stream: Stream) {
        if selectedStreams.isEmpty {
            // Show stream player
            selectedStreamForPlayer = stream
            showingStreamPlayer = true
        } else {
            // Toggle selection
            if selectedStreams.contains(stream.id) {
                selectedStreams.remove(stream.id)
            } else {
                selectedStreams.insert(stream.id)
            }
        }
    }
    
    private func handleStreamLongPress(_ stream: Stream) {
        if selectedStreams.contains(stream.id) {
            selectedStreams.remove(stream.id)
        } else {
            selectedStreams.insert(stream.id)
        }
    }
    
    private func streamContextMenu(_ stream: Stream) -> some View {
        Group {
            Button(action: {
                // Toggle favorite
            }) {
                Label(
                    stream.isFavorited ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: stream.isFavorited ? "heart.fill" : "heart"
                )
            }
            
            Button(action: {
                // Edit stream
            }) {
                Label("Edit Stream", systemImage: "pencil")
            }
            
            Divider()
            
            Button(action: {
                archiveStream(stream)
            }) {
                Label("Archive Stream", systemImage: "archivebox")
            }
            
            Button(action: {
                deleteStream(stream)
            }) {
                Label("Delete Stream", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
    
    private func setupInitialLayout() {
        if selectedLayout == nil {
            selectedLayout = layouts.first { $0.isDefault } ?? layouts.first
        }
        
        // Initialize multi-stream layout
        multiStreamLayoutManager.setModelContext(modelContext)
        
        if let layout = selectedLayout {
            multiStreamLayoutManager.setLayout(layout)
        }
        
        // Add existing streams to multi-stream layout
        for stream in filteredStreams.prefix(4) { // Start with first 4 streams
            multiStreamLayoutManager.addStream(stream)
        }
    }
    
    private func refreshStreams() async {
        refreshing = true
        
        do {
            try await streamManager.refreshStreams()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        refreshing = false
    }
    
    private func archiveStream(_ stream: Stream) {
        stream.archive(reason: "User archived")
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to archive stream"
            showingError = true
        }
    }
    
    private func deleteStream(_ stream: Stream) {
        modelContext.delete(stream)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete stream"
            showingError = true
        }
    }
}

// MARK: - Stream Grid Item View
struct StreamGridItemView: View {
    let stream: Stream
    let layout: Layout?
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = false
    @State private var showingControls = false
    @State private var lastTapTime = Date()
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(.systemGray6))
                .aspectRatio(aspectRatio, contentMode: .fit)
            
            // Thumbnail or Player
            if let thumbnailImage = thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .cornerRadius(cornerRadius)
            } else {
                // Platform icon placeholder
                VStack {
                    Image(systemName: stream.platform.icon)
                        .font(.system(size: 30))
                        .foregroundColor(stream.platform.color)
                    
                    Text(stream.platform.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Overlay
            overlayView
            
            // Selection indicator
            if isSelected {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.purple, lineWidth: 3)
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onTapGesture(count: 2) {
            handleDoubleTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingControls = hovering
            }
        }
        .accessibilityLabel(stream.displayTitle)
        .accessibilityHint("Stream from \(stream.platform.displayName)")
    }
    
    // MARK: - Overlay View
    private var overlayView: some View {
        ZStack {
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .cornerRadius(cornerRadius)
            
            VStack {
                // Top indicators
                HStack {
                    // Live indicator
                    if stream.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    // Health status
                    Image(systemName: stream.healthStatus.icon)
                        .font(.caption)
                        .foregroundColor(stream.healthStatus.color)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Spacer()
                
                // Bottom info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack {
                        if let streamerName = stream.streamerName {
                            Text(streamerName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        if stream.viewerCount > 0 {
                            Text(stream.formattedViewerCount)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            
            // Controls overlay
            if showingControls {
                controlsView
            }
        }
    }
    
    // MARK: - Controls View
    private var controlsView: some View {
        VStack {
            HStack {
                Button(action: {
                    // Toggle favorite
                }) {
                    Image(systemName: stream.isFavorited ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(stream.isFavorited ? .red : .white)
                }
                
                Spacer()
                
                Button(action: {
                    // More options
                }) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Spacer()
            
            // Play button
            Button(action: onTap) {
                Image(systemName: "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(25)
            }
            
            Spacer()
            
            // Quality indicator
            HStack {
                Spacer()
                
                Text(stream.quality.displayName)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(cornerRadius)
    }
    
    // MARK: - Computed Properties
    private var cornerRadius: CGFloat {
        return layout?.configuration.cornerRadius ?? 12
    }
    
    private var aspectRatio: CGFloat {
        return layout?.configuration.aspectRatio ?? 16/9
    }
    
    // MARK: - Actions
    private func loadThumbnail() {
        guard let thumbnailURL = stream.thumbnailURL,
              let url = URL(string: thumbnailURL) else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let image = UIImage(data: data) {
                    thumbnailImage = image
                }
            }
        }.resume()
    }
    
    private func handleDoubleTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        lastTapTime = now
        
        if timeSinceLastTap < 0.5 {
            // Double tap detected - toggle favorite
            // This would typically call a method to toggle favorite
        }
    }
}

// MARK: - Multi-Stream Item View
struct MultiStreamItemView: View {
    let stream: Stream
    let position: StreamPosition
    let isActive: Bool
    let isFocused: Bool
    let isDragging: Bool
    let gestureHandler: GestureHandler
    
    @State private var showingControls = false
    @State private var controlsTimer: Timer?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var currentQuality = StreamQuality.auto
    @State private var isLive = false
    @State private var viewerCount = 0
    
    var body: some View {
        ZStack {
            // Stream content
            streamContentView
            
            // Controls overlay
            if showingControls || isDragging {
                streamControlsOverlay
            }
            
            // Focus indicator
            if isFocused {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple, lineWidth: 3)
                    .animation(.easeInOut(duration: 0.3), value: isFocused)
            }
            
            // Active audio indicator
            if isActive {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.purple.opacity(0.8))
                            .clipShape(Circle())
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: isDragging ? 10 : 2)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isDragging)
        .gesture(
            DragGesture()
                .onChanged { value in
                    gestureHandler.handleDragChange(stream, translation: value.translation)
                }
                .onEnded { _ in
                    gestureHandler.handleDragEnd(stream)
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    gestureHandler.handleZoomChange(stream, scale: value)
                }
                .onEnded { _ in
                    gestureHandler.handleZoomEnd(stream)
                }
        )
        .onTapGesture {
            gestureHandler.handleStreamTap(stream, at: .zero)
        }
        .onTapGesture(count: 2) {
            gestureHandler.handleStreamTap(stream, at: .zero)
        }
        .onLongPressGesture {
            gestureHandler.handleStreamLongPress(stream, at: .zero)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingControls = hovering
            }
        }
    }
    
    private var streamContentView: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    .scaleEffect(1.2)
            } else {
                // Use the existing stream web view component
                StreamWebView(
                    url: stream.url,
                    isMuted: !isActive,
                    isLoading: $isLoading,
                    hasError: $hasError,
                    currentQuality: $currentQuality,
                    isLive: $isLive,
                    viewerCount: $viewerCount
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var streamControlsOverlay: some View {
        ZStack {
            // Semi-transparent background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
            
            VStack {
                // Top controls
                HStack {
                    Text(stream.displayTitle)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        // Toggle favorite
                    }) {
                        Image(systemName: stream.isFavorited ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor(stream.isFavorited ? .red : .white)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                
                Spacer()
                
                // Center play/pause button
                Button(action: {
                    gestureHandler.handleStreamTap(stream, at: .zero)
                }) {
                    Image(systemName: isActive ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Bottom info
                HStack {
                    if let streamerName = stream.streamerName {
                        Text(streamerName)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    if stream.viewerCount > 0 {
                        Text(stream.formattedViewerCount)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .opacity(showingControls ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: showingControls)
    }
}

// MARK: - Fullscreen Stream Overlay
struct FullscreenStreamOverlay: View {
    let stream: Stream
    @Binding var showingControls: Bool
    let onExit: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Stream content
            StreamWebView(
                url: stream.url,
                isMuted: false,
                isLoading: .constant(false),
                hasError: .constant(false)
            )
            .ignoresSafeArea()
            
            // Controls overlay
            if showingControls {
                VStack {
                    // Top controls
                    HStack {
                        Button(action: onExit) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text(stream.displayTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            // More options
                        }) {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Bottom controls
                    HStack {
                        Button(action: {
                            // Toggle favorite
                        }) {
                            Image(systemName: stream.isFavorited ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(stream.isFavorited ? .red : .white)
                        }
                        
                        Spacer()
                        
                        // Volume control
                        HStack {
                            Image(systemName: "speaker.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Slider(value: .constant(Float(stream.volume)), in: 0...1)
                                .frame(width: 100)
                                .accentColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Quality settings
                        }) {
                            Text(stream.quality.displayName)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .transition(.opacity)
            }
        }
        .onTapGesture {
            showingControls.toggle()
        }
    }
}

// MARK: - Layout Manager
@MainActor
class LayoutManager: ObservableObject {
    @Published var selectedLayout: Layout?
    @Published var layouts: [Layout] = []
    
    init() {
        loadLayouts()
    }
    
    private func loadLayouts() {
        // This would typically load from Core Data or another persistence layer
        layouts = [
            Layout(name: "2x2 Grid", type: .grid2x2),
            Layout(name: "3x3 Grid", type: .grid3x3),
            Layout(name: "4x4 Grid", type: .grid4x4),
            Layout(name: "Stack", type: .stack)
        ]
        
        selectedLayout = layouts.first
    }
}

// MARK: - Stream Manager
@MainActor
class StreamManager: ObservableObject {
    @Published var streams: [Stream] = []
    @Published var isLoading = false
    
    func refreshStreams() async throws {
        isLoading = true
        
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // This would typically fetch from API
        
        isLoading = false
    }
}

// MARK: - Stream Player Modal View
struct StreamPlayerModalView: View {
    let stream: Stream
    @Binding var isPresented: Bool
    @State private var isPlaying = true
    @State private var isFullScreen = false
    @State private var showingControls = true
    @State private var controlsTimer: Timer?
    @State private var activeStreams: [Stream] = []
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Main video player
                        ZStack {
                            StreamWebView(
                                url: stream.url,
                                isMuted: false,
                                isLoading: .constant(false),
                                hasError: .constant(false)
                            )
                            .frame(height: isFullScreen ? geometry.size.height : 280)
                            .background(Color.black)
                            .onTapGesture {
                                toggleControls()
                            }
                            
                            // Video controls overlay
                            if showingControls {
                                videoControlsOverlay
                            }
                        }
                        
                        if !isFullScreen {
                            // Stream info section
                            streamInfoSection
                                .background(Color(.systemBackground))
                            
                            // Multi-stream bottom section
                            multiStreamBottomSection
                                .background(Color(.systemGray6))
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(isFullScreen)
            .navigationTitle(stream.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            isFullScreen.toggle()
                        }
                    }) {
                        Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                }
            }
        }
        .onAppear {
            setupMultiStream()
            startControlsTimer()
        }
        .onDisappear {
            controlsTimer?.invalidate()
        }
    }
    
    // MARK: - Video Controls Overlay
    private var videoControlsOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
            
            VStack {
                // Top controls
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text(stream.displayTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        // More options
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Center play/pause button
                Button(action: {
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Bottom controls
                HStack {
                    Button(action: {
                        // Toggle favorite
                    }) {
                        Image(systemName: stream.isFavorited ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(stream.isFavorited ? .red : .white)
                    }
                    
                    Spacer()
                    
                    HStack {
                        if stream.isLive {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    Text(stream.quality.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .opacity(showingControls ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: showingControls)
    }
    
    // MARK: - Stream Info Section
    private var streamInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stream.displayTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack {
                if let streamerName = stream.streamerName {
                    Text(streamerName)
                        .font(.subheadline)
                        .foregroundColor(stream.platform.color)
                }
                
                Spacer()
                
                if stream.isLive {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(stream.formattedViewerCount)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Text(stream.platform.displayName.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(stream.platform.color.opacity(0.8))
                    )
                
                Spacer()
            }
        }
        .padding()
    }
    
    // MARK: - Multi-Stream Bottom Section
    private var multiStreamBottomSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Multi-Stream")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    // Add more streams
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal)
            
            if !activeStreams.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeStreams) { activeStream in
                            MultiStreamThumbnailView(
                                stream: activeStream,
                                isCurrentlyViewing: activeStream.id == stream.id
                            ) {
                                // Switch to this stream
                                // This would switch the main player
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("Add more streams to watch multiple at once")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Helper Methods
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
    
    private func setupMultiStream() {
        // This would load user's saved multi-stream setup
        // For now, we'll leave it empty - user can add streams
        activeStreams = []
    }
}

// MARK: - Multi-Stream Thumbnail View
struct MultiStreamThumbnailView: View {
    let stream: Stream
    let isCurrentlyViewing: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 68)
                    
                    // Platform icon or thumbnail
                    Image(systemName: stream.platform.icon)
                        .font(.title2)
                        .foregroundColor(stream.platform.color)
                    
                    // Currently viewing indicator
                    if isCurrentlyViewing {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple, lineWidth: 3)
                            .frame(width: 120, height: 68)
                    }
                    
                    // Live indicator
                    if stream.isLive {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                
                Text(stream.streamerName ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    StreamGridView()
        .modelContainer(for: [Stream.self, Layout.self])
}