//
//  PreferencesView.swift
//  StreamyyyApp
//
//  App preferences and customization settings
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var clerkManager: ClerkManager
    
    @State private var currentPreferences: UserPreferences
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init() {
        _currentPreferences = State(initialValue: UserPreferences())
    }
    
    var body: some View {
        Form {
            // Appearance Section
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $currentPreferences.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                
                Toggle("Enable Haptic Feedback", isOn: $currentPreferences.enableHapticFeedback)
                Toggle("Enable Sound Effects", isOn: $currentPreferences.enableSoundEffects)
            }
            
            // Streaming Section
            Section(header: Text("Streaming")) {
                Toggle("Auto-play Streams", isOn: $currentPreferences.autoPlayStreams)
                Toggle("Enable Picture in Picture", isOn: $currentPreferences.enablePictureInPicture)
                
                Picker("Default Quality", selection: $currentPreferences.defaultQuality) {
                    ForEach(StreamQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
            }
            
            // Notifications Section
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $currentPreferences.enableNotifications)
                
                if currentPreferences.enableNotifications {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notification Types")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        // Add specific notification toggles here
                        Text("Configure which notifications you want to receive in the Notifications section.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Chat Section
            Section(header: Text("Chat")) {
                Toggle("Enable Chat", isOn: $currentPreferences.chatSettings.enableChat)
                Toggle("Enable Emotes", isOn: $currentPreferences.chatSettings.enableEmotes)
                Toggle("Enable Mentions", isOn: $currentPreferences.chatSettings.enableMentions)
                Toggle("Enable Profanity Filter", isOn: $currentPreferences.chatSettings.enableProfanityFilter)
                Toggle("Enable Spam Protection", isOn: $currentPreferences.chatSettings.enableSpamProtection)
                
                Picker("Chat Font Size", selection: $currentPreferences.chatSettings.fontSize) {
                    ForEach(ChatFontSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                
                HStack {
                    Text("Auto-hide Delay")
                    Spacer()
                    Text("\(Int(currentPreferences.chatSettings.autoHideDelay))s")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $currentPreferences.chatSettings.autoHideDelay,
                    in: 1...30,
                    step: 1
                )
            }
            
            // Layout Section
            Section(header: Text("Layout")) {
                Toggle("Enable Grid Lines", isOn: $currentPreferences.layoutSettings.enableGridLines)
                Toggle("Enable Stream Labels", isOn: $currentPreferences.layoutSettings.enableLabels)
                Toggle("Compact Mode", isOn: $currentPreferences.layoutSettings.compactMode)
                Toggle("Enable Animations", isOn: $currentPreferences.layoutSettings.animationsEnabled)
                
                Picker("Default Layout", selection: $currentPreferences.layoutSettings.defaultLayout) {
                    Text("Single Stream").tag("single")
                    Text("2x2 Grid").tag("grid2x2")
                    Text("3x3 Grid").tag("grid3x3")
                    Text("Custom").tag("custom")
                }
            }
            
            // Privacy Section
            Section(header: Text("Privacy")) {
                Toggle("Allow Analytics", isOn: $currentPreferences.privacySettings.allowAnalytics)
                Toggle("Allow Crash Reporting", isOn: $currentPreferences.privacySettings.allowCrashReporting)
                Toggle("Share Usage Data", isOn: $currentPreferences.privacySettings.shareUsageData)
                Toggle("Allow Location Access", isOn: $currentPreferences.privacySettings.allowLocationAccess)
                Toggle("Allow Personalized Ads", isOn: $currentPreferences.privacySettings.allowPersonalizedAds)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Collection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("We collect minimal data to improve your experience. You can control what data is shared above.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Advanced Section
            Section(header: Text("Advanced")) {
                Toggle("Enable Analytics", isOn: $currentPreferences.enableAnalytics)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reset Preferences")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button("Reset to Default") {
                        resetToDefault()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        await savePreferences()
                    }
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            loadCurrentPreferences()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Methods
    
    private func loadCurrentPreferences() {
        if let user = profileManager.currentUser {
            currentPreferences = user.preferences
        }
    }
    
    private func savePreferences() async {
        guard clerkManager.isAuthenticated else { return }
        
        isLoading = true
        
        do {
            try await profileManager.updatePreferences(currentPreferences)
            
            // Show success message
            // TODO: Add toast notification
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
    
    private func resetToDefault() {
        currentPreferences = UserPreferences()
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var notificationsEnabled = true
    @State private var streamAlertsEnabled = true
    @State private var newFollowersEnabled = true
    @State private var systemUpdatesEnabled = true
    
    var body: some View {
        Form {
            Section(header: Text("Notification Types")) {
                Toggle("Push Notifications", isOn: $notificationsEnabled)
                
                if notificationsEnabled {
                    Toggle("Stream Alerts", isOn: $streamAlertsEnabled)
                    Toggle("New Followers", isOn: $newFollowersEnabled)
                    Toggle("System Updates", isOn: $systemUpdatesEnabled)
                }
            }
            
            Section(header: Text("Delivery Settings")) {
                if notificationsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quiet Hours")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text("From")
                            Spacer()
                            Text("10:00 PM")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("To")
                            Spacer()
                            Text("8:00 AM")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Streaming Settings View

struct StreamingSettingsView: View {
    @State private var autoPlayEnabled = true
    @State private var defaultQuality = StreamQuality.high
    @State private var enablePiP = true
    @State private var enableAutoMute = false
    
    var body: some View {
        Form {
            Section(header: Text("Playback")) {
                Toggle("Auto-play Streams", isOn: $autoPlayEnabled)
                Toggle("Auto-mute New Streams", isOn: $enableAutoMute)
                Toggle("Picture in Picture", isOn: $enablePiP)
                
                Picker("Default Quality", selection: $defaultQuality) {
                    ForEach(StreamQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
            }
            
            Section(header: Text("Performance")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Buffer Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Automatic")
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hardware Acceleration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Enabled")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Streaming")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Other Settings Views

struct AccountSettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("Account")) {
                Text("Account settings coming soon...")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SubscriptionManagementView: View {
    var body: some View {
        Form {
            Section(header: Text("Subscription")) {
                Text("Subscription management coming soon...")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("Privacy")) {
                Text("Privacy settings coming soon...")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Data")) {
                    Text("Data export coming soon...")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Export Data")
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

// MARK: - Preview

#Preview {
    NavigationView {
        PreferencesView()
            .environmentObject(ProfileManager(clerkManager: ClerkManager(), modelContext: ModelContext()))
            .environmentObject(ClerkManager())
    }
}