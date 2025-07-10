//
//  SettingsView.swift
//  StreamyyyApp
//
//  Comprehensive settings and preferences management
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var clerkManager: ClerkManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var showingPreferences = false
    @State private var showingAccountDeletion = false
    @State private var showingDataExport = false
    
    var body: some View {
        NavigationView {
            List {
                // App Preferences Section
                Section(header: Text("App Preferences")) {
                    NavigationLink(destination: PreferencesView()) {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            title: "App Preferences",
                            subtitle: "Customize your experience"
                        )
                    }
                    
                    NavigationLink(destination: NotificationSettingsView()) {
                        SettingsRow(
                            icon: "bell",
                            title: "Notifications",
                            subtitle: "Manage notification settings"
                        )
                    }
                    
                    NavigationLink(destination: StreamingSettingsView()) {
                        SettingsRow(
                            icon: "play.circle",
                            title: "Streaming",
                            subtitle: "Video quality and playback"
                        )
                    }
                }
                
                // Account Section
                if clerkManager.isAuthenticated {
                    Section(header: Text("Account")) {
                        NavigationLink(destination: AccountSettingsView()) {
                            SettingsRow(
                                icon: "person.crop.circle",
                                title: "Account Settings",
                                subtitle: "Manage your account"
                            )
                        }
                        
                        if subscriptionManager.isSubscribed {
                            NavigationLink(destination: SubscriptionManagementView()) {
                                SettingsRow(
                                    icon: "creditcard",
                                    title: "Subscription",
                                    subtitle: "Manage your subscription"
                                )
                            }
                        }
                        
                        NavigationLink(destination: PrivacySettingsView()) {
                            SettingsRow(
                                icon: "shield",
                                title: "Privacy & Security",
                                subtitle: "Data and privacy controls"
                            )
                        }
                    }
                }
                
                // Data Section
                Section(header: Text("Data")) {
                    Button(action: { showingDataExport = true }) {
                        SettingsRow(
                            icon: "square.and.arrow.up",
                            title: "Export Data",
                            subtitle: "Download your data"
                        )
                    }
                    
                    if clerkManager.isAuthenticated {
                        Button(action: clearCache) {
                            SettingsRow(
                                icon: "trash",
                                title: "Clear Cache",
                                subtitle: "Free up storage space"
                            )
                        }
                    }
                }
                
                // Support Section
                Section(header: Text("Support")) {
                    Button(action: openSupport) {
                        SettingsRow(
                            icon: "questionmark.circle",
                            title: "Help & Support",
                            subtitle: "Get help with the app"
                        )
                    }
                    
                    Button(action: sendFeedback) {
                        SettingsRow(
                            icon: "envelope",
                            title: "Send Feedback",
                            subtitle: "Help us improve"
                        )
                    }
                    
                    Button(action: rateApp) {
                        SettingsRow(
                            icon: "star",
                            title: "Rate App",
                            subtitle: "Rate us on the App Store"
                        )
                    }
                }
                
                // Legal Section
                Section(header: Text("Legal")) {
                    Button(action: openPrivacyPolicy) {
                        SettingsRow(
                            icon: "doc.text",
                            title: "Privacy Policy",
                            subtitle: "View our privacy policy"
                        )
                    }
                    
                    Button(action: openTermsOfService) {
                        SettingsRow(
                            icon: "doc.text",
                            title: "Terms of Service",
                            subtitle: "View our terms"
                        )
                    }
                }
                
                // Danger Zone
                if clerkManager.isAuthenticated {
                    Section(header: Text("Danger Zone")) {
                        Button(action: { showingAccountDeletion = true }) {
                            SettingsRow(
                                icon: "exclamationmark.triangle",
                                title: "Delete Account",
                                subtitle: "Permanently delete your account",
                                isDestructive: true
                            )
                        }
                    }
                }
                
                // App Info Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Config.App.version)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Config.App.build)
                            .foregroundColor(.secondary)
                    }
                    
                    if let bundleId = Bundle.main.bundleIdentifier {
                        HStack {
                            Text("Bundle ID")
                            Spacer()
                            Text(bundleId)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
            }
            .alert("Delete Account", isPresented: $showingAccountDeletion) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func clearCache() {
        // Clear app cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: "cached_user_profile")
        UserDefaults.standard.removeObject(forKey: "cached_user_stats")
        UserDefaults.standard.removeObject(forKey: "profile_cache_date")
        
        // Show success message
        // TODO: Add toast notification
    }
    
    private func deleteAccount() async {
        do {
            try await profileManager.deleteAccount()
            dismiss()
        } catch {
            // Handle error
            print("Failed to delete account: \(error)")
        }
    }
    
    private func openSupport() {
        if let url = URL(string: Config.URLs.support) {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendFeedback() {
        if let url = URL(string: "mailto:support@streamyyy.com?subject=Feedback") {
            UIApplication.shared.open(url)
        }
    }
    
    private func rateApp() {
        if let url = URL(string: Config.URLs.appStore) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: Config.URLs.privacyPolicy) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        if let url = URL(string: Config.URLs.termsOfService) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isDestructive ? .red : .blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(ProfileManager(clerkManager: ClerkManager(), modelContext: ModelContext()))
        .environmentObject(ClerkManager())
        .environmentObject(SubscriptionManager())
}