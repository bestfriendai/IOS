//
//  ContentView.swift
//  StreamyyyApp
//
//  Modern entry point with enhanced UI/UX
//

import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @State private var isLoading = true
    @State private var hasCompletedOnboarding = true // Set to false for onboarding
    
    var body: some View {
        Group {
            if isLoading {
                SplashScreenView()
            } else if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainAppTabView()
            }
        }
        .onAppear {
            // Simulate app initialization
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Splash Screen
struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background gradient
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
            
            VStack(spacing: 24) {
                // App logo/icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                    
                    Image(systemName: "tv")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // App name
                VStack(spacing: 8) {
                    Text("StreamHub")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(logoOpacity)
                    
                    Text("Multi-Stream Experience")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(logoOpacity)
                }
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    .scaleEffect(1.2)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            // Animate logo appearance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            // Start pulse animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showingMainApp = false
    
    private let onboardingPages = [
        OnboardingPage(
            title: "Welcome to StreamHub",
            description: "Watch multiple live streams simultaneously with our advanced multi-stream technology",
            imageName: "rectangle.3.offgrid",
            color: .purple
        ),
        OnboardingPage(
            title: "Discover Amazing Content",
            description: "Explore live streams from Twitch, YouTube, and more platforms all in one place",
            imageName: "safari",
            color: .cyan
        ),
        OnboardingPage(
            title: "Customize Your Experience",
            description: "Create custom layouts, manage audio, and personalize your viewing experience",
            imageName: "slider.horizontal.3",
            color: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        OnboardingPageView(page: onboardingPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom page indicator and controls
                VStack(spacing: 32) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.cyan : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack {
                        Button("Skip") {
                            showingMainApp = true
                        }
                        .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Button(currentPage == onboardingPages.count - 1 ? "Get Started" : "Next") {
                            if currentPage == onboardingPages.count - 1 {
                                showingMainApp = true
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
                            }
                        }
                        .foregroundColor(.cyan)
                        .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showingMainApp) {
            MainAppTabView()
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [page.color, page.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

// MARK: - Main App Tab View
struct MainAppTabView: View {
    @State private var selectedTab: MainTab = .discover
    
    enum MainTab: Int, CaseIterable {
        case discover = 0
        case watch = 1
        case library = 2
        case profile = 3
        
        var title: String {
            switch self {
            case .discover: return "Discover"
            case .watch: return "Watch"
            case .library: return "Library"
            case .profile: return "Profile"
            }
        }
        
        var icon: String {
            switch self {
            case .discover: return "safari"
            case .watch: return "rectangle.3.offgrid"
            case .library: return "books.vertical"
            case .profile: return "person.circle"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .discover: return "safari.fill"
            case .watch: return "rectangle.3.offgrid.fill"
            case .library: return "books.vertical.fill"
            case .profile: return "person.circle.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Discover Tab
            DiscoverTabView()
                .tabItem {
                    Image(systemName: selectedTab == .discover ? MainTab.discover.selectedIcon : MainTab.discover.icon)
                    Text(MainTab.discover.title)
                }
                .tag(MainTab.discover)
            
            // Watch Tab (Multi-Stream)
            MultiStreamTabView()
                .tabItem {
                    Image(systemName: selectedTab == .watch ? MainTab.watch.selectedIcon : MainTab.watch.icon)
                    Text(MainTab.watch.title)
                }
                .tag(MainTab.watch)
            
            // Library Tab
            LibraryTabView()
                .tabItem {
                    Image(systemName: selectedTab == .library ? MainTab.library.selectedIcon : MainTab.library.icon)
                    Text(MainTab.library.title)
                }
                .tag(MainTab.library)
            
            // Profile Tab
            ProfileTabView()
                .tabItem {
                    Image(systemName: selectedTab == .profile ? MainTab.profile.selectedIcon : MainTab.profile.icon)
                    Text(MainTab.profile.title)
                }
                .tag(MainTab.profile)
        }
        .accentColor(.purple)
    }
}

// MARK: - Tab Views
struct DiscoverTabView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Discover")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Find amazing live streams")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.6))
                            
                            TextField("Search streams...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                        
                        // Quick actions
                        VStack(spacing: 16) {
                            Text("Quick Actions")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                QuickActionCard(
                                    title: "Add Stream",
                                    icon: "plus.circle",
                                    color: .purple
                                )
                                
                                QuickActionCard(
                                    title: "Multi-Stream",
                                    icon: "rectangle.3.offgrid",
                                    color: .cyan
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct MultiStreamTabView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Text("Multi-Stream Viewer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Advanced multi-streaming features coming soon!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

struct LibraryTabView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Text("Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Your saved streams and favorites")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

struct ProfileTabView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    VStack(spacing: 8) {
                        Text("Guest User")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Sign in to personalize your experience")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 12) {
                        Button("Sign In") {
                            // TODO: Implement sign in
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        
                        Button("Settings") {
                            // TODO: Implement settings
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
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
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legacy Support (for backward compatibility)
struct ModernMainView: View {
    var body: some View {
        MainAppTabView()
    }
}

#Preview {
    ContentView()
}