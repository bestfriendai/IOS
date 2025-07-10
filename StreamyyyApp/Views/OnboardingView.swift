//
//  OnboardingView.swift
//  StreamyyyApp
//
//  Enhanced onboarding experience with personalization features
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var clerkManager: ClerkManager
    @State private var currentPage = 0
    @State private var selectedPlatforms: Set<String> = []
    @State private var selectedCategories: Set<String> = []
    @State private var enableNotifications = true
    @State private var showingPermissionRequest = false
    @State private var isLoading = false
    
    private let pages = [
        OnboardingPage(
            title: "Welcome to Streamyyy",
            subtitle: "Watch multiple streams simultaneously",
            imageName: "play.tv",
            description: "Experience the ultimate multi-stream viewer designed for modern content consumption.",
            pageType: .welcome
        ),
        OnboardingPage(
            title: "Choose Your Platforms",
            subtitle: "Select your favorite streaming platforms",
            imageName: "globe",
            description: "Tell us which platforms you use most so we can personalize your experience.",
            pageType: .platforms
        ),
        OnboardingPage(
            title: "Pick Your Interests",
            subtitle: "What content do you enjoy?",
            imageName: "heart.fill",
            description: "Select your favorite categories to get personalized stream recommendations.",
            pageType: .categories
        ),
        OnboardingPage(
            title: "Stay Connected",
            subtitle: "Never miss your favorite streams",
            imageName: "bell.fill",
            description: "Enable notifications to get alerts when your favorite streamers go live.",
            pageType: .notifications
        ),
        OnboardingPage(
            title: "You're All Set!",
            subtitle: "Start watching your favorite streams",
            imageName: "checkmark.circle.fill",
            description: "Your personalized streaming experience is ready. Let's start watching!",
            pageType: .completion
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Page Content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(
                        page: pages[index],
                        selectedPlatforms: $selectedPlatforms,
                        selectedCategories: $selectedCategories,
                        enableNotifications: $enableNotifications,
                        showingPermissionRequest: $showingPermissionRequest
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            
            // Bottom Section
            VStack(spacing: 20) {
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
                
                // Action Buttons
                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button(action: nextPage) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(buttonTitle)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading || !canProceed)
                        .opacity(canProceed ? 1.0 : 0.6)
                        .accessibilityLabel(buttonTitle)
                        .accessibilityHint(buttonHint)
                        
                        if currentPage != 0 {
                            Button("Skip") {
                                completeOnboarding()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityLabel("Skip")
                            .accessibilityHint("Skip onboarding and start using the app")
                        }
                    } else {
                        Button(action: completeOnboarding) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isLoading ? "Setting up..." : "Get Started")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading)
                        .accessibilityLabel("Get Started")
                        .accessibilityHint("Complete onboarding and start using the app")
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.purple.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            requestNotificationPermission()
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonTitle: String {
        switch pages[currentPage].pageType {
        case .welcome:
            return "Next"
        case .platforms:
            return selectedPlatforms.isEmpty ? "Skip" : "Continue"
        case .categories:
            return selectedCategories.isEmpty ? "Skip" : "Continue"
        case .notifications:
            return "Continue"
        case .completion:
            return "Get Started"
        }
    }
    
    private var buttonHint: String {
        switch pages[currentPage].pageType {
        case .welcome:
            return "Proceed to platform selection"
        case .platforms:
            return "Continue with selected platforms"
        case .categories:
            return "Continue with selected categories"
        case .notifications:
            return "Continue with notification settings"
        case .completion:
            return "Complete onboarding"
        }
    }
    
    private var canProceed: Bool {
        switch pages[currentPage].pageType {
        case .welcome, .completion:
            return true
        case .platforms:
            return true // Allow skipping
        case .categories:
            return true // Allow skipping
        case .notifications:
            return true
        }
    }
    
    // MARK: - Actions
    
    private func nextPage() {
        guard currentPage < pages.count - 1 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
    }
    
    private func completeOnboarding() {
        isLoading = true
        
        Task {
            await saveUserPreferences()
            
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        }
    }
    
    private func saveUserPreferences() async {
        // Save user preferences to UserDefaults or database
        UserDefaults.standard.set(Array(selectedPlatforms), forKey: "selected_platforms")
        UserDefaults.standard.set(Array(selectedCategories), forKey: "selected_categories")
        UserDefaults.standard.set(enableNotifications, forKey: "enable_notifications")
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        
        // TODO: Save to user profile if authenticated
        if clerkManager.isAuthenticated {
            // Save to user profile through API
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.enableNotifications = granted
            }
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Binding var selectedPlatforms: Set<String>
    @Binding var selectedCategories: Set<String>
    @Binding var enableNotifications: Bool
    @Binding var showingPermissionRequest: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.purple)
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Interactive Content
            switch page.pageType {
            case .platforms:
                PlatformSelectionView(selectedPlatforms: $selectedPlatforms)
                    .padding(.horizontal, 32)
            case .categories:
                CategorySelectionView(selectedCategories: $selectedCategories)
                    .padding(.horizontal, 32)
            case .notifications:
                NotificationSettingsView(enableNotifications: $enableNotifications)
                    .padding(.horizontal, 32)
            case .completion:
                CompletionSummaryView(
                    selectedPlatforms: selectedPlatforms,
                    selectedCategories: selectedCategories,
                    enableNotifications: enableNotifications
                )
                .padding(.horizontal, 32)
            default:
                EmptyView()
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let description: String
    let pageType: OnboardingPageType
}

enum OnboardingPageType {
    case welcome
    case platforms
    case categories
    case notifications
    case completion
}

// MARK: - Interactive Components

struct PlatformSelectionView: View {
    @Binding var selectedPlatforms: Set<String>
    
    private let platforms = [
        Platform(name: "Twitch", icon: "tv", color: .purple),
        Platform(name: "YouTube", icon: "play.rectangle", color: .red),
        Platform(name: "Kick", icon: "play.circle", color: .green),
        Platform(name: "Discord", icon: "message", color: .blue),
        Platform(name: "Facebook", icon: "video", color: .blue),
        Platform(name: "Instagram", icon: "camera", color: .pink)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select platforms you use:")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(platforms, id: \.name) { platform in
                    PlatformButton(
                        platform: platform,
                        isSelected: selectedPlatforms.contains(platform.name)
                    ) {
                        if selectedPlatforms.contains(platform.name) {
                            selectedPlatforms.remove(platform.name)
                        } else {
                            selectedPlatforms.insert(platform.name)
                        }
                    }
                }
            }
            
            Text("\(selectedPlatforms.count) platform\(selectedPlatforms.count != 1 ? "s" : "") selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CategorySelectionView: View {
    @Binding var selectedCategories: Set<String>
    
    private let categories = [
        "Gaming", "Music", "Art", "Technology", "Sports", "Education",
        "Entertainment", "News", "Science", "Travel", "Food", "Fitness"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("What content do you enjoy?")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
            
            Text("\(selectedCategories.count) categor\(selectedCategories.count != 1 ? "ies" : "y") selected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NotificationSettingsView: View {
    @Binding var enableNotifications: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
                
                Text("Stay updated with notifications")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("Get notified when your favorite streamers go live")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Toggle("Enable Notifications", isOn: $enableNotifications)
                .toggleStyle(SwitchToggleStyle(tint: .purple))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .accessibilityLabel("Enable Notifications")
                .accessibilityHint("Toggle to enable or disable push notifications for live streams")
        }
    }
}

struct CompletionSummaryView: View {
    let selectedPlatforms: Set<String>
    let selectedCategories: Set<String>
    let enableNotifications: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Perfect! You're all set")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Here's what we've set up for you:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                if !selectedPlatforms.isEmpty {
                    SummaryRow(
                        icon: "tv",
                        title: "Platforms",
                        value: "\(selectedPlatforms.count) selected",
                        detail: selectedPlatforms.joined(separator: ", ")
                    )
                }
                
                if !selectedCategories.isEmpty {
                    SummaryRow(
                        icon: "heart.fill",
                        title: "Interests",
                        value: "\(selectedCategories.count) selected",
                        detail: selectedCategories.joined(separator: ", ")
                    )
                }
                
                SummaryRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    value: enableNotifications ? "Enabled" : "Disabled",
                    detail: enableNotifications ? "You'll get live stream alerts" : "No notifications will be sent"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Supporting Views

struct PlatformButton: View {
    let platform: Platform
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: platform.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : platform.color)
                
                Text(platform.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? platform.color : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(platform.color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .accessibilityLabel(platform.name)
        .accessibilityHint(isSelected ? "Deselect \(platform.name)" : "Select \(platform.name)")
    }
}

struct CategoryButton: View {
    let category: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSelected ? Color.purple : Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple, lineWidth: isSelected ? 0 : 1)
                )
        }
        .accessibilityLabel(category)
        .accessibilityHint(isSelected ? "Deselect \(category)" : "Select \(category)")
    }
}

struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Models

struct Platform {
    let name: String
    let icon: String
    let color: Color
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.clear)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingView()
}