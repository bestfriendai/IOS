//
//  LayoutSharingView.swift
//  StreamyyyApp
//
//  Layout sharing and management interface
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Layout Sharing View

struct LayoutSharingView: View {
    @StateObject private var sharingService = LayoutSharingService()
    @State private var selectedTab: SharingTab = .saved
    @State private var searchText = ""
    @State private var showingImportSheet = false
    @State private var showingNewLayoutSheet = false
    @State private var selectedLayout: SavedLayout?
    
    enum SharingTab: String, CaseIterable {
        case saved = "Saved"
        case recent = "Recent"
        case shared = "Shared"
        
        var systemImage: String {
            switch self {
            case .saved: return "bookmark.fill"
            case .recent: return "clock.fill"
            case .shared: return "square.and.arrow.up.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and actions
                headerSection
                
                // Tab selector
                tabSelector
                
                // Content
                contentSection
            }
            .navigationTitle("My Layouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingImportSheet = true }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    
                    Button(action: { showingNewLayoutSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportLayoutSheet(sharingService: sharingService)
            }
            .sheet(isPresented: $showingNewLayoutSheet) {
                NewLayoutSheet(sharingService: sharingService)
            }
            .sheet(item: $selectedLayout) { layout in
                LayoutDetailSheet(layout: layout, sharingService: sharingService)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search layouts...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // Statistics
            statisticsSection
        }
        .padding(.horizontal)
    }
    
    private var statisticsSection: some View {
        let stats = sharingService.getLayoutStatistics()
        
        return HStack(spacing: 20) {
            StatisticView(
                title: "Total",
                value: "\(stats.totalLayouts)",
                systemImage: "bookmark",
                color: .blue
            )
            
            StatisticView(
                title: "Shared",
                value: "\(stats.publicLayouts)",
                systemImage: "square.and.arrow.up",
                color: .green
            )
            
            StatisticView(
                title: "Downloads",
                value: "\(stats.totalShares)",
                systemImage: "arrow.down.circle",
                color: .orange
            )
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SharingTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.title3)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(.regularMaterial)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch selectedTab {
                case .saved:
                    savedLayoutsContent
                case .recent:
                    recentLayoutsContent
                case .shared:
                    sharedLayoutsContent
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Tab bar spacing
        }
        .refreshable {
            // Refresh layouts
        }
    }
    
    private var savedLayoutsContent: some View {
        let filteredLayouts = filteredSavedLayouts
        
        return Group {
            if filteredLayouts.isEmpty {
                emptyStateView(
                    title: searchText.isEmpty ? "No Saved Layouts" : "No Results",
                    subtitle: searchText.isEmpty ? "Create your first layout to get started" : "Try adjusting your search terms",
                    systemImage: "bookmark"
                )
            } else {
                ForEach(filteredLayouts) { layout in
                    LayoutCard(layout: layout) {
                        selectedLayout = layout
                    } onShare: {
                        shareLayout(layout)
                    } onDelete: {
                        deleteLayout(layout)
                    }
                }
            }
        }
    }
    
    private var recentLayoutsContent: some View {
        Group {
            if sharingService.recentLayouts.isEmpty {
                emptyStateView(
                    title: "No Recent Layouts",
                    subtitle: "Your recently used layouts will appear here",
                    systemImage: "clock"
                )
            } else {
                ForEach(sharingService.recentLayouts) { layout in
                    LayoutCard(layout: layout, showLastUsed: true) {
                        selectedLayout = layout
                    } onShare: {
                        shareLayout(layout)
                    } onDelete: {
                        deleteLayout(layout)
                    }
                }
            }
        }
    }
    
    private var sharedLayoutsContent: some View {
        Group {
            if sharingService.sharedLayouts.isEmpty {
                emptyStateView(
                    title: "No Shared Layouts",
                    subtitle: "Browse community layouts and share your own",
                    systemImage: "square.and.arrow.up"
                )
            } else {
                ForEach(sharingService.sharedLayouts) { layout in
                    SharedLayoutCard(layout: layout) {
                        // Import shared layout
                        Task {
                            do {
                                let imported = try await sharingService.importLayout(from: Data()) // Placeholder
                                selectedLayout = imported
                            } catch {
                                print("Failed to import layout: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func emptyStateView(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Computed Properties
    
    private var filteredSavedLayouts: [SavedLayout] {
        if searchText.isEmpty {
            return sharingService.savedLayouts
        } else {
            return sharingService.searchLayouts(query: searchText)
        }
    }
    
    // MARK: - Actions
    
    private func shareLayout(_ layout: SavedLayout) {
        Task {
            do {
                let shareURL = try await sharingService.shareLayout(layout.id)
                
                DispatchQueue.main.async {
                    let activityVC = UIActivityViewController(
                        activityItems: [shareURL],
                        applicationActivities: nil
                    )
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(activityVC, animated: true)
                    }
                }
            } catch {
                print("Failed to share layout: \(error)")
            }
        }
    }
    
    private func deleteLayout(_ layout: SavedLayout) {
        Task {
            do {
                try await sharingService.deleteLayout(layout.id)
            } catch {
                print("Failed to delete layout: \(error)")
            }
        }
    }
}

// MARK: - Statistic View

struct StatisticView: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Layout Card

struct LayoutCard: View {
    let layout: SavedLayout
    let showLastUsed: Bool
    let onTap: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    
    init(
        layout: SavedLayout,
        showLastUsed: Bool = false,
        onTap: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.layout = layout
        self.showLastUsed = showLastUsed
        self.onTap = onTap
        self.onShare = onShare
        self.onDelete = onDelete
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(layout.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text("\(layout.layout.streams.count) streams • \(layout.layout.type.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Actions menu
                    Menu {
                        Button(action: onShare) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Layout preview
                LayoutPreview(layout: layout.layout)
                    .frame(height: 80)
                
                // Footer
                HStack {
                    // Platform indicators
                    PlatformIndicators(platforms: layout.layout.streams.map { $0.platform })
                    
                    Spacer()
                    
                    // Date info
                    VStack(alignment: .trailing, spacing: 2) {
                        if showLastUsed {
                            Text("Last used")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Created")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(layout.updatedAt.formatted(.relative(presentation: .abbreviated)))
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                
                // Tags
                if !layout.tags.isEmpty {
                    TagsView(tags: layout.tags)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Shared Layout Card

struct SharedLayoutCard: View {
    let layout: SharedLayout
    let onImport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(layout.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("by \(layout.createdBy)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onImport) {
                    Text("Import")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue, in: Capsule())
                }
            }
            
            // Layout preview
            LayoutPreview(layout: layout.layout)
                .frame(height: 80)
            
            // Footer
            HStack {
                // Platform indicators
                PlatformIndicators(platforms: layout.layout.streams.map { $0.platform })
                
                Spacer()
                
                // Stats
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", layout.rating))
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(layout.shareCount)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Platform Indicators

struct PlatformIndicators: View {
    let platforms: [Platform]
    
    var body: some View {
        HStack(spacing: -4) {
            ForEach(Array(Set(platforms)).prefix(4), id: \.self) { platform in
                Image(systemName: platform.icon)
                    .font(.caption2)
                    .foregroundColor(platform.color)
                    .padding(4)
                    .background(.regularMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.quaternary, lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Tags View

struct TagsView: View {
    let tags: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags.prefix(5), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
            }
            .padding(.horizontal, 1) // Prevent clipping
        }
    }
}

// MARK: - Layout Preview

struct LayoutPreview: View {
    let layout: StreamLayout
    
    var body: some View {
        // Simplified layout visualization
        GeometryReader { geometry in
            let columns = getGridColumns(for: layout.streams.count)
            let itemWidth = (geometry.size.width - CGFloat(columns - 1) * 4) / CGFloat(columns)
            let itemHeight = itemWidth * 9/16 // 16:9 aspect ratio
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth)), count: columns), spacing: 4) {
                ForEach(layout.streams.indices, id: \.self) { index in
                    let stream = layout.streams[index]
                    
                    Rectangle()
                        .fill(stream.platform.color.opacity(0.3))
                        .frame(width: itemWidth, height: itemHeight)
                        .overlay(
                            Image(systemName: stream.platform.icon)
                                .font(.caption2)
                                .foregroundColor(stream.platform.color)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
    
    private func getGridColumns(for streamCount: Int) -> Int {
        switch streamCount {
        case 1: return 1
        case 2: return 2
        case 3, 4: return 2
        default: return 3
        }
    }
}

// MARK: - Import Layout Sheet

struct ImportLayoutSheet: View {
    let sharingService: LayoutSharingService
    @Environment(\.dismiss) private var dismiss
    
    @State private var importURL = ""
    @State private var isLoading = false
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // URL Import
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import from URL")
                        .font(.headline)
                    
                    TextField("Paste share URL here...", text: $importURL)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Import from URL") {
                        importFromURL()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(importURL.isEmpty || isLoading)
                }
                
                Divider()
                
                // File Import
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import from File")
                        .font(.headline)
                    
                    Button("Choose File") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }
    
    private func importFromURL() {
        guard let url = URL(string: importURL) else { return }
        
        isLoading = true
        
        Task {
            do {
                _ = try await sharingService.importLayout(from: url)
                
                DispatchQueue.main.async {
                    isLoading = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    print("Import failed: \(error)")
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            
            Task {
                do {
                    let data = try Data(contentsOf: fileURL)
                    _ = try await sharingService.importLayout(from: data)
                    
                    DispatchQueue.main.async {
                        dismiss()
                    }
                } catch {
                    print("File import failed: \(error)")
                }
            }
            
        case .failure(let error):
            print("File picker failed: \(error)")
        }
    }
}

// MARK: - New Layout Sheet

struct NewLayoutSheet: View {
    let sharingService: LayoutSharingService
    @Environment(\.dismiss) private var dismiss
    
    @State private var layoutName = ""
    @State private var selectedStreams: [Stream] = []
    @State private var layoutType: LayoutType = .grid
    @State private var isPublic = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Layout Info") {
                    TextField("Layout Name", text: $layoutName)
                    
                    Toggle("Make Public", isOn: $isPublic)
                }
                
                Section("Layout Type") {
                    Picker("Type", selection: $layoutType) {
                        ForEach(LayoutType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Streams") {
                    Text("Select streams to include in this layout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Stream selection would go here
                    // This is a placeholder for the actual stream selection UI
                }
            }
            .navigationTitle("New Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveLayout()
                    }
                    .disabled(layoutName.isEmpty)
                }
            }
        }
    }
    
    private func saveLayout() {
        // Create layout and save
        let layout = StreamLayout(
            id: UUID().uuidString,
            type: layoutType,
            streams: selectedStreams,
            customPositions: [:],
            aspectRatio: .standard,
            backgroundColor: .black
        )
        
        Task {
            do {
                _ = try await sharingService.saveLayout(layout, name: layoutName, isPublic: isPublic)
                
                DispatchQueue.main.async {
                    dismiss()
                }
            } catch {
                print("Failed to save layout: \(error)")
            }
        }
    }
}

// MARK: - Layout Detail Sheet

struct LayoutDetailSheet: View {
    let layout: SavedLayout
    let sharingService: LayoutSharingService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Layout preview
                    LayoutPreview(layout: layout.layout)
                        .frame(height: 200)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Layout info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Layout Information")
                            .font(.headline)
                        
                        InfoRow(label: "Name", value: layout.name)
                        InfoRow(label: "Type", value: layout.layout.type.displayName)
                        InfoRow(label: "Streams", value: "\(layout.layout.streams.count)")
                        InfoRow(label: "Created", value: layout.createdAt.formatted(.dateTime))
                        InfoRow(label: "Updated", value: layout.updatedAt.formatted(.dateTime))
                        
                        if layout.isPublic {
                            InfoRow(label: "Shares", value: "\(layout.shareCount)")
                        }
                    }
                    
                    // Platforms
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Platforms")
                            .font(.headline)
                        
                        PlatformIndicators(platforms: layout.layout.streams.map { $0.platform })
                    }
                    
                    // Tags
                    if !layout.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.headline)
                            
                            TagsView(tags: layout.tags)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(layout.name)
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

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Preview

#Preview {
    LayoutSharingView()
}