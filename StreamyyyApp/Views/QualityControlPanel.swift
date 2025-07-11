//
//  QualityControlPanel.swift
//  StreamyyyApp
//
//  Advanced quality control panel for multi-stream management
//

import SwiftUI

struct QualityControlPanel: View {
    @Binding var globalQuality: StreamQuality
    let streamSlots: [StreamSlot]
    
    @Environment(\.dismiss) private var dismiss
    @State private var individualQualities: [String: StreamQuality] = [:]
    @State private var showingAdvancedOptions = false
    @State private var bandwidthOptimization = true
    @State private var adaptiveQuality = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                        
                        // Global Quality Control
                        globalQualitySection
                        
                        // Individual Stream Controls
                        if !activeStreams.isEmpty {
                            individualStreamSection
                        }
                        
                        // Advanced Options
                        advancedOptionsSection
                        
                        // Performance Info
                        performanceSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupInitialQualities()
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quality Control")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Manage stream quality and performance")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .foregroundColor(.cyan)
            .font(.subheadline)
            .fontWeight(.medium)
        }
    }
    
    // MARK: - Global Quality Section
    private var globalQualitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundColor(.cyan)
                
                Text("Global Quality")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(globalQuality.displayName)
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.cyan.opacity(0.2))
                    )
            }
            
            Text("Set default quality for all new streams")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            qualitySegmentedControl(selectedQuality: $globalQuality)
                .onChange(of: globalQuality) { oldValue, newValue in
                    applyGlobalQuality(newValue)
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
    
    // MARK: - Individual Stream Section
    private var individualStreamSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tv")
                    .font(.title3)
                    .foregroundColor(.purple)
                
                Text("Individual Streams")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(activeStreams.count) active")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(spacing: 12) {
                ForEach(activeStreams, id: \.id) { slot in
                    if let stream = slot.stream {
                        StreamQualityRow(
                            stream: stream,
                            quality: individualQualities[stream.id] ?? globalQuality,
                            onQualityChange: { newQuality in
                                individualQualities[stream.id] = newQuality
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
    
    // MARK: - Advanced Options Section
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: {
                withAnimation(.easeInOut) {
                    showingAdvancedOptions.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.orange)
                    
                    Text("Advanced Options")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: showingAdvancedOptions ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showingAdvancedOptions {
                VStack(spacing: 16) {
                    // Bandwidth Optimization
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bandwidth Optimization")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Text("Automatically adjust quality based on connection")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $bandwidthOptimization)
                            .tint(.cyan)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Adaptive Quality
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Adaptive Quality")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Text("Reduce quality when multiple streams are active")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $adaptiveQuality)
                            .tint(.cyan)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        Button("Optimize All") {
                            optimizeAllStreams()
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.2))
                        )
                        
                        Button("Reset to Auto") {
                            resetAllToAuto()
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                        )
                        
                        Spacer()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
    
    // MARK: - Performance Section
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speedometer")
                    .font(.title3)
                    .foregroundColor(.green)
                
                Text("Performance")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack {
                PerformanceMetric(
                    title: "Bandwidth",
                    value: "\(estimatedBandwidth) Mbps",
                    color: .blue
                )
                
                Spacer()
                
                PerformanceMetric(
                    title: "CPU Usage",
                    value: "\(estimatedCPUUsage)%",
                    color: estimatedCPUUsage > 80 ? .red : .green
                )
                
                Spacer()
                
                PerformanceMetric(
                    title: "Memory",
                    value: "\(estimatedMemoryUsage) MB",
                    color: .orange
                )
            }
            
            // Performance tips
            if estimatedCPUUsage > 70 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Consider reducing quality or number of streams for better performance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
    
    // MARK: - Helper Views and Methods
    private var activeStreams: [StreamSlot] {
        streamSlots.filter { $0.stream != nil }
    }
    
    private var estimatedBandwidth: Int {
        let baseUsage = activeStreams.count * 2 // Base 2 Mbps per stream
        let qualityMultiplier = globalQuality.bandwidthMultiplier
        return Int(Double(baseUsage) * qualityMultiplier)
    }
    
    private var estimatedCPUUsage: Int {
        let baseUsage = activeStreams.count * 15 // Base 15% per stream
        let qualityMultiplier = globalQuality.cpuMultiplier
        return min(100, Int(Double(baseUsage) * qualityMultiplier))
    }
    
    private var estimatedMemoryUsage: Int {
        let baseUsage = activeStreams.count * 150 // Base 150 MB per stream
        let qualityMultiplier = globalQuality.memoryMultiplier
        return Int(Double(baseUsage) * qualityMultiplier)
    }
    
    private func setupInitialQualities() {
        for slot in streamSlots {
            if let stream = slot.stream {
                individualQualities[stream.id] = globalQuality
            }
        }
    }
    
    private func applyGlobalQuality(_ quality: StreamQuality) {
        for slot in streamSlots {
            if let stream = slot.stream {
                individualQualities[stream.id] = quality
            }
        }
    }
    
    private func optimizeAllStreams() {
        let optimalQuality: StreamQuality = activeStreams.count > 4 ? .low : .medium
        globalQuality = optimalQuality
        applyGlobalQuality(optimalQuality)
    }
    
    private func resetAllToAuto() {
        globalQuality = .auto
        applyGlobalQuality(.auto)
    }
    
    @ViewBuilder
    private func qualitySegmentedControl(selectedQuality: Binding<StreamQuality>) -> some View {
        HStack(spacing: 8) {
            ForEach([StreamQuality.auto, .low, .medium, .high, .source], id: \.self) { quality in
                Button(action: {
                    selectedQuality.wrappedValue = quality
                }) {
                    Text(quality.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(selectedQuality.wrappedValue == quality ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedQuality.wrappedValue == quality ? Color.cyan : Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Stream Quality Row
struct StreamQualityRow: View {
    let stream: TwitchStream
    let quality: StreamQuality
    let onQualityChange: (StreamQuality) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(stream.gameName.isEmpty ? "Unknown Game" : stream.gameName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Menu {
                ForEach(StreamQuality.allCases, id: \.self) { qualityOption in
                    Button(action: {
                        onQualityChange(qualityOption)
                    }) {
                        HStack {
                            Text(qualityOption.displayName)
                            if quality == qualityOption {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(quality.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cyan.opacity(0.2))
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Performance Metric
struct PerformanceMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - StreamQuality Extensions
extension StreamQuality {
    var bandwidthMultiplier: Double {
        switch self {
        case .auto: return 1.0
        case .source: return 2.5
        case .high: return 1.8
        case .medium: return 1.0
        case .low: return 0.6
        case .mobile: return 0.3
        }
    }
    
    var cpuMultiplier: Double {
        switch self {
        case .auto: return 1.0
        case .source: return 2.0
        case .high: return 1.5
        case .medium: return 1.0
        case .low: return 0.7
        case .mobile: return 0.5
        }
    }
    
    var memoryMultiplier: Double {
        switch self {
        case .auto: return 1.0
        case .source: return 2.2
        case .high: return 1.6
        case .medium: return 1.0
        case .low: return 0.8
        case .mobile: return 0.6
        }
    }
}

#Preview {
    QualityControlPanel(
        globalQuality: .constant(.medium),
        streamSlots: []
    )
}