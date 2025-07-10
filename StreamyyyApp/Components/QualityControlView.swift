//
//  QualityControlView.swift
//  StreamyyyApp
//
//  User interface for stream quality control and performance monitoring
//

import SwiftUI

// MARK: - Quality Control View

struct QualityControlView: View {
    @ObservedObject var qualityService = QualityService.shared
    @State private var showingPerformanceDetails = false
    @State private var showingQualitySettings = false
    @State private var showingDiagnostics = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Quality Status Card
            QualityStatusCard(
                currentQuality: qualityService.currentQuality,
                networkCondition: qualityService.networkCondition,
                isAdaptive: qualityService.isAdaptiveQualityEnabled,
                onToggleAdaptive: {
                    if qualityService.isAdaptiveQualityEnabled {
                        qualityService.disableAdaptiveQuality()
                    } else {
                        qualityService.enableAdaptiveQuality()
                    }
                }
            )
            
            // Performance Metrics
            PerformanceMetricsView(
                metrics: qualityService.performanceMetrics,
                thermalState: qualityService.thermalState,
                batteryState: qualityService.batteryState
            )
            
            // Control Buttons
            HStack(spacing: 12) {
                Button("Quality Settings") {
                    showingQualitySettings = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Performance") {
                    showingPerformanceDetails = true
                }
                .buttonStyle(.bordered)
                
                Button("Diagnostics") {
                    showingDiagnostics = true
                }
                .buttonStyle(.bordered)
            }
            
            // Quality Selection (if not adaptive)
            if !qualityService.isAdaptiveQualityEnabled {
                QualitySelectionView(
                    availableQualities: qualityService.availableQualities,
                    selectedQuality: qualityService.currentQuality,
                    onQualitySelected: { quality in
                        qualityService.setQuality(quality, userInitiated: true)
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingQualitySettings) {
            QualitySettingsView()
        }
        .sheet(isPresented: $showingPerformanceDetails) {
            PerformanceDetailsView()
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView()
        }
    }
}

// MARK: - Quality Status Card

struct QualityStatusCard: View {
    let currentQuality: StreamQuality
    let networkCondition: NetworkCondition
    let isAdaptive: Bool
    let onToggleAdaptive: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stream Quality")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(currentQuality.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(networkCondition.statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(networkCondition.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Toggle("Adaptive Quality", isOn: Binding(
                    get: { isAdaptive },
                    set: { _ in onToggleAdaptive() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            if isAdaptive {
                Text("Quality automatically adjusts based on network conditions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Manual quality control enabled")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Performance Metrics View

struct PerformanceMetricsView: View {
    let metrics: PerformanceMetrics
    let thermalState: ThermalState
    let batteryState: BatteryState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                MetricCard(
                    title: "Frame Rate",
                    value: String(format: "%.1f fps", metrics.frameRate),
                    color: metrics.frameRate > 30 ? .green : .orange
                )
                
                MetricCard(
                    title: "Dropped Frames",
                    value: String(format: "%.1f%%", metrics.frameDropRate * 100),
                    color: metrics.frameDropRate < 0.05 ? .green : .red
                )
                
                MetricCard(
                    title: "Buffer Health",
                    value: String(format: "%.1fs", metrics.bufferHealth),
                    color: metrics.bufferHealth > 2.0 ? .green : .orange
                )
                
                MetricCard(
                    title: "CPU Usage",
                    value: String(format: "%.1f%%", metrics.cpuUsage * 100),
                    color: metrics.cpuUsage < 0.7 ? .green : .red
                )
                
                MetricCard(
                    title: "Memory",
                    value: String(format: "%.1f%%", metrics.memoryUsage * 100),
                    color: metrics.memoryUsage < 0.8 ? .green : .orange
                )
                
                MetricCard(
                    title: "Thermal",
                    value: thermalState.displayName,
                    color: thermalState.color
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Quality Selection View

struct QualitySelectionView: View {
    let availableQualities: [StreamQuality]
    let selectedQuality: StreamQuality
    let onQualitySelected: (StreamQuality) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual Quality")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableQualities, id: \.self) { quality in
                        QualityButton(
                            quality: quality,
                            isSelected: quality == selectedQuality,
                            onTap: { onQualitySelected(quality) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quality Button

struct QualityButton: View {
    let quality: StreamQuality
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(quality.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(quality.resolution)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60, height: 40)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quality Settings View

struct QualitySettingsView: View {
    @ObservedObject private var qualityService = QualityService.shared
    @ObservedObject private var qualityPresets = QualityPresets()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Quality Presets") {
                    ForEach(qualityPresets.getAllPresets(), id: \.id) { preset in
                        PresetRow(
                            preset: preset,
                            isSelected: qualityPresets.currentPreset?.id == preset.id,
                            onSelect: {
                                qualityPresets.selectPreset(preset)
                            }
                        )
                    }
                }
                
                Section("Optimization Settings") {
                    Toggle("Battery Optimization", isOn: .constant(qualityPresets.userPreferences.batteryOptimization))
                    Toggle("Thermal Optimization", isOn: .constant(qualityPresets.userPreferences.thermalOptimization))
                    Toggle("Network Optimization", isOn: .constant(qualityPresets.userPreferences.networkOptimization))
                }
                
                Section("Display Settings") {
                    Toggle("Show Quality Indicator", isOn: .constant(qualityPresets.userPreferences.showQualityIndicator))
                    Toggle("Notify Quality Changes", isOn: .constant(qualityPresets.userPreferences.notifyQualityChanges))
                }
            }
            .navigationTitle("Quality Settings")
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

// MARK: - Preset Row

struct PresetRow: View {
    let preset: QualityPreset
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Performance Details View

struct PerformanceDetailsView: View {
    @ObservedObject private var qualityService = QualityService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Performance Score
                    PerformanceScoreCard(metrics: qualityService.performanceMetrics)
                    
                    // Detailed Metrics
                    DetailedMetricsView(metrics: qualityService.performanceMetrics)
                    
                    // System Status
                    SystemStatusView(
                        thermalState: qualityService.thermalState,
                        batteryState: qualityService.batteryState,
                        networkCondition: qualityService.networkCondition
                    )
                    
                    // Recommendations
                    RecommendationsView()
                }
                .padding()
            }
            .navigationTitle("Performance Details")
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

// MARK: - Performance Score Card

struct PerformanceScoreCard: View {
    let metrics: PerformanceMetrics
    
    private var performanceScore: Double {
        var score = 100.0
        
        // Frame rate impact
        if metrics.frameRate < 30 {
            score -= 20
        } else if metrics.frameRate < 60 {
            score -= 10
        }
        
        // Frame drop impact
        score -= metrics.frameDropRate * 100
        
        // CPU usage impact
        score -= metrics.cpuUsage * 30
        
        // Memory usage impact
        score -= metrics.memoryUsage * 20
        
        return max(0, min(100, score))
    }
    
    private var scoreColor: Color {
        switch performanceScore {
        case 80...100: return .green
        case 60...80: return .yellow
        case 40...60: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Performance Score")
                .font(.headline)
                .foregroundColor(.primary)
            
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0.0, to: performanceScore / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: performanceScore)
                
                Text(String(format: "%.0f", performanceScore))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
            }
            
            Text(scoreDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var scoreDescription: String {
        switch performanceScore {
        case 80...100: return "Excellent performance"
        case 60...80: return "Good performance"
        case 40...60: return "Fair performance"
        default: return "Poor performance"
        }
    }
}

// MARK: - Detailed Metrics View

struct DetailedMetricsView: View {
    let metrics: PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detailed Metrics")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                MetricRow(title: "Frame Rate", value: String(format: "%.1f fps", metrics.frameRate))
                MetricRow(title: "Frame Drop Rate", value: String(format: "%.2f%%", metrics.frameDropRate * 100))
                MetricRow(title: "Buffer Health", value: String(format: "%.1f seconds", metrics.bufferHealth))
                MetricRow(title: "CPU Usage", value: String(format: "%.1f%%", metrics.cpuUsage * 100))
                MetricRow(title: "Memory Usage", value: String(format: "%.1f%%", metrics.memoryUsage * 100))
                MetricRow(title: "Network Throughput", value: String(format: "%.1f Mbps", metrics.networkThroughput))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - System Status View

struct SystemStatusView: View {
    let thermalState: ThermalState
    let batteryState: BatteryState
    let networkCondition: NetworkCondition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Status")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                StatusRow(title: "Thermal State", value: thermalState.displayName, color: thermalState.color)
                StatusRow(title: "Battery State", value: batteryState.displayName, color: batteryState.color)
                StatusRow(title: "Network", value: networkCondition.displayName, color: networkCondition.statusColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recommendations View

struct RecommendationsView: View {
    @ObservedObject private var qualityService = QualityService.shared
    
    var body: some View {
        let recommendations = qualityService.performanceMonitor.getPerformanceRecommendations()
        
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recommendations, id: \.self) { recommendation in
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                            
                            Text(recommendation.displayText)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Diagnostics View

struct DiagnosticsView: View {
    @ObservedObject private var qualityService = QualityService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Health Summary
                    HealthSummaryCard()
                    
                    // Connection Quality
                    ConnectionQualityCard()
                    
                    // Stream Issues
                    StreamIssuesCard()
                    
                    // Diagnostics Report
                    DiagnosticsReportCard()
                }
                .padding()
            }
            .navigationTitle("Stream Diagnostics")
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

// MARK: - Health Summary Card

struct HealthSummaryCard: View {
    @ObservedObject private var qualityService = QualityService.shared
    
    var body: some View {
        let healthSummary = qualityService.healthDiagnostics.getHealthSummary()
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Stream Health")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall Health")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(healthSummary.overallHealth.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(healthSummary.overallHealth.color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Health Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.0f%%", healthSummary.healthScore))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(healthSummary.healthScore > 70 ? .green : .red)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                MetricRow(title: "Uptime", value: String(format: "%.1f%%", healthSummary.uptime * 100))
                MetricRow(title: "Error Rate", value: String(format: "%.2f%%", healthSummary.errorRate * 100))
                MetricRow(title: "Avg Response Time", value: String(format: "%.0f ms", healthSummary.averageResponseTime * 1000))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Connection Quality Card

struct ConnectionQualityCard: View {
    @ObservedObject private var qualityService = QualityService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection Quality")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(qualityService.healthDiagnostics.connectionQuality.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(qualityService.healthDiagnostics.connectionQuality.color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Network")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(qualityService.networkCondition.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(qualityService.networkCondition.statusColor)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Stream Issues Card

struct StreamIssuesCard: View {
    @ObservedObject private var qualityService = QualityService.shared
    
    var body: some View {
        let activeIssues = qualityService.healthDiagnostics.activeIssues
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Issues")
                .font(.headline)
                .foregroundColor(.primary)
            
            if activeIssues.isEmpty {
                Text("No active issues")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(activeIssues, id: \.self) { issue in
                    HStack {
                        Circle()
                            .fill(issue.severity.color)
                            .frame(width: 8, height: 8)
                        
                        Text(issue.displayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(issue.severity.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(issue.severity.color)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Diagnostics Report Card

struct DiagnosticsReportCard: View {
    @ObservedObject private var qualityService = QualityService.shared
    
    var body: some View {
        let report = qualityService.healthDiagnostics.getDiagnosticsReport()
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics Report")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                MetricRow(title: "Connection Attempts", value: "\(report.connectionAttempts)")
                MetricRow(title: "Successful Connections", value: "\(report.successfulConnections)")
                MetricRow(title: "Success Rate", value: String(format: "%.1f%%", report.successRate * 100))
                MetricRow(title: "Total Errors", value: "\(report.totalErrors)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension NetworkCondition {
    var statusColor: Color {
        switch self {
        case .ethernet: return .green
        case .wifi: return .blue
        case .cellular: return .orange
        case .offline: return .red
        case .unknown: return .gray
        }
    }
}

extension ThermalState {
    var color: Color {
        switch self {
        case .normal: return .green
        case .warm: return .yellow
        case .hot: return .orange
        case .critical: return .red
        }
    }
}

extension BatteryState {
    var color: Color {
        switch self {
        case .normal: return .green
        case .low: return .orange
        case .critical: return .red
        case .charging: return .blue
        }
    }
}

#Preview {
    QualityControlView()
}