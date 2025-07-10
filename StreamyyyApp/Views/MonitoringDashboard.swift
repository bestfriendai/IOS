//
//  MonitoringDashboard.swift
//  StreamyyyApp
//
//  Real-time monitoring dashboard for system health and performance
//

import SwiftUI
import Charts
import Combine

struct MonitoringDashboard: View {
    @StateObject private var monitoringManager = MonitoringManager.shared
    @StateObject private var alertManager = AlertManager.shared
    @State private var selectedTab = 0
    @State private var isAlertsExpanded = false
    @State private var autoRefresh = true
    @State private var refreshInterval: Double = 5.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with refresh controls
                headerView
                
                // Tab selection
                tabSelectionView
                
                // Main content
                TabView(selection: $selectedTab) {
                    // System Health
                    systemHealthView
                        .tag(0)
                    
                    // Performance Metrics
                    performanceMetricsView
                        .tag(1)
                    
                    // Stream Quality
                    streamQualityView
                        .tag(2)
                    
                    // User Analytics
                    userAnalyticsView
                        .tag(3)
                    
                    // Alerts & Logs
                    alertsView
                        .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Monitoring Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { exportData() }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { showSettings() }) {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                startMonitoring()
            }
            .onDisappear {
                stopMonitoring()
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // System status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(monitoringManager.systemStatus.color)
                    .frame(width: 12, height: 12)
                    .animation(.easeInOut(duration: 0.3), value: monitoringManager.systemStatus)
                
                Text(monitoringManager.systemStatus.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Auto refresh toggle
            Toggle("Auto Refresh", isOn: $autoRefresh)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                .scaleEffect(0.8)
            
            // Refresh interval
            if autoRefresh {
                Stepper("", value: $refreshInterval, in: 1...60, step: 1)
                    .labelsHidden()
                    .frame(width: 80)
                
                Text("\(Int(refreshInterval))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Manual refresh button
            Button(action: { refreshData() }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
            }
            .disabled(monitoringManager.isRefreshing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .shadow(radius: 1)
    }
    
    // MARK: - Tab Selection View
    private var tabSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(0..<5) { index in
                    Button(action: { selectedTab = index }) {
                        VStack(spacing: 4) {
                            Image(systemName: tabIcon(for: index))
                                .font(.system(size: 20))
                                .foregroundColor(selectedTab == index ? .blue : .gray)
                            
                            Text(tabTitle(for: index))
                                .font(.caption)
                                .foregroundColor(selectedTab == index ? .blue : .gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTab == index ? Color.blue.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - System Health View
    private var systemHealthView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Key metrics cards
                HStack(spacing: 12) {
                    MetricCard(
                        title: "CPU Usage",
                        value: "\(Int(monitoringManager.cpuUsage * 100))%",
                        color: cpuUsageColor,
                        icon: "cpu"
                    )
                    
                    MetricCard(
                        title: "Memory",
                        value: "\(Int(monitoringManager.memoryUsage * 100))%",
                        color: memoryUsageColor,
                        icon: "memorychip"
                    )
                }
                
                HStack(spacing: 12) {
                    MetricCard(
                        title: "Network",
                        value: "\(formatBytes(monitoringManager.networkThroughput))/s",
                        color: .blue,
                        icon: "wifi"
                    )
                    
                    MetricCard(
                        title: "Thermal",
                        value: monitoringManager.thermalState.displayName,
                        color: thermalStateColor,
                        icon: "thermometer"
                    )
                }
                
                // System health chart
                systemHealthChartView
                
                // Active streams status
                activeStreamsStatusView
                
                // Recent system events
                recentSystemEventsView
            }
            .padding()
        }
        .refreshable {
            await refreshSystemHealth()
        }
    }
    
    // MARK: - Performance Metrics View
    private var performanceMetricsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Performance overview
                performanceOverviewView
                
                // Frame rate chart
                frameRateChartView
                
                // Memory usage trend
                memoryUsageTrendView
                
                // Network performance
                networkPerformanceView
                
                // Performance recommendations
                performanceRecommendationsView
            }
            .padding()
        }
        .refreshable {
            await refreshPerformanceMetrics()
        }
    }
    
    // MARK: - Stream Quality View
    private var streamQualityView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Stream quality overview
                streamQualityOverviewView
                
                // Quality metrics by platform
                qualityMetricsByPlatformView
                
                // Buffer health chart
                bufferHealthChartView
                
                // Latency metrics
                latencyMetricsView
                
                // Stream load times
                streamLoadTimesView
            }
            .padding()
        }
        .refreshable {
            await refreshStreamQuality()
        }
    }
    
    // MARK: - User Analytics View
    private var userAnalyticsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // User engagement metrics
                userEngagementMetricsView
                
                // Feature adoption
                featureAdoptionView
                
                // User journey funnel
                userJourneyFunnelView
                
                // Retention metrics
                retentionMetricsView
                
                // A/B test results
                abTestResultsView
            }
            .padding()
        }
        .refreshable {
            await refreshUserAnalytics()
        }
    }
    
    // MARK: - Alerts View
    private var alertsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Alert summary
                alertSummaryView
                
                // Active alerts
                activeAlertsView
                
                // Alert history
                alertHistoryView
                
                // System logs
                systemLogsView
            }
            .padding()
        }
        .refreshable {
            await refreshAlerts()
        }
    }
    
    // MARK: - Helper Views
    private var systemHealthChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Health Trend")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(monitoringManager.healthHistory) { dataPoint in
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Health Score", dataPoint.healthScore)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var activeStreamsStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Streams")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(monitoringManager.activeStreams, id: \.id) { stream in
                HStack {
                    Circle()
                        .fill(stream.isHealthy ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(stream.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(stream.platform)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    
                    Text("\(stream.viewerCount) viewers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Helper Methods
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "heart.circle"
        case 1: return "speedometer"
        case 2: return "play.circle"
        case 3: return "person.2.circle"
        case 4: return "bell.circle"
        default: return "circle"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Health"
        case 1: return "Performance"
        case 2: return "Streams"
        case 3: return "Users"
        case 4: return "Alerts"
        default: return ""
        }
    }
    
    private var cpuUsageColor: Color {
        switch monitoringManager.cpuUsage {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .yellow
        default: return .red
        }
    }
    
    private var memoryUsageColor: Color {
        switch monitoringManager.memoryUsage {
        case 0..<0.6: return .green
        case 0.6..<0.8: return .yellow
        default: return .red
        }
    }
    
    private var thermalStateColor: Color {
        switch monitoringManager.thermalState {
        case .normal: return .green
        case .warm: return .yellow
        case .hot: return .orange
        case .critical: return .red
        }
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func startMonitoring() {
        monitoringManager.startMonitoring()
        if autoRefresh {
            startAutoRefresh()
        }
    }
    
    private func stopMonitoring() {
        monitoringManager.stopMonitoring()
    }
    
    private func startAutoRefresh() {
        // Implementation for auto refresh timer
    }
    
    private func refreshData() {
        Task {
            await monitoringManager.refreshData()
        }
    }
    
    private func exportData() {
        // Implementation for data export
    }
    
    private func showSettings() {
        // Implementation for settings
    }
    
    // MARK: - Async Refresh Methods
    private func refreshSystemHealth() async {
        await monitoringManager.refreshSystemHealth()
    }
    
    private func refreshPerformanceMetrics() async {
        await monitoringManager.refreshPerformanceMetrics()
    }
    
    private func refreshStreamQuality() async {
        await monitoringManager.refreshStreamQuality()
    }
    
    private func refreshUserAnalytics() async {
        await monitoringManager.refreshUserAnalytics()
    }
    
    private func refreshAlerts() async {
        await alertManager.refreshAlerts()
    }
}

// MARK: - Supporting Views
struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Preview
struct MonitoringDashboard_Previews: PreviewProvider {
    static var previews: some View {
        MonitoringDashboard()
    }
}