//
//  LayoutCustomizationView.swift
//  StreamyyyApp
//
//  Advanced layout customization interface with real-time preview
//

import SwiftUI
import SwiftData

struct LayoutCustomizationView: View {
    @Binding var layout: Layout
    @State private var configuration: LayoutConfiguration
    @State private var selectedSection: CustomizationSection = .appearance
    @State private var showingColorPicker = false
    @State private var showingPresets = false
    @State private var hasUnsavedChanges = false
    
    @StateObject private var layoutManager = LayoutManager.shared
    @Environment(\.dismiss) private var dismiss
    
    init(layout: Binding<Layout>) {
        self._layout = layout
        self._configuration = State(initialValue: layout.wrappedValue.configuration)
    }
    
    var body: some View {
        NavigationView {
            HSplitView {
                // Configuration panel
                configurationPanel
                    .frame(minWidth: 300, maxWidth: 400)
                
                // Live preview
                previewPanel
                    .frame(minWidth: 400)
            }
            .navigationTitle("Customize Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showDiscardChangesAlert()
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Reset") {
                            resetToDefaults()
                        }
                        .disabled(!hasUnsavedChanges)
                        
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(!hasUnsavedChanges)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .onAppear {
            trackChanges()
        }
    }
    
    // MARK: - Configuration Panel
    private var configurationPanel: some View {
        VStack(spacing: 0) {
            // Section selector
            sectionSelector
            
            // Configuration content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedSection {
                    case .appearance:
                        appearanceSection
                    case .layout:
                        layoutSection
                    case .animation:
                        animationSection
                    case .controls:
                        controlsSection
                    case .advanced:
                        advancedSection
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Section Selector
    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CustomizationSection.allCases, id: \.self) { section in
                    SectionTab(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Appearance Section
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Appearance")
            
            // Background
            CustomizationGroup("Background") {
                ColorPicker("Background Color", selection: Binding(
                    get: { Color(hex: configuration.backgroundColor) ?? .clear },
                    set: { configuration.backgroundColor = $0.toHex() }
                ))
                
                HStack {
                    Text("Corner Radius")
                    Spacer()
                    Slider(
                        value: $configuration.cornerRadius,
                        in: 0...20,
                        step: 1
                    ) {
                        Text("\(Int(configuration.cornerRadius))pt")
                    }
                }
            }
            
            // Borders
            CustomizationGroup("Borders") {
                HStack {
                    Text("Width")
                    Spacer()
                    Slider(
                        value: $configuration.borderWidth,
                        in: 0...5,
                        step: 0.5
                    ) {
                        Text("\(configuration.borderWidth, specifier: "%.1f")pt")
                    }
                }
                
                ColorPicker("Border Color", selection: Binding(
                    get: { Color(hex: configuration.borderColor) ?? .clear },
                    set: { configuration.borderColor = $0.toHex() }
                ))
            }
            
            // Shadows
            CustomizationGroup("Shadows") {
                HStack {
                    Text("Radius")
                    Spacer()
                    Slider(
                        value: $configuration.shadowRadius,
                        in: 0...20,
                        step: 1
                    ) {
                        Text("\(Int(configuration.shadowRadius))pt")
                    }
                }
                
                HStack {
                    Text("Opacity")
                    Spacer()
                    Slider(
                        value: $configuration.shadowOpacity,
                        in: 0...1,
                        step: 0.1
                    ) {
                        Text("\(Int(configuration.shadowOpacity * 100))%")
                    }
                }
                
                HStack {
                    Text("Offset X")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.shadowOffset.width },
                            set: { configuration.shadowOffset.width = $0 }
                        ),
                        in: -10...10,
                        step: 1
                    ) {
                        Text("\(Int(configuration.shadowOffset.width))pt")
                    }
                }
                
                HStack {
                    Text("Offset Y")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.shadowOffset.height },
                            set: { configuration.shadowOffset.height = $0 }
                        ),
                        in: -10...10,
                        step: 1
                    ) {
                        Text("\(Int(configuration.shadowOffset.height))pt")
                    }
                }
            }
        }
    }
    
    // MARK: - Layout Section
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Layout")
            
            // Spacing
            CustomizationGroup("Spacing") {
                HStack {
                    Text("Stream Spacing")
                    Spacer()
                    Slider(
                        value: $configuration.spacing,
                        in: 0...50,
                        step: 2
                    ) {
                        Text("\(Int(configuration.spacing))pt")
                    }
                }
            }
            
            // Padding
            CustomizationGroup("Padding") {
                HStack {
                    Text("Top")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.padding.top },
                            set: { configuration.padding.top = $0 }
                        ),
                        in: 0...100,
                        step: 4
                    ) {
                        Text("\(Int(configuration.padding.top))pt")
                    }
                }
                
                HStack {
                    Text("Leading")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.padding.leading },
                            set: { configuration.padding.leading = $0 }
                        ),
                        in: 0...100,
                        step: 4
                    ) {
                        Text("\(Int(configuration.padding.leading))pt")
                    }
                }
                
                HStack {
                    Text("Bottom")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.padding.bottom },
                            set: { configuration.padding.bottom = $0 }
                        ),
                        in: 0...100,
                        step: 4
                    ) {
                        Text("\(Int(configuration.padding.bottom))pt")
                    }
                }
                
                HStack {
                    Text("Trailing")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.padding.trailing },
                            set: { configuration.padding.trailing = $0 }
                        ),
                        in: 0...100,
                        step: 4
                    ) {
                        Text("\(Int(configuration.padding.trailing))pt")
                    }
                }
            }
            
            // Aspect Ratio
            CustomizationGroup("Aspect Ratio") {
                if configuration.aspectRatio != nil {
                    HStack {
                        Text("Ratio")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { configuration.aspectRatio ?? 16/9 },
                                set: { configuration.aspectRatio = $0 }
                            ),
                            in: 1...3,
                            step: 0.1
                        ) {
                            Text("\(configuration.aspectRatio ?? 16/9, specifier: "%.1f"):1")
                        }
                    }
                }
                
                Toggle("Lock Aspect Ratio", isOn: Binding(
                    get: { configuration.aspectRatio != nil },
                    set: { enabled in
                        configuration.aspectRatio = enabled ? 16/9 : nil
                    }
                ))
            }
            
            // Stream Size Constraints
            CustomizationGroup("Stream Size") {
                HStack {
                    Text("Min Width")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.minStreamSize.width },
                            set: { configuration.minStreamSize.width = $0 }
                        ),
                        in: 50...300,
                        step: 10
                    ) {
                        Text("\(Int(configuration.minStreamSize.width))pt")
                    }
                }
                
                HStack {
                    Text("Min Height")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.minStreamSize.height },
                            set: { configuration.minStreamSize.height = $0 }
                        ),
                        in: 50...300,
                        step: 10
                    ) {
                        Text("\(Int(configuration.minStreamSize.height))pt")
                    }
                }
                
                HStack {
                    Text("Max Width")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.maxStreamSize.width },
                            set: { configuration.maxStreamSize.width = $0 }
                        ),
                        in: 200...1000,
                        step: 50
                    ) {
                        Text("\(Int(configuration.maxStreamSize.width))pt")
                    }
                }
                
                HStack {
                    Text("Max Height")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { configuration.maxStreamSize.height },
                            set: { configuration.maxStreamSize.height = $0 }
                        ),
                        in: 200...800,
                        step: 50
                    ) {
                        Text("\(Int(configuration.maxStreamSize.height))pt")
                    }
                }
            }
        }
    }
    
    // MARK: - Animation Section
    private var animationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Animation")
            
            CustomizationGroup("Settings") {
                Toggle("Enable Animations", isOn: $configuration.enableAnimations)
                
                if configuration.enableAnimations {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Slider(
                            value: $configuration.animationDuration,
                            in: 0.1...2.0,
                            step: 0.1
                        ) {
                            Text("\(configuration.animationDuration, specifier: "%.1f")s")
                        }
                    }
                }
            }
            
            // Animation Presets
            CustomizationGroup("Presets") {
                AnimationPresetButton("Smooth", duration: 0.3) {
                    configuration.animationDuration = 0.3
                }
                
                AnimationPresetButton("Quick", duration: 0.15) {
                    configuration.animationDuration = 0.15
                }
                
                AnimationPresetButton("Slow", duration: 0.6) {
                    configuration.animationDuration = 0.6
                }
                
                AnimationPresetButton("Bouncy", duration: 0.4) {
                    configuration.animationDuration = 0.4
                }
            }
        }
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Controls")
            
            // Labels
            CustomizationGroup("Labels") {
                Toggle("Show Labels", isOn: $configuration.showLabels)
                
                if configuration.showLabels {
                    Picker("Position", selection: $configuration.labelPosition) {
                        ForEach(LabelPosition.allCases, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Slider(
                            value: $configuration.labelFontSize,
                            in: 10...20,
                            step: 1
                        ) {
                            Text("\(Int(configuration.labelFontSize))pt")
                        }
                    }
                    
                    ColorPicker("Label Color", selection: Binding(
                        get: { Color(hex: configuration.labelColor) ?? .primary },
                        set: { configuration.labelColor = $0.toHex() }
                    ))
                }
            }
            
            // Stream Controls
            CustomizationGroup("Stream Controls") {
                Toggle("Show Controls", isOn: $configuration.showControls)
                
                if configuration.showControls {
                    Picker("Position", selection: $configuration.controlsPosition) {
                        ForEach(ControlsPosition.allCases, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Auto Hide", isOn: $configuration.autoHideControls)
                    
                    if configuration.autoHideControls {
                        HStack {
                            Text("Timeout")
                            Spacer()
                            Slider(
                                value: $configuration.controlsTimeout,
                                in: 1...10,
                                step: 0.5
                            ) {
                                Text("\(configuration.controlsTimeout, specifier: "%.1f")s")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Section
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Advanced")
            
            // Interaction
            CustomizationGroup("Interaction") {
                Toggle("Enable Gestures", isOn: $configuration.enableGestures)
                Toggle("Enable Drag & Drop", isOn: $configuration.enableDragAndDrop)
            }
            
            // Grid
            CustomizationGroup("Grid") {
                Toggle("Snap to Grid", isOn: $configuration.snapToGrid)
                
                if configuration.snapToGrid {
                    HStack {
                        Text("Grid Size")
                        Spacer()
                        Slider(
                            value: $configuration.gridSize,
                            in: 5...50,
                            step: 5
                        ) {
                            Text("\(Int(configuration.gridSize))pt")
                        }
                    }
                }
            }
            
            // Custom Properties
            CustomizationGroup("Custom Properties") {
                ForEach(Array(configuration.customProperties.keys), id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        TextField("Value", text: Binding(
                            get: { configuration.customProperties[key] as? String ?? "" },
                            set: { configuration.customProperties[key] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                    }
                }
                
                Button("Add Property") {
                    configuration.customProperties["new_property"] = ""
                }
            }
        }
    }
    
    // MARK: - Preview Panel
    private var previewPanel: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Text("Live Preview")
                    .font(.headline)
                
                Spacer()
                
                Button("Full Screen") {
                    // TODO: Show full screen preview
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Preview content
            ScrollView([.horizontal, .vertical]) {
                LayoutPreviewCanvas(
                    layout: layout,
                    configuration: configuration
                )
                .frame(
                    width: max(600, layoutManager.screenSize.width),
                    height: max(800, layoutManager.screenSize.height)
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Helper Methods
    private func trackChanges() {
        hasUnsavedChanges = configuration != layout.configuration
    }
    
    private func saveChanges() {
        layout.updateConfiguration(configuration)
        hasUnsavedChanges = false
        dismiss()
    }
    
    private func resetToDefaults() {
        configuration = LayoutConfiguration.default(for: layout.type)
        hasUnsavedChanges = true
    }
    
    private func showDiscardChangesAlert() {
        // TODO: Show alert
    }
}

// MARK: - Supporting Views
struct SectionTab: View {
    let section: CustomizationSection
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.caption)
                Text(section.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
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

struct SectionHeader: View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
    }
}

struct CustomizationGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct AnimationPresetButton: View {
    let name: String
    let duration: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(.caption)
                Spacer()
                Text("\(duration, specifier: "%.1f")s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LayoutPreviewCanvas: View {
    let layout: Layout
    let configuration: LayoutConfiguration
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: configuration.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .stroke(Color(hex: configuration.borderColor), lineWidth: configuration.borderWidth)
                )
                .shadow(
                    color: Color.black.opacity(configuration.shadowOpacity),
                    radius: configuration.shadowRadius,
                    x: configuration.shadowOffset.width,
                    y: configuration.shadowOffset.height
                )
            
            // Stream placeholders
            ForEach(layout.streams, id: \.id) { layoutStream in
                StreamPlaceholder(
                    layoutStream: layoutStream,
                    configuration: configuration
                )
            }
        }
        .padding(EdgeInsets(
            top: configuration.padding.top,
            leading: configuration.padding.leading,
            bottom: configuration.padding.bottom,
            trailing: configuration.padding.trailing
        ))
    }
}

struct StreamPlaceholder: View {
    let layoutStream: LayoutStream
    let configuration: LayoutConfiguration
    
    var body: some View {
        VStack(spacing: 0) {
            // Stream content area
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    VStack {
                        Image(systemName: "tv")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text("Stream")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
            
            // Label
            if configuration.showLabels && configuration.labelPosition == .bottom {
                Text("Stream Name")
                    .font(.system(size: configuration.labelFontSize))
                    .foregroundColor(Color(hex: configuration.labelColor))
                    .padding(.top, 4)
            }
        }
        .frame(
            width: layoutStream.position.width,
            height: layoutStream.position.height
        )
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .position(
            x: layoutStream.position.x + layoutStream.position.width / 2,
            y: layoutStream.position.y + layoutStream.position.height / 2
        )
    }
}

// MARK: - Supporting Types
enum CustomizationSection: CaseIterable {
    case appearance
    case layout
    case animation
    case controls
    case advanced
    
    var displayName: String {
        switch self {
        case .appearance: return "Appearance"
        case .layout: return "Layout"
        case .animation: return "Animation"
        case .controls: return "Controls"
        case .advanced: return "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .appearance: return "paintbrush"
        case .layout: return "rectangle.3.group"
        case .animation: return "play.circle"
        case .controls: return "slider.horizontal.3"
        case .advanced: return "gearshape"
        }
    }
}

// MARK: - Color Extensions
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(format: "#%02X%02X%02X",
                     Int(red * 255),
                     Int(green * 255),
                     Int(blue * 255))
    }
    
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Preview
struct LayoutCustomizationView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutCustomizationView(layout: .constant(Layout(
            name: "Test Layout",
            type: .grid2x2
        )))
    }
}