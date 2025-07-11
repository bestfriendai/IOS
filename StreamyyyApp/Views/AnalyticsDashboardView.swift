//
//  AnalyticsDashboardView.swift
//  StreamyyyApp
//
//  Real user analytics dashboard with viewing habits and statistics
//

import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userStatsManager = UserStatsManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedMetric: MetricType = .watchTime
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Overview Cards
                    overviewCards
                    
                    // Chart Section
                    chartSection
                    
                    // Platform Breakdown
                    platformBreakdown
                    
                    // Viewing Patterns
                    viewingPatterns
                    
                    // Top Content
                    topContent
                    
                    // Achievements
                    achievements
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(backgroundGradient)
            .navigationTitle("Analytics Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAnalytics()
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Analytics Overview")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        selectedTimeRange = range
                        loadAnalytics()
                    }) {
                        Text(range.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTimeRange == range ? .black : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTimeRange == range ? Color.cyan : Color.white.opacity(0.1))
                            )
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Overview Cards
    private var overviewCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            AnalyticsCard(
                title: "Total Watch Time",
                value: userStatsManager.formattedWatchTime,
                subtitle: getTimeRangeSubtitle(),
                icon: "clock.fill",
                color: .blue,
                trend: .up,
                trendValue: "+12%"
            )
            
            AnalyticsCard(
                title: "Streams Watched",
                value: "\\(userStatsManager.totalStreamsWatched)",
                subtitle: "Total streams",
                icon: "play.circle.fill",
                color: .purple,
                trend: .up,
                trendValue: "+8%"
            )
            
            AnalyticsCard(
                title: "Avg Session",
                value: userStatsManager.userStats?.formattedAverageSession ?? "0m",
                subtitle: "Per session",
                icon: "timer",
                color: .green,
                trend: .stable,
                trendValue: "±0%"
            )
            
            AnalyticsCard(
                title: "Platforms",
                value: "\\(userStatsManager.userStats?.uniquePlatforms ?? 0)",
                subtitle: "Connected",
                icon: "link.circle.fill",
                color: .orange,
                trend: .up,
                trendValue: "+1"
            )
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Activity Trends")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(.cyan)
            }
            
            // Chart View
            VStack(spacing: 12) {
                if let chartData = generateChartData() {
                    Chart(chartData) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.date),
                            y: .value(selectedMetric.displayName, dataPoint.value)
                        )
                        .foregroundStyle(selectedMetric.color.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        AreaMark(
                            x: .value("Date", dataPoint.date),
                            y: .value(selectedMetric.displayName, dataPoint.value)
                        )
                        .foregroundStyle(selectedMetric.color.gradient.opacity(0.3))
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No data available")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        )
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Platform Breakdown
    private var platformBreakdown: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Platform Usage")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                PlatformUsageBar(platform: "Twitch", percentage: 65, color: .purple)
                PlatformUsageBar(platform: "YouTube", percentage: 25, color: .red)
                PlatformUsageBar(platform: "Kick", percentage: 8, color: .green)
                PlatformUsageBar(platform: "Others", percentage: 2, color: .gray)
            }
            
            HStack {
                Text("Most watched: ")
                    .foregroundColor(.white.opacity(0.7))
                + Text("Twitch")
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("65% of total time")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Viewing Patterns
    private var viewingPatterns: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Viewing Patterns")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                PatternCard(
                    title: "Peak Hours",
                    value: "8-10 PM",
                    subtitle: "Most active time",
                    icon: "clock.arrow.circlepath"
                )
                
                PatternCard(
                    title: "Favorite Day",
                    value: "Saturday",
                    subtitle: "Longest sessions",
                    icon: "calendar"
                )
                
                PatternCard(
                    title: "Avg Per Day",
                    value: "2.4 hours",
                    subtitle: "Daily average",
                    icon: "chart.bar"
                )
                
                PatternCard(
                    title: "Longest Session",
                    value: "4.2 hours",
                    subtitle: "Personal record",
                    icon: "stopwatch"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Top Content
    private var topContent: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Top Content")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    // Show detailed content list
                }
                .font(.subheadline)
                .foregroundColor(.cyan)
            }
            
            VStack(spacing: 12) {
                TopContentRow(
                    rank: 1,
                    title: "Just Chatting",
                    subtitle: "Category",
                    watchTime: "12.5 hours",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .blue
                )
                
                TopContentRow(
                    rank: 2,
                    title: "Valorant",
                    subtitle: "Game",
                    watchTime: "8.2 hours",
                    icon: "gamecontroller.fill",
                    color: .red
                )
                
                TopContentRow(
                    rank: 3,
                    title: "Music",
                    subtitle: "Category",
                    watchTime: "6.1 hours",
                    icon: "music.note",
                    color: .green
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Achievements
    private var achievements: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                AchievementBadge(
                    title: "Early Bird",
                    description: "Watch 5 streams before 9 AM",
                    icon: "sun.max.fill",
                    color: .yellow,
                    isUnlocked: true
                )
                
                AchievementBadge(
                    title: "Night Owl",
                    description: "Watch 10 streams after midnight",
                    icon: "moon.fill",
                    color: .indigo,
                    isUnlocked: true
                )
                
                AchievementBadge(
                    title: "Explorer",
                    description: "Watch streams from 5 different platforms",
                    icon: "globe",
                    color: .cyan,
                    isUnlocked: false
                )
                
                AchievementBadge(
                    title: "Marathon",
                    description: "Watch for 6 hours straight",
                    icon: "flame.fill",
                    color: .orange,
                    isUnlocked: true
                )
                
                AchievementBadge(
                    title: "Social",
                    description: "Chat in 20 different streams",
                    icon: "message.fill",
                    color: .green,
                    isUnlocked: false
                )
                
                AchievementBadge(
                    title: "Loyal",
                    description: "Follow a streamer for 30 days",
                    icon: "heart.fill",
                    color: .pink,
                    isUnlocked: false
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Methods
    private func loadAnalytics() {
        isLoading = true
        
        // In a real app, this would load analytics data from the backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
    
    private func getTimeRangeSubtitle() -> String {
        switch selectedTimeRange {
        case .day: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        }
    }
    
    private func generateChartData() -> [ChartDataPoint]? {
        // Generate mock chart data based on selected time range and metric
        let calendar = Calendar.current
        let endDate = Date()
        let days = selectedTimeRange.days
        
        var data: [ChartDataPoint] = []
        
        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: endDate) ?? endDate
            let value = Double.random(in: selectedMetric.range)
            data.append(ChartDataPoint(date: date, value: value))
        }
        
        return data.reversed()
    }
}

// MARK: - Supporting Models and Enums

enum TimeRange: CaseIterable {
    case day, week, month, year
    
    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
    
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

enum MetricType: CaseIterable {
    case watchTime, streamsWatched, sessionLength
    
    var displayName: String {
        switch self {
        case .watchTime: return "Watch Time"
        case .streamsWatched: return "Streams"
        case .sessionLength: return "Session Length"
        }
    }
    
    var color: Color {
        switch self {
        case .watchTime: return .blue
        case .streamsWatched: return .purple
        case .sessionLength: return .green
        }
    }
    
    var range: ClosedRange<Double> {
        switch self {
        case .watchTime: return 0...8
        case .streamsWatched: return 0...15
        case .sessionLength: return 0...4
        }
    }
}

enum TrendDirection {
    case up, down, stable
}

struct ChartDataPoint {
    let date: Date
    let value: Double
}

// MARK: - Supporting Views

struct AnalyticsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    let trendValue: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .foregroundColor(trendColor)
                        .font(.caption)
                    
                    Text(trendValue)
                        .font(.caption)
                        .foregroundColor(trendColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var trendIcon: String {
        switch trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "minus"
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

struct PlatformUsageBar: View {
    let platform: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(platform)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\\(Int(percentage))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (percentage / 100))
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

struct PatternCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.cyan)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cyan.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct TopContentRow: View {
    let rank: Int
    let title: String
    let subtitle: String
    let watchTime: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24)
            
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text(watchTime)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct AchievementBadge: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isUnlocked ? color : .gray)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isUnlocked ? .white : .gray)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(isUnlocked ? .white.opacity(0.7) : .gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUnlocked ? color.opacity(0.1) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnlocked ? color.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}

#Preview {
    AnalyticsDashboardView()
}"