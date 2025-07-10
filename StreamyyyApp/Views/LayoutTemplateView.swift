//
//  LayoutTemplateView.swift
//  StreamyyyApp
//
//  Pre-built layout templates browser and manager
//

import SwiftUI
import SwiftData

struct LayoutTemplateView: View {
    @StateObject private var layoutManager = LayoutManager.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var sortOrder: TemplateSortOrder = .popular
    @State private var showingCreateTemplate = false
    @State private var selectedTemplate: StreamTemplate?
    @State private var isLoading = false
    @State private var templates: [StreamTemplate] = []
    @State private var categories: [String] = ["All", "Gaming", "Entertainment", "Sports", "Music", "Talk Shows", "Custom"]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header controls
                headerControls
                
                // Category filter
                categoryFilter
                
                // Templates grid
                templatesGrid
            }
            .navigationTitle("Layout Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        showingCreateTemplate = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTemplate) {
            CreateTemplateView()
        }
        .sheet(item: $selectedTemplate) { template in
            TemplateDetailView(template: template) { action in
                handleTemplateAction(action, template: template)
            }
        }
        .onAppear {
            loadTemplates()
        }
        .refreshable {
            loadTemplates()
        }
    }
    
    // MARK: - Header Controls
    private var headerControls: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search templates...", text: $searchText)
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
            
            // Sort options
            HStack {
                Menu {
                    Button("Most Popular") {
                        sortOrder = .popular
                    }
                    Button("Highest Rated") {
                        sortOrder = .rating
                    }
                    Button("Newest") {
                        sortOrder = .newest
                    }
                    Button("Name") {
                        sortOrder = .name
                    }
                    Button("Most Downloaded") {
                        sortOrder = .downloads
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
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        count: templateCount(for: category)
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
    
    // MARK: - Templates Grid
    private var templatesGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(filteredTemplates) { template in
                    TemplateCard(template: template) {
                        selectedTemplate = template
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
            GridItem(.adaptive(minimum: 300, maximum: 350), spacing: 20)
        ]
    }
    
    private var filteredTemplates: [StreamTemplate] {
        var filtered = templates
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.description?.localizedCaseInsensitiveContains(searchText) == true ||
                template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Sort templates
        switch sortOrder {
        case .popular:
            filtered.sort { $0.downloads > $1.downloads }
        case .rating:
            filtered.sort { $0.rating > $1.rating }
        case .newest:
            filtered.sort { $0.createdAt > $1.createdAt }
        case .name:
            filtered.sort { $0.name < $1.name }
        case .downloads:
            filtered.sort { $0.downloads > $1.downloads }
        }
        
        return filtered
    }
    
    private func templateCount(for category: String) -> Int {
        if category == "All" {
            return templates.count
        }
        return templates.filter { $0.category == category }.count
    }
    
    // MARK: - Actions
    private func loadTemplates() {
        isLoading = true
        
        Task {
            do {
                let loadedTemplates = try await layoutManager.layoutSyncManager.loadTemplates()
                await MainActor.run {
                    templates = loadedTemplates
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // TODO: Show error
                }
            }
        }
    }
    
    private func handleTemplateAction(_ action: TemplateAction, template: StreamTemplate) {
        switch action {
        case .use:
            useTemplate(template)
        case .download:
            downloadTemplate(template)
        case .favorite:
            toggleFavorite(template)
        case .share:
            shareTemplate(template)
        case .report:
            reportTemplate(template)
        }
    }
    
    private func useTemplate(_ template: StreamTemplate) {
        Task {
            do {
                let layout = try await layoutManager.layoutSyncManager.createLayoutFromTemplate(template)
                await MainActor.run {
                    layoutManager.setCurrentLayout(layout)
                    dismiss()
                }
            } catch {
                // TODO: Show error
            }
        }
    }
    
    private func downloadTemplate(_ template: StreamTemplate) {
        // TODO: Implement download for offline use
    }
    
    private func toggleFavorite(_ template: StreamTemplate) {
        // TODO: Implement favorite toggle
    }
    
    private func shareTemplate(_ template: StreamTemplate) {
        // TODO: Implement sharing
    }
    
    private func reportTemplate(_ template: StreamTemplate) {
        // TODO: Implement reporting
    }
}

// MARK: - Category Button
struct CategoryButton: View {
    let category: String
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: categoryIcon(for: category))
                    .font(.caption)
                
                Text(category)
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
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "All": return "square.stack"
        case "Gaming": return "gamecontroller"
        case "Entertainment": return "tv"
        case "Sports": return "sportscourt"
        case "Music": return "music.note"
        case "Talk Shows": return "mic"
        case "Custom": return "slider.horizontal.3"
        default: return "folder"
        }
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let template: StreamTemplate
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Template preview
            templatePreview
            
            // Template info
            templateInfo
            
            // Stats and actions
            statsAndActions
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
        .onTapGesture {
            onTap()
        }
    }
    
    private var templatePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .aspectRatio(16/9, contentMode: .fit)
            
            // Template layout visualization
            TemplateMiniPreview(template: template)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var templateInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Name and category
            HStack {
                Text(template.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(template.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }
            
            // Description
            if let description = template.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Tags
            if !template.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(template.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
    private var statsAndActions: some View {
        HStack {
            // Rating
            if template.rating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("\(template.rating, specifier: "%.1f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Downloads
            HStack(spacing: 2) {
                Image(systemName: "arrow.down.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(template.downloads)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Premium badge
            if template.isPremium {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundColor(.purple)
            }
            
            // Action button
            Button("Use") {
                onTap()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Template Mini Preview
struct TemplateMiniPreview: View {
    let template: StreamTemplate
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGray6)
                
                // Create layout visualization from template data
                if let layoutData = template.layoutData as? [String: Any],
                   let streamsData = layoutData["streams"] as? [[String: Any]] {
                    
                    ForEach(0..<min(streamsData.count, 6), id: \.self) { index in
                        let streamData = streamsData[index]
                        let normalizedRect = normalizeStreamRect(streamData, to: geometry.size)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.6))
                            .frame(
                                width: normalizedRect.width,
                                height: normalizedRect.height
                            )
                            .position(
                                x: normalizedRect.midX,
                                y: normalizedRect.midY
                            )
                    }
                } else {
                    // Default pattern for unknown template structure
                    defaultLayoutPattern(in: geometry.size)
                }
                
                // Category icon overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: categoryIcon(for: template.category))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding(4)
            }
        }
    }
    
    private func normalizeStreamRect(_ streamData: [String: Any], to size: CGSize) -> CGRect {
        let x = (streamData["x"] as? Double) ?? 0
        let y = (streamData["y"] as? Double) ?? 0
        let width = (streamData["width"] as? Double) ?? 100
        let height = (streamData["height"] as? Double) ?? 75
        
        let scaleX = size.width / 375
        let scaleY = size.height / 667
        
        return CGRect(
            x: x * scaleX,
            y: y * scaleY,
            width: width * scaleX,
            height: height * scaleY
        )
    }
    
    private func defaultLayoutPattern(in size: CGSize) -> some View {
        let itemWidth = size.width / 3
        let itemHeight = size.height / 3
        
        return Group {
            ForEach(0..<4) { index in
                let col = index % 2
                let row = index / 2
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.6))
                    .frame(
                        width: itemWidth * 0.8,
                        height: itemHeight * 0.8
                    )
                    .position(
                        x: CGFloat(col) * itemWidth + itemWidth/2,
                        y: CGFloat(row) * itemHeight + itemHeight/2
                    )
            }
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Gaming": return "gamecontroller"
        case "Entertainment": return "tv"
        case "Sports": return "sportscourt"
        case "Music": return "music.note"
        case "Talk Shows": return "mic"
        default: return "square.stack"
        }
    }
}

// MARK: - Template Detail View
struct TemplateDetailView: View {
    let template: StreamTemplate
    let onAction: (TemplateAction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Large preview
                    templatePreview
                    
                    // Template info
                    templateInfo
                    
                    // Description
                    if let description = template.description {
                        descriptionSection(description)
                    }
                    
                    // Tags
                    if !template.tags.isEmpty {
                        tagsSection
                    }
                    
                    // Stats
                    statsSection
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var templatePreview: some View {
        TemplateMiniPreview(template: template)
            .aspectRatio(16/9, contentMode: .fit)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var templateInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                if template.isPremium {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
            }
            
            HStack {
                Text(template.category)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if template.rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("\(template.rating, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("(\(template.ratingCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                ForEach(template.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)
            
            HStack {
                StatItem(icon: "arrow.down.circle", value: "\(template.downloads)", label: "Downloads")
                Spacer()
                StatItem(icon: "heart", value: "\(template.favorites)", label: "Favorites")
                Spacer()
                StatItem(icon: "calendar", value: formatDate(template.createdAt), label: "Created")
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button("Use This Template") {
                onAction(.use)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 12) {
                Button("Download") {
                    onAction(.download)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Favorite") {
                    onAction(.favorite)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Share") {
                    onAction(.share)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            
            Button("Report") {
                onAction(.report)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .font(.caption)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Create Template View
struct CreateTemplateView: View {
    @State private var name = ""
    @State private var description = ""
    @State private var category = "Custom"
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var isPublic = false
    @State private var selectedLayout: Layout?
    
    @StateObject private var layoutManager = LayoutManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Template Details")) {
                    TextField("Template Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Category", selection: $category) {
                        ForEach(["Custom", "Gaming", "Entertainment", "Sports", "Music", "Talk Shows"], id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section(header: Text("Layout Source")) {
                    Picker("Base Layout", selection: $selectedLayout) {
                        Text("Select Layout").tag(Layout?.none)
                        ForEach(layoutManager.availableLayouts) { layout in
                            Text(layout.name).tag(layout as Layout?)
                        }
                    }
                }
                
                Section(header: Text("Tags")) {
                    HStack {
                        TextField("Add tag", text: $newTag)
                        Button("Add") {
                            if !newTag.isEmpty && !tags.contains(newTag) {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }
                        .disabled(newTag.isEmpty)
                    }
                    
                    if !tags.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack {
                                    Text(tag)
                                        .font(.caption)
                                    Button("×") {
                                        tags.removeAll { $0 == tag }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Section(header: Text("Visibility")) {
                    Toggle("Make Public", isOn: $isPublic)
                }
            }
            .navigationTitle("Create Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTemplate()
                    }
                    .disabled(name.isEmpty || selectedLayout == nil)
                }
            }
        }
    }
    
    private func createTemplate() {
        guard let layout = selectedLayout else { return }
        
        Task {
            do {
                let _ = try await layoutManager.layoutSyncManager.saveAsTemplate(
                    layout,
                    category: category
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // TODO: Show error
            }
        }
    }
}

// MARK: - Supporting Types
enum TemplateSortOrder: CaseIterable {
    case popular
    case rating
    case newest
    case name
    case downloads
    
    var displayName: String {
        switch self {
        case .popular: return "Most Popular"
        case .rating: return "Highest Rated"
        case .newest: return "Newest"
        case .name: return "Name"
        case .downloads: return "Most Downloaded"
        }
    }
}

enum TemplateAction {
    case use
    case download
    case favorite
    case share
    case report
}

// MARK: - Mock StreamTemplate for compilation
struct StreamTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String?
    let category: String
    let tags: [String]
    let layoutData: [String: Any]
    let rating: Double
    let ratingCount: Int
    let downloads: Int
    let favorites: Int
    let isPremium: Bool
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init(name: String, description: String? = nil, category: String, tags: [String] = [], layoutData: [String: Any], isPublic: Bool = false) {
        self.name = name
        self.description = description
        self.category = category
        self.tags = tags
        self.layoutData = layoutData
        self.rating = Double.random(in: 3.0...5.0)
        self.ratingCount = Int.random(in: 5...100)
        self.downloads = Int.random(in: 10...1000)
        self.favorites = Int.random(in: 5...200)
        self.isPremium = Bool.random()
        self.isPublic = isPublic
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Preview
struct LayoutTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutTemplateView()
    }
}