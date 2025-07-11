//
//  LayoutPickerSheet.swift
//  StreamyyyApp
//
//  Advanced layout picker with visual previews and saved layouts
//

import SwiftUI

struct LayoutPickerSheet: View {
    let currentLayout: MultiStreamLayout
    let onLayoutSelected: (MultiStreamLayout) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLayout: MultiStreamLayout
    @State private var showingSavedLayouts = false
    
    init(currentLayout: MultiStreamLayout, onLayoutSelected: @escaping (MultiStreamLayout) -> Void) {
        self.currentLayout = currentLayout
        self.onLayoutSelected = onLayoutSelected
        self._selectedLayout = State(initialValue: currentLayout)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Layout options
                    layoutOptionsView
                    
                    // Action buttons
                    actionButtonsView
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Layout")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Select your preferred multi-stream layout")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.cyan)
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Layout Options
    private var layoutOptionsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            ForEach(MultiStreamLayout.allCases, id: \.self) { layout in
                LayoutOptionCard(
                    layout: layout,
                    isSelected: selectedLayout == layout,
                    isCurrent: currentLayout == layout,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedLayout = layout
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            // Apply button
            Button(action: {
                onLayoutSelected(selectedLayout)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    
                    Text("Apply Layout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            selectedLayout != currentLayout ?
                            LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                )
            }
            .disabled(selectedLayout == currentLayout)
            
            // Quick actions
            HStack(spacing: 12) {
                Button(action: {
                    // Reset to 2x2 default
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedLayout = .twoByTwo
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                        Text("Reset")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
                }
                
                Spacer()
                
                Button(action: {
                    showingSavedLayouts = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.caption)
                        Text("Saved")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            }
        }
    }
}

// MARK: - Layout Option Card
struct LayoutOptionCard: View {
    let layout: MultiStreamLayout
    let isSelected: Bool
    let isCurrent: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Layout preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .frame(height: 120)
                    
                    layoutPreview
                        .padding(12)
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
                
                // Layout info
                VStack(spacing: 6) {
                    HStack {
                        Text(layout.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if isCurrent {
                            Text("CURRENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.cyan.opacity(0.2))
                                )
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("\(layout.maxStreams) streams")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected ?
                        Color.white.opacity(0.05) :
                        Color.clear
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            action()
        }
    }
    
    @ViewBuilder
    private var layoutPreview: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: layout.columns),
            spacing: 4
        ) {
            ForEach(0..<layout.maxStreams, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.4),
                                Color.purple.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .aspectRatio(16/9, contentMode: .fit)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                        .delay(Double(index) * 0.05),
                        value: isSelected
                    )
            }
        }
    }
}

// MARK: - Layout Descriptions
extension MultiStreamLayout {
    var description: String {
        switch self {
        case .single:
            return "Focus on one stream with maximum detail"
        case .twoByTwo:
            return "Balanced view with four streams"
        case .threeByThree:
            return "Grid layout for monitoring many streams"
        case .fourByFour:
            return "Maximum streams for professional monitoring"
        }
    }
    
    var recommendedFor: String {
        switch self {
        case .single:
            return "Detailed viewing, focus mode"
        case .twoByTwo:
            return "Casual multi-streaming"
        case .threeByThree:
            return "Content monitoring"
        case .fourByFour:
            return "Professional streaming"
        }
    }
}

#Preview {
    LayoutPickerSheet(
        currentLayout: .twoByTwo,
        onLayoutSelected: { _ in }
    )
}