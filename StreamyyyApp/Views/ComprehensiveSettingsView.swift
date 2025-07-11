//
//  ComprehensiveSettingsView.swift
//  StreamyyyApp
//
//  Complete app settings and preferences
//

import SwiftUI

struct ComprehensiveSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var authService = AuthenticationService.shared
    
    // Playback Settings
    @State private var autoPlayStreams = true
    @State private var defaultQuality = "Auto"
    @State private var enableLowLatency = true
    @State private var enablePictureInPicture = true
    @State private var defaultVolume = 0.8
    @State private var enableAudioFocus = true
    
    // Notification Settings
    @State private var enablePushNotifications = true
    @State private var enableLiveStreamAlerts = true
    @State private var enableFollowedStreamers = true
    @State private var enableSystemUpdates = true
    @State private var notificationSound = "Default"
    @State private var quietHoursEnabled = false
    @State private var quietHoursStart = Date()
    @State private var quietHoursEnd = Date()
    
    // Appearance Settings
    @State private var selectedTheme = "System"
    @State private var enableAnimations = true
    @State private var enableHaptics = true
    @State private var enableReducedMotion = false
    @State private var fontSize = "Medium"
    @State private var enableColorblindSupport = false
    
    // Data & Storage
    @State private var enableCellularStreaming = false
    @State private var dataQualityLimit = "720p"
    @State private var enableOfflineMode = false
    @State private var cacheSize = "500 MB"
    @State private var enableAutoDownload = false
    
    // Advanced Settings
    @State private var enableBetaFeatures = false
    @State private var enableDebugMode = false
    @State private var enableAnalytics = true
    @State private var enableCrashReporting = true
    @State private var enablePerformanceMetrics = false
    
    private let themes = ["System", "Light", "Dark"]
    private let qualities = ["Auto", "Source", "1080p", "720p", "480p", "360p"]
    private let fontSizes = ["Small", "Medium", "Large", "Extra Large"]
    private let notificationSounds = ["Default", "Stream Alert", "Chime", "Bell", "None"]
    private let cacheSizes = ["100 MB", "250 MB", "500 MB", "1 GB", "2 GB"]
    
    var body: some View {
        NavigationView {
            List {
                // Playback Settings
                Section("Playback") {
                    Toggle("Auto-play Streams", isOn: $autoPlayStreams)
                    
                    Picker("Default Quality", selection: $defaultQuality) {
                        ForEach(qualities, id: \.self) { quality in
                            Text(quality).tag(quality)
                        }
                    }
                    
                    Toggle("Enable Low Latency", isOn: $enableLowLatency)
                    Toggle("Picture in Picture", isOn: $enablePictureInPicture)
                    Toggle("Audio Focus Management", isOn: $enableAudioFocus)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Volume")
                            Spacer()
                            Text("\\(Int(defaultVolume * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $defaultVolume, in: 0...1, step: 0.1)
                            .accentColor(.purple)
                    }
                }
                
                // Notification Settings
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $enablePushNotifications)
                    
                    if enablePushNotifications {
                        Toggle("Live Stream Alerts", isOn: $enableLiveStreamAlerts)
                        Toggle("Followed Streamers", isOn: $enableFollowedStreamers)
                        Toggle("System Updates", isOn: $enableSystemUpdates)
                        
                        Picker("Notification Sound", selection: $notificationSound) {
                            ForEach(notificationSounds, id: \.self) { sound in
                                Text(sound).tag(sound)
                            }
                        }
                        
                        Toggle("Quiet Hours", isOn: $quietHoursEnabled)
                        
                        if quietHoursEnabled {
                            DatePicker("Start Time", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                            DatePicker("End Time", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                        }
                    }
                }
                
                // Appearance Settings
                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                    
                    Picker("Font Size", selection: $fontSize) {
                        ForEach(fontSizes, id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    
                    Toggle("Animations", isOn: $enableAnimations)
                    Toggle("Haptic Feedback", isOn: $enableHaptics)
                    Toggle("Reduce Motion", isOn: $enableReducedMotion)
                    Toggle("Colorblind Support", isOn: $enableColorblindSupport)
                }
                
                // Data & Storage
                Section("Data & Storage") {
                    Toggle("Cellular Streaming", isOn: $enableCellularStreaming)
                    
                    if enableCellularStreaming {
                        Picker("Cellular Quality Limit", selection: $dataQualityLimit) {
                            ForEach(qualities.dropFirst(), id: \.self) { quality in
                                Text(quality).tag(quality)
                            }
                        }
                    }
                    
                    Toggle("Offline Mode", isOn: $enableOfflineMode)
                    Toggle("Auto Download", isOn: $enableAutoDownload)
                    
                    Picker("Cache Size", selection: $cacheSize) {
                        ForEach(cacheSizes, id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    
                    Button("Clear Cache") {
                        clearCache()
                    }
                    .foregroundColor(.red)
                }
                
                // Privacy & Security
                Section("Privacy & Security") {
                    NavigationLink("Privacy Settings") {
                        PrivacySettingsView()
                    }
                    
                    if authService.isAuthenticated {
                        NavigationLink("Account Security") {
                            AccountSecurityView()
                        }
                        
                        NavigationLink("Data Management") {
                            DataManagementView()
                        }
                    }
                }
                
                // Advanced Settings
                Section("Advanced") {
                    Toggle("Beta Features", isOn: $enableBetaFeatures)
                    Toggle("Analytics", isOn: $enableAnalytics)
                    Toggle("Crash Reporting", isOn: $enableCrashReporting)
                    Toggle("Performance Metrics", isOn: $enablePerformanceMetrics)
                    
                    #if DEBUG
                    Toggle("Debug Mode", isOn: $enableDebugMode)
                    
                    Button("Export Logs") {
                        exportLogs()
                    }
                    #endif
                    
                    Button("Reset All Settings") {
                        resetAllSettings()
                    }
                    .foregroundColor(.red)
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\\(Config.App.version) (\\(Config.App.build))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build Date")
                        Spacer()
                        Text(buildDate)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Check for Updates") {
                        checkForUpdates()
                    }
                    
                    NavigationLink("Open Source Licenses") {
                        LicensesView()
                    }
                    
                    Link("Privacy Policy", destination: URL(string: Config.URLs.privacyPolicy)!)
                    Link("Terms of Service", destination: URL(string: Config.URLs.termsOfService)!)
                    Link("Support", destination: URL(string: Config.URLs.support)!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private var buildDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date()) // In real app, this would be build date
    }
    
    private func loadSettings() {
        // Load settings from UserDefaults or User preferences
        let defaults = UserDefaults.standard
        
        autoPlayStreams = defaults.bool(forKey: "autoPlayStreams") 
        enablePushNotifications = defaults.bool(forKey: "enablePushNotifications")
        enableAnimations = defaults.bool(forKey: "enableAnimations")
        enableCellularStreaming = defaults.bool(forKey: "enableCellularStreaming")
        enableBetaFeatures = defaults.bool(forKey: "enableBetaFeatures")
        enableAnalytics = defaults.bool(forKey: "enableAnalytics")
        
        defaultQuality = defaults.string(forKey: "defaultQuality") ?? "Auto"
        selectedTheme = defaults.string(forKey: "selectedTheme") ?? "System"
        fontSize = defaults.string(forKey: "fontSize") ?? "Medium"
        
        // If user is authenticated, load from user preferences
        if let user = profileManager.currentUser {
            autoPlayStreams = user.preferences.autoPlayStreams
            enablePushNotifications = user.preferences.enableNotifications
            enableAnimations = user.preferences.layoutSettings.animationsEnabled
            defaultQuality = user.preferences.defaultQuality.rawValue
            selectedTheme = user.preferences.theme.rawValue
        }
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        
        // Save to UserDefaults
        defaults.set(autoPlayStreams, forKey: "autoPlayStreams")
        defaults.set(enablePushNotifications, forKey: "enablePushNotifications")
        defaults.set(enableAnimations, forKey: "enableAnimations")
        defaults.set(enableCellularStreaming, forKey: "enableCellularStreaming")
        defaults.set(enableBetaFeatures, forKey: "enableBetaFeatures")
        defaults.set(enableAnalytics, forKey: "enableAnalytics")
        defaults.set(defaultQuality, forKey: "defaultQuality")
        defaults.set(selectedTheme, forKey: "selectedTheme")
        defaults.set(fontSize, forKey: "fontSize")
        
        // If user is authenticated, save to user preferences
        if var user = profileManager.currentUser {
            user.preferences.autoPlayStreams = autoPlayStreams
            user.preferences.enableNotifications = enablePushNotifications
            user.preferences.layoutSettings.animationsEnabled = enableAnimations
            user.preferences.defaultQuality = StreamQuality(rawValue: defaultQuality) ?? .high
            user.preferences.theme = AppTheme(rawValue: selectedTheme.lowercased()) ?? .system
            
            Task {
                try? await profileManager.updatePreferences(user.preferences)
            }
        }
    }
    
    private func clearCache() {
        // Clear app cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear image cache if using a library
        // ImageCache.shared.clear()
        
        // Show confirmation
        let alert = UIAlertController(
            title: "Cache Cleared",
            message: "App cache has been cleared successfully.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func resetAllSettings() {
        let alert = UIAlertController(
            title: "Reset All Settings",
            message: "This will reset all settings to their default values. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            performReset()
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func performReset() {
        // Reset to default values
        autoPlayStreams = true
        defaultQuality = "Auto"
        enableLowLatency = true
        enablePictureInPicture = true
        enablePushNotifications = true
        selectedTheme = "System"
        enableAnimations = true
        enableCellularStreaming = false
        enableBetaFeatures = false
        enableAnalytics = true
        
        // Clear UserDefaults
        let defaults = UserDefaults.standard
        let keys = [
            "autoPlayStreams", "enablePushNotifications", "enableAnimations",
            "enableCellularStreaming", "enableBetaFeatures", "enableAnalytics",
            "defaultQuality", "selectedTheme", "fontSize"
        ]
        
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        
        saveSettings()
    }
    
    private func checkForUpdates() {
        // In a real app, this would check the App Store for updates
        let alert = UIAlertController(
            title: "Up to Date",
            message: "You're running the latest version of StreamHub.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    #if DEBUG
    private func exportLogs() {
        // Export debug logs for development
        let logs = "Debug logs would be exported here..."
        
        let activityController = UIActivityViewController(
            activityItems: [logs],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
    #endif
}

// MARK: - Supporting Views

struct AccountSecurityView: View {
    @StateObject private var clerkManager = ClerkManager.shared
    @State private var showingPasswordChange = false
    @State private var showingTwoFactorSetup = false
    @State private var twoFactorEnabled = false
    
    var body: some View {
        List {
            Section("Security") {
                Button("Change Password") {
                    showingPasswordChange = true
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Two-Factor Authentication")
                        Text("Add an extra layer of security")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $twoFactorEnabled)
                        .labelsHidden()
                }
                
                Button("View Login History") {
                    // Show login history
                }
                
                Button("Sign Out All Devices") {
                    // Sign out from all devices
                }
                .foregroundColor(.orange)
            }
            
            Section("Danger Zone") {
                Button("Delete Account") {
                    // Show account deletion flow
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Account Security")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPasswordChange) {
            PasswordChangeView()
        }
        .sheet(isPresented: $showingTwoFactorSetup) {
            TwoFactorSetupView()
        }
        .onChange(of: twoFactorEnabled) { _, newValue in
            if newValue {
                showingTwoFactorSetup = true
            }
        }
    }
}

struct DataManagementView: View {
    @StateObject private var profileManager = ProfileManager.shared
    @State private var showingExportData = false
    @State private var showingDeleteData = false
    
    var body: some View {
        List {
            Section("Your Data") {
                Button("Export Data") {
                    showingExportData = true
                }
                
                Button("Download Profile Backup") {
                    downloadBackup()
                }
                
                Button("View Data Usage") {
                    // Show data usage statistics
                }
            }
            
            Section("Data Control") {
                Button("Clear Viewing History") {
                    clearViewingHistory()
                }
                .foregroundColor(.orange)
                
                Button("Delete All Data") {
                    showingDeleteData = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Data", isPresented: $showingExportData) {
            Button("Cancel", role: .cancel) { }
            Button("Export") {
                exportUserData()
            }
        } message: {
            Text("This will create a file containing all your profile data and viewing history.")
        }
        .alert("Delete All Data", isPresented: $showingDeleteData) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all your data. This action cannot be undone.")
        }
    }
    
    private func downloadBackup() {
        // Create and download profile backup
    }
    
    private func clearViewingHistory() {
        // Clear user's viewing history
    }
    
    private func exportUserData() {
        Task {
            do {
                let data = try await profileManager.exportUserData()
                
                let activityController = UIActivityViewController(
                    activityItems: [data],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    await MainActor.run {
                        window.rootViewController?.present(activityController, animated: true)
                    }
                }
            } catch {
                print("Failed to export user data: \\(error)")
            }
        }
    }
    
    private func deleteAllData() {
        Task {
            try? await profileManager.deleteAccount()
        }
    }
}

struct LicensesView: View {
    private let licenses = [
        License(name: "SwiftUI", description: "Apple's declarative UI framework"),
        License(name: "Combine", description: "Apple's reactive programming framework"),
        License(name: "Foundation", description: "Apple's foundational framework"),
        License(name: "WebKit", description: "Apple's web browser engine"),
        License(name: "AVFoundation", description: "Apple's audiovisual framework")
    ]
    
    var body: some View {
        List(licenses) { license in
            VStack(alignment: .leading, spacing: 4) {
                Text(license.name)
                    .font(.headline)
                
                Text(license.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Open Source Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct License: Identifiable {
    let id = UUID()
    let name: String
    let description: String
}

struct PasswordChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    SecureField("Current Password", text: $currentPassword)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("New Password", text: $newPassword)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button("Change Password") {
                    changePassword()
                }
                .disabled(!isFormValid || isLoading)
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 6
    }
    
    private func changePassword() {
        isLoading = true
        
        // Mock password change
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            dismiss()
        }
    }
}

struct TwoFactorSetupView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Two-Factor Authentication Setup")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Scan this QR code with your authenticator app")
                    .foregroundColor(.secondary)
                
                // Mock QR code
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Text("QR Code")
                            .foregroundColor(.secondary)
                    )
                
                Button("I've Set Up My Authenticator") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("2FA Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ComprehensiveSettingsView()
}"