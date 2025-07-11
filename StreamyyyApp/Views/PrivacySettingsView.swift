//
//  PrivacySettingsView.swift
//  StreamyyyApp
//
//  Real privacy settings and data management
//

import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfileManager.shared
    
    // Privacy Settings
    @State private var allowAnalytics = true
    @State private var allowCrashReporting = true
    @State private var allowPersonalizedAds = false
    @State private var shareUsageData = true
    @State private var allowLocationAccess = false
    @State private var enableActivityStatus = true
    @State private var showViewingHistory = true
    @State private var allowDataSync = true
    
    // Data Collection
    @State private var collectDeviceInfo = true
    @State private var collectAppUsage = true
    @State private var collectNetworkStats = false
    @State private var collectPerformanceMetrics = true
    
    // Marketing & Communications
    @State private var allowMarketingEmails = false
    @State private var allowProductUpdates = true
    @State private var allowSurveyInvitations = false
    @State private var allowThirdPartyOffers = false
    
    @State private var showingDataDeletion = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDataExport = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List {
                // Privacy Overview
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            Text("Your Privacy Matters")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        
                        Text("Control how your data is collected, used, and shared. These settings help you maintain your privacy while using StreamHub.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // Data Collection & Analytics
                Section("Data Collection & Analytics") {
                    PrivacyToggle(
                        title: "Usage Analytics",
                        description: "Help improve the app by sharing anonymous usage data",
                        isOn: $allowAnalytics,
                        icon: "chart.bar.fill",
                        color: .blue
                    )
                    
                    PrivacyToggle(
                        title: "Crash Reporting",
                        description: "Automatically send crash reports to help fix bugs",
                        isOn: $allowCrashReporting,
                        icon: "exclamationmark.triangle.fill",
                        color: .orange
                    )
                    
                    PrivacyToggle(
                        title: "Performance Metrics",
                        description: "Share app performance data to optimize experience",
                        isOn: $collectPerformanceMetrics,
                        icon: "speedometer",
                        color: .green
                    )
                    
                    PrivacyToggle(
                        title: "Device Information",
                        description: "Share device model and OS version for compatibility",
                        isOn: $collectDeviceInfo,
                        icon: "iphone",
                        color: .purple
                    )
                }
                
                // Personalization
                Section("Personalization") {
                    PrivacyToggle(
                        title: "Personalized Recommendations",
                        description: "Use your viewing history to suggest relevant content",
                        isOn: $shareUsageData,
                        icon: "star.fill",
                        color: .yellow
                    )
                    
                    PrivacyToggle(
                        title: "Activity Status",
                        description: "Show when you're active to connected platforms",
                        isOn: $enableActivityStatus,
                        icon: "circle.fill",
                        color: .green
                    )
                    
                    PrivacyToggle(
                        title: "Viewing History",
                        description: "Save your viewing history for recommendations",
                        isOn: $showViewingHistory,
                        icon: "clock.fill",
                        color: .blue
                    )
                }
                
                // Advertising
                Section("Advertising") {
                    PrivacyToggle(
                        title: "Personalized Ads",
                        description: "Show ads based on your interests and activity",
                        isOn: $allowPersonalizedAds,
                        icon: "rectangle.and.pencil.and.ellipsis",
                        color: .red
                    )
                    
                    Button("Manage Ad Preferences") {
                        // Open ad preferences
                    }
                    .foregroundColor(.blue)
                }
                
                // Location & Sync
                Section("Location & Sync") {
                    PrivacyToggle(
                        title: "Location Access",
                        description: "Use location for regional content and features",
                        isOn: $allowLocationAccess,
                        icon: "location.fill",
                        color: .red
                    )
                    
                    PrivacyToggle(
                        title: "Cloud Sync",
                        description: "Sync your data across devices securely",
                        isOn: $allowDataSync,
                        icon: "icloud.fill",
                        color: .blue
                    )
                }
                
                // Communications
                Section("Communications") {
                    PrivacyToggle(
                        title: "Product Updates",
                        description: "Receive notifications about new features",
                        isOn: $allowProductUpdates,
                        icon: "bell.fill",
                        color: .blue
                    )
                    
                    PrivacyToggle(
                        title: "Marketing Emails",
                        description: "Receive promotional emails and newsletters",
                        isOn: $allowMarketingEmails,
                        icon: "envelope.fill",
                        color: .purple
                    )
                    
                    PrivacyToggle(
                        title: "Survey Invitations",
                        description: "Participate in user research and surveys",
                        isOn: $allowSurveyInvitations,
                        icon: "questionmark.circle.fill",
                        color: .orange
                    )
                    
                    PrivacyToggle(
                        title: "Third-Party Offers",
                        description: "Receive offers from our trusted partners",
                        isOn: $allowThirdPartyOffers,
                        icon: "gift.fill",
                        color: .red
                    )
                }
                
                // Data Management
                Section("Data Management") {
                    Button(action: {
                        showingDataExport = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export My Data")
                                    .foregroundColor(.primary)
                                
                                Text("Download a copy of all your data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        clearViewingHistory()
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Viewing History")
                                    .foregroundColor(.primary)
                                
                                Text("Remove all viewing history data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        showingDataDeletion = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete All Data")
                                    .foregroundColor(.red)
                                
                                Text("Permanently delete your account and data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                // Privacy Resources
                Section("Privacy Resources") {
                    Link(destination: URL(string: Config.URLs.privacyPolicy)!) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Privacy Policy")
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: Config.URLs.termsOfService)!) {
                        HStack {
                            Image(systemName: "doc.plaintext.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Terms of Service")
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Contact Privacy Team") {
                        openPrivacyContact()
                    }
                }
                
                // Data Usage Summary
                Section("Data Usage Summary") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Settings Impact")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        DataUsageIndicator(
                            title: "Data Collection",
                            level: calculateDataCollectionLevel(),
                            description: getDataCollectionDescription()
                        )
                        
                        DataUsageIndicator(
                            title: "Personalization",
                            level: calculatePersonalizationLevel(),
                            description: getPersonalizationDescription()
                        )
                        
                        DataUsageIndicator(
                            title: "Marketing",
                            level: calculateMarketingLevel(),
                            description: getMarketingDescription()
                        )
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        savePrivacySettings()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadPrivacySettings()
        }
        .alert("Delete All Data", isPresented: $showingDataDeletion) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
    }
    
    private func loadPrivacySettings() {
        // Load privacy settings from UserDefaults or user preferences
        if let user = profileManager.currentUser {
            allowAnalytics = user.preferences.enableAnalytics
            allowLocationAccess = user.preferences.privacySettings.allowLocationAccess
            allowPersonalizedAds = user.preferences.privacySettings.allowPersonalizedAds
            shareUsageData = user.preferences.privacySettings.shareUsageData
            allowCrashReporting = user.preferences.privacySettings.allowCrashReporting
        }
    }
    
    private func savePrivacySettings() {
        // Save settings to user preferences
        if var user = profileManager.currentUser {
            user.preferences.enableAnalytics = allowAnalytics
            user.preferences.privacySettings.allowLocationAccess = allowLocationAccess
            user.preferences.privacySettings.allowPersonalizedAds = allowPersonalizedAds
            user.preferences.privacySettings.shareUsageData = shareUsageData
            user.preferences.privacySettings.allowCrashReporting = allowCrashReporting
            
            Task {
                try? await profileManager.updatePreferences(user.preferences)
            }
        }
        
        // Also save to UserDefaults for immediate access
        UserDefaults.standard.set(allowAnalytics, forKey: "allowAnalytics")
        UserDefaults.standard.set(allowLocationAccess, forKey: "allowLocationAccess")
        UserDefaults.standard.set(allowPersonalizedAds, forKey: "allowPersonalizedAds")
        UserDefaults.standard.set(shareUsageData, forKey: "shareUsageData")
        UserDefaults.standard.set(allowCrashReporting, forKey: "allowCrashReporting")
    }
    
    private func clearViewingHistory() {
        // Clear viewing history
        // In a real app, this would clear the user's viewing history from the database
        print("Clearing viewing history...")
    }
    
    private func deleteAllData() {
        Task {
            try? await profileManager.deleteAccount()
        }
    }
    
    private func openPrivacyContact() {
        if let url = URL(string: "mailto:privacy@streamhub.com") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Data Usage Calculations
    
    private func calculateDataCollectionLevel() -> PrivacyLevel {
        let settings = [allowAnalytics, allowCrashReporting, collectPerformanceMetrics, collectDeviceInfo]
        let enabledCount = settings.filter { $0 }.count
        
        switch enabledCount {
        case 0: return .minimal
        case 1...2: return .balanced
        default: return .full
        }
    }
    
    private func calculatePersonalizationLevel() -> PrivacyLevel {
        let settings = [shareUsageData, enableActivityStatus, showViewingHistory, allowDataSync]
        let enabledCount = settings.filter { $0 }.count
        
        switch enabledCount {
        case 0: return .minimal
        case 1...2: return .balanced
        default: return .full
        }
    }
    
    private func calculateMarketingLevel() -> PrivacyLevel {
        let settings = [allowMarketingEmails, allowSurveyInvitations, allowThirdPartyOffers]
        let enabledCount = settings.filter { $0 }.count
        
        switch enabledCount {
        case 0: return .minimal
        case 1: return .balanced
        default: return .full
        }
    }
    
    private func getDataCollectionDescription() -> String {
        switch calculateDataCollectionLevel() {
        case .minimal: return "Very limited data collection"
        case .balanced: return "Moderate data collection for core features"
        case .full: return "Enhanced data collection for full experience"
        }
    }
    
    private func getPersonalizationDescription() -> String {
        switch calculatePersonalizationLevel() {
        case .minimal: return "Basic experience with no personalization"
        case .balanced: return "Some personalized features enabled"
        case .full: return "Fully personalized experience"
        }
    }
    
    private func getMarketingDescription() -> String {
        switch calculateMarketingLevel() {
        case .minimal: return "No marketing communications"
        case .balanced: return "Essential communications only"
        case .full: return "All marketing communications enabled"
        }
    }
}

// MARK: - Supporting Views and Models

enum PrivacyLevel {
    case minimal, balanced, full
    
    var color: Color {
        switch self {
        case .minimal: return .green
        case .balanced: return .orange
        case .full: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .minimal: return "shield.fill"
        case .balanced: return "shield.lefthalf.filled"
        case .full: return "shield.slash.fill"
        }
    }
}

struct PrivacyToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

struct DataUsageIndicator: View {
    let title: String
    let level: PrivacyLevel
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: level.icon)
                .foregroundColor(level.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(level.color == .green ? "Low" : level.color == .orange ? "Medium" : "High")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(level.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(level.color.opacity(0.1))
                )
        }
    }
}

#Preview {
    PrivacySettingsView()
}"