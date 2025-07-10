//
//  ProfileView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var clerkManager: ClerkManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var userStatsManager: UserStatsManager
    @State private var showingSettings = false
    @State private var showingSubscription = false
    @State private var showingSignOut = false
    @State private var showingProfile = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeaderView()
                    
                    // Subscription Status
                    if clerkManager.isAuthenticated {
                        SubscriptionStatusCard(showingSubscription: $showingSubscription)
                    }
                    
                    // Quick Stats
                    QuickStatsView()
                    
                    // Menu Items
                    VStack(spacing: 0) {
                        if clerkManager.isAuthenticated && !subscriptionManager.isSubscribed {
                            ProfileMenuItem(
                                icon: "crown.fill",
                                title: "Upgrade to Pro",
                                subtitle: "Unlock premium features",
                                color: .purple
                            ) {
                                showingSubscription = true
                            }
                            
                            Divider().padding(.leading, 60)
                        }
                        
                        if clerkManager.isAuthenticated {
                            ProfileMenuItem(
                                icon: "person.fill",
                                title: "Edit Profile",
                                subtitle: "Update your profile information"
                            ) {
                                showingProfile = true
                            }
                            
                            Divider().padding(.leading, 60)
                        }
                        
                        ProfileMenuItem(
                            icon: "gearshape.fill",
                            title: "Settings",
                            subtitle: "App preferences and configuration"
                        ) {
                            showingSettings = true
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        ProfileMenuItem(
                            icon: "questionmark.circle.fill",
                            title: "Help & Support",
                            subtitle: "Get help and contact support"
                        ) {
                            // Open help
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        ProfileMenuItem(
                            icon: "star.fill",
                            title: "Rate App",
                            subtitle: "Share your feedback"
                        ) {
                            // Open App Store rating
                        }
                        
                        if clerkManager.isAuthenticated {
                            Divider().padding(.leading, 60)
                            
                            ProfileMenuItem(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                subtitle: "Sign out of your account",
                                color: .red
                            ) {
                                showingSignOut = true
                            }
                        } else {
                            Divider().padding(.leading, 60)
                            
                            ProfileMenuItem(
                                icon: "person.badge.plus",
                                title: "Sign In",
                                subtitle: "Sign in to your account",
                                color: .blue
                            ) {
                                // Handle sign in
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 1)
                    
                    // App Info
                    AppInfoView()
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshProfile()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileEditView()
        }
        .confirmationDialog("Sign Out", isPresented: $showingSignOut) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await clerkManager.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func refreshProfile() async {
        isLoading = true
        
        // Refresh profile data
        await profileManager.refreshProfile()
        
        // Refresh subscription data
        await subscriptionManager.refreshSubscription()
        
        // Refresh user stats
        await userStatsManager.refreshStats()
        
        isLoading = false
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    @EnvironmentObject var clerkManager: ClerkManager
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                if clerkManager.isAuthenticated {
                    Text(profileManager.userInitials)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            // User Info
            VStack(spacing: 4) {
                if clerkManager.isAuthenticated {
                    Text(profileManager.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let email = profileManager.userEmail {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Member since \(profileManager.memberSince)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Guest User")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Button("Sign In") {
                        // Navigate to sign in
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
}

// MARK: - Subscription Status Card
struct SubscriptionStatusCard: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showingSubscription: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "crown")
                            .foregroundColor(subscriptionManager.isSubscribed ? .yellow : .gray)
                        
                        Text(subscriptionManager.isSubscribed ? "Pro Member" : "Free Plan")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    if subscriptionManager.isSubscribed {
                        Text("Expires \(expirationDateString)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Upgrade to unlock premium features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(subscriptionManager.isSubscribed ? "Manage" : "Upgrade") {
                    showingSubscription = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if !subscriptionManager.isSubscribed {
                // Pro Features Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pro Features:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        ProFeatureItem(icon: "infinity", text: "Unlimited Streams")
                        ProFeatureItem(icon: "hd.circle", text: "HD Quality")
                        ProFeatureItem(icon: "bell", text: "Notifications")
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(subscriptionManager.isSubscribed ? 
                      LinearGradient(colors: [.purple.opacity(0.1), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                      Color(.systemGray6)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(subscriptionManager.isSubscribed ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private var expirationDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date().addingTimeInterval(30 * 24 * 3600)) // Mock 30 days from now
    }
}

struct ProFeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.purple)
            Text(text)
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Stats
struct QuickStatsView: View {
    @EnvironmentObject var userStatsManager: UserStatsManager
    @EnvironmentObject var clerkManager: ClerkManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Your Stats")
                .font(.headline)
                .fontWeight(.semibold)
            
            if clerkManager.isAuthenticated {
                HStack(spacing: 16) {
                    StatItem(
                        title: "Streams Watched",
                        value: "\(userStatsManager.totalStreamsWatched)",
                        icon: "play.circle.fill"
                    )
                    StatItem(
                        title: "Watch Time",
                        value: userStatsManager.formattedWatchTime,
                        icon: "clock.fill"
                    )
                    StatItem(
                        title: "Favorites",
                        value: "\(userStatsManager.favoriteStreams)",
                        icon: "heart.fill"
                    )
                }
                
                if let mostWatchedPlatform = userStatsManager.mostWatchedPlatform {
                    VStack(spacing: 8) {
                        Text("Most Watched Platform")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: mostWatchedPlatform.systemImage)
                                .foregroundColor(mostWatchedPlatform.color)
                            Text(mostWatchedPlatform.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.top, 8)
                }
            } else {
                VStack(spacing: 16) {
                    Text("Sign in to view your stats")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Sign In") {
                        // Handle sign in
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Menu Item
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(color)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - App Info
struct AppInfoView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Streamyyy")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Version 1.0.0 (Build 1)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("© 2024 Streamyyy Team")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var autoPlayEnabled = true
    @State private var highQualityEnabled = false
    @State private var selectedTheme = "System"
    @State private var selectedQuality = "Auto"
    
    private let themes = ["System", "Light", "Dark"]
    private let qualities = ["Auto", "720p", "1080p", "Source"]
    
    var body: some View {
        NavigationView {
            List {
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                    Toggle("Live Stream Alerts", isOn: $notificationsEnabled)
                }
                
                Section("Playback") {
                    Toggle("Auto-play Streams", isOn: $autoPlayEnabled)
                    Toggle("High Quality by Default", isOn: $highQualityEnabled)
                    
                    Picker("Default Quality", selection: $selectedQuality) {
                        ForEach(qualities, id: \.self) { quality in
                            Text(quality).tag(quality)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                    }
                    
                    Button("Terms of Service") {
                        // Open terms
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
        }
    }
}

// MARK: - Subscription View
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedPlan: SubscriptionPlan = .premium
    @State private var selectedInterval: BillingInterval = .monthly
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Upgrade to Pro")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Unlock all premium features and enjoy unlimited streaming")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Features
                    VStack(spacing: 16) {
                        FeatureRow(icon: "infinity", title: "Unlimited Streams", description: "Watch as many streams as you want")
                        FeatureRow(icon: "hd.circle.fill", title: "HD Quality", description: "Stream in high definition")
                        FeatureRow(icon: "bell.fill", title: "Live Notifications", description: "Get notified when streamers go live")
                        FeatureRow(icon: "heart.fill", title: "Unlimited Favorites", description: "Save all your favorite streamers")
                        FeatureRow(icon: "rectangle.on.rectangle", title: "Picture in Picture", description: "Watch while using other apps")
                        FeatureRow(icon: "wand.and.stars", title: "Advanced Features", description: "Access to beta features first")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Pricing
                    VStack(spacing: 12) {
                        Text("Choose Your Plan")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            // Plan selection
                            VStack(spacing: 8) {
                                ForEach(subscriptionManager.availablePlans, id: \.self) { plan in
                                    PlanCard(
                                        plan: plan,
                                        isSelected: selectedPlan == plan
                                    ) {
                                        selectedPlan = plan
                                    }
                                }
                            }
                            
                            // Billing interval
                            VStack(spacing: 8) {
                                Text("Billing Interval")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack(spacing: 12) {
                                    IntervalButton(
                                        interval: .monthly,
                                        isSelected: selectedInterval == .monthly
                                    ) {
                                        selectedInterval = .monthly
                                    }
                                    
                                    IntervalButton(
                                        interval: .yearly,
                                        isSelected: selectedInterval == .yearly
                                    ) {
                                        selectedInterval = .yearly
                                    }
                                }
                            }
                        }
                    }
                    
                    // Subscribe Button
                    Button(action: subscribe) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Processing..." : "Start Free Trial")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    
                    Text("7-day free trial, then \(selectedPlan.price(for: selectedInterval), specifier: "%.2f")/\(selectedInterval.displayName.lowercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Pro Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func subscribe() {
        isLoading = true
        
        Task {
            do {
                try await subscriptionManager.subscribe(to: selectedPlan, billingInterval: selectedInterval)
                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                // Handle error
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(plan.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? plan.color : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? plan.color.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? plan.color : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct IntervalButton: View {
    let interval: BillingInterval
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(interval.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if interval == .yearly {
                    Text("Save \(interval.discountPercentage)%")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.purple.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
        .environmentObject(SubscriptionManager())
}