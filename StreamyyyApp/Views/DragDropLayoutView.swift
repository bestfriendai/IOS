//
//  DragDropLayoutView.swift
//  StreamyyyApp
//
//  Advanced drag and drop stream arrangement interface
//

import SwiftUI
import UniformTypeIdentifiers

struct DragDropLayoutView: View {
    @StateObject private var layoutManager = LayoutManager.shared
    @State private var selectedStream: Stream?
    @State private var showingStreamSelector = false
    @State private var showingLayoutOptions = false
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastPanValue: CGSize = .zero
    
    @GestureState private var panGesture: CGSize = .zero
    @GestureState private var magnificationGesture: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundView
                
                // Grid overlay
                if layoutManager.showGrid {
                    gridOverlay
                }
                
                // Drop targets
                dropTargetsView
                
                // Streams
                streamsView
                
                // Drag preview
                dragPreviewView
                
                // Controls overlay
                controlsOverlay
            }
            .clipped()
            .scaleEffect(scale * magnificationGesture)
            .offset(
                x: offset.x + panGesture.x,
                y: offset.y + panGesture.y
            )
            .gesture(
                SimultaneousGesture(
                    panGesture,
                    magnificationGesture
                )
            )
            .onAppear {
                layoutManager.screenSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                layoutManager.screenSize = newSize
            }
        }
        .sheet(isPresented: $showingStreamSelector) {
            StreamSelectorView { stream in
                addStreamToLayout(stream, at: CGPoint(x: 100, y: 100))
            }
        }
        .sheet(isPresented: $showingLayoutOptions) {
            LayoutOptionsView()
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        Rectangle()
            .fill(Color(.systemGroupedBackground))
            .onTapGesture {
                selectedStream = nil
            }
            .onDrop(of: [UTType.text], isTargeted: nil) { providers, location in
                handleDrop(providers: providers, at: location)
            }
    }
    
    // MARK: - Grid Overlay
    private var gridOverlay: some View {
        GridOverlay(
            gridSize: layoutManager.gridSize,
            color: Color(.systemGray4).opacity(0.5),
            screenSize: layoutManager.screenSize
        )
    }
    
    // MARK: - Drop Targets View
    private var dropTargetsView: some View {
        ForEach(layoutManager.dropTargets) { target in
            DropTargetView(target: target)
        }
    }
    
    // MARK: - Streams View
    private var streamsView: some View {
        Group {
            if let layout = layoutManager.currentLayout {
                ForEach(layout.streams, id: \.id) { layoutStream in
                    if let stream = getStream(for: layoutStream.streamId) {
                        DraggableStreamView(
                            stream: stream,
                            layoutStream: layoutStream,
                            isSelected: selectedStream?.id == stream.id,
                            onSelect: { selectedStream = stream },
                            onDragStart: { position in
                                layoutManager.startDragging(stream: stream, at: position)
                            },
                            onDragUpdate: { position in
                                layoutManager.updateDragPosition(position)
                            },
                            onDragEnd: { position in
                                layoutManager.endDragging(at: position)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Drag Preview View
    private var dragPreviewView: some View {
        Group {
            if let dragPreview = layoutManager.dragPreview {
                DragPreviewView(preview: dragPreview)
            }
        }
    }
    
    // MARK: - Controls Overlay
    private var controlsOverlay: some View {
        VStack {
            HStack {
                // Layout controls
                layoutControls
                
                Spacer()
                
                // View controls
                viewControls
            }
            .padding()
            
            Spacer()
            
            // Bottom toolbar
            bottomToolbar
        }
    }
    
    // MARK: - Layout Controls
    private var layoutControls: some View {
        HStack(spacing: 8) {
            Button(action: {
                showingStreamSelector = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                showingLayoutOptions = true
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                layoutManager.showGrid.toggle()
            }) {
                Image(systemName: layoutManager.showGrid ? "grid.circle.fill" : "grid.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                layoutManager.snapToGrid.toggle()
            }) {
                Image(systemName: layoutManager.snapToGrid ? "magnetometer.fill" : "magnetometer")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(Capsule())
        .shadow(radius: 2)
    }
    
    // MARK: - View Controls
    private var viewControls: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.0
                    offset = .zero
                }
            }) {
                Image(systemName: "viewfinder.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = max(0.5, scale - 0.2)
                }
            }) {
                Image(systemName: "minus.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = min(2.0, scale + 0.2)
                }
            }) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(Capsule())
        .shadow(radius: 2)
    }
    
    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack {
            // Auto arrange menu
            Menu {
                Button("Grid") {
                    autoArrange(.grid)
                }
                Button("Cascade") {
                    autoArrange(.cascade)
                }
                Button("Stack") {
                    autoArrange(.stack)
                }
                Button("Circle") {
                    autoArrange(.circle)
                }
            } label: {
                Label("Auto Arrange", systemImage: "rectangle.3.group")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            // Selected stream controls
            if let stream = selectedStream {
                selectedStreamControls(stream)
            }
            
            Spacer()
            
            // Layout info
            if let layout = layoutManager.currentLayout {
                Text("\(layout.streams.count) streams")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
    
    // MARK: - Selected Stream Controls
    private func selectedStreamControls(_ stream: Stream) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                layoutManager.sendStreamToBack(stream)
            }) {
                Image(systemName: "arrow.down.to.line")
                    .font(.caption)
            }
            
            Button(action: {
                layoutManager.bringStreamToFront(stream)
            }) {
                Image(systemName: "arrow.up.to.line")
                    .font(.caption)
            }
            
            Button(action: {
                removeStreamFromLayout(stream)
            }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    
    // MARK: - Gestures
    private var panGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .updating($panGesture) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($magnificationGesture) { value, state, _ in
                state = value
            }
            .onEnded { value in
                scale = max(0.5, min(2.0, scale * value))
            }
    }
    
    // MARK: - Helper Methods
    private func getStream(for streamId: String) -> Stream? {
        // TODO: Implement stream lookup from model context
        return nil
    }
    
    private func addStreamToLayout(_ stream: Stream, at position: CGPoint) {
        guard let layout = layoutManager.currentLayout else { return }
        
        let streamPosition = StreamPosition(
            x: position.x,
            y: position.y,
            width: 300,
            height: 200,
            zIndex: layout.streams.count
        )
        
        layout.addStream(position: streamPosition, streamId: stream.id)
        stream.updatePosition(streamPosition)
    }
    
    private func removeStreamFromLayout(_ stream: Stream) {
        guard let layout = layoutManager.currentLayout else { return }
        
        layout.removeStream(streamId: stream.id)
        selectedStream = nil
    }
    
    private func autoArrange(_ style: AutoArrangeStyle) {
        guard let layout = layoutManager.currentLayout else { return }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            layoutManager.autoArrangeStreams(in: layout, style: style)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier) { item, error in
                    if let urlString = item as? String,
                       let url = URL(string: urlString) {
                        DispatchQueue.main.async {
                            // TODO: Create stream from URL and add to layout
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Draggable Stream View
struct DraggableStreamView: View {
    let stream: Stream
    let layoutStream: LayoutStream
    let isSelected: Bool
    let onSelect: () -> Void
    let onDragStart: (CGPoint) -> Void
    let onDragUpdate: (CGPoint) -> Void
    let onDragEnd: (CGPoint) -> Void
    
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        StreamCardView(stream: stream, layoutStream: layoutStream, isSelected: isSelected)
            .offset(dragOffset)
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .shadow(radius: isDragging ? 8 : 2)
            .animation(.easeInOut(duration: 0.2), value: isDragging)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .onTapGesture {
                onSelect()
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStart(value.location)
                        }
                        dragOffset = value.translation
                        onDragUpdate(value.location)
                    }
                    .onEnded { value in
                        isDragging = false
                        dragOffset = .zero
                        onDragEnd(value.location)
                    }
            )
    }
}

// MARK: - Stream Card View
struct StreamCardView: View {
    let stream: Stream
    let layoutStream: LayoutStream
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Stream preview/thumbnail
            streamPreview
            
            // Stream info
            streamInfo
        }
        .frame(
            width: layoutStream.position.width,
            height: layoutStream.position.height
        )
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
        )
        .position(
            x: layoutStream.position.x + layoutStream.position.width / 2,
            y: layoutStream.position.y + layoutStream.position.height / 2
        )
    }
    
    private var streamPreview: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(LinearGradient(
                    colors: [stream.platformColor.opacity(0.3), stream.platformColor.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            // Platform icon
            Image(systemName: stream.platform.icon)
                .font(.title)
                .foregroundColor(stream.platformColor)
                .opacity(0.3)
            
            // Status indicators
            VStack {
                HStack {
                    // Live indicator
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
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Quality indicator
                    Text(stream.quality.displayName)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Controls
                HStack {
                    Button(action: {
                        stream.toggleMute()
                    }) {
                        Image(systemName: stream.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        stream.toggleFullscreen()
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(8)
        }
        .aspectRatio(16/9, contentMode: .fit)
    }
    
    private var streamInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stream.displayTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            HStack {
                Text(stream.streamerName ?? "Unknown")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if stream.viewerCount > 0 {
                    Text(stream.formattedViewerCount)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
    }
}

// MARK: - Drop Target View
struct DropTargetView: View {
    @ObservedObject var target: DropTarget
    
    var body: some View {
        Rectangle()
            .fill(target.isActive ? Color.blue.opacity(0.3) : Color.clear)
            .stroke(
                target.isActive ? Color.blue : Color.gray.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, dash: [5])
            )
            .frame(
                width: target.position.width,
                height: target.position.height
            )
            .position(
                x: target.position.x + target.position.width / 2,
                y: target.position.y + target.position.height / 2
            )
            .animation(.easeInOut(duration: 0.2), value: target.isActive)
    }
}

// MARK: - Drag Preview View
struct DragPreviewView: View {
    @ObservedObject var preview: DragPreview
    
    var body: some View {
        StreamCardView(
            stream: preview.stream,
            layoutStream: LayoutStream(
                layoutId: "",
                streamId: preview.stream.id,
                position: preview.position
            ),
            isSelected: false
        )
        .opacity(preview.opacity)
        .scaleEffect(preview.scale)
        .rotationEffect(.degrees(preview.rotation))
    }
}

// MARK: - Grid Overlay
struct GridOverlay: View {
    let gridSize: CGSize
    let color: Color
    let screenSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / gridSize.width)
            let rows = Int(size.height / gridSize.height)
            
            // Vertical lines
            for col in 0...cols {
                let x = CGFloat(col) * gridSize.width
                let start = CGPoint(x: x, y: 0)
                let end = CGPoint(x: x, y: size.height)
                
                context.stroke(
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    },
                    with: .color(color),
                    lineWidth: 0.5
                )
            }
            
            // Horizontal lines
            for row in 0...rows {
                let y = CGFloat(row) * gridSize.height
                let start = CGPoint(x: 0, y: y)
                let end = CGPoint(x: size.width, y: y)
                
                context.stroke(
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    },
                    with: .color(color),
                    lineWidth: 0.5
                )
            }
        }
    }
}

// MARK: - Stream Selector View
struct StreamSelectorView: View {
    let onStreamSelected: (Stream) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var availableStreams: [Stream] = []
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search streams...")
                    .padding()
                
                // Stream list
                List(filteredStreams) { stream in
                    StreamListItem(stream: stream) {
                        onStreamSelected(stream)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Add Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredStreams: [Stream] {
        if searchText.isEmpty {
            return availableStreams
        } else {
            return availableStreams.filter { stream in
                stream.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                stream.streamerName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
}

// MARK: - Stream List Item
struct StreamListItem: View {
    let stream: Stream
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Platform icon
            Image(systemName: stream.platform.icon)
                .font(.title2)
                .foregroundColor(stream.platformColor)
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stream.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                if let streamerName = stream.streamerName {
                    Text(streamerName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicators
            VStack(alignment: .trailing, spacing: 2) {
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
                
                if stream.viewerCount > 0 {
                    Text(stream.formattedViewerCount)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Layout Options View
struct LayoutOptionsView: View {
    @StateObject private var layoutManager = LayoutManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Grid Settings")) {
                    HStack {
                        Text("Grid Size")
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { layoutManager.gridSize.width },
                                set: { layoutManager.gridSize = CGSize(width: $0, height: $0) }
                            ),
                            in: 10...50,
                            step: 5
                        ) {
                            Text("\(Int(layoutManager.gridSize.width))")
                        }
                    }
                    
                    Toggle("Show Grid", isOn: $layoutManager.showGrid)
                    Toggle("Snap to Grid", isOn: $layoutManager.snapToGrid)
                }
                
                Section(header: Text("Behavior")) {
                    Toggle("Magnetic Snap", isOn: $layoutManager.magneticSnap)
                    Toggle("Show Guides", isOn: $layoutManager.showGuides)
                }
                
                Section(header: Text("Animation")) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Slider(
                            value: $layoutManager.animationDuration,
                            in: 0.1...1.0,
                            step: 0.1
                        ) {
                            Text("\(layoutManager.animationDuration, specifier: "%.1f")s")
                        }
                    }
                }
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
}

// MARK: - Preview
struct DragDropLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        DragDropLayoutView()
    }
}