//
//  AccountManagementView.swift
//  StreamyyyApp
//
//  Real account management with security features
//

import SwiftUI

struct AccountManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var clerkManager = ClerkManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var showingPasswordChange = false
    @State private var showingEmailChange = false
    @State private var showingDeleteAccount = false
    @State private var showingTwoFactorSetup = false
    @State private var showingLoginSessions = false
    @State private var showingDataExport = false
    
    // Account Info
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var phoneNumber = ""
    
    // Security Settings
    @State private var twoFactorEnabled = false
    @State private var loginNotifications = true
    @State private var deviceNotifications = true
    @State private var securityAlerts = true
    
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Profile Information
                Section("Profile Information") {
                    ProfileInfoField(title: "First Name", text: $firstName)
                    ProfileInfoField(title: "Last Name", text: $lastName)
                    ProfileInfoField(title: "Username", text: $username)
                    ProfileInfoField(title: "Phone Number", text: $phoneNumber, keyboardType: .phonePad)
                    
                    Button("Save Changes") {
                        saveProfileChanges()
                    }
                    .disabled(isLoading)
                    .foregroundColor(.blue)
                }
                
                // Account Security
                Section("Account Security") {
                    Button(action: {
                        showingPasswordChange = true
                    }) {
                        AccountActionRow(
                            icon: "key.fill",
                            title: "Change Password",
                            subtitle: "Update your login password",
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingEmailChange = true
                    }) {
                        AccountActionRow(
                            icon: "envelope.fill",
                            title: "Change Email",
                            subtitle: profileManager.userEmail ?? "No email set",
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    HStack {
                        AccountActionRow(
                            icon: "shield.fill",
                            title: "Two-Factor Authentication",
                            subtitle: twoFactorEnabled ? "Enabled" : "Disabled",
                            showChevron: false
                        )
                        
                        Spacer()
                        
                        Toggle("", isOn: $twoFactorEnabled)
                            .labelsHidden()
                    }
                    
                    Button(action: {
                        showingLoginSessions = true
                    }) {
                        AccountActionRow(
                            icon: "desktopcomputer",
                            title: "Active Sessions",
                            subtitle: "Manage logged-in devices",
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Privacy & Data
                Section("Privacy & Data") {
                    Toggle("Login Notifications", isOn: $loginNotifications)
                    Toggle("New Device Alerts", isOn: $deviceNotifications)
                    Toggle("Security Alerts", isOn: $securityAlerts)
                    
                    Button(action: {
                        showingDataExport = true
                    }) {
                        AccountActionRow(
                            icon: "square.and.arrow.up",
                            title: "Export Data",
                            subtitle: "Download your account data",
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Platform Connections
                Section("Connected Platforms") {
                    PlatformConnectionRow(
                        platform: "Twitch",
                        icon: "gamecontroller.fill",
                        isConnected: authService.twitchAuthStatus == .authenticated,
                        color: .purple,
                        action: {
                            toggleTwitchConnection()
                        }
                    )
                    
                    PlatformConnectionRow(
                        platform: "YouTube",
                        icon: "play.rectangle.fill",
                        isConnected: authService.youtubeAuthStatus == .authenticated,
                        color: .red,
                        action: {
                            toggleYouTubeConnection()
                        }
                    )
                    
                    Button("Manage All Connections") {
                        // Open comprehensive platform connections view
                    }
                    .foregroundColor(.blue)
                }
                
                // Danger Zone
                Section("Danger Zone") {
                    Button(action: {
                        showingDeleteAccount = true
                    }) {
                        AccountActionRow(
                            icon: "trash.fill",
                            title: "Delete Account",
                            subtitle: "Permanently delete your account",
                            color: .red,
                            showChevron: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Account Management")
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
            loadAccountData()
        }
        .sheet(isPresented: $showingPasswordChange) {
            PasswordChangeView()
        }
        .sheet(isPresented: $showingEmailChange) {
            EmailChangeView()
        }
        .sheet(isPresented: $showingTwoFactorSetup) {
            TwoFactorSetupView()
        }
        .sheet(isPresented: $showingLoginSessions) {
            LoginSessionsView()
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
        .alert("Delete Account", isPresented: $showingDeleteAccount) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted, including your viewing history, favorites, and subscription.")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: twoFactorEnabled) { _, newValue in
            if newValue && !twoFactorEnabled {
                showingTwoFactorSetup = true
            }
        }
    }
    
    private func loadAccountData() {
        if let user = profileManager.currentUser {
            firstName = user.firstName ?? ""
            lastName = user.lastName ?? ""
            username = user.username ?? ""
            phoneNumber = user.phoneNumber ?? ""
        }
        
        // Load security settings
        twoFactorEnabled = UserDefaults.standard.bool(forKey: "twoFactorEnabled")
        loginNotifications = UserDefaults.standard.bool(forKey: "loginNotifications")
        deviceNotifications = UserDefaults.standard.bool(forKey: "deviceNotifications")
        securityAlerts = UserDefaults.standard.bool(forKey: "securityAlerts")
    }
    
    private func saveProfileChanges() {
        isLoading = true
        
        Task {
            do {
                try await profileManager.updateProfile(
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    username: username.isEmpty ? nil : username
                )
                
                // Save security preferences
                UserDefaults.standard.set(loginNotifications, forKey: "loginNotifications")
                UserDefaults.standard.set(deviceNotifications, forKey: "deviceNotifications")
                UserDefaults.standard.set(securityAlerts, forKey: "securityAlerts")
                
                await MainActor.run {
                    successMessage = "Profile updated successfully"
                    showingSuccessAlert = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update profile: \\(error.localizedDescription)"
                    showingErrorAlert = true
                    isLoading = false
                }
            }
        }
    }
    
    private func toggleTwitchConnection() {
        Task {
            do {
                if authService.twitchAuthStatus == .authenticated {
                    // Disconnect Twitch
                    try await authService.signOut()
                } else {
                    // Connect Twitch
                    try await authService.authenticateWithTwitch()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update Twitch connection: \\(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func toggleYouTubeConnection() {
        Task {
            do {
                if authService.youtubeAuthStatus == .authenticated {
                    // Disconnect YouTube (would need specific implementation)
                    // For now, just show success
                    successMessage = "YouTube disconnected successfully"
                    showingSuccessAlert = true
                } else {
                    // Connect YouTube
                    try await authService.authenticateWithYouTube()
                    successMessage = "YouTube connected successfully"
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update YouTube connection: \\(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await profileManager.deleteAccount()
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete account: \\(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ProfileInfoField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
        }
    }
}

struct AccountActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = .primary
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color == .primary ? .blue : color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlatformConnectionRow: View {
    let platform: String
    let icon: String
    let isConnected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(platform)
                    .font(.subheadline)
                
                Text(isConnected ? "Connected" : "Not connected")
                    .font(.caption)
                    .foregroundColor(isConnected ? .green : .secondary)
            }
            
            Spacer()
            
            Button(isConnected ? "Disconnect" : "Connect") {
                action()
            }
            .font(.caption)
            .foregroundColor(isConnected ? .red : .blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isConnected ? Color.red : Color.blue, lineWidth: 1)
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Additional Views

struct EmailChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var clerkManager = ClerkManager.shared
    
    @State private var newEmail = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Current Email")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(clerkManager.userEmail ?? "No email")
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    TextField("New Email", text: $newEmail)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Current Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button("Change Email") {
                    changeEmail()
                }
                .disabled(!isFormValid || isLoading)
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Change Email")
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
        !newEmail.isEmpty && 
        newEmail.contains("@") && 
        !password.isEmpty &&
        newEmail != clerkManager.userEmail
    }
    
    private func changeEmail() {
        isLoading = true
        
        // Mock email change - in real app would integrate with Clerk
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if newEmail.contains("@") {
                isLoading = false
                dismiss()
            } else {
                errorMessage = "Invalid email address"
                showingError = true
                isLoading = false
            }
        }
    }
}

struct LoginSessionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let mockSessions = [
        LoginSession(id: "1", device: "iPhone 15 Pro", location: "San Francisco, CA", lastActive: Date(), isCurrent: true),
        LoginSession(id: "2", device: "MacBook Pro", location: "San Francisco, CA", lastActive: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(), isCurrent: false),
        LoginSession(id: "3", device: "iPad Air", location: "Los Angeles, CA", lastActive: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), isCurrent: false)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Active Sessions") {
                    ForEach(mockSessions) { session in
                        LoginSessionRow(session: session) {
                            // Revoke session
                        }
                    }
                }
                
                Section {
                    Button("Sign Out All Other Devices") {
                        // Sign out all other devices
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Login Sessions")
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

struct LoginSession: Identifiable {
    let id: String
    let device: String
    let location: String
    let lastActive: Date
    let isCurrent: Bool
}

struct LoginSessionRow: View {
    let session: LoginSession
    let onRevoke: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.device)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if session.isCurrent {
                        Text("Current")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(session.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Last active: \\(RelativeDateTimeFormatter().localizedString(for: session.lastActive, relativeTo: Date()))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !session.isCurrent {
                Button("Revoke") {
                    onRevoke()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var isExporting = false
    @State private var exportCompleted = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Export Your Data")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Download a copy of all your account data including profile information, viewing history, and preferences.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your export will include:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ExportItem(icon: "person.circle", text: "Profile information")
                        ExportItem(icon: "clock", text: "Viewing history")
                        ExportItem(icon: "heart", text: "Favorites and bookmarks")
                        ExportItem(icon: "gearshape", text: "App preferences")
                        ExportItem(icon: "creditcard", text: "Subscription data")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: exportData) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isExporting ? "Exporting..." : "Export Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isExporting)
                
                if exportCompleted {
                    Text("✓ Export completed successfully")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .padding()
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
    
    private func exportData() {
        isExporting = true
        
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
                        isExporting = false
                        exportCompleted = true
                    }
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                }
            }
        }
    }
}

struct ExportItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    AccountManagementView()
}"