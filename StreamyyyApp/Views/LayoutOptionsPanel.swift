//
//  LayoutOptionsPanel.swift
//  StreamyyyApp
//
//  Advanced layout customization panel with presets and custom options
//

import SwiftUI

struct LayoutOptionsPanel: View {
    @ObservedObject var streamManager: MultiStreamManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: LayoutPreset? = nil
    @State private var showingCustomEditor = false
    @State private var customSpacing: Double = 16
    @State private var customCornerRadius: Double = 12
    @State private var showLayoutGrid = true
    
    struct LayoutPreset: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let layout: MultiStreamLayout
        let description: String
        let icon: String
        let category: PresetCategory
        
        enum PresetCategory: String, CaseIterable {
            case gaming = "Gaming"
            case streaming = "Streaming"
            case productivity = "Productivity"
            case entertainment = "Entertainment"
        }
    }
    
    private let layoutPresets: [LayoutPreset] = [
        // Gaming presets
        LayoutPreset(name: "Main + Chat", layout: .twoByTwo, description: "Perfect for gaming with chat monitoring", icon: "gamecontroller", category: .gaming),
        LayoutPreset(name: "Multi-Gaming", layout: .fourByFour, description: "Watch multiple gaming streams", icon: "rectangle.grid.2x2", category: .gaming),
        LayoutPreset(name: "Focus Mode", layout: .single, description: "Single stream focus", icon: "viewfinder", category: .gaming),
        
        // Streaming presets
        LayoutPreset(name: "Stream Setup", layout: .twoByTwo, description: "Monitor your own stream and others", icon: "tv", category: .streaming),
        LayoutPreset(name: "Collaboration", layout: .threeByThree, description: "Multi-creator collaboration", icon: "person.3", category: .streaming),
        
        // Productivity presets
        LayoutPreset(name: "News & Updates", layout: .twoByTwo, description: "Stay informed with multiple news streams", icon: "newspaper", category: .productivity),
        LayoutPreset(name: "Learning", layout: .threeByThree, description: "Educational content viewing", icon: "book", category: .productivity),
        
        // Entertainment presets
        LayoutPreset(name: "Entertainment Hub", layout: .fourByFour, description: "Maximum content consumption", icon: "sparkles", category: .entertainment),
        LayoutPreset(name: "Chill Mode", layout: .single, description: "Relaxed single stream viewing", icon: "leaf", category: .entertainment)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Current layout overview
                        currentLayoutOverview
                        
                        // Quick layout selector
                        quickLayoutSelector
                        
                        // Layout presets by category
                        layoutPresetsByCategory
                        
                        // Custom layout options
                        customLayoutOptions
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Layout Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingCustomEditor) {
            CustomLayoutEditor(streamManager: streamManager)
        }
    }
    
    // MARK: - Current Layout Overview
    private var currentLayoutOverview: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Layout")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(streamManager.currentLayout.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Layout preview
                layoutPreviewGrid(layout: streamManager.currentLayout, size: 80)
            }
            
            // Layout stats
            HStack(spacing: 20) {
                statItem(title: "Slots", value: "\(streamManager.currentLayout.maxStreams)", icon: "square.grid.3x3")
                statItem(title: "Active", value: "\(activeStreamCount)", icon: "tv")
                statItem(title: "Layout", value: streamManager.currentLayout.rawValue, icon: "rectangle.3.offgrid")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.cyan)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Quick Layout Selector
    private var quickLayoutSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Select")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(MultiStreamLayout.allCases, id: \.self) { layout in
                    quickLayoutCard(layout: layout)
                }
            }
        }
    }
    
    private func quickLayoutCard(layout: MultiStreamLayout) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                streamManager.updateLayout(layout)
            }
        }) {
            VStack(spacing: 12) {
                layoutPreviewGrid(layout: layout, size: 60)
                
                VStack(spacing: 4) {
                    Text(layout.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(streamManager.currentLayout == layout ? .black : .white)
                    
                    Text("\(layout.maxStreams) streams")
                        .font(.caption2)
                        .foregroundColor(streamManager.currentLayout == layout ? .black.opacity(0.7) : .white.opacity(0.7))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(streamManager.currentLayout == layout ? Color.white : .ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                streamManager.currentLayout == layout ? Color.clear : Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
    
    // MARK: - Layout Presets by Category
    private var layoutPresetsByCategory: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Layout Presets")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(LayoutPreset.PresetCategory.allCases, id: \.self) { category in
                presetCategorySection(category: category)
            }
        }
    }
    
    private func presetCategorySection(category: LayoutPreset.PresetCategory) -> some View {
        let categoryPresets = layoutPresets.filter { $0.category == category }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.purple)
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categoryPresets) { preset in
                        presetCard(preset: preset)
                    }
                }
                .padding(.horizontal, 1) // Prevents clipping of shadows
            }
        }
    }
    
    private func presetCard(preset: LayoutPreset) -> some View {
        Button(action: {
            selectedPreset = preset
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                streamManager.updateLayout(preset.layout)
            }
        }) {
            VStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                    )
                
                VStack(spacing: 4) {
                    Text(preset.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(preset.description)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .frame(width: 140, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedPreset?.id == preset.id ? Color.purple : Color.white.opacity(0.2),
                                lineWidth: selectedPreset?.id == preset.id ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
    
    // MARK: - Custom Layout Options
    private var customLayoutOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customization")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Spacing control
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stream Spacing")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(customSpacing))px")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Slider(value: $customSpacing, in: 8...32, step: 4)
                        .accentColor(.purple)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Corner radius control
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Corner Radius")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(customCornerRadius))px")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Slider(value: $customCornerRadius, in: 0...24, step: 2)
                        .accentColor(.purple)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Advanced editor button
                Button(action: { showingCustomEditor = true }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Advanced Layout Editor")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(ModernButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Methods
    private var activeStreamCount: Int {
        streamManager.activeStreams.compactMap { $0.stream }.count
    }
    
    private func categoryIcon(for category: LayoutPreset.PresetCategory) -> String {
        switch category {
        case .gaming: return "gamecontroller"
        case .streaming: return "tv"
        case .productivity: return "briefcase"
        case .entertainment: return "popcorn"
        }
    }
    
    private func layoutPreviewGrid(layout: MultiStreamLayout, size: CGFloat) -> some View {
        let columns = layout.columns
        let itemSize = (size - CGFloat(columns - 1) * 2) / CGFloat(columns)
        
        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(itemSize), spacing: 2), count: columns),
            spacing: 2
        ) {
            ForEach(0..<layout.maxStreams, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: itemSize, height: itemSize * 0.6)
            }
        }
        .frame(width: size, height: size * 0.8)
    }
}

// MARK: - Custom Layout Editor
struct CustomLayoutEditor: View {
    @ObservedObject var streamManager: MultiStreamManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Text("Custom Layout Editor")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Advanced layout customization coming soon!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    LayoutOptionsPanel(streamManager: MultiStreamManager())
}