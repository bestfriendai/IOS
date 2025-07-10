//
//  ProfileEditView.swift
//  StreamyyyApp
//
//  Enhanced profile editing interface with validation and accessibility
//

import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var clerkManager: ClerkManager
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingDataExport = false
    @State private var validationErrors: [String: String] = [:]
    @State private var hasUnsavedChanges = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    ProfileHeaderView(
                        user: profileManager.currentUser,
                        displayName: profileManager.displayName,
                        userEmail: profileManager.userEmail,
                        userInitials: profileManager.userInitials
                    )
                    .padding(.bottom, 32)
                    
                    // Form Content
                    VStack(spacing: 24) {
                        // Profile Information Section
                        ProfileSectionView(title: "Profile Information", icon: "person.circle.fill") {
                            VStack(spacing: 16) {
                                CustomTextField(
                                    title: "First Name",
                                    text: $firstName,
                                    icon: "person.fill",
                                    errorMessage: validationErrors["firstName"]
                                )
                                .accessibilityLabel("First Name")
                                .accessibilityHint("Enter your first name")
                                .onChange(of: firstName) { _ in
                                    validateField("firstName", value: firstName)
                                    hasUnsavedChanges = true
                                }
                                
                                CustomTextField(
                                    title: "Last Name",
                                    text: $lastName,
                                    icon: "person.fill",
                                    errorMessage: validationErrors["lastName"]
                                )
                                .accessibilityLabel("Last Name")
                                .accessibilityHint("Enter your last name")
                                .onChange(of: lastName) { _ in
                                    validateField("lastName", value: lastName)
                                    hasUnsavedChanges = true
                                }
                                
                                CustomTextField(
                                    title: "Username",
                                    text: $username,
                                    icon: "at",
                                    errorMessage: validationErrors["username"]
                                )
                                .accessibilityLabel("Username")
                                .accessibilityHint("Enter your username")
                                .onChange(of: username) { _ in
                                    validateField("username", value: username)
                                    hasUnsavedChanges = true
                                }
                                
                                CustomTextField(
                                    title: "Phone Number",
                                    text: $phoneNumber,
                                    icon: "phone.fill",
                                    keyboardType: .phonePad,
                                    errorMessage: validationErrors["phoneNumber"]
                                )
                                .accessibilityLabel("Phone Number")
                                .accessibilityHint("Enter your phone number")
                                .onChange(of: phoneNumber) { _ in
                                    validateField("phoneNumber", value: phoneNumber)
                                    hasUnsavedChanges = true
                                }
                            }
                        }
                
                        // Account Information Section
                        ProfileSectionView(title: "Account Information", icon: "info.circle.fill") {
                            VStack(spacing: 16) {
                                if let email = profileManager.userEmail {
                                    InfoRow(title: "Email", value: email, icon: "envelope.fill")
                                }
                                
                                InfoRow(title: "Member Since", value: profileManager.memberSince, icon: "calendar.circle.fill")
                                
                                if let user = profileManager.currentUser {
                                    HStack {
                                        Image(systemName: "checkmark.shield.fill")
                                            .foregroundColor(.green)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Account Status")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            HStack {
                                                Image(systemName: user.isValidated ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                                    .foregroundColor(user.isValidated ? .green : .orange)
                                                    .font(.caption)
                                                
                                                Text(user.isValidated ? "Verified" : "Pending Verification")
                                                    .font(.caption)
                                                    .foregroundColor(user.isValidated ? .green : .orange)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                
                        // Subscription Section
                        ProfileSectionView(title: "Subscription", icon: "crown.fill") {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.purple)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Current Plan")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text(profileManager.subscriptionStatus.displayName)
                                            .font(.caption)
                                            .foregroundColor(profileManager.subscriptionStatus.color)
                                    }
                                    
                                    Spacer()
                                    
                                    if profileManager.subscriptionStatus == .free {
                                        Button("Upgrade") {
                                            // Handle upgrade
                                        }
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.purple)
                                        .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                
                                if let stats = profileManager.userStats {
                                    VStack(spacing: 8) {
                                        HStack {
                                            StatsItem(title: "Streams Watched", value: "\(stats.totalStreamsWatched)", icon: "play.circle.fill")
                                            Spacer()
                                            StatsItem(title: "Watch Time", value: stats.formattedWatchTime, icon: "clock.fill")
                                        }
                                        
                                        HStack {
                                            StatsItem(title: "Favorites", value: "\(stats.favoriteStreams)", icon: "heart.fill")
                                            Spacer()
                                            StatsItem(title: "Member", value: stats.membershipDuration, icon: "person.badge.clock.fill")
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                
                        // Danger Zone Section
                        ProfileSectionView(title: "Account Actions", icon: "exclamationmark.triangle.fill") {
                            VStack(spacing: 12) {
                                Button(action: { showingDataExport = true }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(.blue)
                                        
                                        Text("Export My Data")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .accessibilityLabel("Export Data")
                                .accessibilityHint("Export your account data")
                                
                                Button(action: { showingDeleteConfirmation = true }) {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.red)
                                        
                                        Text("Delete Account")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.red)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .accessibilityLabel("Delete Account")
                                .accessibilityHint("Permanently delete your account")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // Show confirmation dialog
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isLoading || !isFormValid || !hasUnsavedChanges)
                    .opacity(isFormValid && hasUnsavedChanges ? 1.0 : 0.6)
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text(successMessage)
            }
            .confirmationDialog("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView(profileManager: profileManager)
            }
        }
    }
    
    private func loadCurrentProfile() {
        guard let user = profileManager.currentUser else { return }
        
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        username = user.username ?? ""
        email = user.email
        phoneNumber = user.phoneNumber ?? ""
        
        // Reset change tracking
        hasUnsavedChanges = false
        validationErrors.removeAll()
    }
    
    private var isFormValid: Bool {
        validationErrors.isEmpty &&
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !username.isEmpty
    }
    
    private func validateField(_ field: String, value: String) {
        switch field {
        case "firstName":
            if value.isEmpty {
                validationErrors[field] = "First name is required"
            } else if value.count < 2 {
                validationErrors[field] = "First name must be at least 2 characters"
            } else {
                validationErrors.removeValue(forKey: field)
            }
            
        case "lastName":
            if value.isEmpty {
                validationErrors[field] = "Last name is required"
            } else if value.count < 2 {
                validationErrors[field] = "Last name must be at least 2 characters"
            } else {
                validationErrors.removeValue(forKey: field)
            }
            
        case "username":
            if value.isEmpty {
                validationErrors[field] = "Username is required"
            } else if value.count < 3 {
                validationErrors[field] = "Username must be at least 3 characters"
            } else if !isValidUsername(value) {
                validationErrors[field] = "Username can only contain letters, numbers, and underscores"
            } else {
                validationErrors.removeValue(forKey: field)
            }
            
        case "phoneNumber":
            if !value.isEmpty && !isValidPhoneNumber(value) {
                validationErrors[field] = "Please enter a valid phone number"
            } else {
                validationErrors.removeValue(forKey: field)
            }
            
        default:
            break
        }
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    private func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let phoneRegex = "^[+]?[0-9]{10,15}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phoneNumber)
    }
    
    private func saveProfile() async {
        isLoading = true
        
        do {
            try await profileManager.updateProfile(
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                username: username.isEmpty ? nil : username
            )
            
            hasUnsavedChanges = false
            successMessage = "Profile updated successfully"
            showingSuccess = true
            
            // Auto-dismiss after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
    
    private func deleteAccount() async {
        isLoading = true
        
        do {
            try await profileManager.deleteAccount()
            
            // Account deleted successfully, dismiss and sign out
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
    
    private func exportUserData() async {
        do {
            let data = try await profileManager.exportUserData()
            
            // Save to Documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("streamyyy_data_export.json")
            
            try data.write(to: fileURL)
            
            // Show share sheet
            let activityController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityController, animated: true)
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Supporting UI Components

struct ProfileHeaderView: View {
    let user: User?
    let displayName: String
    let userEmail: String?
    let userInitials: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: user?.profileImageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    Text(userInitials)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // User Info
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let email = userEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 20)
    }
}

struct ProfileSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                TextField(title, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(errorMessage != nil ? Color.red : Color.purple.opacity(0.3), lineWidth: 1)
            )
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 32)
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .font(.title3)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatsItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

struct DataExportView: View {
    let profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportComplete = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "doc.zip")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Export Your Data")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Download a copy of all your account data including profile, streams, and preferences.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Export Button
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
                .padding(.horizontal)
                
                if exportComplete {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("Export Complete!")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Your data has been exported and saved to your device.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
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
    
    private func exportData() {
        isExporting = true
        
        Task {
            do {
                let data = try await profileManager.exportUserData()
                
                // Save to Documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsPath.appendingPathComponent("streamyyy_data_export.json")
                
                try data.write(to: fileURL)
                
                await MainActor.run {
                    isExporting = false
                    exportComplete = true
                }
                
                // Show share sheet
                let activityController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityController, animated: true)
                }
                
            } catch {
                await MainActor.run {
                    isExporting = false
                    // Handle error
                }
            }
        }
    }
}

// MARK: - Extensions

extension SubscriptionStatus {
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        case .premium:
            return "Premium"
        }
    }
    
    var color: Color {
        switch self {
        case .free:
            return .gray
        case .pro:
            return .blue
        case .premium:
            return .purple
        }
    }
}

#Preview {
    ProfileEditView()
        .environmentObject(ProfileManager(clerkManager: ClerkManager(), modelContext: ModelContext()))
        .environmentObject(ClerkManager())
}