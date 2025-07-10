//
//  LayoutSelectorView.swift
//  StreamyyyApp
//
//  Advanced layout selection interface with search, filtering, and preview
//

import SwiftUI
import SwiftData

struct LayoutSelectorView: View {
    @StateObject private var layoutManager = LayoutManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: LayoutCategory = .all
    @State private var showingCreator = false
    @State private var showingTemplates = false
    @State private var selectedLayout: Layout?
    @State private var showingPreview = false
    @State private var sortOrder: SortOrder = .recentlyUsed
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search and filters
                headerView
                
                // Category selector
                categorySelector
                
                // Layout grid
                layoutGrid
            }
            .navigationTitle("Select Layout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("New Layout") {
                            showingCreator = true
                        }
                        Button("Browse Templates") {
                            showingTemplates = true
                        }
                        Button("Import Layout") {
                            // TODO: Implement import
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreator) {
            LayoutCreatorView()
        }
        .sheet(isPresented: $showingTemplates) {
            LayoutTemplateView()
        }
        .sheet(item: $selectedLayout) { layout in
            LayoutPreviewView(layout: layout) { confirmed in
                if confirmed {
                    layoutManager.setCurrentLayout(layout)
                    dismiss()
                }
            }
        }
        .onAppear {
            Task {
                await layoutManager.loadAvailableLayouts()
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search layouts...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Sort and filter controls
            HStack {
                Menu {
                    Button("Recently Used") {
                        sortOrder = .recentlyUsed
                    }
                    Button("Name") {
                        sortOrder = .name
                    }
                    Button("Type") {
                        sortOrder = .type
                    }
                    Button("Rating") {
                        sortOrder = .rating
                    }
                    Button("Created Date") {
                        sortOrder = .created
                    }
                } label: {
                    HStack {
                        Text("Sort: \(sortOrder.displayName)")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Implement view mode toggle
                }) {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    // MARK: - Category Selector
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LayoutCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        count: layoutCount(for: category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Layout Grid
    private var layoutGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(filteredLayouts) { layout in
                    LayoutCard(layout: layout) {
                        selectedLayout = layout
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Computed Properties
    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 16)
        ]
    }
    
    private var filteredLayouts: [Layout] {
        var layouts = layoutManager.availableLayouts
        
        // Filter by category
        switch selectedCategory {
        case .all:
            break
        case .templates:
            layouts = layoutManager.templateLayouts
        case .custom:
            layouts = layoutManager.customLayouts
        case .recent:
            layouts = layoutManager.recentLayouts
        case .favorites:
            layouts = layoutManager.favoriteLayouts
        case .shared:
            layouts = layouts.filter { $0.isShared }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            layouts = layouts.filter { layout in
                layout.name.localizedCaseInsensitiveContains(searchText) ||
                layout.description?.localizedCaseInsensitiveContains(searchText) == true ||
                layout.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Sort layouts
        switch sortOrder {
        case .recentlyUsed:
            layouts.sort { ($0.lastUsedAt ?? Date.distantPast) > ($1.lastUsedAt ?? Date.distantPast) }
        case .name:
            layouts.sort { $0.name < $1.name }
        case .type:
            layouts.sort { $0.type.displayName < $1.type.displayName }
        case .rating:
            layouts.sort { $0.rating > $1.rating }
        case .created:
            layouts.sort { $0.createdAt > $1.createdAt }
        }
        
        return layouts
    }
    
    private func layoutCount(for category: LayoutCategory) -> Int {
        switch category {
        case .all:
            return layoutManager.availableLayouts.count
        case .templates:
            return layoutManager.templateLayouts.count
        case .custom:
            return layoutManager.customLayouts.count
        case .recent:
            return layoutManager.recentLayouts.count
        case .favorites:
            return layoutManager.favoriteLayouts.count
        case .shared:
            return layoutManager.availableLayouts.filter { $0.isShared }.count
        }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: LayoutCategory
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Layout Card
struct LayoutCard: View {
    let layout: Layout
    let onTap: () -> Void
    
    @StateObject private var layoutManager = LayoutManager.shared
    @State private var showingOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preview thumbnail
            layoutPreview
            
            // Layout info
            layoutInfo
            
            // Action buttons
            actionButtons
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
        .contextMenu {
            contextMenuItems
        }
    }
    
    private var layoutPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .aspectRatio(16/9, contentMode: .fit)
            
            // Mini layout preview
            LayoutMiniPreview(layout: layout)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private var layoutInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Layout name and type
            HStack {
                Text(layout.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: layout.typeIcon)
                        .font(.caption)
                        .foregroundColor(layout.typeColor)
                    
                    Text(layout.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description
            if let description = layout.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Stats
            HStack {
                // Stream count
                HStack(spacing: 2) {
                    Image(systemName: "tv")
                        .font(.caption2)
                    Text("\(layout.streams.count)")
                        .font(.caption2)
                }
                
                Spacer()
                
                // Rating
                if layout.rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(layout.displayRating)
                            .font(.caption2)
                    }
                }
                
                // Status badges
                HStack(spacing: 4) {
                    if layout.isDefault {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    if layout.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                    
                    if layout.isShared {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var actionButtons: some View {
        HStack {
            Button("Select") {
                layoutManager.setCurrentLayout(layout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Spacer()
            
            Button(action: {
                showingOptions = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .actionSheet(isPresented: $showingOptions) {
            ActionSheet(
                title: Text(layout.name),
                message: Text("Choose an action"),
                buttons: [
                    .default(Text("Duplicate")) {
                        layoutManager.duplicateLayout(layout)
                    },
                    .default(Text("Edit")) {
                        // TODO: Open layout editor
                    },
                    .default(Text("Share")) {
                        // TODO: Share layout
                    },
                    .destructive(Text("Delete")) {
                        layoutManager.deleteLayout(layout)
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private var contextMenuItems: some View {
        Group {
            Button {
                layoutManager.setCurrentLayout(layout)
            } label: {
                Label("Select Layout", systemImage: "checkmark")
            }
            
            Button {
                layoutManager.duplicateLayout(layout)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Button {
                // TODO: Edit layout
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button {
                // TODO: Share layout
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive) {
                layoutManager.deleteLayout(layout)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Layout Mini Preview
struct LayoutMiniPreview: View {
    let layout: Layout
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemGray6)
                
                // Stream rectangles
                ForEach(layout.streams, id: \.id) { layoutStream in
                    let normalizedRect = normalizeRect(
                        layoutStream.position.rect,
                        to: geometry.size
                    )
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(layout.typeColor.opacity(0.7))
                        .frame(
                            width: normalizedRect.width,
                            height: normalizedRect.height
                        )
                        .position(
                            x: normalizedRect.midX,
                            y: normalizedRect.midY
                        )
                }
                
                // Type indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: layout.typeIcon)
                            .font(.caption2)
                            .foregroundColor(layout.typeColor)
                            .padding(4)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                    }
                }
                .padding(4)
            }
        }
    }
    
    private func normalizeRect(_ rect: CGRect, to size: CGSize) -> CGRect {
        let scaleX = size.width / 375  // Base iPhone width
        let scaleY = size.height / 667 // Base iPhone height
        
        return CGRect(
            x: rect.minX * scaleX,
            y: rect.minY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }
}

// MARK: - Layout Preview Modal
struct LayoutPreviewView: View {
    let layout: Layout
    let onConfirm: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Large preview
                LayoutMiniPreview(layout: layout)
                    .aspectRatio(16/9, contentMode: .fit)
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                
                // Layout details
                VStack(alignment: .leading, spacing: 12) {
                    Text(layout.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(layout.description ?? "No description")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label("\(layout.streams.count) streams", systemImage: "tv")
                        Spacer()
                        Label(layout.type.displayName, systemImage: layout.typeIcon)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onConfirm(false)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("Select Layout") {
                        onConfirm(true)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Layout Creator View
struct LayoutCreatorView: View {
    @State private var name = ""
    @State private var selectedType: LayoutType = .custom
    @State private var description = ""
    
    @StateObject private var layoutManager = LayoutManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Layout Details")) {
                    TextField("Layout Name", text: $name)
                    TextField("Description (Optional)", text: $description)
                }
                
                Section(header: Text("Layout Type")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(LayoutType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section(header: Text("Preview")) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedType.color.opacity(0.2))
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Image(systemName: selectedType.icon)
                                    .font(.title)
                                    .foregroundColor(selectedType.color)
                                Text(selectedType.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        )
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
                    Button("Create") {
                        let layout = layoutManager.createLayout(
                            name: name.isEmpty ? selectedType.displayName : name,
                            type: selectedType
                        )
                        layoutManager.setCurrentLayout(layout)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Supporting Types
enum LayoutCategory: CaseIterable {
    case all
    case templates
    case custom
    case recent
    case favorites
    case shared
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .templates: return "Templates"
        case .custom: return "Custom"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        case .shared: return "Shared"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.stack"
        case .templates: return "doc.badge.gearshape"
        case .custom: return "slider.horizontal.3"
        case .recent: return "clock"
        case .favorites: return "heart"
        case .shared: return "square.and.arrow.up"
        }
    }
}

enum SortOrder: CaseIterable {
    case recentlyUsed
    case name
    case type
    case rating
    case created
    
    var displayName: String {
        switch self {
        case .recentlyUsed: return "Recently Used"
        case .name: return "Name"
        case .type: return "Type"
        case .rating: return "Rating"
        case .created: return "Created"
        }
    }
}

// MARK: - Preview
struct LayoutSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutSelectorView()
    }
}